package com.h4cks1lv3.iron_cadence

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.util.AtomicFile
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.*
import java.security.MessageDigest
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream
import kotlinx.coroutines.*

/** Private assets never enter MediaStore. Body archives use streaming ZIP and
 * authenticated encryption; restoration is staged before one durable commit. */
class BodyMediaBridge(private val activity: FlutterActivity, messenger: BinaryMessenger, private val stateStore: DurableStateStore) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val root = File(activity.noBackupFilesDir, "progression_body").apply { mkdirs() }
    private val assets = File(root,"assets").apply { mkdirs() }
    private val journalFile = AtomicFile(File(root,"journal.json"))
    private val transaction = AtomicFile(File(root,"transaction.json"))
    private var pending: MethodChannel.Result? = null
    private var pendingExport: File? = null
    private var pendingPassword: String? = null
    private val maxBytes = 2L * 1024 * 1024 * 1024

    init {
        File(activity.cacheDir,"shared_files").listFiles()?.filter {
            System.currentTimeMillis()-it.lastModified()>24*60*60*1000L
        }?.forEach { it.delete() }
        MethodChannel(messenger,"progression_lab/body_media").setMethodCallHandler { call,result ->
            scope.launch {
                try {
                    when(call.method) {
                        "load" -> result.success(withContext(Dispatchers.IO) {
                            recoverTransaction()
                            mapOf("directory" to assets.absolutePath,"journal" to jsonMap(readJournal()))
                        })
                        "saveJournal" -> { withContext(Dispatchers.IO) {
                            val next = JSONObject(call.arguments as String)
                            validateJournal(next, assets)
                            writeAtomic(journalFile,next.toString())
                        }; result.success(null) }
                        "importPhoto" -> result.success(withContext(Dispatchers.IO) { importPhoto(call.argument<String>("path")!!) })
                        "protectScreen" -> { if(call.arguments == true) activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            else activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE);result.success(null) }
                        "unlock" -> unlock(result)
                        "setReminder" -> {
                            val days = (call.argument<Number>("days")?.toInt() ?: 0).coerceIn(0,365)
                            if(days>0 && Build.VERSION.SDK_INT>=33 && activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED) {
                                activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS),8790)
                                result.success(false)
                            } else { scheduleBodyReminder(activity,days);result.success(true) }
                        }
                        "exportArchive" -> {
                            check(pending==null) { "A body file operation is already open." }
                            val password=call.argument<String>("password")!!
                            validatePassword(password)
                            val bundle=JSONObject(call.argument<String>("bundle")!!)
                            val file=withContext(Dispatchers.IO) { exportArchive(bundle,password,call.argument<Boolean>("photos")==true) }
                            pending=result;pendingExport=file
                            activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE);type="application/octet-stream"
                                putExtra(Intent.EXTRA_TITLE,"Progression-Lab-Body.plabbody")
                            },EXPORT)
                        }
                        "importArchive" -> {
                            check(pending==null) { "A body file operation is already open." }
                            val password=call.argument<String>("password")!!;validatePassword(password)
                            pending=result;pendingPassword=password
                            activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE);type="*/*"
                            },IMPORT)
                        }
                        "discardImport" -> {
                            val token=call.argument<String>("token")!!
                            val active=try { JSONObject(String(transaction.readFully(),Charsets.UTF_8)).optString("token") } catch(e:FileNotFoundException) { "" }
                            if(token!=active) stage(token).deleteRecursively()
                            result.success(null)
                        }
                        "commit" -> {
                            withContext(Dispatchers.IO) {
                                val state=JSONObject(call.argument<String>("state")!!)
                                val journal=JSONObject(call.argument<String>("journal")!!)
                                val token=call.argument<String>("token")
                                val tx=JSONObject().put("state",state).put("journal",journal)
                                if(token!=null) tx.put("token",token)
                                validateJournal(journal,if(token==null) assets else stage(token))
                                if(token!=null) for(name in photoNames(journal)) {
                                    val incoming=asset(name,stage(token)); val existing=asset(name)
                                    if(incoming.exists() && existing.exists()) require(digest(incoming)==digest(existing)) { "An existing photo conflicts with the backup." }
                                }
                                writeAtomic(transaction,tx.toString())
                                recoverTransaction()
                            }
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch(e:Exception) { result.error("body_operation_failed",e.message ?: "The body operation failed.",null) }
            }
        }
    }

    fun recoverPending() = recoverTransaction()

    private fun readJournal():JSONObject = try { JSONObject(String(journalFile.readFully(),Charsets.UTF_8)) }
        catch(e:FileNotFoundException) { JSONObject().put("version",1).put("checkIns",JSONArray()) }
    private fun writeAtomic(file:AtomicFile,text:String) {
        val out=file.startWrite()
        try { out.write(text.toByteArray(Charsets.UTF_8));out.fd.sync();file.finishWrite(out) }
        catch(e:Exception) { file.failWrite(out);throw e }
    }
    private fun asset(name:String,base:File=assets):File {
        require(Regex("[A-Za-z0-9_-]{1,100}\\.jpg").matches(name)) { "The photo archive has an invalid asset name." }
        return File(base,name)
    }
    private fun stage(token:String):File {
        require(Regex("[a-f0-9-]{36}").matches(token)) { "Invalid import token." }
        return File(root,"import-$token")
    }
    private fun photoNames(j:JSONObject):Set<String> {
        val names=mutableSetOf<String>()
        val entries=j.optJSONArray("checkIns") ?: JSONArray()
        for(i in 0 until entries.length()) {
            val entry=entries.getJSONObject(i)
            require(entry.optString("id").isNotBlank() && Regex("\\d{4}-\\d{2}-\\d{2}").matches(entry.optString("date"))) { "Invalid check-in." }
            java.time.LocalDate.parse(entry.getString("date"))
            val photos=entry.optJSONArray("photos") ?: JSONArray()
            for(k in 0 until photos.length()) {
                val p=photos.getJSONObject(k);names.add(p.getString("asset"));names.add(p.getString("thumbnail"))
            }
        }
        val draft=j.optJSONObject("draft")
        if(draft!=null) {
            val photos=draft.optJSONArray("photos") ?: JSONArray()
            for(i in 0 until photos.length()) { val p=photos.getJSONObject(i);names.add(p.getString("asset"));names.add(p.getString("thumbnail")) }
        }
        return names
    }
    private fun validateJournal(j:JSONObject,base:File) {
        require(j.optInt("version",1)==1) { "Update the app to open this photo journal." }
        for(name in photoNames(j)) require(asset(name,base).exists() || asset(name).exists()) { "A photo is missing: $name" }
    }
    @Synchronized private fun recoverTransaction() {
        val tx=try { JSONObject(String(transaction.readFully(),Charsets.UTF_8)) } catch(e:FileNotFoundException) { return }
        val token=tx.optString("token")
        if(token.isNotEmpty()) {
            val source=stage(token)
            for(name in photoNames(tx.getJSONObject("journal"))) {
                val existing=asset(name);val incoming=asset(name,source)
                if(incoming.exists()) {
                    if(existing.exists()) require(digest(existing)==digest(incoming)) { "An existing photo conflicts with the backup." }
                    else { val temp=File(assets,"$name.tmp");incoming.copyTo(temp,overwrite=true)
                        FileOutputStream(temp,true).use { it.fd.sync() };check(temp.renameTo(existing)) { "Could not restore photo." } }
                }
            }
        }
        validateJournal(tx.getJSONObject("journal"),assets)
        stateStore.write(tx.getJSONObject("state").toString())
        writeAtomic(journalFile,tx.getJSONObject("journal").toString())
        transaction.delete()
        if(token.isNotEmpty()) stage(token).deleteRecursively()
        // Remove only unreferenced app assets after the committed journal exists.
        val live=photoNames(tx.getJSONObject("journal"))
        assets.listFiles()?.filter { it.extension=="jpg" && it.name !in live }?.forEach { it.delete() }
        File(activity.cacheDir,"shared_files").listFiles()?.filter { it.name.startsWith("body-") && System.currentTimeMillis()-it.lastModified()>24*60*60*1000L }?.forEach { it.delete() }
    }
    private fun importPhoto(path:String):Map<String,Any> {
        val input=File(path)
        require(input.isFile && input.length()<=100L*1024*1024) { "Choose a photo smaller than 100 MB." }
        val bitmap=ImageDecoder.decodeBitmap(ImageDecoder.createSource(input)) { decoder,info,_ ->
            val longest=maxOf(info.size.width,info.size.height)
            val ratio=minOf(1.0,2048.0/longest)
            decoder.setTargetSize(maxOf(1,(info.size.width*ratio).toInt()),maxOf(1,(info.size.height*ratio).toInt()))
            decoder.allocator=ImageDecoder.ALLOCATOR_SOFTWARE
        }
        val id=UUID.randomUUID().toString()
        val main=asset("p_$id.jpg");val thumb=asset("t_$id.jpg")
        try {
            FileOutputStream(main).use { check(bitmap.compress(Bitmap.CompressFormat.JPEG,92,it));it.fd.sync() }
            val scale=320.0/maxOf(bitmap.width,bitmap.height)
            val small=Bitmap.createScaledBitmap(bitmap,maxOf(1,(bitmap.width*scale).toInt()),maxOf(1,(bitmap.height*scale).toInt()),true)
            FileOutputStream(thumb).use { check(small.compress(Bitmap.CompressFormat.JPEG,85,it));it.fd.sync() }
            if(small!==bitmap) small.recycle()
            return mapOf("asset" to main.name,"thumbnail" to thumb.name)
        } catch(e:Exception) { main.delete();thumb.delete();throw e }
        finally { bitmap.recycle() }
    }
    private fun validatePassword(p:String) { require(p.length in 10..256) { "Use a backup password of 10 to 256 characters." } }
    private fun digest(file:File):String {
        val sha=MessageDigest.getInstance("SHA-256")
        file.inputStream().buffered().use { input -> val buffer=ByteArray(65536);while(true) {val n=input.read(buffer);if(n<0)break;sha.update(buffer,0,n)} }
        return sha.digest().joinToString("") { "%02x".format(it) }
    }
    private fun exportArchive(bundle:JSONObject,password:String,photos:Boolean):File {
        val j=bundle.getJSONObject("journal");j.remove("draft");j.put("lockEnabled",false)
        if(!photos) {
            val entries=j.optJSONArray("checkIns") ?: JSONArray()
            for(i in 0 until entries.length()) entries.getJSONObject(i).put("photos",JSONArray())
        }
        bundle.put("format","progression-body").put("version",1).put("photosIncluded",photos)
        val names=photoNames(j);require(names.size<=20000) { "The archive supports up to 10,000 photos." }
        val hashes=JSONObject();var size=0L
        for(name in names) { val f=asset(name);require(f.isFile) { "A photo is missing." };size+=f.length();hashes.put(name,digest(f)) }
        require(size<=maxBytes) { "Split archives larger than 2 GB into smaller exports." }
        bundle.put("assets",hashes)
        val target=File(activity.cacheDir,"body-${UUID.randomUUID()}.plabbody")
        try {
            target.outputStream().buffered().use { output ->
                ZipOutputStream(BodyArchiveCodec.encryptingStream(output,password)).use { zip ->
                    zip.putNextEntry(ZipEntry("body.json"));zip.write(bundle.toString().toByteArray(Charsets.UTF_8));zip.closeEntry()
                    for(name in names) { zip.putNextEntry(ZipEntry(name));asset(name).inputStream().use { it.copyTo(zip) };zip.closeEntry() }
                }
            };return target
        } catch(e:Exception) {target.delete();throw e}
    }
    private fun importArchive(uri:Uri,password:String):Map<String,Any> {
        val token=UUID.randomUUID().toString();val staging=stage(token).apply { mkdirs() }
        val plain=File(staging,"archive.tmp")
        try {
            activity.contentResolver.openInputStream(uri)!!.buffered().use { input ->
                plain.outputStream().buffered().use { output ->
                    BodyArchiveCodec.decrypt(input,output,password,maxBytes+64*1024*1024)
                }
            }
            val seen=mutableSetOf<String>();var expanded=0L
            ZipInputStream(plain.inputStream().buffered()).use { zip ->
                while(true) {
                    val entry=zip.nextEntry ?: break
                    require(!entry.isDirectory && seen.add(entry.name) && seen.size<=20001) { "Invalid or duplicate archive entry." }
                    val dest=if(entry.name=="body.json") File(staging,"body.json") else asset(entry.name,staging)
                    dest.outputStream().buffered().use { output ->
                        val buffer=ByteArray(65536);var fileSize=0L
                        while(true) { val n=zip.read(buffer);if(n<0)break;expanded+=n;fileSize+=n
                            require(expanded<=maxBytes && fileSize<=(if(entry.name=="body.json")16*1024*1024 else 30*1024*1024)) { "Expanded archive exceeds its limit." };output.write(buffer,0,n) }
                    };zip.closeEntry()
                }
            }
            val bundle=JSONObject(File(staging,"body.json").readText())
            require(bundle.optString("format")=="progression-body" && bundle.optInt("version")==1) { "Unsupported body backup version." }
            val j=bundle.getJSONObject("journal");validateJournal(j,staging)
            val names=photoNames(j);val hashes=bundle.getJSONObject("assets")
            require(seen==names+"body.json" && hashes.length()==names.size) { "The asset manifest does not match the archive." }
            for(name in names) require(asset(name,staging).isFile && digest(asset(name,staging))==hashes.getString(name)) { "A restored photo failed verification." }
            plain.delete()
            return mapOf("token" to token,"bundle" to jsonMap(bundle))
        } catch(e:Exception) { staging.deleteRecursively();throw IllegalArgumentException("Could not open the backup. Check the password and file integrity.",e) }
    }
    fun onActivityResult(request:Int,resultCode:Int,data:Intent?):Boolean {
        if(request!=IMPORT && request!=EXPORT)return false
        val result=pending ?: return true;pending=null
        val export=pendingExport;pendingExport=null
        val password=pendingPassword;pendingPassword=null
        val uri=data?.data
        if(resultCode!=Activity.RESULT_OK || uri==null) {export?.delete();result.success(null);return true}
        scope.launch {
            try {
                val value=withContext(Dispatchers.IO) {
                    if(request==IMPORT) importArchive(uri,password!!) else {
                        activity.contentResolver.openOutputStream(uri,"wt")!!.use { out -> export!!.inputStream().use { it.copyTo(out) } };uri.toString()
                    }
                };result.success(value)
            } catch(e:Exception) {result.error("body_archive_failed",e.message,null)}
            finally {export?.delete()}
        };return true
    }
    private fun unlock(result:MethodChannel.Result) {
        BiometricPrompt.Builder(activity).setTitle("Open body progress")
            .setSubtitle("Use your device lock to view private progress photos")
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.DEVICE_CREDENTIAL)
            .build().authenticate(CancellationSignal(),activity.mainExecutor,object:BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(value:BiometricPrompt.AuthenticationResult) {result.success(true)}
                override fun onAuthenticationError(code:Int,message:CharSequence) {result.success(false)}
            })
    }
    fun dispose() { scope.cancel();pending?.error("cancelled","Activity closed. Try again.",null);pending=null;pendingExport?.delete();pendingPassword=null }
    private fun jsonMap(j:JSONObject):Map<String,Any?> = j.keys().asSequence().associateWith { jsonValue(j.get(it)) }
    private fun jsonValue(v:Any?):Any? = when(v) {JSONObject.NULL -> null;is JSONObject -> jsonMap(v);is JSONArray -> (0 until v.length()).map {jsonValue(v.get(it))};else -> v}
    companion object { const val EXPORT=8781;const val IMPORT=8782 }
}

fun scheduleBodyReminder(context:Context,days:Int) {
    val prefs=context.getSharedPreferences("body_reminder",Context.MODE_PRIVATE)
    prefs.edit().putInt("days",days).apply()
    val alarm=context.getSystemService(AlarmManager::class.java)
    val pending=PendingIntent.getBroadcast(context,8783,Intent(context,BodyReminderReceiver::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    alarm.cancel(pending)
    if(days>0) alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,System.currentTimeMillis()+days*24*60*60*1000L,pending)
}
class BodyReminderReceiver:BroadcastReceiver() {
    override fun onReceive(context:Context,intent:Intent) {
        val days=context.getSharedPreferences("body_reminder",Context.MODE_PRIVATE).getInt("days",0)
        if(days<=0)return
        if(intent.action==Intent.ACTION_BOOT_COMPLETED) {scheduleBodyReminder(context,days);return}
        val manager=context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel("body_checkin","Body check-in reminders",NotificationManager.IMPORTANCE_DEFAULT))
        val launch=context.packageManager.getLaunchIntentForPackage(context.packageName)!!.putExtra("bodyProgress",true)
        val pending=PendingIntent.getActivity(context,8784,launch,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification=android.app.Notification.Builder(context,"body_checkin").setSmallIcon(android.R.drawable.ic_menu_camera)
            .setContentTitle("Your optional progress check-in").setContentText("Add a photo or measurement when it suits you.")
            .setContentIntent(pending).setAutoCancel(true).build()
        if(Build.VERSION.SDK_INT<33 || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)==PackageManager.PERMISSION_GRANTED) manager.notify(8783,notification)
        scheduleBodyReminder(context,days)
    }
}

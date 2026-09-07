package com.h4cks1lv3.iron_cadence

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.ExifInterface
import android.net.Uri
import androidx.core.content.FileProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Device tests exercise Android decoding, metadata removal, real FileProvider
 * paths, and an encrypted archive through the production native bridge. */
@RunWith(AndroidJUnit4::class)
class BodyAndroidTest {
    @Test fun privatePhotoArchiveAndSharingContract() {
        val instrumentation=InstrumentationRegistry.getInstrumentation()
        val context=instrumentation.targetContext
        val activity=instrumentation.startActivitySync(Intent(context,MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) as MainActivity
        instrumentation.waitForIdleSync()
        try {
            val field=MainActivity::class.java.getDeclaredField("bodyMediaBridge").apply { isAccessible=true }
            val bridge=field.get(activity)!!
            val source=File(context.cacheDir,"body-instrumented-source.jpg")
            val bitmap=Bitmap.createBitmap(80,120,Bitmap.Config.ARGB_8888).apply { eraseColor(android.graphics.Color.BLUE) }
            source.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG,95,it) }; bitmap.recycle()
            ExifInterface(source).apply {
                setAttribute(ExifInterface.TAG_ORIENTATION,ExifInterface.ORIENTATION_ROTATE_90.toString())
                setAttribute(ExifInterface.TAG_GPS_LATITUDE,"51/1,30/1,0/1")
                setAttribute(ExifInterface.TAG_GPS_LATITUDE_REF,"N")
                setAttribute(ExifInterface.TAG_USER_COMMENT,"Private fixture metadata")
                saveAttributes()
            }
            val importPhoto=bridge.javaClass.getDeclaredMethod("importPhoto",String::class.java).apply { isAccessible=true }
            @Suppress("UNCHECKED_CAST") val imported=importPhoto.invoke(bridge,source.absolutePath) as Map<String,Any>
            val assets=File(context.noBackupFilesDir,"progression_body/assets")
            val master=File(assets,imported["asset"] as String)
            val thumb=File(assets,imported["thumbnail"] as String)
            assertTrue(master.isFile);assertTrue(thumb.isFile)
            val bounds=BitmapFactory.Options().apply { inJustDecodeBounds=true };BitmapFactory.decodeFile(master.path,bounds)
            assertEquals(120,bounds.outWidth);assertEquals(80,bounds.outHeight)
            assertNull(ExifInterface(master).getAttribute(ExifInterface.TAG_GPS_LATITUDE))
            assertNull(ExifInterface(master).getAttribute(ExifInterface.TAG_USER_COMMENT))
            val photo=JSONObject(imported).put("id","photo-test").put("view","Front").put("pose","Relaxed")
            val checkIn=JSONObject().put("id","test-checkin").put("date","2026-09-01").put("photos",JSONArray().put(photo))
            val journal=JSONObject().put("version",1).put("checkIns",JSONArray().put(checkIn))
            val bundle=JSONObject().put("journal",journal).put("measurements",JSONArray()).put("settings",JSONObject())
            val export=bridge.javaClass.getDeclaredMethod("exportArchive",JSONObject::class.java,String::class.java,Boolean::class.javaPrimitiveType).apply { isAccessible=true }
            val archive=export.invoke(bridge,bundle,"instrumented test password",true) as File
            val restore=bridge.javaClass.getDeclaredMethod("importArchive",Uri::class.java,String::class.java).apply { isAccessible=true }
            @Suppress("UNCHECKED_CAST") val restored=restore.invoke(bridge,Uri.fromFile(archive),"instrumented test password") as Map<String,Any>
            assertNotNull(restored["token"]);assertNotNull(restored["bundle"])
            // Exactly the directory used by MainActivity.sharePng must be served.
            val shared=File(context.cacheDir,"shared_files/body-test.png").apply { parentFile!!.mkdirs(); writeBytes(byteArrayOf(1,2,3,4)) }
            val uri=FileProvider.getUriForFile(context,"${context.packageName}.fileprovider",shared)
            assertEquals("content",uri.scheme)
            assertArrayEquals(shared.readBytes(),context.contentResolver.openInputStream(uri)!!.use { it.readBytes() })
            val stage=File(context.noBackupFilesDir,"progression_body/import-${restored["token"]}")
            assertArrayEquals(master.readBytes(),File(stage,master.name).readBytes())
            assertArrayEquals(thumb.readBytes(),File(stage,thumb.name).readBytes())
            stage.deleteRecursively();archive.delete();source.delete();shared.delete();master.delete();thumb.delete()
        } finally { instrumentation.runOnMainSync { activity.finish() } }
    }
}

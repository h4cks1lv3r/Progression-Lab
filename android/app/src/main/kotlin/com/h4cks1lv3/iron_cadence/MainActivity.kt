package com.h4cks1lv3.iron_cadence

import android.app.Activity
import android.content.ClipData
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerativeModel
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.generateContentRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.Calendar
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    private var integrationBridge: IntegrationBridge? = null

    private val aiScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var generativeModel: GenerativeModel? = null
    private var generationJob: Job? = null

    private var pendingOpenResult: MethodChannel.Result? = null
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveBytes: ByteArray? = null
    private var pendingSaveName: String = "Progression-Lab-Export.plab"
    private var pendingSaveMime: String = "application/octet-stream"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        integrationBridge = IntegrationBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        val preferences = getSharedPreferences("iron_cadence", MODE_PRIVATE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "iron_cadence/storage")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "read" -> result.success(preferences.getString("state", null))
                    "write" -> {
                        preferences.edit().putString("state", call.arguments as? String ?: "{}").apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "progression_lab/share")
            .setMethodCallHandler { call, result -> handleShareImageCall(call, result) }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "progression_lab/data_portability",
        ).setMethodCallHandler { call, result -> handleDataPortabilityCall(call, result) }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "progression_lab/gemini")
            .setMethodCallHandler { call, result -> handleGeminiCall(call, result) }
    }

    private fun handleShareImageCall(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        val fileName = safeFileName(
            call.argument<String>("fileName"),
            "progression-lab-workout.png",
        )
        if (bytes == null || bytes.isEmpty()) {
            result.error("invalid_image", "The generated image is empty.", null)
            return
        }
        try {
            when (call.method) {
                "saveImage" -> result.success(saveImage(bytes, fileName))
                "shareImage" -> {
                    shareBytes(bytes, fileName, "image/png", "Share workout")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error(
                "share_failed",
                error.message ?: "The workout image could not be processed.",
                null,
            )
        }
    }

    private fun handleDataPortabilityCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "saveFile" -> beginSaveFile(call, result)
                "pickFile" -> beginPickFile(call, result)
                "shareFile" -> {
                    val bytes = requiredBytes(call)
                    val fileName = safeFileName(
                        call.argument<String>("fileName"),
                        "Progression-Lab-Export.plab",
                    )
                    val mimeType = call.argument<String>("mimeType")
                        ?.takeIf { it.isNotBlank() }
                        ?: "application/octet-stream"
                    shareBytes(bytes, fileName, mimeType, "Share Progression Lab data")
                    result.success(null)
                }
                "writeAutomaticBackup" -> {
                    val bytes = requiredBytes(call)
                    val fileName = safeFileName(
                        call.argument<String>("fileName"),
                        "Progression-Lab-Auto.plab",
                    )
                    val retention = (call.argument<Number>("retention")?.toInt() ?: 16)
                        .coerceIn(1, 100)
                    result.success(writeAutomaticBackup(bytes, fileName, retention))
                }
                "listAutomaticBackups" -> result.success(listAutomaticBackups())
                "readAutomaticBackup" -> {
                    val path = call.argument<String>("path")
                        ?: throw IllegalArgumentException("Backup path is missing.")
                    result.success(verifiedBackupFile(path).readBytes())
                }
                "deleteAutomaticBackup" -> {
                    val path = call.argument<String>("path")
                        ?: throw IllegalArgumentException("Backup path is missing.")
                    val file = verifiedBackupFile(path)
                    if (file.exists() && !file.delete()) {
                        throw IllegalStateException("Android could not delete the backup.")
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error(
                "data_portability_failed",
                error.message ?: "The data operation could not be completed.",
                null,
            )
        }
    }

    private fun handleGeminiCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> aiScope.launch { result.success(readGeminiStatus()) }
            "download" -> aiScope.launch {
                try {
                    val model = model()
                    val status = model.checkStatus()
                    if (status == FeatureStatus.UNAVAILABLE) {
                        result.success(
                            mapOf(
                                "status" to "unavailable",
                                "message" to "Gemini Nano Prompt API is unavailable on this device.",
                            ),
                        )
                        return@launch
                    }
                    if (status != FeatureStatus.AVAILABLE) {
                        model.download().collect { /* Wait for the model flow to complete. */ }
                    }
                    result.success(readGeminiStatus())
                } catch (error: Throwable) {
                    result.error(
                        geminiErrorCode(error),
                        error.message ?: "Gemini Nano could not be prepared.",
                        null,
                    )
                }
            }
            "generate" -> {
                if (generationJob?.isActive == true) {
                    result.error("busy", "An on-device analysis is already running.", null)
                    return
                }
                val prompt = call.argument<String>("prompt")?.trim().orEmpty()
                val systemInstruction =
                    call.argument<String>("systemInstruction")?.trim().orEmpty()
                if (prompt.isEmpty()) {
                    result.error("invalid_prompt", "The analysis prompt is empty.", null)
                    return
                }
                generationJob = aiScope.launch {
                    try {
                        val model = model()
                        val status = model.checkStatus()
                        if (status != FeatureStatus.AVAILABLE) {
                            result.error(
                                "not_available",
                                "Gemini Nano is not ready on this device.",
                                status,
                            )
                            return@launch
                        }
                        val combinedPrompt = buildString {
                            if (systemInstruction.isNotEmpty()) {
                                append(systemInstruction)
                                append("\n\n")
                            }
                            append("VERIFIED PROGRESSION LAB EVIDENCE:\n")
                            append(prompt)
                        }
                        val request = generateContentRequest(TextPart(combinedPrompt)) {
                            temperature = 0.2f
                            topK = 20
                            candidateCount = 1
                            maxOutputTokens = 900
                            seed = 42
                        }
                        val response = model.generateContent(request)
                        val text = response.candidates
                            .joinToString("\n\n") { candidate -> candidate.text }
                            .trim()
                        if (text.isEmpty()) {
                            result.error(
                                "empty_response",
                                "Gemini Nano returned an empty response.",
                                null,
                            )
                            return@launch
                        }
                        val modelName = runCatching { model.getBaseModelName() }.getOrNull()
                        result.success(mapOf("text" to text, "modelName" to modelName))
                    } catch (cancelled: CancellationException) {
                        result.error("cancelled", "The analysis was cancelled.", null)
                    } catch (error: Throwable) {
                        result.error(
                            geminiErrorCode(error),
                            error.message ?: "Gemini Nano could not complete the analysis.",
                            null,
                        )
                    } finally {
                        generationJob = null
                    }
                }
            }
            "cancel" -> {
                generationJob?.cancel()
                generationJob = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun model(): GenerativeModel =
        generativeModel ?: Generation.getClient().also { generativeModel = it }

    private suspend fun readGeminiStatus(): Map<String, Any?> {
        return try {
            val model = model()
            val status = model.checkStatus()
            val statusName = when (status) {
                FeatureStatus.AVAILABLE -> "available"
                FeatureStatus.DOWNLOADABLE -> "downloadable"
                FeatureStatus.DOWNLOADING -> "downloading"
                FeatureStatus.UNAVAILABLE -> "unavailable"
                else -> "unavailable"
            }
            val modelName = if (status == FeatureStatus.AVAILABLE) {
                runCatching { model.getBaseModelName() }.getOrNull()
            } else {
                null
            }
            mapOf("status" to statusName, "modelName" to modelName)
        } catch (error: Throwable) {
            mapOf(
                "status" to "unsupported",
                "message" to (error.message
                    ?: "Gemini Nano Prompt API is not supported on this device."),
            )
        }
    }

    private fun geminiErrorCode(error: Throwable): String {
        val message = error.message?.lowercase().orEmpty()
        return when {
            error is CancellationException -> "cancelled"
            "background" in message -> "background_blocked"
            "battery" in message || "quota" in message -> "quota_exceeded"
            "busy" in message -> "busy"
            "download" in message -> "download_failed"
            "not supported" in message ||
                "not available" in message ||
                "aicore" in message -> "unsupported"
            else -> "genai_failed"
        }
    }

    private fun requiredBytes(call: MethodCall): ByteArray {
        val bytes = call.argument<ByteArray>("bytes")
        if (bytes == null || bytes.isEmpty()) {
            throw IllegalArgumentException("The file is empty.")
        }
        return bytes
    }

    private fun beginSaveFile(call: MethodCall, result: MethodChannel.Result) {
        if (pendingSaveResult != null || pendingOpenResult != null) {
            result.error("picker_busy", "Another file picker is already open.", null)
            return
        }
        pendingSaveBytes = requiredBytes(call)
        pendingSaveName = safeFileName(
            call.argument<String>("fileName"),
            "Progression-Lab-Export.plab",
        )
        pendingSaveMime = call.argument<String>("mimeType")
            ?.takeIf { it.isNotBlank() }
            ?: "application/octet-stream"
        pendingSaveResult = result
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = pendingSaveMime
            putExtra(Intent.EXTRA_TITLE, pendingSaveName)
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQUEST_CREATE_DOCUMENT)
    }

    private fun beginPickFile(call: MethodCall, result: MethodChannel.Result) {
        if (pendingSaveResult != null || pendingOpenResult != null) {
            result.error("picker_busy", "Another file picker is already open.", null)
            return
        }
        pendingOpenResult = result
        val extensions = call.argument<List<String>>("extensions") ?: emptyList()
        val mimeTypes = extensions.flatMap { extension ->
            when (extension.lowercase()) {
                "csv" -> listOf("text/csv", "text/comma-separated-values", "application/csv")
                "zip", "plab" -> listOf("application/zip", "application/octet-stream")
                "gpx" -> listOf("application/gpx+xml", "text/xml", "application/xml")
                "tcx" -> listOf("application/vnd.garmin.tcx+xml", "text/xml", "application/xml")
                "fit" -> listOf("application/octet-stream")
                else -> listOf("application/octet-stream")
            }
        }.distinct().toTypedArray()
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            if (mimeTypes.isNotEmpty()) putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes)
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQUEST_OPEN_DOCUMENT)
    }

    @Deprecated("Deprecated in Android; retained for native integration bridges.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (integrationBridge?.onActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            REQUEST_CREATE_DOCUMENT -> finishSaveFile(resultCode, data?.data)
            REQUEST_OPEN_DOCUMENT -> finishPickFile(resultCode, data?.data)
        }
    }

    private fun finishSaveFile(resultCode: Int, uri: Uri?) {
        val result = pendingSaveResult ?: return
        val bytes = pendingSaveBytes
        pendingSaveResult = null
        pendingSaveBytes = null
        if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) {
            result.success(null)
            return
        }
        try {
            contentResolver.openOutputStream(uri, "wt")?.use { stream ->
                stream.write(bytes)
                stream.flush()
            } ?: throw IllegalStateException("Android could not open the selected file.")
            result.success(uri.toString())
        } catch (error: Exception) {
            result.error("save_failed", error.message ?: "The file could not be saved.", null)
        }
    }

    private fun finishPickFile(resultCode: Int, uri: Uri?) {
        val result = pendingOpenResult ?: return
        pendingOpenResult = null
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        } catch (_: SecurityException) {
            // Some providers return a temporary grant only; reading below still works.
        }
        try {
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: throw IllegalStateException("Android could not open the selected file.")
            if (bytes.size > MAX_IMPORT_BYTES) {
                throw IllegalArgumentException("The selected file is larger than 100 MB.")
            }
            result.success(
                mapOf(
                    "name" to displayName(uri),
                    "bytes" to bytes,
                    "mimeType" to (contentResolver.getType(uri) ?: "application/octet-stream"),
                ),
            )
        } catch (error: Exception) {
            result.error("open_failed", error.message ?: "The file could not be read.", null)
        }
    }

    private fun displayName(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0) return cursor.getString(index)
                }
            }
        return uri.lastPathSegment ?: "Progression-Lab-Import"
    }

    private fun safeFileName(value: String?, fallback: String): String {
        val source = value?.takeIf { it.isNotBlank() } ?: fallback
        return source.replace(Regex("[^A-Za-z0-9._-]"), "-").take(160)
    }

    private fun saveImage(bytes: ByteArray, fileName: String): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw IllegalStateException("Saving workout cards requires Android 10 or newer.")
        }
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(
                MediaStore.Images.Media.RELATIVE_PATH,
                "${Environment.DIRECTORY_PICTURES}/Progression Lab",
            )
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            values,
        ) ?: throw IllegalStateException("Android could not create the image file.")
        try {
            contentResolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
                stream.flush()
            } ?: throw IllegalStateException("Android could not open the image file.")
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            return uri.toString()
        } catch (error: Exception) {
            contentResolver.delete(uri, null, null)
            throw error
        }
    }

    private fun shareBytes(
        bytes: ByteArray,
        fileName: String,
        mimeType: String,
        chooserTitle: String,
    ) {
        val directory = File(cacheDir, "shared_files").apply { mkdirs() }
        val file = File(directory, fileName)
        file.writeBytes(bytes)
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newUri(contentResolver, "Progression Lab data", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, chooserTitle))
    }

    private fun backupsDirectory(): File = File(filesDir, "progression_lab_backups").apply {
        mkdirs()
    }

    private fun writeAutomaticBackup(
        bytes: ByteArray,
        fileName: String,
        retention: Int,
    ): String {
        val directory = backupsDirectory()
        val existing = directory.listFiles()?.filter { it.isFile }?.sortedByDescending {
            it.lastModified()
        } ?: emptyList()
        val digest = sha256(bytes)
        val latest = existing.firstOrNull()
        if (latest != null && sha256(latest.readBytes()).contentEquals(digest)) {
            return latest.absolutePath
        }
        val destination = File(directory, fileName)
        val temporary = File(directory, ".${fileName}.tmp")
        temporary.writeBytes(bytes)
        if (destination.exists()) destination.delete()
        if (!temporary.renameTo(destination)) {
            destination.writeBytes(bytes)
            temporary.delete()
        }
        val refreshed = directory.listFiles()
            ?.filter { it.isFile && !it.name.startsWith(".") }
            ?.sortedByDescending { it.lastModified() }
            ?: emptyList()
        pruneAutomaticBackups(refreshed, retention)
        return destination.absolutePath
    }

    private fun pruneAutomaticBackups(files: List<File>, retention: Int) {
        if (files.size <= 1) return
        val now = System.currentTimeMillis()
        val dayMillis = 24L * 60L * 60L * 1000L
        val keep = linkedSetOf<File>()
        files.take(5).forEach(keep::add)

        val dailyKeys = mutableSetOf<String>()
        val weeklyKeys = mutableSetOf<String>()
        for (file in files) {
            val age = (now - file.lastModified()).coerceAtLeast(0L)
            val calendar = Calendar.getInstance().apply { timeInMillis = file.lastModified() }
            if (age <= 7L * dayMillis) {
                val dayKey = "${calendar.get(Calendar.YEAR)}-${calendar.get(Calendar.DAY_OF_YEAR)}"
                if (dailyKeys.add(dayKey)) keep.add(file)
            }
            if (age <= 28L * dayMillis) {
                val weekKey = "${calendar.get(Calendar.YEAR)}-${calendar.get(Calendar.WEEK_OF_YEAR)}"
                if (weeklyKeys.add(weekKey)) keep.add(file)
            }
        }
        val retained = files.filter { keep.contains(it) }.take(retention).toSet()
        files.filterNot { retained.contains(it) }.forEach { it.delete() }
    }

    private fun listAutomaticBackups(): List<Map<String, Any>> =
        backupsDirectory().listFiles()?.filter { it.isFile && !it.name.startsWith(".") }
            ?.sortedByDescending { it.lastModified() }
            ?.map { file ->
                mapOf(
                    "name" to file.name,
                    "path" to file.absolutePath,
                    "size" to file.length(),
                    "modified" to file.lastModified(),
                )
            } ?: emptyList()

    private fun verifiedBackupFile(path: String): File {
        val directory = backupsDirectory().canonicalFile
        val file = File(path).canonicalFile
        if (file.parentFile != directory) {
            throw SecurityException("The selected path is not an app backup.")
        }
        return file
    }

    private fun sha256(bytes: ByteArray): ByteArray =
        MessageDigest.getInstance("SHA-256").digest(bytes)

    override fun onDestroy() {
        generationJob?.cancel()
        generativeModel?.close()
        generativeModel = null
        aiScope.cancel()
        integrationBridge?.dispose()
        integrationBridge = null
        super.onDestroy()
    }

    companion object {
        private const val REQUEST_CREATE_DOCUMENT = 4201
        private const val REQUEST_OPEN_DOCUMENT = 4202
        private const val MAX_IMPORT_BYTES = 100 * 1024 * 1024
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        integrationBridge?.handleIntent(intent)
    }




}

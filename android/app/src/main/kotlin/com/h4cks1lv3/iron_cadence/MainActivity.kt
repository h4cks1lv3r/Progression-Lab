package com.h4cks1lv3.iron_cadence

import android.content.ClipData
import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerativeModel
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.generateContentRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    private val aiScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var generativeModel: GenerativeModel? = null
    private var generationJob: Job? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
            .setMethodCallHandler { call, result ->
                val bytes = call.argument<ByteArray>("bytes")
                val fileName = safeFileName(call.argument<String>("fileName"))
                if (bytes == null || bytes.isEmpty()) {
                    result.error("invalid_image", "The generated image is empty.", null)
                    return@setMethodCallHandler
                }
                try {
                    when (call.method) {
                        "saveImage" -> result.success(saveImage(bytes, fileName))
                        "shareImage" -> {
                            shareImage(bytes, fileName)
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "progression_lab/gemini")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> aiScope.launch {
                        result.success(readGeminiStatus())
                    }
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
                            return@setMethodCallHandler
                        }
                        val prompt = call.argument<String>("prompt")?.trim().orEmpty()
                        val systemInstruction =
                            call.argument<String>("systemInstruction")?.trim().orEmpty()
                        if (prompt.isEmpty()) {
                            result.error("invalid_prompt", "The analysis prompt is empty.", null)
                            return@setMethodCallHandler
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
                                result.success(
                                    mapOf(
                                        "text" to text,
                                        "modelName" to modelName,
                                    ),
                                )
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
            mapOf(
                "status" to statusName,
                "modelName" to modelName,
            )
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

    override fun onDestroy() {
        generationJob?.cancel()
        generativeModel?.close()
        generativeModel = null
        aiScope.cancel()
        super.onDestroy()
    }

    private fun safeFileName(value: String?): String {
        val source = value?.takeIf { it.isNotBlank() } ?: "progression-lab-workout.png"
        val cleaned = source.replace(Regex("[^A-Za-z0-9._-]"), "-")
        return if (cleaned.endsWith(".png", ignoreCase = true)) cleaned else "$cleaned.png"
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

    private fun shareImage(bytes: ByteArray, fileName: String) {
        val directory = File(cacheDir, "shared_workouts").apply { mkdirs() }
        val file = File(directory, fileName)
        file.writeBytes(bytes)
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newUri(contentResolver, "Progression Lab workout", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, "Share workout"))
    }
}

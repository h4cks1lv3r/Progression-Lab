package com.h4cks1lv3.iron_cadence

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import androidx.documentfile.provider.DocumentFile
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.BodyFatRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.Mass
import androidx.health.connect.client.units.Percentage
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Native services used by the optional integrations hub.
 *
 * This bridge deliberately uses startActivityForResult instead of AndroidX's
 * registerForActivityResult API because FlutterActivity is not required to be
 * a ComponentActivity. MainActivity forwards activity results and OAuth deep
 * links into this class.
 */
class IntegrationBridge(
    private val activity: FlutterActivity,
    messenger: BinaryMessenger,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val preferences = activity.getSharedPreferences(
        "progression_lab_integrations",
        Context.MODE_PRIVATE,
    )
    private val healthClient by lazy { HealthConnectClient.getOrCreate(activity) }
    private val healthPermissionContract by lazy {
        PermissionController.createRequestPermissionResultContract()
    }

    private var pendingHealthPermissionResult: MethodChannel.Result? = null
    private var pendingFolderResult: MethodChannel.Result? = null
    private var pendingFileResult: MethodChannel.Result? = null
    private var pendingOAuthResult: MethodChannel.Result? = null
    private var expectedOAuthState: String? = null
    private var expectedOAuthRedirect: String? = null

    private val healthPermissions = setOf(
        HealthPermission.getReadPermission(ExerciseSessionRecord::class),
        HealthPermission.getWritePermission(ExerciseSessionRecord::class),
        HealthPermission.getReadPermission(WeightRecord::class),
        HealthPermission.getWritePermission(WeightRecord::class),
        HealthPermission.getReadPermission(BodyFatRecord::class),
        HealthPermission.getWritePermission(BodyFatRecord::class),
    )

    private val encryptedPreferences by lazy {
        val masterKey = MasterKey.Builder(activity)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            activity,
            "progression_lab_secure",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    init {
        MethodChannel(messenger, "progression_lab/health")
            .setMethodCallHandler(::handleHealth)
        MethodChannel(messenger, "progression_lab/cloud_sync")
            .setMethodCallHandler(::handleCloud)
        MethodChannel(messenger, "progression_lab/integrations")
            .setMethodCallHandler(::handleFileImport)
        MethodChannel(messenger, "progression_lab/oauth")
            .setMethodCallHandler(::handleOAuth)
        MethodChannel(messenger, "progression_lab/secure_storage")
            .setMethodCallHandler(::handleSecureStorage)
        MethodChannel(messenger, "progression_lab/integration_preferences")
            .setMethodCallHandler(::handleIntegrationPreferences)
        MethodChannel(messenger, "progression_lab/guide_state")
            .setMethodCallHandler(::handleGuideState)
    }

    fun dispose() {
        pendingHealthPermissionResult?.error("cancelled", "Activity closed.", null)
        pendingFolderResult?.error("cancelled", "Activity closed.", null)
        pendingFileResult?.error("cancelled", "Activity closed.", null)
        pendingOAuthResult?.error("cancelled", "Activity closed.", null)
        pendingHealthPermissionResult = null
        pendingFolderResult = null
        pendingFileResult = null
        pendingOAuthResult = null
        scope.cancel()
    }

    fun handleIntent(intent: Intent?): Boolean {
        val uri = intent?.data ?: return false
        val pending = pendingOAuthResult ?: return false
        val expectedRedirect = expectedOAuthRedirect ?: return false
        if (!uri.toString().startsWith(expectedRedirect)) return false

        pendingOAuthResult = null
        expectedOAuthRedirect = null
        val state = uri.getQueryParameter("state")
        val expected = expectedOAuthState
        expectedOAuthState = null
        if (expected != null && state != expected) {
            pending.error("oauth_state_mismatch", "OAuth state verification failed.", null)
            return true
        }
        pending.success(
            mapOf(
                "code" to uri.getQueryParameter("code"),
                "state" to state,
                "error" to uri.getQueryParameter("error"),
                "errorDescription" to uri.getQueryParameter("error_description"),
            )
        )
        return true
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            REQUEST_HEALTH_PERMISSIONS -> {
                val pending = pendingHealthPermissionResult ?: return false
                pendingHealthPermissionResult = null
                try {
                    val granted = healthPermissionContract.parseResult(resultCode, data)
                    pending.success(granted.containsAll(healthPermissions))
                } catch (error: Exception) {
                    pending.error("health_permission_failed", error.message, null)
                }
                return true
            }
            REQUEST_CLOUD_FOLDER -> {
                val pending = pendingFolderResult ?: return false
                pendingFolderResult = null
                val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
                if (uri == null) {
                    pending.success(null)
                    return true
                }
                val flags = data?.flags?.and(
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                ) ?: 0
                try {
                    activity.contentResolver.takePersistableUriPermission(uri, flags)
                } catch (_: SecurityException) {
                    // Some providers grant only session-scoped access.
                }
                preferences.edit().putString(KEY_CLOUD_TREE_URI, uri.toString()).apply()
                pending.success(folderStatus(uri))
                return true
            }
            REQUEST_WORKOUT_FILE -> {
                val pending = pendingFileResult ?: return false
                pendingFileResult = null
                val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
                if (uri == null) {
                    pending.success(null)
                    return true
                }
                try {
                    val bytes = activity.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                        ?: throw IllegalStateException("The selected file could not be read.")
                    pending.success(mapOf("name" to displayName(uri), "bytes" to bytes))
                } catch (error: Exception) {
                    pending.error("file_read_failed", error.message, null)
                }
                return true
            }
        }
        return false
    }

    private fun handleHealth(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> scope.launch {
                val sdkStatus = HealthConnectClient.getSdkStatus(activity)
                if (sdkStatus != HealthConnectClient.SDK_AVAILABLE) {
                    result.success(
                        mapOf(
                            "platform" to "healthConnect",
                            "available" to false,
                            "authorization" to "unavailable",
                            "message" to if (
                                sdkStatus ==
                                    HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED
                            ) {
                                "Health Connect needs an update."
                            } else {
                                "Health Connect is not available on this device."
                            },
                        )
                    )
                    return@launch
                }
                try {
                    val granted = healthClient.permissionController.getGrantedPermissions()
                    result.success(
                        mapOf(
                            "platform" to "healthConnect",
                            "available" to true,
                            "authorization" to if (granted.containsAll(healthPermissions)) {
                                "authorized"
                            } else {
                                "notDetermined"
                            },
                        )
                    )
                } catch (error: Exception) {
                    result.error("health_status_failed", error.message, null)
                }
            }
            "requestAuthorization" -> {
                if (pendingHealthPermissionResult != null) {
                    result.error("busy", "A Health Connect permission request is already open.", null)
                    return
                }
                pendingHealthPermissionResult = result
                try {
                    val intent = healthPermissionContract.createIntent(activity, healthPermissions)
                    activity.startActivityForResult(intent, REQUEST_HEALTH_PERMISSIONS)
                } catch (error: Exception) {
                    pendingHealthPermissionResult = null
                    result.error("health_permission_failed", error.message, null)
                }
            }
            "readWorkouts" -> scope.launch {
                try {
                    val start = Instant.parse(call.argument<String>("start"))
                    val end = Instant.parse(call.argument<String>("end"))
                    val response = healthClient.readRecords(
                        ReadRecordsRequest(
                            recordType = ExerciseSessionRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(start, end),
                            pageSize = 1000,
                        )
                    )
                    result.success(
                        response.records.map { record ->
                            mapOf(
                                "id" to record.metadata.id.ifBlank {
                                    "health-${record.startTime.toEpochMilli()}"
                                },
                                "platform" to "healthConnect",
                                "source" to record.metadata.dataOrigin.packageName,
                                "title" to (record.title ?: "Health Connect Workout"),
                                "sport" to exerciseTypeName(record.exerciseType),
                                "startedAt" to record.startTime.toString(),
                                "endedAt" to record.endTime.toString(),
                                "durationSeconds" to
                                    (record.endTime.epochSecond - record.startTime.epochSecond),
                                "notes" to (record.notes ?: ""),
                            )
                        }
                    )
                } catch (error: Exception) {
                    result.error("health_read_failed", error.message, null)
                }
            }
            "readBodyMetrics" -> scope.launch {
                try {
                    val start = Instant.parse(call.argument<String>("start"))
                    val end = Instant.parse(call.argument<String>("end"))
                    val filter = TimeRangeFilter.between(start, end)
                    val weights = healthClient.readRecords(
                        ReadRecordsRequest(
                            recordType = WeightRecord::class,
                            timeRangeFilter = filter,
                            pageSize = 1000,
                        )
                    ).records.map { record ->
                        mapOf(
                            "type" to "bodyWeight",
                            "value" to record.weight.inKilograms,
                            "unit" to "kg",
                            "recordedAt" to record.time.toString(),
                            "source" to record.metadata.dataOrigin.packageName,
                        )
                    }
                    val bodyFat = healthClient.readRecords(
                        ReadRecordsRequest(
                            recordType = BodyFatRecord::class,
                            timeRangeFilter = filter,
                            pageSize = 1000,
                        )
                    ).records.map { record ->
                        mapOf(
                            "type" to "bodyFatPercentage",
                            "value" to record.percentage.value,
                            "unit" to "%",
                            "recordedAt" to record.time.toString(),
                            "source" to record.metadata.dataOrigin.packageName,
                        )
                    }
                    result.success(weights + bodyFat)
                } catch (error: Exception) {
                    result.error("health_metric_read_failed", error.message, null)
                }
            }
            "writeWorkout" -> scope.launch {
                try {
                    val arguments = call.arguments as? Map<*, *>
                        ?: throw IllegalArgumentException("Workout arguments are missing.")
                    val start = Instant.parse(arguments["startedAt"] as String)
                    val end = Instant.parse(arguments["endedAt"] as String)
                    val externalId = arguments["externalId"] as? String
                        ?: UUID.randomUUID().toString()
                    val zone = ZoneId.systemDefault()
                    val record = ExerciseSessionRecord(
                        startTime = start,
                        startZoneOffset = zone.rules.getOffset(start),
                        endTime = end,
                        endZoneOffset = zone.rules.getOffset(end),
                        metadata = Metadata.manualEntry(
                            clientRecordId = externalId,
                            clientRecordVersion = 1,
                        ),
                        exerciseType = exerciseType(arguments["sport"] as? String),
                        title = arguments["title"] as? String,
                        notes = arguments["notes"] as? String,
                    )
                    healthClient.insertRecords(listOf(record))
                    result.success(true)
                } catch (error: Exception) {
                    result.error("health_write_failed", error.message, null)
                }
            }
            "writeBodyWeight" -> scope.launch {
                try {
                    val arguments = call.arguments as? Map<*, *>
                        ?: throw IllegalArgumentException("Weight arguments are missing.")
                    val time = Instant.parse(arguments["recordedAt"] as String)
                    val raw = (arguments["value"] as Number).toDouble()
                    val unit = arguments["unit"] as? String ?: "kg"
                    val kilograms = if (unit == "lb") raw * 0.45359237 else raw
                    val zoneOffset: ZoneOffset = ZoneId.systemDefault().rules.getOffset(time)
                    healthClient.insertRecords(
                        listOf(
                            WeightRecord(
                                time = time,
                                zoneOffset = zoneOffset,
                                weight = Mass.kilograms(kilograms),
                                metadata = Metadata.manualEntry(
                                    clientRecordId =
                                        "progression-lab-weight-${time.toEpochMilli()}",
                                    clientRecordVersion = 1,
                                ),
                            )
                        )
                    )
                    result.success(true)
                } catch (error: Exception) {
                    result.error("health_weight_write_failed", error.message, null)
                }
            }
            "writeBodyFat" -> scope.launch {
                try {
                    val arguments = call.arguments as? Map<*, *>
                        ?: throw IllegalArgumentException("Body-fat arguments are missing.")
                    val time = Instant.parse(arguments["recordedAt"] as String)
                    val raw = (arguments["value"] as Number).toDouble()
                    require(raw in 0.0..100.0) {
                        "Body-fat percentage must be between 0 and 100."
                    }
                    val zoneOffset: ZoneOffset = ZoneId.systemDefault().rules.getOffset(time)
                    healthClient.insertRecords(
                        listOf(
                            BodyFatRecord(
                                time = time,
                                zoneOffset = zoneOffset,
                                percentage = Percentage(raw),
                                metadata = Metadata.manualEntry(
                                    clientRecordId =
                                        "progression-lab-body-fat-${time.toEpochMilli()}",
                                    clientRecordVersion = 1,
                                ),
                            )
                        )
                    )
                    result.success(true)
                } catch (error: Exception) {
                    result.error("health_body_fat_write_failed", error.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun handleCloud(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> {
                val uri = cloudTreeUri()
                result.success(
                    if (uri == null) {
                        mapOf(
                            "configured" to false,
                            "automaticSyncEnabled" to preferences.getBoolean(
                                KEY_AUTOMATIC_SYNC,
                                false,
                            ),
                        )
                    } else {
                        folderStatus(uri) + mapOf(
                            "automaticSyncEnabled" to preferences.getBoolean(
                                KEY_AUTOMATIC_SYNC,
                                false,
                            ),
                            "lastSuccessfulSync" to preferences.getString(
                                KEY_LAST_SYNC,
                                null,
                            ),
                        )
                    }
                )
            }
            "chooseFolder" -> {
                if (pendingFolderResult != null) {
                    result.error("busy", "A folder picker is already open.", null)
                    return
                }
                pendingFolderResult = result
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                    addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
                    )
                    cloudTreeUri()?.let { putExtra("android.provider.extra.INITIAL_URI", it) }
                }
                activity.startActivityForResult(intent, REQUEST_CLOUD_FOLDER)
            }
            "disconnectFolder" -> {
                cloudTreeUri()?.let { uri ->
                    try {
                        activity.contentResolver.releasePersistableUriPermission(
                            uri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                        )
                    } catch (_: Exception) {
                    }
                }
                preferences.edit()
                    .remove(KEY_CLOUD_TREE_URI)
                    .putBoolean(KEY_AUTOMATIC_SYNC, false)
                    .apply()
                result.success(null)
            }
            "setAutomaticSyncEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") == true
                if (enabled && cloudTreeUri() == null) {
                    result.error("folder_required", "Choose a cloud backup folder first.", null)
                    return
                }
                preferences.edit().putBoolean(KEY_AUTOMATIC_SYNC, enabled).apply()
                result.success(null)
            }
            "listBackups" -> {
                try {
                    val directory = cloudDirectory()
                        ?: throw IllegalStateException("No cloud folder is configured.")
                    result.success(
                        directory.listFiles()
                            .filter { it.isFile && it.name?.endsWith(".plab") == true }
                            .map { file ->
                                mapOf(
                                    "name" to (file.name ?: "backup.plab"),
                                    "modifiedAt" to
                                        Instant.ofEpochMilli(file.lastModified()).toString(),
                                    "size" to file.length(),
                                    "token" to file.uri.toString(),
                                )
                            }
                    )
                } catch (error: Exception) {
                    result.error("cloud_list_failed", error.message, null)
                }
            }
            "writeBackup" -> {
                try {
                    val directory = cloudDirectory()
                        ?: throw IllegalStateException("No cloud folder is configured.")
                    val name = call.argument<String>("name") ?: "Progression-Lab.plab"
                    val bytes = call.argument<ByteArray>("bytes")
                        ?: throw IllegalArgumentException("Backup bytes are missing.")
                    directory.findFile(name)?.delete()
                    val file = directory.createFile("application/zip", name)
                        ?: throw IllegalStateException("The provider could not create the backup.")
                    activity.contentResolver.openOutputStream(file.uri, "w")?.use {
                        it.write(bytes)
                        it.flush()
                    } ?: throw IllegalStateException(
                        "The provider did not open the backup file."
                    )
                    val syncedAt = Instant.now().toString()
                    preferences.edit().putString(KEY_LAST_SYNC, syncedAt).apply()
                    result.success(
                        mapOf(
                            "name" to (file.name ?: name),
                            "modifiedAt" to syncedAt,
                            "createdAt" to call.argument<String>("createdAt"),
                            "schemaVersion" to call.argument<Int>("schemaVersion"),
                            "size" to bytes.size,
                            "token" to file.uri.toString(),
                        )
                    )
                } catch (error: Exception) {
                    result.error("cloud_write_failed", error.message, null)
                }
            }
            "readBackup" -> {
                try {
                    val token = call.argument<String>("token")
                        ?: throw IllegalArgumentException("Backup token is missing.")
                    val bytes = activity.contentResolver.openInputStream(Uri.parse(token))?.use {
                        it.readBytes()
                    } ?: throw IllegalStateException("The backup could not be read.")
                    result.success(bytes)
                } catch (error: Exception) {
                    result.error("cloud_read_failed", error.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun handleFileImport(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickWorkoutFile" -> {
                if (pendingFileResult != null) {
                    result.error("busy", "A file picker is already open.", null)
                    return
                }
                pendingFileResult = result
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                    putExtra(
                        Intent.EXTRA_MIME_TYPES,
                        arrayOf(
                            "application/octet-stream",
                            "application/vnd.ant.fit",
                            "application/xml",
                            "text/xml",
                            "application/gpx+xml",
                        ),
                    )
                }
                activity.startActivityForResult(intent, REQUEST_WORKOUT_FILE)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleOAuth(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "authorize" -> {
                if (pendingOAuthResult != null) {
                    result.error("busy", "An authorization flow is already open.", null)
                    return
                }
                val url = call.argument<String>("url")
                val redirectUri = call.argument<String>("redirectUri")
                if (url == null || redirectUri == null) {
                    result.error("invalid_arguments", "Authorization URL is missing.", null)
                    return
                }
                pendingOAuthResult = result
                expectedOAuthState = call.argument<String>("state")
                expectedOAuthRedirect = redirectUri
                activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            }
            else -> result.notImplemented()
        }
    }

    private fun handleSecureStorage(call: MethodCall, result: MethodChannel.Result) {
        try {
            val key = call.argument<String>("key")
                ?: throw IllegalArgumentException("Secure-storage key is missing.")
            when (call.method) {
                "read" -> result.success(encryptedPreferences.getString(key, null))
                "write" -> {
                    val value = call.argument<String>("value")
                        ?: throw IllegalArgumentException("Secure-storage value is missing.")
                    encryptedPreferences.edit().putString(key, value).apply()
                    result.success(null)
                }
                "delete" -> {
                    encryptedPreferences.edit().remove(key).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("secure_storage_failed", error.message, null)
        }
    }

    private fun handleIntegrationPreferences(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "read" -> result.success(
                preferences.getString(KEY_INTEGRATION_PREFERENCES, null)
            )
            "write" -> {
                val value = call.arguments as? String ?: "{}"
                preferences.edit().putString(KEY_INTEGRATION_PREFERENCES, value).apply()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleGuideState(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "read" -> {
                val seen = preferences.getStringSet(KEY_GUIDES_SEEN, emptySet())
                    ?: emptySet()
                result.success(
                    mapOf(
                        "tipsEnabled" to preferences.getBoolean(KEY_GUIDES_ENABLED, true),
                        "seen" to seen.toList(),
                    )
                )
            }
            "write" -> {
                val arguments = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                val seen = (arguments["seen"] as? List<*>)
                    ?.mapNotNull { it as? String }
                    ?.toSet()
                    ?: emptySet()
                preferences.edit()
                    .putBoolean(KEY_GUIDES_ENABLED, arguments["tipsEnabled"] != false)
                    .putStringSet(KEY_GUIDES_SEEN, seen)
                    .apply()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun cloudTreeUri(): Uri? =
        preferences.getString(KEY_CLOUD_TREE_URI, null)?.let(Uri::parse)

    private fun cloudDirectory(): DocumentFile? = cloudTreeUri()?.let { uri ->
        DocumentFile.fromTreeUri(activity, uri)
    }

    private fun folderStatus(uri: Uri): Map<String, Any?> {
        val directory = DocumentFile.fromTreeUri(activity, uri)
        val authority = uri.authority.orEmpty().lowercase()
        val provider = when {
            authority.contains("google") -> "googleDrive"
            authority.contains("onedrive") || authority.contains("microsoft") -> "oneDrive"
            authority.contains("dropbox") -> "dropbox"
            else -> "filesProvider"
        }
        return mapOf(
            "configured" to true,
            "provider" to provider,
            "displayName" to (directory?.name ?: "Selected folder"),
            "locationToken" to uri.toString(),
        )
    }

    private fun displayName(uri: Uri): String {
        activity.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) return cursor.getString(index)
        }
        return uri.lastPathSegment ?: "workout.fit"
    }

    private fun exerciseType(sport: String?): Int {
        val normalized = sport.orEmpty().lowercase()
        return when {
            normalized.contains("run") -> ExerciseSessionRecord.EXERCISE_TYPE_RUNNING
            normalized.contains("walk") -> ExerciseSessionRecord.EXERCISE_TYPE_WALKING
            normalized.contains("cycle") || normalized.contains("bike") ->
                ExerciseSessionRecord.EXERCISE_TYPE_BIKING
            normalized.contains("swim") ->
                ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL
            normalized.contains("row") -> ExerciseSessionRecord.EXERCISE_TYPE_ROWING
            normalized.contains("strength") || normalized.contains("weight") ->
                ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING
            normalized.contains("stretch") || normalized.contains("mobility") ->
                ExerciseSessionRecord.EXERCISE_TYPE_STRETCHING
            else -> ExerciseSessionRecord.EXERCISE_TYPE_OTHER_WORKOUT
        }
    }

    private fun exerciseTypeName(type: Int): String = when (type) {
        ExerciseSessionRecord.EXERCISE_TYPE_RUNNING -> "running"
        ExerciseSessionRecord.EXERCISE_TYPE_WALKING -> "walking"
        ExerciseSessionRecord.EXERCISE_TYPE_BIKING -> "cycling"
        ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL,
        ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_OPEN_WATER -> "swimming"
        ExerciseSessionRecord.EXERCISE_TYPE_ROWING,
        ExerciseSessionRecord.EXERCISE_TYPE_ROWING_MACHINE -> "rowing"
        ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING,
        ExerciseSessionRecord.EXERCISE_TYPE_WEIGHTLIFTING -> "strength training"
        ExerciseSessionRecord.EXERCISE_TYPE_STRETCHING -> "mobility"
        else -> "other"
    }

    companion object {
        private const val REQUEST_HEALTH_PERMISSIONS = 9041
        private const val REQUEST_CLOUD_FOLDER = 9042
        private const val REQUEST_WORKOUT_FILE = 9043
        private const val KEY_CLOUD_TREE_URI = "cloud_tree_uri"
        private const val KEY_AUTOMATIC_SYNC = "cloud_automatic_sync"
        private const val KEY_LAST_SYNC = "cloud_last_sync"
        private const val KEY_INTEGRATION_PREFERENCES = "integration_preferences"
        private const val KEY_GUIDES_ENABLED = "guide_tips_enabled"
        private const val KEY_GUIDES_SEEN = "guide_tips_seen"
    }
}

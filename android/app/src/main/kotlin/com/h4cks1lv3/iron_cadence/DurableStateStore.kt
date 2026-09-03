package com.h4cks1lv3.iron_cadence

import android.content.Context
import android.util.AtomicFile
import org.json.JSONObject
import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets

/**
 * Crash-safe storage for the complete Progression Lab state document.
 *
 * SharedPreferences.apply() reports success before the bytes are durable. This
 * store writes through AtomicFile, flushes the stream, and synchronizes the file
 * descriptor before the atomic commit is completed. The former preference value
 * is kept as a one-time migration copy and is never deleted automatically.
 */
class DurableStateStore(private val context: Context) {
    private val directory = File(context.filesDir, STATE_DIRECTORY).apply {
        if (!exists() && !mkdirs()) {
            throw IllegalStateException("Progression Lab could not create its state directory.")
        }
    }
    private val atomicFile = AtomicFile(File(directory, STATE_FILE))
    private val legacyPreferences = context.getSharedPreferences(LEGACY_PREFERENCES, Context.MODE_PRIVATE)

    @Synchronized
    fun read(): String? {
        val raw = if (hasAtomicState()) {
            readAtomic()
        } else {
            migrateLegacyState()
        }
        if (raw == null) return null
        validate(raw)
        return raw
    }

    @Synchronized
    fun write(raw: String) {
        validate(raw)
        writeAtomic(raw)
    }

    @Synchronized
    fun quarantine(): String? {
        val base = atomicFile.baseFile
        val backup = File("${base.path}.bak")
        val source = when {
            base.exists() -> base
            backup.exists() -> backup
            else -> return null
        }
        val destination = File(
            directory,
            "quarantine-${System.currentTimeMillis()}.json",
        )
        writeStandaloneDurably(destination, source.readBytes())
        atomicFile.delete()
        return destination.absolutePath
    }

    @Synchronized
    fun status(): Map<String, Any> = mapOf(
        "hasAtomicState" to hasAtomicState(),
        "hasLegacyState" to !legacyPreferences.getString(LEGACY_STATE_KEY, null).isNullOrBlank(),
        "statePath" to atomicFile.baseFile.absolutePath,
    )

    private fun hasAtomicState(): Boolean {
        val base = atomicFile.baseFile
        return base.exists() || File("${base.path}.bak").exists()
    }

    private fun readAtomic(): String {
        try {
            return atomicFile.openRead().bufferedReader(StandardCharsets.UTF_8).use { it.readText() }
        } catch (error: FileNotFoundException) {
            throw IllegalStateException("The saved state disappeared before it could be read.", error)
        }
    }

    private fun writeAtomic(raw: String) {
        var stream: FileOutputStream? = null
        try {
            stream = atomicFile.startWrite()
            stream.write(raw.toByteArray(StandardCharsets.UTF_8))
            stream.flush()
            stream.fd.sync()
            atomicFile.finishWrite(stream)
            stream = null
        } catch (error: Throwable) {
            stream?.let { atomicFile.failWrite(it) }
            throw IllegalStateException("Progression Lab could not durably save its data.", error)
        }
    }

    private fun migrateLegacyState(): String? {
        val legacy = legacyPreferences.getString(LEGACY_STATE_KEY, null)
            ?.takeIf { it.isNotBlank() }
            ?: return null
        validate(legacy)

        val migrationCopy = File(directory, LEGACY_COPY_FILE)
        if (!migrationCopy.exists()) {
            writeStandaloneDurably(migrationCopy, legacy.toByteArray(StandardCharsets.UTF_8))
        }
        writeAtomic(legacy)
        legacyPreferences.edit().putBoolean(LEGACY_MIGRATED_KEY, true).commit()
        return legacy
    }

    private fun validate(raw: String) {
        if (raw.isBlank()) {
            throw IllegalStateException("The saved state is empty.")
        }
        try {
            JSONObject(raw)
        } catch (error: Throwable) {
            throw IllegalStateException("The saved state is not valid JSON.", error)
        }
    }

    private fun writeStandaloneDurably(destination: File, bytes: ByteArray) {
        val temporary = File(destination.parentFile, ".${destination.name}.tmp")
        try {
            FileOutputStream(temporary).use { stream ->
                stream.write(bytes)
                stream.flush()
                stream.fd.sync()
            }
            if (destination.exists() && !destination.delete()) {
                throw IllegalStateException("Could not replace the migration backup.")
            }
            if (!temporary.renameTo(destination)) {
                FileOutputStream(destination).use { stream ->
                    stream.write(bytes)
                    stream.flush()
                    stream.fd.sync()
                }
                temporary.delete()
            }
        } catch (error: Throwable) {
            temporary.delete()
            throw IllegalStateException("Could not preserve the legacy state before migration.", error)
        }
    }

    companion object {
        private const val STATE_DIRECTORY = "progression_lab_state"
        private const val STATE_FILE = "state.json"
        private const val LEGACY_COPY_FILE = "legacy-shared-preferences-state.json"
        private const val LEGACY_PREFERENCES = "iron_cadence"
        private const val LEGACY_STATE_KEY = "state"
        private const val LEGACY_MIGRATED_KEY = "atomic_state_migrated"
    }
}

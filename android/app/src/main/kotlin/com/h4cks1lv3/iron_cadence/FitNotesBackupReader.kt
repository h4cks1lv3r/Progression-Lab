package com.h4cks1lv3.iron_cadence

import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import java.io.File
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets
import java.util.Locale

/** Converts a native FitNotes .fitnotes SQLite backup to Progression Lab CSV. */
object FitNotesBackupReader {
    fun convert(context: Context, bytes: ByteArray, originalName: String): Map<String, Any> {
        require(bytes.size >= SQLITE_HEADER.length) { "The FitNotes backup is too small." }
        val header = String(bytes, 0, SQLITE_HEADER.length, StandardCharsets.US_ASCII)
        require(header == SQLITE_HEADER) { "The selected .fitnotes file is not a SQLite database." }

        val temporary = File.createTempFile("progression-fitnotes-", ".db", context.cacheDir)
        try {
            FileOutputStream(temporary).use { stream ->
                stream.write(bytes)
                stream.flush()
                stream.fd.sync()
            }
            val csv = SQLiteDatabase.openDatabase(
                temporary.absolutePath,
                null,
                SQLiteDatabase.OPEN_READONLY or SQLiteDatabase.NO_LOCALIZED_COLLATORS,
            ).use { database ->
                database.rawQuery("PRAGMA query_only=ON", null).use { it.moveToFirst() }
                verifyDatabase(database)
                buildCsv(database)
            }
            val outputName = originalName
                .replace(Regex("(?i)\\.fitnotes$"), "")
                .ifBlank { "FitNotes-Backup" } + "-converted.csv"
            return mapOf(
                "name" to outputName,
                "bytes" to csv.toByteArray(StandardCharsets.UTF_8),
                "mimeType" to "text/csv",
            )
        } finally {
            temporary.delete()
            File("${temporary.path}-journal").delete()
            File("${temporary.path}-wal").delete()
            File("${temporary.path}-shm").delete()
        }
    }

    private fun verifyDatabase(database: SQLiteDatabase) {
        require(tableExists(database, "training_log")) {
            "The FitNotes backup does not contain training_log."
        }
        require(tableExists(database, "exercise")) {
            "The FitNotes backup does not contain exercise."
        }
        database.rawQuery("PRAGMA quick_check(1)", null).use { cursor ->
            require(cursor.moveToFirst() && cursor.getString(0).equals("ok", ignoreCase = true)) {
                "The FitNotes backup failed SQLite integrity validation."
            }
        }
    }

    private fun buildCsv(database: SQLiteDatabase): String {
        val exerciseNames = loadExerciseNames(database)
        val comments = loadSetComments(database)
        val workoutComments = loadWorkoutComments(database)
        val groups = loadWorkoutGroups(database)
        val columns = tableColumns(database, "training_log")
        val required = setOf("_id", "exercise_id", "date")
        require(columns.containsAll(required)) {
            "The FitNotes training_log schema is not supported."
        }

        val selected = listOf(
            "_id",
            "exercise_id",
            "date",
            "metric_weight",
            "reps",
            "distance",
            "duration_seconds",
            "time",
            "workout_group_id",
            "is_personal_record",
        ).filter(columns::contains)

        val output = StringBuilder()
        output.append(
            "Date,Workout Name,Exercise,Set Order,Weight (kg),Reps,Notes," +
                "Workout Notes,Duration Seconds,Distance,Distance Unit,Kind,Source ID\r\n",
        )
        val setCounts = mutableMapOf<String, Int>()
        var importedRows = 0

        database.query(
            "training_log",
            selected.toTypedArray(),
            null,
            null,
            null,
            null,
            "date ASC, _id ASC",
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val logId = cursor.longOrNull("_id") ?: continue
                val exerciseId = cursor.longOrNull("exercise_id") ?: continue
                val exercise = exerciseNames[exerciseId]?.trim().orEmpty()
                val sourceDate = cursor.stringOrNull("date")?.trim().orEmpty()
                if (exercise.isEmpty() || sourceDate.isEmpty()) continue

                val reps = cursor.intOrZero("reps").coerceAtLeast(0)
                val duration = cursor.intOrZero(
                    if (columns.contains("duration_seconds")) "duration_seconds" else "time",
                ).coerceAtLeast(0)
                val distance = cursor.doubleOrZero("distance").coerceAtLeast(0.0)
                if (reps == 0 && duration == 0 && distance == 0.0) continue

                val groupId = cursor.longOrNull("workout_group_id")
                val group = groupId?.let(groups.byId::get) ?: groups.forDate(sourceDate)
                val day = sourceDate.take(10)
                val workoutName = group?.name?.takeIf(String::isNotBlank)
                    ?: "FitNotes Workout $day"
                val groupToken = group?.id?.toString()
                    ?: group?.date?.takeIf(String::isNotBlank)
                    ?: day
                val sourceId = "fitnotes:$groupToken"
                val countKey = "$sourceId|${exercise.lowercase(Locale.ROOT)}"
                val setOrder = (setCounts[countKey] ?: 0) + 1
                setCounts[countKey] = setOrder

                val noteParts = mutableListOf<String>()
                comments[logId]?.takeIf(String::isNotBlank)?.let(noteParts::add)
                if (cursor.intOrZero("is_personal_record") == 1) {
                    noteParts.add("FitNotes personal record")
                }
                val weight = cursor.doubleOrZero("metric_weight").coerceAtLeast(0.0)
                val row = listOf(
                    sourceDate,
                    workoutName,
                    exercise,
                    setOrder.toString(),
                    decimal(weight),
                    reps.toString(),
                    noteParts.joinToString(" · "),
                    workoutComments[sourceDate] ?: workoutComments[day] ?: "",
                    if (duration > 0) duration.toString() else "",
                    if (distance > 0) decimal(distance) else "",
                    if (distance > 0) "m" else "",
                    "workout",
                    sourceId,
                )
                output.append(row.joinToString(",", postfix = "\r\n", transform = ::csvCell))
                importedRows++
            }
        }
        require(importedRows > 0) {
            "The FitNotes backup contains no importable workout sets."
        }
        return output.toString()
    }

    private fun loadExerciseNames(database: SQLiteDatabase): Map<Long, String> {
        val output = mutableMapOf<Long, String>()
        database.query("exercise", arrayOf("_id", "name"), null, null, null, null, null)
            .use { cursor ->
                while (cursor.moveToNext()) {
                    val id = cursor.longOrNull("_id") ?: continue
                    output[id] = cursor.stringOrNull("name").orEmpty()
                }
            }
        return output
    }

    private fun loadSetComments(database: SQLiteDatabase): Map<Long, String> {
        if (!tableExists(database, "Comment")) return emptyMap()
        val columns = tableColumns(database, "Comment")
        if (!columns.containsAll(setOf("owner_id", "comment"))) return emptyMap()
        val output = mutableMapOf<Long, String>()
        val selection = if (columns.contains("owner_type_id")) "owner_type_id = ?" else null
        val arguments = if (selection == null) null else arrayOf("1")
        database.query(
            "Comment",
            arrayOf("owner_id", "comment"),
            selection,
            arguments,
            null,
            null,
            "_id ASC",
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val ownerId = cursor.longOrNull("owner_id") ?: continue
                val text = cursor.stringOrNull("comment")?.trim().orEmpty()
                if (text.isNotEmpty()) output[ownerId] = text
            }
        }
        return output
    }

    private fun loadWorkoutComments(database: SQLiteDatabase): Map<String, String> {
        if (!tableExists(database, "WorkoutComment")) return emptyMap()
        val columns = tableColumns(database, "WorkoutComment")
        if (!columns.containsAll(setOf("date", "comment"))) return emptyMap()
        val output = mutableMapOf<String, String>()
        database.query(
            "WorkoutComment",
            arrayOf("date", "comment"),
            null,
            null,
            null,
            null,
            "_id ASC",
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val date = cursor.stringOrNull("date")?.trim().orEmpty()
                val comment = cursor.stringOrNull("comment")?.trim().orEmpty()
                if (date.isNotEmpty() && comment.isNotEmpty()) output[date] = comment
            }
        }
        return output
    }

    private fun loadWorkoutGroups(database: SQLiteDatabase): WorkoutGroups {
        if (!tableExists(database, "WorkoutGroup")) return WorkoutGroups(emptyMap(), emptyList())
        val columns = tableColumns(database, "WorkoutGroup")
        if (!columns.contains("_id")) return WorkoutGroups(emptyMap(), emptyList())
        val selected = listOf("_id", "name", "date").filter(columns::contains)
        val values = mutableListOf<WorkoutGroupValue>()
        database.query(
            "WorkoutGroup",
            selected.toTypedArray(),
            null,
            null,
            null,
            null,
            "_id ASC",
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.longOrNull("_id") ?: continue
                values.add(
                    WorkoutGroupValue(
                        id = id,
                        name = cursor.stringOrNull("name").orEmpty(),
                        date = cursor.stringOrNull("date").orEmpty(),
                    ),
                )
            }
        }
        return WorkoutGroups(values.associateBy(WorkoutGroupValue::id), values)
    }

    private fun tableExists(database: SQLiteDatabase, table: String): Boolean =
        database.rawQuery(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND lower(name)=lower(?) LIMIT 1",
            arrayOf(table),
        ).use(Cursor::moveToFirst)

    private fun tableColumns(database: SQLiteDatabase, table: String): Set<String> =
        database.rawQuery("PRAGMA table_info(\"${table.replace("\"", "\"\"")}\")", null)
            .use { cursor ->
                buildSet {
                    val index = cursor.getColumnIndex("name")
                    while (cursor.moveToNext()) {
                        if (index >= 0) add(cursor.getString(index))
                    }
                }
            }

    private fun Cursor.stringOrNull(column: String): String? {
        val index = getColumnIndex(column)
        return if (index < 0 || isNull(index)) null else getString(index)
    }

    private fun Cursor.longOrNull(column: String): Long? {
        val index = getColumnIndex(column)
        return if (index < 0 || isNull(index)) null else getLong(index)
    }

    private fun Cursor.intOrZero(column: String): Int {
        val index = getColumnIndex(column)
        return if (index < 0 || isNull(index)) 0 else getInt(index)
    }

    private fun Cursor.doubleOrZero(column: String): Double {
        val index = getColumnIndex(column)
        return if (index < 0 || isNull(index)) 0.0 else getDouble(index)
    }

    private fun decimal(value: Double): String {
        if (!value.isFinite()) return "0"
        val raw = String.format(Locale.US, "%.6f", value)
        return raw.trimEnd('0').trimEnd('.').ifEmpty { "0" }
    }

    private fun csvCell(value: String): String {
        val escaped = value.replace("\"", "\"\"")
        return if (value.any { it == ',' || it == '\"' || it == '\r' || it == '\n' }) {
            "\"$escaped\""
        } else {
            value
        }
    }

    private data class WorkoutGroupValue(
        val id: Long,
        val name: String,
        val date: String,
    )

    private data class WorkoutGroups(
        val byId: Map<Long, WorkoutGroupValue>,
        val values: List<WorkoutGroupValue>,
    ) {
        fun forDate(sourceDate: String): WorkoutGroupValue? {
            val day = sourceDate.take(10)
            return values.lastOrNull { value ->
                value.date == sourceDate || value.date.take(10) == day
            }
        }
    }

    private const val SQLITE_HEADER = "SQLite format 3\u0000"
}

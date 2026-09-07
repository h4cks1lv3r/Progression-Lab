package com.h4cks1lv3.iron_cadence

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.changes.DeletionChange
import androidx.health.connect.client.changes.UpsertionChange
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.ChangesTokenRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Instant
import java.time.ZoneId

object BodyHealthReader {
    private fun recordType(type: String) = when(type) {
        "bodyWeight" -> WeightRecord::class
        "height" -> HeightRecord::class
        "bodyFatPercentage" -> BodyFatRecord::class
        else -> throw IllegalArgumentException("Unsupported body measurement.")
    }
    fun row(record: Record, ownPackage: String): Map<String, Any>? {
        if(record.metadata.dataOrigin.packageName == ownPackage) return null
        val (type, value, unit) = when(record) {
            is WeightRecord -> Triple("bodyWeight", record.weight.inKilograms, "kg")
            is HeightRecord -> Triple("height", record.height.inMeters * 100, "cm")
            is BodyFatRecord -> Triple("bodyFatPercentage", record.percentage.value, "%")
            else -> return null
        }
        val (time, offset) = when(record) {
            is WeightRecord -> record.time to record.zoneOffset
            is HeightRecord -> record.time to record.zoneOffset
            is BodyFatRecord -> record.time to record.zoneOffset
            else -> return null
        }
        return mapOf("type" to type, "value" to value, "unit" to unit,
            "recordedAt" to time.toString(),
            "localDate" to time.atOffset(offset ?: ZoneId.systemDefault().rules.getOffset(time)).toLocalDate().toString(),
            "source" to record.metadata.dataOrigin.packageName, "recordId" to record.metadata.id,
            "revision" to record.metadata.lastModifiedTime.toEpochMilli(),
            "method" to (record.metadata.device?.model ?: "Health Connect • method unspecified"))
    }
    suspend fun read(client: HealthConnectClient, ownPackage: String, types: List<String>, start: Instant, end: Instant): List<Map<String, Any>> {
        val rows = mutableListOf<Map<String, Any>>()
        for(type in types.distinct()) {
            var token: String? = null
            do {
                val page = client.readRecords(ReadRecordsRequest(recordType = recordType(type), timeRangeFilter = TimeRangeFilter.between(start, end), pageSize = 1000, pageToken = token))
                page.records.mapNotNullTo(rows) { row(it, ownPackage) }
                token = page.pageToken
            } while(!token.isNullOrEmpty())
        }
        return rows
    }
    suspend fun sync(client: HealthConnectClient, ownPackage: String, types: List<String>, tokens: Map<String, String>, start: Instant, end: Instant): Map<String, Any> {
        val rows = mutableMapOf<String, Map<String, Any>>()
        val deleted = mutableSetOf<String>()
        val nextTokens = mutableMapOf<String, String>()
        val refreshed = mutableListOf<String>()
        var expired = false
        for(type in types.distinct()) {
            var token = tokens[type]
            if(token != null && client.getChanges(token).changesTokenExpired) { token = null; expired = true }
            if(token == null) {
                // Get the token before the snapshot so concurrent edits are replayed.
                token = client.getChangesToken(ChangesTokenRequest(recordTypes = setOf(recordType(type))))
                for(value in read(client, ownPackage, listOf(type), start, end)) rows[value["recordId"] as String] = value
                refreshed.add(type)
            }
            do {
                val page = client.getChanges(token!!)
                check(!page.changesTokenExpired) { "Health Connect sync expired. Try again." }
                for(change in page.changes) when(change) {
                    is UpsertionChange -> row(change.record, ownPackage)?.let { value ->
                        val id = value["recordId"] as String
                        rows[id] = value; deleted.remove(id)
                    }
                    is DeletionChange -> { rows.remove(change.recordId); deleted.add(change.recordId) }
                }
                token = page.nextChangesToken
            } while(page.hasMore)
            nextTokens[type] = token!!
        }
        return mapOf("records" to rows.values.toList(), "deletedIds" to deleted.toList(), "tokens" to nextTokens, "refreshedTypes" to refreshed, "expired" to expired)
    }
}

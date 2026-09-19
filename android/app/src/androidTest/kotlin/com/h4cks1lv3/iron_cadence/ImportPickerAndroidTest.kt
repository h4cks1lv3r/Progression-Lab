package com.h4cks1lv3.iron_cadence

import android.app.Activity
import android.app.Instrumentation
import android.content.ClipDescription
import android.content.Intent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Exercise the intents emitted by both production import entry points, not
 * just the picker helper. Simulated cancellation also checks pending callbacks. */
@RunWith(AndroidJUnit4::class)
class ImportPickerAndroidTest {
    @Test fun providerLabelsDoNotDisableImportsAndCancellationAllowsRetry() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val activity = instrumentation.startActivitySync(
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ) as MainActivity
        instrumentation.waitForIdleSync()
        val opened = Collections.synchronizedList(mutableListOf<Intent>())
        val monitor = object : Instrumentation.ActivityMonitor() {
            override fun onStartActivity(intent: Intent): Instrumentation.ActivityResult? {
                if (intent.action != Intent.ACTION_OPEN_DOCUMENT) return null
                opened.add(Intent(intent))
                return Instrumentation.ActivityResult(Activity.RESULT_CANCELED, null)
            }
        }
        instrumentation.addMonitor(monitor)
        try {
            val dataImport = MainActivity::class.java.getDeclaredMethod(
                "handleDataPortabilityCall", MethodCall::class.java, MethodChannel.Result::class.java
            ).apply { isAccessible = true }
            val bridge = MainActivity::class.java.getDeclaredField("integrationBridge")
                .apply { isAccessible = true }.get(activity)!!
            val activityImport = bridge.javaClass.getDeclaredMethod(
                "handleFileImport", MethodCall::class.java, MethodChannel.Result::class.java
            ).apply { isAccessible = true }

            // Repeat each call: a dismissed picker must not leave the next one busy.
            repeat(2) {
                val dataResult = PickerResult()
                instrumentation.runOnMainSync {
                    dataImport.invoke(activity, MethodCall("pickFile", mapOf(
                        "extensions" to listOf("plab", "csv", "tsv", "json", "txt", "zip", "fitnotes")
                    )), dataResult)
                }
                dataResult.assertCancelled()
                val activityResult = PickerResult()
                instrumentation.runOnMainSync {
                    activityImport.invoke(bridge, MethodCall("pickWorkoutFile", null), activityResult)
                }
                activityResult.assertCancelled()
            }

            assertEquals(4, opened.size)
            for (intent in opened) {
                assertTrue(intent.hasCategory(Intent.CATEGORY_OPENABLE))
                val requested = intent.getStringArrayExtra(Intent.EXTRA_MIME_TYPES)
                    ?: arrayOf(requireNotNull(intent.type))
                // Android providers use both standard and provider-specific labels
                // for the same valid file. The old allowlists rejected these cases.
                for (reported in listOf(
                    "text/csv", "application/vnd.ms-excel", "application/x-csv",
                    "text/plain", "application/json", "application/x-zip-compressed",
                    "application/x-plab", "application/x-fitnotes", "application/octet-stream",
                    "application/vnd.ant.fit", "application/vnd.garmin.tcx+xml", "application/gpx+xml"
                )) {
                    assertTrue("Picker disabled provider type $reported",
                        requested.any { ClipDescription.compareMimeTypes(reported, it) })
                }
            }
        } finally {
            instrumentation.removeMonitor(monitor)
            instrumentation.runOnMainSync { activity.finish() }
        }
    }

    private class PickerResult : MethodChannel.Result {
        private val completed = CountDownLatch(1)
        private var value: Any? = null
        private var error: String? = null
        override fun success(result: Any?) { value = result; completed.countDown() }
        override fun error(code: String, message: String?, details: Any?) {
            error = "$code: $message"; completed.countDown()
        }
        override fun notImplemented() { error = "Not implemented"; completed.countDown() }
        fun assertCancelled() {
            assertTrue("Picker did not return cancellation", completed.await(10, TimeUnit.SECONDS))
            assertNull(error)
            assertNull(value)
        }
    }
}

package com.h4cks1lv3.iron_cadence

import android.app.Activity
import android.graphics.Typeface
import android.os.Bundle
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import kotlin.math.roundToInt

class PermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val padding = (24 * resources.displayMetrics.density).roundToInt()
        val sectionGap = (18 * resources.displayMetrics.density).roundToInt()
        val paragraphGap = (10 * resources.displayMetrics.density).roundToInt()

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(padding, padding, padding, padding)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
        }

        content.addView(TextView(this).apply {
            text = "Progression Lab and Health Connect"
            textSize = 26f
            setTypeface(typeface, Typeface.BOLD)
        })
        content.addView(TextView(this).apply {
            text = "How requested health permissions are used"
            textSize = 16f
            alpha = 0.72f
            setPadding(0, paragraphGap, 0, sectionGap)
        })

        addSection(
            content,
            "Permission timing",
            "Progression Lab requests Health Connect access only after you select Review Health Permissions. You can grant or deny each requested data type.",
            paragraphGap,
            sectionGap,
        )
        addSection(
            content,
            "Workout summaries",
            "With permission, Progression Lab can read and write workout title, activity type, start and end time, duration, distance, and energy when those values are available. Detailed sets, loads, substitutions, and notes remain in Progression Lab.",
            paragraphGap,
            sectionGap,
        )
        addSection(
            content,
            "Body metrics",
            "With permission, Progression Lab can read and write body weight and body-fat percentage. Supplement, meal, hydration, sleep, stress, soreness, illness, and workout-response records are not written to Health Connect.",
            paragraphGap,
            sectionGap,
        )
        addSection(
            content,
            "Control and storage",
            "You can change Health Connect access in Android settings at any time. Cloud backup is separate: it remains off until you choose a document-provider folder and enable automatic sync.",
            paragraphGap,
            sectionGap,
        )

        content.addView(Button(this).apply {
            text = "Close"
            setOnClickListener { finish() }
            setPadding(0, paragraphGap, 0, paragraphGap)
        })

        setContentView(ScrollView(this).apply { addView(content) })
    }

    private fun addSection(
        parent: LinearLayout,
        heading: String,
        body: String,
        paragraphGap: Int,
        sectionGap: Int,
    ) {
        parent.addView(TextView(this).apply {
            text = heading
            textSize = 18f
            setTypeface(typeface, Typeface.BOLD)
        })
        parent.addView(TextView(this).apply {
            text = body
            textSize = 15f
            setLineSpacing(0f, 1.25f)
            setPadding(0, paragraphGap, 0, sectionGap)
        })
    }
}

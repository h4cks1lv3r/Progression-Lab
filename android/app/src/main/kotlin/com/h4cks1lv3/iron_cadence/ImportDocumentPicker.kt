package com.h4cks1lv3.iron_cadence

import android.content.Intent

/** Providers do not agree on MIME labels for CSV, custom backups, and workout
 * exports. An EXTRA_MIME_TYPES allowlist disables valid files in DocumentsUI,
 * even when the base intent requests all types. */
internal object ImportDocumentPicker {
    fun createIntent(): Intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
        addCategory(Intent.CATEGORY_OPENABLE)
        // Let users select a readable document. The import controller checks
        // its extension and contents and presents a preview before any write.
        type = "*/*"
    }
}

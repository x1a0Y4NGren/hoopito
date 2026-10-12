package io.github.x1a0y4ngren.hooptrace

import android.provider.DocumentsContract

/** Ownership rules for files that the automatic-backup retention may remove. */
internal object AutomaticBackupFilePolicy {
    private const val JSON_MIME_TYPE = "application/json"
    private val automaticBackupPattern = Regex("^hoop(?:trace|ito)-auto-.+\\.json$")

    fun isAutomaticBackupFile(fileName: String): Boolean {
        if (fileName.contains('/') || fileName.contains('\\')) return false
        return automaticBackupPattern.matches(fileName)
    }

    /**
     * SAF providers can return a directory or an unrelated same-named file.
     * An exact MIME match is intentionally required; missing/unknown MIME is
     * treated as not owned so retention fails closed.
     */
    fun isOwnedDocument(fileName: String, mimeType: String?): Boolean {
        return isAutomaticBackupFile(fileName) &&
            mimeType != null &&
            mimeType != DocumentsContract.Document.MIME_TYPE_DIR &&
            mimeType == JSON_MIME_TYPE
    }
}

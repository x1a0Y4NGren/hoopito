package io.github.x1a0y4ngren.hooptrace

import android.content.ContentResolver
import android.net.Uri
import android.provider.DocumentsContract
import java.io.IOException

/** SAF-only storage operations kept separate from the Flutter activity shell. */
internal class AutomaticBackupStorageDelegate(
    private val contentResolver: ContentResolver,
) {
    fun directoryExists(treeUri: Uri): Boolean {
        if (!isTreeUri(treeUri)) return false
        val hasWritePermission = contentResolver.persistedUriPermissions.any {
            it.uri == treeUri && it.isWritePermission
        }
        if (!hasWritePermission) return false
        return contentResolver.query(
            treeDocumentUri(treeUri),
            arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID),
            null,
            null,
            null,
        )?.use { cursor -> cursor.moveToFirst() } == true
    }

    fun directoryDisplayName(treeUri: Uri): String {
        requireTreeUri(treeUri)
        val name = contentResolver.query(
            treeDocumentUri(treeUri),
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0) else null
        }
        return name?.takeIf { it.isNotBlank() }
            ?: treeUri.lastPathSegment?.takeIf { it.isNotBlank() }
            ?: treeUri.toString()
    }

    fun writeBackup(treeUri: Uri, requestedName: String, bytes: ByteArray): String {
        requireWriteFileName(requestedName)
        requireDirectory(treeUri)
        val directoryUri = treeDocumentUri(treeUri)
        val fileName = uniqueFileName(treeUri, requestedName)
        val temporaryName = ".$fileName.partial"
        val temporaryUri = DocumentsContract.createDocument(
            contentResolver,
            directoryUri,
            JSON_MIME_TYPE,
            temporaryName,
        ) ?: throw IOException("The document provider could not create a backup file.")

        try {
            writeDocument(temporaryUri, bytes)
            val renamedUri = runCatching {
                DocumentsContract.renameDocument(
                    contentResolver,
                    temporaryUri,
                    fileName,
                )
            }.getOrNull()
            if (renamedUri != null) return renamedUri.toString()

            runCatching { DocumentsContract.deleteDocument(contentResolver, temporaryUri) }
            return createAndWriteDocument(directoryUri, fileName, bytes).toString()
        } catch (error: Exception) {
            runCatching { DocumentsContract.deleteDocument(contentResolver, temporaryUri) }
            throw error
        }
    }

    fun listBackupFiles(treeUri: Uri): List<String> {
        requireDirectory(treeUri)
        val childrenUri = childDocumentsUri(treeUri)
        val names = mutableListOf<String>()
        contentResolver.query(
            childrenUri,
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val name = cursor.getString(0)
                if (!name.isNullOrBlank()) names += name
            }
        }
        return names
    }

    fun deleteBackupFile(treeUri: Uri, fileName: String) {
        if (!isAutomaticBackupFile(fileName)) return
        requireDirectory(treeUri)
        val documentUri = findChildDocumentUri(treeUri, fileName) ?: return
        if (!DocumentsContract.deleteDocument(contentResolver, documentUri)) {
            throw IOException("The document provider could not delete the backup file.")
        }
    }

    private fun findChildDocumentUri(treeUri: Uri, fileName: String): Uri? {
        val childrenUri = childDocumentsUri(treeUri)
        contentResolver.query(
            childrenUri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            ),
            null,
            null,
            null,
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)
            while (cursor.moveToNext()) {
                val mimeType = if (mimeIndex >= 0) cursor.getString(mimeIndex) else null
                // A display name alone is not ownership proof. Some providers
                // expose directories and unrelated files with the same name;
                // only an ordinary application/json document created by this
                // storage implementation may be removed by retention.
                if (idIndex >= 0 &&
                    nameIndex >= 0 &&
                    mimeIndex >= 0 &&
                    cursor.getString(nameIndex) == fileName &&
                    AutomaticBackupFilePolicy.isOwnedDocument(fileName, mimeType)
                ) {
                    return DocumentsContract.buildDocumentUriUsingTree(
                        treeUri,
                        cursor.getString(idIndex),
                    )
                }
            }
        }
        return null
    }

    private fun createAndWriteDocument(
        directoryUri: Uri,
        fileName: String,
        bytes: ByteArray,
    ): Uri {
        val destinationUri = DocumentsContract.createDocument(
            contentResolver,
            directoryUri,
            JSON_MIME_TYPE,
            fileName,
        ) ?: throw IOException("The document provider could not create a backup file.")
        try {
            writeDocument(destinationUri, bytes)
            return destinationUri
        } catch (error: Exception) {
            runCatching { DocumentsContract.deleteDocument(contentResolver, destinationUri) }
            throw error
        }
    }

    private fun writeDocument(documentUri: Uri, bytes: ByteArray) {
        contentResolver.openOutputStream(documentUri, "wt")?.use { stream ->
            stream.write(bytes)
            stream.flush()
        } ?: throw IOException("The document provider could not open the backup file.")
    }

    private fun uniqueFileName(treeUri: Uri, requestedName: String): String {
        val existingNames = mutableSetOf<String>()
        contentResolver.query(
            childDocumentsUri(treeUri),
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) existingNames += cursor.getString(0)
        }
        if (requestedName !in existingNames) return requestedName

        val extensionIndex = requestedName.lastIndexOf('.')
        val baseName = if (extensionIndex > 0) {
            requestedName.substring(0, extensionIndex)
        } else {
            requestedName
        }
        val extension = if (extensionIndex > 0) requestedName.substring(extensionIndex) else ""
        var suffix = 1
        while ("$baseName-$suffix$extension" in existingNames) suffix++
        return "$baseName-$suffix$extension"
    }

    private fun childDocumentsUri(treeUri: Uri): Uri {
        return DocumentsContract.buildChildDocumentsUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri),
        )
    }

    private fun treeDocumentUri(treeUri: Uri): Uri {
        return DocumentsContract.buildDocumentUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri),
        )
    }

    private fun requireDirectory(treeUri: Uri) {
        requireTreeUri(treeUri)
        if (!directoryExists(treeUri)) {
            throw IOException("The selected directory permission is unavailable.")
        }
    }

    private fun requireTreeUri(treeUri: Uri) {
        require(isTreeUri(treeUri)) { "A persisted SAF tree URI is required." }
    }

    private fun isTreeUri(uri: Uri): Boolean {
        return uri.scheme == "content" && DocumentsContract.isTreeUri(uri)
    }

    private fun isAutomaticBackupFile(fileName: String): Boolean {
        return AutomaticBackupFilePolicy.isAutomaticBackupFile(fileName)
    }

    private fun requireWriteFileName(fileName: String) {
        require(
            fileName.isNotEmpty() &&
                fileName.none { it.code < 0x20 || it.code == 0x7f } &&
                WRITE_FILE_NAME_PATTERN.matches(fileName),
        ) { "A safe Hoopito backup basename is required." }
    }

    companion object {
        private const val JSON_MIME_TYPE = "application/json"
        private val WRITE_FILE_NAME_PATTERN =
            Regex("^hoop(?:trace|ito)-(?:auto|backup|safety-backup)-[A-Za-z0-9][A-Za-z0-9._-]*\\.json$")
    }
}

package io.github.x1a0y4ngren.hooptrace

import java.io.File

/** Short-lived seal for already hashed private bytes; never persisted. */
internal data class AppUpdatePreparedFile private constructor(
    val file: File,
    private val generation: Long,
    private val path: String,
    private val bytes: Long,
    private val modified: Long,
) {
    fun matches(currentGeneration: Long): Boolean = try {
        currentGeneration == generation && file.isFile &&
            file.canonicalPath == path && file.length() == bytes &&
            file.lastModified() == modified
    } catch (_: Exception) { false }

    companion object {
        fun capture(file: File, generation: Long): AppUpdatePreparedFile {
            require(file.isFile)
            return AppUpdatePreparedFile(file, generation, file.canonicalPath, file.length(), file.lastModified())
        }
    }
}

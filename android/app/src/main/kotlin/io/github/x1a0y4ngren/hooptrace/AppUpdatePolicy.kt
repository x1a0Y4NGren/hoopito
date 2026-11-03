package io.github.x1a0y4ngren.hooptrace

import java.io.File
import java.net.URI

/** Platform-free trust boundaries shared by download and install verification. */
internal object AppUpdatePolicy {
    // DownloadManager.PAUSED_WAITING_TO_RETRY = 1: a failed transfer, unlike
    // waiting for connectivity or a user-imposed Wi-Fi restriction.
    fun shouldFallbackPaused(usedFallback: Boolean, reason: Int): Boolean = !usedFallback && reason == 1

    fun isOfficialUrl(value: String): Boolean = try {
        val uri = URI(value)
        uri.scheme == "https" && uri.rawUserInfo == null && uri.port == -1 &&
            uri.rawQuery == null && uri.rawFragment == null &&
            uri.rawPath == uri.path && uri.normalize().path == uri.path &&
            when (uri.host) {
                "hoopito.com" -> uri.path.matches(Regex("/downloads/v[0-9A-Za-z.-]+/Hoopito-v[0-9A-Za-z.-]+-android\\.apk"))
                "github.com" -> uri.path.matches(Regex("/x1a0Y4NGren/hoopito/releases/download/v[0-9A-Za-z.-]+/Hoopito-v[0-9A-Za-z.-]+-android\\.apk"))
                else -> false
            }
    } catch (_: Exception) { false }

    fun sameSigners(installed: Set<String>, candidate: Set<String>): Boolean =
        installed.isNotEmpty() && installed == candidate

    fun isUpgrade(candidateCode: Long, installedCode: Long): Boolean = candidateCode > installedCode

    fun matchesPackage(
        expectedId: String, expectedCode: Long, expectedName: String, expectedApi: Int,
        actualId: String, actualCode: Long, actualName: String?, actualApi: Int,
        installedCode: Long, sdkInt: Int,
    ): Boolean = expectedId == actualId && expectedCode == actualCode &&
        expectedName == actualName && expectedApi == actualApi &&
        actualApi <= sdkInt && isUpgrade(actualCode, installedCode)

    fun ownedFile(root: File, digest: String, extension: String): File {
        require(digest.matches(Regex("[a-f0-9]{64}")))
        require(extension in setOf(".part", ".apk", ".tmp"))
        val parent = root.canonicalFile
        return File(parent, digest + extension).canonicalFile.also {
            require(it.parentFile == parent)
        }
    }

    fun isOwnedName(name: String): Boolean = name.matches(Regex("[a-f0-9]{64}\\.(part|apk|tmp)"))
}

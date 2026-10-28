package io.github.x1a0y4ngren.hooptrace

import android.app.Activity
import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

/** Attached only to the foreground engine. Background backup engines never register it. */
internal class AppUpdateDelegate(private val activity: Activity) {
    private val coordinator = AppUpdateCoordinator.get(activity.applicationContext)
    private var disposed = false
    private var resumed = false
    private var lifecycleGeneration = 0L

    fun onResume() { resumed = true }
    fun onPause() {
        resumed = false
        lifecycleGeneration++
        coordinator.clearPreparedInstall()
    }

    fun dispose() { disposed = true }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        fun reply(value: Any?) { if (!disposed) result.success(value) }
        when (call.method) {
            "claimStartupCheck" -> reply(startupCheckClaimed.compareAndSet(false, true))
            "getInstalledApp" -> coordinator.execute({ coordinator.installedApp() }, ::reply)
            "startDownload" -> {
                coordinator.invalidateInstall()
                coordinator.execute({ coordinator.start(call.arguments) }, ::reply)
            }
            "queryDownload" -> coordinator.execute({ coordinator.query() }, ::reply)
            "cancelDownload" -> {
                coordinator.invalidateInstall()
                coordinator.execute({ coordinator.cancel(); null }, ::reply)
            }
            "prepareInstall" -> {
                val lifecycleToken = lifecycleGeneration
                coordinator.prepareInstall { prepared ->
                    if (disposed || !resumed || lifecycleToken != lifecycleGeneration ||
                        activity.isFinishing || activity.isDestroyed || !prepared
                    ) {
                        coordinator.clearPreparedInstall()
                        reply("unavailable")
                    } else if (Build.VERSION.SDK_INT >= 26 &&
                        !activity.packageManager.canRequestPackageInstalls()
                    ) {
                        coordinator.clearPreparedInstall()
                        reply("permissionRequired")
                    } else reply("prepared")
                }
            }
            "requestInstall" -> {
                // No worker hop here: Dart has just rechecked the initiating
                // route and match, and this turn consumes its prepared seal.
                val file = coordinator.consumePreparedInstall()
                if (disposed || !resumed || activity.isFinishing || activity.isDestroyed || file == null) {
                    reply("unavailable")
                } else if (Build.VERSION.SDK_INT >= 26 &&
                    !activity.packageManager.canRequestPackageInstalls()
                ) {
                    reply("permissionRequired")
                } else {
                    try {
                        val uri = FileProvider.getUriForFile(
                            activity, "${activity.packageName}.updates", file,
                        )
                        activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            clipData = android.content.ClipData.newRawUri("Hoopito update", uri)
                        })
                        reply("installerLaunched")
                    } catch (_: Exception) { reply("unavailable") }
                }
            }
            "openInstallSettings" -> {
                try {
                    activity.startActivity(
                        if (Build.VERSION.SDK_INT >= 26) {
                            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:${activity.packageName}"))
                        } else {
                            Intent(Settings.ACTION_SECURITY_SETTINGS)
                        },
                    )
                    reply(null)
                } catch (_: Exception) {
                    result.error("unavailable", "Installation settings unavailable", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val channelName = "io.github.x1a0y4ngren.hooptrace/app_update"
        private val startupCheckClaimed = AtomicBoolean(false)
    }
}

private data class AppUpdateRelease(val json: JSONObject) {
    val id = json.getString("applicationId")
    val code = integer(json, "versionCode")
    val name = json.getString("versionName")
    val minimumApi = integer(json, "minimumApi").toInt()
    private val apk = json.getJSONObject("apk")
    val bytes = integer(apk, "bytes")
    val digest = apk.getString("sha256")
    val url = apk.getString("url")
    val fallback = apk.getString("fallbackUrl")

    init {
        require(integer(json, "schemaVersion") == 1L)
        require(id == "io.github.x1a0y4ngren.hooptrace")
        require(code > 0 && name.isNotBlank() && name.length <= 128)
        require(integer(json, "minimumApi") in 24..Int.MAX_VALUE.toLong())
        require(bytes in 1..(512L * 1024 * 1024))
        require(digest.matches(Regex("[a-f0-9]{64}")))
        require(AppUpdatePolicy.isOfficialUrl(url) && AppUpdatePolicy.isOfficialUrl(fallback))
        val notes = json.getJSONObject("releaseNotes")
        require(notes.get("zh") is String && notes.get("en") is String)
        require(json.toString().toByteArray(Charsets.UTF_8).size <= 65536)
    }

    companion object {
        private fun integer(json: JSONObject, key: String): Long {
            val value = json.get(key)
            require(value is Int || value is Long)
            return (value as Number).toLong()
        }
    }
}

/** One serial worker and persisted DM identity survive Activity and engine recreation. */
private class AppUpdateCoordinator private constructor(private val context: Context) {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val prefs = context.getSharedPreferences("app_update_v1", Context.MODE_PRIVATE)
    private val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    private val generation = AtomicLong()
    private var release = runCatching {
        prefs.getString("release", null)?.let { AppUpdateRelease(JSONObject(it)) }
    }.getOrNull()
    private var downloadId = prefs.getLong("downloadId", -1)
    private var phase = prefs.getString("phase", "idle") ?: "idle"
    private var error = prefs.getString("error", null)
    private var usedFallback = prefs.getBoolean("usedFallback", false)
    private var received = 0L
    private var total = release?.bytes ?: 0L
    private var verifying = false
    @Volatile private var preparedInstall: AppUpdatePreparedFile? = null

    fun clearPreparedInstall() { preparedInstall = null }
    fun invalidateInstall() { generation.incrementAndGet(); clearPreparedInstall() }
    fun isCurrent(value: Long): Boolean = generation.get() == value

    fun consumePreparedInstall(): File? {
        val prepared = preparedInstall ?: return null
        preparedInstall = null
        return runCatching {
            val writeBits = android.system.OsConstants.S_IWUSR or
                android.system.OsConstants.S_IWGRP or android.system.OsConstants.S_IWOTH
            if (prepared.matches(generation.get()) &&
                android.system.Os.stat(prepared.file.path).st_mode and writeBits == 0
            ) prepared.file else null
        }.getOrNull()
    }

    fun execute(action: () -> Any?, reply: (Any?) -> Unit) {
        worker.execute {
            val value = try { action() } catch (failure: Exception) {
                runCatching { fail(errorFor(failure)) }
                snapshot()
            }
            main.post { reply(value) }
        }
    }

    @Suppress("DEPRECATION")
    private fun installed(): PackageInfo = context.packageManager.getPackageInfo(
        context.packageName, signingFlags(),
    )

    fun installedApp(): Map<String, Any> {
        val app = installed()
        return mapOf("applicationId" to app.packageName, "versionName" to (app.versionName ?: ""),
            "versionCode" to versionCode(app), "sdkInt" to Build.VERSION.SDK_INT)
    }

    fun start(arguments: Any?): Map<String, Any?> {
        val next = try {
            require(arguments is Map<*, *>)
            AppUpdateRelease(JSONObject(arguments))
        } catch (_: Exception) {
            // A malformed caller cannot discard an existing task or verified candidate.
            return snapshot().toMutableMap().apply { put("error", "verification") }
        }
        if (next.minimumApi > Build.VERSION.SDK_INT || !AppUpdatePolicy.isUpgrade(next.code, versionCode(installed()))) {
            return snapshot().toMutableMap().apply { put("error", "unsupported") }
        }
        if (release?.digest == next.digest && phase in setOf("queued", "downloading", "paused", "verifying", "ready")) {
            return query()
        }
        cancel()
        release = next
        usedFallback = false
        total = next.bytes
        received = 0
        enqueue(next.url)
        return snapshot()
    }

    @Suppress("DEPRECATION")
    private fun enqueue(url: String) {
        val current = requireNotNull(release)
        val externalRoot = externalRoot()
        require(externalRoot.mkdirs() || externalRoot.isDirectory)
        val destination = AppUpdatePolicy.ownedFile(externalRoot, current.digest, ".part")
        if (destination.exists() && !destination.delete()) throw IOException("Cannot remove staging")
        phase = "queued"
        error = null
        // Save release before enqueue so an interrupted write never binds an old release to a new ID.
        downloadId = -1
        persist()
        val request = DownloadManager.Request(Uri.parse(url))
            .setDestinationInExternalFilesDir(context, "updates", destination.name)
            .setMimeType("application/octet-stream")
            .setTitle("Hoopito")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(false)
        if (Build.VERSION.SDK_INT < 29) request.setVisibleInDownloadsUi(false)
        downloadId = manager.enqueue(request)
        persist()
    }

    fun query(): Map<String, Any?> {
        val current = release ?: return snapshot()
        if (!AppUpdatePolicy.isUpgrade(current.code, versionCode(installed()))) {
            cancel()
            return snapshot()
        }
        if (phase == "ready") {
            if (!privateFile(current).isFile) fail("missing")
            return snapshot()
        }
        if (phase == "failed" || phase == "idle" || verifying) return snapshot()
        if (downloadId < 0) {
            // Recover the small enqueue/ID-persistence interruption window without starting a second task.
            downloadId = ownDownloads(current.digest).firstOrNull() ?: -1
            if (downloadId < 0) { fail("missing"); return snapshot() }
            persist()
        }
        val cursor = manager.query(DownloadManager.Query().setFilterById(downloadId))
        cursor.use {
            if (it == null || !it.moveToFirst()) { fail("missing"); return snapshot() }
            received = it.getLong(it.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)).coerceAtLeast(0)
            total = current.bytes
            when (it.getInt(it.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))) {
                DownloadManager.STATUS_PENDING -> phase = "queued"
                DownloadManager.STATUS_RUNNING -> phase = "downloading"
                DownloadManager.STATUS_PAUSED -> {
                    val reason = it.getInt(it.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
                    if (AppUpdatePolicy.shouldFallbackPaused(usedFallback, reason)) {
                        retryFallback(current)
                    } else phase = "paused"
                }
                DownloadManager.STATUS_FAILED -> {
                    val reason = it.getInt(it.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
                    manager.remove(downloadId)
                    downloadId = -1
                    if (!usedFallback) {
                        retryFallback(current)
                    } else {
                        fail(if (reason in setOf(DownloadManager.ERROR_INSUFFICIENT_SPACE,
                                DownloadManager.ERROR_FILE_ERROR, DownloadManager.ERROR_DEVICE_NOT_FOUND)) "storage" else "network")
                    }
                }
                DownloadManager.STATUS_SUCCESSFUL -> beginVerification(current)
                else -> fail("unavailable")
            }
        }
        persist()
        return snapshot()
    }

    private fun beginVerification(current: AppUpdateRelease) {
        if (verifying) return
        val token = generation.get()
        verifying = true
        phase = "verifying"
        persist()
        worker.execute {
            if (!isCurrent(token) || release !== current || phase != "verifying") {
                if (release === current) verifying = false
                return@execute
            }
            try {
                val stage = AppUpdatePolicy.ownedFile(externalRoot(), current.digest, ".part")
                val root = privateRoot()
                if (!root.mkdirs() && !root.isDirectory) throw IOException("Cannot create update directory")
                val temporary = AppUpdatePolicy.ownedFile(root, current.digest, ".tmp")
                AppUpdateFiles.copyAndVerify(stage, temporary, current.bytes, current.digest)
                verifyPackage(temporary, current)
                if (!isCurrent(token)) {
                    temporary.delete()
                    return@execute
                }
                val candidate = privateFile(current)
                if (candidate.exists() && !candidate.delete()) throw IOException("Cannot replace candidate")
                if (!temporary.renameTo(candidate)) throw IOException("Cannot retain candidate")
                if (!candidate.setReadOnly()) throw IOException("Cannot protect candidate")
                phase = "ready"
                error = null
                received = current.bytes
                manager.remove(downloadId)
                downloadId = -1
                stage.delete()
            } catch (failure: Exception) {
                removePrivate(current)
                if (isCurrent(token)) fail(errorFor(failure))
            } finally {
                verifying = false
                runCatching { persist() }
            }
        }
    }

    private fun retryFallback(current: AppUpdateRelease) {
        if (downloadId >= 0) manager.remove(downloadId)
        downloadId = -1
        usedFallback = true
        received = 0
        enqueue(current.fallback)
    }

    fun prepareInstall(reply: (Boolean) -> Unit) {
        clearPreparedInstall()
        val token = generation.get()
        worker.execute {
            val current = release
            val file = try {
                if (!isCurrent(token) || phase != "ready" || current == null) null else {
                    privateFile(current).also {
                        // Never trust a persisted ready flag, external staging, or a former verification.
                        AppUpdateFiles.verify(it, current.bytes, current.digest)
                        verifyPackage(it, current)
                        if (!it.setReadOnly()) throw IOException("Cannot protect candidate")
                    }
                }
            } catch (failure: Exception) {
                if (current != null) removePrivate(current)
                runCatching { fail(errorFor(failure)) }
                null
            }
            val prepared = file?.let { AppUpdatePreparedFile.capture(it, token) }
            main.post {
                preparedInstall = prepared?.takeIf { it.matches(generation.get()) }
                reply(preparedInstall != null)
            }
        }
    }

    fun cancel() {
        invalidateInstall()
        // Also recover IDs interrupted between enqueue and preference persistence.
        val ownedIds = runCatching { ownDownloads() }.getOrDefault(emptyList())
        if (ownedIds.isNotEmpty()) manager.remove(*ownedIds.toLongArray())
        if (downloadId >= 0) manager.remove(downloadId)
        downloadId = -1
        // Only digest-named files immediately inside our two dedicated directories are owned.
        listOfNotNull(runCatching { externalRoot() }.getOrNull(), privateRoot()).forEach { root ->
            root.listFiles()?.filter { AppUpdatePolicy.isOwnedName(it.name) }?.forEach { file ->
                if (file.canonicalFile.parentFile == root.canonicalFile) file.delete()
            }
        }
        release = null
        verifying = false
        phase = "idle"
        error = null
        usedFallback = false
        received = 0
        total = 0
        persist()
    }

    private fun ownDownloads(digest: String? = null): List<Long> {
        val root = externalRoot().canonicalFile
        val ids = mutableListOf<Long>()
        manager.query(DownloadManager.Query()).use { cursor ->
            if (cursor == null) return ids
            while (cursor.moveToNext()) {
                val local = cursor.getString(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI)) ?: continue
                val uri = Uri.parse(local)
                if (uri.scheme != "file") continue
                val file = File(uri.path ?: continue)
                if (file.canonicalFile.parentFile != root || !file.name.endsWith(".part") ||
                    !AppUpdatePolicy.isOwnedName(file.name) ||
                    (digest != null && file.name != "$digest.part") ||
                    cursor.getString(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_MEDIA_TYPE)) != "application/octet-stream"
                ) continue
                ids += cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_ID))
            }
        }
        return ids
    }

    @Suppress("DEPRECATION")
    private fun verifyPackage(file: File, current: AppUpdateRelease) {
        val candidate = context.packageManager.getPackageArchiveInfo(file.absolutePath, signingFlags())
            ?: throw SecurityException("Invalid APK")
        val own = installed()
        if (!AppUpdatePolicy.matchesPackage(
                current.id, current.code, current.name, current.minimumApi,
                candidate.packageName, versionCode(candidate), candidate.versionName,
                candidate.applicationInfo?.minSdkVersion ?: -1, versionCode(own), Build.VERSION.SDK_INT,
            ) || !AppUpdatePolicy.sameSigners(signers(own), signers(candidate))
        ) throw SecurityException("APK identity mismatch")
    }

    @Suppress("DEPRECATION")
    private fun signers(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners
            else info.signatures
        return signatures?.map { hex(MessageDigest.getInstance("SHA-256").digest(it.toByteArray())) }?.toSet().orEmpty()
    }

    private fun privateRoot(): File = updateRoot(context.filesDir)
    private fun externalRoot(): File = updateRoot(context.getExternalFilesDir(null)
        ?: throw IOException("No staging storage"))
    private fun updateRoot(base: File): File {
        val root = File(base.canonicalFile, "updates")
        if (root.canonicalFile != root) throw SecurityException("Unsafe update directory")
        return root
    }
    private fun privateFile(current: AppUpdateRelease) = AppUpdatePolicy.ownedFile(privateRoot(), current.digest, ".apk")
    private fun removePrivate(current: AppUpdateRelease) {
        for (extension in listOf(".apk", ".tmp")) {
            AppUpdatePolicy.ownedFile(privateRoot(), current.digest, extension).delete()
        }
    }

    private fun fail(code: String) { phase = "failed"; error = code; persist() }
    private fun errorFor(failure: Exception): String = when (failure) {
        is FileNotFoundException -> "missing"
        is SecurityException, is IllegalArgumentException -> "verification"
        is IOException -> "storage"
        else -> "unavailable"
    }

    private fun persist() {
        if (!prefs.edit().putString("release", release?.json?.toString())
            .putLong("downloadId", downloadId).putString("phase", phase)
            .putString("error", error).putBoolean("usedFallback", usedFallback).commit()) {
            throw IOException("Cannot persist update state")
        }
    }

    private fun snapshot(): Map<String, Any?> = mapOf(
        "phase" to phase, "bytesReceived" to received, "bytesTotal" to total,
        "release" to release?.json?.let(::jsonMap), "error" to error, "usedFallback" to usedFallback,
    )

    companion object {
        @Volatile private var instance: AppUpdateCoordinator? = null
        fun get(context: Context): AppUpdateCoordinator = instance ?: synchronized(this) {
            instance ?: AppUpdateCoordinator(context).also { instance = it }
        }
        @Suppress("DEPRECATION")
        private fun signingFlags() = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
        @Suppress("DEPRECATION")
        private fun versionCode(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
        private fun hex(bytes: ByteArray) = bytes.joinToString("") { "%02x".format(it) }
        private fun jsonMap(json: JSONObject): Map<String, Any?> = json.keys().asSequence().associateWith { key ->
            when (val value = json.get(key)) {
                JSONObject.NULL -> null
                is JSONObject -> jsonMap(value)
                is JSONArray -> error("Unexpected array")
                else -> value
            }
        }
    }
}

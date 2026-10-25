package io.github.x1a0y4ngren.hooptrace

import android.os.Handler
import android.os.Looper
import androidx.core.net.toUri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** Dispatches backup method calls without making MainActivity own storage code. */
internal class AutomaticBackupChannelDelegate(
    private val storage: AutomaticBackupStorageDelegate,
    private val picker: AutomaticBackupDirectoryPickerDelegate?,
    private val workManager: AutomaticBackupWorkManagerFacade? = null,
    private val backgroundDatabasePath: String? = null,
    private val mainHandler: Handler = Handler(Looper.getMainLooper()),
    private val executor: ExecutorService = Executors.newCachedThreadPool(),
) {
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickDirectory" -> {
                val directoryPicker = picker
                if (directoryPicker == null) {
                    result.error("picker_unavailable", null, null)
                } else {
                    directoryPicker.pickDirectory(result)
                }
            }
            "scheduleAutomaticBackup" -> {
                runCatching {
                    workManager?.schedule()
                        ?: throw IllegalStateException("Background scheduler unavailable.")
                }.onSuccess { result.success(null) }
                    .onFailure {
                        result.error("scheduler_error", null, null)
                    }
            }
            "cancelAutomaticBackup" -> {
                runCatching {
                    workManager?.cancel()
                        ?: throw IllegalStateException("Background scheduler unavailable.")
                }.onSuccess { result.success(null) }
                    .onFailure {
                        result.error("scheduler_error", null, null)
                    }
            }
            "backgroundDatabasePath" -> {
                val path = backgroundDatabasePath
                if (path == null) {
                    result.error("background_database_unavailable", null, null)
                } else {
                    result.success(path)
                }
            }
            "directoryExists" -> runStorageOperation(result) {
                storage.directoryExists(call.requireString("directory").toUri())
            }
            "writeBackup" -> runStorageOperation(result) {
                val bytes = call.argument<ByteArray>("bytes")
                    ?: throw IllegalArgumentException("Missing bytes")
                storage.writeBackup(
                    call.requireString("directory").toUri(),
                    call.requireString("fileName"),
                    bytes,
                )
            }
            "listBackupFiles" -> runStorageOperation(result) {
                storage.listBackupFiles(call.requireString("directory").toUri())
            }
            "deleteBackupFile" -> runStorageOperation(result) {
                storage.deleteBackupFile(
                    call.requireString("directory").toUri(),
                    call.requireString("fileName"),
                )
                // StandardMethodCodec cannot encode Kotlin Unit. Dart expects
                // a void success envelope after the deletion completes.
                null
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        executor.shutdownNow()
    }

    private fun MethodCall.requireString(name: String): String {
        return argument<String>(name)?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("Missing $name")
    }

    private fun <T> runStorageOperation(
        result: MethodChannel.Result,
        operation: () -> T,
    ) {
        executor.execute {
            try {
                val value = operation()
                mainHandler.post { result.success(value) }
            } catch (_: Exception) {
                mainHandler.post {
                    result.error("storage_error", null, null)
                }
            }
        }
    }
}

internal interface AutomaticBackupWorkManagerFacade {
    fun schedule()

    fun cancel()
}

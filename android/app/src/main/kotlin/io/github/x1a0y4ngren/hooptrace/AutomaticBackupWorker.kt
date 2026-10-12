package io.github.x1a0y4ngren.hooptrace

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * Runs the existing Dart export service in a short-lived headless Flutter
 * engine. The engine registers the same storage-only SAF channel as the
 * activity, so no picker or activity lifecycle is required in the worker.
 */
internal class AutomaticBackupWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : Worker(appContext, workerParams) {
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun doWork(): Result {
        val completion = CountDownLatch(1)
        val outcome = AtomicReference<AutomaticBackupWorkerOutcome?>(null)
        val engineReference = AtomicReference<FlutterEngine?>(null)
        val storageChannelReference = AtomicReference<AutomaticBackupChannelDelegate?>(null)
        val startFailure = AtomicReference<Throwable?>(null)
        val startComplete = CountDownLatch(1)

        mainHandler.post {
            try {
                val engine = FlutterEngine(
                    applicationContext,
                    null,
                    false,
                )
                engineReference.set(engine)

                val storage = AutomaticBackupStorageDelegate(
                    applicationContext.contentResolver,
                )
                val storageChannel = AutomaticBackupChannelDelegate(
                    storage = storage,
                    picker = null,
                    workManager = object : AutomaticBackupWorkManagerFacade {
                        override fun schedule() {
                            AutomaticBackupWorkManager.schedule(applicationContext)
                        }

                        override fun cancel() {
                            AutomaticBackupWorkManager.cancel(applicationContext)
                        }
                    },
                    backgroundDatabasePath = File(
                        applicationContext.getDir("flutter", Context.MODE_PRIVATE),
                        "hooptrace.sqlite",
                    ).absolutePath,
                )
                storageChannelReference.set(storageChannel)
                MethodChannel(
                    engine.dartExecutor.binaryMessenger,
                    AutomaticBackupWorkPolicy.storageChannelName,
                ).setMethodCallHandler(storageChannel::handle)

                MethodChannel(
                    engine.dartExecutor.binaryMessenger,
                    AutomaticBackupWorkPolicy.completionChannelName,
                ).setMethodCallHandler { call, result ->
                    if (call.method != "completed") {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                    val wireOutcome = call.argument<String>("outcome")
                    outcome.set(AutomaticBackupWorkerOutcome.fromWire(wireOutcome))
                    result.success(null)
                    completion.countDown()
                }

                engine.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(
                        DartExecutor.DartEntrypoint.createDefault().pathToBundle,
                        "package:hoopito/main.dart",
                        "automaticBackupBackgroundMain",
                    ),
                )
            } catch (error: Throwable) {
                startFailure.set(error)
            } finally {
                startComplete.countDown()
            }
        }

        try {
            if (!startComplete.await(START_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
                return Result.retry()
            }
            if (startFailure.get() != null) return Result.retry()
            if (!completion.await(COMPLETION_TIMEOUT_MINUTES, TimeUnit.MINUTES)) {
                return Result.retry()
            }
            return when (outcome.get()) {
                null -> Result.retry()
                else -> if (outcome.get()!!.shouldRetry) Result.retry() else Result.success()
            }
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            return Result.retry()
        } finally {
            storageChannelReference.get()?.dispose()
            mainHandler.post { engineReference.get()?.destroy() }
        }
    }

    companion object {
        private const val START_TIMEOUT_SECONDS = 30L
        private const val COMPLETION_TIMEOUT_MINUTES = 8L
    }
}

package io.github.x1a0y4ngren.hooptrace

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.SurfaceHolder
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Flutter shell; Android-specific storage and picker behavior live in delegates. */
class MainActivity : FlutterActivity() {
    private val suppressEntryAnimation = synchronized(MainActivity::class.java) {
        val alreadyClaimed = entryAnimationClaimed
        entryAnimationClaimed = true
        alreadyClaimed
    }
    private lateinit var backupChannel: AutomaticBackupChannelDelegate
    private lateinit var directoryPicker: AutomaticBackupDirectoryPickerDelegate
    private var appUpdateDelegate: AppUpdateDelegate? = null
    private var appUpdateChannel: MethodChannel? = null

    override fun onResume() {
        super.onResume()
        appUpdateDelegate?.onResume()
    }

    override fun onPause() {
        appUpdateDelegate?.onPause()
        super.onPause()
    }
    private var entryMotionChannel: MethodChannel? = null
    private var entryRendererChannel: MethodChannel? = null
    private val entrySurfaceReadiness = EntrySurfaceReadiness()
    private val entryPresentationReadiness = EntrySurfaceReadiness()
    private var entrySurfaceHolder: SurfaceHolder? = null
    private val entrySurfaceCallback = object : SurfaceHolder.Callback {
        override fun surfaceCreated(holder: SurfaceHolder) = Unit

        override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
            // Registered after Flutter's callback: its native creation and
            // initial resize have completed before Dart receives readiness.
            if (holder.surface.isValid && width > 0 && height > 0) {
                entrySurfaceReadiness.surfaceReady()
            }
        }

        override fun surfaceDestroyed(holder: SurfaceHolder) {
            entrySurfaceReadiness.surfaceLost()
        }
    }

    override fun onFlutterSurfaceViewCreated(flutterSurfaceView: FlutterSurfaceView) {
        super.onFlutterSurfaceViewCreated(flutterSurfaceView)
        entrySurfaceHolder = flutterSurfaceView.holder.also {
            it.addCallback(entrySurfaceCallback)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AndroidWindowPolicy.apply(window)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Flutter's first frame matches the native icon. The platform's
            // default exit fade would cover the beginning of its jump.
            splashScreen.setOnExitAnimationListener { splash ->
                splash.remove()
                updateSystemUiOverlays()
                entryPresentationReadiness.surfaceReady()
            }
        }
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            entryPresentationReadiness.surfaceReady()
        }
    }

    override fun getDartEntrypointArgs(): List<String>? {
        val arguments = super.getDartEntrypointArgs().orEmpty().toMutableList()
        if (suppressEntryAnimation) {
            arguments += ENTRY_ANIMATION_DISABLED_ARGUMENT
        }
        val value = getSharedPreferences(ENTRY_MOTION_PREFERENCES, MODE_PRIVATE)
            .getString(ENTRY_MOTION_KEY, null)
        if (value == "standard" || value == "reduced") {
            arguments += "$ENTRY_MOTION_ARGUMENT_PREFIX$value"
        }
        return arguments.ifEmpty { null }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        appUpdateDelegate = AppUpdateDelegate(this)
        appUpdateChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, AppUpdateDelegate.channelName,
        ).also { channel -> channel.setMethodCallHandler(appUpdateDelegate!!::handle) }
        val storage = AutomaticBackupStorageDelegate(contentResolver)
        directoryPicker = AutomaticBackupDirectoryPickerDelegate(
            activity = this,
            contentResolver = contentResolver,
            storage = storage,
        )
        val workManager = object : AutomaticBackupWorkManagerFacade {
            override fun schedule() = AutomaticBackupWorkManager.schedule(this@MainActivity)

            override fun cancel() = AutomaticBackupWorkManager.cancel(this@MainActivity)
        }
        backupChannel = AutomaticBackupChannelDelegate(
            storage = storage,
            picker = directoryPicker,
            workManager = workManager,
        )
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKUP_CHANNEL)
            .setMethodCallHandler(backupChannel::handle)
        entryMotionChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ENTRY_MOTION_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                val preferences = getSharedPreferences(
                    ENTRY_MOTION_PREFERENCES,
                    MODE_PRIVATE,
                )
                when (call.method) {
                    "read" -> result.success(
                        if (preferences.contains(ENTRY_MOTION_KEY)) {
                            preferences.getString(ENTRY_MOTION_KEY, null)
                        } else {
                            null
                        },
                    )
                    "write" -> {
                        val value = call.arguments as? String
                        if (value != "standard" && value != "reduced") {
                            result.error("invalid_motion", "Unsupported motion preference", null)
                        } else if (preferences.edit().putString(ENTRY_MOTION_KEY, value).commit()) {
                            result.success(null)
                        } else {
                            result.error("write_failed", "Could not cache motion preference", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
        entryRendererChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ENTRY_RENDERER_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "waitUntilReady" -> entrySurfaceReadiness.waitUntilReady {
                        result.success(it)
                    }
                    "waitUntilPresented" -> entryPresentationReadiness.waitUntilReady {
                        result.success(it)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (::directoryPicker.isInitialized) {
            directoryPicker.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onDestroy() {
        appUpdateChannel?.setMethodCallHandler(null)
        appUpdateChannel = null
        appUpdateDelegate?.dispose()
        appUpdateDelegate = null
        entrySurfaceHolder?.removeCallback(entrySurfaceCallback)
        entrySurfaceHolder = null
        entrySurfaceReadiness.dispose()
        entryPresentationReadiness.dispose()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.clearOnExitAnimationListener()
        }
        entryRendererChannel?.setMethodCallHandler(null)
        entryRendererChannel = null
        entryMotionChannel?.setMethodCallHandler(null)
        entryMotionChannel = null
        if (::directoryPicker.isInitialized) directoryPicker.dispose()
        if (::backupChannel.isInitialized) backupChannel.dispose()
        super.onDestroy()
    }

    companion object {
        internal const val BACKUP_CHANNEL =
            AutomaticBackupWorkPolicy.storageChannelName
        internal const val ENTRY_MOTION_CHANNEL =
            "io.github.x1a0y4ngren.hooptrace/entry_motion_preference"
        internal const val ENTRY_RENDERER_CHANNEL =
            "io.github.x1a0y4ngren.hooptrace/entry_renderer"
        private const val ENTRY_MOTION_PREFERENCES = "entry_motion_preference"
        private const val ENTRY_MOTION_KEY = "motion"
        private const val ENTRY_MOTION_ARGUMENT_PREFIX = "--hoopito-entry-motion="
        private const val ENTRY_ANIMATION_DISABLED_ARGUMENT =
            "--hoopito-entry-animation=disabled"
        private var entryAnimationClaimed = false
    }
}

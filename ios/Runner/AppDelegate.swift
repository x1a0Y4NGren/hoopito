import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var entryMotionChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "io.github.x1a0y4ngren.hooptrace/entry_motion_preference",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      let defaults = UserDefaults.standard
      let key = "entry_motion_preference"
      switch call.method {
      case "read":
        result(defaults.string(forKey: key))
      case "write":
        guard let value = call.arguments as? String,
              value == "standard" || value == "reduced" else {
          result(FlutterError(
            code: "invalid_motion",
            message: "Unsupported motion preference",
            details: nil
          ))
          return
        }
        defaults.set(value, forKey: key)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    entryMotionChannel = channel
  }
}

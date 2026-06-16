import Flutter
import UIKit
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // WorkManager iOS BGTask 핸들러 등록
    UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60 * 60))
    WorkmanagerPlugin.registerBGProcessingTask(
      withIdentifier: "ansim-signal-check"
    )
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

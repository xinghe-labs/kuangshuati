import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// 持有原生通道对象，避免被释放后 Dart 侧调用无响应。
  private var channels: KuangshuatiChannels?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // 使用隐式引擎时没有现成的 FlutterViewController 引用，交给通道自行
    // 从 window scene 里找最顶层控制器来展示系统面板。
    channels = KuangshuatiChannels(
      messenger: engineBridge.applicationRegistrar.messenger(),
      viewController: nil
    )
  }
}

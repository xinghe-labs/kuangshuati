import Flutter
import UIKit
import UniformTypeIdentifiers

/// iOS 侧的原生出入口实现，与 Android 的 MainActivity 保持同名 MethodChannel。
///
/// - `com.kuangshuati.app/backup`：备份文件的分享、另存为、从文件选择器导入。
/// - `com.kuangshuati.app/updates`：只实现 `getVersion`；iOS 无法自行安装
///   APK，更新相关方法一律返回 notImplemented，Dart 侧会降级为「不可更新」。
final class KuangshuatiChannels: NSObject {
  private static let backupChannelName = "com.kuangshuati.app/backup"
  private static let updatesChannelName = "com.kuangshuati.app/updates"

  private let messenger: FlutterBinaryMessenger
  private weak var viewController: UIViewController?

  init(messenger: FlutterBinaryMessenger, viewController: UIViewController?) {
    self.messenger = messenger
    self.viewController = viewController
    super.init()

    let backup = FlutterMethodChannel(
      name: Self.backupChannelName,
      binaryMessenger: messenger
    )
    backup.setMethodCallHandler { [weak self] call, result in
      self?.handleBackup(call, result: result)
    }

    let updates = FlutterMethodChannel(
      name: Self.updatesChannelName,
      binaryMessenger: messenger
    )
    updates.setMethodCallHandler { [weak self] call, result in
      self?.handleUpdates(call, result: result)
    }
  }

  // MARK: - 备份

  private func handleBackup(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "shareFile":
      guard
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String,
        !path.isEmpty
      else {
        result(FlutterError(code: "invalid_path", message: "备份路径为空", details: nil))
        return
      }
      let url = URL(fileURLWithPath: path)
      guard FileManager.default.fileExists(atPath: url.path) else {
        result(FlutterError(code: "share_failed", message: "备份文件不存在", details: nil))
        return
      }
      share(url: url, name: args["name"] as? String, result: result)

    case "saveFile":
      guard
        let args = call.arguments as? [String: Any],
        let data = args["bytes"] as? FlutterStandardTypedData,
        !data.data.isEmpty
      else {
        result(FlutterError(code: "invalid_data", message: "备份数据为空", details: nil))
        return
      }
      let name = (args["name"] as? String) ?? "kst-backup.gkbackup"
      save(data: data.data, name: name, result: result)

    case "pickFile":
      pick(result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func share(url: URL, name: String?, result: @escaping FlutterResult) {
    guard let presenter = topViewController() else {
      result(FlutterError(code: "share_failed", message: "当前无可用的展示界面", details: nil))
      return
    }
    // 复制到临时目录再分享：原文件在沙盒内可能不可读，复制后带扩展名更利于
    // 接收方（微信/邮件/文件 App）正确识别。
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(name ?? url.lastPathComponent)
    try? FileManager.default.removeItem(at: tempURL)
    do {
      try FileManager.default.copyItem(at: url, to: tempURL)
    } catch {
      result(FlutterError(code: "share_failed", message: error.localizedDescription, details: nil))
      return
    }

    let activity = UIActivityViewController(
      activityItems: [tempURL],
      applicationActivities: nil
    )
    // iPad 上必须给出 popover 锚点，否则会崩溃。
    if let popover = activity.popoverPresentationController {
      popover.sourceView = presenter.view
      popover.sourceRect = CGRect(
        x: presenter.view.bounds.midX,
        y: presenter.view.bounds.midY,
        width: 0,
        height: 0
      )
      popover.permittedArrowDirections = []
    }
    presenter.present(activity, animated: true) {
      result(true)
    }
  }

  private func save(data: Data, name: String, result: @escaping FlutterResult) {
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    do {
      try data.write(to: tempURL, options: .atomic)
    } catch {
      result(FlutterError(code: "save_failed", message: error.localizedDescription, details: nil))
      return
    }

    let picker = UIDocumentPickerViewController(
      forExporting: [tempURL],
      asCopy: true
    )
    picker.delegate = ExportDelegate(result: result)
    // delegate 是弱引用，需由 channel 对象持有到回调结束。
    retainDelegate(picker.delegate)
    present(picker, result: result)
  }

  private func pick(result: @escaping FlutterResult) {
    var types: [UTType] = [.data]
    // 备份文件后缀是 .gkbackup，系统不认识，用 .data 兜底后按内容校验。
    if let custom = UTType(filenameExtension: "gkbackup") {
      types.append(custom)
    }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
    picker.delegate = ImportDelegate(result: result)
    retainDelegate(picker.delegate)
    present(picker, result: result)
  }

  private func present(_ picker: UIDocumentPickerViewController, result: @escaping FlutterResult) {
    guard let presenter = topViewController() else {
      result(FlutterError(code: "no_presenter", message: "当前无可用的展示界面", details: nil))
      return
    }
    presenter.present(picker, animated: true)
  }

  /// UIDocumentPicker 的 delegate 由 UIKit 弱引用，必须显式持有到回调完成。
  private var retainedDelegates: [AnyObject] = []

  private func retainDelegate(_ delegate: AnyObject?) {
    guard let delegate else { return }
    retainedDelegates.append(delegate)
    // 回调结束后由 delegate 自己触发 release（见 Delegate 实现）。
    if let pickerDelegate = delegate as? RetainedPickerDelegate {
      pickerDelegate.onFinish = { [weak self, weak delegate] in
        guard let self, let delegate else { return }
        self.retainedDelegates.removeAll { $0 === delegate }
      }
    }
  }

  private func topViewController() -> UIViewController? {
    if let vc = viewController {
      return topMost(from: vc)
    }
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
    for scene in scenes {
      if let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
        return topMost(from: root)
      }
    }
    return nil
  }

  private func topMost(from controller: UIViewController) -> UIViewController {
    if let presented = controller.presentedViewController {
      return topMost(from: presented)
    }
    if let nav = controller as? UINavigationController, let visible = nav.visibleViewController {
      return topMost(from: visible)
    }
    if let tab = controller as? UITabBarController, let selected = tab.selectedViewController {
      return topMost(from: selected)
    }
    return controller
  }

  // MARK: - 更新（iOS 仅提供版本号）

  private func handleUpdates(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getVersion":
      let info = Bundle.main.infoDictionary
      let name = (info?["CFBundleShortVersionString"] as? String) ?? "未知"
      let build = (info?["CFBundleVersion"] as? String) ?? "0"
      result([
        "versionName": name,
        "versionCode": Int64(build) ?? 0,
      ])
    default:
      // canInstallPackages / openInstallPermissionSettings / installApk
      // 都是 Android APK 专用，iOS 上不存在对应能力。
      result(FlutterMethodNotImplemented)
    }
  }
}

// MARK: - 文档选择器 delegate

protocol RetainedPickerDelegate: AnyObject {
  var onFinish: (() -> Void)? { get set }
}

final class ExportDelegate: NSObject, UIDocumentPickerDelegate, RetainedPickerDelegate {
  private let result: FlutterResult
  var onFinish: (() -> Void)?

  init(result: @escaping FlutterResult) {
    self.result = result
    super.init()
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    result(!urls.isEmpty)
    onFinish?()
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    result(false)
    onFinish?()
  }
}

final class ImportDelegate: NSObject, UIDocumentPickerDelegate, RetainedPickerDelegate {
  private let result: FlutterResult
  var onFinish: (() -> Void)?

  /// 与 Android 侧一致的上限，避免超大文件一次性读进内存。
  private let byteLimit = 128 * 1024 * 1024

  init(result: @escaping FlutterResult) {
    self.result = result
    super.init()
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    defer { onFinish?() }
    guard let url = urls.first else {
      result(nil)
      return
    }
    // asCopy: true 时文件已在临时目录，无需安全作用域访问。
    do {
      let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? nil
      if let size, size > byteLimit {
        result(FlutterError(code: "read_failed", message: "备份文件超过 128MB", details: nil))
        return
      }
      let data = try Data(contentsOf: url)
      result([
        "name": url.lastPathComponent,
        "bytes": FlutterStandardTypedData(bytes: data),
      ])
    } catch {
      result(FlutterError(code: "read_failed", message: error.localizedDescription, details: nil))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    result(nil)
    onFinish?()
  }
}

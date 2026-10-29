/// 原生端（Android / iOS / 桌面）的能力开关。
///
/// 备份依赖 `dart:io` 写文件和原生 MethodChannel 选文件，应用自更新依赖
/// 下载安装包，这些都只在原生端可用。
const bool platformSupportsBackup = true;
const bool platformSupportsAppUpdate = true;
const bool platformSupportsFilePicker = true;

/// Web 端的能力开关。
///
/// 浏览器里没有可写的应用目录，也不能安装新的应用版本：
/// - 备份/恢复留空（用户数据在浏览器存储里，靠导出 JSON 也没地方存）；
/// - 应用更新交给浏览器刷新，不做自更新；
/// - 文件选择交给 `<input type=file>`，但当前没有 Web 备份，一并关闭。
const bool platformSupportsBackup = false;
const bool platformSupportsAppUpdate = false;
const bool platformSupportsFilePicker = false;

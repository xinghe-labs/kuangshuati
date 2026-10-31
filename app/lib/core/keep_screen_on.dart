import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 做题期间让屏幕保持常亮。
///
/// 为什么需要：读一段长材料（上海卷单题材料常在 300 字以上）很容易超过
/// 系统息屏时间（Android 默认 30 秒），屏幕黑掉后要重新解锁，作答节奏
/// 被直接打断。桌面/网页端由系统自己管，不需要也不支持这个能力。
///
/// 走原生 `FLAG_KEEP_SCREEN_ON`，不引入第三方包：效果等价于
/// `wakelock_plus`，但少一个依赖，也不会在无插件环境下抛异常。
class KeepScreenOn {
  KeepScreenOn._();

  static const MethodChannel _channel = MethodChannel(
    'com.kuangshuati.app/screen',
  );

  /// 是否调用过 [enable]。用于在 [disable] 时避免无意义的跨端调用。
  static bool _enabled = false;

  /// 进入做题页时调用。任何异常都吞掉——拿不到屏幕常亮只是体验退化，
  /// 绝不能因为它在真机上闪退或卡住作答。
  static Future<void> enable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _enabled = true;
    try {
      await _channel.invokeMethod<bool>('setKeepScreenOn', {'enabled': true});
    } catch (error) {
      debugPrint('KeepScreenOn.enable failed: $error');
    }
  }

  /// 离开做题页时调用。同样吞掉异常，但要保证 flag 一定被清掉，
  /// 否则用户退出做题后整台手机都不息屏、白耗电。
  static Future<void> disable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!_enabled) return;
    _enabled = false;
    try {
      await _channel.invokeMethod<bool>('setKeepScreenOn', {'enabled': false});
    } catch (error) {
      debugPrint('KeepScreenOn.disable failed: $error');
    }
  }
}

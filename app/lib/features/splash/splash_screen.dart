import 'dart:async';

import 'package:flutter/material.dart';

/// 原生启动页的底色（`android/app/src/main/res/values/launch_colors.xml`）。
///
/// 与 Flutter 启动动效用同一组值，原生图淡出后不会先闪一下别的颜色。
/// 注意深色不是 `AppPalette.dark.paper`（#121210）：这里要对齐的是原生
/// 启动图，进到 App 之后再由主题接管，中间那点色差由淡入遮掉。
const _launchPaperLight = Color(0xFFF4F3EF);
const _launchPaperDark = Color(0xFF171715);

/// 启动动效渲染在 MaterialApp **之上**，那时还没有 MediaQuery，所以直接问
/// 平台调度器。
///
/// 早先这里用 `MediaQuery.maybePlatformBrightnessOf`，拿到的永远是 null
/// （`null == Brightness.dark` 为 false），结果暗色设备上也渲染成亮色，
/// 和原生启动图硬切一下——真机录屏确认过。
bool _isDark() =>
    WidgetsBinding.instance.platformDispatcher.platformBrightness ==
    Brightness.dark;

/// 启动动效：图标淡入 + 轻微放大，下方一条墨色进度线走满。
///
/// 首帧前的工作实测只要约 10 ms，所以这段动效是**故意**留出来的开场，
/// 不是用来掩盖等待的（那部分在提交 25ddfae 里已经从根上修掉了）。
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onFinished});

  /// 动效播完时回调，由 [SplashGate] 用来决定最早什么时候切页。
  final VoidCallback? onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 620);

  late final AnimationController _controller;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _iconScale;
  late final Animation<double> _barProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _total);
    _iconOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.52, curve: Curves.easeOut),
    );
    _iconScale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    // 进度线比图标晚一点起步，读起来像「图标落定 → 开始加载」。
    // 曲线用 easeInOutSine 而不是 easeInOutCubic：后者前段太懒，
    // 280 ms 时只填到 5%，看着像卡住了。
    _barProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.95, curve: Curves.easeInOutSine),
    );
    _controller.forward().whenComplete(() => widget.onFinished?.call());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = _isDark();
    final paper = dark ? _launchPaperDark : _launchPaperLight;
    final ink = dark ? const Color(0xFFE6E5DE) : const Color(0xFF171715);
    final track = dark ? const Color(0xFF2B2B27) : const Color(0xFFE2E1DA);
    return ColoredBox(
      color: paper,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _iconOpacity,
              child: ScaleTransition(
                scale: _iconScale,
                child: Image.asset(
                  'assets/branding/launch_icon.png',
                  width: 132,
                  height: 132,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
            const SizedBox(height: 30),
            // 固定 96 宽的轨道，里面按进度填墨色，不用 LinearProgressIndicator
            // 是为了控制圆角与粗细（它的高度在小尺寸下会糊）。
            Container(
              width: 96,
              height: 3,
              decoration: BoxDecoration(
                color: track,
                borderRadius: BorderRadius.circular(2),
              ),
              child: AnimatedBuilder(
                animation: _barProgress,
                builder: (context, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _barProgress.value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: ink,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 启动闸门：先播 [SplashScreen]，初始化完成后淡入真正的 App。
///
/// 冷启动路径（`ContentManager.initialize` 等）放到首帧之后再跑，所以
/// 启动动效能真的动起来；同时给一个最短展示时长，避免初始化太快导致
/// 图标只闪一帧。
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.bootstrap});

  /// 构建真正的 App 根 widget（内部包着 ProviderScope / MaterialApp）。
  final Future<Widget> Function() bootstrap;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  Widget? _app;
  Object? _error;
  final _animDone = Completer<void>();

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    // 先让动效完整播完，再跑初始化。
    //
    // 顺序很关键：初始化（打开/校验题库）会占住 UI 线程几百毫秒，真机实测
    // 755 ms 一帧都不出。放在前面播动效的话，动画只会渲染出 t=0 那一帧
    // （图标 opacity 0、进度线宽 0 = 一整屏空白纸色），然后直接跳到最后。
    // 放到后面，动效就能正常播完，期间进度线走满、停在满格上等初始化。
    await _animDone.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
    try {
      final app = await widget.bootstrap();
      if (!mounted) return;
      setState(() => _app = app);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _app = null;
    });
    unawaited(_start());
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    final error = _error;
    final Widget child;
    if (app != null) {
      child = KeyedSubtree(key: const ValueKey('app'), child: app);
    } else if (error != null) {
      child = _BootstrapFailure(key: const ValueKey('error'), onRetry: _retry);
    } else {
      child = SplashScreen(
        key: const ValueKey('splash'),
        onFinished: () {
          if (!_animDone.isCompleted) _animDone.complete();
        },
      );
    }
    // 两个页面都是整屏不透明的，交叉淡入的中间帧如果直接合成到黑底上，
    // 整屏会明显发灰一下（真机录屏量到 #F4F2EE -> #BAB8B6）。垫一层纸色
    // 底之后中间帧仍是纸色，只是内容在换。
    final paper = _isDark() ? _launchPaperDark : _launchPaperLight;
    return ColoredBox(
      color: paper,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: child,
      ),
    );
  }
}
/// 初始化失败时的兜底页。以前这种情况会停在原生启动图上（异常在
/// `runApp` 之前抛出，根本没有界面），现在至少能告诉用户发生了什么。
class _BootstrapFailure extends StatelessWidget {
  const _BootstrapFailure({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark();
    final paper = dark ? _launchPaperDark : _launchPaperLight;
    final ink = dark ? const Color(0xFFE6E5DE) : const Color(0xFF171715);
    final muted = dark ? const Color(0xFF8F8E85) : const Color(0xFF74746E);
    return ColoredBox(
      color: paper,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '应用启动失败',
                  style: TextStyle(
                    color: ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '题库或本地数据打不开。可以重试一次，'
                  '仍然不行请在「设置」里反馈。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: onRetry,
                  child: Text('重试', style: TextStyle(color: ink)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

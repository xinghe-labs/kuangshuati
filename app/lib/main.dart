import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: KuangshuatiApp()));
}

class KuangshuatiApp extends ConsumerWidget {
  const KuangshuatiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final scale = ref.watch(fontScaleProvider).value ?? 1;
    return MaterialApp.router(
      title: '狂刷题',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(scale.clamp(0.9, 1.3)),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

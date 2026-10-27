import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'data/content/content_repository.dart';
import 'data/content/full_content_repository.dart';
import 'data/content/seed_content_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await buildKuangshuatiApp());
}

Future<ProviderScope> buildKuangshuatiApp({
  AssetBundle? bundle,
  Directory? supportDirectory,
}) async {
  ContentRepository repository;
  try {
    repository = await FullContentRepository.open(
      bundle: bundle,
      supportDirectory: supportDirectory,
    );
    final stats = await repository.stats();
    debugPrint(
      'Content ${stats.contentVersion}: '
      '${stats.questionCount} questions, ${stats.paperCount} papers',
    );
  } on Exception catch (error, stackTrace) {
    debugPrint('Full content unavailable, using seed data: $error');
    debugPrintStack(stackTrace: stackTrace);
    repository = SeedContentRepository();
  }
  return ProviderScope(
    overrides: [
      contentRepositoryProvider.overrideWith((ref) {
        ref.onDispose(repository.close);
        return repository;
      }),
    ],
    child: const KuangshuatiApp(),
  );
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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/features/content/content_manager.dart';
import 'package:kuangshuati/features/content/content_package_service.dart';

void main() {
  test('network failures show a readable message, not a raw exception', () {
    final message = friendlyContentError(
      const SocketException(
        'Connection refused',
        osError: OSError('Connection refused', 111),
        address: null,
        port: 40792,
      ),
    );

    expect(message, '网络不可用或连接被打断，请检查网络后重试。');
    // 不能把本机端口、errno 这类调试信息倒给用户。
    expect(message.contains('40792'), isFalse);
    expect(message.contains('errno'), isFalse);
    expect(message.contains('SocketException'), isFalse);
  });

  test('package level failures keep their own wording', () {
    // ContentPackageException 的文案本来就是写给用户看的，不应被覆盖。
    expect(
      friendlyContentError(const ContentPackageException('题库校验失败，请重试。')),
      '题库校验失败，请重试。',
    );
  });

  test('storage failures point at device space instead of the network', () {
    expect(
      friendlyContentError(
        const FileSystemException('Cannot write', '/data/app/content.part'),
      ),
      '本机存储不可写或空间不足，请清理空间后重试。',
    );
  });

  test('unknown failures fall back to a neutral retry message', () {
    expect(friendlyContentError(StateError('boom')), '题库处理失败，请重试。');
    expect(friendlyContentError(StateError('boom')).contains('boom'), isFalse);
  });
}

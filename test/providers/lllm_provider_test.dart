import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/providers/lllm_provider.dart';

void main() {
  group('LlmError', () {
    test('stores message and toString returns message', () {
      final error = LlmError('something went wrong');
      expect(error.message, 'something went wrong');
      expect(error.toString(), 'something went wrong');
    });

    test('implements Exception', () {
      final error = LlmError('fail');
      expect(error, isA<Exception>());
    });
  });

  group('LlmProvider', () {
    test('is abstract and requires concrete subclass', () {
      final provider = _FakeLlmProvider();
      expect(provider, isA<LlmProvider>());
    });

    test('generate and generateWithSystem can be overridden', () async {
      final provider = _FakeLlmProvider();
      expect(await provider.generate('hi'), 'generated: hi');
      expect(
        await provider.generateWithSystem('sys', 'user'),
        'system: sys user: user',
      );
    });
  });
}

class _FakeLlmProvider extends LlmProvider {
  @override
  Future<String> generate(String prompt) async => 'generated: $prompt';

  @override
  Future<String> generateWithSystem(String system, String user) async =>
      'system: $system user: $user';
}

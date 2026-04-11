import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';

void main() {
  group('ThreadDefinition', () {
    test('defaults enabled=true and status=idle', () {
      const thread = ThreadDefinition(
        name: 'review',
        path: '/home/user/project',
        layerIds: [1, 2],
      );
      expect(thread.enabled, true);
      expect(thread.status, ThreadStatus.idle);
      expect(thread.contextPrompt, isNull);
    });

    test('holds all fields', () {
      const thread = ThreadDefinition(
        name: 'analysis',
        path: '/data/src',
        layerIds: [1, 2],
        contextPrompt: 'Legal document analysis pipeline',
        enabled: false,
        status: ThreadStatus.completed,
      );
      expect(thread.name, 'analysis');
      expect(thread.path, '/data/src');
      expect(thread.layerIds, [1, 2]);
      expect(thread.contextPrompt, 'Legal document analysis pipeline');
      expect(thread.enabled, false);
      expect(thread.status, ThreadStatus.completed);
    });

    test('copyWith overrides specified fields only', () {
      const thread = ThreadDefinition(
        name: 't1',
        path: '/old',
        layerIds: [1],
        contextPrompt: 'old context',
      );
      final copied = thread.copyWith(
        path: '/new',
        layerIds: [1, 2],
        status: ThreadStatus.running,
      );

      expect(copied.name, 't1');
      expect(copied.path, '/new');
      expect(copied.layerIds, [1, 2]);
      expect(copied.enabled, true);
      expect(copied.status, ThreadStatus.running);
      expect(copied.contextPrompt, 'old context');
    });

    test('copyWith can update contextPrompt', () {
      const thread = ThreadDefinition(
        name: 't1',
        path: '/old',
        layerIds: [1],
        contextPrompt: 'old context',
      );
      final copied = thread.copyWith(contextPrompt: 'new context');
      expect(copied.contextPrompt, 'new context');
    });

    test('statusLabel returns correct labels', () {
      for (final entry in {
        ThreadStatus.idle: 'Idle',
        ThreadStatus.running: 'Running',
        ThreadStatus.completed: 'Completed',
        ThreadStatus.failed: 'Failed',
      }.entries) {
        expect(
          ThreadDefinition(
            name: 't',
            path: '/x',
            layerIds: [],
            status: entry.key,
          ).statusLabel,
          entry.value,
        );
      }
    });
  });
}

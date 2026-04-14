import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';

void main() {
  group('ThreadDefinition', () {
    test('defaults enabled=true and status=idle', () {
      const thread = ThreadDefinition(
        id: 1,
        name: 'review',
        path: '/home/user/project',
      );
      expect(thread.id, 1);
      expect(thread.enabled, true);
      expect(thread.status, ThreadStatus.idle);
      expect(thread.contextPrompt, isNull);
    });

    test('holds all fields', () {
      const thread = ThreadDefinition(
        id: 2,
        name: 'analysis',
        path: '/data/src',
        contextPrompt: 'Legal document analysis pipeline',
        enabled: false,
        status: ThreadStatus.completed,
      );
      expect(thread.id, 2);
      expect(thread.name, 'analysis');
      expect(thread.path, '/data/src');
      expect(thread.contextPrompt, 'Legal document analysis pipeline');
      expect(thread.enabled, false);
      expect(thread.status, ThreadStatus.completed);
    });

    test('copyWith overrides specified fields only', () {
      const thread = ThreadDefinition(
        id: 3,
        name: 't1',
        path: '/old',
        contextPrompt: 'old context',
      );
      final copied = thread.copyWith(
        path: '/new',
        status: ThreadStatus.running,
      );

      expect(copied.id, 3);
      expect(copied.name, 't1');
      expect(copied.path, '/new');
      expect(copied.enabled, true);
      expect(copied.status, ThreadStatus.running);
      expect(copied.contextPrompt, 'old context');
    });

    test('copyWith can update contextPrompt', () {
      const thread = ThreadDefinition(
        id: 4,
        name: 't1',
        path: '/old',
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
            id: 5,
            name: 't',
            path: '/x',
            status: entry.key,
          ).statusLabel,
          entry.value,
        );
      }
    });
  });
}

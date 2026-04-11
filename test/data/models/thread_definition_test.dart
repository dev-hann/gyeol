import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';

void main() {
  group('ThreadDefinition', () {
    test('defaults enabled=true and status=idle', () {
      const thread = ThreadDefinition(
        name: 'review',
        path: '/home/user/project',
        layerNames: ['L1', 'L2'],
      );
      expect(thread.enabled, true);
      expect(thread.status, ThreadStatus.idle);
      expect(thread.contextPrompt, isNull);
    });

    test('holds all fields', () {
      const thread = ThreadDefinition(
        name: 'analysis',
        path: '/data/src',
        layerNames: ['parse', 'analyze'],
        contextPrompt: 'Legal document analysis pipeline',
        enabled: false,
        status: ThreadStatus.completed,
      );
      expect(thread.name, 'analysis');
      expect(thread.path, '/data/src');
      expect(thread.layerNames, ['parse', 'analyze']);
      expect(thread.contextPrompt, 'Legal document analysis pipeline');
      expect(thread.enabled, false);
      expect(thread.status, ThreadStatus.completed);
    });

    test('copyWith overrides specified fields only', () {
      const thread = ThreadDefinition(
        name: 't1',
        path: '/old',
        layerNames: ['A'],
        contextPrompt: 'old context',
      );
      final copied = thread.copyWith(
        path: '/new',
        layerNames: ['A', 'B'],
        status: ThreadStatus.running,
      );

      expect(copied.name, 't1');
      expect(copied.path, '/new');
      expect(copied.layerNames, ['A', 'B']);
      expect(copied.enabled, true);
      expect(copied.status, ThreadStatus.running);
      expect(copied.contextPrompt, 'old context');
    });

    test('copyWith can update contextPrompt', () {
      const thread = ThreadDefinition(
        name: 't1',
        path: '/old',
        layerNames: ['A'],
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
            layerNames: [],
            status: entry.key,
          ).statusLabel,
          entry.value,
        );
      }
    });
  });
}

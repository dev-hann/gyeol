import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/worker_models.dart';

void main() {
  group('WorkerDefinition', () {
    test('required-only constructor sets defaults', () {
      const worker = WorkerDefinition(
        name: 'w1',
        layerId: 1,
        systemPrompt: 'You are a reviewer.',
      );
      expect(worker.name, 'w1');
      expect(worker.layerId, 1);
      expect(worker.systemPrompt, 'You are a reviewer.');
      expect(worker.model, isNull);
      expect(worker.temperature, isNull);
      expect(worker.maxTokens, isNull);
      expect(worker.enabled, isTrue);
    });

    test('all-fields constructor holds every value', () {
      const worker = WorkerDefinition(
        name: 'w2',
        layerId: 2,
        systemPrompt: 'Analyze deeply.',
        model: 'gpt-4o',
        temperature: 0.7,
        maxTokens: 2048,
        enabled: false,
      );
      expect(worker.name, 'w2');
      expect(worker.layerId, 2);
      expect(worker.systemPrompt, 'Analyze deeply.');
      expect(worker.model, 'gpt-4o');
      expect(worker.temperature, 0.7);
      expect(worker.maxTokens, 2048);
      expect(worker.enabled, isFalse);
    });

    test('copyWith overrides specified fields', () {
      const worker = WorkerDefinition(
        name: 'w3',
        layerId: 3,
        systemPrompt: 'Draft content.',
      );
      final copied = worker.copyWith(
        layerId: 4,
        systemPrompt: 'Refine content.',
        model: 'claude-3',
        temperature: 0.5,
        maxTokens: 1024,
        enabled: false,
      );
      expect(copied.name, 'w3');
      expect(copied.layerId, 4);
      expect(copied.systemPrompt, 'Refine content.');
      expect(copied.model, 'claude-3');
      expect(copied.temperature, 0.5);
      expect(copied.maxTokens, 1024);
      expect(copied.enabled, isFalse);
    });

    test('copyWith preserves unspecified fields', () {
      const worker = WorkerDefinition(
        name: 'w4',
        layerId: 5,
        systemPrompt: 'Parse input.',
        model: 'llama3',
        temperature: 0.3,
        maxTokens: 512,
      );
      final copied = worker.copyWith();
      expect(copied.name, 'w4');
      expect(copied.layerId, 5);
      expect(copied.systemPrompt, 'Parse input.');
      expect(copied.model, 'llama3');
      expect(copied.temperature, 0.3);
      expect(copied.maxTokens, 512);
      expect(copied.enabled, isTrue);
    });

    test('copyWith does not expose name parameter', () {
      const worker = WorkerDefinition(
        name: 'immutable',
        layerId: 6,
        systemPrompt: 'prompt',
      );
      final copied = worker.copyWith(layerId: 7);
      expect(copied.name, 'immutable');
    });

    test('equality uses identity (no manual operator override)', () {
      const a = WorkerDefinition(name: 'w5', layerId: 8, systemPrompt: 'p');
      final b = a.copyWith();
      expect(a == b, isFalse);
    });

    test('is constructable as const', () {
      const worker = WorkerDefinition(
        name: 'const-w',
        layerId: 9,
        systemPrompt: 'const prompt',
      );
      expect(worker.name, 'const-w');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/layer_models.dart';

void main() {
  group('LayerDefinition', () {
    test('constructor sets all fields', () {
      const layer = LayerDefinition(
        name: 'parse',
        inputTypes: ['raw'],
        outputTypes: ['structured'],
        layerPrompt: 'Parse input',
        order: 1,
      );

      expect(layer.name, 'parse');
      expect(layer.inputTypes, ['raw']);
      expect(layer.outputTypes, ['structured']);
      expect(layer.layerPrompt, 'Parse input');
      expect(layer.order, 1);
      expect(layer.enabled, true);
    });

    test('constructor defaults optional fields', () {
      const layer = LayerDefinition(
        name: 'eval',
        inputTypes: [],
        outputTypes: [],
      );

      expect(layer.layerPrompt, isNull);
      expect(layer.order, 0);
      expect(layer.enabled, true);
    });

    test('is a const-constructible class', () {
      const layer = LayerDefinition(
        name: 'x',
        inputTypes: ['a'],
        outputTypes: ['b'],
      );

      expect(layer, isA<LayerDefinition>());
    });

    test('copyWith overrides specified fields', () {
      const original = LayerDefinition(
        name: 'parse',
        inputTypes: ['raw'],
        outputTypes: ['structured'],
        layerPrompt: 'original prompt',
        order: 1,
      );

      final copied = original.copyWith(
        inputTypes: ['text'],
        outputTypes: ['json'],
        layerPrompt: 'new prompt',
        order: 2,
        enabled: false,
      );

      expect(copied.name, 'parse');
      expect(copied.inputTypes, ['text']);
      expect(copied.outputTypes, ['json']);
      expect(copied.layerPrompt, 'new prompt');
      expect(copied.order, 2);
      expect(copied.enabled, false);
    });

    test('copyWith preserves fields when not specified', () {
      const original = LayerDefinition(
        name: 'parse',
        inputTypes: ['raw'],
        outputTypes: ['structured'],
        layerPrompt: 'prompt',
        order: 3,
        enabled: false,
      );

      final copied = original.copyWith();

      expect(copied.name, original.name);
      expect(copied.inputTypes, original.inputTypes);
      expect(copied.outputTypes, original.outputTypes);
      expect(copied.layerPrompt, original.layerPrompt);
      expect(copied.order, original.order);
      expect(copied.enabled, original.enabled);
    });

    test('copyWith layerPrompt keeps original when not specified', () {
      const original = LayerDefinition(
        name: 'parse',
        inputTypes: ['raw'],
        outputTypes: ['structured'],
        layerPrompt: 'old prompt',
      );

      final copied = original.copyWith(order: 5);

      expect(copied.name, 'parse');
      expect(copied.layerPrompt, 'old prompt');
      expect(copied.order, 5);
    });

    test('inputTypes and outputTypes are independent lists', () {
      const layer = LayerDefinition(
        name: 'test',
        inputTypes: ['a', 'b'],
        outputTypes: ['c', 'd', 'e'],
      );

      expect(layer.inputTypes, hasLength(2));
      expect(layer.outputTypes, hasLength(3));
      expect(layer.inputTypes, containsAll(['a', 'b']));
      expect(layer.outputTypes, containsAll(['c', 'd', 'e']));
    });

    test(
      'two instances with same values are not identical (no value equality)',
      () {
        const a = LayerDefinition(
          name: 'parse',
          inputTypes: ['raw'],
          outputTypes: ['structured'],
        );
        const b = LayerDefinition(
          name: 'parse',
          inputTypes: ['raw'],
          outputTypes: ['structured'],
        );

        expect(identical(a, b), true);
      },
    );

    test('order can be negative', () {
      const layer = LayerDefinition(
        name: 'pre',
        inputTypes: [],
        outputTypes: [],
        order: -1,
      );

      expect(layer.order, -1);
    });

    test('enabled can be false', () {
      const layer = LayerDefinition(
        name: 'disabled',
        inputTypes: [],
        outputTypes: [],
        enabled: false,
      );

      expect(layer.enabled, false);
    });
  });
}

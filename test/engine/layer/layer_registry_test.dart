import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/layer_models.dart';
import 'package:gyeol/engine/layer_registry.dart';

void main() {
  group('LayerRegistry', () {
    late LayerRegistry registry;

    setUp(() {
      registry = LayerRegistry();
    });

    LayerDefinition mkLayer({
      required String name,
      List<String> inputTypes = const ['text'],
      List<String> outputTypes = const ['text'],
      int order = 0,
      bool enabled = true,
    }) {
      return LayerDefinition(
        id: 0,
        threadId: 1,
        name: name,
        inputTypes: inputTypes,
        outputTypes: outputTypes,
        order: order,
        enabled: enabled,
      );
    }

    group('register', () {
      test('adds single layer', () {
        registry.register(mkLayer(name: 'a'));
        expect(registry.findByInputType('text').length, 1);
      });

      test('sorts layers by order', () {
        registry
          ..register(mkLayer(name: 'b', order: 2))
          ..register(mkLayer(name: 'a', order: 1));
        final result = registry.findByInputType('text');
        expect(result.map((l) => l.name), ['a', 'b']);
      });

      test('replaces layer with same name', () {
        registry
          ..register(mkLayer(name: 'x', order: 1))
          ..register(mkLayer(name: 'x', order: 5, inputTypes: ['image']));
        expect(registry.findByInputType('text'), isEmpty);
        expect(registry.findByInputType('image').length, 1);
      });
    });

    group('remove', () {
      test('removes existing layer', () {
        registry
          ..register(mkLayer(name: 'target'))
          ..remove('target');
        expect(registry.findByInputType('text'), isEmpty);
      });

      test('no-op for non-existent name', () {
        registry
          ..register(mkLayer(name: 'a'))
          ..remove('missing');
        expect(registry.findByInputType('text').length, 1);
      });
    });

    group('setAll', () {
      test('replaces all layers and sorts by order', () {
        registry
          ..register(mkLayer(name: 'old'))
          ..setAll([
            mkLayer(name: 'c', order: 3),
            mkLayer(name: 'a', order: 1),
            mkLayer(name: 'b', order: 2),
          ]);
        final result = registry.findByInputType('text');
        expect(result.map((l) => l.name), ['a', 'b', 'c']);
      });
    });

    group('findByInputType', () {
      test('returns only enabled layers', () {
        registry
          ..register(mkLayer(name: 'on'))
          ..register(mkLayer(name: 'off', enabled: false));
        final result = registry.findByInputType('text');
        expect(result.length, 1);
        expect(result.first.name, 'on');
      });

      test('filters by input type', () {
        registry
          ..register(mkLayer(name: 'text', inputTypes: ['text']))
          ..register(mkLayer(name: 'image', inputTypes: ['image']));
        expect(registry.findByInputType('text').first.name, 'text');
        expect(registry.findByInputType('image').first.name, 'image');
        expect(registry.findByInputType('audio'), isEmpty);
      });

      test('returns results sorted by order', () {
        registry
          ..register(mkLayer(name: 'z', order: 3))
          ..register(mkLayer(name: 'a', order: 1))
          ..register(mkLayer(name: 'm', order: 2));
        final result = registry.findByInputType('text');
        expect(result.map((l) => l.name), ['a', 'm', 'z']);
      });

      test('returns empty for no match', () {
        registry.register(mkLayer(name: 'x', inputTypes: ['image']));
        expect(registry.findByInputType('text'), isEmpty);
      });
    });
  });
}

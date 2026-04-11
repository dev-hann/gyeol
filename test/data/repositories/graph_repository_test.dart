import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/repositories/graph_repository.dart';

void main() {
  late AppDatabase db;
  late GraphRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = GraphRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('loadNodePositions', () {
    test('returns empty when no data stored', () async {
      final positions = await repo.loadNodePositions();
      expect(positions, isEmpty);
    });

    test('round-trips multiple node positions', () async {
      final original = <String, Offset>{
        'node-a': const Offset(10.5, 20),
        'node-b': const Offset(0, -5.3),
        'node-c': const Offset(100, 200),
      };
      await repo.saveNodePositions(original);

      final loaded = await repo.loadNodePositions();
      expect(loaded, equals(original));
    });

    test('returns empty on malformed JSON', () async {
      await db.saveUiState('graph_node_positions', 'not-valid-json{{{');

      final positions = await repo.loadNodePositions();
      expect(positions, isEmpty);
    });

    test('returns empty when stored value is not a map', () async {
      await db.saveUiState('graph_node_positions', '"a_string"');

      final positions = await repo.loadNodePositions();
      expect(positions, isEmpty);
    });

    test('skips entries where value is not a list', () async {
      await db.saveUiState(
        'graph_node_positions',
        '{"good":[1.0,2.0],"bad":"not_a_list"}',
      );

      final positions = await repo.loadNodePositions();
      expect(positions, hasLength(1));
      expect(positions['good'], const Offset(1, 2));
    });

    test('skips entries where list has fewer than 2 elements', () async {
      await db.saveUiState(
        'graph_node_positions',
        '{"a":[1.0],"b":[],"c":[3.0,4.0]}',
      );

      final positions = await repo.loadNodePositions();
      expect(positions, hasLength(1));
      expect(positions['c'], const Offset(3, 4));
    });

    test('skips entries where elements are not numbers', () async {
      await db.saveUiState(
        'graph_node_positions',
        '{"a":["x","y"],"b":[1.0,2.0]}',
      );

      final positions = await repo.loadNodePositions();
      expect(positions, hasLength(1));
      expect(positions['b'], const Offset(1, 2));
    });
  });

  group('saveNodePositions', () {
    test('overwrites previous positions', () async {
      await repo.saveNodePositions({'n1': const Offset(1, 1)});
      await repo.saveNodePositions({'n2': const Offset(2, 2)});

      final loaded = await repo.loadNodePositions();
      expect(loaded, hasLength(1));
      expect(loaded['n2'], const Offset(2, 2));
    });

    test('stores empty map as valid JSON', () async {
      await repo.saveNodePositions({});

      final raw = await db.getUiState('graph_node_positions');
      expect(raw, isNotNull);
      expect(jsonDecode(raw!), isA<Map<String, dynamic>>());
    });
  });

  group('loadViewport', () {
    test('returns default when no data stored', () async {
      final viewport = await repo.loadViewport();
      expect(viewport, (0.0, 0.0, 1.0));
    });

    test('round-trips viewport values', () async {
      await repo.saveViewport(-10.5, 42.3, 2.5);

      final viewport = await repo.loadViewport();
      expect(viewport, (-10.5, 42.3, 2.5));
    });

    test('returns default on malformed JSON', () async {
      await db.saveUiState('graph_viewport', 'not-json{{{');

      final viewport = await repo.loadViewport();
      expect(viewport, (0.0, 0.0, 1.0));
    });

    test('returns default when stored value is not a map', () async {
      await db.saveUiState('graph_viewport', '42');

      final viewport = await repo.loadViewport();
      expect(viewport, (0.0, 0.0, 1.0));
    });

    test('uses defaults for missing or non-numeric fields', () async {
      await db.saveUiState('graph_viewport', '{"x":"bad","y":null}');

      final viewport = await repo.loadViewport();
      expect(viewport.$1, 0.0);
      expect(viewport.$2, 0.0);
      expect(viewport.$3, 1.0);
    });
  });

  group('saveViewport', () {
    test('overwrites previous viewport', () async {
      await repo.saveViewport(1, 2, 3);
      await repo.saveViewport(4, 5, 6);

      final viewport = await repo.loadViewport();
      expect(viewport, (4.0, 5.0, 6.0));
    });
  });
}

import 'package:drift/drift.dart';

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get taskType => text()();
  TextColumn get payload => text()();
  TextColumn get priority => text()();
  TextColumn get status => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get maxRetries => integer().withDefault(const Constant(3))();
  IntColumn get depth => integer().withDefault(const Constant(0))();
  IntColumn get parentTaskId => integer().nullable().customConstraint(
    'REFERENCES tasks(id) ON DELETE CASCADE',
  )();
  IntColumn get layerId => integer().nullable().customConstraint(
    'REFERENCES layers(id) ON DELETE SET NULL',
  )();
  IntColumn get workerId => integer().nullable().customConstraint(
    'REFERENCES workers(id) ON DELETE SET NULL',
  )();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
}

class Layers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().customConstraint('UNIQUE NOT NULL')();
  TextColumn get inputTypes => text()();
  TextColumn get outputTypes => text()();
  TextColumn get layerPrompt => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
}

class Workers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().customConstraint('UNIQUE NOT NULL')();
  IntColumn get layerId => integer().customConstraint(
    'NOT NULL REFERENCES layers(id) ON DELETE CASCADE',
  )();
  TextColumn get systemPrompt => text()();
  TextColumn get model => text().nullable()();
  RealColumn get temperature => real().nullable()();
  IntColumn get maxTokens => integer().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class Threads extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().customConstraint('UNIQUE NOT NULL')();
  TextColumn get path => text()();
  TextColumn get contextPrompt => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get status => text().withDefault(const Constant('idle'))();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
}

@DataClassName('ThreadLayer')
class ThreadLayers extends Table {
  IntColumn get threadId => integer().customConstraint(
    'NOT NULL REFERENCES threads(id) ON DELETE CASCADE',
  )();
  IntColumn get layerId => integer().customConstraint(
    'NOT NULL REFERENCES layers(id) ON DELETE CASCADE',
  )();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {threadId, layerId};
}

class LayerConnections extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sourceLayerId => integer().customConstraint(
    'NOT NULL REFERENCES layers(id) ON DELETE CASCADE',
  )();
  IntColumn get targetLayerId => integer().customConstraint(
    'NOT NULL REFERENCES layers(id) ON DELETE CASCADE',
  )();

  @override
  List<Set<Column>> get uniqueKeys => [
    {sourceLayerId, targetLayerId},
  ];
}

class ExecutionLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId => integer().customConstraint(
    'NOT NULL REFERENCES tasks(id) ON DELETE CASCADE',
  )();
  IntColumn get workerId => integer().nullable()();
  TextColumn get status => text()();
  TextColumn get message => text().nullable()();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
}

@DataClassName('ChatConversationRow')
class ChatConversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ChatMessageRow')
class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().customConstraint(
    'NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE',
  )();
  TextColumn get role => text()();
  TextColumn get content => text()();
  TextColumn get toolName => text().nullable()();
  TextColumn get toolCallId => text().nullable()();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('UiStateRow')
class UiStates extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

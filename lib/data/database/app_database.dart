import 'package:drift/drift.dart';

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get taskType => text()();
  TextColumn get payload => text()();
  TextColumn get priority => text()();
  TextColumn get status => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get maxRetries => integer().withDefault(const Constant(3))();
  IntColumn get depth => integer().withDefault(const Constant(0))();
  TextColumn get parentTaskId => text().nullable()();
  TextColumn get layerName => text().nullable()();
  TextColumn get workerName => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Layers extends Table {
  TextColumn get name => text()();
  TextColumn get inputTypes => text()();
  TextColumn get outputTypes => text()();
  TextColumn get layerPrompt => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {name};
}

class Workers extends Table {
  TextColumn get name => text()();
  TextColumn get layerName => text()();
  TextColumn get systemPrompt => text()();
  TextColumn get model => text().nullable()();
  RealColumn get temperature => real().nullable()();
  IntColumn get maxTokens => integer().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {name};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class Threads extends Table {
  TextColumn get name => text()();
  TextColumn get path => text()();
  TextColumn get layerNames => text()();
  TextColumn get contextPrompt => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get status => text().withDefault(const Constant('idle'))();

  @override
  Set<Column> get primaryKey => {name};
}

class ExecutionLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get taskId => text()();
  TextColumn get workerName => text().nullable()();
  TextColumn get status => text()();
  TextColumn get message => text().nullable()();
  IntColumn get createdAt => integer()();
}

@DataClassName('ChatConversationRow')
class ChatConversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ChatMessageRow')
class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get role => text()();
  TextColumn get content => text()();
  TextColumn get toolName => text().nullable()();
  TextColumn get toolCallId => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

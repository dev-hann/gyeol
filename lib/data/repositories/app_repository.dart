import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/repositories/chat_repository.dart';
import 'package:gyeol/data/repositories/connection_repository.dart';
import 'package:gyeol/data/repositories/graph_repository.dart';
import 'package:gyeol/data/repositories/layer_repository.dart';
import 'package:gyeol/data/repositories/log_repository.dart';
import 'package:gyeol/data/repositories/settings_repository.dart';
import 'package:gyeol/data/repositories/task_repository.dart';
import 'package:gyeol/data/repositories/thread_repository.dart';
import 'package:gyeol/data/repositories/worker_repository.dart';

export 'chat_repository.dart';
export 'connection_repository.dart';
export 'graph_repository.dart';
export 'layer_repository.dart';
export 'log_repository.dart';
export 'settings_repository.dart';
export 'task_repository.dart';
export 'thread_repository.dart';
export 'worker_repository.dart';

class AppRepository {
  AppRepository(this._db);
  final AppDatabase _db;

  late final TaskRepository tasks = TaskRepository(_db);
  late final LayerRepository layers = LayerRepository(_db);
  late final WorkerRepository workers = WorkerRepository(_db);
  late final ThreadRepository threads = ThreadRepository(_db);
  late final SettingsRepository settings = SettingsRepository(_db);
  late final GraphRepository graph = GraphRepository(_db);
  late final LogRepository logs = LogRepository(_db);
  late final ChatRepository chat = ChatRepository(_db);
  late final ConnectionRepository connections = ConnectionRepository(_db);
}

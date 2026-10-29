import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// 原生端的用户库连接：`drift_flutter` 会落到应用文档目录下的 `user.db`。
QueryExecutor openUserDatabase({required String name}) =>
    driftDatabase(name: name);

import 'dart:convert';

import 'app_database.dart' as db;

extension SessionAnswerSelection on db.SessionAnswer {
  Set<String> get selected {
    try {
      final decoded = jsonDecode(selectedJson);
      if (decoded is! List) return {};
      return decoded.whereType<String>().toSet();
    } on FormatException {
      return {};
    }
  }
}

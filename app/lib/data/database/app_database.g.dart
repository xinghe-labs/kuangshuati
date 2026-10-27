// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PracticeSessionsTable extends PracticeSessions
    with TableInfo<$PracticeSessionsTable, PracticeSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paperIdMeta = const VerificationMeta(
    'paperId',
  );
  @override
  late final GeneratedColumn<String> paperId = GeneratedColumn<String>(
    'paper_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filtersJsonMeta = const VerificationMeta(
    'filtersJson',
  );
  @override
  late final GeneratedColumn<String> filtersJson = GeneratedColumn<String>(
    'filters_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _questionIdsJsonMeta = const VerificationMeta(
    'questionIdsJson',
  );
  @override
  late final GeneratedColumn<String> questionIdsJson = GeneratedColumn<String>(
    'question_ids_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentIndexMeta = const VerificationMeta(
    'currentIndex',
  );
  @override
  late final GeneratedColumn<int> currentIndex = GeneratedColumn<int>(
    'current_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _requestedCountMeta = const VerificationMeta(
    'requestedCount',
  );
  @override
  late final GeneratedColumn<int> requestedCount = GeneratedColumn<int>(
    'requested_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actualCountMeta = const VerificationMeta(
    'actualCount',
  );
  @override
  late final GeneratedColumn<int> actualCount = GeneratedColumn<int>(
    'actual_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeLimitSecondsMeta = const VerificationMeta(
    'timeLimitSeconds',
  );
  @override
  late final GeneratedColumn<int> timeLimitSeconds = GeneratedColumn<int>(
    'time_limit_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deadlineAtMeta = const VerificationMeta(
    'deadlineAt',
  );
  @override
  late final GeneratedColumn<int> deadlineAt = GeneratedColumn<int>(
    'deadline_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revealModeMeta = const VerificationMeta(
    'revealMode',
  );
  @override
  late final GeneratedColumn<String> revealMode = GeneratedColumn<String>(
    'reveal_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finalizedAtMeta = const VerificationMeta(
    'finalizedAt',
  );
  @override
  late final GeneratedColumn<int> finalizedAt = GeneratedColumn<int>(
    'finalized_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentVersionMeta = const VerificationMeta(
    'contentVersion',
  );
  @override
  late final GeneratedColumn<String> contentVersion = GeneratedColumn<String>(
    'content_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('demo-1'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mode,
    title,
    paperId,
    filtersJson,
    questionIdsJson,
    currentIndex,
    requestedCount,
    actualCount,
    timeLimitSeconds,
    durationMs,
    deadlineAt,
    revealMode,
    status,
    createdAt,
    updatedAt,
    finalizedAt,
    contentVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('paper_id')) {
      context.handle(
        _paperIdMeta,
        paperId.isAcceptableOrUnknown(data['paper_id']!, _paperIdMeta),
      );
    }
    if (data.containsKey('filters_json')) {
      context.handle(
        _filtersJsonMeta,
        filtersJson.isAcceptableOrUnknown(
          data['filters_json']!,
          _filtersJsonMeta,
        ),
      );
    }
    if (data.containsKey('question_ids_json')) {
      context.handle(
        _questionIdsJsonMeta,
        questionIdsJson.isAcceptableOrUnknown(
          data['question_ids_json']!,
          _questionIdsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_questionIdsJsonMeta);
    }
    if (data.containsKey('current_index')) {
      context.handle(
        _currentIndexMeta,
        currentIndex.isAcceptableOrUnknown(
          data['current_index']!,
          _currentIndexMeta,
        ),
      );
    }
    if (data.containsKey('requested_count')) {
      context.handle(
        _requestedCountMeta,
        requestedCount.isAcceptableOrUnknown(
          data['requested_count']!,
          _requestedCountMeta,
        ),
      );
    }
    if (data.containsKey('actual_count')) {
      context.handle(
        _actualCountMeta,
        actualCount.isAcceptableOrUnknown(
          data['actual_count']!,
          _actualCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_actualCountMeta);
    }
    if (data.containsKey('time_limit_seconds')) {
      context.handle(
        _timeLimitSecondsMeta,
        timeLimitSeconds.isAcceptableOrUnknown(
          data['time_limit_seconds']!,
          _timeLimitSecondsMeta,
        ),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('deadline_at')) {
      context.handle(
        _deadlineAtMeta,
        deadlineAt.isAcceptableOrUnknown(data['deadline_at']!, _deadlineAtMeta),
      );
    }
    if (data.containsKey('reveal_mode')) {
      context.handle(
        _revealModeMeta,
        revealMode.isAcceptableOrUnknown(data['reveal_mode']!, _revealModeMeta),
      );
    } else if (isInserting) {
      context.missing(_revealModeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('finalized_at')) {
      context.handle(
        _finalizedAtMeta,
        finalizedAt.isAcceptableOrUnknown(
          data['finalized_at']!,
          _finalizedAtMeta,
        ),
      );
    }
    if (data.containsKey('content_version')) {
      context.handle(
        _contentVersionMeta,
        contentVersion.isAcceptableOrUnknown(
          data['content_version']!,
          _contentVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      paperId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paper_id'],
      ),
      filtersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filters_json'],
      )!,
      questionIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_ids_json'],
      )!,
      currentIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_index'],
      )!,
      requestedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}requested_count'],
      ),
      actualCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actual_count'],
      )!,
      timeLimitSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_limit_seconds'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      deadlineAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deadline_at'],
      ),
      revealMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reveal_mode'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      finalizedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}finalized_at'],
      ),
      contentVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_version'],
      )!,
    );
  }

  @override
  $PracticeSessionsTable createAlias(String alias) {
    return $PracticeSessionsTable(attachedDatabase, alias);
  }
}

class PracticeSession extends DataClass implements Insertable<PracticeSession> {
  final String id;
  final String mode;
  final String title;
  final String? paperId;
  final String filtersJson;
  final String questionIdsJson;
  final int currentIndex;
  final int? requestedCount;
  final int actualCount;
  final int? timeLimitSeconds;
  final int durationMs;
  final int? deadlineAt;
  final String revealMode;
  final String status;
  final int createdAt;
  final int updatedAt;
  final int? finalizedAt;
  final String contentVersion;
  const PracticeSession({
    required this.id,
    required this.mode,
    required this.title,
    this.paperId,
    required this.filtersJson,
    required this.questionIdsJson,
    required this.currentIndex,
    this.requestedCount,
    required this.actualCount,
    this.timeLimitSeconds,
    required this.durationMs,
    this.deadlineAt,
    required this.revealMode,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.finalizedAt,
    required this.contentVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mode'] = Variable<String>(mode);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || paperId != null) {
      map['paper_id'] = Variable<String>(paperId);
    }
    map['filters_json'] = Variable<String>(filtersJson);
    map['question_ids_json'] = Variable<String>(questionIdsJson);
    map['current_index'] = Variable<int>(currentIndex);
    if (!nullToAbsent || requestedCount != null) {
      map['requested_count'] = Variable<int>(requestedCount);
    }
    map['actual_count'] = Variable<int>(actualCount);
    if (!nullToAbsent || timeLimitSeconds != null) {
      map['time_limit_seconds'] = Variable<int>(timeLimitSeconds);
    }
    map['duration_ms'] = Variable<int>(durationMs);
    if (!nullToAbsent || deadlineAt != null) {
      map['deadline_at'] = Variable<int>(deadlineAt);
    }
    map['reveal_mode'] = Variable<String>(revealMode);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || finalizedAt != null) {
      map['finalized_at'] = Variable<int>(finalizedAt);
    }
    map['content_version'] = Variable<String>(contentVersion);
    return map;
  }

  PracticeSessionsCompanion toCompanion(bool nullToAbsent) {
    return PracticeSessionsCompanion(
      id: Value(id),
      mode: Value(mode),
      title: Value(title),
      paperId: paperId == null && nullToAbsent
          ? const Value.absent()
          : Value(paperId),
      filtersJson: Value(filtersJson),
      questionIdsJson: Value(questionIdsJson),
      currentIndex: Value(currentIndex),
      requestedCount: requestedCount == null && nullToAbsent
          ? const Value.absent()
          : Value(requestedCount),
      actualCount: Value(actualCount),
      timeLimitSeconds: timeLimitSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(timeLimitSeconds),
      durationMs: Value(durationMs),
      deadlineAt: deadlineAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deadlineAt),
      revealMode: Value(revealMode),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      finalizedAt: finalizedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finalizedAt),
      contentVersion: Value(contentVersion),
    );
  }

  factory PracticeSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeSession(
      id: serializer.fromJson<String>(json['id']),
      mode: serializer.fromJson<String>(json['mode']),
      title: serializer.fromJson<String>(json['title']),
      paperId: serializer.fromJson<String?>(json['paperId']),
      filtersJson: serializer.fromJson<String>(json['filtersJson']),
      questionIdsJson: serializer.fromJson<String>(json['questionIdsJson']),
      currentIndex: serializer.fromJson<int>(json['currentIndex']),
      requestedCount: serializer.fromJson<int?>(json['requestedCount']),
      actualCount: serializer.fromJson<int>(json['actualCount']),
      timeLimitSeconds: serializer.fromJson<int?>(json['timeLimitSeconds']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      deadlineAt: serializer.fromJson<int?>(json['deadlineAt']),
      revealMode: serializer.fromJson<String>(json['revealMode']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      finalizedAt: serializer.fromJson<int?>(json['finalizedAt']),
      contentVersion: serializer.fromJson<String>(json['contentVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mode': serializer.toJson<String>(mode),
      'title': serializer.toJson<String>(title),
      'paperId': serializer.toJson<String?>(paperId),
      'filtersJson': serializer.toJson<String>(filtersJson),
      'questionIdsJson': serializer.toJson<String>(questionIdsJson),
      'currentIndex': serializer.toJson<int>(currentIndex),
      'requestedCount': serializer.toJson<int?>(requestedCount),
      'actualCount': serializer.toJson<int>(actualCount),
      'timeLimitSeconds': serializer.toJson<int?>(timeLimitSeconds),
      'durationMs': serializer.toJson<int>(durationMs),
      'deadlineAt': serializer.toJson<int?>(deadlineAt),
      'revealMode': serializer.toJson<String>(revealMode),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'finalizedAt': serializer.toJson<int?>(finalizedAt),
      'contentVersion': serializer.toJson<String>(contentVersion),
    };
  }

  PracticeSession copyWith({
    String? id,
    String? mode,
    String? title,
    Value<String?> paperId = const Value.absent(),
    String? filtersJson,
    String? questionIdsJson,
    int? currentIndex,
    Value<int?> requestedCount = const Value.absent(),
    int? actualCount,
    Value<int?> timeLimitSeconds = const Value.absent(),
    int? durationMs,
    Value<int?> deadlineAt = const Value.absent(),
    String? revealMode,
    String? status,
    int? createdAt,
    int? updatedAt,
    Value<int?> finalizedAt = const Value.absent(),
    String? contentVersion,
  }) => PracticeSession(
    id: id ?? this.id,
    mode: mode ?? this.mode,
    title: title ?? this.title,
    paperId: paperId.present ? paperId.value : this.paperId,
    filtersJson: filtersJson ?? this.filtersJson,
    questionIdsJson: questionIdsJson ?? this.questionIdsJson,
    currentIndex: currentIndex ?? this.currentIndex,
    requestedCount: requestedCount.present
        ? requestedCount.value
        : this.requestedCount,
    actualCount: actualCount ?? this.actualCount,
    timeLimitSeconds: timeLimitSeconds.present
        ? timeLimitSeconds.value
        : this.timeLimitSeconds,
    durationMs: durationMs ?? this.durationMs,
    deadlineAt: deadlineAt.present ? deadlineAt.value : this.deadlineAt,
    revealMode: revealMode ?? this.revealMode,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    finalizedAt: finalizedAt.present ? finalizedAt.value : this.finalizedAt,
    contentVersion: contentVersion ?? this.contentVersion,
  );
  PracticeSession copyWithCompanion(PracticeSessionsCompanion data) {
    return PracticeSession(
      id: data.id.present ? data.id.value : this.id,
      mode: data.mode.present ? data.mode.value : this.mode,
      title: data.title.present ? data.title.value : this.title,
      paperId: data.paperId.present ? data.paperId.value : this.paperId,
      filtersJson: data.filtersJson.present
          ? data.filtersJson.value
          : this.filtersJson,
      questionIdsJson: data.questionIdsJson.present
          ? data.questionIdsJson.value
          : this.questionIdsJson,
      currentIndex: data.currentIndex.present
          ? data.currentIndex.value
          : this.currentIndex,
      requestedCount: data.requestedCount.present
          ? data.requestedCount.value
          : this.requestedCount,
      actualCount: data.actualCount.present
          ? data.actualCount.value
          : this.actualCount,
      timeLimitSeconds: data.timeLimitSeconds.present
          ? data.timeLimitSeconds.value
          : this.timeLimitSeconds,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      deadlineAt: data.deadlineAt.present
          ? data.deadlineAt.value
          : this.deadlineAt,
      revealMode: data.revealMode.present
          ? data.revealMode.value
          : this.revealMode,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      finalizedAt: data.finalizedAt.present
          ? data.finalizedAt.value
          : this.finalizedAt,
      contentVersion: data.contentVersion.present
          ? data.contentVersion.value
          : this.contentVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeSession(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('title: $title, ')
          ..write('paperId: $paperId, ')
          ..write('filtersJson: $filtersJson, ')
          ..write('questionIdsJson: $questionIdsJson, ')
          ..write('currentIndex: $currentIndex, ')
          ..write('requestedCount: $requestedCount, ')
          ..write('actualCount: $actualCount, ')
          ..write('timeLimitSeconds: $timeLimitSeconds, ')
          ..write('durationMs: $durationMs, ')
          ..write('deadlineAt: $deadlineAt, ')
          ..write('revealMode: $revealMode, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('finalizedAt: $finalizedAt, ')
          ..write('contentVersion: $contentVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mode,
    title,
    paperId,
    filtersJson,
    questionIdsJson,
    currentIndex,
    requestedCount,
    actualCount,
    timeLimitSeconds,
    durationMs,
    deadlineAt,
    revealMode,
    status,
    createdAt,
    updatedAt,
    finalizedAt,
    contentVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeSession &&
          other.id == this.id &&
          other.mode == this.mode &&
          other.title == this.title &&
          other.paperId == this.paperId &&
          other.filtersJson == this.filtersJson &&
          other.questionIdsJson == this.questionIdsJson &&
          other.currentIndex == this.currentIndex &&
          other.requestedCount == this.requestedCount &&
          other.actualCount == this.actualCount &&
          other.timeLimitSeconds == this.timeLimitSeconds &&
          other.durationMs == this.durationMs &&
          other.deadlineAt == this.deadlineAt &&
          other.revealMode == this.revealMode &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.finalizedAt == this.finalizedAt &&
          other.contentVersion == this.contentVersion);
}

class PracticeSessionsCompanion extends UpdateCompanion<PracticeSession> {
  final Value<String> id;
  final Value<String> mode;
  final Value<String> title;
  final Value<String?> paperId;
  final Value<String> filtersJson;
  final Value<String> questionIdsJson;
  final Value<int> currentIndex;
  final Value<int?> requestedCount;
  final Value<int> actualCount;
  final Value<int?> timeLimitSeconds;
  final Value<int> durationMs;
  final Value<int?> deadlineAt;
  final Value<String> revealMode;
  final Value<String> status;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> finalizedAt;
  final Value<String> contentVersion;
  final Value<int> rowid;
  const PracticeSessionsCompanion({
    this.id = const Value.absent(),
    this.mode = const Value.absent(),
    this.title = const Value.absent(),
    this.paperId = const Value.absent(),
    this.filtersJson = const Value.absent(),
    this.questionIdsJson = const Value.absent(),
    this.currentIndex = const Value.absent(),
    this.requestedCount = const Value.absent(),
    this.actualCount = const Value.absent(),
    this.timeLimitSeconds = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.deadlineAt = const Value.absent(),
    this.revealMode = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.finalizedAt = const Value.absent(),
    this.contentVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeSessionsCompanion.insert({
    required String id,
    required String mode,
    required String title,
    this.paperId = const Value.absent(),
    this.filtersJson = const Value.absent(),
    required String questionIdsJson,
    this.currentIndex = const Value.absent(),
    this.requestedCount = const Value.absent(),
    required int actualCount,
    this.timeLimitSeconds = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.deadlineAt = const Value.absent(),
    required String revealMode,
    this.status = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.finalizedAt = const Value.absent(),
    this.contentVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mode = Value(mode),
       title = Value(title),
       questionIdsJson = Value(questionIdsJson),
       actualCount = Value(actualCount),
       revealMode = Value(revealMode),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PracticeSession> custom({
    Expression<String>? id,
    Expression<String>? mode,
    Expression<String>? title,
    Expression<String>? paperId,
    Expression<String>? filtersJson,
    Expression<String>? questionIdsJson,
    Expression<int>? currentIndex,
    Expression<int>? requestedCount,
    Expression<int>? actualCount,
    Expression<int>? timeLimitSeconds,
    Expression<int>? durationMs,
    Expression<int>? deadlineAt,
    Expression<String>? revealMode,
    Expression<String>? status,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? finalizedAt,
    Expression<String>? contentVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mode != null) 'mode': mode,
      if (title != null) 'title': title,
      if (paperId != null) 'paper_id': paperId,
      if (filtersJson != null) 'filters_json': filtersJson,
      if (questionIdsJson != null) 'question_ids_json': questionIdsJson,
      if (currentIndex != null) 'current_index': currentIndex,
      if (requestedCount != null) 'requested_count': requestedCount,
      if (actualCount != null) 'actual_count': actualCount,
      if (timeLimitSeconds != null) 'time_limit_seconds': timeLimitSeconds,
      if (durationMs != null) 'duration_ms': durationMs,
      if (deadlineAt != null) 'deadline_at': deadlineAt,
      if (revealMode != null) 'reveal_mode': revealMode,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (finalizedAt != null) 'finalized_at': finalizedAt,
      if (contentVersion != null) 'content_version': contentVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? mode,
    Value<String>? title,
    Value<String?>? paperId,
    Value<String>? filtersJson,
    Value<String>? questionIdsJson,
    Value<int>? currentIndex,
    Value<int?>? requestedCount,
    Value<int>? actualCount,
    Value<int?>? timeLimitSeconds,
    Value<int>? durationMs,
    Value<int?>? deadlineAt,
    Value<String>? revealMode,
    Value<String>? status,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? finalizedAt,
    Value<String>? contentVersion,
    Value<int>? rowid,
  }) {
    return PracticeSessionsCompanion(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      title: title ?? this.title,
      paperId: paperId ?? this.paperId,
      filtersJson: filtersJson ?? this.filtersJson,
      questionIdsJson: questionIdsJson ?? this.questionIdsJson,
      currentIndex: currentIndex ?? this.currentIndex,
      requestedCount: requestedCount ?? this.requestedCount,
      actualCount: actualCount ?? this.actualCount,
      timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
      durationMs: durationMs ?? this.durationMs,
      deadlineAt: deadlineAt ?? this.deadlineAt,
      revealMode: revealMode ?? this.revealMode,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      finalizedAt: finalizedAt ?? this.finalizedAt,
      contentVersion: contentVersion ?? this.contentVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (paperId.present) {
      map['paper_id'] = Variable<String>(paperId.value);
    }
    if (filtersJson.present) {
      map['filters_json'] = Variable<String>(filtersJson.value);
    }
    if (questionIdsJson.present) {
      map['question_ids_json'] = Variable<String>(questionIdsJson.value);
    }
    if (currentIndex.present) {
      map['current_index'] = Variable<int>(currentIndex.value);
    }
    if (requestedCount.present) {
      map['requested_count'] = Variable<int>(requestedCount.value);
    }
    if (actualCount.present) {
      map['actual_count'] = Variable<int>(actualCount.value);
    }
    if (timeLimitSeconds.present) {
      map['time_limit_seconds'] = Variable<int>(timeLimitSeconds.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (deadlineAt.present) {
      map['deadline_at'] = Variable<int>(deadlineAt.value);
    }
    if (revealMode.present) {
      map['reveal_mode'] = Variable<String>(revealMode.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (finalizedAt.present) {
      map['finalized_at'] = Variable<int>(finalizedAt.value);
    }
    if (contentVersion.present) {
      map['content_version'] = Variable<String>(contentVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeSessionsCompanion(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('title: $title, ')
          ..write('paperId: $paperId, ')
          ..write('filtersJson: $filtersJson, ')
          ..write('questionIdsJson: $questionIdsJson, ')
          ..write('currentIndex: $currentIndex, ')
          ..write('requestedCount: $requestedCount, ')
          ..write('actualCount: $actualCount, ')
          ..write('timeLimitSeconds: $timeLimitSeconds, ')
          ..write('durationMs: $durationMs, ')
          ..write('deadlineAt: $deadlineAt, ')
          ..write('revealMode: $revealMode, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('finalizedAt: $finalizedAt, ')
          ..write('contentVersion: $contentVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionQuestionsTable extends SessionQuestions
    with TableInfo<$SessionQuestionsTable, SessionQuestion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionQuestionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [sessionId, questionId, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_questions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionQuestion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId, questionId};
  @override
  SessionQuestion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionQuestion(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $SessionQuestionsTable createAlias(String alias) {
    return $SessionQuestionsTable(attachedDatabase, alias);
  }
}

class SessionQuestion extends DataClass implements Insertable<SessionQuestion> {
  final String sessionId;
  final String questionId;
  final int position;
  const SessionQuestion({
    required this.sessionId,
    required this.questionId,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['question_id'] = Variable<String>(questionId);
    map['position'] = Variable<int>(position);
    return map;
  }

  SessionQuestionsCompanion toCompanion(bool nullToAbsent) {
    return SessionQuestionsCompanion(
      sessionId: Value(sessionId),
      questionId: Value(questionId),
      position: Value(position),
    );
  }

  factory SessionQuestion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionQuestion(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      questionId: serializer.fromJson<String>(json['questionId']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'questionId': serializer.toJson<String>(questionId),
      'position': serializer.toJson<int>(position),
    };
  }

  SessionQuestion copyWith({
    String? sessionId,
    String? questionId,
    int? position,
  }) => SessionQuestion(
    sessionId: sessionId ?? this.sessionId,
    questionId: questionId ?? this.questionId,
    position: position ?? this.position,
  );
  SessionQuestion copyWithCompanion(SessionQuestionsCompanion data) {
    return SessionQuestion(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionQuestion(')
          ..write('sessionId: $sessionId, ')
          ..write('questionId: $questionId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sessionId, questionId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionQuestion &&
          other.sessionId == this.sessionId &&
          other.questionId == this.questionId &&
          other.position == this.position);
}

class SessionQuestionsCompanion extends UpdateCompanion<SessionQuestion> {
  final Value<String> sessionId;
  final Value<String> questionId;
  final Value<int> position;
  final Value<int> rowid;
  const SessionQuestionsCompanion({
    this.sessionId = const Value.absent(),
    this.questionId = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionQuestionsCompanion.insert({
    required String sessionId,
    required String questionId,
    required int position,
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       questionId = Value(questionId),
       position = Value(position);
  static Insertable<SessionQuestion> custom({
    Expression<String>? sessionId,
    Expression<String>? questionId,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (questionId != null) 'question_id': questionId,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionQuestionsCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? questionId,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return SessionQuestionsCompanion(
      sessionId: sessionId ?? this.sessionId,
      questionId: questionId ?? this.questionId,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionQuestionsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('questionId: $questionId, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionAnswersTable extends SessionAnswers
    with TableInfo<$SessionAnswersTable, SessionAnswer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionAnswersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _selectedJsonMeta = const VerificationMeta(
    'selectedJson',
  );
  @override
  late final GeneratedColumn<String> selectedJson = GeneratedColumn<String>(
    'selected_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _submittedMeta = const VerificationMeta(
    'submitted',
  );
  @override
  late final GeneratedColumn<bool> submitted = GeneratedColumn<bool>(
    'submitted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("submitted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isCorrectMeta = const VerificationMeta(
    'isCorrect',
  );
  @override
  late final GeneratedColumn<bool> isCorrect = GeneratedColumn<bool>(
    'is_correct',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_correct" IN (0, 1))',
    ),
  );
  static const VerificationMeta _uncertainMeta = const VerificationMeta(
    'uncertain',
  );
  @override
  late final GeneratedColumn<bool> uncertain = GeneratedColumn<bool>(
    'uncertain',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("uncertain" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _answeredAtMeta = const VerificationMeta(
    'answeredAt',
  );
  @override
  late final GeneratedColumn<int> answeredAt = GeneratedColumn<int>(
    'answered_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    questionId,
    selectedJson,
    submitted,
    isCorrect,
    uncertain,
    durationMs,
    answeredAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_answers';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionAnswer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('selected_json')) {
      context.handle(
        _selectedJsonMeta,
        selectedJson.isAcceptableOrUnknown(
          data['selected_json']!,
          _selectedJsonMeta,
        ),
      );
    }
    if (data.containsKey('submitted')) {
      context.handle(
        _submittedMeta,
        submitted.isAcceptableOrUnknown(data['submitted']!, _submittedMeta),
      );
    }
    if (data.containsKey('is_correct')) {
      context.handle(
        _isCorrectMeta,
        isCorrect.isAcceptableOrUnknown(data['is_correct']!, _isCorrectMeta),
      );
    }
    if (data.containsKey('uncertain')) {
      context.handle(
        _uncertainMeta,
        uncertain.isAcceptableOrUnknown(data['uncertain']!, _uncertainMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('answered_at')) {
      context.handle(
        _answeredAtMeta,
        answeredAt.isAcceptableOrUnknown(data['answered_at']!, _answeredAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId, questionId};
  @override
  SessionAnswer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionAnswer(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      selectedJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_json'],
      )!,
      submitted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}submitted'],
      )!,
      isCorrect: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_correct'],
      ),
      uncertain: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}uncertain'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      answeredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}answered_at'],
      ),
    );
  }

  @override
  $SessionAnswersTable createAlias(String alias) {
    return $SessionAnswersTable(attachedDatabase, alias);
  }
}

class SessionAnswer extends DataClass implements Insertable<SessionAnswer> {
  final String sessionId;
  final String questionId;
  final String selectedJson;
  final bool submitted;
  final bool? isCorrect;
  final bool uncertain;
  final int durationMs;
  final int? answeredAt;
  const SessionAnswer({
    required this.sessionId,
    required this.questionId,
    required this.selectedJson,
    required this.submitted,
    this.isCorrect,
    required this.uncertain,
    required this.durationMs,
    this.answeredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['question_id'] = Variable<String>(questionId);
    map['selected_json'] = Variable<String>(selectedJson);
    map['submitted'] = Variable<bool>(submitted);
    if (!nullToAbsent || isCorrect != null) {
      map['is_correct'] = Variable<bool>(isCorrect);
    }
    map['uncertain'] = Variable<bool>(uncertain);
    map['duration_ms'] = Variable<int>(durationMs);
    if (!nullToAbsent || answeredAt != null) {
      map['answered_at'] = Variable<int>(answeredAt);
    }
    return map;
  }

  SessionAnswersCompanion toCompanion(bool nullToAbsent) {
    return SessionAnswersCompanion(
      sessionId: Value(sessionId),
      questionId: Value(questionId),
      selectedJson: Value(selectedJson),
      submitted: Value(submitted),
      isCorrect: isCorrect == null && nullToAbsent
          ? const Value.absent()
          : Value(isCorrect),
      uncertain: Value(uncertain),
      durationMs: Value(durationMs),
      answeredAt: answeredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(answeredAt),
    );
  }

  factory SessionAnswer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionAnswer(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      questionId: serializer.fromJson<String>(json['questionId']),
      selectedJson: serializer.fromJson<String>(json['selectedJson']),
      submitted: serializer.fromJson<bool>(json['submitted']),
      isCorrect: serializer.fromJson<bool?>(json['isCorrect']),
      uncertain: serializer.fromJson<bool>(json['uncertain']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      answeredAt: serializer.fromJson<int?>(json['answeredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'questionId': serializer.toJson<String>(questionId),
      'selectedJson': serializer.toJson<String>(selectedJson),
      'submitted': serializer.toJson<bool>(submitted),
      'isCorrect': serializer.toJson<bool?>(isCorrect),
      'uncertain': serializer.toJson<bool>(uncertain),
      'durationMs': serializer.toJson<int>(durationMs),
      'answeredAt': serializer.toJson<int?>(answeredAt),
    };
  }

  SessionAnswer copyWith({
    String? sessionId,
    String? questionId,
    String? selectedJson,
    bool? submitted,
    Value<bool?> isCorrect = const Value.absent(),
    bool? uncertain,
    int? durationMs,
    Value<int?> answeredAt = const Value.absent(),
  }) => SessionAnswer(
    sessionId: sessionId ?? this.sessionId,
    questionId: questionId ?? this.questionId,
    selectedJson: selectedJson ?? this.selectedJson,
    submitted: submitted ?? this.submitted,
    isCorrect: isCorrect.present ? isCorrect.value : this.isCorrect,
    uncertain: uncertain ?? this.uncertain,
    durationMs: durationMs ?? this.durationMs,
    answeredAt: answeredAt.present ? answeredAt.value : this.answeredAt,
  );
  SessionAnswer copyWithCompanion(SessionAnswersCompanion data) {
    return SessionAnswer(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      selectedJson: data.selectedJson.present
          ? data.selectedJson.value
          : this.selectedJson,
      submitted: data.submitted.present ? data.submitted.value : this.submitted,
      isCorrect: data.isCorrect.present ? data.isCorrect.value : this.isCorrect,
      uncertain: data.uncertain.present ? data.uncertain.value : this.uncertain,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      answeredAt: data.answeredAt.present
          ? data.answeredAt.value
          : this.answeredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionAnswer(')
          ..write('sessionId: $sessionId, ')
          ..write('questionId: $questionId, ')
          ..write('selectedJson: $selectedJson, ')
          ..write('submitted: $submitted, ')
          ..write('isCorrect: $isCorrect, ')
          ..write('uncertain: $uncertain, ')
          ..write('durationMs: $durationMs, ')
          ..write('answeredAt: $answeredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sessionId,
    questionId,
    selectedJson,
    submitted,
    isCorrect,
    uncertain,
    durationMs,
    answeredAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionAnswer &&
          other.sessionId == this.sessionId &&
          other.questionId == this.questionId &&
          other.selectedJson == this.selectedJson &&
          other.submitted == this.submitted &&
          other.isCorrect == this.isCorrect &&
          other.uncertain == this.uncertain &&
          other.durationMs == this.durationMs &&
          other.answeredAt == this.answeredAt);
}

class SessionAnswersCompanion extends UpdateCompanion<SessionAnswer> {
  final Value<String> sessionId;
  final Value<String> questionId;
  final Value<String> selectedJson;
  final Value<bool> submitted;
  final Value<bool?> isCorrect;
  final Value<bool> uncertain;
  final Value<int> durationMs;
  final Value<int?> answeredAt;
  final Value<int> rowid;
  const SessionAnswersCompanion({
    this.sessionId = const Value.absent(),
    this.questionId = const Value.absent(),
    this.selectedJson = const Value.absent(),
    this.submitted = const Value.absent(),
    this.isCorrect = const Value.absent(),
    this.uncertain = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.answeredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionAnswersCompanion.insert({
    required String sessionId,
    required String questionId,
    this.selectedJson = const Value.absent(),
    this.submitted = const Value.absent(),
    this.isCorrect = const Value.absent(),
    this.uncertain = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.answeredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       questionId = Value(questionId);
  static Insertable<SessionAnswer> custom({
    Expression<String>? sessionId,
    Expression<String>? questionId,
    Expression<String>? selectedJson,
    Expression<bool>? submitted,
    Expression<bool>? isCorrect,
    Expression<bool>? uncertain,
    Expression<int>? durationMs,
    Expression<int>? answeredAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (questionId != null) 'question_id': questionId,
      if (selectedJson != null) 'selected_json': selectedJson,
      if (submitted != null) 'submitted': submitted,
      if (isCorrect != null) 'is_correct': isCorrect,
      if (uncertain != null) 'uncertain': uncertain,
      if (durationMs != null) 'duration_ms': durationMs,
      if (answeredAt != null) 'answered_at': answeredAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionAnswersCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? questionId,
    Value<String>? selectedJson,
    Value<bool>? submitted,
    Value<bool?>? isCorrect,
    Value<bool>? uncertain,
    Value<int>? durationMs,
    Value<int?>? answeredAt,
    Value<int>? rowid,
  }) {
    return SessionAnswersCompanion(
      sessionId: sessionId ?? this.sessionId,
      questionId: questionId ?? this.questionId,
      selectedJson: selectedJson ?? this.selectedJson,
      submitted: submitted ?? this.submitted,
      isCorrect: isCorrect ?? this.isCorrect,
      uncertain: uncertain ?? this.uncertain,
      durationMs: durationMs ?? this.durationMs,
      answeredAt: answeredAt ?? this.answeredAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (selectedJson.present) {
      map['selected_json'] = Variable<String>(selectedJson.value);
    }
    if (submitted.present) {
      map['submitted'] = Variable<bool>(submitted.value);
    }
    if (isCorrect.present) {
      map['is_correct'] = Variable<bool>(isCorrect.value);
    }
    if (uncertain.present) {
      map['uncertain'] = Variable<bool>(uncertain.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (answeredAt.present) {
      map['answered_at'] = Variable<int>(answeredAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionAnswersCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('questionId: $questionId, ')
          ..write('selectedJson: $selectedJson, ')
          ..write('submitted: $submitted, ')
          ..write('isCorrect: $isCorrect, ')
          ..write('uncertain: $uncertain, ')
          ..write('durationMs: $durationMs, ')
          ..write('answeredAt: $answeredAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewItemsTable extends ReviewItems
    with TableInfo<$ReviewItemsTable, ReviewItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('practice'),
  );
  static const VerificationMeta _wrongCountMeta = const VerificationMeta(
    'wrongCount',
  );
  @override
  late final GeneratedColumn<int> wrongCount = GeneratedColumn<int>(
    'wrong_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _blankCountMeta = const VerificationMeta(
    'blankCount',
  );
  @override
  late final GeneratedColumn<int> blankCount = GeneratedColumn<int>(
    'blank_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<int> stage = GeneratedColumn<int>(
    'stage',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextReviewAtMeta = const VerificationMeta(
    'nextReviewAt',
  );
  @override
  late final GeneratedColumn<int> nextReviewAt = GeneratedColumn<int>(
    'next_review_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _masteredMeta = const VerificationMeta(
    'mastered',
  );
  @override
  late final GeneratedColumn<bool> mastered = GeneratedColumn<bool>(
    'mastered',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("mastered" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastResultMeta = const VerificationMeta(
    'lastResult',
  );
  @override
  late final GeneratedColumn<String> lastResult = GeneratedColumn<String>(
    'last_result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    questionId,
    source,
    wrongCount,
    blankCount,
    stage,
    nextReviewAt,
    mastered,
    lastResult,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('wrong_count')) {
      context.handle(
        _wrongCountMeta,
        wrongCount.isAcceptableOrUnknown(data['wrong_count']!, _wrongCountMeta),
      );
    }
    if (data.containsKey('blank_count')) {
      context.handle(
        _blankCountMeta,
        blankCount.isAcceptableOrUnknown(data['blank_count']!, _blankCountMeta),
      );
    }
    if (data.containsKey('stage')) {
      context.handle(
        _stageMeta,
        stage.isAcceptableOrUnknown(data['stage']!, _stageMeta),
      );
    }
    if (data.containsKey('next_review_at')) {
      context.handle(
        _nextReviewAtMeta,
        nextReviewAt.isAcceptableOrUnknown(
          data['next_review_at']!,
          _nextReviewAtMeta,
        ),
      );
    }
    if (data.containsKey('mastered')) {
      context.handle(
        _masteredMeta,
        mastered.isAcceptableOrUnknown(data['mastered']!, _masteredMeta),
      );
    }
    if (data.containsKey('last_result')) {
      context.handle(
        _lastResultMeta,
        lastResult.isAcceptableOrUnknown(data['last_result']!, _lastResultMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {questionId};
  @override
  ReviewItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewItem(
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      wrongCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wrong_count'],
      )!,
      blankCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}blank_count'],
      )!,
      stage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stage'],
      )!,
      nextReviewAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_review_at'],
      ),
      mastered: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}mastered'],
      )!,
      lastResult: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_result'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReviewItemsTable createAlias(String alias) {
    return $ReviewItemsTable(attachedDatabase, alias);
  }
}

class ReviewItem extends DataClass implements Insertable<ReviewItem> {
  final String questionId;
  final String source;
  final int wrongCount;
  final int blankCount;
  final int stage;
  final int? nextReviewAt;
  final bool mastered;
  final String? lastResult;
  final int updatedAt;
  const ReviewItem({
    required this.questionId,
    required this.source,
    required this.wrongCount,
    required this.blankCount,
    required this.stage,
    this.nextReviewAt,
    required this.mastered,
    this.lastResult,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['question_id'] = Variable<String>(questionId);
    map['source'] = Variable<String>(source);
    map['wrong_count'] = Variable<int>(wrongCount);
    map['blank_count'] = Variable<int>(blankCount);
    map['stage'] = Variable<int>(stage);
    if (!nullToAbsent || nextReviewAt != null) {
      map['next_review_at'] = Variable<int>(nextReviewAt);
    }
    map['mastered'] = Variable<bool>(mastered);
    if (!nullToAbsent || lastResult != null) {
      map['last_result'] = Variable<String>(lastResult);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ReviewItemsCompanion toCompanion(bool nullToAbsent) {
    return ReviewItemsCompanion(
      questionId: Value(questionId),
      source: Value(source),
      wrongCount: Value(wrongCount),
      blankCount: Value(blankCount),
      stage: Value(stage),
      nextReviewAt: nextReviewAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextReviewAt),
      mastered: Value(mastered),
      lastResult: lastResult == null && nullToAbsent
          ? const Value.absent()
          : Value(lastResult),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReviewItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewItem(
      questionId: serializer.fromJson<String>(json['questionId']),
      source: serializer.fromJson<String>(json['source']),
      wrongCount: serializer.fromJson<int>(json['wrongCount']),
      blankCount: serializer.fromJson<int>(json['blankCount']),
      stage: serializer.fromJson<int>(json['stage']),
      nextReviewAt: serializer.fromJson<int?>(json['nextReviewAt']),
      mastered: serializer.fromJson<bool>(json['mastered']),
      lastResult: serializer.fromJson<String?>(json['lastResult']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'questionId': serializer.toJson<String>(questionId),
      'source': serializer.toJson<String>(source),
      'wrongCount': serializer.toJson<int>(wrongCount),
      'blankCount': serializer.toJson<int>(blankCount),
      'stage': serializer.toJson<int>(stage),
      'nextReviewAt': serializer.toJson<int?>(nextReviewAt),
      'mastered': serializer.toJson<bool>(mastered),
      'lastResult': serializer.toJson<String?>(lastResult),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ReviewItem copyWith({
    String? questionId,
    String? source,
    int? wrongCount,
    int? blankCount,
    int? stage,
    Value<int?> nextReviewAt = const Value.absent(),
    bool? mastered,
    Value<String?> lastResult = const Value.absent(),
    int? updatedAt,
  }) => ReviewItem(
    questionId: questionId ?? this.questionId,
    source: source ?? this.source,
    wrongCount: wrongCount ?? this.wrongCount,
    blankCount: blankCount ?? this.blankCount,
    stage: stage ?? this.stage,
    nextReviewAt: nextReviewAt.present ? nextReviewAt.value : this.nextReviewAt,
    mastered: mastered ?? this.mastered,
    lastResult: lastResult.present ? lastResult.value : this.lastResult,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReviewItem copyWithCompanion(ReviewItemsCompanion data) {
    return ReviewItem(
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      source: data.source.present ? data.source.value : this.source,
      wrongCount: data.wrongCount.present
          ? data.wrongCount.value
          : this.wrongCount,
      blankCount: data.blankCount.present
          ? data.blankCount.value
          : this.blankCount,
      stage: data.stage.present ? data.stage.value : this.stage,
      nextReviewAt: data.nextReviewAt.present
          ? data.nextReviewAt.value
          : this.nextReviewAt,
      mastered: data.mastered.present ? data.mastered.value : this.mastered,
      lastResult: data.lastResult.present
          ? data.lastResult.value
          : this.lastResult,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewItem(')
          ..write('questionId: $questionId, ')
          ..write('source: $source, ')
          ..write('wrongCount: $wrongCount, ')
          ..write('blankCount: $blankCount, ')
          ..write('stage: $stage, ')
          ..write('nextReviewAt: $nextReviewAt, ')
          ..write('mastered: $mastered, ')
          ..write('lastResult: $lastResult, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    questionId,
    source,
    wrongCount,
    blankCount,
    stage,
    nextReviewAt,
    mastered,
    lastResult,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewItem &&
          other.questionId == this.questionId &&
          other.source == this.source &&
          other.wrongCount == this.wrongCount &&
          other.blankCount == this.blankCount &&
          other.stage == this.stage &&
          other.nextReviewAt == this.nextReviewAt &&
          other.mastered == this.mastered &&
          other.lastResult == this.lastResult &&
          other.updatedAt == this.updatedAt);
}

class ReviewItemsCompanion extends UpdateCompanion<ReviewItem> {
  final Value<String> questionId;
  final Value<String> source;
  final Value<int> wrongCount;
  final Value<int> blankCount;
  final Value<int> stage;
  final Value<int?> nextReviewAt;
  final Value<bool> mastered;
  final Value<String?> lastResult;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ReviewItemsCompanion({
    this.questionId = const Value.absent(),
    this.source = const Value.absent(),
    this.wrongCount = const Value.absent(),
    this.blankCount = const Value.absent(),
    this.stage = const Value.absent(),
    this.nextReviewAt = const Value.absent(),
    this.mastered = const Value.absent(),
    this.lastResult = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewItemsCompanion.insert({
    required String questionId,
    this.source = const Value.absent(),
    this.wrongCount = const Value.absent(),
    this.blankCount = const Value.absent(),
    this.stage = const Value.absent(),
    this.nextReviewAt = const Value.absent(),
    this.mastered = const Value.absent(),
    this.lastResult = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : questionId = Value(questionId),
       updatedAt = Value(updatedAt);
  static Insertable<ReviewItem> custom({
    Expression<String>? questionId,
    Expression<String>? source,
    Expression<int>? wrongCount,
    Expression<int>? blankCount,
    Expression<int>? stage,
    Expression<int>? nextReviewAt,
    Expression<bool>? mastered,
    Expression<String>? lastResult,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (questionId != null) 'question_id': questionId,
      if (source != null) 'source': source,
      if (wrongCount != null) 'wrong_count': wrongCount,
      if (blankCount != null) 'blank_count': blankCount,
      if (stage != null) 'stage': stage,
      if (nextReviewAt != null) 'next_review_at': nextReviewAt,
      if (mastered != null) 'mastered': mastered,
      if (lastResult != null) 'last_result': lastResult,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewItemsCompanion copyWith({
    Value<String>? questionId,
    Value<String>? source,
    Value<int>? wrongCount,
    Value<int>? blankCount,
    Value<int>? stage,
    Value<int?>? nextReviewAt,
    Value<bool>? mastered,
    Value<String?>? lastResult,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReviewItemsCompanion(
      questionId: questionId ?? this.questionId,
      source: source ?? this.source,
      wrongCount: wrongCount ?? this.wrongCount,
      blankCount: blankCount ?? this.blankCount,
      stage: stage ?? this.stage,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      mastered: mastered ?? this.mastered,
      lastResult: lastResult ?? this.lastResult,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (wrongCount.present) {
      map['wrong_count'] = Variable<int>(wrongCount.value);
    }
    if (blankCount.present) {
      map['blank_count'] = Variable<int>(blankCount.value);
    }
    if (stage.present) {
      map['stage'] = Variable<int>(stage.value);
    }
    if (nextReviewAt.present) {
      map['next_review_at'] = Variable<int>(nextReviewAt.value);
    }
    if (mastered.present) {
      map['mastered'] = Variable<bool>(mastered.value);
    }
    if (lastResult.present) {
      map['last_result'] = Variable<String>(lastResult.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewItemsCompanion(')
          ..write('questionId: $questionId, ')
          ..write('source: $source, ')
          ..write('wrongCount: $wrongCount, ')
          ..write('blankCount: $blankCount, ')
          ..write('stage: $stage, ')
          ..write('nextReviewAt: $nextReviewAt, ')
          ..write('mastered: $mastered, ')
          ..write('lastResult: $lastResult, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoritesTable extends Favorites
    with TableInfo<$FavoritesTable, Favorite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [questionId, createdAt, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<Favorite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {questionId};
  @override
  Favorite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Favorite(
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
    );
  }

  @override
  $FavoritesTable createAlias(String alias) {
    return $FavoritesTable(attachedDatabase, alias);
  }
}

class Favorite extends DataClass implements Insertable<Favorite> {
  final String questionId;
  final int createdAt;
  final String note;
  const Favorite({
    required this.questionId,
    required this.createdAt,
    required this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['question_id'] = Variable<String>(questionId);
    map['created_at'] = Variable<int>(createdAt);
    map['note'] = Variable<String>(note);
    return map;
  }

  FavoritesCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCompanion(
      questionId: Value(questionId),
      createdAt: Value(createdAt),
      note: Value(note),
    );
  }

  factory Favorite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Favorite(
      questionId: serializer.fromJson<String>(json['questionId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      note: serializer.fromJson<String>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'questionId': serializer.toJson<String>(questionId),
      'createdAt': serializer.toJson<int>(createdAt),
      'note': serializer.toJson<String>(note),
    };
  }

  Favorite copyWith({String? questionId, int? createdAt, String? note}) =>
      Favorite(
        questionId: questionId ?? this.questionId,
        createdAt: createdAt ?? this.createdAt,
        note: note ?? this.note,
      );
  Favorite copyWithCompanion(FavoritesCompanion data) {
    return Favorite(
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Favorite(')
          ..write('questionId: $questionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(questionId, createdAt, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Favorite &&
          other.questionId == this.questionId &&
          other.createdAt == this.createdAt &&
          other.note == this.note);
}

class FavoritesCompanion extends UpdateCompanion<Favorite> {
  final Value<String> questionId;
  final Value<int> createdAt;
  final Value<String> note;
  final Value<int> rowid;
  const FavoritesCompanion({
    this.questionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoritesCompanion.insert({
    required String questionId,
    required int createdAt,
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : questionId = Value(questionId),
       createdAt = Value(createdAt);
  static Insertable<Favorite> custom({
    Expression<String>? questionId,
    Expression<int>? createdAt,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (questionId != null) 'question_id': questionId,
      if (createdAt != null) 'created_at': createdAt,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoritesCompanion copyWith({
    Value<String>? questionId,
    Value<int>? createdAt,
    Value<String>? note,
    Value<int>? rowid,
  }) {
    return FavoritesCompanion(
      questionId: questionId ?? this.questionId,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesCompanion(')
          ..write('questionId: $questionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyStatsTable extends DailyStats
    with TableInfo<$DailyStatsTable, DailyStat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answeredCountMeta = const VerificationMeta(
    'answeredCount',
  );
  @override
  late final GeneratedColumn<int> answeredCount = GeneratedColumn<int>(
    'answered_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _correctCountMeta = const VerificationMeta(
    'correctCount',
  );
  @override
  late final GeneratedColumn<int> correctCount = GeneratedColumn<int>(
    'correct_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sessionsCountMeta = const VerificationMeta(
    'sessionsCount',
  );
  @override
  late final GeneratedColumn<int> sessionsCount = GeneratedColumn<int>(
    'sessions_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    day,
    answeredCount,
    correctCount,
    durationMs,
    sessionsCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyStat> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('answered_count')) {
      context.handle(
        _answeredCountMeta,
        answeredCount.isAcceptableOrUnknown(
          data['answered_count']!,
          _answeredCountMeta,
        ),
      );
    }
    if (data.containsKey('correct_count')) {
      context.handle(
        _correctCountMeta,
        correctCount.isAcceptableOrUnknown(
          data['correct_count']!,
          _correctCountMeta,
        ),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('sessions_count')) {
      context.handle(
        _sessionsCountMeta,
        sessionsCount.isAcceptableOrUnknown(
          data['sessions_count']!,
          _sessionsCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  DailyStat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyStat(
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      answeredCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}answered_count'],
      )!,
      correctCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct_count'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      sessionsCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sessions_count'],
      )!,
    );
  }

  @override
  $DailyStatsTable createAlias(String alias) {
    return $DailyStatsTable(attachedDatabase, alias);
  }
}

class DailyStat extends DataClass implements Insertable<DailyStat> {
  final String day;
  final int answeredCount;
  final int correctCount;
  final int durationMs;
  final int sessionsCount;
  const DailyStat({
    required this.day,
    required this.answeredCount,
    required this.correctCount,
    required this.durationMs,
    required this.sessionsCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<String>(day);
    map['answered_count'] = Variable<int>(answeredCount);
    map['correct_count'] = Variable<int>(correctCount);
    map['duration_ms'] = Variable<int>(durationMs);
    map['sessions_count'] = Variable<int>(sessionsCount);
    return map;
  }

  DailyStatsCompanion toCompanion(bool nullToAbsent) {
    return DailyStatsCompanion(
      day: Value(day),
      answeredCount: Value(answeredCount),
      correctCount: Value(correctCount),
      durationMs: Value(durationMs),
      sessionsCount: Value(sessionsCount),
    );
  }

  factory DailyStat.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyStat(
      day: serializer.fromJson<String>(json['day']),
      answeredCount: serializer.fromJson<int>(json['answeredCount']),
      correctCount: serializer.fromJson<int>(json['correctCount']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      sessionsCount: serializer.fromJson<int>(json['sessionsCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<String>(day),
      'answeredCount': serializer.toJson<int>(answeredCount),
      'correctCount': serializer.toJson<int>(correctCount),
      'durationMs': serializer.toJson<int>(durationMs),
      'sessionsCount': serializer.toJson<int>(sessionsCount),
    };
  }

  DailyStat copyWith({
    String? day,
    int? answeredCount,
    int? correctCount,
    int? durationMs,
    int? sessionsCount,
  }) => DailyStat(
    day: day ?? this.day,
    answeredCount: answeredCount ?? this.answeredCount,
    correctCount: correctCount ?? this.correctCount,
    durationMs: durationMs ?? this.durationMs,
    sessionsCount: sessionsCount ?? this.sessionsCount,
  );
  DailyStat copyWithCompanion(DailyStatsCompanion data) {
    return DailyStat(
      day: data.day.present ? data.day.value : this.day,
      answeredCount: data.answeredCount.present
          ? data.answeredCount.value
          : this.answeredCount,
      correctCount: data.correctCount.present
          ? data.correctCount.value
          : this.correctCount,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      sessionsCount: data.sessionsCount.present
          ? data.sessionsCount.value
          : this.sessionsCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyStat(')
          ..write('day: $day, ')
          ..write('answeredCount: $answeredCount, ')
          ..write('correctCount: $correctCount, ')
          ..write('durationMs: $durationMs, ')
          ..write('sessionsCount: $sessionsCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(day, answeredCount, correctCount, durationMs, sessionsCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyStat &&
          other.day == this.day &&
          other.answeredCount == this.answeredCount &&
          other.correctCount == this.correctCount &&
          other.durationMs == this.durationMs &&
          other.sessionsCount == this.sessionsCount);
}

class DailyStatsCompanion extends UpdateCompanion<DailyStat> {
  final Value<String> day;
  final Value<int> answeredCount;
  final Value<int> correctCount;
  final Value<int> durationMs;
  final Value<int> sessionsCount;
  final Value<int> rowid;
  const DailyStatsCompanion({
    this.day = const Value.absent(),
    this.answeredCount = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.sessionsCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyStatsCompanion.insert({
    required String day,
    this.answeredCount = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.sessionsCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : day = Value(day);
  static Insertable<DailyStat> custom({
    Expression<String>? day,
    Expression<int>? answeredCount,
    Expression<int>? correctCount,
    Expression<int>? durationMs,
    Expression<int>? sessionsCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (answeredCount != null) 'answered_count': answeredCount,
      if (correctCount != null) 'correct_count': correctCount,
      if (durationMs != null) 'duration_ms': durationMs,
      if (sessionsCount != null) 'sessions_count': sessionsCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyStatsCompanion copyWith({
    Value<String>? day,
    Value<int>? answeredCount,
    Value<int>? correctCount,
    Value<int>? durationMs,
    Value<int>? sessionsCount,
    Value<int>? rowid,
  }) {
    return DailyStatsCompanion(
      day: day ?? this.day,
      answeredCount: answeredCount ?? this.answeredCount,
      correctCount: correctCount ?? this.correctCount,
      durationMs: durationMs ?? this.durationMs,
      sessionsCount: sessionsCount ?? this.sessionsCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (answeredCount.present) {
      map['answered_count'] = Variable<int>(answeredCount.value);
    }
    if (correctCount.present) {
      map['correct_count'] = Variable<int>(correctCount.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (sessionsCount.present) {
      map['sessions_count'] = Variable<int>(sessionsCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyStatsCompanion(')
          ..write('day: $day, ')
          ..write('answeredCount: $answeredCount, ')
          ..write('correctCount: $correctCount, ')
          ..write('durationMs: $durationMs, ')
          ..write('sessionsCount: $sessionsCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModuleStatsTable extends ModuleStats
    with TableInfo<$ModuleStatsTable, ModuleStat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModuleStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _moduleMeta = const VerificationMeta('module');
  @override
  late final GeneratedColumn<String> module = GeneratedColumn<String>(
    'module',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answeredCountMeta = const VerificationMeta(
    'answeredCount',
  );
  @override
  late final GeneratedColumn<int> answeredCount = GeneratedColumn<int>(
    'answered_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _correctCountMeta = const VerificationMeta(
    'correctCount',
  );
  @override
  late final GeneratedColumn<int> correctCount = GeneratedColumn<int>(
    'correct_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    module,
    answeredCount,
    correctCount,
    durationMs,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'module_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModuleStat> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('module')) {
      context.handle(
        _moduleMeta,
        module.isAcceptableOrUnknown(data['module']!, _moduleMeta),
      );
    } else if (isInserting) {
      context.missing(_moduleMeta);
    }
    if (data.containsKey('answered_count')) {
      context.handle(
        _answeredCountMeta,
        answeredCount.isAcceptableOrUnknown(
          data['answered_count']!,
          _answeredCountMeta,
        ),
      );
    }
    if (data.containsKey('correct_count')) {
      context.handle(
        _correctCountMeta,
        correctCount.isAcceptableOrUnknown(
          data['correct_count']!,
          _correctCountMeta,
        ),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {module};
  @override
  ModuleStat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModuleStat(
      module: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}module'],
      )!,
      answeredCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}answered_count'],
      )!,
      correctCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct_count'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ModuleStatsTable createAlias(String alias) {
    return $ModuleStatsTable(attachedDatabase, alias);
  }
}

class ModuleStat extends DataClass implements Insertable<ModuleStat> {
  final String module;
  final int answeredCount;
  final int correctCount;
  final int durationMs;
  final int updatedAt;
  const ModuleStat({
    required this.module,
    required this.answeredCount,
    required this.correctCount,
    required this.durationMs,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['module'] = Variable<String>(module);
    map['answered_count'] = Variable<int>(answeredCount);
    map['correct_count'] = Variable<int>(correctCount);
    map['duration_ms'] = Variable<int>(durationMs);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ModuleStatsCompanion toCompanion(bool nullToAbsent) {
    return ModuleStatsCompanion(
      module: Value(module),
      answeredCount: Value(answeredCount),
      correctCount: Value(correctCount),
      durationMs: Value(durationMs),
      updatedAt: Value(updatedAt),
    );
  }

  factory ModuleStat.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModuleStat(
      module: serializer.fromJson<String>(json['module']),
      answeredCount: serializer.fromJson<int>(json['answeredCount']),
      correctCount: serializer.fromJson<int>(json['correctCount']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'module': serializer.toJson<String>(module),
      'answeredCount': serializer.toJson<int>(answeredCount),
      'correctCount': serializer.toJson<int>(correctCount),
      'durationMs': serializer.toJson<int>(durationMs),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ModuleStat copyWith({
    String? module,
    int? answeredCount,
    int? correctCount,
    int? durationMs,
    int? updatedAt,
  }) => ModuleStat(
    module: module ?? this.module,
    answeredCount: answeredCount ?? this.answeredCount,
    correctCount: correctCount ?? this.correctCount,
    durationMs: durationMs ?? this.durationMs,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ModuleStat copyWithCompanion(ModuleStatsCompanion data) {
    return ModuleStat(
      module: data.module.present ? data.module.value : this.module,
      answeredCount: data.answeredCount.present
          ? data.answeredCount.value
          : this.answeredCount,
      correctCount: data.correctCount.present
          ? data.correctCount.value
          : this.correctCount,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModuleStat(')
          ..write('module: $module, ')
          ..write('answeredCount: $answeredCount, ')
          ..write('correctCount: $correctCount, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(module, answeredCount, correctCount, durationMs, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModuleStat &&
          other.module == this.module &&
          other.answeredCount == this.answeredCount &&
          other.correctCount == this.correctCount &&
          other.durationMs == this.durationMs &&
          other.updatedAt == this.updatedAt);
}

class ModuleStatsCompanion extends UpdateCompanion<ModuleStat> {
  final Value<String> module;
  final Value<int> answeredCount;
  final Value<int> correctCount;
  final Value<int> durationMs;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ModuleStatsCompanion({
    this.module = const Value.absent(),
    this.answeredCount = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModuleStatsCompanion.insert({
    required String module,
    this.answeredCount = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.durationMs = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : module = Value(module),
       updatedAt = Value(updatedAt);
  static Insertable<ModuleStat> custom({
    Expression<String>? module,
    Expression<int>? answeredCount,
    Expression<int>? correctCount,
    Expression<int>? durationMs,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (module != null) 'module': module,
      if (answeredCount != null) 'answered_count': answeredCount,
      if (correctCount != null) 'correct_count': correctCount,
      if (durationMs != null) 'duration_ms': durationMs,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModuleStatsCompanion copyWith({
    Value<String>? module,
    Value<int>? answeredCount,
    Value<int>? correctCount,
    Value<int>? durationMs,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ModuleStatsCompanion(
      module: module ?? this.module,
      answeredCount: answeredCount ?? this.answeredCount,
      correctCount: correctCount ?? this.correctCount,
      durationMs: durationMs ?? this.durationMs,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (module.present) {
      map['module'] = Variable<String>(module.value);
    }
    if (answeredCount.present) {
      map['answered_count'] = Variable<int>(answeredCount.value);
    }
    if (correctCount.present) {
      map['correct_count'] = Variable<int>(correctCount.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModuleStatsCompanion(')
          ..write('module: $module, ')
          ..write('answeredCount: $answeredCount, ')
          ..write('correctCount: $correctCount, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PracticeSessionsTable practiceSessions = $PracticeSessionsTable(
    this,
  );
  late final $SessionQuestionsTable sessionQuestions = $SessionQuestionsTable(
    this,
  );
  late final $SessionAnswersTable sessionAnswers = $SessionAnswersTable(this);
  late final $ReviewItemsTable reviewItems = $ReviewItemsTable(this);
  late final $FavoritesTable favorites = $FavoritesTable(this);
  late final $DailyStatsTable dailyStats = $DailyStatsTable(this);
  late final $ModuleStatsTable moduleStats = $ModuleStatsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    practiceSessions,
    sessionQuestions,
    sessionAnswers,
    reviewItems,
    favorites,
    dailyStats,
    moduleStats,
    appSettings,
  ];
}

typedef $$PracticeSessionsTableCreateCompanionBuilder =
    PracticeSessionsCompanion Function({
      required String id,
      required String mode,
      required String title,
      Value<String?> paperId,
      Value<String> filtersJson,
      required String questionIdsJson,
      Value<int> currentIndex,
      Value<int?> requestedCount,
      required int actualCount,
      Value<int?> timeLimitSeconds,
      Value<int> durationMs,
      Value<int?> deadlineAt,
      required String revealMode,
      Value<String> status,
      required int createdAt,
      required int updatedAt,
      Value<int?> finalizedAt,
      Value<String> contentVersion,
      Value<int> rowid,
    });
typedef $$PracticeSessionsTableUpdateCompanionBuilder =
    PracticeSessionsCompanion Function({
      Value<String> id,
      Value<String> mode,
      Value<String> title,
      Value<String?> paperId,
      Value<String> filtersJson,
      Value<String> questionIdsJson,
      Value<int> currentIndex,
      Value<int?> requestedCount,
      Value<int> actualCount,
      Value<int?> timeLimitSeconds,
      Value<int> durationMs,
      Value<int?> deadlineAt,
      Value<String> revealMode,
      Value<String> status,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> finalizedAt,
      Value<String> contentVersion,
      Value<int> rowid,
    });

class $$PracticeSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paperId => $composableBuilder(
    column: $table.paperId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filtersJson => $composableBuilder(
    column: $table.filtersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questionIdsJson => $composableBuilder(
    column: $table.questionIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentIndex => $composableBuilder(
    column: $table.currentIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get requestedCount => $composableBuilder(
    column: $table.requestedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actualCount => $composableBuilder(
    column: $table.actualCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeLimitSeconds => $composableBuilder(
    column: $table.timeLimitSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deadlineAt => $composableBuilder(
    column: $table.deadlineAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get revealMode => $composableBuilder(
    column: $table.revealMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get finalizedAt => $composableBuilder(
    column: $table.finalizedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentVersion => $composableBuilder(
    column: $table.contentVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PracticeSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paperId => $composableBuilder(
    column: $table.paperId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filtersJson => $composableBuilder(
    column: $table.filtersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questionIdsJson => $composableBuilder(
    column: $table.questionIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentIndex => $composableBuilder(
    column: $table.currentIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get requestedCount => $composableBuilder(
    column: $table.requestedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actualCount => $composableBuilder(
    column: $table.actualCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeLimitSeconds => $composableBuilder(
    column: $table.timeLimitSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deadlineAt => $composableBuilder(
    column: $table.deadlineAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get revealMode => $composableBuilder(
    column: $table.revealMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get finalizedAt => $composableBuilder(
    column: $table.finalizedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentVersion => $composableBuilder(
    column: $table.contentVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PracticeSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get paperId =>
      $composableBuilder(column: $table.paperId, builder: (column) => column);

  GeneratedColumn<String> get filtersJson => $composableBuilder(
    column: $table.filtersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get questionIdsJson => $composableBuilder(
    column: $table.questionIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentIndex => $composableBuilder(
    column: $table.currentIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get requestedCount => $composableBuilder(
    column: $table.requestedCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actualCount => $composableBuilder(
    column: $table.actualCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timeLimitSeconds => $composableBuilder(
    column: $table.timeLimitSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deadlineAt => $composableBuilder(
    column: $table.deadlineAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get revealMode => $composableBuilder(
    column: $table.revealMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get finalizedAt => $composableBuilder(
    column: $table.finalizedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentVersion => $composableBuilder(
    column: $table.contentVersion,
    builder: (column) => column,
  );
}

class $$PracticeSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PracticeSessionsTable,
          PracticeSession,
          $$PracticeSessionsTableFilterComposer,
          $$PracticeSessionsTableOrderingComposer,
          $$PracticeSessionsTableAnnotationComposer,
          $$PracticeSessionsTableCreateCompanionBuilder,
          $$PracticeSessionsTableUpdateCompanionBuilder,
          (
            PracticeSession,
            BaseReferences<
              _$AppDatabase,
              $PracticeSessionsTable,
              PracticeSession
            >,
          ),
          PracticeSession,
          PrefetchHooks Function()
        > {
  $$PracticeSessionsTableTableManager(
    _$AppDatabase db,
    $PracticeSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PracticeSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PracticeSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PracticeSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> paperId = const Value.absent(),
                Value<String> filtersJson = const Value.absent(),
                Value<String> questionIdsJson = const Value.absent(),
                Value<int> currentIndex = const Value.absent(),
                Value<int?> requestedCount = const Value.absent(),
                Value<int> actualCount = const Value.absent(),
                Value<int?> timeLimitSeconds = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int?> deadlineAt = const Value.absent(),
                Value<String> revealMode = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> finalizedAt = const Value.absent(),
                Value<String> contentVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PracticeSessionsCompanion(
                id: id,
                mode: mode,
                title: title,
                paperId: paperId,
                filtersJson: filtersJson,
                questionIdsJson: questionIdsJson,
                currentIndex: currentIndex,
                requestedCount: requestedCount,
                actualCount: actualCount,
                timeLimitSeconds: timeLimitSeconds,
                durationMs: durationMs,
                deadlineAt: deadlineAt,
                revealMode: revealMode,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                finalizedAt: finalizedAt,
                contentVersion: contentVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String mode,
                required String title,
                Value<String?> paperId = const Value.absent(),
                Value<String> filtersJson = const Value.absent(),
                required String questionIdsJson,
                Value<int> currentIndex = const Value.absent(),
                Value<int?> requestedCount = const Value.absent(),
                required int actualCount,
                Value<int?> timeLimitSeconds = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int?> deadlineAt = const Value.absent(),
                required String revealMode,
                Value<String> status = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> finalizedAt = const Value.absent(),
                Value<String> contentVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PracticeSessionsCompanion.insert(
                id: id,
                mode: mode,
                title: title,
                paperId: paperId,
                filtersJson: filtersJson,
                questionIdsJson: questionIdsJson,
                currentIndex: currentIndex,
                requestedCount: requestedCount,
                actualCount: actualCount,
                timeLimitSeconds: timeLimitSeconds,
                durationMs: durationMs,
                deadlineAt: deadlineAt,
                revealMode: revealMode,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                finalizedAt: finalizedAt,
                contentVersion: contentVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PracticeSessionsTable, PracticeSession>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PracticeSessionsTable,
                    PracticeSession
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PracticeSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PracticeSessionsTable,
      PracticeSession,
      $$PracticeSessionsTableFilterComposer,
      $$PracticeSessionsTableOrderingComposer,
      $$PracticeSessionsTableAnnotationComposer,
      $$PracticeSessionsTableCreateCompanionBuilder,
      $$PracticeSessionsTableUpdateCompanionBuilder,
      (
        PracticeSession,
        BaseReferences<_$AppDatabase, $PracticeSessionsTable, PracticeSession>,
      ),
      PracticeSession,
      PrefetchHooks Function()
    >;
typedef $$SessionQuestionsTableCreateCompanionBuilder =
    SessionQuestionsCompanion Function({
      required String sessionId,
      required String questionId,
      required int position,
      Value<int> rowid,
    });
typedef $$SessionQuestionsTableUpdateCompanionBuilder =
    SessionQuestionsCompanion Function({
      Value<String> sessionId,
      Value<String> questionId,
      Value<int> position,
      Value<int> rowid,
    });

class $$SessionQuestionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionQuestionsTable> {
  $$SessionQuestionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionQuestionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionQuestionsTable> {
  $$SessionQuestionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionQuestionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionQuestionsTable> {
  $$SessionQuestionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$SessionQuestionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionQuestionsTable,
          SessionQuestion,
          $$SessionQuestionsTableFilterComposer,
          $$SessionQuestionsTableOrderingComposer,
          $$SessionQuestionsTableAnnotationComposer,
          $$SessionQuestionsTableCreateCompanionBuilder,
          $$SessionQuestionsTableUpdateCompanionBuilder,
          (
            SessionQuestion,
            BaseReferences<
              _$AppDatabase,
              $SessionQuestionsTable,
              SessionQuestion
            >,
          ),
          SessionQuestion,
          PrefetchHooks Function()
        > {
  $$SessionQuestionsTableTableManager(
    _$AppDatabase db,
    $SessionQuestionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionQuestionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionQuestionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionQuestionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> questionId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionQuestionsCompanion(
                sessionId: sessionId,
                questionId: questionId,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String questionId,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => SessionQuestionsCompanion.insert(
                sessionId: sessionId,
                questionId: questionId,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionQuestionsTable, SessionQuestion>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SessionQuestionsTable,
                    SessionQuestion
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionQuestionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionQuestionsTable,
      SessionQuestion,
      $$SessionQuestionsTableFilterComposer,
      $$SessionQuestionsTableOrderingComposer,
      $$SessionQuestionsTableAnnotationComposer,
      $$SessionQuestionsTableCreateCompanionBuilder,
      $$SessionQuestionsTableUpdateCompanionBuilder,
      (
        SessionQuestion,
        BaseReferences<_$AppDatabase, $SessionQuestionsTable, SessionQuestion>,
      ),
      SessionQuestion,
      PrefetchHooks Function()
    >;
typedef $$SessionAnswersTableCreateCompanionBuilder =
    SessionAnswersCompanion Function({
      required String sessionId,
      required String questionId,
      Value<String> selectedJson,
      Value<bool> submitted,
      Value<bool?> isCorrect,
      Value<bool> uncertain,
      Value<int> durationMs,
      Value<int?> answeredAt,
      Value<int> rowid,
    });
typedef $$SessionAnswersTableUpdateCompanionBuilder =
    SessionAnswersCompanion Function({
      Value<String> sessionId,
      Value<String> questionId,
      Value<String> selectedJson,
      Value<bool> submitted,
      Value<bool?> isCorrect,
      Value<bool> uncertain,
      Value<int> durationMs,
      Value<int?> answeredAt,
      Value<int> rowid,
    });

class $$SessionAnswersTableFilterComposer
    extends Composer<_$AppDatabase, $SessionAnswersTable> {
  $$SessionAnswersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedJson => $composableBuilder(
    column: $table.selectedJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get submitted => $composableBuilder(
    column: $table.submitted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCorrect => $composableBuilder(
    column: $table.isCorrect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get uncertain => $composableBuilder(
    column: $table.uncertain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionAnswersTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionAnswersTable> {
  $$SessionAnswersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedJson => $composableBuilder(
    column: $table.selectedJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get submitted => $composableBuilder(
    column: $table.submitted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCorrect => $composableBuilder(
    column: $table.isCorrect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get uncertain => $composableBuilder(
    column: $table.uncertain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionAnswersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionAnswersTable> {
  $$SessionAnswersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selectedJson => $composableBuilder(
    column: $table.selectedJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get submitted =>
      $composableBuilder(column: $table.submitted, builder: (column) => column);

  GeneratedColumn<bool> get isCorrect =>
      $composableBuilder(column: $table.isCorrect, builder: (column) => column);

  GeneratedColumn<bool> get uncertain =>
      $composableBuilder(column: $table.uncertain, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => column,
  );
}

class $$SessionAnswersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionAnswersTable,
          SessionAnswer,
          $$SessionAnswersTableFilterComposer,
          $$SessionAnswersTableOrderingComposer,
          $$SessionAnswersTableAnnotationComposer,
          $$SessionAnswersTableCreateCompanionBuilder,
          $$SessionAnswersTableUpdateCompanionBuilder,
          (
            SessionAnswer,
            BaseReferences<_$AppDatabase, $SessionAnswersTable, SessionAnswer>,
          ),
          SessionAnswer,
          PrefetchHooks Function()
        > {
  $$SessionAnswersTableTableManager(
    _$AppDatabase db,
    $SessionAnswersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionAnswersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionAnswersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionAnswersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> questionId = const Value.absent(),
                Value<String> selectedJson = const Value.absent(),
                Value<bool> submitted = const Value.absent(),
                Value<bool?> isCorrect = const Value.absent(),
                Value<bool> uncertain = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int?> answeredAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionAnswersCompanion(
                sessionId: sessionId,
                questionId: questionId,
                selectedJson: selectedJson,
                submitted: submitted,
                isCorrect: isCorrect,
                uncertain: uncertain,
                durationMs: durationMs,
                answeredAt: answeredAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String questionId,
                Value<String> selectedJson = const Value.absent(),
                Value<bool> submitted = const Value.absent(),
                Value<bool?> isCorrect = const Value.absent(),
                Value<bool> uncertain = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int?> answeredAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionAnswersCompanion.insert(
                sessionId: sessionId,
                questionId: questionId,
                selectedJson: selectedJson,
                submitted: submitted,
                isCorrect: isCorrect,
                uncertain: uncertain,
                durationMs: durationMs,
                answeredAt: answeredAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionAnswersTable, SessionAnswer>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SessionAnswersTable,
                    SessionAnswer
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionAnswersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionAnswersTable,
      SessionAnswer,
      $$SessionAnswersTableFilterComposer,
      $$SessionAnswersTableOrderingComposer,
      $$SessionAnswersTableAnnotationComposer,
      $$SessionAnswersTableCreateCompanionBuilder,
      $$SessionAnswersTableUpdateCompanionBuilder,
      (
        SessionAnswer,
        BaseReferences<_$AppDatabase, $SessionAnswersTable, SessionAnswer>,
      ),
      SessionAnswer,
      PrefetchHooks Function()
    >;
typedef $$ReviewItemsTableCreateCompanionBuilder =
    ReviewItemsCompanion Function({
      required String questionId,
      Value<String> source,
      Value<int> wrongCount,
      Value<int> blankCount,
      Value<int> stage,
      Value<int?> nextReviewAt,
      Value<bool> mastered,
      Value<String?> lastResult,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ReviewItemsTableUpdateCompanionBuilder =
    ReviewItemsCompanion Function({
      Value<String> questionId,
      Value<String> source,
      Value<int> wrongCount,
      Value<int> blankCount,
      Value<int> stage,
      Value<int?> nextReviewAt,
      Value<bool> mastered,
      Value<String?> lastResult,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$ReviewItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ReviewItemsTable> {
  $$ReviewItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wrongCount => $composableBuilder(
    column: $table.wrongCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get blankCount => $composableBuilder(
    column: $table.blankCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get mastered => $composableBuilder(
    column: $table.mastered,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastResult => $composableBuilder(
    column: $table.lastResult,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReviewItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReviewItemsTable> {
  $$ReviewItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wrongCount => $composableBuilder(
    column: $table.wrongCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get blankCount => $composableBuilder(
    column: $table.blankCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get mastered => $composableBuilder(
    column: $table.mastered,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastResult => $composableBuilder(
    column: $table.lastResult,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReviewItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReviewItemsTable> {
  $$ReviewItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get wrongCount => $composableBuilder(
    column: $table.wrongCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get blankCount => $composableBuilder(
    column: $table.blankCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<int> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get mastered =>
      $composableBuilder(column: $table.mastered, builder: (column) => column);

  GeneratedColumn<String> get lastResult => $composableBuilder(
    column: $table.lastResult,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReviewItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReviewItemsTable,
          ReviewItem,
          $$ReviewItemsTableFilterComposer,
          $$ReviewItemsTableOrderingComposer,
          $$ReviewItemsTableAnnotationComposer,
          $$ReviewItemsTableCreateCompanionBuilder,
          $$ReviewItemsTableUpdateCompanionBuilder,
          (
            ReviewItem,
            BaseReferences<_$AppDatabase, $ReviewItemsTable, ReviewItem>,
          ),
          ReviewItem,
          PrefetchHooks Function()
        > {
  $$ReviewItemsTableTableManager(_$AppDatabase db, $ReviewItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> questionId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> wrongCount = const Value.absent(),
                Value<int> blankCount = const Value.absent(),
                Value<int> stage = const Value.absent(),
                Value<int?> nextReviewAt = const Value.absent(),
                Value<bool> mastered = const Value.absent(),
                Value<String?> lastResult = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewItemsCompanion(
                questionId: questionId,
                source: source,
                wrongCount: wrongCount,
                blankCount: blankCount,
                stage: stage,
                nextReviewAt: nextReviewAt,
                mastered: mastered,
                lastResult: lastResult,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String questionId,
                Value<String> source = const Value.absent(),
                Value<int> wrongCount = const Value.absent(),
                Value<int> blankCount = const Value.absent(),
                Value<int> stage = const Value.absent(),
                Value<int?> nextReviewAt = const Value.absent(),
                Value<bool> mastered = const Value.absent(),
                Value<String?> lastResult = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ReviewItemsCompanion.insert(
                questionId: questionId,
                source: source,
                wrongCount: wrongCount,
                blankCount: blankCount,
                stage: stage,
                nextReviewAt: nextReviewAt,
                mastered: mastered,
                lastResult: lastResult,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReviewItemsTable, ReviewItem>(table),
                  BaseReferences<_$AppDatabase, $ReviewItemsTable, ReviewItem>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReviewItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReviewItemsTable,
      ReviewItem,
      $$ReviewItemsTableFilterComposer,
      $$ReviewItemsTableOrderingComposer,
      $$ReviewItemsTableAnnotationComposer,
      $$ReviewItemsTableCreateCompanionBuilder,
      $$ReviewItemsTableUpdateCompanionBuilder,
      (
        ReviewItem,
        BaseReferences<_$AppDatabase, $ReviewItemsTable, ReviewItem>,
      ),
      ReviewItem,
      PrefetchHooks Function()
    >;
typedef $$FavoritesTableCreateCompanionBuilder =
    FavoritesCompanion Function({
      required String questionId,
      required int createdAt,
      Value<String> note,
      Value<int> rowid,
    });
typedef $$FavoritesTableUpdateCompanionBuilder =
    FavoritesCompanion Function({
      Value<String> questionId,
      Value<int> createdAt,
      Value<String> note,
      Value<int> rowid,
    });

class $$FavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$FavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoritesTable,
          Favorite,
          $$FavoritesTableFilterComposer,
          $$FavoritesTableOrderingComposer,
          $$FavoritesTableAnnotationComposer,
          $$FavoritesTableCreateCompanionBuilder,
          $$FavoritesTableUpdateCompanionBuilder,
          (Favorite, BaseReferences<_$AppDatabase, $FavoritesTable, Favorite>),
          Favorite,
          PrefetchHooks Function()
        > {
  $$FavoritesTableTableManager(_$AppDatabase db, $FavoritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> questionId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion(
                questionId: questionId,
                createdAt: createdAt,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String questionId,
                required int createdAt,
                Value<String> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion.insert(
                questionId: questionId,
                createdAt: createdAt,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FavoritesTable, Favorite>(table),
                  BaseReferences<_$AppDatabase, $FavoritesTable, Favorite>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoritesTable,
      Favorite,
      $$FavoritesTableFilterComposer,
      $$FavoritesTableOrderingComposer,
      $$FavoritesTableAnnotationComposer,
      $$FavoritesTableCreateCompanionBuilder,
      $$FavoritesTableUpdateCompanionBuilder,
      (Favorite, BaseReferences<_$AppDatabase, $FavoritesTable, Favorite>),
      Favorite,
      PrefetchHooks Function()
    >;
typedef $$DailyStatsTableCreateCompanionBuilder =
    DailyStatsCompanion Function({
      required String day,
      Value<int> answeredCount,
      Value<int> correctCount,
      Value<int> durationMs,
      Value<int> sessionsCount,
      Value<int> rowid,
    });
typedef $$DailyStatsTableUpdateCompanionBuilder =
    DailyStatsCompanion Function({
      Value<String> day,
      Value<int> answeredCount,
      Value<int> correctCount,
      Value<int> durationMs,
      Value<int> sessionsCount,
      Value<int> rowid,
    });

class $$DailyStatsTableFilterComposer
    extends Composer<_$AppDatabase, $DailyStatsTable> {
  $$DailyStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get answeredCount => $composableBuilder(
    column: $table.answeredCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sessionsCount => $composableBuilder(
    column: $table.sessionsCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyStatsTable> {
  $$DailyStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get answeredCount => $composableBuilder(
    column: $table.answeredCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sessionsCount => $composableBuilder(
    column: $table.sessionsCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyStatsTable> {
  $$DailyStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<int> get answeredCount => $composableBuilder(
    column: $table.answeredCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sessionsCount => $composableBuilder(
    column: $table.sessionsCount,
    builder: (column) => column,
  );
}

class $$DailyStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyStatsTable,
          DailyStat,
          $$DailyStatsTableFilterComposer,
          $$DailyStatsTableOrderingComposer,
          $$DailyStatsTableAnnotationComposer,
          $$DailyStatsTableCreateCompanionBuilder,
          $$DailyStatsTableUpdateCompanionBuilder,
          (
            DailyStat,
            BaseReferences<_$AppDatabase, $DailyStatsTable, DailyStat>,
          ),
          DailyStat,
          PrefetchHooks Function()
        > {
  $$DailyStatsTableTableManager(_$AppDatabase db, $DailyStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> day = const Value.absent(),
                Value<int> answeredCount = const Value.absent(),
                Value<int> correctCount = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> sessionsCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyStatsCompanion(
                day: day,
                answeredCount: answeredCount,
                correctCount: correctCount,
                durationMs: durationMs,
                sessionsCount: sessionsCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String day,
                Value<int> answeredCount = const Value.absent(),
                Value<int> correctCount = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> sessionsCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyStatsCompanion.insert(
                day: day,
                answeredCount: answeredCount,
                correctCount: correctCount,
                durationMs: durationMs,
                sessionsCount: sessionsCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DailyStatsTable, DailyStat>(table),
                  BaseReferences<_$AppDatabase, $DailyStatsTable, DailyStat>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyStatsTable,
      DailyStat,
      $$DailyStatsTableFilterComposer,
      $$DailyStatsTableOrderingComposer,
      $$DailyStatsTableAnnotationComposer,
      $$DailyStatsTableCreateCompanionBuilder,
      $$DailyStatsTableUpdateCompanionBuilder,
      (DailyStat, BaseReferences<_$AppDatabase, $DailyStatsTable, DailyStat>),
      DailyStat,
      PrefetchHooks Function()
    >;
typedef $$ModuleStatsTableCreateCompanionBuilder =
    ModuleStatsCompanion Function({
      required String module,
      Value<int> answeredCount,
      Value<int> correctCount,
      Value<int> durationMs,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ModuleStatsTableUpdateCompanionBuilder =
    ModuleStatsCompanion Function({
      Value<String> module,
      Value<int> answeredCount,
      Value<int> correctCount,
      Value<int> durationMs,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$ModuleStatsTableFilterComposer
    extends Composer<_$AppDatabase, $ModuleStatsTable> {
  $$ModuleStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get answeredCount => $composableBuilder(
    column: $table.answeredCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ModuleStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $ModuleStatsTable> {
  $$ModuleStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get answeredCount => $composableBuilder(
    column: $table.answeredCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ModuleStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModuleStatsTable> {
  $$ModuleStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get module =>
      $composableBuilder(column: $table.module, builder: (column) => column);

  GeneratedColumn<int> get answeredCount => $composableBuilder(
    column: $table.answeredCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ModuleStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ModuleStatsTable,
          ModuleStat,
          $$ModuleStatsTableFilterComposer,
          $$ModuleStatsTableOrderingComposer,
          $$ModuleStatsTableAnnotationComposer,
          $$ModuleStatsTableCreateCompanionBuilder,
          $$ModuleStatsTableUpdateCompanionBuilder,
          (
            ModuleStat,
            BaseReferences<_$AppDatabase, $ModuleStatsTable, ModuleStat>,
          ),
          ModuleStat,
          PrefetchHooks Function()
        > {
  $$ModuleStatsTableTableManager(_$AppDatabase db, $ModuleStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModuleStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModuleStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModuleStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> module = const Value.absent(),
                Value<int> answeredCount = const Value.absent(),
                Value<int> correctCount = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModuleStatsCompanion(
                module: module,
                answeredCount: answeredCount,
                correctCount: correctCount,
                durationMs: durationMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String module,
                Value<int> answeredCount = const Value.absent(),
                Value<int> correctCount = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ModuleStatsCompanion.insert(
                module: module,
                answeredCount: answeredCount,
                correctCount: correctCount,
                durationMs: durationMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ModuleStatsTable, ModuleStat>(table),
                  BaseReferences<_$AppDatabase, $ModuleStatsTable, ModuleStat>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ModuleStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ModuleStatsTable,
      ModuleStat,
      $$ModuleStatsTableFilterComposer,
      $$ModuleStatsTableOrderingComposer,
      $$ModuleStatsTableAnnotationComposer,
      $$ModuleStatsTableCreateCompanionBuilder,
      $$ModuleStatsTableUpdateCompanionBuilder,
      (
        ModuleStat,
        BaseReferences<_$AppDatabase, $ModuleStatsTable, ModuleStat>,
      ),
      ModuleStat,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, AppSetting>(table),
                  BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PracticeSessionsTableTableManager get practiceSessions =>
      $$PracticeSessionsTableTableManager(_db, _db.practiceSessions);
  $$SessionQuestionsTableTableManager get sessionQuestions =>
      $$SessionQuestionsTableTableManager(_db, _db.sessionQuestions);
  $$SessionAnswersTableTableManager get sessionAnswers =>
      $$SessionAnswersTableTableManager(_db, _db.sessionAnswers);
  $$ReviewItemsTableTableManager get reviewItems =>
      $$ReviewItemsTableTableManager(_db, _db.reviewItems);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
  $$DailyStatsTableTableManager get dailyStats =>
      $$DailyStatsTableTableManager(_db, _db.dailyStats);
  $$ModuleStatsTableTableManager get moduleStats =>
      $$ModuleStatsTableTableManager(_db, _db.moduleStats);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}

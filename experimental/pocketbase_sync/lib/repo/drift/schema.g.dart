// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schema.dart';

// ignore_for_file: type=lint
class $SyncEntriesTable extends SyncEntries
    with TableInfo<$SyncEntriesTable, SyncEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionMeta =
      const VerificationMeta('collection');
  @override
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
      'collection', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
      'data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _baseDataMeta =
      const VerificationMeta('baseData');
  @override
  late final GeneratedColumn<String> baseData = GeneratedColumn<String>(
      'base_data', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _serverUpdatedAtMeta =
      const VerificationMeta('serverUpdatedAt');
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>('server_updated_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _isDirtyMeta =
      const VerificationMeta('isDirty');
  @override
  late final GeneratedColumn<bool> isDirty = GeneratedColumn<bool>(
      'is_dirty', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_dirty" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        collection,
        id,
        data,
        baseData,
        serverUpdatedAt,
        isDirty,
        isDeleted,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_entries';
  @override
  VerificationContext validateIntegrity(Insertable<SyncEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection')) {
      context.handle(
          _collectionMeta,
          collection.isAcceptableOrUnknown(
              data['collection']!, _collectionMeta));
    } else if (isInserting) {
      context.missing(_collectionMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
          _dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('base_data')) {
      context.handle(_baseDataMeta,
          baseData.isAcceptableOrUnknown(data['base_data']!, _baseDataMeta));
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
          _serverUpdatedAtMeta,
          serverUpdatedAt.isAcceptableOrUnknown(
              data['server_updated_at']!, _serverUpdatedAtMeta));
    }
    if (data.containsKey('is_dirty')) {
      context.handle(_isDirtyMeta,
          isDirty.isAcceptableOrUnknown(data['is_dirty']!, _isDirtyMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collection, id};
  @override
  SyncEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncEntry(
      collection: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}collection'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      data: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data'])!,
      baseData: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}base_data']),
      serverUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}server_updated_at']),
      isDirty: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_dirty'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $SyncEntriesTable createAlias(String alias) {
    return $SyncEntriesTable(attachedDatabase, alias);
  }
}

class SyncEntry extends DataClass implements Insertable<SyncEntry> {
  final String collection;
  final String id;

  /// serialized JSON of the current local data
  final String data;

  /// serialized JSON of the base data (snapshot)
  final String? baseData;
  final DateTime? serverUpdatedAt;
  final bool isDirty;
  final bool isDeleted;
  final DateTime? deletedAt;
  const SyncEntry(
      {required this.collection,
      required this.id,
      required this.data,
      this.baseData,
      this.serverUpdatedAt,
      required this.isDirty,
      required this.isDeleted,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection'] = Variable<String>(collection);
    map['id'] = Variable<String>(id);
    map['data'] = Variable<String>(data);
    if (!nullToAbsent || baseData != null) {
      map['base_data'] = Variable<String>(baseData);
    }
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    }
    map['is_dirty'] = Variable<bool>(isDirty);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  SyncEntriesCompanion toCompanion(bool nullToAbsent) {
    return SyncEntriesCompanion(
      collection: Value(collection),
      id: Value(id),
      data: Value(data),
      baseData: baseData == null && nullToAbsent
          ? const Value.absent()
          : Value(baseData),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
      isDirty: Value(isDirty),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory SyncEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncEntry(
      collection: serializer.fromJson<String>(json['collection']),
      id: serializer.fromJson<String>(json['id']),
      data: serializer.fromJson<String>(json['data']),
      baseData: serializer.fromJson<String?>(json['baseData']),
      serverUpdatedAt: serializer.fromJson<DateTime?>(json['serverUpdatedAt']),
      isDirty: serializer.fromJson<bool>(json['isDirty']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collection': serializer.toJson<String>(collection),
      'id': serializer.toJson<String>(id),
      'data': serializer.toJson<String>(data),
      'baseData': serializer.toJson<String?>(baseData),
      'serverUpdatedAt': serializer.toJson<DateTime?>(serverUpdatedAt),
      'isDirty': serializer.toJson<bool>(isDirty),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  SyncEntry copyWith(
          {String? collection,
          String? id,
          String? data,
          Value<String?> baseData = const Value.absent(),
          Value<DateTime?> serverUpdatedAt = const Value.absent(),
          bool? isDirty,
          bool? isDeleted,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      SyncEntry(
        collection: collection ?? this.collection,
        id: id ?? this.id,
        data: data ?? this.data,
        baseData: baseData.present ? baseData.value : this.baseData,
        serverUpdatedAt: serverUpdatedAt.present
            ? serverUpdatedAt.value
            : this.serverUpdatedAt,
        isDirty: isDirty ?? this.isDirty,
        isDeleted: isDeleted ?? this.isDeleted,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  SyncEntry copyWithCompanion(SyncEntriesCompanion data) {
    return SyncEntry(
      collection:
          data.collection.present ? data.collection.value : this.collection,
      id: data.id.present ? data.id.value : this.id,
      data: data.data.present ? data.data.value : this.data,
      baseData: data.baseData.present ? data.baseData.value : this.baseData,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
      isDirty: data.isDirty.present ? data.isDirty.value : this.isDirty,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncEntry(')
          ..write('collection: $collection, ')
          ..write('id: $id, ')
          ..write('data: $data, ')
          ..write('baseData: $baseData, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('isDirty: $isDirty, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collection, id, data, baseData,
      serverUpdatedAt, isDirty, isDeleted, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEntry &&
          other.collection == this.collection &&
          other.id == this.id &&
          other.data == this.data &&
          other.baseData == this.baseData &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.isDirty == this.isDirty &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt);
}

class SyncEntriesCompanion extends UpdateCompanion<SyncEntry> {
  final Value<String> collection;
  final Value<String> id;
  final Value<String> data;
  final Value<String?> baseData;
  final Value<DateTime?> serverUpdatedAt;
  final Value<bool> isDirty;
  final Value<bool> isDeleted;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const SyncEntriesCompanion({
    this.collection = const Value.absent(),
    this.id = const Value.absent(),
    this.data = const Value.absent(),
    this.baseData = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncEntriesCompanion.insert({
    required String collection,
    required String id,
    required String data,
    this.baseData = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : collection = Value(collection),
        id = Value(id),
        data = Value(data);
  static Insertable<SyncEntry> custom({
    Expression<String>? collection,
    Expression<String>? id,
    Expression<String>? data,
    Expression<String>? baseData,
    Expression<DateTime>? serverUpdatedAt,
    Expression<bool>? isDirty,
    Expression<bool>? isDeleted,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collection != null) 'collection': collection,
      if (id != null) 'id': id,
      if (data != null) 'data': data,
      if (baseData != null) 'base_data': baseData,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (isDirty != null) 'is_dirty': isDirty,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncEntriesCompanion copyWith(
      {Value<String>? collection,
      Value<String>? id,
      Value<String>? data,
      Value<String?>? baseData,
      Value<DateTime?>? serverUpdatedAt,
      Value<bool>? isDirty,
      Value<bool>? isDeleted,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return SyncEntriesCompanion(
      collection: collection ?? this.collection,
      id: id ?? this.id,
      data: data ?? this.data,
      baseData: baseData ?? this.baseData,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      isDirty: isDirty ?? this.isDirty,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (baseData.present) {
      map['base_data'] = Variable<String>(baseData.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (isDirty.present) {
      map['is_dirty'] = Variable<bool>(isDirty.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncEntriesCompanion(')
          ..write('collection: $collection, ')
          ..write('id: $id, ')
          ..write('data: $data, ')
          ..write('baseData: $baseData, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('isDirty: $isDirty, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMetaTable extends SyncMeta
    with TableInfo<$SyncMetaTable, SyncMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionMeta =
      const VerificationMeta('collection');
  @override
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
      'collection', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastSyncMeta =
      const VerificationMeta('lastSync');
  @override
  late final GeneratedColumn<DateTime> lastSync = GeneratedColumn<DateTime>(
      'last_sync', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: Constant(DateTime.fromMillisecondsSinceEpoch(0)));
  @override
  List<GeneratedColumn> get $columns => [collection, lastSync];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_meta';
  @override
  VerificationContext validateIntegrity(Insertable<SyncMetaData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection')) {
      context.handle(
          _collectionMeta,
          collection.isAcceptableOrUnknown(
              data['collection']!, _collectionMeta));
    } else if (isInserting) {
      context.missing(_collectionMeta);
    }
    if (data.containsKey('last_sync')) {
      context.handle(_lastSyncMeta,
          lastSync.isAcceptableOrUnknown(data['last_sync']!, _lastSyncMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collection};
  @override
  SyncMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetaData(
      collection: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}collection'])!,
      lastSync: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_sync'])!,
    );
  }

  @override
  $SyncMetaTable createAlias(String alias) {
    return $SyncMetaTable(attachedDatabase, alias);
  }
}

class SyncMetaData extends DataClass implements Insertable<SyncMetaData> {
  final String collection;
  final DateTime lastSync;
  const SyncMetaData({required this.collection, required this.lastSync});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection'] = Variable<String>(collection);
    map['last_sync'] = Variable<DateTime>(lastSync);
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(
      collection: Value(collection),
      lastSync: Value(lastSync),
    );
  }

  factory SyncMetaData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetaData(
      collection: serializer.fromJson<String>(json['collection']),
      lastSync: serializer.fromJson<DateTime>(json['lastSync']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collection': serializer.toJson<String>(collection),
      'lastSync': serializer.toJson<DateTime>(lastSync),
    };
  }

  SyncMetaData copyWith({String? collection, DateTime? lastSync}) =>
      SyncMetaData(
        collection: collection ?? this.collection,
        lastSync: lastSync ?? this.lastSync,
      );
  SyncMetaData copyWithCompanion(SyncMetaCompanion data) {
    return SyncMetaData(
      collection:
          data.collection.present ? data.collection.value : this.collection,
      lastSync: data.lastSync.present ? data.lastSync.value : this.lastSync,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaData(')
          ..write('collection: $collection, ')
          ..write('lastSync: $lastSync')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collection, lastSync);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetaData &&
          other.collection == this.collection &&
          other.lastSync == this.lastSync);
}

class SyncMetaCompanion extends UpdateCompanion<SyncMetaData> {
  final Value<String> collection;
  final Value<DateTime> lastSync;
  final Value<int> rowid;
  const SyncMetaCompanion({
    this.collection = const Value.absent(),
    this.lastSync = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    required String collection,
    this.lastSync = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : collection = Value(collection);
  static Insertable<SyncMetaData> custom({
    Expression<String>? collection,
    Expression<DateTime>? lastSync,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collection != null) 'collection': collection,
      if (lastSync != null) 'last_sync': lastSync,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetaCompanion copyWith(
      {Value<String>? collection,
      Value<DateTime>? lastSync,
      Value<int>? rowid}) {
    return SyncMetaCompanion(
      collection: collection ?? this.collection,
      lastSync: lastSync ?? this.lastSync,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    if (lastSync.present) {
      map['last_sync'] = Variable<DateTime>(lastSync.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaCompanion(')
          ..write('collection: $collection, ')
          ..write('lastSync: $lastSync, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$PackageDatabase extends GeneratedDatabase {
  _$PackageDatabase(QueryExecutor e) : super(e);
  $PackageDatabaseManager get managers => $PackageDatabaseManager(this);
  late final $SyncEntriesTable syncEntries = $SyncEntriesTable(this);
  late final $SyncMetaTable syncMeta = $SyncMetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [syncEntries, syncMeta];
}

typedef $$SyncEntriesTableCreateCompanionBuilder = SyncEntriesCompanion
    Function({
  required String collection,
  required String id,
  required String data,
  Value<String?> baseData,
  Value<DateTime?> serverUpdatedAt,
  Value<bool> isDirty,
  Value<bool> isDeleted,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$SyncEntriesTableUpdateCompanionBuilder = SyncEntriesCompanion
    Function({
  Value<String> collection,
  Value<String> id,
  Value<String> data,
  Value<String?> baseData,
  Value<DateTime?> serverUpdatedAt,
  Value<bool> isDirty,
  Value<bool> isDeleted,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$SyncEntriesTableFilterComposer
    extends Composer<_$PackageDatabase, $SyncEntriesTable> {
  $$SyncEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get collection => $composableBuilder(
      column: $table.collection, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get baseData => $composableBuilder(
      column: $table.baseData, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
      column: $table.serverUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDirty => $composableBuilder(
      column: $table.isDirty, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$SyncEntriesTableOrderingComposer
    extends Composer<_$PackageDatabase, $SyncEntriesTable> {
  $$SyncEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get collection => $composableBuilder(
      column: $table.collection, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get baseData => $composableBuilder(
      column: $table.baseData, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
      column: $table.serverUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDirty => $composableBuilder(
      column: $table.isDirty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncEntriesTableAnnotationComposer
    extends Composer<_$PackageDatabase, $SyncEntriesTable> {
  $$SyncEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get collection => $composableBuilder(
      column: $table.collection, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get baseData =>
      $composableBuilder(column: $table.baseData, builder: (column) => column);

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
      column: $table.serverUpdatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDirty =>
      $composableBuilder(column: $table.isDirty, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$SyncEntriesTableTableManager extends RootTableManager<
    _$PackageDatabase,
    $SyncEntriesTable,
    SyncEntry,
    $$SyncEntriesTableFilterComposer,
    $$SyncEntriesTableOrderingComposer,
    $$SyncEntriesTableAnnotationComposer,
    $$SyncEntriesTableCreateCompanionBuilder,
    $$SyncEntriesTableUpdateCompanionBuilder,
    (
      SyncEntry,
      BaseReferences<_$PackageDatabase, $SyncEntriesTable, SyncEntry>
    ),
    SyncEntry,
    PrefetchHooks Function()> {
  $$SyncEntriesTableTableManager(_$PackageDatabase db, $SyncEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> collection = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> data = const Value.absent(),
            Value<String?> baseData = const Value.absent(),
            Value<DateTime?> serverUpdatedAt = const Value.absent(),
            Value<bool> isDirty = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncEntriesCompanion(
            collection: collection,
            id: id,
            data: data,
            baseData: baseData,
            serverUpdatedAt: serverUpdatedAt,
            isDirty: isDirty,
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String collection,
            required String id,
            required String data,
            Value<String?> baseData = const Value.absent(),
            Value<DateTime?> serverUpdatedAt = const Value.absent(),
            Value<bool> isDirty = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncEntriesCompanion.insert(
            collection: collection,
            id: id,
            data: data,
            baseData: baseData,
            serverUpdatedAt: serverUpdatedAt,
            isDirty: isDirty,
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncEntriesTableProcessedTableManager = ProcessedTableManager<
    _$PackageDatabase,
    $SyncEntriesTable,
    SyncEntry,
    $$SyncEntriesTableFilterComposer,
    $$SyncEntriesTableOrderingComposer,
    $$SyncEntriesTableAnnotationComposer,
    $$SyncEntriesTableCreateCompanionBuilder,
    $$SyncEntriesTableUpdateCompanionBuilder,
    (
      SyncEntry,
      BaseReferences<_$PackageDatabase, $SyncEntriesTable, SyncEntry>
    ),
    SyncEntry,
    PrefetchHooks Function()>;
typedef $$SyncMetaTableCreateCompanionBuilder = SyncMetaCompanion Function({
  required String collection,
  Value<DateTime> lastSync,
  Value<int> rowid,
});
typedef $$SyncMetaTableUpdateCompanionBuilder = SyncMetaCompanion Function({
  Value<String> collection,
  Value<DateTime> lastSync,
  Value<int> rowid,
});

class $$SyncMetaTableFilterComposer
    extends Composer<_$PackageDatabase, $SyncMetaTable> {
  $$SyncMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get collection => $composableBuilder(
      column: $table.collection, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSync => $composableBuilder(
      column: $table.lastSync, builder: (column) => ColumnFilters(column));
}

class $$SyncMetaTableOrderingComposer
    extends Composer<_$PackageDatabase, $SyncMetaTable> {
  $$SyncMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get collection => $composableBuilder(
      column: $table.collection, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSync => $composableBuilder(
      column: $table.lastSync, builder: (column) => ColumnOrderings(column));
}

class $$SyncMetaTableAnnotationComposer
    extends Composer<_$PackageDatabase, $SyncMetaTable> {
  $$SyncMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get collection => $composableBuilder(
      column: $table.collection, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSync =>
      $composableBuilder(column: $table.lastSync, builder: (column) => column);
}

class $$SyncMetaTableTableManager extends RootTableManager<
    _$PackageDatabase,
    $SyncMetaTable,
    SyncMetaData,
    $$SyncMetaTableFilterComposer,
    $$SyncMetaTableOrderingComposer,
    $$SyncMetaTableAnnotationComposer,
    $$SyncMetaTableCreateCompanionBuilder,
    $$SyncMetaTableUpdateCompanionBuilder,
    (
      SyncMetaData,
      BaseReferences<_$PackageDatabase, $SyncMetaTable, SyncMetaData>
    ),
    SyncMetaData,
    PrefetchHooks Function()> {
  $$SyncMetaTableTableManager(_$PackageDatabase db, $SyncMetaTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> collection = const Value.absent(),
            Value<DateTime> lastSync = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncMetaCompanion(
            collection: collection,
            lastSync: lastSync,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String collection,
            Value<DateTime> lastSync = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncMetaCompanion.insert(
            collection: collection,
            lastSync: lastSync,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncMetaTableProcessedTableManager = ProcessedTableManager<
    _$PackageDatabase,
    $SyncMetaTable,
    SyncMetaData,
    $$SyncMetaTableFilterComposer,
    $$SyncMetaTableOrderingComposer,
    $$SyncMetaTableAnnotationComposer,
    $$SyncMetaTableCreateCompanionBuilder,
    $$SyncMetaTableUpdateCompanionBuilder,
    (
      SyncMetaData,
      BaseReferences<_$PackageDatabase, $SyncMetaTable, SyncMetaData>
    ),
    SyncMetaData,
    PrefetchHooks Function()>;

class $PackageDatabaseManager {
  final _$PackageDatabase _db;
  $PackageDatabaseManager(this._db);
  $$SyncEntriesTableTableManager get syncEntries =>
      $$SyncEntriesTableTableManager(_db, _db.syncEntries);
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db, _db.syncMeta);
}

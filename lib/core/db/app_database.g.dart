// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TodoListsTable extends TodoLists
    with TableInfo<$TodoListsTable, TodoList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderLocalIdMeta = const VerificationMeta(
    'folderLocalId',
  );
  @override
  late final GeneratedColumn<String> folderLocalId = GeneratedColumn<String>(
    'folder_local_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<int> folderId = GeneratedColumn<int>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _accessRoleMeta = const VerificationMeta(
    'accessRole',
  );
  @override
  late final GeneratedColumn<String> accessRole = GeneratedColumn<String>(
    'access_role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('owner'),
  );
  static const VerificationMeta _writableMeta = const VerificationMeta(
    'writable',
  );
  @override
  late final GeneratedColumn<bool> writable = GeneratedColumn<bool>(
    'writable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("writable" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    name,
    folderLocalId,
    folderId,
    sortOrder,
    accessRole,
    writable,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoList> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('folder_local_id')) {
      context.handle(
        _folderLocalIdMeta,
        folderLocalId.isAcceptableOrUnknown(
          data['folder_local_id']!,
          _folderLocalIdMeta,
        ),
      );
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('access_role')) {
      context.handle(
        _accessRoleMeta,
        accessRole.isAcceptableOrUnknown(data['access_role']!, _accessRoleMeta),
      );
    }
    if (data.containsKey('writable')) {
      context.handle(
        _writableMeta,
        writable.isAcceptableOrUnknown(data['writable']!, _writableMeta),
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
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoList(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      folderLocalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_local_id'],
      ),
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      accessRole: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}access_role'],
      )!,
      writable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}writable'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TodoListsTable createAlias(String alias) {
    return $TodoListsTable(attachedDatabase, alias);
  }
}

class TodoList extends DataClass implements Insertable<TodoList> {
  final String id;
  final int? serverId;
  final String name;

  /// 本地 UUID，指向 [TodoFolders.id]；UI、Repository 与离线关联只使用此列。
  final String? folderLocalId;

  /// folder REST 服务端整数 ID 缓存，仅供同步协议和旧数据迁移使用。
  final int? folderId;
  final int sortOrder;
  final String accessRole;
  final bool writable;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoList({
    required this.id,
    this.serverId,
    required this.name,
    this.folderLocalId,
    this.folderId,
    required this.sortOrder,
    required this.accessRole,
    required this.writable,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || folderLocalId != null) {
      map['folder_local_id'] = Variable<String>(folderLocalId);
    }
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<int>(folderId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['access_role'] = Variable<String>(accessRole);
    map['writable'] = Variable<bool>(writable);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TodoListsCompanion toCompanion(bool nullToAbsent) {
    return TodoListsCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      name: Value(name),
      folderLocalId: folderLocalId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderLocalId),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      sortOrder: Value(sortOrder),
      accessRole: Value(accessRole),
      writable: Value(writable),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory TodoList.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoList(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      name: serializer.fromJson<String>(json['name']),
      folderLocalId: serializer.fromJson<String?>(json['folderLocalId']),
      folderId: serializer.fromJson<int?>(json['folderId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      accessRole: serializer.fromJson<String>(json['accessRole']),
      writable: serializer.fromJson<bool>(json['writable']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'name': serializer.toJson<String>(name),
      'folderLocalId': serializer.toJson<String?>(folderLocalId),
      'folderId': serializer.toJson<int?>(folderId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'accessRole': serializer.toJson<String>(accessRole),
      'writable': serializer.toJson<bool>(writable),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoList copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    String? name,
    Value<String?> folderLocalId = const Value.absent(),
    Value<int?> folderId = const Value.absent(),
    int? sortOrder,
    String? accessRole,
    bool? writable,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoList(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    name: name ?? this.name,
    folderLocalId: folderLocalId.present
        ? folderLocalId.value
        : this.folderLocalId,
    folderId: folderId.present ? folderId.value : this.folderId,
    sortOrder: sortOrder ?? this.sortOrder,
    accessRole: accessRole ?? this.accessRole,
    writable: writable ?? this.writable,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoList copyWithCompanion(TodoListsCompanion data) {
    return TodoList(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      name: data.name.present ? data.name.value : this.name,
      folderLocalId: data.folderLocalId.present
          ? data.folderLocalId.value
          : this.folderLocalId,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      accessRole: data.accessRole.present
          ? data.accessRole.value
          : this.accessRole,
      writable: data.writable.present ? data.writable.value : this.writable,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoList(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('folderLocalId: $folderLocalId, ')
          ..write('folderId: $folderId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('accessRole: $accessRole, ')
          ..write('writable: $writable, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    name,
    folderLocalId,
    folderId,
    sortOrder,
    accessRole,
    writable,
    updatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoList &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.name == this.name &&
          other.folderLocalId == this.folderLocalId &&
          other.folderId == this.folderId &&
          other.sortOrder == this.sortOrder &&
          other.accessRole == this.accessRole &&
          other.writable == this.writable &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoListsCompanion extends UpdateCompanion<TodoList> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<String> name;
  final Value<String?> folderLocalId;
  final Value<int?> folderId;
  final Value<int> sortOrder;
  final Value<String> accessRole;
  final Value<bool> writable;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TodoListsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.name = const Value.absent(),
    this.folderLocalId = const Value.absent(),
    this.folderId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.accessRole = const Value.absent(),
    this.writable = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoListsCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String name,
    this.folderLocalId = const Value.absent(),
    this.folderId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.accessRole = const Value.absent(),
    this.writable = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoList> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<String>? name,
    Expression<String>? folderLocalId,
    Expression<int>? folderId,
    Expression<int>? sortOrder,
    Expression<String>? accessRole,
    Expression<bool>? writable,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (name != null) 'name': name,
      if (folderLocalId != null) 'folder_local_id': folderLocalId,
      if (folderId != null) 'folder_id': folderId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (accessRole != null) 'access_role': accessRole,
      if (writable != null) 'writable': writable,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoListsCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<String>? name,
    Value<String?>? folderLocalId,
    Value<int?>? folderId,
    Value<int>? sortOrder,
    Value<String>? accessRole,
    Value<bool>? writable,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TodoListsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      folderLocalId: folderLocalId ?? this.folderLocalId,
      folderId: folderId ?? this.folderId,
      sortOrder: sortOrder ?? this.sortOrder,
      accessRole: accessRole ?? this.accessRole,
      writable: writable ?? this.writable,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (folderLocalId.present) {
      map['folder_local_id'] = Variable<String>(folderLocalId.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<int>(folderId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (accessRole.present) {
      map['access_role'] = Variable<String>(accessRole.value);
    }
    if (writable.present) {
      map['writable'] = Variable<bool>(writable.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoListsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('folderLocalId: $folderLocalId, ')
          ..write('folderId: $folderId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('accessRole: $accessRole, ')
          ..write('writable: $writable, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoTaskSectionsTable extends TodoTaskSections
    with TableInfo<$TodoTaskSectionsTable, TodoTaskSection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoTaskSectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
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
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    listId,
    name,
    sortOrder,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_task_sections';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoTaskSection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
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
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoTaskSection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoTaskSection(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TodoTaskSectionsTable createAlias(String alias) {
    return $TodoTaskSectionsTable(attachedDatabase, alias);
  }
}

class TodoTaskSection extends DataClass implements Insertable<TodoTaskSection> {
  final String id;
  final int? serverId;
  final String listId;
  final String name;
  final int sortOrder;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoTaskSection({
    required this.id,
    this.serverId,
    required this.listId,
    required this.name,
    required this.sortOrder,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['list_id'] = Variable<String>(listId);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TodoTaskSectionsCompanion toCompanion(bool nullToAbsent) {
    return TodoTaskSectionsCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      listId: Value(listId),
      name: Value(name),
      sortOrder: Value(sortOrder),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory TodoTaskSection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoTaskSection(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      listId: serializer.fromJson<String>(json['listId']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'listId': serializer.toJson<String>(listId),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoTaskSection copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    String? listId,
    String? name,
    int? sortOrder,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoTaskSection(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    listId: listId ?? this.listId,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoTaskSection copyWithCompanion(TodoTaskSectionsCompanion data) {
    return TodoTaskSection(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      listId: data.listId.present ? data.listId.value : this.listId,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoTaskSection(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('listId: $listId, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, serverId, listId, name, sortOrder, updatedAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoTaskSection &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.listId == this.listId &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoTaskSectionsCompanion extends UpdateCompanion<TodoTaskSection> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<String> listId;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TodoTaskSectionsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.listId = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoTaskSectionsCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String listId,
    required String name,
    this.sortOrder = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       listId = Value(listId),
       name = Value(name),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoTaskSection> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<String>? listId,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (listId != null) 'list_id': listId,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoTaskSectionsCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<String>? listId,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TodoTaskSectionsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoTaskSectionsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('listId: $listId, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoTasksTable extends TodoTasks
    with TableInfo<$TodoTasksTable, TodoTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sectionIdMeta = const VerificationMeta(
    'sectionId',
  );
  @override
  late final GeneratedColumn<String> sectionId = GeneratedColumn<String>(
    'section_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentTaskIdMeta = const VerificationMeta(
    'parentTaskId',
  );
  @override
  late final GeneratedColumn<String> parentTaskId = GeneratedColumn<String>(
    'parent_task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cancelledMeta = const VerificationMeta(
    'cancelled',
  );
  @override
  late final GeneratedColumn<bool> cancelled = GeneratedColumn<bool>(
    'cancelled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("cancelled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _assigneeUserIdMeta = const VerificationMeta(
    'assigneeUserId',
  );
  @override
  late final GeneratedColumn<int> assigneeUserId = GeneratedColumn<int>(
    'assignee_user_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assigneeUserNameMeta = const VerificationMeta(
    'assigneeUserName',
  );
  @override
  late final GeneratedColumn<String> assigneeUserName = GeneratedColumn<String>(
    'assignee_user_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _startAtMeta = const VerificationMeta(
    'startAt',
  );
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
    'start_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<DateTime> endAt = GeneratedColumn<DateTime>(
    'end_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allDayMeta = const VerificationMeta('allDay');
  @override
  late final GeneratedColumn<bool> allDay = GeneratedColumn<bool>(
    'all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("all_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _timeZoneMeta = const VerificationMeta(
    'timeZone',
  );
  @override
  late final GeneratedColumn<String> timeZone = GeneratedColumn<String>(
    'time_zone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fixedTimezoneMeta = const VerificationMeta(
    'fixedTimezone',
  );
  @override
  late final GeneratedColumn<bool> fixedTimezone = GeneratedColumn<bool>(
    'fixed_timezone',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("fixed_timezone" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _repeatParentTaskIdMeta =
      const VerificationMeta('repeatParentTaskId');
  @override
  late final GeneratedColumn<String> repeatParentTaskId =
      GeneratedColumn<String>(
        'repeat_parent_task_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _repeatRuleIdMeta = const VerificationMeta(
    'repeatRuleId',
  );
  @override
  late final GeneratedColumn<String> repeatRuleId = GeneratedColumn<String>(
    'repeat_rule_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repeatOccurrenceAtMeta =
      const VerificationMeta('repeatOccurrenceAt');
  @override
  late final GeneratedColumn<DateTime> repeatOccurrenceAt =
      GeneratedColumn<DateTime>(
        'repeat_occurrence_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    listId,
    sectionId,
    parentTaskId,
    title,
    description,
    completed,
    completedAt,
    cancelled,
    priority,
    isPinned,
    assigneeUserId,
    assigneeUserName,
    sortOrder,
    startAt,
    endAt,
    dueAt,
    allDay,
    timeZone,
    fixedTimezone,
    repeatParentTaskId,
    repeatRuleId,
    repeatOccurrenceAt,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoTask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('section_id')) {
      context.handle(
        _sectionIdMeta,
        sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta),
      );
    }
    if (data.containsKey('parent_task_id')) {
      context.handle(
        _parentTaskIdMeta,
        parentTaskId.isAcceptableOrUnknown(
          data['parent_task_id']!,
          _parentTaskIdMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('cancelled')) {
      context.handle(
        _cancelledMeta,
        cancelled.isAcceptableOrUnknown(data['cancelled']!, _cancelledMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('assignee_user_id')) {
      context.handle(
        _assigneeUserIdMeta,
        assigneeUserId.isAcceptableOrUnknown(
          data['assignee_user_id']!,
          _assigneeUserIdMeta,
        ),
      );
    }
    if (data.containsKey('assignee_user_name')) {
      context.handle(
        _assigneeUserNameMeta,
        assigneeUserName.isAcceptableOrUnknown(
          data['assignee_user_name']!,
          _assigneeUserNameMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('start_at')) {
      context.handle(
        _startAtMeta,
        startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta),
      );
    }
    if (data.containsKey('end_at')) {
      context.handle(
        _endAtMeta,
        endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta),
      );
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('all_day')) {
      context.handle(
        _allDayMeta,
        allDay.isAcceptableOrUnknown(data['all_day']!, _allDayMeta),
      );
    }
    if (data.containsKey('time_zone')) {
      context.handle(
        _timeZoneMeta,
        timeZone.isAcceptableOrUnknown(data['time_zone']!, _timeZoneMeta),
      );
    }
    if (data.containsKey('fixed_timezone')) {
      context.handle(
        _fixedTimezoneMeta,
        fixedTimezone.isAcceptableOrUnknown(
          data['fixed_timezone']!,
          _fixedTimezoneMeta,
        ),
      );
    }
    if (data.containsKey('repeat_parent_task_id')) {
      context.handle(
        _repeatParentTaskIdMeta,
        repeatParentTaskId.isAcceptableOrUnknown(
          data['repeat_parent_task_id']!,
          _repeatParentTaskIdMeta,
        ),
      );
    }
    if (data.containsKey('repeat_rule_id')) {
      context.handle(
        _repeatRuleIdMeta,
        repeatRuleId.isAcceptableOrUnknown(
          data['repeat_rule_id']!,
          _repeatRuleIdMeta,
        ),
      );
    }
    if (data.containsKey('repeat_occurrence_at')) {
      context.handle(
        _repeatOccurrenceAtMeta,
        repeatOccurrenceAt.isAcceptableOrUnknown(
          data['repeat_occurrence_at']!,
          _repeatOccurrenceAtMeta,
        ),
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
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoTask(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      )!,
      sectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_id'],
      ),
      parentTaskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_task_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      cancelled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}cancelled'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      assigneeUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}assignee_user_id'],
      ),
      assigneeUserName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assignee_user_name'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      startAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_at'],
      ),
      endAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_at'],
      ),
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      ),
      allDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}all_day'],
      )!,
      timeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone'],
      ),
      fixedTimezone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}fixed_timezone'],
      )!,
      repeatParentTaskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_parent_task_id'],
      ),
      repeatRuleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_rule_id'],
      ),
      repeatOccurrenceAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}repeat_occurrence_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TodoTasksTable createAlias(String alias) {
    return $TodoTasksTable(attachedDatabase, alias);
  }
}

class TodoTask extends DataClass implements Insertable<TodoTask> {
  final String id;
  final int? serverId;
  final String listId;
  final String? sectionId;
  final String? parentTaskId;
  final String title;
  final String? description;
  final bool completed;
  final DateTime? completedAt;
  final bool cancelled;
  final int priority;
  final bool isPinned;
  final int? assigneeUserId;
  final String? assigneeUserName;
  final int sortOrder;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? dueAt;
  final bool allDay;

  /// IANA 时区；固定时区任务必须保留墙上时间所属的时区，不能只依赖设备时区。
  final String? timeZone;
  final bool fixedTimezone;

  /// 本地 UUID，指向服务端物化实例的源任务。
  final String? repeatParentTaskId;

  /// 本地 UUID，指向触发本实例的重复规则。
  final String? repeatRuleId;
  final DateTime? repeatOccurrenceAt;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoTask({
    required this.id,
    this.serverId,
    required this.listId,
    this.sectionId,
    this.parentTaskId,
    required this.title,
    this.description,
    required this.completed,
    this.completedAt,
    required this.cancelled,
    required this.priority,
    required this.isPinned,
    this.assigneeUserId,
    this.assigneeUserName,
    required this.sortOrder,
    this.startAt,
    this.endAt,
    this.dueAt,
    required this.allDay,
    this.timeZone,
    required this.fixedTimezone,
    this.repeatParentTaskId,
    this.repeatRuleId,
    this.repeatOccurrenceAt,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['list_id'] = Variable<String>(listId);
    if (!nullToAbsent || sectionId != null) {
      map['section_id'] = Variable<String>(sectionId);
    }
    if (!nullToAbsent || parentTaskId != null) {
      map['parent_task_id'] = Variable<String>(parentTaskId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['completed'] = Variable<bool>(completed);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['cancelled'] = Variable<bool>(cancelled);
    map['priority'] = Variable<int>(priority);
    map['is_pinned'] = Variable<bool>(isPinned);
    if (!nullToAbsent || assigneeUserId != null) {
      map['assignee_user_id'] = Variable<int>(assigneeUserId);
    }
    if (!nullToAbsent || assigneeUserName != null) {
      map['assignee_user_name'] = Variable<String>(assigneeUserName);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || startAt != null) {
      map['start_at'] = Variable<DateTime>(startAt);
    }
    if (!nullToAbsent || endAt != null) {
      map['end_at'] = Variable<DateTime>(endAt);
    }
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<DateTime>(dueAt);
    }
    map['all_day'] = Variable<bool>(allDay);
    if (!nullToAbsent || timeZone != null) {
      map['time_zone'] = Variable<String>(timeZone);
    }
    map['fixed_timezone'] = Variable<bool>(fixedTimezone);
    if (!nullToAbsent || repeatParentTaskId != null) {
      map['repeat_parent_task_id'] = Variable<String>(repeatParentTaskId);
    }
    if (!nullToAbsent || repeatRuleId != null) {
      map['repeat_rule_id'] = Variable<String>(repeatRuleId);
    }
    if (!nullToAbsent || repeatOccurrenceAt != null) {
      map['repeat_occurrence_at'] = Variable<DateTime>(repeatOccurrenceAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TodoTasksCompanion toCompanion(bool nullToAbsent) {
    return TodoTasksCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      listId: Value(listId),
      sectionId: sectionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sectionId),
      parentTaskId: parentTaskId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentTaskId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      completed: Value(completed),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      cancelled: Value(cancelled),
      priority: Value(priority),
      isPinned: Value(isPinned),
      assigneeUserId: assigneeUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(assigneeUserId),
      assigneeUserName: assigneeUserName == null && nullToAbsent
          ? const Value.absent()
          : Value(assigneeUserName),
      sortOrder: Value(sortOrder),
      startAt: startAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startAt),
      endAt: endAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endAt),
      dueAt: dueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAt),
      allDay: Value(allDay),
      timeZone: timeZone == null && nullToAbsent
          ? const Value.absent()
          : Value(timeZone),
      fixedTimezone: Value(fixedTimezone),
      repeatParentTaskId: repeatParentTaskId == null && nullToAbsent
          ? const Value.absent()
          : Value(repeatParentTaskId),
      repeatRuleId: repeatRuleId == null && nullToAbsent
          ? const Value.absent()
          : Value(repeatRuleId),
      repeatOccurrenceAt: repeatOccurrenceAt == null && nullToAbsent
          ? const Value.absent()
          : Value(repeatOccurrenceAt),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory TodoTask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoTask(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      listId: serializer.fromJson<String>(json['listId']),
      sectionId: serializer.fromJson<String?>(json['sectionId']),
      parentTaskId: serializer.fromJson<String?>(json['parentTaskId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      completed: serializer.fromJson<bool>(json['completed']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      cancelled: serializer.fromJson<bool>(json['cancelled']),
      priority: serializer.fromJson<int>(json['priority']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      assigneeUserId: serializer.fromJson<int?>(json['assigneeUserId']),
      assigneeUserName: serializer.fromJson<String?>(json['assigneeUserName']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      startAt: serializer.fromJson<DateTime?>(json['startAt']),
      endAt: serializer.fromJson<DateTime?>(json['endAt']),
      dueAt: serializer.fromJson<DateTime?>(json['dueAt']),
      allDay: serializer.fromJson<bool>(json['allDay']),
      timeZone: serializer.fromJson<String?>(json['timeZone']),
      fixedTimezone: serializer.fromJson<bool>(json['fixedTimezone']),
      repeatParentTaskId: serializer.fromJson<String?>(
        json['repeatParentTaskId'],
      ),
      repeatRuleId: serializer.fromJson<String?>(json['repeatRuleId']),
      repeatOccurrenceAt: serializer.fromJson<DateTime?>(
        json['repeatOccurrenceAt'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'listId': serializer.toJson<String>(listId),
      'sectionId': serializer.toJson<String?>(sectionId),
      'parentTaskId': serializer.toJson<String?>(parentTaskId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'completed': serializer.toJson<bool>(completed),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'cancelled': serializer.toJson<bool>(cancelled),
      'priority': serializer.toJson<int>(priority),
      'isPinned': serializer.toJson<bool>(isPinned),
      'assigneeUserId': serializer.toJson<int?>(assigneeUserId),
      'assigneeUserName': serializer.toJson<String?>(assigneeUserName),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'startAt': serializer.toJson<DateTime?>(startAt),
      'endAt': serializer.toJson<DateTime?>(endAt),
      'dueAt': serializer.toJson<DateTime?>(dueAt),
      'allDay': serializer.toJson<bool>(allDay),
      'timeZone': serializer.toJson<String?>(timeZone),
      'fixedTimezone': serializer.toJson<bool>(fixedTimezone),
      'repeatParentTaskId': serializer.toJson<String?>(repeatParentTaskId),
      'repeatRuleId': serializer.toJson<String?>(repeatRuleId),
      'repeatOccurrenceAt': serializer.toJson<DateTime?>(repeatOccurrenceAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoTask copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    String? listId,
    Value<String?> sectionId = const Value.absent(),
    Value<String?> parentTaskId = const Value.absent(),
    String? title,
    Value<String?> description = const Value.absent(),
    bool? completed,
    Value<DateTime?> completedAt = const Value.absent(),
    bool? cancelled,
    int? priority,
    bool? isPinned,
    Value<int?> assigneeUserId = const Value.absent(),
    Value<String?> assigneeUserName = const Value.absent(),
    int? sortOrder,
    Value<DateTime?> startAt = const Value.absent(),
    Value<DateTime?> endAt = const Value.absent(),
    Value<DateTime?> dueAt = const Value.absent(),
    bool? allDay,
    Value<String?> timeZone = const Value.absent(),
    bool? fixedTimezone,
    Value<String?> repeatParentTaskId = const Value.absent(),
    Value<String?> repeatRuleId = const Value.absent(),
    Value<DateTime?> repeatOccurrenceAt = const Value.absent(),
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoTask(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    listId: listId ?? this.listId,
    sectionId: sectionId.present ? sectionId.value : this.sectionId,
    parentTaskId: parentTaskId.present ? parentTaskId.value : this.parentTaskId,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    completed: completed ?? this.completed,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    cancelled: cancelled ?? this.cancelled,
    priority: priority ?? this.priority,
    isPinned: isPinned ?? this.isPinned,
    assigneeUserId: assigneeUserId.present
        ? assigneeUserId.value
        : this.assigneeUserId,
    assigneeUserName: assigneeUserName.present
        ? assigneeUserName.value
        : this.assigneeUserName,
    sortOrder: sortOrder ?? this.sortOrder,
    startAt: startAt.present ? startAt.value : this.startAt,
    endAt: endAt.present ? endAt.value : this.endAt,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    allDay: allDay ?? this.allDay,
    timeZone: timeZone.present ? timeZone.value : this.timeZone,
    fixedTimezone: fixedTimezone ?? this.fixedTimezone,
    repeatParentTaskId: repeatParentTaskId.present
        ? repeatParentTaskId.value
        : this.repeatParentTaskId,
    repeatRuleId: repeatRuleId.present ? repeatRuleId.value : this.repeatRuleId,
    repeatOccurrenceAt: repeatOccurrenceAt.present
        ? repeatOccurrenceAt.value
        : this.repeatOccurrenceAt,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoTask copyWithCompanion(TodoTasksCompanion data) {
    return TodoTask(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      listId: data.listId.present ? data.listId.value : this.listId,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      parentTaskId: data.parentTaskId.present
          ? data.parentTaskId.value
          : this.parentTaskId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      completed: data.completed.present ? data.completed.value : this.completed,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      cancelled: data.cancelled.present ? data.cancelled.value : this.cancelled,
      priority: data.priority.present ? data.priority.value : this.priority,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      assigneeUserId: data.assigneeUserId.present
          ? data.assigneeUserId.value
          : this.assigneeUserId,
      assigneeUserName: data.assigneeUserName.present
          ? data.assigneeUserName.value
          : this.assigneeUserName,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      allDay: data.allDay.present ? data.allDay.value : this.allDay,
      timeZone: data.timeZone.present ? data.timeZone.value : this.timeZone,
      fixedTimezone: data.fixedTimezone.present
          ? data.fixedTimezone.value
          : this.fixedTimezone,
      repeatParentTaskId: data.repeatParentTaskId.present
          ? data.repeatParentTaskId.value
          : this.repeatParentTaskId,
      repeatRuleId: data.repeatRuleId.present
          ? data.repeatRuleId.value
          : this.repeatRuleId,
      repeatOccurrenceAt: data.repeatOccurrenceAt.present
          ? data.repeatOccurrenceAt.value
          : this.repeatOccurrenceAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoTask(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('listId: $listId, ')
          ..write('sectionId: $sectionId, ')
          ..write('parentTaskId: $parentTaskId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('completed: $completed, ')
          ..write('completedAt: $completedAt, ')
          ..write('cancelled: $cancelled, ')
          ..write('priority: $priority, ')
          ..write('isPinned: $isPinned, ')
          ..write('assigneeUserId: $assigneeUserId, ')
          ..write('assigneeUserName: $assigneeUserName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('dueAt: $dueAt, ')
          ..write('allDay: $allDay, ')
          ..write('timeZone: $timeZone, ')
          ..write('fixedTimezone: $fixedTimezone, ')
          ..write('repeatParentTaskId: $repeatParentTaskId, ')
          ..write('repeatRuleId: $repeatRuleId, ')
          ..write('repeatOccurrenceAt: $repeatOccurrenceAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    serverId,
    listId,
    sectionId,
    parentTaskId,
    title,
    description,
    completed,
    completedAt,
    cancelled,
    priority,
    isPinned,
    assigneeUserId,
    assigneeUserName,
    sortOrder,
    startAt,
    endAt,
    dueAt,
    allDay,
    timeZone,
    fixedTimezone,
    repeatParentTaskId,
    repeatRuleId,
    repeatOccurrenceAt,
    updatedAt,
    createdAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoTask &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.listId == this.listId &&
          other.sectionId == this.sectionId &&
          other.parentTaskId == this.parentTaskId &&
          other.title == this.title &&
          other.description == this.description &&
          other.completed == this.completed &&
          other.completedAt == this.completedAt &&
          other.cancelled == this.cancelled &&
          other.priority == this.priority &&
          other.isPinned == this.isPinned &&
          other.assigneeUserId == this.assigneeUserId &&
          other.assigneeUserName == this.assigneeUserName &&
          other.sortOrder == this.sortOrder &&
          other.startAt == this.startAt &&
          other.endAt == this.endAt &&
          other.dueAt == this.dueAt &&
          other.allDay == this.allDay &&
          other.timeZone == this.timeZone &&
          other.fixedTimezone == this.fixedTimezone &&
          other.repeatParentTaskId == this.repeatParentTaskId &&
          other.repeatRuleId == this.repeatRuleId &&
          other.repeatOccurrenceAt == this.repeatOccurrenceAt &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoTasksCompanion extends UpdateCompanion<TodoTask> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<String> listId;
  final Value<String?> sectionId;
  final Value<String?> parentTaskId;
  final Value<String> title;
  final Value<String?> description;
  final Value<bool> completed;
  final Value<DateTime?> completedAt;
  final Value<bool> cancelled;
  final Value<int> priority;
  final Value<bool> isPinned;
  final Value<int?> assigneeUserId;
  final Value<String?> assigneeUserName;
  final Value<int> sortOrder;
  final Value<DateTime?> startAt;
  final Value<DateTime?> endAt;
  final Value<DateTime?> dueAt;
  final Value<bool> allDay;
  final Value<String?> timeZone;
  final Value<bool> fixedTimezone;
  final Value<String?> repeatParentTaskId;
  final Value<String?> repeatRuleId;
  final Value<DateTime?> repeatOccurrenceAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TodoTasksCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.listId = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.parentTaskId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.completed = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.cancelled = const Value.absent(),
    this.priority = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.assigneeUserId = const Value.absent(),
    this.assigneeUserName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.allDay = const Value.absent(),
    this.timeZone = const Value.absent(),
    this.fixedTimezone = const Value.absent(),
    this.repeatParentTaskId = const Value.absent(),
    this.repeatRuleId = const Value.absent(),
    this.repeatOccurrenceAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoTasksCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String listId,
    this.sectionId = const Value.absent(),
    this.parentTaskId = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    this.completed = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.cancelled = const Value.absent(),
    this.priority = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.assigneeUserId = const Value.absent(),
    this.assigneeUserName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.allDay = const Value.absent(),
    this.timeZone = const Value.absent(),
    this.fixedTimezone = const Value.absent(),
    this.repeatParentTaskId = const Value.absent(),
    this.repeatRuleId = const Value.absent(),
    this.repeatOccurrenceAt = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       listId = Value(listId),
       title = Value(title),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoTask> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<String>? listId,
    Expression<String>? sectionId,
    Expression<String>? parentTaskId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<bool>? completed,
    Expression<DateTime>? completedAt,
    Expression<bool>? cancelled,
    Expression<int>? priority,
    Expression<bool>? isPinned,
    Expression<int>? assigneeUserId,
    Expression<String>? assigneeUserName,
    Expression<int>? sortOrder,
    Expression<DateTime>? startAt,
    Expression<DateTime>? endAt,
    Expression<DateTime>? dueAt,
    Expression<bool>? allDay,
    Expression<String>? timeZone,
    Expression<bool>? fixedTimezone,
    Expression<String>? repeatParentTaskId,
    Expression<String>? repeatRuleId,
    Expression<DateTime>? repeatOccurrenceAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (listId != null) 'list_id': listId,
      if (sectionId != null) 'section_id': sectionId,
      if (parentTaskId != null) 'parent_task_id': parentTaskId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (completed != null) 'completed': completed,
      if (completedAt != null) 'completed_at': completedAt,
      if (cancelled != null) 'cancelled': cancelled,
      if (priority != null) 'priority': priority,
      if (isPinned != null) 'is_pinned': isPinned,
      if (assigneeUserId != null) 'assignee_user_id': assigneeUserId,
      if (assigneeUserName != null) 'assignee_user_name': assigneeUserName,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (dueAt != null) 'due_at': dueAt,
      if (allDay != null) 'all_day': allDay,
      if (timeZone != null) 'time_zone': timeZone,
      if (fixedTimezone != null) 'fixed_timezone': fixedTimezone,
      if (repeatParentTaskId != null)
        'repeat_parent_task_id': repeatParentTaskId,
      if (repeatRuleId != null) 'repeat_rule_id': repeatRuleId,
      if (repeatOccurrenceAt != null)
        'repeat_occurrence_at': repeatOccurrenceAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoTasksCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<String>? listId,
    Value<String?>? sectionId,
    Value<String?>? parentTaskId,
    Value<String>? title,
    Value<String?>? description,
    Value<bool>? completed,
    Value<DateTime?>? completedAt,
    Value<bool>? cancelled,
    Value<int>? priority,
    Value<bool>? isPinned,
    Value<int?>? assigneeUserId,
    Value<String?>? assigneeUserName,
    Value<int>? sortOrder,
    Value<DateTime?>? startAt,
    Value<DateTime?>? endAt,
    Value<DateTime?>? dueAt,
    Value<bool>? allDay,
    Value<String?>? timeZone,
    Value<bool>? fixedTimezone,
    Value<String?>? repeatParentTaskId,
    Value<String?>? repeatRuleId,
    Value<DateTime?>? repeatOccurrenceAt,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TodoTasksCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      listId: listId ?? this.listId,
      sectionId: sectionId ?? this.sectionId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      cancelled: cancelled ?? this.cancelled,
      priority: priority ?? this.priority,
      isPinned: isPinned ?? this.isPinned,
      assigneeUserId: assigneeUserId ?? this.assigneeUserId,
      assigneeUserName: assigneeUserName ?? this.assigneeUserName,
      sortOrder: sortOrder ?? this.sortOrder,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      dueAt: dueAt ?? this.dueAt,
      allDay: allDay ?? this.allDay,
      timeZone: timeZone ?? this.timeZone,
      fixedTimezone: fixedTimezone ?? this.fixedTimezone,
      repeatParentTaskId: repeatParentTaskId ?? this.repeatParentTaskId,
      repeatRuleId: repeatRuleId ?? this.repeatRuleId,
      repeatOccurrenceAt: repeatOccurrenceAt ?? this.repeatOccurrenceAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<String>(sectionId.value);
    }
    if (parentTaskId.present) {
      map['parent_task_id'] = Variable<String>(parentTaskId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (cancelled.present) {
      map['cancelled'] = Variable<bool>(cancelled.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (assigneeUserId.present) {
      map['assignee_user_id'] = Variable<int>(assigneeUserId.value);
    }
    if (assigneeUserName.present) {
      map['assignee_user_name'] = Variable<String>(assigneeUserName.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<DateTime>(endAt.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (allDay.present) {
      map['all_day'] = Variable<bool>(allDay.value);
    }
    if (timeZone.present) {
      map['time_zone'] = Variable<String>(timeZone.value);
    }
    if (fixedTimezone.present) {
      map['fixed_timezone'] = Variable<bool>(fixedTimezone.value);
    }
    if (repeatParentTaskId.present) {
      map['repeat_parent_task_id'] = Variable<String>(repeatParentTaskId.value);
    }
    if (repeatRuleId.present) {
      map['repeat_rule_id'] = Variable<String>(repeatRuleId.value);
    }
    if (repeatOccurrenceAt.present) {
      map['repeat_occurrence_at'] = Variable<DateTime>(
        repeatOccurrenceAt.value,
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoTasksCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('listId: $listId, ')
          ..write('sectionId: $sectionId, ')
          ..write('parentTaskId: $parentTaskId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('completed: $completed, ')
          ..write('completedAt: $completedAt, ')
          ..write('cancelled: $cancelled, ')
          ..write('priority: $priority, ')
          ..write('isPinned: $isPinned, ')
          ..write('assigneeUserId: $assigneeUserId, ')
          ..write('assigneeUserName: $assigneeUserName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('dueAt: $dueAt, ')
          ..write('allDay: $allDay, ')
          ..write('timeZone: $timeZone, ')
          ..write('fixedTimezone: $fixedTimezone, ')
          ..write('repeatParentTaskId: $repeatParentTaskId, ')
          ..write('repeatRuleId: $repeatRuleId, ')
          ..write('repeatOccurrenceAt: $repeatOccurrenceAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoFoldersTable extends TodoFolders
    with TableInfo<$TodoFoldersTable, TodoFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
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
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    parentId,
    name,
    sortOrder,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
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
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoFolder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TodoFoldersTable createAlias(String alias) {
    return $TodoFoldersTable(attachedDatabase, alias);
  }
}

class TodoFolder extends DataClass implements Insertable<TodoFolder> {
  final String id;
  final int? serverId;

  /// 本地 UUID，指向上级文件夹；REST 时转换为服务端整数 ID。
  final String? parentId;
  final String name;
  final int sortOrder;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoFolder({
    required this.id,
    this.serverId,
    this.parentId,
    required this.name,
    required this.sortOrder,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TodoFoldersCompanion toCompanion(bool nullToAbsent) {
    return TodoFoldersCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      sortOrder: Value(sortOrder),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory TodoFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoFolder(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'parentId': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoFolder copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    Value<String?> parentId = const Value.absent(),
    String? name,
    int? sortOrder,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoFolder(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    parentId: parentId.present ? parentId.value : this.parentId,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoFolder copyWithCompanion(TodoFoldersCompanion data) {
    return TodoFolder(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoFolder(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    parentId,
    name,
    sortOrder,
    updatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoFolder &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoFoldersCompanion extends UpdateCompanion<TodoFolder> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TodoFoldersCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoFoldersCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    this.parentId = const Value.absent(),
    required String name,
    this.sortOrder = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoFolder> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoFoldersCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<String?>? parentId,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TodoFoldersCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoFoldersCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoTagsTable extends TodoTags with TableInfo<$TodoTagsTable, TodoTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    parentId,
    name,
    color,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
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
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoTag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TodoTagsTable createAlias(String alias) {
    return $TodoTagsTable(attachedDatabase, alias);
  }
}

class TodoTag extends DataClass implements Insertable<TodoTag> {
  final String id;
  final int? serverId;

  /// 本地 UUID，指向上级标签；同步时转换为服务端整数 ID。
  final String? parentId;
  final String name;
  final String? color;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoTag({
    required this.id,
    this.serverId,
    this.parentId,
    required this.name,
    this.color,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TodoTagsCompanion toCompanion(bool nullToAbsent) {
    return TodoTagsCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory TodoTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoTag(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String?>(json['color']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'parentId': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String?>(color),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoTag copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    Value<String?> parentId = const Value.absent(),
    String? name,
    Value<String?> color = const Value.absent(),
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoTag(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    parentId: parentId.present ? parentId.value : this.parentId,
    name: name ?? this.name,
    color: color.present ? color.value : this.color,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoTag copyWithCompanion(TodoTagsCompanion data) {
    return TodoTag(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoTag(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, serverId, parentId, name, color, updatedAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoTag &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.color == this.color &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoTagsCompanion extends UpdateCompanion<TodoTag> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<String?> color;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TodoTagsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoTagsCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    this.parentId = const Value.absent(),
    required String name,
    this.color = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoTag> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<String>? color,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoTagsCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<String?>? parentId,
    Value<String>? name,
    Value<String?>? color,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TodoTagsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      color: color ?? this.color,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoTagsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoTaskTagsTable extends TodoTaskTags
    with TableInfo<$TodoTaskTagsTable, TodoTaskTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoTaskTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [taskId, tagId, serverId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_task_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoTaskTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskId, tagId};
  @override
  TodoTaskTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoTaskTag(
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
    );
  }

  @override
  $TodoTaskTagsTable createAlias(String alias) {
    return $TodoTaskTagsTable(attachedDatabase, alias);
  }
}

class TodoTaskTag extends DataClass implements Insertable<TodoTaskTag> {
  final String taskId;
  final String tagId;
  final int? serverId;
  const TodoTaskTag({required this.taskId, required this.tagId, this.serverId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_id'] = Variable<String>(taskId);
    map['tag_id'] = Variable<String>(tagId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    return map;
  }

  TodoTaskTagsCompanion toCompanion(bool nullToAbsent) {
    return TodoTaskTagsCompanion(
      taskId: Value(taskId),
      tagId: Value(tagId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
    );
  }

  factory TodoTaskTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoTaskTag(
      taskId: serializer.fromJson<String>(json['taskId']),
      tagId: serializer.fromJson<String>(json['tagId']),
      serverId: serializer.fromJson<int?>(json['serverId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'taskId': serializer.toJson<String>(taskId),
      'tagId': serializer.toJson<String>(tagId),
      'serverId': serializer.toJson<int?>(serverId),
    };
  }

  TodoTaskTag copyWith({
    String? taskId,
    String? tagId,
    Value<int?> serverId = const Value.absent(),
  }) => TodoTaskTag(
    taskId: taskId ?? this.taskId,
    tagId: tagId ?? this.tagId,
    serverId: serverId.present ? serverId.value : this.serverId,
  );
  TodoTaskTag copyWithCompanion(TodoTaskTagsCompanion data) {
    return TodoTaskTag(
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoTaskTag(')
          ..write('taskId: $taskId, ')
          ..write('tagId: $tagId, ')
          ..write('serverId: $serverId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(taskId, tagId, serverId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoTaskTag &&
          other.taskId == this.taskId &&
          other.tagId == this.tagId &&
          other.serverId == this.serverId);
}

class TodoTaskTagsCompanion extends UpdateCompanion<TodoTaskTag> {
  final Value<String> taskId;
  final Value<String> tagId;
  final Value<int?> serverId;
  final Value<int> rowid;
  const TodoTaskTagsCompanion({
    this.taskId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoTaskTagsCompanion.insert({
    required String taskId,
    required String tagId,
    this.serverId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : taskId = Value(taskId),
       tagId = Value(tagId);
  static Insertable<TodoTaskTag> custom({
    Expression<String>? taskId,
    Expression<String>? tagId,
    Expression<int>? serverId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (taskId != null) 'task_id': taskId,
      if (tagId != null) 'tag_id': tagId,
      if (serverId != null) 'server_id': serverId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoTaskTagsCompanion copyWith({
    Value<String>? taskId,
    Value<String>? tagId,
    Value<int?>? serverId,
    Value<int>? rowid,
  }) {
    return TodoTaskTagsCompanion(
      taskId: taskId ?? this.taskId,
      tagId: tagId ?? this.tagId,
      serverId: serverId ?? this.serverId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoTaskTagsCompanion(')
          ..write('taskId: $taskId, ')
          ..write('tagId: $tagId, ')
          ..write('serverId: $serverId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoChecklistItemsTable extends TodoChecklistItems
    with TableInfo<$TodoChecklistItemsTable, TodoChecklistItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoChecklistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
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
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
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
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    taskId,
    title,
    completed,
    sortOrder,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_checklist_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoChecklistItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
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
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoChecklistItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoChecklistItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TodoChecklistItemsTable createAlias(String alias) {
    return $TodoChecklistItemsTable(attachedDatabase, alias);
  }
}

class TodoChecklistItem extends DataClass
    implements Insertable<TodoChecklistItem> {
  final String id;
  final int? serverId;
  final String taskId;
  final String title;
  final bool completed;
  final int sortOrder;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoChecklistItem({
    required this.id,
    this.serverId,
    required this.taskId,
    required this.title,
    required this.completed,
    required this.sortOrder,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['task_id'] = Variable<String>(taskId);
    map['title'] = Variable<String>(title);
    map['completed'] = Variable<bool>(completed);
    map['sort_order'] = Variable<int>(sortOrder);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TodoChecklistItemsCompanion toCompanion(bool nullToAbsent) {
    return TodoChecklistItemsCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      taskId: Value(taskId),
      title: Value(title),
      completed: Value(completed),
      sortOrder: Value(sortOrder),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory TodoChecklistItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoChecklistItem(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      taskId: serializer.fromJson<String>(json['taskId']),
      title: serializer.fromJson<String>(json['title']),
      completed: serializer.fromJson<bool>(json['completed']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'taskId': serializer.toJson<String>(taskId),
      'title': serializer.toJson<String>(title),
      'completed': serializer.toJson<bool>(completed),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoChecklistItem copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    String? taskId,
    String? title,
    bool? completed,
    int? sortOrder,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoChecklistItem(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    taskId: taskId ?? this.taskId,
    title: title ?? this.title,
    completed: completed ?? this.completed,
    sortOrder: sortOrder ?? this.sortOrder,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoChecklistItem copyWithCompanion(TodoChecklistItemsCompanion data) {
    return TodoChecklistItem(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      title: data.title.present ? data.title.value : this.title,
      completed: data.completed.present ? data.completed.value : this.completed,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoChecklistItem(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('taskId: $taskId, ')
          ..write('title: $title, ')
          ..write('completed: $completed, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    taskId,
    title,
    completed,
    sortOrder,
    updatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoChecklistItem &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.taskId == this.taskId &&
          other.title == this.title &&
          other.completed == this.completed &&
          other.sortOrder == this.sortOrder &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoChecklistItemsCompanion extends UpdateCompanion<TodoChecklistItem> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<String> taskId;
  final Value<String> title;
  final Value<bool> completed;
  final Value<int> sortOrder;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TodoChecklistItemsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.title = const Value.absent(),
    this.completed = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoChecklistItemsCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String taskId,
    required String title,
    this.completed = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       title = Value(title),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoChecklistItem> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<String>? taskId,
    Expression<String>? title,
    Expression<bool>? completed,
    Expression<int>? sortOrder,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (taskId != null) 'task_id': taskId,
      if (title != null) 'title': title,
      if (completed != null) 'completed': completed,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoChecklistItemsCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<String>? taskId,
    Value<String>? title,
    Value<bool>? completed,
    Value<int>? sortOrder,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TodoChecklistItemsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      sortOrder: sortOrder ?? this.sortOrder,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoChecklistItemsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('taskId: $taskId, ')
          ..write('title: $title, ')
          ..write('completed: $completed, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoAttachmentsTable extends TodoAttachments
    with TableInfo<$TodoAttachmentsTable, TodoAttachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoAttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteUrlMeta = const VerificationMeta(
    'remoteUrl',
  );
  @override
  late final GeneratedColumn<String> remoteUrl = GeneratedColumn<String>(
    'remote_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    taskId,
    name,
    localPath,
    remoteUrl,
    mimeType,
    size,
    status,
    error,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoAttachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('remote_url')) {
      context.handle(
        _remoteUrlMeta,
        remoteUrl.isAcceptableOrUnknown(data['remote_url']!, _remoteUrlMeta),
      );
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
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
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoAttachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoAttachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      remoteUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_url'],
      ),
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TodoAttachmentsTable createAlias(String alias) {
    return $TodoAttachmentsTable(attachedDatabase, alias);
  }
}

class TodoAttachment extends DataClass implements Insertable<TodoAttachment> {
  final String id;
  final int? serverId;
  final String taskId;
  final String name;
  final String? localPath;
  final String? remoteUrl;
  final String mimeType;
  final int size;
  final String status;
  final String? error;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoAttachment({
    required this.id,
    this.serverId,
    required this.taskId,
    required this.name,
    this.localPath,
    this.remoteUrl,
    required this.mimeType,
    required this.size,
    required this.status,
    this.error,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['task_id'] = Variable<String>(taskId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || remoteUrl != null) {
      map['remote_url'] = Variable<String>(remoteUrl);
    }
    map['mime_type'] = Variable<String>(mimeType);
    map['size'] = Variable<int>(size);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TodoAttachmentsCompanion toCompanion(bool nullToAbsent) {
    return TodoAttachmentsCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      taskId: Value(taskId),
      name: Value(name),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      remoteUrl: remoteUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUrl),
      mimeType: Value(mimeType),
      size: Value(size),
      status: Value(status),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory TodoAttachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoAttachment(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      taskId: serializer.fromJson<String>(json['taskId']),
      name: serializer.fromJson<String>(json['name']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      remoteUrl: serializer.fromJson<String?>(json['remoteUrl']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      size: serializer.fromJson<int>(json['size']),
      status: serializer.fromJson<String>(json['status']),
      error: serializer.fromJson<String?>(json['error']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'taskId': serializer.toJson<String>(taskId),
      'name': serializer.toJson<String>(name),
      'localPath': serializer.toJson<String?>(localPath),
      'remoteUrl': serializer.toJson<String?>(remoteUrl),
      'mimeType': serializer.toJson<String>(mimeType),
      'size': serializer.toJson<int>(size),
      'status': serializer.toJson<String>(status),
      'error': serializer.toJson<String?>(error),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoAttachment copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    String? taskId,
    String? name,
    Value<String?> localPath = const Value.absent(),
    Value<String?> remoteUrl = const Value.absent(),
    String? mimeType,
    int? size,
    String? status,
    Value<String?> error = const Value.absent(),
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoAttachment(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    taskId: taskId ?? this.taskId,
    name: name ?? this.name,
    localPath: localPath.present ? localPath.value : this.localPath,
    remoteUrl: remoteUrl.present ? remoteUrl.value : this.remoteUrl,
    mimeType: mimeType ?? this.mimeType,
    size: size ?? this.size,
    status: status ?? this.status,
    error: error.present ? error.value : this.error,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoAttachment copyWithCompanion(TodoAttachmentsCompanion data) {
    return TodoAttachment(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      name: data.name.present ? data.name.value : this.name,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      remoteUrl: data.remoteUrl.present ? data.remoteUrl.value : this.remoteUrl,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      size: data.size.present ? data.size.value : this.size,
      status: data.status.present ? data.status.value : this.status,
      error: data.error.present ? data.error.value : this.error,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoAttachment(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('taskId: $taskId, ')
          ..write('name: $name, ')
          ..write('localPath: $localPath, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('mimeType: $mimeType, ')
          ..write('size: $size, ')
          ..write('status: $status, ')
          ..write('error: $error, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    taskId,
    name,
    localPath,
    remoteUrl,
    mimeType,
    size,
    status,
    error,
    updatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoAttachment &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.taskId == this.taskId &&
          other.name == this.name &&
          other.localPath == this.localPath &&
          other.remoteUrl == this.remoteUrl &&
          other.mimeType == this.mimeType &&
          other.size == this.size &&
          other.status == this.status &&
          other.error == this.error &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoAttachmentsCompanion extends UpdateCompanion<TodoAttachment> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<String> taskId;
  final Value<String> name;
  final Value<String?> localPath;
  final Value<String?> remoteUrl;
  final Value<String> mimeType;
  final Value<int> size;
  final Value<String> status;
  final Value<String?> error;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TodoAttachmentsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.name = const Value.absent(),
    this.localPath = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.size = const Value.absent(),
    this.status = const Value.absent(),
    this.error = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoAttachmentsCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String taskId,
    required String name,
    this.localPath = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    required String mimeType,
    required int size,
    this.status = const Value.absent(),
    this.error = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       name = Value(name),
       mimeType = Value(mimeType),
       size = Value(size),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoAttachment> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<String>? taskId,
    Expression<String>? name,
    Expression<String>? localPath,
    Expression<String>? remoteUrl,
    Expression<String>? mimeType,
    Expression<int>? size,
    Expression<String>? status,
    Expression<String>? error,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (taskId != null) 'task_id': taskId,
      if (name != null) 'name': name,
      if (localPath != null) 'local_path': localPath,
      if (remoteUrl != null) 'remote_url': remoteUrl,
      if (mimeType != null) 'mime_type': mimeType,
      if (size != null) 'size': size,
      if (status != null) 'status': status,
      if (error != null) 'error': error,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoAttachmentsCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<String>? taskId,
    Value<String>? name,
    Value<String?>? localPath,
    Value<String?>? remoteUrl,
    Value<String>? mimeType,
    Value<int>? size,
    Value<String>? status,
    Value<String?>? error,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TodoAttachmentsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      taskId: taskId ?? this.taskId,
      name: name ?? this.name,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      status: status ?? this.status,
      error: error ?? this.error,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (remoteUrl.present) {
      map['remote_url'] = Variable<String>(remoteUrl.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoAttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('taskId: $taskId, ')
          ..write('name: $name, ')
          ..write('localPath: $localPath, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('mimeType: $mimeType, ')
          ..write('size: $size, ')
          ..write('status: $status, ')
          ..write('error: $error, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoActivitiesTable extends TodoActivities
    with TableInfo<$TodoActivitiesTable, TodoActivity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoActivitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taskServerIdMeta = const VerificationMeta(
    'taskServerId',
  );
  @override
  late final GeneratedColumn<int> taskServerId = GeneratedColumn<int>(
    'task_server_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorUserIdMeta = const VerificationMeta(
    'actorUserId',
  );
  @override
  late final GeneratedColumn<int> actorUserId = GeneratedColumn<int>(
    'actor_user_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actorUserNameMeta = const VerificationMeta(
    'actorUserName',
  );
  @override
  late final GeneratedColumn<String> actorUserName = GeneratedColumn<String>(
    'actor_user_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    serverId,
    taskServerId,
    actorUserId,
    actorUserName,
    action,
    detail,
    occurredAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_activities';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoActivity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('task_server_id')) {
      context.handle(
        _taskServerIdMeta,
        taskServerId.isAcceptableOrUnknown(
          data['task_server_id']!,
          _taskServerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_taskServerIdMeta);
    }
    if (data.containsKey('actor_user_id')) {
      context.handle(
        _actorUserIdMeta,
        actorUserId.isAcceptableOrUnknown(
          data['actor_user_id']!,
          _actorUserIdMeta,
        ),
      );
    }
    if (data.containsKey('actor_user_name')) {
      context.handle(
        _actorUserNameMeta,
        actorUserName.isAcceptableOrUnknown(
          data['actor_user_name']!,
          _actorUserNameMeta,
        ),
      );
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId};
  @override
  TodoActivity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoActivity(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      )!,
      taskServerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_server_id'],
      )!,
      actorUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actor_user_id'],
      ),
      actorUserName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_user_name'],
      ),
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
    );
  }

  @override
  $TodoActivitiesTable createAlias(String alias) {
    return $TodoActivitiesTable(attachedDatabase, alias);
  }
}

class TodoActivity extends DataClass implements Insertable<TodoActivity> {
  final int serverId;
  final int taskServerId;
  final int? actorUserId;
  final String? actorUserName;
  final String action;
  final String? detail;
  final DateTime occurredAt;
  const TodoActivity({
    required this.serverId,
    required this.taskServerId,
    this.actorUserId,
    this.actorUserName,
    required this.action,
    this.detail,
    required this.occurredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<int>(serverId);
    map['task_server_id'] = Variable<int>(taskServerId);
    if (!nullToAbsent || actorUserId != null) {
      map['actor_user_id'] = Variable<int>(actorUserId);
    }
    if (!nullToAbsent || actorUserName != null) {
      map['actor_user_name'] = Variable<String>(actorUserName);
    }
    map['action'] = Variable<String>(action);
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    return map;
  }

  TodoActivitiesCompanion toCompanion(bool nullToAbsent) {
    return TodoActivitiesCompanion(
      serverId: Value(serverId),
      taskServerId: Value(taskServerId),
      actorUserId: actorUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(actorUserId),
      actorUserName: actorUserName == null && nullToAbsent
          ? const Value.absent()
          : Value(actorUserName),
      action: Value(action),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
      occurredAt: Value(occurredAt),
    );
  }

  factory TodoActivity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoActivity(
      serverId: serializer.fromJson<int>(json['serverId']),
      taskServerId: serializer.fromJson<int>(json['taskServerId']),
      actorUserId: serializer.fromJson<int?>(json['actorUserId']),
      actorUserName: serializer.fromJson<String?>(json['actorUserName']),
      action: serializer.fromJson<String>(json['action']),
      detail: serializer.fromJson<String?>(json['detail']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<int>(serverId),
      'taskServerId': serializer.toJson<int>(taskServerId),
      'actorUserId': serializer.toJson<int?>(actorUserId),
      'actorUserName': serializer.toJson<String?>(actorUserName),
      'action': serializer.toJson<String>(action),
      'detail': serializer.toJson<String?>(detail),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
    };
  }

  TodoActivity copyWith({
    int? serverId,
    int? taskServerId,
    Value<int?> actorUserId = const Value.absent(),
    Value<String?> actorUserName = const Value.absent(),
    String? action,
    Value<String?> detail = const Value.absent(),
    DateTime? occurredAt,
  }) => TodoActivity(
    serverId: serverId ?? this.serverId,
    taskServerId: taskServerId ?? this.taskServerId,
    actorUserId: actorUserId.present ? actorUserId.value : this.actorUserId,
    actorUserName: actorUserName.present
        ? actorUserName.value
        : this.actorUserName,
    action: action ?? this.action,
    detail: detail.present ? detail.value : this.detail,
    occurredAt: occurredAt ?? this.occurredAt,
  );
  TodoActivity copyWithCompanion(TodoActivitiesCompanion data) {
    return TodoActivity(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      taskServerId: data.taskServerId.present
          ? data.taskServerId.value
          : this.taskServerId,
      actorUserId: data.actorUserId.present
          ? data.actorUserId.value
          : this.actorUserId,
      actorUserName: data.actorUserName.present
          ? data.actorUserName.value
          : this.actorUserName,
      action: data.action.present ? data.action.value : this.action,
      detail: data.detail.present ? data.detail.value : this.detail,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoActivity(')
          ..write('serverId: $serverId, ')
          ..write('taskServerId: $taskServerId, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('actorUserName: $actorUserName, ')
          ..write('action: $action, ')
          ..write('detail: $detail, ')
          ..write('occurredAt: $occurredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    serverId,
    taskServerId,
    actorUserId,
    actorUserName,
    action,
    detail,
    occurredAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoActivity &&
          other.serverId == this.serverId &&
          other.taskServerId == this.taskServerId &&
          other.actorUserId == this.actorUserId &&
          other.actorUserName == this.actorUserName &&
          other.action == this.action &&
          other.detail == this.detail &&
          other.occurredAt == this.occurredAt);
}

class TodoActivitiesCompanion extends UpdateCompanion<TodoActivity> {
  final Value<int> serverId;
  final Value<int> taskServerId;
  final Value<int?> actorUserId;
  final Value<String?> actorUserName;
  final Value<String> action;
  final Value<String?> detail;
  final Value<DateTime> occurredAt;
  const TodoActivitiesCompanion({
    this.serverId = const Value.absent(),
    this.taskServerId = const Value.absent(),
    this.actorUserId = const Value.absent(),
    this.actorUserName = const Value.absent(),
    this.action = const Value.absent(),
    this.detail = const Value.absent(),
    this.occurredAt = const Value.absent(),
  });
  TodoActivitiesCompanion.insert({
    this.serverId = const Value.absent(),
    required int taskServerId,
    this.actorUserId = const Value.absent(),
    this.actorUserName = const Value.absent(),
    required String action,
    this.detail = const Value.absent(),
    required DateTime occurredAt,
  }) : taskServerId = Value(taskServerId),
       action = Value(action),
       occurredAt = Value(occurredAt);
  static Insertable<TodoActivity> custom({
    Expression<int>? serverId,
    Expression<int>? taskServerId,
    Expression<int>? actorUserId,
    Expression<String>? actorUserName,
    Expression<String>? action,
    Expression<String>? detail,
    Expression<DateTime>? occurredAt,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (taskServerId != null) 'task_server_id': taskServerId,
      if (actorUserId != null) 'actor_user_id': actorUserId,
      if (actorUserName != null) 'actor_user_name': actorUserName,
      if (action != null) 'action': action,
      if (detail != null) 'detail': detail,
      if (occurredAt != null) 'occurred_at': occurredAt,
    });
  }

  TodoActivitiesCompanion copyWith({
    Value<int>? serverId,
    Value<int>? taskServerId,
    Value<int?>? actorUserId,
    Value<String?>? actorUserName,
    Value<String>? action,
    Value<String?>? detail,
    Value<DateTime>? occurredAt,
  }) {
    return TodoActivitiesCompanion(
      serverId: serverId ?? this.serverId,
      taskServerId: taskServerId ?? this.taskServerId,
      actorUserId: actorUserId ?? this.actorUserId,
      actorUserName: actorUserName ?? this.actorUserName,
      action: action ?? this.action,
      detail: detail ?? this.detail,
      occurredAt: occurredAt ?? this.occurredAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (taskServerId.present) {
      map['task_server_id'] = Variable<int>(taskServerId.value);
    }
    if (actorUserId.present) {
      map['actor_user_id'] = Variable<int>(actorUserId.value);
    }
    if (actorUserName.present) {
      map['actor_user_name'] = Variable<String>(actorUserName.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoActivitiesCompanion(')
          ..write('serverId: $serverId, ')
          ..write('taskServerId: $taskServerId, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('actorUserName: $actorUserName, ')
          ..write('action: $action, ')
          ..write('detail: $detail, ')
          ..write('occurredAt: $occurredAt')
          ..write(')'))
        .toString();
  }
}

class $TodoTemplatesTable extends TodoTemplates
    with TableInfo<$TodoTemplatesTable, TodoTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentJsonMeta = const VerificationMeta(
    'contentJson',
  );
  @override
  late final GeneratedColumn<String> contentJson = GeneratedColumn<String>(
    'content_json',
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
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    name,
    contentJson,
    status,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('content_json')) {
      context.handle(
        _contentJsonMeta,
        contentJson.isAcceptableOrUnknown(
          data['content_json']!,
          _contentJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      contentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TodoTemplatesTable createAlias(String alias) {
    return $TodoTemplatesTable(attachedDatabase, alias);
  }
}

class TodoTemplate extends DataClass implements Insertable<TodoTemplate> {
  final String id;
  final int? serverId;
  final String name;
  final String contentJson;
  final String status;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoTemplate({
    required this.id,
    this.serverId,
    required this.name,
    required this.contentJson,
    required this.status,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['name'] = Variable<String>(name);
    map['content_json'] = Variable<String>(contentJson);
    map['status'] = Variable<String>(status);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TodoTemplatesCompanion toCompanion(bool nullToAbsent) {
    return TodoTemplatesCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      name: Value(name),
      contentJson: Value(contentJson),
      status: Value(status),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory TodoTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoTemplate(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      name: serializer.fromJson<String>(json['name']),
      contentJson: serializer.fromJson<String>(json['contentJson']),
      status: serializer.fromJson<String>(json['status']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'name': serializer.toJson<String>(name),
      'contentJson': serializer.toJson<String>(contentJson),
      'status': serializer.toJson<String>(status),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoTemplate copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    String? name,
    String? contentJson,
    String? status,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoTemplate(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    name: name ?? this.name,
    contentJson: contentJson ?? this.contentJson,
    status: status ?? this.status,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoTemplate copyWithCompanion(TodoTemplatesCompanion data) {
    return TodoTemplate(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      name: data.name.present ? data.name.value : this.name,
      contentJson: data.contentJson.present
          ? data.contentJson.value
          : this.contentJson,
      status: data.status.present ? data.status.value : this.status,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoTemplate(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('contentJson: $contentJson, ')
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    name,
    contentJson,
    status,
    updatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoTemplate &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.name == this.name &&
          other.contentJson == this.contentJson &&
          other.status == this.status &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoTemplatesCompanion extends UpdateCompanion<TodoTemplate> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<String> name;
  final Value<String> contentJson;
  final Value<String> status;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TodoTemplatesCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.name = const Value.absent(),
    this.contentJson = const Value.absent(),
    this.status = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoTemplatesCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String name,
    required String contentJson,
    this.status = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       contentJson = Value(contentJson),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoTemplate> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<String>? name,
    Expression<String>? contentJson,
    Expression<String>? status,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (name != null) 'name': name,
      if (contentJson != null) 'content_json': contentJson,
      if (status != null) 'status': status,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoTemplatesCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<String>? name,
    Value<String>? contentJson,
    Value<String>? status,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TodoTemplatesCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      contentJson: contentJson ?? this.contentJson,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (contentJson.present) {
      map['content_json'] = Variable<String>(contentJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('contentJson: $contentJson, ')
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoRemindersTable extends TodoReminders
    with TableInfo<$TodoRemindersTable, TodoReminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoRemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remindAtMeta = const VerificationMeta(
    'remindAt',
  );
  @override
  late final GeneratedColumn<DateTime> remindAt = GeneratedColumn<DateTime>(
    'remind_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _anchorTypeMeta = const VerificationMeta(
    'anchorType',
  );
  @override
  late final GeneratedColumn<String> anchorType = GeneratedColumn<String>(
    'anchor_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ABSOLUTE'),
  );
  static const VerificationMeta _offsetMinutesMeta = const VerificationMeta(
    'offsetMinutes',
  );
  @override
  late final GeneratedColumn<int> offsetMinutes = GeneratedColumn<int>(
    'offset_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PENDING'),
  );
  static const VerificationMeta _firedAtMeta = const VerificationMeta(
    'firedAt',
  );
  @override
  late final GeneratedColumn<DateTime> firedAt = GeneratedColumn<DateTime>(
    'fired_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _persistentMeta = const VerificationMeta(
    'persistent',
  );
  @override
  late final GeneratedColumn<bool> persistent = GeneratedColumn<bool>(
    'persistent',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("persistent" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _intervalMinutesMeta = const VerificationMeta(
    'intervalMinutes',
  );
  @override
  late final GeneratedColumn<int> intervalMinutes = GeneratedColumn<int>(
    'interval_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeZoneMeta = const VerificationMeta(
    'timeZone',
  );
  @override
  late final GeneratedColumn<String> timeZone = GeneratedColumn<String>(
    'time_zone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fixedTimezoneMeta = const VerificationMeta(
    'fixedTimezone',
  );
  @override
  late final GeneratedColumn<bool> fixedTimezone = GeneratedColumn<bool>(
    'fixed_timezone',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("fixed_timezone" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _clientMutationIdMeta = const VerificationMeta(
    'clientMutationId',
  );
  @override
  late final GeneratedColumn<String> clientMutationId = GeneratedColumn<String>(
    'client_mutation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    taskId,
    remindAt,
    anchorType,
    offsetMinutes,
    status,
    firedAt,
    persistent,
    intervalMinutes,
    timeZone,
    fixedTimezone,
    clientMutationId,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoReminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('remind_at')) {
      context.handle(
        _remindAtMeta,
        remindAt.isAcceptableOrUnknown(data['remind_at']!, _remindAtMeta),
      );
    } else if (isInserting) {
      context.missing(_remindAtMeta);
    }
    if (data.containsKey('anchor_type')) {
      context.handle(
        _anchorTypeMeta,
        anchorType.isAcceptableOrUnknown(data['anchor_type']!, _anchorTypeMeta),
      );
    }
    if (data.containsKey('offset_minutes')) {
      context.handle(
        _offsetMinutesMeta,
        offsetMinutes.isAcceptableOrUnknown(
          data['offset_minutes']!,
          _offsetMinutesMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('fired_at')) {
      context.handle(
        _firedAtMeta,
        firedAt.isAcceptableOrUnknown(data['fired_at']!, _firedAtMeta),
      );
    }
    if (data.containsKey('persistent')) {
      context.handle(
        _persistentMeta,
        persistent.isAcceptableOrUnknown(data['persistent']!, _persistentMeta),
      );
    }
    if (data.containsKey('interval_minutes')) {
      context.handle(
        _intervalMinutesMeta,
        intervalMinutes.isAcceptableOrUnknown(
          data['interval_minutes']!,
          _intervalMinutesMeta,
        ),
      );
    }
    if (data.containsKey('time_zone')) {
      context.handle(
        _timeZoneMeta,
        timeZone.isAcceptableOrUnknown(data['time_zone']!, _timeZoneMeta),
      );
    }
    if (data.containsKey('fixed_timezone')) {
      context.handle(
        _fixedTimezoneMeta,
        fixedTimezone.isAcceptableOrUnknown(
          data['fixed_timezone']!,
          _fixedTimezoneMeta,
        ),
      );
    }
    if (data.containsKey('client_mutation_id')) {
      context.handle(
        _clientMutationIdMeta,
        clientMutationId.isAcceptableOrUnknown(
          data['client_mutation_id']!,
          _clientMutationIdMeta,
        ),
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
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoReminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoReminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      remindAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remind_at'],
      )!,
      anchorType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anchor_type'],
      )!,
      offsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offset_minutes'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      firedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fired_at'],
      ),
      persistent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}persistent'],
      )!,
      intervalMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_minutes'],
      ),
      timeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone'],
      ),
      fixedTimezone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}fixed_timezone'],
      )!,
      clientMutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_mutation_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TodoRemindersTable createAlias(String alias) {
    return $TodoRemindersTable(attachedDatabase, alias);
  }
}

class TodoReminder extends DataClass implements Insertable<TodoReminder> {
  final String id;
  final int? serverId;
  final String taskId;
  final DateTime remindAt;
  final String anchorType;
  final int? offsetMinutes;
  final String status;
  final DateTime? firedAt;
  final bool persistent;
  final int? intervalMinutes;
  final String? timeZone;
  final bool fixedTimezone;
  final String? clientMutationId;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoReminder({
    required this.id,
    this.serverId,
    required this.taskId,
    required this.remindAt,
    required this.anchorType,
    this.offsetMinutes,
    required this.status,
    this.firedAt,
    required this.persistent,
    this.intervalMinutes,
    this.timeZone,
    required this.fixedTimezone,
    this.clientMutationId,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['task_id'] = Variable<String>(taskId);
    map['remind_at'] = Variable<DateTime>(remindAt);
    map['anchor_type'] = Variable<String>(anchorType);
    if (!nullToAbsent || offsetMinutes != null) {
      map['offset_minutes'] = Variable<int>(offsetMinutes);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || firedAt != null) {
      map['fired_at'] = Variable<DateTime>(firedAt);
    }
    map['persistent'] = Variable<bool>(persistent);
    if (!nullToAbsent || intervalMinutes != null) {
      map['interval_minutes'] = Variable<int>(intervalMinutes);
    }
    if (!nullToAbsent || timeZone != null) {
      map['time_zone'] = Variable<String>(timeZone);
    }
    map['fixed_timezone'] = Variable<bool>(fixedTimezone);
    if (!nullToAbsent || clientMutationId != null) {
      map['client_mutation_id'] = Variable<String>(clientMutationId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TodoRemindersCompanion toCompanion(bool nullToAbsent) {
    return TodoRemindersCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      taskId: Value(taskId),
      remindAt: Value(remindAt),
      anchorType: Value(anchorType),
      offsetMinutes: offsetMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(offsetMinutes),
      status: Value(status),
      firedAt: firedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(firedAt),
      persistent: Value(persistent),
      intervalMinutes: intervalMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(intervalMinutes),
      timeZone: timeZone == null && nullToAbsent
          ? const Value.absent()
          : Value(timeZone),
      fixedTimezone: Value(fixedTimezone),
      clientMutationId: clientMutationId == null && nullToAbsent
          ? const Value.absent()
          : Value(clientMutationId),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory TodoReminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoReminder(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      taskId: serializer.fromJson<String>(json['taskId']),
      remindAt: serializer.fromJson<DateTime>(json['remindAt']),
      anchorType: serializer.fromJson<String>(json['anchorType']),
      offsetMinutes: serializer.fromJson<int?>(json['offsetMinutes']),
      status: serializer.fromJson<String>(json['status']),
      firedAt: serializer.fromJson<DateTime?>(json['firedAt']),
      persistent: serializer.fromJson<bool>(json['persistent']),
      intervalMinutes: serializer.fromJson<int?>(json['intervalMinutes']),
      timeZone: serializer.fromJson<String?>(json['timeZone']),
      fixedTimezone: serializer.fromJson<bool>(json['fixedTimezone']),
      clientMutationId: serializer.fromJson<String?>(json['clientMutationId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'taskId': serializer.toJson<String>(taskId),
      'remindAt': serializer.toJson<DateTime>(remindAt),
      'anchorType': serializer.toJson<String>(anchorType),
      'offsetMinutes': serializer.toJson<int?>(offsetMinutes),
      'status': serializer.toJson<String>(status),
      'firedAt': serializer.toJson<DateTime?>(firedAt),
      'persistent': serializer.toJson<bool>(persistent),
      'intervalMinutes': serializer.toJson<int?>(intervalMinutes),
      'timeZone': serializer.toJson<String?>(timeZone),
      'fixedTimezone': serializer.toJson<bool>(fixedTimezone),
      'clientMutationId': serializer.toJson<String?>(clientMutationId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoReminder copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    String? taskId,
    DateTime? remindAt,
    String? anchorType,
    Value<int?> offsetMinutes = const Value.absent(),
    String? status,
    Value<DateTime?> firedAt = const Value.absent(),
    bool? persistent,
    Value<int?> intervalMinutes = const Value.absent(),
    Value<String?> timeZone = const Value.absent(),
    bool? fixedTimezone,
    Value<String?> clientMutationId = const Value.absent(),
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoReminder(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    taskId: taskId ?? this.taskId,
    remindAt: remindAt ?? this.remindAt,
    anchorType: anchorType ?? this.anchorType,
    offsetMinutes: offsetMinutes.present
        ? offsetMinutes.value
        : this.offsetMinutes,
    status: status ?? this.status,
    firedAt: firedAt.present ? firedAt.value : this.firedAt,
    persistent: persistent ?? this.persistent,
    intervalMinutes: intervalMinutes.present
        ? intervalMinutes.value
        : this.intervalMinutes,
    timeZone: timeZone.present ? timeZone.value : this.timeZone,
    fixedTimezone: fixedTimezone ?? this.fixedTimezone,
    clientMutationId: clientMutationId.present
        ? clientMutationId.value
        : this.clientMutationId,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoReminder copyWithCompanion(TodoRemindersCompanion data) {
    return TodoReminder(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      remindAt: data.remindAt.present ? data.remindAt.value : this.remindAt,
      anchorType: data.anchorType.present
          ? data.anchorType.value
          : this.anchorType,
      offsetMinutes: data.offsetMinutes.present
          ? data.offsetMinutes.value
          : this.offsetMinutes,
      status: data.status.present ? data.status.value : this.status,
      firedAt: data.firedAt.present ? data.firedAt.value : this.firedAt,
      persistent: data.persistent.present
          ? data.persistent.value
          : this.persistent,
      intervalMinutes: data.intervalMinutes.present
          ? data.intervalMinutes.value
          : this.intervalMinutes,
      timeZone: data.timeZone.present ? data.timeZone.value : this.timeZone,
      fixedTimezone: data.fixedTimezone.present
          ? data.fixedTimezone.value
          : this.fixedTimezone,
      clientMutationId: data.clientMutationId.present
          ? data.clientMutationId.value
          : this.clientMutationId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoReminder(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('taskId: $taskId, ')
          ..write('remindAt: $remindAt, ')
          ..write('anchorType: $anchorType, ')
          ..write('offsetMinutes: $offsetMinutes, ')
          ..write('status: $status, ')
          ..write('firedAt: $firedAt, ')
          ..write('persistent: $persistent, ')
          ..write('intervalMinutes: $intervalMinutes, ')
          ..write('timeZone: $timeZone, ')
          ..write('fixedTimezone: $fixedTimezone, ')
          ..write('clientMutationId: $clientMutationId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    taskId,
    remindAt,
    anchorType,
    offsetMinutes,
    status,
    firedAt,
    persistent,
    intervalMinutes,
    timeZone,
    fixedTimezone,
    clientMutationId,
    updatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoReminder &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.taskId == this.taskId &&
          other.remindAt == this.remindAt &&
          other.anchorType == this.anchorType &&
          other.offsetMinutes == this.offsetMinutes &&
          other.status == this.status &&
          other.firedAt == this.firedAt &&
          other.persistent == this.persistent &&
          other.intervalMinutes == this.intervalMinutes &&
          other.timeZone == this.timeZone &&
          other.fixedTimezone == this.fixedTimezone &&
          other.clientMutationId == this.clientMutationId &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoRemindersCompanion extends UpdateCompanion<TodoReminder> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<String> taskId;
  final Value<DateTime> remindAt;
  final Value<String> anchorType;
  final Value<int?> offsetMinutes;
  final Value<String> status;
  final Value<DateTime?> firedAt;
  final Value<bool> persistent;
  final Value<int?> intervalMinutes;
  final Value<String?> timeZone;
  final Value<bool> fixedTimezone;
  final Value<String?> clientMutationId;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TodoRemindersCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.remindAt = const Value.absent(),
    this.anchorType = const Value.absent(),
    this.offsetMinutes = const Value.absent(),
    this.status = const Value.absent(),
    this.firedAt = const Value.absent(),
    this.persistent = const Value.absent(),
    this.intervalMinutes = const Value.absent(),
    this.timeZone = const Value.absent(),
    this.fixedTimezone = const Value.absent(),
    this.clientMutationId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoRemindersCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String taskId,
    required DateTime remindAt,
    this.anchorType = const Value.absent(),
    this.offsetMinutes = const Value.absent(),
    this.status = const Value.absent(),
    this.firedAt = const Value.absent(),
    this.persistent = const Value.absent(),
    this.intervalMinutes = const Value.absent(),
    this.timeZone = const Value.absent(),
    this.fixedTimezone = const Value.absent(),
    this.clientMutationId = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       remindAt = Value(remindAt),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoReminder> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<String>? taskId,
    Expression<DateTime>? remindAt,
    Expression<String>? anchorType,
    Expression<int>? offsetMinutes,
    Expression<String>? status,
    Expression<DateTime>? firedAt,
    Expression<bool>? persistent,
    Expression<int>? intervalMinutes,
    Expression<String>? timeZone,
    Expression<bool>? fixedTimezone,
    Expression<String>? clientMutationId,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (taskId != null) 'task_id': taskId,
      if (remindAt != null) 'remind_at': remindAt,
      if (anchorType != null) 'anchor_type': anchorType,
      if (offsetMinutes != null) 'offset_minutes': offsetMinutes,
      if (status != null) 'status': status,
      if (firedAt != null) 'fired_at': firedAt,
      if (persistent != null) 'persistent': persistent,
      if (intervalMinutes != null) 'interval_minutes': intervalMinutes,
      if (timeZone != null) 'time_zone': timeZone,
      if (fixedTimezone != null) 'fixed_timezone': fixedTimezone,
      if (clientMutationId != null) 'client_mutation_id': clientMutationId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoRemindersCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<String>? taskId,
    Value<DateTime>? remindAt,
    Value<String>? anchorType,
    Value<int?>? offsetMinutes,
    Value<String>? status,
    Value<DateTime?>? firedAt,
    Value<bool>? persistent,
    Value<int?>? intervalMinutes,
    Value<String?>? timeZone,
    Value<bool>? fixedTimezone,
    Value<String?>? clientMutationId,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TodoRemindersCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      taskId: taskId ?? this.taskId,
      remindAt: remindAt ?? this.remindAt,
      anchorType: anchorType ?? this.anchorType,
      offsetMinutes: offsetMinutes ?? this.offsetMinutes,
      status: status ?? this.status,
      firedAt: firedAt ?? this.firedAt,
      persistent: persistent ?? this.persistent,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      timeZone: timeZone ?? this.timeZone,
      fixedTimezone: fixedTimezone ?? this.fixedTimezone,
      clientMutationId: clientMutationId ?? this.clientMutationId,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (remindAt.present) {
      map['remind_at'] = Variable<DateTime>(remindAt.value);
    }
    if (anchorType.present) {
      map['anchor_type'] = Variable<String>(anchorType.value);
    }
    if (offsetMinutes.present) {
      map['offset_minutes'] = Variable<int>(offsetMinutes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (firedAt.present) {
      map['fired_at'] = Variable<DateTime>(firedAt.value);
    }
    if (persistent.present) {
      map['persistent'] = Variable<bool>(persistent.value);
    }
    if (intervalMinutes.present) {
      map['interval_minutes'] = Variable<int>(intervalMinutes.value);
    }
    if (timeZone.present) {
      map['time_zone'] = Variable<String>(timeZone.value);
    }
    if (fixedTimezone.present) {
      map['fixed_timezone'] = Variable<bool>(fixedTimezone.value);
    }
    if (clientMutationId.present) {
      map['client_mutation_id'] = Variable<String>(clientMutationId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoRemindersCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('taskId: $taskId, ')
          ..write('remindAt: $remindAt, ')
          ..write('anchorType: $anchorType, ')
          ..write('offsetMinutes: $offsetMinutes, ')
          ..write('status: $status, ')
          ..write('firedAt: $firedAt, ')
          ..write('persistent: $persistent, ')
          ..write('intervalMinutes: $intervalMinutes, ')
          ..write('timeZone: $timeZone, ')
          ..write('fixedTimezone: $fixedTimezone, ')
          ..write('clientMutationId: $clientMutationId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoRepeatRulesTable extends TodoRepeatRules
    with TableInfo<$TodoRepeatRulesTable, TodoRepeatRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoRepeatRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _freqMeta = const VerificationMeta('freq');
  @override
  late final GeneratedColumn<String> freq = GeneratedColumn<String>(
    'freq',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intervalMeta = const VerificationMeta(
    'interval',
  );
  @override
  late final GeneratedColumn<int> interval = GeneratedColumn<int>(
    'interval',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _byDayMeta = const VerificationMeta('byDay');
  @override
  late final GeneratedColumn<String> byDay = GeneratedColumn<String>(
    'by_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _monthDayMeta = const VerificationMeta(
    'monthDay',
  );
  @override
  late final GeneratedColumn<int> monthDay = GeneratedColumn<int>(
    'month_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startAtMeta = const VerificationMeta(
    'startAt',
  );
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
    'start_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _untilMeta = const VerificationMeta('until');
  @override
  late final GeneratedColumn<DateTime> until = GeneratedColumn<DateTime>(
    'until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countLimitMeta = const VerificationMeta(
    'countLimit',
  );
  @override
  late final GeneratedColumn<int> countLimit = GeneratedColumn<int>(
    'count_limit',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _repeatModeMeta = const VerificationMeta(
    'repeatMode',
  );
  @override
  late final GeneratedColumn<String> repeatMode = GeneratedColumn<String>(
    'repeat_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ON_DUE'),
  );
  static const VerificationMeta _timeZoneMeta = const VerificationMeta(
    'timeZone',
  );
  @override
  late final GeneratedColumn<String> timeZone = GeneratedColumn<String>(
    'time_zone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _selectedDatesJsonMeta = const VerificationMeta(
    'selectedDatesJson',
  );
  @override
  late final GeneratedColumn<String> selectedDatesJson =
      GeneratedColumn<String>(
        'selected_dates_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    taskId,
    freq,
    interval,
    byDay,
    monthDay,
    startAt,
    until,
    countLimit,
    enabled,
    repeatMode,
    timeZone,
    selectedDatesJson,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_repeat_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoRepeatRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('freq')) {
      context.handle(
        _freqMeta,
        freq.isAcceptableOrUnknown(data['freq']!, _freqMeta),
      );
    } else if (isInserting) {
      context.missing(_freqMeta);
    }
    if (data.containsKey('interval')) {
      context.handle(
        _intervalMeta,
        interval.isAcceptableOrUnknown(data['interval']!, _intervalMeta),
      );
    }
    if (data.containsKey('by_day')) {
      context.handle(
        _byDayMeta,
        byDay.isAcceptableOrUnknown(data['by_day']!, _byDayMeta),
      );
    }
    if (data.containsKey('month_day')) {
      context.handle(
        _monthDayMeta,
        monthDay.isAcceptableOrUnknown(data['month_day']!, _monthDayMeta),
      );
    }
    if (data.containsKey('start_at')) {
      context.handle(
        _startAtMeta,
        startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta),
      );
    }
    if (data.containsKey('until')) {
      context.handle(
        _untilMeta,
        until.isAcceptableOrUnknown(data['until']!, _untilMeta),
      );
    }
    if (data.containsKey('count_limit')) {
      context.handle(
        _countLimitMeta,
        countLimit.isAcceptableOrUnknown(data['count_limit']!, _countLimitMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('repeat_mode')) {
      context.handle(
        _repeatModeMeta,
        repeatMode.isAcceptableOrUnknown(data['repeat_mode']!, _repeatModeMeta),
      );
    }
    if (data.containsKey('time_zone')) {
      context.handle(
        _timeZoneMeta,
        timeZone.isAcceptableOrUnknown(data['time_zone']!, _timeZoneMeta),
      );
    }
    if (data.containsKey('selected_dates_json')) {
      context.handle(
        _selectedDatesJsonMeta,
        selectedDatesJson.isAcceptableOrUnknown(
          data['selected_dates_json']!,
          _selectedDatesJsonMeta,
        ),
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
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoRepeatRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoRepeatRule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      freq: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}freq'],
      )!,
      interval: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval'],
      )!,
      byDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}by_day'],
      ),
      monthDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month_day'],
      ),
      startAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_at'],
      ),
      until: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}until'],
      ),
      countLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count_limit'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      repeatMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_mode'],
      )!,
      timeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone'],
      ),
      selectedDatesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_dates_json'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TodoRepeatRulesTable createAlias(String alias) {
    return $TodoRepeatRulesTable(attachedDatabase, alias);
  }
}

class TodoRepeatRule extends DataClass implements Insertable<TodoRepeatRule> {
  final String id;
  final int? serverId;
  final String taskId;
  final String freq;
  final int interval;
  final String? byDay;
  final int? monthDay;
  final DateTime? startAt;
  final DateTime? until;
  final int? countLimit;
  final bool enabled;
  final String repeatMode;
  final String? timeZone;
  final String? selectedDatesJson;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoRepeatRule({
    required this.id,
    this.serverId,
    required this.taskId,
    required this.freq,
    required this.interval,
    this.byDay,
    this.monthDay,
    this.startAt,
    this.until,
    this.countLimit,
    required this.enabled,
    required this.repeatMode,
    this.timeZone,
    this.selectedDatesJson,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['task_id'] = Variable<String>(taskId);
    map['freq'] = Variable<String>(freq);
    map['interval'] = Variable<int>(interval);
    if (!nullToAbsent || byDay != null) {
      map['by_day'] = Variable<String>(byDay);
    }
    if (!nullToAbsent || monthDay != null) {
      map['month_day'] = Variable<int>(monthDay);
    }
    if (!nullToAbsent || startAt != null) {
      map['start_at'] = Variable<DateTime>(startAt);
    }
    if (!nullToAbsent || until != null) {
      map['until'] = Variable<DateTime>(until);
    }
    if (!nullToAbsent || countLimit != null) {
      map['count_limit'] = Variable<int>(countLimit);
    }
    map['enabled'] = Variable<bool>(enabled);
    map['repeat_mode'] = Variable<String>(repeatMode);
    if (!nullToAbsent || timeZone != null) {
      map['time_zone'] = Variable<String>(timeZone);
    }
    if (!nullToAbsent || selectedDatesJson != null) {
      map['selected_dates_json'] = Variable<String>(selectedDatesJson);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TodoRepeatRulesCompanion toCompanion(bool nullToAbsent) {
    return TodoRepeatRulesCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      taskId: Value(taskId),
      freq: Value(freq),
      interval: Value(interval),
      byDay: byDay == null && nullToAbsent
          ? const Value.absent()
          : Value(byDay),
      monthDay: monthDay == null && nullToAbsent
          ? const Value.absent()
          : Value(monthDay),
      startAt: startAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startAt),
      until: until == null && nullToAbsent
          ? const Value.absent()
          : Value(until),
      countLimit: countLimit == null && nullToAbsent
          ? const Value.absent()
          : Value(countLimit),
      enabled: Value(enabled),
      repeatMode: Value(repeatMode),
      timeZone: timeZone == null && nullToAbsent
          ? const Value.absent()
          : Value(timeZone),
      selectedDatesJson: selectedDatesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(selectedDatesJson),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory TodoRepeatRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoRepeatRule(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      taskId: serializer.fromJson<String>(json['taskId']),
      freq: serializer.fromJson<String>(json['freq']),
      interval: serializer.fromJson<int>(json['interval']),
      byDay: serializer.fromJson<String?>(json['byDay']),
      monthDay: serializer.fromJson<int?>(json['monthDay']),
      startAt: serializer.fromJson<DateTime?>(json['startAt']),
      until: serializer.fromJson<DateTime?>(json['until']),
      countLimit: serializer.fromJson<int?>(json['countLimit']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      repeatMode: serializer.fromJson<String>(json['repeatMode']),
      timeZone: serializer.fromJson<String?>(json['timeZone']),
      selectedDatesJson: serializer.fromJson<String?>(
        json['selectedDatesJson'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'taskId': serializer.toJson<String>(taskId),
      'freq': serializer.toJson<String>(freq),
      'interval': serializer.toJson<int>(interval),
      'byDay': serializer.toJson<String?>(byDay),
      'monthDay': serializer.toJson<int?>(monthDay),
      'startAt': serializer.toJson<DateTime?>(startAt),
      'until': serializer.toJson<DateTime?>(until),
      'countLimit': serializer.toJson<int?>(countLimit),
      'enabled': serializer.toJson<bool>(enabled),
      'repeatMode': serializer.toJson<String>(repeatMode),
      'timeZone': serializer.toJson<String?>(timeZone),
      'selectedDatesJson': serializer.toJson<String?>(selectedDatesJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoRepeatRule copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    String? taskId,
    String? freq,
    int? interval,
    Value<String?> byDay = const Value.absent(),
    Value<int?> monthDay = const Value.absent(),
    Value<DateTime?> startAt = const Value.absent(),
    Value<DateTime?> until = const Value.absent(),
    Value<int?> countLimit = const Value.absent(),
    bool? enabled,
    String? repeatMode,
    Value<String?> timeZone = const Value.absent(),
    Value<String?> selectedDatesJson = const Value.absent(),
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoRepeatRule(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    taskId: taskId ?? this.taskId,
    freq: freq ?? this.freq,
    interval: interval ?? this.interval,
    byDay: byDay.present ? byDay.value : this.byDay,
    monthDay: monthDay.present ? monthDay.value : this.monthDay,
    startAt: startAt.present ? startAt.value : this.startAt,
    until: until.present ? until.value : this.until,
    countLimit: countLimit.present ? countLimit.value : this.countLimit,
    enabled: enabled ?? this.enabled,
    repeatMode: repeatMode ?? this.repeatMode,
    timeZone: timeZone.present ? timeZone.value : this.timeZone,
    selectedDatesJson: selectedDatesJson.present
        ? selectedDatesJson.value
        : this.selectedDatesJson,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoRepeatRule copyWithCompanion(TodoRepeatRulesCompanion data) {
    return TodoRepeatRule(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      freq: data.freq.present ? data.freq.value : this.freq,
      interval: data.interval.present ? data.interval.value : this.interval,
      byDay: data.byDay.present ? data.byDay.value : this.byDay,
      monthDay: data.monthDay.present ? data.monthDay.value : this.monthDay,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      until: data.until.present ? data.until.value : this.until,
      countLimit: data.countLimit.present
          ? data.countLimit.value
          : this.countLimit,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      repeatMode: data.repeatMode.present
          ? data.repeatMode.value
          : this.repeatMode,
      timeZone: data.timeZone.present ? data.timeZone.value : this.timeZone,
      selectedDatesJson: data.selectedDatesJson.present
          ? data.selectedDatesJson.value
          : this.selectedDatesJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoRepeatRule(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('taskId: $taskId, ')
          ..write('freq: $freq, ')
          ..write('interval: $interval, ')
          ..write('byDay: $byDay, ')
          ..write('monthDay: $monthDay, ')
          ..write('startAt: $startAt, ')
          ..write('until: $until, ')
          ..write('countLimit: $countLimit, ')
          ..write('enabled: $enabled, ')
          ..write('repeatMode: $repeatMode, ')
          ..write('timeZone: $timeZone, ')
          ..write('selectedDatesJson: $selectedDatesJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    taskId,
    freq,
    interval,
    byDay,
    monthDay,
    startAt,
    until,
    countLimit,
    enabled,
    repeatMode,
    timeZone,
    selectedDatesJson,
    updatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoRepeatRule &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.taskId == this.taskId &&
          other.freq == this.freq &&
          other.interval == this.interval &&
          other.byDay == this.byDay &&
          other.monthDay == this.monthDay &&
          other.startAt == this.startAt &&
          other.until == this.until &&
          other.countLimit == this.countLimit &&
          other.enabled == this.enabled &&
          other.repeatMode == this.repeatMode &&
          other.timeZone == this.timeZone &&
          other.selectedDatesJson == this.selectedDatesJson &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoRepeatRulesCompanion extends UpdateCompanion<TodoRepeatRule> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<String> taskId;
  final Value<String> freq;
  final Value<int> interval;
  final Value<String?> byDay;
  final Value<int?> monthDay;
  final Value<DateTime?> startAt;
  final Value<DateTime?> until;
  final Value<int?> countLimit;
  final Value<bool> enabled;
  final Value<String> repeatMode;
  final Value<String?> timeZone;
  final Value<String?> selectedDatesJson;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TodoRepeatRulesCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.freq = const Value.absent(),
    this.interval = const Value.absent(),
    this.byDay = const Value.absent(),
    this.monthDay = const Value.absent(),
    this.startAt = const Value.absent(),
    this.until = const Value.absent(),
    this.countLimit = const Value.absent(),
    this.enabled = const Value.absent(),
    this.repeatMode = const Value.absent(),
    this.timeZone = const Value.absent(),
    this.selectedDatesJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoRepeatRulesCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String taskId,
    required String freq,
    this.interval = const Value.absent(),
    this.byDay = const Value.absent(),
    this.monthDay = const Value.absent(),
    this.startAt = const Value.absent(),
    this.until = const Value.absent(),
    this.countLimit = const Value.absent(),
    this.enabled = const Value.absent(),
    this.repeatMode = const Value.absent(),
    this.timeZone = const Value.absent(),
    this.selectedDatesJson = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       freq = Value(freq),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoRepeatRule> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<String>? taskId,
    Expression<String>? freq,
    Expression<int>? interval,
    Expression<String>? byDay,
    Expression<int>? monthDay,
    Expression<DateTime>? startAt,
    Expression<DateTime>? until,
    Expression<int>? countLimit,
    Expression<bool>? enabled,
    Expression<String>? repeatMode,
    Expression<String>? timeZone,
    Expression<String>? selectedDatesJson,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (taskId != null) 'task_id': taskId,
      if (freq != null) 'freq': freq,
      if (interval != null) 'interval': interval,
      if (byDay != null) 'by_day': byDay,
      if (monthDay != null) 'month_day': monthDay,
      if (startAt != null) 'start_at': startAt,
      if (until != null) 'until': until,
      if (countLimit != null) 'count_limit': countLimit,
      if (enabled != null) 'enabled': enabled,
      if (repeatMode != null) 'repeat_mode': repeatMode,
      if (timeZone != null) 'time_zone': timeZone,
      if (selectedDatesJson != null) 'selected_dates_json': selectedDatesJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoRepeatRulesCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<String>? taskId,
    Value<String>? freq,
    Value<int>? interval,
    Value<String?>? byDay,
    Value<int?>? monthDay,
    Value<DateTime?>? startAt,
    Value<DateTime?>? until,
    Value<int?>? countLimit,
    Value<bool>? enabled,
    Value<String>? repeatMode,
    Value<String?>? timeZone,
    Value<String?>? selectedDatesJson,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TodoRepeatRulesCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      taskId: taskId ?? this.taskId,
      freq: freq ?? this.freq,
      interval: interval ?? this.interval,
      byDay: byDay ?? this.byDay,
      monthDay: monthDay ?? this.monthDay,
      startAt: startAt ?? this.startAt,
      until: until ?? this.until,
      countLimit: countLimit ?? this.countLimit,
      enabled: enabled ?? this.enabled,
      repeatMode: repeatMode ?? this.repeatMode,
      timeZone: timeZone ?? this.timeZone,
      selectedDatesJson: selectedDatesJson ?? this.selectedDatesJson,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (freq.present) {
      map['freq'] = Variable<String>(freq.value);
    }
    if (interval.present) {
      map['interval'] = Variable<int>(interval.value);
    }
    if (byDay.present) {
      map['by_day'] = Variable<String>(byDay.value);
    }
    if (monthDay.present) {
      map['month_day'] = Variable<int>(monthDay.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (until.present) {
      map['until'] = Variable<DateTime>(until.value);
    }
    if (countLimit.present) {
      map['count_limit'] = Variable<int>(countLimit.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (repeatMode.present) {
      map['repeat_mode'] = Variable<String>(repeatMode.value);
    }
    if (timeZone.present) {
      map['time_zone'] = Variable<String>(timeZone.value);
    }
    if (selectedDatesJson.present) {
      map['selected_dates_json'] = Variable<String>(selectedDatesJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoRepeatRulesCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('taskId: $taskId, ')
          ..write('freq: $freq, ')
          ..write('interval: $interval, ')
          ..write('byDay: $byDay, ')
          ..write('monthDay: $monthDay, ')
          ..write('startAt: $startAt, ')
          ..write('until: $until, ')
          ..write('countLimit: $countLimit, ')
          ..write('enabled: $enabled, ')
          ..write('repeatMode: $repeatMode, ')
          ..write('timeZone: $timeZone, ')
          ..write('selectedDatesJson: $selectedDatesJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoRepeatSkipsTable extends TodoRepeatSkips
    with TableInfo<$TodoRepeatSkipsTable, TodoRepeatSkip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoRepeatSkipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repeatRuleIdMeta = const VerificationMeta(
    'repeatRuleId',
  );
  @override
  late final GeneratedColumn<String> repeatRuleId = GeneratedColumn<String>(
    'repeat_rule_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurrenceDateMeta = const VerificationMeta(
    'occurrenceDate',
  );
  @override
  late final GeneratedColumn<DateTime> occurrenceDate =
      GeneratedColumn<DateTime>(
        'occurrence_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    repeatRuleId,
    taskId,
    occurrenceDate,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_repeat_skips';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoRepeatSkip> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('repeat_rule_id')) {
      context.handle(
        _repeatRuleIdMeta,
        repeatRuleId.isAcceptableOrUnknown(
          data['repeat_rule_id']!,
          _repeatRuleIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repeatRuleIdMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('occurrence_date')) {
      context.handle(
        _occurrenceDateMeta,
        occurrenceDate.isAcceptableOrUnknown(
          data['occurrence_date']!,
          _occurrenceDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurrenceDateMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoRepeatSkip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoRepeatSkip(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      repeatRuleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_rule_id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      occurrenceDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurrence_date'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TodoRepeatSkipsTable createAlias(String alias) {
    return $TodoRepeatSkipsTable(attachedDatabase, alias);
  }
}

class TodoRepeatSkip extends DataClass implements Insertable<TodoRepeatSkip> {
  final String id;
  final int? serverId;
  final String repeatRuleId;
  final String taskId;
  final DateTime occurrenceDate;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoRepeatSkip({
    required this.id,
    this.serverId,
    required this.repeatRuleId,
    required this.taskId,
    required this.occurrenceDate,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['repeat_rule_id'] = Variable<String>(repeatRuleId);
    map['task_id'] = Variable<String>(taskId);
    map['occurrence_date'] = Variable<DateTime>(occurrenceDate);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TodoRepeatSkipsCompanion toCompanion(bool nullToAbsent) {
    return TodoRepeatSkipsCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      repeatRuleId: Value(repeatRuleId),
      taskId: Value(taskId),
      occurrenceDate: Value(occurrenceDate),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory TodoRepeatSkip.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoRepeatSkip(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      repeatRuleId: serializer.fromJson<String>(json['repeatRuleId']),
      taskId: serializer.fromJson<String>(json['taskId']),
      occurrenceDate: serializer.fromJson<DateTime>(json['occurrenceDate']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'repeatRuleId': serializer.toJson<String>(repeatRuleId),
      'taskId': serializer.toJson<String>(taskId),
      'occurrenceDate': serializer.toJson<DateTime>(occurrenceDate),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoRepeatSkip copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    String? repeatRuleId,
    String? taskId,
    DateTime? occurrenceDate,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoRepeatSkip(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    repeatRuleId: repeatRuleId ?? this.repeatRuleId,
    taskId: taskId ?? this.taskId,
    occurrenceDate: occurrenceDate ?? this.occurrenceDate,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoRepeatSkip copyWithCompanion(TodoRepeatSkipsCompanion data) {
    return TodoRepeatSkip(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      repeatRuleId: data.repeatRuleId.present
          ? data.repeatRuleId.value
          : this.repeatRuleId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      occurrenceDate: data.occurrenceDate.present
          ? data.occurrenceDate.value
          : this.occurrenceDate,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoRepeatSkip(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('repeatRuleId: $repeatRuleId, ')
          ..write('taskId: $taskId, ')
          ..write('occurrenceDate: $occurrenceDate, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    repeatRuleId,
    taskId,
    occurrenceDate,
    updatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoRepeatSkip &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.repeatRuleId == this.repeatRuleId &&
          other.taskId == this.taskId &&
          other.occurrenceDate == this.occurrenceDate &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoRepeatSkipsCompanion extends UpdateCompanion<TodoRepeatSkip> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<String> repeatRuleId;
  final Value<String> taskId;
  final Value<DateTime> occurrenceDate;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TodoRepeatSkipsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.repeatRuleId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.occurrenceDate = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoRepeatSkipsCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String repeatRuleId,
    required String taskId,
    required DateTime occurrenceDate,
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       repeatRuleId = Value(repeatRuleId),
       taskId = Value(taskId),
       occurrenceDate = Value(occurrenceDate),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoRepeatSkip> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<String>? repeatRuleId,
    Expression<String>? taskId,
    Expression<DateTime>? occurrenceDate,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (repeatRuleId != null) 'repeat_rule_id': repeatRuleId,
      if (taskId != null) 'task_id': taskId,
      if (occurrenceDate != null) 'occurrence_date': occurrenceDate,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoRepeatSkipsCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<String>? repeatRuleId,
    Value<String>? taskId,
    Value<DateTime>? occurrenceDate,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TodoRepeatSkipsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      repeatRuleId: repeatRuleId ?? this.repeatRuleId,
      taskId: taskId ?? this.taskId,
      occurrenceDate: occurrenceDate ?? this.occurrenceDate,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (repeatRuleId.present) {
      map['repeat_rule_id'] = Variable<String>(repeatRuleId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (occurrenceDate.present) {
      map['occurrence_date'] = Variable<DateTime>(occurrenceDate.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoRepeatSkipsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('repeatRuleId: $repeatRuleId, ')
          ..write('taskId: $taskId, ')
          ..write('occurrenceDate: $occurrenceDate, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoViewPreferencesTable extends TodoViewPreferences
    with TableInfo<$TodoViewPreferencesTable, TodoViewPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoViewPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta(
    'sourceKey',
  );
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  @override
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    sourceType,
    sourceKey,
    valueJson,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_view_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoViewPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('source_key')) {
      context.handle(
        _sourceKeyMeta,
        sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceKeyMeta);
    }
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valueJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourceType, sourceKey},
  ];
  @override
  TodoViewPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoViewPreference(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      sourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_key'],
      )!,
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TodoViewPreferencesTable createAlias(String alias) {
    return $TodoViewPreferencesTable(attachedDatabase, alias);
  }
}

class TodoViewPreference extends DataClass
    implements Insertable<TodoViewPreference> {
  final String id;
  final int? serverId;
  final String sourceType;
  final String sourceKey;
  final String valueJson;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoViewPreference({
    required this.id,
    this.serverId,
    required this.sourceType,
    required this.sourceKey,
    required this.valueJson,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['source_type'] = Variable<String>(sourceType);
    map['source_key'] = Variable<String>(sourceKey);
    map['value_json'] = Variable<String>(valueJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TodoViewPreferencesCompanion toCompanion(bool nullToAbsent) {
    return TodoViewPreferencesCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      sourceType: Value(sourceType),
      sourceKey: Value(sourceKey),
      valueJson: Value(valueJson),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory TodoViewPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoViewPreference(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      sourceKey: serializer.fromJson<String>(json['sourceKey']),
      valueJson: serializer.fromJson<String>(json['valueJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'sourceType': serializer.toJson<String>(sourceType),
      'sourceKey': serializer.toJson<String>(sourceKey),
      'valueJson': serializer.toJson<String>(valueJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoViewPreference copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    String? sourceType,
    String? sourceKey,
    String? valueJson,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoViewPreference(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    sourceType: sourceType ?? this.sourceType,
    sourceKey: sourceKey ?? this.sourceKey,
    valueJson: valueJson ?? this.valueJson,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoViewPreference copyWithCompanion(TodoViewPreferencesCompanion data) {
    return TodoViewPreference(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoViewPreference(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    sourceType,
    sourceKey,
    valueJson,
    updatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoViewPreference &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.sourceType == this.sourceType &&
          other.sourceKey == this.sourceKey &&
          other.valueJson == this.valueJson &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoViewPreferencesCompanion extends UpdateCompanion<TodoViewPreference> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<String> sourceType;
  final Value<String> sourceKey;
  final Value<String> valueJson;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TodoViewPreferencesCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoViewPreferencesCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String sourceType,
    required String sourceKey,
    required String valueJson,
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceType = Value(sourceType),
       sourceKey = Value(sourceKey),
       valueJson = Value(valueJson),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoViewPreference> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<String>? sourceType,
    Expression<String>? sourceKey,
    Expression<String>? valueJson,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (sourceType != null) 'source_type': sourceType,
      if (sourceKey != null) 'source_key': sourceKey,
      if (valueJson != null) 'value_json': valueJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoViewPreferencesCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<String>? sourceType,
    Value<String>? sourceKey,
    Value<String>? valueJson,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TodoViewPreferencesCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      sourceType: sourceType ?? this.sourceType,
      sourceKey: sourceKey ?? this.sourceKey,
      valueJson: valueJson ?? this.valueJson,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoViewPreferencesCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoBoardPreferencesTable extends TodoBoardPreferences
    with TableInfo<$TodoBoardPreferencesTable, TodoBoardPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoBoardPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupDimensionMeta = const VerificationMeta(
    'groupDimension',
  );
  @override
  late final GeneratedColumn<String> groupDimension = GeneratedColumn<String>(
    'group_dimension',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _columnsJsonMeta = const VerificationMeta(
    'columnsJson',
  );
  @override
  late final GeneratedColumn<String> columnsJson = GeneratedColumn<String>(
    'columns_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    listId,
    groupDimension,
    columnsJson,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_board_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoBoardPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('group_dimension')) {
      context.handle(
        _groupDimensionMeta,
        groupDimension.isAcceptableOrUnknown(
          data['group_dimension']!,
          _groupDimensionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_groupDimensionMeta);
    }
    if (data.containsKey('columns_json')) {
      context.handle(
        _columnsJsonMeta,
        columnsJson.isAcceptableOrUnknown(
          data['columns_json']!,
          _columnsJsonMeta,
        ),
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
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {listId},
  ];
  @override
  TodoBoardPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoBoardPreference(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      )!,
      groupDimension: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_dimension'],
      )!,
      columnsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}columns_json'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TodoBoardPreferencesTable createAlias(String alias) {
    return $TodoBoardPreferencesTable(attachedDatabase, alias);
  }
}

class TodoBoardPreference extends DataClass
    implements Insertable<TodoBoardPreference> {
  final String id;
  final int? serverId;
  final String listId;
  final String groupDimension;
  final String? columnsJson;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoBoardPreference({
    required this.id,
    this.serverId,
    required this.listId,
    required this.groupDimension,
    this.columnsJson,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['list_id'] = Variable<String>(listId);
    map['group_dimension'] = Variable<String>(groupDimension);
    if (!nullToAbsent || columnsJson != null) {
      map['columns_json'] = Variable<String>(columnsJson);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TodoBoardPreferencesCompanion toCompanion(bool nullToAbsent) {
    return TodoBoardPreferencesCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      listId: Value(listId),
      groupDimension: Value(groupDimension),
      columnsJson: columnsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(columnsJson),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory TodoBoardPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoBoardPreference(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      listId: serializer.fromJson<String>(json['listId']),
      groupDimension: serializer.fromJson<String>(json['groupDimension']),
      columnsJson: serializer.fromJson<String?>(json['columnsJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'listId': serializer.toJson<String>(listId),
      'groupDimension': serializer.toJson<String>(groupDimension),
      'columnsJson': serializer.toJson<String?>(columnsJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoBoardPreference copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    String? listId,
    String? groupDimension,
    Value<String?> columnsJson = const Value.absent(),
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoBoardPreference(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    listId: listId ?? this.listId,
    groupDimension: groupDimension ?? this.groupDimension,
    columnsJson: columnsJson.present ? columnsJson.value : this.columnsJson,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoBoardPreference copyWithCompanion(TodoBoardPreferencesCompanion data) {
    return TodoBoardPreference(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      listId: data.listId.present ? data.listId.value : this.listId,
      groupDimension: data.groupDimension.present
          ? data.groupDimension.value
          : this.groupDimension,
      columnsJson: data.columnsJson.present
          ? data.columnsJson.value
          : this.columnsJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoBoardPreference(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('listId: $listId, ')
          ..write('groupDimension: $groupDimension, ')
          ..write('columnsJson: $columnsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    listId,
    groupDimension,
    columnsJson,
    updatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoBoardPreference &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.listId == this.listId &&
          other.groupDimension == this.groupDimension &&
          other.columnsJson == this.columnsJson &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoBoardPreferencesCompanion
    extends UpdateCompanion<TodoBoardPreference> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<String> listId;
  final Value<String> groupDimension;
  final Value<String?> columnsJson;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TodoBoardPreferencesCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.listId = const Value.absent(),
    this.groupDimension = const Value.absent(),
    this.columnsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoBoardPreferencesCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String listId,
    required String groupDimension,
    this.columnsJson = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       listId = Value(listId),
       groupDimension = Value(groupDimension),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoBoardPreference> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<String>? listId,
    Expression<String>? groupDimension,
    Expression<String>? columnsJson,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (listId != null) 'list_id': listId,
      if (groupDimension != null) 'group_dimension': groupDimension,
      if (columnsJson != null) 'columns_json': columnsJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoBoardPreferencesCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<String>? listId,
    Value<String>? groupDimension,
    Value<String?>? columnsJson,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TodoBoardPreferencesCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      listId: listId ?? this.listId,
      groupDimension: groupDimension ?? this.groupDimension,
      columnsJson: columnsJson ?? this.columnsJson,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (groupDimension.present) {
      map['group_dimension'] = Variable<String>(groupDimension.value);
    }
    if (columnsJson.present) {
      map['columns_json'] = Variable<String>(columnsJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoBoardPreferencesCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('listId: $listId, ')
          ..write('groupDimension: $groupDimension, ')
          ..write('columnsJson: $columnsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoFiltersTable extends TodoFilters
    with TableInfo<$TodoFiltersTable, TodoFilter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoFiltersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conditionJsonMeta = const VerificationMeta(
    'conditionJson',
  );
  @override
  late final GeneratedColumn<String> conditionJson = GeneratedColumn<String>(
    'condition_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrdersJsonMeta = const VerificationMeta(
    'sortOrdersJson',
  );
  @override
  late final GeneratedColumn<String> sortOrdersJson = GeneratedColumn<String>(
    'sort_orders_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _isSmartMeta = const VerificationMeta(
    'isSmart',
  );
  @override
  late final GeneratedColumn<bool> isSmart = GeneratedColumn<bool>(
    'is_smart',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_smart" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
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
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    name,
    conditionJson,
    sortOrdersJson,
    isSmart,
    isPinned,
    sortOrder,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_filters';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoFilter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('condition_json')) {
      context.handle(
        _conditionJsonMeta,
        conditionJson.isAcceptableOrUnknown(
          data['condition_json']!,
          _conditionJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conditionJsonMeta);
    }
    if (data.containsKey('sort_orders_json')) {
      context.handle(
        _sortOrdersJsonMeta,
        sortOrdersJson.isAcceptableOrUnknown(
          data['sort_orders_json']!,
          _sortOrdersJsonMeta,
        ),
      );
    }
    if (data.containsKey('is_smart')) {
      context.handle(
        _isSmartMeta,
        isSmart.isAcceptableOrUnknown(data['is_smart']!, _isSmartMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
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
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoFilter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoFilter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      conditionJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}condition_json'],
      )!,
      sortOrdersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_orders_json'],
      )!,
      isSmart: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_smart'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TodoFiltersTable createAlias(String alias) {
    return $TodoFiltersTable(attachedDatabase, alias);
  }
}

class TodoFilter extends DataClass implements Insertable<TodoFilter> {
  final String id;
  final int? serverId;
  final String name;
  final String conditionJson;
  final String sortOrdersJson;
  final bool isSmart;
  final bool isPinned;
  final int sortOrder;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoFilter({
    required this.id,
    this.serverId,
    required this.name,
    required this.conditionJson,
    required this.sortOrdersJson,
    required this.isSmart,
    required this.isPinned,
    required this.sortOrder,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['name'] = Variable<String>(name);
    map['condition_json'] = Variable<String>(conditionJson);
    map['sort_orders_json'] = Variable<String>(sortOrdersJson);
    map['is_smart'] = Variable<bool>(isSmart);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['sort_order'] = Variable<int>(sortOrder);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TodoFiltersCompanion toCompanion(bool nullToAbsent) {
    return TodoFiltersCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      name: Value(name),
      conditionJson: Value(conditionJson),
      sortOrdersJson: Value(sortOrdersJson),
      isSmart: Value(isSmart),
      isPinned: Value(isPinned),
      sortOrder: Value(sortOrder),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory TodoFilter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoFilter(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      name: serializer.fromJson<String>(json['name']),
      conditionJson: serializer.fromJson<String>(json['conditionJson']),
      sortOrdersJson: serializer.fromJson<String>(json['sortOrdersJson']),
      isSmart: serializer.fromJson<bool>(json['isSmart']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'name': serializer.toJson<String>(name),
      'conditionJson': serializer.toJson<String>(conditionJson),
      'sortOrdersJson': serializer.toJson<String>(sortOrdersJson),
      'isSmart': serializer.toJson<bool>(isSmart),
      'isPinned': serializer.toJson<bool>(isPinned),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoFilter copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    String? name,
    String? conditionJson,
    String? sortOrdersJson,
    bool? isSmart,
    bool? isPinned,
    int? sortOrder,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoFilter(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    name: name ?? this.name,
    conditionJson: conditionJson ?? this.conditionJson,
    sortOrdersJson: sortOrdersJson ?? this.sortOrdersJson,
    isSmart: isSmart ?? this.isSmart,
    isPinned: isPinned ?? this.isPinned,
    sortOrder: sortOrder ?? this.sortOrder,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoFilter copyWithCompanion(TodoFiltersCompanion data) {
    return TodoFilter(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      name: data.name.present ? data.name.value : this.name,
      conditionJson: data.conditionJson.present
          ? data.conditionJson.value
          : this.conditionJson,
      sortOrdersJson: data.sortOrdersJson.present
          ? data.sortOrdersJson.value
          : this.sortOrdersJson,
      isSmart: data.isSmart.present ? data.isSmart.value : this.isSmart,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoFilter(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('conditionJson: $conditionJson, ')
          ..write('sortOrdersJson: $sortOrdersJson, ')
          ..write('isSmart: $isSmart, ')
          ..write('isPinned: $isPinned, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    name,
    conditionJson,
    sortOrdersJson,
    isSmart,
    isPinned,
    sortOrder,
    updatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoFilter &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.name == this.name &&
          other.conditionJson == this.conditionJson &&
          other.sortOrdersJson == this.sortOrdersJson &&
          other.isSmart == this.isSmart &&
          other.isPinned == this.isPinned &&
          other.sortOrder == this.sortOrder &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoFiltersCompanion extends UpdateCompanion<TodoFilter> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<String> name;
  final Value<String> conditionJson;
  final Value<String> sortOrdersJson;
  final Value<bool> isSmart;
  final Value<bool> isPinned;
  final Value<int> sortOrder;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TodoFiltersCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.name = const Value.absent(),
    this.conditionJson = const Value.absent(),
    this.sortOrdersJson = const Value.absent(),
    this.isSmart = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoFiltersCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String name,
    required String conditionJson,
    this.sortOrdersJson = const Value.absent(),
    this.isSmart = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       conditionJson = Value(conditionJson),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoFilter> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<String>? name,
    Expression<String>? conditionJson,
    Expression<String>? sortOrdersJson,
    Expression<bool>? isSmart,
    Expression<bool>? isPinned,
    Expression<int>? sortOrder,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (name != null) 'name': name,
      if (conditionJson != null) 'condition_json': conditionJson,
      if (sortOrdersJson != null) 'sort_orders_json': sortOrdersJson,
      if (isSmart != null) 'is_smart': isSmart,
      if (isPinned != null) 'is_pinned': isPinned,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoFiltersCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<String>? name,
    Value<String>? conditionJson,
    Value<String>? sortOrdersJson,
    Value<bool>? isSmart,
    Value<bool>? isPinned,
    Value<int>? sortOrder,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TodoFiltersCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      conditionJson: conditionJson ?? this.conditionJson,
      sortOrdersJson: sortOrdersJson ?? this.sortOrdersJson,
      isSmart: isSmart ?? this.isSmart,
      isPinned: isPinned ?? this.isPinned,
      sortOrder: sortOrder ?? this.sortOrder,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (conditionJson.present) {
      map['condition_json'] = Variable<String>(conditionJson.value);
    }
    if (sortOrdersJson.present) {
      map['sort_orders_json'] = Variable<String>(sortOrdersJson.value);
    }
    if (isSmart.present) {
      map['is_smart'] = Variable<bool>(isSmart.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoFiltersCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('conditionJson: $conditionJson, ')
          ..write('sortOrdersJson: $sortOrdersJson, ')
          ..write('isSmart: $isSmart, ')
          ..write('isPinned: $isPinned, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoRecommendationsTable extends TodoRecommendations
    with TableInfo<$TodoRecommendationsTable, TodoRecommendation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoRecommendationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _taskServerIdMeta = const VerificationMeta(
    'taskServerId',
  );
  @override
  late final GeneratedColumn<int> taskServerId = GeneratedColumn<int>(
    'task_server_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reasonCodeMeta = const VerificationMeta(
    'reasonCode',
  );
  @override
  late final GeneratedColumn<String> reasonCode = GeneratedColumn<String>(
    'reason_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _refreshedAtMeta = const VerificationMeta(
    'refreshedAt',
  );
  @override
  late final GeneratedColumn<DateTime> refreshedAt = GeneratedColumn<DateTime>(
    'refreshed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    taskServerId,
    title,
    dueAt,
    reasonCode,
    reason,
    score,
    refreshedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_recommendations';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoRecommendation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('task_server_id')) {
      context.handle(
        _taskServerIdMeta,
        taskServerId.isAcceptableOrUnknown(
          data['task_server_id']!,
          _taskServerIdMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('reason_code')) {
      context.handle(
        _reasonCodeMeta,
        reasonCode.isAcceptableOrUnknown(data['reason_code']!, _reasonCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonCodeMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('refreshed_at')) {
      context.handle(
        _refreshedAtMeta,
        refreshedAt.isAcceptableOrUnknown(
          data['refreshed_at']!,
          _refreshedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_refreshedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskServerId};
  @override
  TodoRecommendation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoRecommendation(
      taskServerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_server_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      ),
      reasonCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason_code'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      )!,
      refreshedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}refreshed_at'],
      )!,
    );
  }

  @override
  $TodoRecommendationsTable createAlias(String alias) {
    return $TodoRecommendationsTable(attachedDatabase, alias);
  }
}

class TodoRecommendation extends DataClass
    implements Insertable<TodoRecommendation> {
  final int taskServerId;
  final String title;
  final DateTime? dueAt;
  final String reasonCode;
  final String reason;
  final int score;
  final DateTime refreshedAt;
  const TodoRecommendation({
    required this.taskServerId,
    required this.title,
    this.dueAt,
    required this.reasonCode,
    required this.reason,
    required this.score,
    required this.refreshedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_server_id'] = Variable<int>(taskServerId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<DateTime>(dueAt);
    }
    map['reason_code'] = Variable<String>(reasonCode);
    map['reason'] = Variable<String>(reason);
    map['score'] = Variable<int>(score);
    map['refreshed_at'] = Variable<DateTime>(refreshedAt);
    return map;
  }

  TodoRecommendationsCompanion toCompanion(bool nullToAbsent) {
    return TodoRecommendationsCompanion(
      taskServerId: Value(taskServerId),
      title: Value(title),
      dueAt: dueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAt),
      reasonCode: Value(reasonCode),
      reason: Value(reason),
      score: Value(score),
      refreshedAt: Value(refreshedAt),
    );
  }

  factory TodoRecommendation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoRecommendation(
      taskServerId: serializer.fromJson<int>(json['taskServerId']),
      title: serializer.fromJson<String>(json['title']),
      dueAt: serializer.fromJson<DateTime?>(json['dueAt']),
      reasonCode: serializer.fromJson<String>(json['reasonCode']),
      reason: serializer.fromJson<String>(json['reason']),
      score: serializer.fromJson<int>(json['score']),
      refreshedAt: serializer.fromJson<DateTime>(json['refreshedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'taskServerId': serializer.toJson<int>(taskServerId),
      'title': serializer.toJson<String>(title),
      'dueAt': serializer.toJson<DateTime?>(dueAt),
      'reasonCode': serializer.toJson<String>(reasonCode),
      'reason': serializer.toJson<String>(reason),
      'score': serializer.toJson<int>(score),
      'refreshedAt': serializer.toJson<DateTime>(refreshedAt),
    };
  }

  TodoRecommendation copyWith({
    int? taskServerId,
    String? title,
    Value<DateTime?> dueAt = const Value.absent(),
    String? reasonCode,
    String? reason,
    int? score,
    DateTime? refreshedAt,
  }) => TodoRecommendation(
    taskServerId: taskServerId ?? this.taskServerId,
    title: title ?? this.title,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    reasonCode: reasonCode ?? this.reasonCode,
    reason: reason ?? this.reason,
    score: score ?? this.score,
    refreshedAt: refreshedAt ?? this.refreshedAt,
  );
  TodoRecommendation copyWithCompanion(TodoRecommendationsCompanion data) {
    return TodoRecommendation(
      taskServerId: data.taskServerId.present
          ? data.taskServerId.value
          : this.taskServerId,
      title: data.title.present ? data.title.value : this.title,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      reasonCode: data.reasonCode.present
          ? data.reasonCode.value
          : this.reasonCode,
      reason: data.reason.present ? data.reason.value : this.reason,
      score: data.score.present ? data.score.value : this.score,
      refreshedAt: data.refreshedAt.present
          ? data.refreshedAt.value
          : this.refreshedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoRecommendation(')
          ..write('taskServerId: $taskServerId, ')
          ..write('title: $title, ')
          ..write('dueAt: $dueAt, ')
          ..write('reasonCode: $reasonCode, ')
          ..write('reason: $reason, ')
          ..write('score: $score, ')
          ..write('refreshedAt: $refreshedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    taskServerId,
    title,
    dueAt,
    reasonCode,
    reason,
    score,
    refreshedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoRecommendation &&
          other.taskServerId == this.taskServerId &&
          other.title == this.title &&
          other.dueAt == this.dueAt &&
          other.reasonCode == this.reasonCode &&
          other.reason == this.reason &&
          other.score == this.score &&
          other.refreshedAt == this.refreshedAt);
}

class TodoRecommendationsCompanion extends UpdateCompanion<TodoRecommendation> {
  final Value<int> taskServerId;
  final Value<String> title;
  final Value<DateTime?> dueAt;
  final Value<String> reasonCode;
  final Value<String> reason;
  final Value<int> score;
  final Value<DateTime> refreshedAt;
  const TodoRecommendationsCompanion({
    this.taskServerId = const Value.absent(),
    this.title = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.reasonCode = const Value.absent(),
    this.reason = const Value.absent(),
    this.score = const Value.absent(),
    this.refreshedAt = const Value.absent(),
  });
  TodoRecommendationsCompanion.insert({
    this.taskServerId = const Value.absent(),
    required String title,
    this.dueAt = const Value.absent(),
    required String reasonCode,
    required String reason,
    required int score,
    required DateTime refreshedAt,
  }) : title = Value(title),
       reasonCode = Value(reasonCode),
       reason = Value(reason),
       score = Value(score),
       refreshedAt = Value(refreshedAt);
  static Insertable<TodoRecommendation> custom({
    Expression<int>? taskServerId,
    Expression<String>? title,
    Expression<DateTime>? dueAt,
    Expression<String>? reasonCode,
    Expression<String>? reason,
    Expression<int>? score,
    Expression<DateTime>? refreshedAt,
  }) {
    return RawValuesInsertable({
      if (taskServerId != null) 'task_server_id': taskServerId,
      if (title != null) 'title': title,
      if (dueAt != null) 'due_at': dueAt,
      if (reasonCode != null) 'reason_code': reasonCode,
      if (reason != null) 'reason': reason,
      if (score != null) 'score': score,
      if (refreshedAt != null) 'refreshed_at': refreshedAt,
    });
  }

  TodoRecommendationsCompanion copyWith({
    Value<int>? taskServerId,
    Value<String>? title,
    Value<DateTime?>? dueAt,
    Value<String>? reasonCode,
    Value<String>? reason,
    Value<int>? score,
    Value<DateTime>? refreshedAt,
  }) {
    return TodoRecommendationsCompanion(
      taskServerId: taskServerId ?? this.taskServerId,
      title: title ?? this.title,
      dueAt: dueAt ?? this.dueAt,
      reasonCode: reasonCode ?? this.reasonCode,
      reason: reason ?? this.reason,
      score: score ?? this.score,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (taskServerId.present) {
      map['task_server_id'] = Variable<int>(taskServerId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (reasonCode.present) {
      map['reason_code'] = Variable<String>(reasonCode.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (refreshedAt.present) {
      map['refreshed_at'] = Variable<DateTime>(refreshedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoRecommendationsCompanion(')
          ..write('taskServerId: $taskServerId, ')
          ..write('title: $title, ')
          ..write('dueAt: $dueAt, ')
          ..write('reasonCode: $reasonCode, ')
          ..write('reason: $reason, ')
          ..write('score: $score, ')
          ..write('refreshedAt: $refreshedAt')
          ..write(')'))
        .toString();
  }
}

class $TodoSyncChangesTable extends TodoSyncChanges
    with TableInfo<$TodoSyncChangesTable, TodoSyncChange> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoSyncChangesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _clientMutationIdMeta = const VerificationMeta(
    'clientMutationId',
  );
  @override
  late final GeneratedColumn<String> clientMutationId = GeneratedColumn<String>(
    'client_mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityLocalIdMeta = const VerificationMeta(
    'entityLocalId',
  );
  @override
  late final GeneratedColumn<String> entityLocalId = GeneratedColumn<String>(
    'entity_local_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _entityServerIdMeta = const VerificationMeta(
    'entityServerId',
  );
  @override
  late final GeneratedColumn<int> entityServerId = GeneratedColumn<int>(
    'entity_server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _failureReasonMeta = const VerificationMeta(
    'failureReason',
  );
  @override
  late final GeneratedColumn<String> failureReason = GeneratedColumn<String>(
    'failure_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientMutationId,
    entity,
    op,
    entityLocalId,
    entityServerId,
    payloadJson,
    createdAt,
    attemptCount,
    nextAttemptAt,
    status,
    failureReason,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_sync_changes';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoSyncChange> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_mutation_id')) {
      context.handle(
        _clientMutationIdMeta,
        clientMutationId.isAcceptableOrUnknown(
          data['client_mutation_id']!,
          _clientMutationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientMutationIdMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('entity_local_id')) {
      context.handle(
        _entityLocalIdMeta,
        entityLocalId.isAcceptableOrUnknown(
          data['entity_local_id']!,
          _entityLocalIdMeta,
        ),
      );
    }
    if (data.containsKey('entity_server_id')) {
      context.handle(
        _entityServerIdMeta,
        entityServerId.isAcceptableOrUnknown(
          data['entity_server_id']!,
          _entityServerIdMeta,
        ),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('failure_reason')) {
      context.handle(
        _failureReasonMeta,
        failureReason.isAcceptableOrUnknown(
          data['failure_reason']!,
          _failureReasonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoSyncChange map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoSyncChange(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientMutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_mutation_id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      entityLocalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_local_id'],
      ),
      entityServerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entity_server_id'],
      ),
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      failureReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_reason'],
      ),
    );
  }

  @override
  $TodoSyncChangesTable createAlias(String alias) {
    return $TodoSyncChangesTable(attachedDatabase, alias);
  }
}

class TodoSyncChange extends DataClass implements Insertable<TodoSyncChange> {
  final int id;
  final String clientMutationId;
  final String entity;
  final String op;
  final String? entityLocalId;
  final int? entityServerId;
  final String payloadJson;
  final DateTime createdAt;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final String status;
  final String? failureReason;
  const TodoSyncChange({
    required this.id,
    required this.clientMutationId,
    required this.entity,
    required this.op,
    this.entityLocalId,
    this.entityServerId,
    required this.payloadJson,
    required this.createdAt,
    required this.attemptCount,
    this.nextAttemptAt,
    required this.status,
    this.failureReason,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_mutation_id'] = Variable<String>(clientMutationId);
    map['entity'] = Variable<String>(entity);
    map['op'] = Variable<String>(op);
    if (!nullToAbsent || entityLocalId != null) {
      map['entity_local_id'] = Variable<String>(entityLocalId);
    }
    if (!nullToAbsent || entityServerId != null) {
      map['entity_server_id'] = Variable<int>(entityServerId);
    }
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || failureReason != null) {
      map['failure_reason'] = Variable<String>(failureReason);
    }
    return map;
  }

  TodoSyncChangesCompanion toCompanion(bool nullToAbsent) {
    return TodoSyncChangesCompanion(
      id: Value(id),
      clientMutationId: Value(clientMutationId),
      entity: Value(entity),
      op: Value(op),
      entityLocalId: entityLocalId == null && nullToAbsent
          ? const Value.absent()
          : Value(entityLocalId),
      entityServerId: entityServerId == null && nullToAbsent
          ? const Value.absent()
          : Value(entityServerId),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
      attemptCount: Value(attemptCount),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      status: Value(status),
      failureReason: failureReason == null && nullToAbsent
          ? const Value.absent()
          : Value(failureReason),
    );
  }

  factory TodoSyncChange.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoSyncChange(
      id: serializer.fromJson<int>(json['id']),
      clientMutationId: serializer.fromJson<String>(json['clientMutationId']),
      entity: serializer.fromJson<String>(json['entity']),
      op: serializer.fromJson<String>(json['op']),
      entityLocalId: serializer.fromJson<String?>(json['entityLocalId']),
      entityServerId: serializer.fromJson<int?>(json['entityServerId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      status: serializer.fromJson<String>(json['status']),
      failureReason: serializer.fromJson<String?>(json['failureReason']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientMutationId': serializer.toJson<String>(clientMutationId),
      'entity': serializer.toJson<String>(entity),
      'op': serializer.toJson<String>(op),
      'entityLocalId': serializer.toJson<String?>(entityLocalId),
      'entityServerId': serializer.toJson<int?>(entityServerId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'status': serializer.toJson<String>(status),
      'failureReason': serializer.toJson<String?>(failureReason),
    };
  }

  TodoSyncChange copyWith({
    int? id,
    String? clientMutationId,
    String? entity,
    String? op,
    Value<String?> entityLocalId = const Value.absent(),
    Value<int?> entityServerId = const Value.absent(),
    String? payloadJson,
    DateTime? createdAt,
    int? attemptCount,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    String? status,
    Value<String?> failureReason = const Value.absent(),
  }) => TodoSyncChange(
    id: id ?? this.id,
    clientMutationId: clientMutationId ?? this.clientMutationId,
    entity: entity ?? this.entity,
    op: op ?? this.op,
    entityLocalId: entityLocalId.present
        ? entityLocalId.value
        : this.entityLocalId,
    entityServerId: entityServerId.present
        ? entityServerId.value
        : this.entityServerId,
    payloadJson: payloadJson ?? this.payloadJson,
    createdAt: createdAt ?? this.createdAt,
    attemptCount: attemptCount ?? this.attemptCount,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    status: status ?? this.status,
    failureReason: failureReason.present
        ? failureReason.value
        : this.failureReason,
  );
  TodoSyncChange copyWithCompanion(TodoSyncChangesCompanion data) {
    return TodoSyncChange(
      id: data.id.present ? data.id.value : this.id,
      clientMutationId: data.clientMutationId.present
          ? data.clientMutationId.value
          : this.clientMutationId,
      entity: data.entity.present ? data.entity.value : this.entity,
      op: data.op.present ? data.op.value : this.op,
      entityLocalId: data.entityLocalId.present
          ? data.entityLocalId.value
          : this.entityLocalId,
      entityServerId: data.entityServerId.present
          ? data.entityServerId.value
          : this.entityServerId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      status: data.status.present ? data.status.value : this.status,
      failureReason: data.failureReason.present
          ? data.failureReason.value
          : this.failureReason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoSyncChange(')
          ..write('id: $id, ')
          ..write('clientMutationId: $clientMutationId, ')
          ..write('entity: $entity, ')
          ..write('op: $op, ')
          ..write('entityLocalId: $entityLocalId, ')
          ..write('entityServerId: $entityServerId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('status: $status, ')
          ..write('failureReason: $failureReason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientMutationId,
    entity,
    op,
    entityLocalId,
    entityServerId,
    payloadJson,
    createdAt,
    attemptCount,
    nextAttemptAt,
    status,
    failureReason,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoSyncChange &&
          other.id == this.id &&
          other.clientMutationId == this.clientMutationId &&
          other.entity == this.entity &&
          other.op == this.op &&
          other.entityLocalId == this.entityLocalId &&
          other.entityServerId == this.entityServerId &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt &&
          other.attemptCount == this.attemptCount &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.status == this.status &&
          other.failureReason == this.failureReason);
}

class TodoSyncChangesCompanion extends UpdateCompanion<TodoSyncChange> {
  final Value<int> id;
  final Value<String> clientMutationId;
  final Value<String> entity;
  final Value<String> op;
  final Value<String?> entityLocalId;
  final Value<int?> entityServerId;
  final Value<String> payloadJson;
  final Value<DateTime> createdAt;
  final Value<int> attemptCount;
  final Value<DateTime?> nextAttemptAt;
  final Value<String> status;
  final Value<String?> failureReason;
  const TodoSyncChangesCompanion({
    this.id = const Value.absent(),
    this.clientMutationId = const Value.absent(),
    this.entity = const Value.absent(),
    this.op = const Value.absent(),
    this.entityLocalId = const Value.absent(),
    this.entityServerId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.status = const Value.absent(),
    this.failureReason = const Value.absent(),
  });
  TodoSyncChangesCompanion.insert({
    this.id = const Value.absent(),
    required String clientMutationId,
    required String entity,
    required String op,
    this.entityLocalId = const Value.absent(),
    this.entityServerId = const Value.absent(),
    required String payloadJson,
    required DateTime createdAt,
    this.attemptCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.status = const Value.absent(),
    this.failureReason = const Value.absent(),
  }) : clientMutationId = Value(clientMutationId),
       entity = Value(entity),
       op = Value(op),
       payloadJson = Value(payloadJson),
       createdAt = Value(createdAt);
  static Insertable<TodoSyncChange> custom({
    Expression<int>? id,
    Expression<String>? clientMutationId,
    Expression<String>? entity,
    Expression<String>? op,
    Expression<String>? entityLocalId,
    Expression<int>? entityServerId,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<int>? attemptCount,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? status,
    Expression<String>? failureReason,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientMutationId != null) 'client_mutation_id': clientMutationId,
      if (entity != null) 'entity': entity,
      if (op != null) 'op': op,
      if (entityLocalId != null) 'entity_local_id': entityLocalId,
      if (entityServerId != null) 'entity_server_id': entityServerId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (status != null) 'status': status,
      if (failureReason != null) 'failure_reason': failureReason,
    });
  }

  TodoSyncChangesCompanion copyWith({
    Value<int>? id,
    Value<String>? clientMutationId,
    Value<String>? entity,
    Value<String>? op,
    Value<String?>? entityLocalId,
    Value<int?>? entityServerId,
    Value<String>? payloadJson,
    Value<DateTime>? createdAt,
    Value<int>? attemptCount,
    Value<DateTime?>? nextAttemptAt,
    Value<String>? status,
    Value<String?>? failureReason,
  }) {
    return TodoSyncChangesCompanion(
      id: id ?? this.id,
      clientMutationId: clientMutationId ?? this.clientMutationId,
      entity: entity ?? this.entity,
      op: op ?? this.op,
      entityLocalId: entityLocalId ?? this.entityLocalId,
      entityServerId: entityServerId ?? this.entityServerId,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      status: status ?? this.status,
      failureReason: failureReason ?? this.failureReason,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientMutationId.present) {
      map['client_mutation_id'] = Variable<String>(clientMutationId.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (entityLocalId.present) {
      map['entity_local_id'] = Variable<String>(entityLocalId.value);
    }
    if (entityServerId.present) {
      map['entity_server_id'] = Variable<int>(entityServerId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (failureReason.present) {
      map['failure_reason'] = Variable<String>(failureReason.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoSyncChangesCompanion(')
          ..write('id: $id, ')
          ..write('clientMutationId: $clientMutationId, ')
          ..write('entity: $entity, ')
          ..write('op: $op, ')
          ..write('entityLocalId: $entityLocalId, ')
          ..write('entityServerId: $entityServerId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('status: $status, ')
          ..write('failureReason: $failureReason')
          ..write(')'))
        .toString();
  }
}

class $TodoSyncCursorTable extends TodoSyncCursor
    with TableInfo<$TodoSyncCursorTable, TodoSyncCursorData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoSyncCursorTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<String> cursor = GeneratedColumn<String>(
    'cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncAt = GeneratedColumn<DateTime>(
    'last_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, cursor, lastSyncAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_sync_cursor';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoSyncCursorData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodoSyncCursorData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoSyncCursorData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor'],
      ),
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_sync_at'],
      ),
    );
  }

  @override
  $TodoSyncCursorTable createAlias(String alias) {
    return $TodoSyncCursorTable(attachedDatabase, alias);
  }
}

class TodoSyncCursorData extends DataClass
    implements Insertable<TodoSyncCursorData> {
  final int id;
  final String? cursor;
  final DateTime? lastSyncAt;
  const TodoSyncCursorData({required this.id, this.cursor, this.lastSyncAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || cursor != null) {
      map['cursor'] = Variable<String>(cursor);
    }
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt);
    }
    return map;
  }

  TodoSyncCursorCompanion toCompanion(bool nullToAbsent) {
    return TodoSyncCursorCompanion(
      id: Value(id),
      cursor: cursor == null && nullToAbsent
          ? const Value.absent()
          : Value(cursor),
      lastSyncAt: lastSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAt),
    );
  }

  factory TodoSyncCursorData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoSyncCursorData(
      id: serializer.fromJson<int>(json['id']),
      cursor: serializer.fromJson<String?>(json['cursor']),
      lastSyncAt: serializer.fromJson<DateTime?>(json['lastSyncAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cursor': serializer.toJson<String?>(cursor),
      'lastSyncAt': serializer.toJson<DateTime?>(lastSyncAt),
    };
  }

  TodoSyncCursorData copyWith({
    int? id,
    Value<String?> cursor = const Value.absent(),
    Value<DateTime?> lastSyncAt = const Value.absent(),
  }) => TodoSyncCursorData(
    id: id ?? this.id,
    cursor: cursor.present ? cursor.value : this.cursor,
    lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
  );
  TodoSyncCursorData copyWithCompanion(TodoSyncCursorCompanion data) {
    return TodoSyncCursorData(
      id: data.id.present ? data.id.value : this.id,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoSyncCursorData(')
          ..write('id: $id, ')
          ..write('cursor: $cursor, ')
          ..write('lastSyncAt: $lastSyncAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, cursor, lastSyncAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoSyncCursorData &&
          other.id == this.id &&
          other.cursor == this.cursor &&
          other.lastSyncAt == this.lastSyncAt);
}

class TodoSyncCursorCompanion extends UpdateCompanion<TodoSyncCursorData> {
  final Value<int> id;
  final Value<String?> cursor;
  final Value<DateTime?> lastSyncAt;
  const TodoSyncCursorCompanion({
    this.id = const Value.absent(),
    this.cursor = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
  });
  TodoSyncCursorCompanion.insert({
    this.id = const Value.absent(),
    this.cursor = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
  });
  static Insertable<TodoSyncCursorData> custom({
    Expression<int>? id,
    Expression<String>? cursor,
    Expression<DateTime>? lastSyncAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cursor != null) 'cursor': cursor,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
    });
  }

  TodoSyncCursorCompanion copyWith({
    Value<int>? id,
    Value<String?>? cursor,
    Value<DateTime?>? lastSyncAt,
  }) {
    return TodoSyncCursorCompanion(
      id: id ?? this.id,
      cursor: cursor ?? this.cursor,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<String>(cursor.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoSyncCursorCompanion(')
          ..write('id: $id, ')
          ..write('cursor: $cursor, ')
          ..write('lastSyncAt: $lastSyncAt')
          ..write(')'))
        .toString();
  }
}

class $TodoEntityRevisionsTable extends TodoEntityRevisions
    with TableInfo<$TodoEntityRevisionsTable, TodoEntityRevision> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoEntityRevisionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entity, serverId, revision];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_entity_revisions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoEntityRevision> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entity, serverId};
  @override
  TodoEntityRevision map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoEntityRevision(
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $TodoEntityRevisionsTable createAlias(String alias) {
    return $TodoEntityRevisionsTable(attachedDatabase, alias);
  }
}

class TodoEntityRevision extends DataClass
    implements Insertable<TodoEntityRevision> {
  final String entity;
  final int serverId;
  final int revision;
  const TodoEntityRevision({
    required this.entity,
    required this.serverId,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity'] = Variable<String>(entity);
    map['server_id'] = Variable<int>(serverId);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  TodoEntityRevisionsCompanion toCompanion(bool nullToAbsent) {
    return TodoEntityRevisionsCompanion(
      entity: Value(entity),
      serverId: Value(serverId),
      revision: Value(revision),
    );
  }

  factory TodoEntityRevision.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoEntityRevision(
      entity: serializer.fromJson<String>(json['entity']),
      serverId: serializer.fromJson<int>(json['serverId']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entity': serializer.toJson<String>(entity),
      'serverId': serializer.toJson<int>(serverId),
      'revision': serializer.toJson<int>(revision),
    };
  }

  TodoEntityRevision copyWith({String? entity, int? serverId, int? revision}) =>
      TodoEntityRevision(
        entity: entity ?? this.entity,
        serverId: serverId ?? this.serverId,
        revision: revision ?? this.revision,
      );
  TodoEntityRevision copyWithCompanion(TodoEntityRevisionsCompanion data) {
    return TodoEntityRevision(
      entity: data.entity.present ? data.entity.value : this.entity,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoEntityRevision(')
          ..write('entity: $entity, ')
          ..write('serverId: $serverId, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entity, serverId, revision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoEntityRevision &&
          other.entity == this.entity &&
          other.serverId == this.serverId &&
          other.revision == this.revision);
}

class TodoEntityRevisionsCompanion extends UpdateCompanion<TodoEntityRevision> {
  final Value<String> entity;
  final Value<int> serverId;
  final Value<int> revision;
  final Value<int> rowid;
  const TodoEntityRevisionsCompanion({
    this.entity = const Value.absent(),
    this.serverId = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoEntityRevisionsCompanion.insert({
    required String entity,
    required int serverId,
    required int revision,
    this.rowid = const Value.absent(),
  }) : entity = Value(entity),
       serverId = Value(serverId),
       revision = Value(revision);
  static Insertable<TodoEntityRevision> custom({
    Expression<String>? entity,
    Expression<int>? serverId,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entity != null) 'entity': entity,
      if (serverId != null) 'server_id': serverId,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoEntityRevisionsCompanion copyWith({
    Value<String>? entity,
    Value<int>? serverId,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return TodoEntityRevisionsCompanion(
      entity: entity ?? this.entity,
      serverId: serverId ?? this.serverId,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoEntityRevisionsCompanion(')
          ..write('entity: $entity, ')
          ..write('serverId: $serverId, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TodoListsTable todoLists = $TodoListsTable(this);
  late final $TodoTaskSectionsTable todoTaskSections = $TodoTaskSectionsTable(
    this,
  );
  late final $TodoTasksTable todoTasks = $TodoTasksTable(this);
  late final $TodoFoldersTable todoFolders = $TodoFoldersTable(this);
  late final $TodoTagsTable todoTags = $TodoTagsTable(this);
  late final $TodoTaskTagsTable todoTaskTags = $TodoTaskTagsTable(this);
  late final $TodoChecklistItemsTable todoChecklistItems =
      $TodoChecklistItemsTable(this);
  late final $TodoAttachmentsTable todoAttachments = $TodoAttachmentsTable(
    this,
  );
  late final $TodoActivitiesTable todoActivities = $TodoActivitiesTable(this);
  late final $TodoTemplatesTable todoTemplates = $TodoTemplatesTable(this);
  late final $TodoRemindersTable todoReminders = $TodoRemindersTable(this);
  late final $TodoRepeatRulesTable todoRepeatRules = $TodoRepeatRulesTable(
    this,
  );
  late final $TodoRepeatSkipsTable todoRepeatSkips = $TodoRepeatSkipsTable(
    this,
  );
  late final $TodoViewPreferencesTable todoViewPreferences =
      $TodoViewPreferencesTable(this);
  late final $TodoBoardPreferencesTable todoBoardPreferences =
      $TodoBoardPreferencesTable(this);
  late final $TodoFiltersTable todoFilters = $TodoFiltersTable(this);
  late final $TodoRecommendationsTable todoRecommendations =
      $TodoRecommendationsTable(this);
  late final $TodoSyncChangesTable todoSyncChanges = $TodoSyncChangesTable(
    this,
  );
  late final $TodoSyncCursorTable todoSyncCursor = $TodoSyncCursorTable(this);
  late final $TodoEntityRevisionsTable todoEntityRevisions =
      $TodoEntityRevisionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    todoLists,
    todoTaskSections,
    todoTasks,
    todoFolders,
    todoTags,
    todoTaskTags,
    todoChecklistItems,
    todoAttachments,
    todoActivities,
    todoTemplates,
    todoReminders,
    todoRepeatRules,
    todoRepeatSkips,
    todoViewPreferences,
    todoBoardPreferences,
    todoFilters,
    todoRecommendations,
    todoSyncChanges,
    todoSyncCursor,
    todoEntityRevisions,
  ];
}

typedef $$TodoListsTableCreateCompanionBuilder =
    TodoListsCompanion Function({
      required String id,
      Value<int?> serverId,
      required String name,
      Value<String?> folderLocalId,
      Value<int?> folderId,
      Value<int> sortOrder,
      Value<String> accessRole,
      Value<bool> writable,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$TodoListsTableUpdateCompanionBuilder =
    TodoListsCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<String> name,
      Value<String?> folderLocalId,
      Value<int?> folderId,
      Value<int> sortOrder,
      Value<String> accessRole,
      Value<bool> writable,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$TodoListsTableFilterComposer
    extends Composer<_$AppDatabase, $TodoListsTable> {
  $$TodoListsTableFilterComposer({
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

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderLocalId => $composableBuilder(
    column: $table.folderLocalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accessRole => $composableBuilder(
    column: $table.accessRole,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get writable => $composableBuilder(
    column: $table.writable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoListsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoListsTable> {
  $$TodoListsTableOrderingComposer({
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

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderLocalId => $composableBuilder(
    column: $table.folderLocalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accessRole => $composableBuilder(
    column: $table.accessRole,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get writable => $composableBuilder(
    column: $table.writable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoListsTable> {
  $$TodoListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get folderLocalId => $composableBuilder(
    column: $table.folderLocalId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get accessRole => $composableBuilder(
    column: $table.accessRole,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get writable =>
      $composableBuilder(column: $table.writable, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TodoListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoListsTable,
          TodoList,
          $$TodoListsTableFilterComposer,
          $$TodoListsTableOrderingComposer,
          $$TodoListsTableAnnotationComposer,
          $$TodoListsTableCreateCompanionBuilder,
          $$TodoListsTableUpdateCompanionBuilder,
          (TodoList, BaseReferences<_$AppDatabase, $TodoListsTable, TodoList>),
          TodoList,
          PrefetchHooks Function()
        > {
  $$TodoListsTableTableManager(_$AppDatabase db, $TodoListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> folderLocalId = const Value.absent(),
                Value<int?> folderId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> accessRole = const Value.absent(),
                Value<bool> writable = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoListsCompanion(
                id: id,
                serverId: serverId,
                name: name,
                folderLocalId: folderLocalId,
                folderId: folderId,
                sortOrder: sortOrder,
                accessRole: accessRole,
                writable: writable,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                required String name,
                Value<String?> folderLocalId = const Value.absent(),
                Value<int?> folderId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> accessRole = const Value.absent(),
                Value<bool> writable = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TodoListsCompanion.insert(
                id: id,
                serverId: serverId,
                name: name,
                folderLocalId: folderLocalId,
                folderId: folderId,
                sortOrder: sortOrder,
                accessRole: accessRole,
                writable: writable,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoListsTable,
      TodoList,
      $$TodoListsTableFilterComposer,
      $$TodoListsTableOrderingComposer,
      $$TodoListsTableAnnotationComposer,
      $$TodoListsTableCreateCompanionBuilder,
      $$TodoListsTableUpdateCompanionBuilder,
      (TodoList, BaseReferences<_$AppDatabase, $TodoListsTable, TodoList>),
      TodoList,
      PrefetchHooks Function()
    >;
typedef $$TodoTaskSectionsTableCreateCompanionBuilder =
    TodoTaskSectionsCompanion Function({
      required String id,
      Value<int?> serverId,
      required String listId,
      required String name,
      Value<int> sortOrder,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$TodoTaskSectionsTableUpdateCompanionBuilder =
    TodoTaskSectionsCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<String> listId,
      Value<String> name,
      Value<int> sortOrder,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$TodoTaskSectionsTableFilterComposer
    extends Composer<_$AppDatabase, $TodoTaskSectionsTable> {
  $$TodoTaskSectionsTableFilterComposer({
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

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoTaskSectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoTaskSectionsTable> {
  $$TodoTaskSectionsTableOrderingComposer({
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

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoTaskSectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoTaskSectionsTable> {
  $$TodoTaskSectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TodoTaskSectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoTaskSectionsTable,
          TodoTaskSection,
          $$TodoTaskSectionsTableFilterComposer,
          $$TodoTaskSectionsTableOrderingComposer,
          $$TodoTaskSectionsTableAnnotationComposer,
          $$TodoTaskSectionsTableCreateCompanionBuilder,
          $$TodoTaskSectionsTableUpdateCompanionBuilder,
          (
            TodoTaskSection,
            BaseReferences<
              _$AppDatabase,
              $TodoTaskSectionsTable,
              TodoTaskSection
            >,
          ),
          TodoTaskSection,
          PrefetchHooks Function()
        > {
  $$TodoTaskSectionsTableTableManager(
    _$AppDatabase db,
    $TodoTaskSectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoTaskSectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoTaskSectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoTaskSectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> listId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoTaskSectionsCompanion(
                id: id,
                serverId: serverId,
                listId: listId,
                name: name,
                sortOrder: sortOrder,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                required String listId,
                required String name,
                Value<int> sortOrder = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TodoTaskSectionsCompanion.insert(
                id: id,
                serverId: serverId,
                listId: listId,
                name: name,
                sortOrder: sortOrder,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoTaskSectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoTaskSectionsTable,
      TodoTaskSection,
      $$TodoTaskSectionsTableFilterComposer,
      $$TodoTaskSectionsTableOrderingComposer,
      $$TodoTaskSectionsTableAnnotationComposer,
      $$TodoTaskSectionsTableCreateCompanionBuilder,
      $$TodoTaskSectionsTableUpdateCompanionBuilder,
      (
        TodoTaskSection,
        BaseReferences<_$AppDatabase, $TodoTaskSectionsTable, TodoTaskSection>,
      ),
      TodoTaskSection,
      PrefetchHooks Function()
    >;
typedef $$TodoTasksTableCreateCompanionBuilder =
    TodoTasksCompanion Function({
      required String id,
      Value<int?> serverId,
      required String listId,
      Value<String?> sectionId,
      Value<String?> parentTaskId,
      required String title,
      Value<String?> description,
      Value<bool> completed,
      Value<DateTime?> completedAt,
      Value<bool> cancelled,
      Value<int> priority,
      Value<bool> isPinned,
      Value<int?> assigneeUserId,
      Value<String?> assigneeUserName,
      Value<int> sortOrder,
      Value<DateTime?> startAt,
      Value<DateTime?> endAt,
      Value<DateTime?> dueAt,
      Value<bool> allDay,
      Value<String?> timeZone,
      Value<bool> fixedTimezone,
      Value<String?> repeatParentTaskId,
      Value<String?> repeatRuleId,
      Value<DateTime?> repeatOccurrenceAt,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$TodoTasksTableUpdateCompanionBuilder =
    TodoTasksCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<String> listId,
      Value<String?> sectionId,
      Value<String?> parentTaskId,
      Value<String> title,
      Value<String?> description,
      Value<bool> completed,
      Value<DateTime?> completedAt,
      Value<bool> cancelled,
      Value<int> priority,
      Value<bool> isPinned,
      Value<int?> assigneeUserId,
      Value<String?> assigneeUserName,
      Value<int> sortOrder,
      Value<DateTime?> startAt,
      Value<DateTime?> endAt,
      Value<DateTime?> dueAt,
      Value<bool> allDay,
      Value<String?> timeZone,
      Value<bool> fixedTimezone,
      Value<String?> repeatParentTaskId,
      Value<String?> repeatRuleId,
      Value<DateTime?> repeatOccurrenceAt,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$TodoTasksTableFilterComposer
    extends Composer<_$AppDatabase, $TodoTasksTable> {
  $$TodoTasksTableFilterComposer({
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

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentTaskId => $composableBuilder(
    column: $table.parentTaskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get cancelled => $composableBuilder(
    column: $table.cancelled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get assigneeUserId => $composableBuilder(
    column: $table.assigneeUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assigneeUserName => $composableBuilder(
    column: $table.assigneeUserName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fixedTimezone => $composableBuilder(
    column: $table.fixedTimezone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatParentTaskId => $composableBuilder(
    column: $table.repeatParentTaskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatRuleId => $composableBuilder(
    column: $table.repeatRuleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get repeatOccurrenceAt => $composableBuilder(
    column: $table.repeatOccurrenceAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoTasksTable> {
  $$TodoTasksTableOrderingComposer({
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

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentTaskId => $composableBuilder(
    column: $table.parentTaskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get cancelled => $composableBuilder(
    column: $table.cancelled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get assigneeUserId => $composableBuilder(
    column: $table.assigneeUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assigneeUserName => $composableBuilder(
    column: $table.assigneeUserName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fixedTimezone => $composableBuilder(
    column: $table.fixedTimezone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatParentTaskId => $composableBuilder(
    column: $table.repeatParentTaskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatRuleId => $composableBuilder(
    column: $table.repeatRuleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get repeatOccurrenceAt => $composableBuilder(
    column: $table.repeatOccurrenceAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoTasksTable> {
  $$TodoTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => column);

  GeneratedColumn<String> get parentTaskId => $composableBuilder(
    column: $table.parentTaskId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get cancelled =>
      $composableBuilder(column: $table.cancelled, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<int> get assigneeUserId => $composableBuilder(
    column: $table.assigneeUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assigneeUserName => $composableBuilder(
    column: $table.assigneeUserName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<bool> get allDay =>
      $composableBuilder(column: $table.allDay, builder: (column) => column);

  GeneratedColumn<String> get timeZone =>
      $composableBuilder(column: $table.timeZone, builder: (column) => column);

  GeneratedColumn<bool> get fixedTimezone => $composableBuilder(
    column: $table.fixedTimezone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get repeatParentTaskId => $composableBuilder(
    column: $table.repeatParentTaskId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get repeatRuleId => $composableBuilder(
    column: $table.repeatRuleId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get repeatOccurrenceAt => $composableBuilder(
    column: $table.repeatOccurrenceAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TodoTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoTasksTable,
          TodoTask,
          $$TodoTasksTableFilterComposer,
          $$TodoTasksTableOrderingComposer,
          $$TodoTasksTableAnnotationComposer,
          $$TodoTasksTableCreateCompanionBuilder,
          $$TodoTasksTableUpdateCompanionBuilder,
          (TodoTask, BaseReferences<_$AppDatabase, $TodoTasksTable, TodoTask>),
          TodoTask,
          PrefetchHooks Function()
        > {
  $$TodoTasksTableTableManager(_$AppDatabase db, $TodoTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> listId = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<String?> parentTaskId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<bool> cancelled = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<int?> assigneeUserId = const Value.absent(),
                Value<String?> assigneeUserName = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime?> startAt = const Value.absent(),
                Value<DateTime?> endAt = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                Value<String?> timeZone = const Value.absent(),
                Value<bool> fixedTimezone = const Value.absent(),
                Value<String?> repeatParentTaskId = const Value.absent(),
                Value<String?> repeatRuleId = const Value.absent(),
                Value<DateTime?> repeatOccurrenceAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoTasksCompanion(
                id: id,
                serverId: serverId,
                listId: listId,
                sectionId: sectionId,
                parentTaskId: parentTaskId,
                title: title,
                description: description,
                completed: completed,
                completedAt: completedAt,
                cancelled: cancelled,
                priority: priority,
                isPinned: isPinned,
                assigneeUserId: assigneeUserId,
                assigneeUserName: assigneeUserName,
                sortOrder: sortOrder,
                startAt: startAt,
                endAt: endAt,
                dueAt: dueAt,
                allDay: allDay,
                timeZone: timeZone,
                fixedTimezone: fixedTimezone,
                repeatParentTaskId: repeatParentTaskId,
                repeatRuleId: repeatRuleId,
                repeatOccurrenceAt: repeatOccurrenceAt,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                required String listId,
                Value<String?> sectionId = const Value.absent(),
                Value<String?> parentTaskId = const Value.absent(),
                required String title,
                Value<String?> description = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<bool> cancelled = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<int?> assigneeUserId = const Value.absent(),
                Value<String?> assigneeUserName = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime?> startAt = const Value.absent(),
                Value<DateTime?> endAt = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                Value<String?> timeZone = const Value.absent(),
                Value<bool> fixedTimezone = const Value.absent(),
                Value<String?> repeatParentTaskId = const Value.absent(),
                Value<String?> repeatRuleId = const Value.absent(),
                Value<DateTime?> repeatOccurrenceAt = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TodoTasksCompanion.insert(
                id: id,
                serverId: serverId,
                listId: listId,
                sectionId: sectionId,
                parentTaskId: parentTaskId,
                title: title,
                description: description,
                completed: completed,
                completedAt: completedAt,
                cancelled: cancelled,
                priority: priority,
                isPinned: isPinned,
                assigneeUserId: assigneeUserId,
                assigneeUserName: assigneeUserName,
                sortOrder: sortOrder,
                startAt: startAt,
                endAt: endAt,
                dueAt: dueAt,
                allDay: allDay,
                timeZone: timeZone,
                fixedTimezone: fixedTimezone,
                repeatParentTaskId: repeatParentTaskId,
                repeatRuleId: repeatRuleId,
                repeatOccurrenceAt: repeatOccurrenceAt,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoTasksTable,
      TodoTask,
      $$TodoTasksTableFilterComposer,
      $$TodoTasksTableOrderingComposer,
      $$TodoTasksTableAnnotationComposer,
      $$TodoTasksTableCreateCompanionBuilder,
      $$TodoTasksTableUpdateCompanionBuilder,
      (TodoTask, BaseReferences<_$AppDatabase, $TodoTasksTable, TodoTask>),
      TodoTask,
      PrefetchHooks Function()
    >;
typedef $$TodoFoldersTableCreateCompanionBuilder =
    TodoFoldersCompanion Function({
      required String id,
      Value<int?> serverId,
      Value<String?> parentId,
      required String name,
      Value<int> sortOrder,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$TodoFoldersTableUpdateCompanionBuilder =
    TodoFoldersCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<String?> parentId,
      Value<String> name,
      Value<int> sortOrder,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$TodoFoldersTableFilterComposer
    extends Composer<_$AppDatabase, $TodoFoldersTable> {
  $$TodoFoldersTableFilterComposer({
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

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoFoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoFoldersTable> {
  $$TodoFoldersTableOrderingComposer({
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

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoFoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoFoldersTable> {
  $$TodoFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TodoFoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoFoldersTable,
          TodoFolder,
          $$TodoFoldersTableFilterComposer,
          $$TodoFoldersTableOrderingComposer,
          $$TodoFoldersTableAnnotationComposer,
          $$TodoFoldersTableCreateCompanionBuilder,
          $$TodoFoldersTableUpdateCompanionBuilder,
          (
            TodoFolder,
            BaseReferences<_$AppDatabase, $TodoFoldersTable, TodoFolder>,
          ),
          TodoFolder,
          PrefetchHooks Function()
        > {
  $$TodoFoldersTableTableManager(_$AppDatabase db, $TodoFoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoFoldersCompanion(
                id: id,
                serverId: serverId,
                parentId: parentId,
                name: name,
                sortOrder: sortOrder,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                required String name,
                Value<int> sortOrder = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TodoFoldersCompanion.insert(
                id: id,
                serverId: serverId,
                parentId: parentId,
                name: name,
                sortOrder: sortOrder,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoFoldersTable,
      TodoFolder,
      $$TodoFoldersTableFilterComposer,
      $$TodoFoldersTableOrderingComposer,
      $$TodoFoldersTableAnnotationComposer,
      $$TodoFoldersTableCreateCompanionBuilder,
      $$TodoFoldersTableUpdateCompanionBuilder,
      (
        TodoFolder,
        BaseReferences<_$AppDatabase, $TodoFoldersTable, TodoFolder>,
      ),
      TodoFolder,
      PrefetchHooks Function()
    >;
typedef $$TodoTagsTableCreateCompanionBuilder =
    TodoTagsCompanion Function({
      required String id,
      Value<int?> serverId,
      Value<String?> parentId,
      required String name,
      Value<String?> color,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$TodoTagsTableUpdateCompanionBuilder =
    TodoTagsCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<String?> parentId,
      Value<String> name,
      Value<String?> color,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$TodoTagsTableFilterComposer
    extends Composer<_$AppDatabase, $TodoTagsTable> {
  $$TodoTagsTableFilterComposer({
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

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoTagsTable> {
  $$TodoTagsTableOrderingComposer({
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

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoTagsTable> {
  $$TodoTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TodoTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoTagsTable,
          TodoTag,
          $$TodoTagsTableFilterComposer,
          $$TodoTagsTableOrderingComposer,
          $$TodoTagsTableAnnotationComposer,
          $$TodoTagsTableCreateCompanionBuilder,
          $$TodoTagsTableUpdateCompanionBuilder,
          (TodoTag, BaseReferences<_$AppDatabase, $TodoTagsTable, TodoTag>),
          TodoTag,
          PrefetchHooks Function()
        > {
  $$TodoTagsTableTableManager(_$AppDatabase db, $TodoTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoTagsCompanion(
                id: id,
                serverId: serverId,
                parentId: parentId,
                name: name,
                color: color,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                required String name,
                Value<String?> color = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TodoTagsCompanion.insert(
                id: id,
                serverId: serverId,
                parentId: parentId,
                name: name,
                color: color,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoTagsTable,
      TodoTag,
      $$TodoTagsTableFilterComposer,
      $$TodoTagsTableOrderingComposer,
      $$TodoTagsTableAnnotationComposer,
      $$TodoTagsTableCreateCompanionBuilder,
      $$TodoTagsTableUpdateCompanionBuilder,
      (TodoTag, BaseReferences<_$AppDatabase, $TodoTagsTable, TodoTag>),
      TodoTag,
      PrefetchHooks Function()
    >;
typedef $$TodoTaskTagsTableCreateCompanionBuilder =
    TodoTaskTagsCompanion Function({
      required String taskId,
      required String tagId,
      Value<int?> serverId,
      Value<int> rowid,
    });
typedef $$TodoTaskTagsTableUpdateCompanionBuilder =
    TodoTaskTagsCompanion Function({
      Value<String> taskId,
      Value<String> tagId,
      Value<int?> serverId,
      Value<int> rowid,
    });

class $$TodoTaskTagsTableFilterComposer
    extends Composer<_$AppDatabase, $TodoTaskTagsTable> {
  $$TodoTaskTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoTaskTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoTaskTagsTable> {
  $$TodoTaskTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoTaskTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoTaskTagsTable> {
  $$TodoTaskTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);
}

class $$TodoTaskTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoTaskTagsTable,
          TodoTaskTag,
          $$TodoTaskTagsTableFilterComposer,
          $$TodoTaskTagsTableOrderingComposer,
          $$TodoTaskTagsTableAnnotationComposer,
          $$TodoTaskTagsTableCreateCompanionBuilder,
          $$TodoTaskTagsTableUpdateCompanionBuilder,
          (
            TodoTaskTag,
            BaseReferences<_$AppDatabase, $TodoTaskTagsTable, TodoTaskTag>,
          ),
          TodoTaskTag,
          PrefetchHooks Function()
        > {
  $$TodoTaskTagsTableTableManager(_$AppDatabase db, $TodoTaskTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoTaskTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoTaskTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoTaskTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> taskId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoTaskTagsCompanion(
                taskId: taskId,
                tagId: tagId,
                serverId: serverId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String taskId,
                required String tagId,
                Value<int?> serverId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoTaskTagsCompanion.insert(
                taskId: taskId,
                tagId: tagId,
                serverId: serverId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoTaskTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoTaskTagsTable,
      TodoTaskTag,
      $$TodoTaskTagsTableFilterComposer,
      $$TodoTaskTagsTableOrderingComposer,
      $$TodoTaskTagsTableAnnotationComposer,
      $$TodoTaskTagsTableCreateCompanionBuilder,
      $$TodoTaskTagsTableUpdateCompanionBuilder,
      (
        TodoTaskTag,
        BaseReferences<_$AppDatabase, $TodoTaskTagsTable, TodoTaskTag>,
      ),
      TodoTaskTag,
      PrefetchHooks Function()
    >;
typedef $$TodoChecklistItemsTableCreateCompanionBuilder =
    TodoChecklistItemsCompanion Function({
      required String id,
      Value<int?> serverId,
      required String taskId,
      required String title,
      Value<bool> completed,
      Value<int> sortOrder,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$TodoChecklistItemsTableUpdateCompanionBuilder =
    TodoChecklistItemsCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<String> taskId,
      Value<String> title,
      Value<bool> completed,
      Value<int> sortOrder,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$TodoChecklistItemsTableFilterComposer
    extends Composer<_$AppDatabase, $TodoChecklistItemsTable> {
  $$TodoChecklistItemsTableFilterComposer({
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

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoChecklistItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoChecklistItemsTable> {
  $$TodoChecklistItemsTableOrderingComposer({
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

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoChecklistItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoChecklistItemsTable> {
  $$TodoChecklistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TodoChecklistItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoChecklistItemsTable,
          TodoChecklistItem,
          $$TodoChecklistItemsTableFilterComposer,
          $$TodoChecklistItemsTableOrderingComposer,
          $$TodoChecklistItemsTableAnnotationComposer,
          $$TodoChecklistItemsTableCreateCompanionBuilder,
          $$TodoChecklistItemsTableUpdateCompanionBuilder,
          (
            TodoChecklistItem,
            BaseReferences<
              _$AppDatabase,
              $TodoChecklistItemsTable,
              TodoChecklistItem
            >,
          ),
          TodoChecklistItem,
          PrefetchHooks Function()
        > {
  $$TodoChecklistItemsTableTableManager(
    _$AppDatabase db,
    $TodoChecklistItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoChecklistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoChecklistItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoChecklistItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoChecklistItemsCompanion(
                id: id,
                serverId: serverId,
                taskId: taskId,
                title: title,
                completed: completed,
                sortOrder: sortOrder,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                required String taskId,
                required String title,
                Value<bool> completed = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TodoChecklistItemsCompanion.insert(
                id: id,
                serverId: serverId,
                taskId: taskId,
                title: title,
                completed: completed,
                sortOrder: sortOrder,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoChecklistItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoChecklistItemsTable,
      TodoChecklistItem,
      $$TodoChecklistItemsTableFilterComposer,
      $$TodoChecklistItemsTableOrderingComposer,
      $$TodoChecklistItemsTableAnnotationComposer,
      $$TodoChecklistItemsTableCreateCompanionBuilder,
      $$TodoChecklistItemsTableUpdateCompanionBuilder,
      (
        TodoChecklistItem,
        BaseReferences<
          _$AppDatabase,
          $TodoChecklistItemsTable,
          TodoChecklistItem
        >,
      ),
      TodoChecklistItem,
      PrefetchHooks Function()
    >;
typedef $$TodoAttachmentsTableCreateCompanionBuilder =
    TodoAttachmentsCompanion Function({
      required String id,
      Value<int?> serverId,
      required String taskId,
      required String name,
      Value<String?> localPath,
      Value<String?> remoteUrl,
      required String mimeType,
      required int size,
      Value<String> status,
      Value<String?> error,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$TodoAttachmentsTableUpdateCompanionBuilder =
    TodoAttachmentsCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<String> taskId,
      Value<String> name,
      Value<String?> localPath,
      Value<String?> remoteUrl,
      Value<String> mimeType,
      Value<int> size,
      Value<String> status,
      Value<String?> error,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$TodoAttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $TodoAttachmentsTable> {
  $$TodoAttachmentsTableFilterComposer({
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

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoAttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoAttachmentsTable> {
  $$TodoAttachmentsTableOrderingComposer({
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

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoAttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoAttachmentsTable> {
  $$TodoAttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get remoteUrl =>
      $composableBuilder(column: $table.remoteUrl, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TodoAttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoAttachmentsTable,
          TodoAttachment,
          $$TodoAttachmentsTableFilterComposer,
          $$TodoAttachmentsTableOrderingComposer,
          $$TodoAttachmentsTableAnnotationComposer,
          $$TodoAttachmentsTableCreateCompanionBuilder,
          $$TodoAttachmentsTableUpdateCompanionBuilder,
          (
            TodoAttachment,
            BaseReferences<
              _$AppDatabase,
              $TodoAttachmentsTable,
              TodoAttachment
            >,
          ),
          TodoAttachment,
          PrefetchHooks Function()
        > {
  $$TodoAttachmentsTableTableManager(
    _$AppDatabase db,
    $TodoAttachmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoAttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoAttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoAttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> remoteUrl = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoAttachmentsCompanion(
                id: id,
                serverId: serverId,
                taskId: taskId,
                name: name,
                localPath: localPath,
                remoteUrl: remoteUrl,
                mimeType: mimeType,
                size: size,
                status: status,
                error: error,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                required String taskId,
                required String name,
                Value<String?> localPath = const Value.absent(),
                Value<String?> remoteUrl = const Value.absent(),
                required String mimeType,
                required int size,
                Value<String> status = const Value.absent(),
                Value<String?> error = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TodoAttachmentsCompanion.insert(
                id: id,
                serverId: serverId,
                taskId: taskId,
                name: name,
                localPath: localPath,
                remoteUrl: remoteUrl,
                mimeType: mimeType,
                size: size,
                status: status,
                error: error,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoAttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoAttachmentsTable,
      TodoAttachment,
      $$TodoAttachmentsTableFilterComposer,
      $$TodoAttachmentsTableOrderingComposer,
      $$TodoAttachmentsTableAnnotationComposer,
      $$TodoAttachmentsTableCreateCompanionBuilder,
      $$TodoAttachmentsTableUpdateCompanionBuilder,
      (
        TodoAttachment,
        BaseReferences<_$AppDatabase, $TodoAttachmentsTable, TodoAttachment>,
      ),
      TodoAttachment,
      PrefetchHooks Function()
    >;
typedef $$TodoActivitiesTableCreateCompanionBuilder =
    TodoActivitiesCompanion Function({
      Value<int> serverId,
      required int taskServerId,
      Value<int?> actorUserId,
      Value<String?> actorUserName,
      required String action,
      Value<String?> detail,
      required DateTime occurredAt,
    });
typedef $$TodoActivitiesTableUpdateCompanionBuilder =
    TodoActivitiesCompanion Function({
      Value<int> serverId,
      Value<int> taskServerId,
      Value<int?> actorUserId,
      Value<String?> actorUserName,
      Value<String> action,
      Value<String?> detail,
      Value<DateTime> occurredAt,
    });

class $$TodoActivitiesTableFilterComposer
    extends Composer<_$AppDatabase, $TodoActivitiesTable> {
  $$TodoActivitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taskServerId => $composableBuilder(
    column: $table.taskServerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorUserName => $composableBuilder(
    column: $table.actorUserName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoActivitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoActivitiesTable> {
  $$TodoActivitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taskServerId => $composableBuilder(
    column: $table.taskServerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorUserName => $composableBuilder(
    column: $table.actorUserName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoActivitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoActivitiesTable> {
  $$TodoActivitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get taskServerId => $composableBuilder(
    column: $table.taskServerId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actorUserName => $composableBuilder(
    column: $table.actorUserName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );
}

class $$TodoActivitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoActivitiesTable,
          TodoActivity,
          $$TodoActivitiesTableFilterComposer,
          $$TodoActivitiesTableOrderingComposer,
          $$TodoActivitiesTableAnnotationComposer,
          $$TodoActivitiesTableCreateCompanionBuilder,
          $$TodoActivitiesTableUpdateCompanionBuilder,
          (
            TodoActivity,
            BaseReferences<_$AppDatabase, $TodoActivitiesTable, TodoActivity>,
          ),
          TodoActivity,
          PrefetchHooks Function()
        > {
  $$TodoActivitiesTableTableManager(
    _$AppDatabase db,
    $TodoActivitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoActivitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoActivitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoActivitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> serverId = const Value.absent(),
                Value<int> taskServerId = const Value.absent(),
                Value<int?> actorUserId = const Value.absent(),
                Value<String?> actorUserName = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
              }) => TodoActivitiesCompanion(
                serverId: serverId,
                taskServerId: taskServerId,
                actorUserId: actorUserId,
                actorUserName: actorUserName,
                action: action,
                detail: detail,
                occurredAt: occurredAt,
              ),
          createCompanionCallback:
              ({
                Value<int> serverId = const Value.absent(),
                required int taskServerId,
                Value<int?> actorUserId = const Value.absent(),
                Value<String?> actorUserName = const Value.absent(),
                required String action,
                Value<String?> detail = const Value.absent(),
                required DateTime occurredAt,
              }) => TodoActivitiesCompanion.insert(
                serverId: serverId,
                taskServerId: taskServerId,
                actorUserId: actorUserId,
                actorUserName: actorUserName,
                action: action,
                detail: detail,
                occurredAt: occurredAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoActivitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoActivitiesTable,
      TodoActivity,
      $$TodoActivitiesTableFilterComposer,
      $$TodoActivitiesTableOrderingComposer,
      $$TodoActivitiesTableAnnotationComposer,
      $$TodoActivitiesTableCreateCompanionBuilder,
      $$TodoActivitiesTableUpdateCompanionBuilder,
      (
        TodoActivity,
        BaseReferences<_$AppDatabase, $TodoActivitiesTable, TodoActivity>,
      ),
      TodoActivity,
      PrefetchHooks Function()
    >;
typedef $$TodoTemplatesTableCreateCompanionBuilder =
    TodoTemplatesCompanion Function({
      required String id,
      Value<int?> serverId,
      required String name,
      required String contentJson,
      Value<String> status,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$TodoTemplatesTableUpdateCompanionBuilder =
    TodoTemplatesCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<String> name,
      Value<String> contentJson,
      Value<String> status,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$TodoTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $TodoTemplatesTable> {
  $$TodoTemplatesTableFilterComposer({
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

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentJson => $composableBuilder(
    column: $table.contentJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoTemplatesTable> {
  $$TodoTemplatesTableOrderingComposer({
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

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentJson => $composableBuilder(
    column: $table.contentJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoTemplatesTable> {
  $$TodoTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get contentJson => $composableBuilder(
    column: $table.contentJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TodoTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoTemplatesTable,
          TodoTemplate,
          $$TodoTemplatesTableFilterComposer,
          $$TodoTemplatesTableOrderingComposer,
          $$TodoTemplatesTableAnnotationComposer,
          $$TodoTemplatesTableCreateCompanionBuilder,
          $$TodoTemplatesTableUpdateCompanionBuilder,
          (
            TodoTemplate,
            BaseReferences<_$AppDatabase, $TodoTemplatesTable, TodoTemplate>,
          ),
          TodoTemplate,
          PrefetchHooks Function()
        > {
  $$TodoTemplatesTableTableManager(_$AppDatabase db, $TodoTemplatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> contentJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoTemplatesCompanion(
                id: id,
                serverId: serverId,
                name: name,
                contentJson: contentJson,
                status: status,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                required String name,
                required String contentJson,
                Value<String> status = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TodoTemplatesCompanion.insert(
                id: id,
                serverId: serverId,
                name: name,
                contentJson: contentJson,
                status: status,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoTemplatesTable,
      TodoTemplate,
      $$TodoTemplatesTableFilterComposer,
      $$TodoTemplatesTableOrderingComposer,
      $$TodoTemplatesTableAnnotationComposer,
      $$TodoTemplatesTableCreateCompanionBuilder,
      $$TodoTemplatesTableUpdateCompanionBuilder,
      (
        TodoTemplate,
        BaseReferences<_$AppDatabase, $TodoTemplatesTable, TodoTemplate>,
      ),
      TodoTemplate,
      PrefetchHooks Function()
    >;
typedef $$TodoRemindersTableCreateCompanionBuilder =
    TodoRemindersCompanion Function({
      required String id,
      Value<int?> serverId,
      required String taskId,
      required DateTime remindAt,
      Value<String> anchorType,
      Value<int?> offsetMinutes,
      Value<String> status,
      Value<DateTime?> firedAt,
      Value<bool> persistent,
      Value<int?> intervalMinutes,
      Value<String?> timeZone,
      Value<bool> fixedTimezone,
      Value<String?> clientMutationId,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$TodoRemindersTableUpdateCompanionBuilder =
    TodoRemindersCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<String> taskId,
      Value<DateTime> remindAt,
      Value<String> anchorType,
      Value<int?> offsetMinutes,
      Value<String> status,
      Value<DateTime?> firedAt,
      Value<bool> persistent,
      Value<int?> intervalMinutes,
      Value<String?> timeZone,
      Value<bool> fixedTimezone,
      Value<String?> clientMutationId,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$TodoRemindersTableFilterComposer
    extends Composer<_$AppDatabase, $TodoRemindersTable> {
  $$TodoRemindersTableFilterComposer({
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

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get anchorType => $composableBuilder(
    column: $table.anchorType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offsetMinutes => $composableBuilder(
    column: $table.offsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firedAt => $composableBuilder(
    column: $table.firedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get persistent => $composableBuilder(
    column: $table.persistent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalMinutes => $composableBuilder(
    column: $table.intervalMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fixedTimezone => $composableBuilder(
    column: $table.fixedTimezone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientMutationId => $composableBuilder(
    column: $table.clientMutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoRemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoRemindersTable> {
  $$TodoRemindersTableOrderingComposer({
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

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get anchorType => $composableBuilder(
    column: $table.anchorType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offsetMinutes => $composableBuilder(
    column: $table.offsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firedAt => $composableBuilder(
    column: $table.firedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get persistent => $composableBuilder(
    column: $table.persistent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalMinutes => $composableBuilder(
    column: $table.intervalMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fixedTimezone => $composableBuilder(
    column: $table.fixedTimezone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientMutationId => $composableBuilder(
    column: $table.clientMutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoRemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoRemindersTable> {
  $$TodoRemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<DateTime> get remindAt =>
      $composableBuilder(column: $table.remindAt, builder: (column) => column);

  GeneratedColumn<String> get anchorType => $composableBuilder(
    column: $table.anchorType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get offsetMinutes => $composableBuilder(
    column: $table.offsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get firedAt =>
      $composableBuilder(column: $table.firedAt, builder: (column) => column);

  GeneratedColumn<bool> get persistent => $composableBuilder(
    column: $table.persistent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get intervalMinutes => $composableBuilder(
    column: $table.intervalMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timeZone =>
      $composableBuilder(column: $table.timeZone, builder: (column) => column);

  GeneratedColumn<bool> get fixedTimezone => $composableBuilder(
    column: $table.fixedTimezone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clientMutationId => $composableBuilder(
    column: $table.clientMutationId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TodoRemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoRemindersTable,
          TodoReminder,
          $$TodoRemindersTableFilterComposer,
          $$TodoRemindersTableOrderingComposer,
          $$TodoRemindersTableAnnotationComposer,
          $$TodoRemindersTableCreateCompanionBuilder,
          $$TodoRemindersTableUpdateCompanionBuilder,
          (
            TodoReminder,
            BaseReferences<_$AppDatabase, $TodoRemindersTable, TodoReminder>,
          ),
          TodoReminder,
          PrefetchHooks Function()
        > {
  $$TodoRemindersTableTableManager(_$AppDatabase db, $TodoRemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoRemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoRemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoRemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<DateTime> remindAt = const Value.absent(),
                Value<String> anchorType = const Value.absent(),
                Value<int?> offsetMinutes = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> firedAt = const Value.absent(),
                Value<bool> persistent = const Value.absent(),
                Value<int?> intervalMinutes = const Value.absent(),
                Value<String?> timeZone = const Value.absent(),
                Value<bool> fixedTimezone = const Value.absent(),
                Value<String?> clientMutationId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoRemindersCompanion(
                id: id,
                serverId: serverId,
                taskId: taskId,
                remindAt: remindAt,
                anchorType: anchorType,
                offsetMinutes: offsetMinutes,
                status: status,
                firedAt: firedAt,
                persistent: persistent,
                intervalMinutes: intervalMinutes,
                timeZone: timeZone,
                fixedTimezone: fixedTimezone,
                clientMutationId: clientMutationId,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                required String taskId,
                required DateTime remindAt,
                Value<String> anchorType = const Value.absent(),
                Value<int?> offsetMinutes = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> firedAt = const Value.absent(),
                Value<bool> persistent = const Value.absent(),
                Value<int?> intervalMinutes = const Value.absent(),
                Value<String?> timeZone = const Value.absent(),
                Value<bool> fixedTimezone = const Value.absent(),
                Value<String?> clientMutationId = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TodoRemindersCompanion.insert(
                id: id,
                serverId: serverId,
                taskId: taskId,
                remindAt: remindAt,
                anchorType: anchorType,
                offsetMinutes: offsetMinutes,
                status: status,
                firedAt: firedAt,
                persistent: persistent,
                intervalMinutes: intervalMinutes,
                timeZone: timeZone,
                fixedTimezone: fixedTimezone,
                clientMutationId: clientMutationId,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoRemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoRemindersTable,
      TodoReminder,
      $$TodoRemindersTableFilterComposer,
      $$TodoRemindersTableOrderingComposer,
      $$TodoRemindersTableAnnotationComposer,
      $$TodoRemindersTableCreateCompanionBuilder,
      $$TodoRemindersTableUpdateCompanionBuilder,
      (
        TodoReminder,
        BaseReferences<_$AppDatabase, $TodoRemindersTable, TodoReminder>,
      ),
      TodoReminder,
      PrefetchHooks Function()
    >;
typedef $$TodoRepeatRulesTableCreateCompanionBuilder =
    TodoRepeatRulesCompanion Function({
      required String id,
      Value<int?> serverId,
      required String taskId,
      required String freq,
      Value<int> interval,
      Value<String?> byDay,
      Value<int?> monthDay,
      Value<DateTime?> startAt,
      Value<DateTime?> until,
      Value<int?> countLimit,
      Value<bool> enabled,
      Value<String> repeatMode,
      Value<String?> timeZone,
      Value<String?> selectedDatesJson,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$TodoRepeatRulesTableUpdateCompanionBuilder =
    TodoRepeatRulesCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<String> taskId,
      Value<String> freq,
      Value<int> interval,
      Value<String?> byDay,
      Value<int?> monthDay,
      Value<DateTime?> startAt,
      Value<DateTime?> until,
      Value<int?> countLimit,
      Value<bool> enabled,
      Value<String> repeatMode,
      Value<String?> timeZone,
      Value<String?> selectedDatesJson,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$TodoRepeatRulesTableFilterComposer
    extends Composer<_$AppDatabase, $TodoRepeatRulesTable> {
  $$TodoRepeatRulesTableFilterComposer({
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

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get freq => $composableBuilder(
    column: $table.freq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get byDay => $composableBuilder(
    column: $table.byDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthDay => $composableBuilder(
    column: $table.monthDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get until => $composableBuilder(
    column: $table.until,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get countLimit => $composableBuilder(
    column: $table.countLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatMode => $composableBuilder(
    column: $table.repeatMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedDatesJson => $composableBuilder(
    column: $table.selectedDatesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoRepeatRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoRepeatRulesTable> {
  $$TodoRepeatRulesTableOrderingComposer({
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

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get freq => $composableBuilder(
    column: $table.freq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get byDay => $composableBuilder(
    column: $table.byDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthDay => $composableBuilder(
    column: $table.monthDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get until => $composableBuilder(
    column: $table.until,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get countLimit => $composableBuilder(
    column: $table.countLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatMode => $composableBuilder(
    column: $table.repeatMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedDatesJson => $composableBuilder(
    column: $table.selectedDatesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoRepeatRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoRepeatRulesTable> {
  $$TodoRepeatRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get freq =>
      $composableBuilder(column: $table.freq, builder: (column) => column);

  GeneratedColumn<int> get interval =>
      $composableBuilder(column: $table.interval, builder: (column) => column);

  GeneratedColumn<String> get byDay =>
      $composableBuilder(column: $table.byDay, builder: (column) => column);

  GeneratedColumn<int> get monthDay =>
      $composableBuilder(column: $table.monthDay, builder: (column) => column);

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<DateTime> get until =>
      $composableBuilder(column: $table.until, builder: (column) => column);

  GeneratedColumn<int> get countLimit => $composableBuilder(
    column: $table.countLimit,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get repeatMode => $composableBuilder(
    column: $table.repeatMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timeZone =>
      $composableBuilder(column: $table.timeZone, builder: (column) => column);

  GeneratedColumn<String> get selectedDatesJson => $composableBuilder(
    column: $table.selectedDatesJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TodoRepeatRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoRepeatRulesTable,
          TodoRepeatRule,
          $$TodoRepeatRulesTableFilterComposer,
          $$TodoRepeatRulesTableOrderingComposer,
          $$TodoRepeatRulesTableAnnotationComposer,
          $$TodoRepeatRulesTableCreateCompanionBuilder,
          $$TodoRepeatRulesTableUpdateCompanionBuilder,
          (
            TodoRepeatRule,
            BaseReferences<
              _$AppDatabase,
              $TodoRepeatRulesTable,
              TodoRepeatRule
            >,
          ),
          TodoRepeatRule,
          PrefetchHooks Function()
        > {
  $$TodoRepeatRulesTableTableManager(
    _$AppDatabase db,
    $TodoRepeatRulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoRepeatRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoRepeatRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoRepeatRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> freq = const Value.absent(),
                Value<int> interval = const Value.absent(),
                Value<String?> byDay = const Value.absent(),
                Value<int?> monthDay = const Value.absent(),
                Value<DateTime?> startAt = const Value.absent(),
                Value<DateTime?> until = const Value.absent(),
                Value<int?> countLimit = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String> repeatMode = const Value.absent(),
                Value<String?> timeZone = const Value.absent(),
                Value<String?> selectedDatesJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoRepeatRulesCompanion(
                id: id,
                serverId: serverId,
                taskId: taskId,
                freq: freq,
                interval: interval,
                byDay: byDay,
                monthDay: monthDay,
                startAt: startAt,
                until: until,
                countLimit: countLimit,
                enabled: enabled,
                repeatMode: repeatMode,
                timeZone: timeZone,
                selectedDatesJson: selectedDatesJson,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                required String taskId,
                required String freq,
                Value<int> interval = const Value.absent(),
                Value<String?> byDay = const Value.absent(),
                Value<int?> monthDay = const Value.absent(),
                Value<DateTime?> startAt = const Value.absent(),
                Value<DateTime?> until = const Value.absent(),
                Value<int?> countLimit = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String> repeatMode = const Value.absent(),
                Value<String?> timeZone = const Value.absent(),
                Value<String?> selectedDatesJson = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TodoRepeatRulesCompanion.insert(
                id: id,
                serverId: serverId,
                taskId: taskId,
                freq: freq,
                interval: interval,
                byDay: byDay,
                monthDay: monthDay,
                startAt: startAt,
                until: until,
                countLimit: countLimit,
                enabled: enabled,
                repeatMode: repeatMode,
                timeZone: timeZone,
                selectedDatesJson: selectedDatesJson,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoRepeatRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoRepeatRulesTable,
      TodoRepeatRule,
      $$TodoRepeatRulesTableFilterComposer,
      $$TodoRepeatRulesTableOrderingComposer,
      $$TodoRepeatRulesTableAnnotationComposer,
      $$TodoRepeatRulesTableCreateCompanionBuilder,
      $$TodoRepeatRulesTableUpdateCompanionBuilder,
      (
        TodoRepeatRule,
        BaseReferences<_$AppDatabase, $TodoRepeatRulesTable, TodoRepeatRule>,
      ),
      TodoRepeatRule,
      PrefetchHooks Function()
    >;
typedef $$TodoRepeatSkipsTableCreateCompanionBuilder =
    TodoRepeatSkipsCompanion Function({
      required String id,
      Value<int?> serverId,
      required String repeatRuleId,
      required String taskId,
      required DateTime occurrenceDate,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$TodoRepeatSkipsTableUpdateCompanionBuilder =
    TodoRepeatSkipsCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<String> repeatRuleId,
      Value<String> taskId,
      Value<DateTime> occurrenceDate,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$TodoRepeatSkipsTableFilterComposer
    extends Composer<_$AppDatabase, $TodoRepeatSkipsTable> {
  $$TodoRepeatSkipsTableFilterComposer({
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

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatRuleId => $composableBuilder(
    column: $table.repeatRuleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurrenceDate => $composableBuilder(
    column: $table.occurrenceDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoRepeatSkipsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoRepeatSkipsTable> {
  $$TodoRepeatSkipsTableOrderingComposer({
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

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatRuleId => $composableBuilder(
    column: $table.repeatRuleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurrenceDate => $composableBuilder(
    column: $table.occurrenceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoRepeatSkipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoRepeatSkipsTable> {
  $$TodoRepeatSkipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get repeatRuleId => $composableBuilder(
    column: $table.repeatRuleId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<DateTime> get occurrenceDate => $composableBuilder(
    column: $table.occurrenceDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TodoRepeatSkipsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoRepeatSkipsTable,
          TodoRepeatSkip,
          $$TodoRepeatSkipsTableFilterComposer,
          $$TodoRepeatSkipsTableOrderingComposer,
          $$TodoRepeatSkipsTableAnnotationComposer,
          $$TodoRepeatSkipsTableCreateCompanionBuilder,
          $$TodoRepeatSkipsTableUpdateCompanionBuilder,
          (
            TodoRepeatSkip,
            BaseReferences<
              _$AppDatabase,
              $TodoRepeatSkipsTable,
              TodoRepeatSkip
            >,
          ),
          TodoRepeatSkip,
          PrefetchHooks Function()
        > {
  $$TodoRepeatSkipsTableTableManager(
    _$AppDatabase db,
    $TodoRepeatSkipsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoRepeatSkipsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoRepeatSkipsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoRepeatSkipsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> repeatRuleId = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<DateTime> occurrenceDate = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoRepeatSkipsCompanion(
                id: id,
                serverId: serverId,
                repeatRuleId: repeatRuleId,
                taskId: taskId,
                occurrenceDate: occurrenceDate,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                required String repeatRuleId,
                required String taskId,
                required DateTime occurrenceDate,
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TodoRepeatSkipsCompanion.insert(
                id: id,
                serverId: serverId,
                repeatRuleId: repeatRuleId,
                taskId: taskId,
                occurrenceDate: occurrenceDate,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoRepeatSkipsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoRepeatSkipsTable,
      TodoRepeatSkip,
      $$TodoRepeatSkipsTableFilterComposer,
      $$TodoRepeatSkipsTableOrderingComposer,
      $$TodoRepeatSkipsTableAnnotationComposer,
      $$TodoRepeatSkipsTableCreateCompanionBuilder,
      $$TodoRepeatSkipsTableUpdateCompanionBuilder,
      (
        TodoRepeatSkip,
        BaseReferences<_$AppDatabase, $TodoRepeatSkipsTable, TodoRepeatSkip>,
      ),
      TodoRepeatSkip,
      PrefetchHooks Function()
    >;
typedef $$TodoViewPreferencesTableCreateCompanionBuilder =
    TodoViewPreferencesCompanion Function({
      required String id,
      Value<int?> serverId,
      required String sourceType,
      required String sourceKey,
      required String valueJson,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$TodoViewPreferencesTableUpdateCompanionBuilder =
    TodoViewPreferencesCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<String> sourceType,
      Value<String> sourceKey,
      Value<String> valueJson,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$TodoViewPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $TodoViewPreferencesTable> {
  $$TodoViewPreferencesTableFilterComposer({
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

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoViewPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoViewPreferencesTable> {
  $$TodoViewPreferencesTableOrderingComposer({
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

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoViewPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoViewPreferencesTable> {
  $$TodoViewPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TodoViewPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoViewPreferencesTable,
          TodoViewPreference,
          $$TodoViewPreferencesTableFilterComposer,
          $$TodoViewPreferencesTableOrderingComposer,
          $$TodoViewPreferencesTableAnnotationComposer,
          $$TodoViewPreferencesTableCreateCompanionBuilder,
          $$TodoViewPreferencesTableUpdateCompanionBuilder,
          (
            TodoViewPreference,
            BaseReferences<
              _$AppDatabase,
              $TodoViewPreferencesTable,
              TodoViewPreference
            >,
          ),
          TodoViewPreference,
          PrefetchHooks Function()
        > {
  $$TodoViewPreferencesTableTableManager(
    _$AppDatabase db,
    $TodoViewPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoViewPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoViewPreferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TodoViewPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String> sourceKey = const Value.absent(),
                Value<String> valueJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoViewPreferencesCompanion(
                id: id,
                serverId: serverId,
                sourceType: sourceType,
                sourceKey: sourceKey,
                valueJson: valueJson,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                required String sourceType,
                required String sourceKey,
                required String valueJson,
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TodoViewPreferencesCompanion.insert(
                id: id,
                serverId: serverId,
                sourceType: sourceType,
                sourceKey: sourceKey,
                valueJson: valueJson,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoViewPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoViewPreferencesTable,
      TodoViewPreference,
      $$TodoViewPreferencesTableFilterComposer,
      $$TodoViewPreferencesTableOrderingComposer,
      $$TodoViewPreferencesTableAnnotationComposer,
      $$TodoViewPreferencesTableCreateCompanionBuilder,
      $$TodoViewPreferencesTableUpdateCompanionBuilder,
      (
        TodoViewPreference,
        BaseReferences<
          _$AppDatabase,
          $TodoViewPreferencesTable,
          TodoViewPreference
        >,
      ),
      TodoViewPreference,
      PrefetchHooks Function()
    >;
typedef $$TodoBoardPreferencesTableCreateCompanionBuilder =
    TodoBoardPreferencesCompanion Function({
      required String id,
      Value<int?> serverId,
      required String listId,
      required String groupDimension,
      Value<String?> columnsJson,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$TodoBoardPreferencesTableUpdateCompanionBuilder =
    TodoBoardPreferencesCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<String> listId,
      Value<String> groupDimension,
      Value<String?> columnsJson,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$TodoBoardPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $TodoBoardPreferencesTable> {
  $$TodoBoardPreferencesTableFilterComposer({
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

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupDimension => $composableBuilder(
    column: $table.groupDimension,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get columnsJson => $composableBuilder(
    column: $table.columnsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoBoardPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoBoardPreferencesTable> {
  $$TodoBoardPreferencesTableOrderingComposer({
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

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupDimension => $composableBuilder(
    column: $table.groupDimension,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get columnsJson => $composableBuilder(
    column: $table.columnsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoBoardPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoBoardPreferencesTable> {
  $$TodoBoardPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<String> get groupDimension => $composableBuilder(
    column: $table.groupDimension,
    builder: (column) => column,
  );

  GeneratedColumn<String> get columnsJson => $composableBuilder(
    column: $table.columnsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TodoBoardPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoBoardPreferencesTable,
          TodoBoardPreference,
          $$TodoBoardPreferencesTableFilterComposer,
          $$TodoBoardPreferencesTableOrderingComposer,
          $$TodoBoardPreferencesTableAnnotationComposer,
          $$TodoBoardPreferencesTableCreateCompanionBuilder,
          $$TodoBoardPreferencesTableUpdateCompanionBuilder,
          (
            TodoBoardPreference,
            BaseReferences<
              _$AppDatabase,
              $TodoBoardPreferencesTable,
              TodoBoardPreference
            >,
          ),
          TodoBoardPreference,
          PrefetchHooks Function()
        > {
  $$TodoBoardPreferencesTableTableManager(
    _$AppDatabase db,
    $TodoBoardPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoBoardPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoBoardPreferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TodoBoardPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> listId = const Value.absent(),
                Value<String> groupDimension = const Value.absent(),
                Value<String?> columnsJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoBoardPreferencesCompanion(
                id: id,
                serverId: serverId,
                listId: listId,
                groupDimension: groupDimension,
                columnsJson: columnsJson,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                required String listId,
                required String groupDimension,
                Value<String?> columnsJson = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TodoBoardPreferencesCompanion.insert(
                id: id,
                serverId: serverId,
                listId: listId,
                groupDimension: groupDimension,
                columnsJson: columnsJson,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoBoardPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoBoardPreferencesTable,
      TodoBoardPreference,
      $$TodoBoardPreferencesTableFilterComposer,
      $$TodoBoardPreferencesTableOrderingComposer,
      $$TodoBoardPreferencesTableAnnotationComposer,
      $$TodoBoardPreferencesTableCreateCompanionBuilder,
      $$TodoBoardPreferencesTableUpdateCompanionBuilder,
      (
        TodoBoardPreference,
        BaseReferences<
          _$AppDatabase,
          $TodoBoardPreferencesTable,
          TodoBoardPreference
        >,
      ),
      TodoBoardPreference,
      PrefetchHooks Function()
    >;
typedef $$TodoFiltersTableCreateCompanionBuilder =
    TodoFiltersCompanion Function({
      required String id,
      Value<int?> serverId,
      required String name,
      required String conditionJson,
      Value<String> sortOrdersJson,
      Value<bool> isSmart,
      Value<bool> isPinned,
      Value<int> sortOrder,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$TodoFiltersTableUpdateCompanionBuilder =
    TodoFiltersCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<String> name,
      Value<String> conditionJson,
      Value<String> sortOrdersJson,
      Value<bool> isSmart,
      Value<bool> isPinned,
      Value<int> sortOrder,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$TodoFiltersTableFilterComposer
    extends Composer<_$AppDatabase, $TodoFiltersTable> {
  $$TodoFiltersTableFilterComposer({
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

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conditionJson => $composableBuilder(
    column: $table.conditionJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortOrdersJson => $composableBuilder(
    column: $table.sortOrdersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSmart => $composableBuilder(
    column: $table.isSmart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoFiltersTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoFiltersTable> {
  $$TodoFiltersTableOrderingComposer({
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

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conditionJson => $composableBuilder(
    column: $table.conditionJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortOrdersJson => $composableBuilder(
    column: $table.sortOrdersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSmart => $composableBuilder(
    column: $table.isSmart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoFiltersTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoFiltersTable> {
  $$TodoFiltersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get conditionJson => $composableBuilder(
    column: $table.conditionJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sortOrdersJson => $composableBuilder(
    column: $table.sortOrdersJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSmart =>
      $composableBuilder(column: $table.isSmart, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TodoFiltersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoFiltersTable,
          TodoFilter,
          $$TodoFiltersTableFilterComposer,
          $$TodoFiltersTableOrderingComposer,
          $$TodoFiltersTableAnnotationComposer,
          $$TodoFiltersTableCreateCompanionBuilder,
          $$TodoFiltersTableUpdateCompanionBuilder,
          (
            TodoFilter,
            BaseReferences<_$AppDatabase, $TodoFiltersTable, TodoFilter>,
          ),
          TodoFilter,
          PrefetchHooks Function()
        > {
  $$TodoFiltersTableTableManager(_$AppDatabase db, $TodoFiltersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoFiltersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoFiltersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoFiltersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> conditionJson = const Value.absent(),
                Value<String> sortOrdersJson = const Value.absent(),
                Value<bool> isSmart = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoFiltersCompanion(
                id: id,
                serverId: serverId,
                name: name,
                conditionJson: conditionJson,
                sortOrdersJson: sortOrdersJson,
                isSmart: isSmart,
                isPinned: isPinned,
                sortOrder: sortOrder,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                required String name,
                required String conditionJson,
                Value<String> sortOrdersJson = const Value.absent(),
                Value<bool> isSmart = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TodoFiltersCompanion.insert(
                id: id,
                serverId: serverId,
                name: name,
                conditionJson: conditionJson,
                sortOrdersJson: sortOrdersJson,
                isSmart: isSmart,
                isPinned: isPinned,
                sortOrder: sortOrder,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoFiltersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoFiltersTable,
      TodoFilter,
      $$TodoFiltersTableFilterComposer,
      $$TodoFiltersTableOrderingComposer,
      $$TodoFiltersTableAnnotationComposer,
      $$TodoFiltersTableCreateCompanionBuilder,
      $$TodoFiltersTableUpdateCompanionBuilder,
      (
        TodoFilter,
        BaseReferences<_$AppDatabase, $TodoFiltersTable, TodoFilter>,
      ),
      TodoFilter,
      PrefetchHooks Function()
    >;
typedef $$TodoRecommendationsTableCreateCompanionBuilder =
    TodoRecommendationsCompanion Function({
      Value<int> taskServerId,
      required String title,
      Value<DateTime?> dueAt,
      required String reasonCode,
      required String reason,
      required int score,
      required DateTime refreshedAt,
    });
typedef $$TodoRecommendationsTableUpdateCompanionBuilder =
    TodoRecommendationsCompanion Function({
      Value<int> taskServerId,
      Value<String> title,
      Value<DateTime?> dueAt,
      Value<String> reasonCode,
      Value<String> reason,
      Value<int> score,
      Value<DateTime> refreshedAt,
    });

class $$TodoRecommendationsTableFilterComposer
    extends Composer<_$AppDatabase, $TodoRecommendationsTable> {
  $$TodoRecommendationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get taskServerId => $composableBuilder(
    column: $table.taskServerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasonCode => $composableBuilder(
    column: $table.reasonCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get refreshedAt => $composableBuilder(
    column: $table.refreshedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoRecommendationsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoRecommendationsTable> {
  $$TodoRecommendationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get taskServerId => $composableBuilder(
    column: $table.taskServerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasonCode => $composableBuilder(
    column: $table.reasonCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get refreshedAt => $composableBuilder(
    column: $table.refreshedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoRecommendationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoRecommendationsTable> {
  $$TodoRecommendationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get taskServerId => $composableBuilder(
    column: $table.taskServerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<String> get reasonCode => $composableBuilder(
    column: $table.reasonCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<DateTime> get refreshedAt => $composableBuilder(
    column: $table.refreshedAt,
    builder: (column) => column,
  );
}

class $$TodoRecommendationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoRecommendationsTable,
          TodoRecommendation,
          $$TodoRecommendationsTableFilterComposer,
          $$TodoRecommendationsTableOrderingComposer,
          $$TodoRecommendationsTableAnnotationComposer,
          $$TodoRecommendationsTableCreateCompanionBuilder,
          $$TodoRecommendationsTableUpdateCompanionBuilder,
          (
            TodoRecommendation,
            BaseReferences<
              _$AppDatabase,
              $TodoRecommendationsTable,
              TodoRecommendation
            >,
          ),
          TodoRecommendation,
          PrefetchHooks Function()
        > {
  $$TodoRecommendationsTableTableManager(
    _$AppDatabase db,
    $TodoRecommendationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoRecommendationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoRecommendationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TodoRecommendationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> taskServerId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<String> reasonCode = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<int> score = const Value.absent(),
                Value<DateTime> refreshedAt = const Value.absent(),
              }) => TodoRecommendationsCompanion(
                taskServerId: taskServerId,
                title: title,
                dueAt: dueAt,
                reasonCode: reasonCode,
                reason: reason,
                score: score,
                refreshedAt: refreshedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> taskServerId = const Value.absent(),
                required String title,
                Value<DateTime?> dueAt = const Value.absent(),
                required String reasonCode,
                required String reason,
                required int score,
                required DateTime refreshedAt,
              }) => TodoRecommendationsCompanion.insert(
                taskServerId: taskServerId,
                title: title,
                dueAt: dueAt,
                reasonCode: reasonCode,
                reason: reason,
                score: score,
                refreshedAt: refreshedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoRecommendationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoRecommendationsTable,
      TodoRecommendation,
      $$TodoRecommendationsTableFilterComposer,
      $$TodoRecommendationsTableOrderingComposer,
      $$TodoRecommendationsTableAnnotationComposer,
      $$TodoRecommendationsTableCreateCompanionBuilder,
      $$TodoRecommendationsTableUpdateCompanionBuilder,
      (
        TodoRecommendation,
        BaseReferences<
          _$AppDatabase,
          $TodoRecommendationsTable,
          TodoRecommendation
        >,
      ),
      TodoRecommendation,
      PrefetchHooks Function()
    >;
typedef $$TodoSyncChangesTableCreateCompanionBuilder =
    TodoSyncChangesCompanion Function({
      Value<int> id,
      required String clientMutationId,
      required String entity,
      required String op,
      Value<String?> entityLocalId,
      Value<int?> entityServerId,
      required String payloadJson,
      required DateTime createdAt,
      Value<int> attemptCount,
      Value<DateTime?> nextAttemptAt,
      Value<String> status,
      Value<String?> failureReason,
    });
typedef $$TodoSyncChangesTableUpdateCompanionBuilder =
    TodoSyncChangesCompanion Function({
      Value<int> id,
      Value<String> clientMutationId,
      Value<String> entity,
      Value<String> op,
      Value<String?> entityLocalId,
      Value<int?> entityServerId,
      Value<String> payloadJson,
      Value<DateTime> createdAt,
      Value<int> attemptCount,
      Value<DateTime?> nextAttemptAt,
      Value<String> status,
      Value<String?> failureReason,
    });

class $$TodoSyncChangesTableFilterComposer
    extends Composer<_$AppDatabase, $TodoSyncChangesTable> {
  $$TodoSyncChangesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientMutationId => $composableBuilder(
    column: $table.clientMutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityLocalId => $composableBuilder(
    column: $table.entityLocalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get entityServerId => $composableBuilder(
    column: $table.entityServerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoSyncChangesTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoSyncChangesTable> {
  $$TodoSyncChangesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientMutationId => $composableBuilder(
    column: $table.clientMutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityLocalId => $composableBuilder(
    column: $table.entityLocalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entityServerId => $composableBuilder(
    column: $table.entityServerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoSyncChangesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoSyncChangesTable> {
  $$TodoSyncChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientMutationId => $composableBuilder(
    column: $table.clientMutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get entityLocalId => $composableBuilder(
    column: $table.entityLocalId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get entityServerId => $composableBuilder(
    column: $table.entityServerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => column,
  );
}

class $$TodoSyncChangesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoSyncChangesTable,
          TodoSyncChange,
          $$TodoSyncChangesTableFilterComposer,
          $$TodoSyncChangesTableOrderingComposer,
          $$TodoSyncChangesTableAnnotationComposer,
          $$TodoSyncChangesTableCreateCompanionBuilder,
          $$TodoSyncChangesTableUpdateCompanionBuilder,
          (
            TodoSyncChange,
            BaseReferences<
              _$AppDatabase,
              $TodoSyncChangesTable,
              TodoSyncChange
            >,
          ),
          TodoSyncChange,
          PrefetchHooks Function()
        > {
  $$TodoSyncChangesTableTableManager(
    _$AppDatabase db,
    $TodoSyncChangesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoSyncChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoSyncChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoSyncChangesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientMutationId = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String?> entityLocalId = const Value.absent(),
                Value<int?> entityServerId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> failureReason = const Value.absent(),
              }) => TodoSyncChangesCompanion(
                id: id,
                clientMutationId: clientMutationId,
                entity: entity,
                op: op,
                entityLocalId: entityLocalId,
                entityServerId: entityServerId,
                payloadJson: payloadJson,
                createdAt: createdAt,
                attemptCount: attemptCount,
                nextAttemptAt: nextAttemptAt,
                status: status,
                failureReason: failureReason,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientMutationId,
                required String entity,
                required String op,
                Value<String?> entityLocalId = const Value.absent(),
                Value<int?> entityServerId = const Value.absent(),
                required String payloadJson,
                required DateTime createdAt,
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> failureReason = const Value.absent(),
              }) => TodoSyncChangesCompanion.insert(
                id: id,
                clientMutationId: clientMutationId,
                entity: entity,
                op: op,
                entityLocalId: entityLocalId,
                entityServerId: entityServerId,
                payloadJson: payloadJson,
                createdAt: createdAt,
                attemptCount: attemptCount,
                nextAttemptAt: nextAttemptAt,
                status: status,
                failureReason: failureReason,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoSyncChangesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoSyncChangesTable,
      TodoSyncChange,
      $$TodoSyncChangesTableFilterComposer,
      $$TodoSyncChangesTableOrderingComposer,
      $$TodoSyncChangesTableAnnotationComposer,
      $$TodoSyncChangesTableCreateCompanionBuilder,
      $$TodoSyncChangesTableUpdateCompanionBuilder,
      (
        TodoSyncChange,
        BaseReferences<_$AppDatabase, $TodoSyncChangesTable, TodoSyncChange>,
      ),
      TodoSyncChange,
      PrefetchHooks Function()
    >;
typedef $$TodoSyncCursorTableCreateCompanionBuilder =
    TodoSyncCursorCompanion Function({
      Value<int> id,
      Value<String?> cursor,
      Value<DateTime?> lastSyncAt,
    });
typedef $$TodoSyncCursorTableUpdateCompanionBuilder =
    TodoSyncCursorCompanion Function({
      Value<int> id,
      Value<String?> cursor,
      Value<DateTime?> lastSyncAt,
    });

class $$TodoSyncCursorTableFilterComposer
    extends Composer<_$AppDatabase, $TodoSyncCursorTable> {
  $$TodoSyncCursorTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoSyncCursorTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoSyncCursorTable> {
  $$TodoSyncCursorTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoSyncCursorTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoSyncCursorTable> {
  $$TodoSyncCursorTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );
}

class $$TodoSyncCursorTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoSyncCursorTable,
          TodoSyncCursorData,
          $$TodoSyncCursorTableFilterComposer,
          $$TodoSyncCursorTableOrderingComposer,
          $$TodoSyncCursorTableAnnotationComposer,
          $$TodoSyncCursorTableCreateCompanionBuilder,
          $$TodoSyncCursorTableUpdateCompanionBuilder,
          (
            TodoSyncCursorData,
            BaseReferences<
              _$AppDatabase,
              $TodoSyncCursorTable,
              TodoSyncCursorData
            >,
          ),
          TodoSyncCursorData,
          PrefetchHooks Function()
        > {
  $$TodoSyncCursorTableTableManager(
    _$AppDatabase db,
    $TodoSyncCursorTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoSyncCursorTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoSyncCursorTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoSyncCursorTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> cursor = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
              }) => TodoSyncCursorCompanion(
                id: id,
                cursor: cursor,
                lastSyncAt: lastSyncAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> cursor = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
              }) => TodoSyncCursorCompanion.insert(
                id: id,
                cursor: cursor,
                lastSyncAt: lastSyncAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoSyncCursorTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoSyncCursorTable,
      TodoSyncCursorData,
      $$TodoSyncCursorTableFilterComposer,
      $$TodoSyncCursorTableOrderingComposer,
      $$TodoSyncCursorTableAnnotationComposer,
      $$TodoSyncCursorTableCreateCompanionBuilder,
      $$TodoSyncCursorTableUpdateCompanionBuilder,
      (
        TodoSyncCursorData,
        BaseReferences<_$AppDatabase, $TodoSyncCursorTable, TodoSyncCursorData>,
      ),
      TodoSyncCursorData,
      PrefetchHooks Function()
    >;
typedef $$TodoEntityRevisionsTableCreateCompanionBuilder =
    TodoEntityRevisionsCompanion Function({
      required String entity,
      required int serverId,
      required int revision,
      Value<int> rowid,
    });
typedef $$TodoEntityRevisionsTableUpdateCompanionBuilder =
    TodoEntityRevisionsCompanion Function({
      Value<String> entity,
      Value<int> serverId,
      Value<int> revision,
      Value<int> rowid,
    });

class $$TodoEntityRevisionsTableFilterComposer
    extends Composer<_$AppDatabase, $TodoEntityRevisionsTable> {
  $$TodoEntityRevisionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoEntityRevisionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoEntityRevisionsTable> {
  $$TodoEntityRevisionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoEntityRevisionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoEntityRevisionsTable> {
  $$TodoEntityRevisionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$TodoEntityRevisionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoEntityRevisionsTable,
          TodoEntityRevision,
          $$TodoEntityRevisionsTableFilterComposer,
          $$TodoEntityRevisionsTableOrderingComposer,
          $$TodoEntityRevisionsTableAnnotationComposer,
          $$TodoEntityRevisionsTableCreateCompanionBuilder,
          $$TodoEntityRevisionsTableUpdateCompanionBuilder,
          (
            TodoEntityRevision,
            BaseReferences<
              _$AppDatabase,
              $TodoEntityRevisionsTable,
              TodoEntityRevision
            >,
          ),
          TodoEntityRevision,
          PrefetchHooks Function()
        > {
  $$TodoEntityRevisionsTableTableManager(
    _$AppDatabase db,
    $TodoEntityRevisionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoEntityRevisionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoEntityRevisionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TodoEntityRevisionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> entity = const Value.absent(),
                Value<int> serverId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoEntityRevisionsCompanion(
                entity: entity,
                serverId: serverId,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entity,
                required int serverId,
                required int revision,
                Value<int> rowid = const Value.absent(),
              }) => TodoEntityRevisionsCompanion.insert(
                entity: entity,
                serverId: serverId,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoEntityRevisionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoEntityRevisionsTable,
      TodoEntityRevision,
      $$TodoEntityRevisionsTableFilterComposer,
      $$TodoEntityRevisionsTableOrderingComposer,
      $$TodoEntityRevisionsTableAnnotationComposer,
      $$TodoEntityRevisionsTableCreateCompanionBuilder,
      $$TodoEntityRevisionsTableUpdateCompanionBuilder,
      (
        TodoEntityRevision,
        BaseReferences<
          _$AppDatabase,
          $TodoEntityRevisionsTable,
          TodoEntityRevision
        >,
      ),
      TodoEntityRevision,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TodoListsTableTableManager get todoLists =>
      $$TodoListsTableTableManager(_db, _db.todoLists);
  $$TodoTaskSectionsTableTableManager get todoTaskSections =>
      $$TodoTaskSectionsTableTableManager(_db, _db.todoTaskSections);
  $$TodoTasksTableTableManager get todoTasks =>
      $$TodoTasksTableTableManager(_db, _db.todoTasks);
  $$TodoFoldersTableTableManager get todoFolders =>
      $$TodoFoldersTableTableManager(_db, _db.todoFolders);
  $$TodoTagsTableTableManager get todoTags =>
      $$TodoTagsTableTableManager(_db, _db.todoTags);
  $$TodoTaskTagsTableTableManager get todoTaskTags =>
      $$TodoTaskTagsTableTableManager(_db, _db.todoTaskTags);
  $$TodoChecklistItemsTableTableManager get todoChecklistItems =>
      $$TodoChecklistItemsTableTableManager(_db, _db.todoChecklistItems);
  $$TodoAttachmentsTableTableManager get todoAttachments =>
      $$TodoAttachmentsTableTableManager(_db, _db.todoAttachments);
  $$TodoActivitiesTableTableManager get todoActivities =>
      $$TodoActivitiesTableTableManager(_db, _db.todoActivities);
  $$TodoTemplatesTableTableManager get todoTemplates =>
      $$TodoTemplatesTableTableManager(_db, _db.todoTemplates);
  $$TodoRemindersTableTableManager get todoReminders =>
      $$TodoRemindersTableTableManager(_db, _db.todoReminders);
  $$TodoRepeatRulesTableTableManager get todoRepeatRules =>
      $$TodoRepeatRulesTableTableManager(_db, _db.todoRepeatRules);
  $$TodoRepeatSkipsTableTableManager get todoRepeatSkips =>
      $$TodoRepeatSkipsTableTableManager(_db, _db.todoRepeatSkips);
  $$TodoViewPreferencesTableTableManager get todoViewPreferences =>
      $$TodoViewPreferencesTableTableManager(_db, _db.todoViewPreferences);
  $$TodoBoardPreferencesTableTableManager get todoBoardPreferences =>
      $$TodoBoardPreferencesTableTableManager(_db, _db.todoBoardPreferences);
  $$TodoFiltersTableTableManager get todoFilters =>
      $$TodoFiltersTableTableManager(_db, _db.todoFilters);
  $$TodoRecommendationsTableTableManager get todoRecommendations =>
      $$TodoRecommendationsTableTableManager(_db, _db.todoRecommendations);
  $$TodoSyncChangesTableTableManager get todoSyncChanges =>
      $$TodoSyncChangesTableTableManager(_db, _db.todoSyncChanges);
  $$TodoSyncCursorTableTableManager get todoSyncCursor =>
      $$TodoSyncCursorTableTableManager(_db, _db.todoSyncCursor);
  $$TodoEntityRevisionsTableTableManager get todoEntityRevisions =>
      $$TodoEntityRevisionsTableTableManager(_db, _db.todoEntityRevisions);
}

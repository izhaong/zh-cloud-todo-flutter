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
    folderId,
    sortOrder,
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
        DriftSqlType.int,
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
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_id'],
      ),
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
  $TodoListsTable createAlias(String alias) {
    return $TodoListsTable(attachedDatabase, alias);
  }
}

class TodoList extends DataClass implements Insertable<TodoList> {
  final int id;
  final int? serverId;
  final String name;
  final int? folderId;
  final int sortOrder;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoList({
    required this.id,
    this.serverId,
    required this.name,
    this.folderId,
    required this.sortOrder,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<int>(folderId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
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
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      sortOrder: Value(sortOrder),
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
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      name: serializer.fromJson<String>(json['name']),
      folderId: serializer.fromJson<int?>(json['folderId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'name': serializer.toJson<String>(name),
      'folderId': serializer.toJson<int?>(folderId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoList copyWith({
    int? id,
    Value<int?> serverId = const Value.absent(),
    String? name,
    Value<int?> folderId = const Value.absent(),
    int? sortOrder,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoList(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    name: name ?? this.name,
    folderId: folderId.present ? folderId.value : this.folderId,
    sortOrder: sortOrder ?? this.sortOrder,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoList copyWithCompanion(TodoListsCompanion data) {
    return TodoList(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      name: data.name.present ? data.name.value : this.name,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
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
          ..write('folderId: $folderId, ')
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
    folderId,
    sortOrder,
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
          other.folderId == this.folderId &&
          other.sortOrder == this.sortOrder &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoListsCompanion extends UpdateCompanion<TodoList> {
  final Value<int> id;
  final Value<int?> serverId;
  final Value<String> name;
  final Value<int?> folderId;
  final Value<int> sortOrder;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  const TodoListsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.name = const Value.absent(),
    this.folderId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TodoListsCompanion.insert({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    required String name,
    this.folderId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
  }) : name = Value(name),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoList> custom({
    Expression<int>? id,
    Expression<int>? serverId,
    Expression<String>? name,
    Expression<int>? folderId,
    Expression<int>? sortOrder,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (name != null) 'name': name,
      if (folderId != null) 'folder_id': folderId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TodoListsCompanion copyWith({
    Value<int>? id,
    Value<int?>? serverId,
    Value<String>? name,
    Value<int?>? folderId,
    Value<int>? sortOrder,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
  }) {
    return TodoListsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      folderId: folderId ?? this.folderId,
      sortOrder: sortOrder ?? this.sortOrder,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<int>(folderId.value);
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoListsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('folderId: $folderId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
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
  late final GeneratedColumn<int> listId = GeneratedColumn<int>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentTaskIdMeta = const VerificationMeta(
    'parentTaskId',
  );
  @override
  late final GeneratedColumn<int> parentTaskId = GeneratedColumn<int>(
    'parent_task_id',
    aliasedName,
    true,
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
    parentTaskId,
    title,
    description,
    completed,
    priority,
    isPinned,
    sortOrder,
    startAt,
    endAt,
    dueAt,
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
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}list_id'],
      )!,
      parentTaskId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
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
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
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
  final int id;
  final int? serverId;
  final int listId;
  final int? parentTaskId;
  final String title;
  final String? description;
  final bool completed;
  final int priority;
  final bool isPinned;
  final int sortOrder;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? dueAt;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoTask({
    required this.id,
    this.serverId,
    required this.listId,
    this.parentTaskId,
    required this.title,
    this.description,
    required this.completed,
    required this.priority,
    required this.isPinned,
    required this.sortOrder,
    this.startAt,
    this.endAt,
    this.dueAt,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['list_id'] = Variable<int>(listId);
    if (!nullToAbsent || parentTaskId != null) {
      map['parent_task_id'] = Variable<int>(parentTaskId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['completed'] = Variable<bool>(completed);
    map['priority'] = Variable<int>(priority);
    map['is_pinned'] = Variable<bool>(isPinned);
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
      parentTaskId: parentTaskId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentTaskId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      completed: Value(completed),
      priority: Value(priority),
      isPinned: Value(isPinned),
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
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      listId: serializer.fromJson<int>(json['listId']),
      parentTaskId: serializer.fromJson<int?>(json['parentTaskId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      completed: serializer.fromJson<bool>(json['completed']),
      priority: serializer.fromJson<int>(json['priority']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      startAt: serializer.fromJson<DateTime?>(json['startAt']),
      endAt: serializer.fromJson<DateTime?>(json['endAt']),
      dueAt: serializer.fromJson<DateTime?>(json['dueAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'listId': serializer.toJson<int>(listId),
      'parentTaskId': serializer.toJson<int?>(parentTaskId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'completed': serializer.toJson<bool>(completed),
      'priority': serializer.toJson<int>(priority),
      'isPinned': serializer.toJson<bool>(isPinned),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'startAt': serializer.toJson<DateTime?>(startAt),
      'endAt': serializer.toJson<DateTime?>(endAt),
      'dueAt': serializer.toJson<DateTime?>(dueAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoTask copyWith({
    int? id,
    Value<int?> serverId = const Value.absent(),
    int? listId,
    Value<int?> parentTaskId = const Value.absent(),
    String? title,
    Value<String?> description = const Value.absent(),
    bool? completed,
    int? priority,
    bool? isPinned,
    int? sortOrder,
    Value<DateTime?> startAt = const Value.absent(),
    Value<DateTime?> endAt = const Value.absent(),
    Value<DateTime?> dueAt = const Value.absent(),
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoTask(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    listId: listId ?? this.listId,
    parentTaskId: parentTaskId.present ? parentTaskId.value : this.parentTaskId,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    completed: completed ?? this.completed,
    priority: priority ?? this.priority,
    isPinned: isPinned ?? this.isPinned,
    sortOrder: sortOrder ?? this.sortOrder,
    startAt: startAt.present ? startAt.value : this.startAt,
    endAt: endAt.present ? endAt.value : this.endAt,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoTask copyWithCompanion(TodoTasksCompanion data) {
    return TodoTask(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      listId: data.listId.present ? data.listId.value : this.listId,
      parentTaskId: data.parentTaskId.present
          ? data.parentTaskId.value
          : this.parentTaskId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      completed: data.completed.present ? data.completed.value : this.completed,
      priority: data.priority.present ? data.priority.value : this.priority,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
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
          ..write('parentTaskId: $parentTaskId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('completed: $completed, ')
          ..write('priority: $priority, ')
          ..write('isPinned: $isPinned, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('dueAt: $dueAt, ')
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
    parentTaskId,
    title,
    description,
    completed,
    priority,
    isPinned,
    sortOrder,
    startAt,
    endAt,
    dueAt,
    updatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoTask &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.listId == this.listId &&
          other.parentTaskId == this.parentTaskId &&
          other.title == this.title &&
          other.description == this.description &&
          other.completed == this.completed &&
          other.priority == this.priority &&
          other.isPinned == this.isPinned &&
          other.sortOrder == this.sortOrder &&
          other.startAt == this.startAt &&
          other.endAt == this.endAt &&
          other.dueAt == this.dueAt &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoTasksCompanion extends UpdateCompanion<TodoTask> {
  final Value<int> id;
  final Value<int?> serverId;
  final Value<int> listId;
  final Value<int?> parentTaskId;
  final Value<String> title;
  final Value<String?> description;
  final Value<bool> completed;
  final Value<int> priority;
  final Value<bool> isPinned;
  final Value<int> sortOrder;
  final Value<DateTime?> startAt;
  final Value<DateTime?> endAt;
  final Value<DateTime?> dueAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  const TodoTasksCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.listId = const Value.absent(),
    this.parentTaskId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.completed = const Value.absent(),
    this.priority = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TodoTasksCompanion.insert({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    required int listId,
    this.parentTaskId = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    this.completed = const Value.absent(),
    this.priority = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.dueAt = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
  }) : listId = Value(listId),
       title = Value(title),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoTask> custom({
    Expression<int>? id,
    Expression<int>? serverId,
    Expression<int>? listId,
    Expression<int>? parentTaskId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<bool>? completed,
    Expression<int>? priority,
    Expression<bool>? isPinned,
    Expression<int>? sortOrder,
    Expression<DateTime>? startAt,
    Expression<DateTime>? endAt,
    Expression<DateTime>? dueAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (listId != null) 'list_id': listId,
      if (parentTaskId != null) 'parent_task_id': parentTaskId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (completed != null) 'completed': completed,
      if (priority != null) 'priority': priority,
      if (isPinned != null) 'is_pinned': isPinned,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (dueAt != null) 'due_at': dueAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TodoTasksCompanion copyWith({
    Value<int>? id,
    Value<int?>? serverId,
    Value<int>? listId,
    Value<int?>? parentTaskId,
    Value<String>? title,
    Value<String?>? description,
    Value<bool>? completed,
    Value<int>? priority,
    Value<bool>? isPinned,
    Value<int>? sortOrder,
    Value<DateTime?>? startAt,
    Value<DateTime?>? endAt,
    Value<DateTime?>? dueAt,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
  }) {
    return TodoTasksCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      listId: listId ?? this.listId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      isPinned: isPinned ?? this.isPinned,
      sortOrder: sortOrder ?? this.sortOrder,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      dueAt: dueAt ?? this.dueAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<int>(listId.value);
    }
    if (parentTaskId.present) {
      map['parent_task_id'] = Variable<int>(parentTaskId.value);
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
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
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
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoTasksCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('listId: $listId, ')
          ..write('parentTaskId: $parentTaskId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('completed: $completed, ')
          ..write('priority: $priority, ')
          ..write('isPinned: $isPinned, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('dueAt: $dueAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
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
        DriftSqlType.int,
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
  final int id;
  final int? serverId;
  final String name;
  final int sortOrder;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoFolder({
    required this.id,
    this.serverId,
    required this.name,
    required this.sortOrder,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
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
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
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
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoFolder copyWith({
    int? id,
    Value<int?> serverId = const Value.absent(),
    String? name,
    int? sortOrder,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoFolder(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoFolder copyWithCompanion(TodoFoldersCompanion data) {
    return TodoFolder(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
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
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, serverId, name, sortOrder, updatedAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoFolder &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoFoldersCompanion extends UpdateCompanion<TodoFolder> {
  final Value<int> id;
  final Value<int?> serverId;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  const TodoFoldersCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TodoFoldersCompanion.insert({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    required String name,
    this.sortOrder = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
  }) : name = Value(name),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoFolder> custom({
    Expression<int>? id,
    Expression<int>? serverId,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TodoFoldersCompanion copyWith({
    Value<int>? id,
    Value<int?>? serverId,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
  }) {
    return TodoFoldersCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoFoldersCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
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
        DriftSqlType.int,
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
  final int id;
  final int? serverId;
  final String name;
  final String? color;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoTag({
    required this.id,
    this.serverId,
    required this.name,
    this.color,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
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
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
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
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String?>(color),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoTag copyWith({
    int? id,
    Value<int?> serverId = const Value.absent(),
    String? name,
    Value<String?> color = const Value.absent(),
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoTag(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    name: name ?? this.name,
    color: color.present ? color.value : this.color,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoTag copyWithCompanion(TodoTagsCompanion data) {
    return TodoTag(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
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
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, serverId, name, color, updatedAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoTag &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.name == this.name &&
          other.color == this.color &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoTagsCompanion extends UpdateCompanion<TodoTag> {
  final Value<int> id;
  final Value<int?> serverId;
  final Value<String> name;
  final Value<String?> color;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  const TodoTagsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TodoTagsCompanion.insert({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    required String name,
    this.color = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
  }) : name = Value(name),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoTag> custom({
    Expression<int>? id,
    Expression<int>? serverId,
    Expression<String>? name,
    Expression<String>? color,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TodoTagsCompanion copyWith({
    Value<int>? id,
    Value<int?>? serverId,
    Value<String>? name,
    Value<String?>? color,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
  }) {
    return TodoTagsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      color: color ?? this.color,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoTagsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
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
  late final GeneratedColumn<int> taskId = GeneratedColumn<int>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [taskId, tagId];
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskId, tagId};
  @override
  TodoTaskTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoTaskTag(
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $TodoTaskTagsTable createAlias(String alias) {
    return $TodoTaskTagsTable(attachedDatabase, alias);
  }
}

class TodoTaskTag extends DataClass implements Insertable<TodoTaskTag> {
  final int taskId;
  final int tagId;
  const TodoTaskTag({required this.taskId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_id'] = Variable<int>(taskId);
    map['tag_id'] = Variable<int>(tagId);
    return map;
  }

  TodoTaskTagsCompanion toCompanion(bool nullToAbsent) {
    return TodoTaskTagsCompanion(taskId: Value(taskId), tagId: Value(tagId));
  }

  factory TodoTaskTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoTaskTag(
      taskId: serializer.fromJson<int>(json['taskId']),
      tagId: serializer.fromJson<int>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'taskId': serializer.toJson<int>(taskId),
      'tagId': serializer.toJson<int>(tagId),
    };
  }

  TodoTaskTag copyWith({int? taskId, int? tagId}) =>
      TodoTaskTag(taskId: taskId ?? this.taskId, tagId: tagId ?? this.tagId);
  TodoTaskTag copyWithCompanion(TodoTaskTagsCompanion data) {
    return TodoTaskTag(
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoTaskTag(')
          ..write('taskId: $taskId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(taskId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoTaskTag &&
          other.taskId == this.taskId &&
          other.tagId == this.tagId);
}

class TodoTaskTagsCompanion extends UpdateCompanion<TodoTaskTag> {
  final Value<int> taskId;
  final Value<int> tagId;
  final Value<int> rowid;
  const TodoTaskTagsCompanion({
    this.taskId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoTaskTagsCompanion.insert({
    required int taskId,
    required int tagId,
    this.rowid = const Value.absent(),
  }) : taskId = Value(taskId),
       tagId = Value(tagId);
  static Insertable<TodoTaskTag> custom({
    Expression<int>? taskId,
    Expression<int>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (taskId != null) 'task_id': taskId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoTaskTagsCompanion copyWith({
    Value<int>? taskId,
    Value<int>? tagId,
    Value<int>? rowid,
  }) {
    return TodoTaskTagsCompanion(
      taskId: taskId ?? this.taskId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (taskId.present) {
      map['task_id'] = Variable<int>(taskId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
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
  late final GeneratedColumn<int> taskId = GeneratedColumn<int>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
    status,
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
  TodoReminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoReminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_id'],
      )!,
      remindAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remind_at'],
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
  $TodoRemindersTable createAlias(String alias) {
    return $TodoRemindersTable(attachedDatabase, alias);
  }
}

class TodoReminder extends DataClass implements Insertable<TodoReminder> {
  final int id;
  final int? serverId;
  final int taskId;
  final DateTime remindAt;
  final String status;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoReminder({
    required this.id,
    this.serverId,
    required this.taskId,
    required this.remindAt,
    required this.status,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['task_id'] = Variable<int>(taskId);
    map['remind_at'] = Variable<DateTime>(remindAt);
    map['status'] = Variable<String>(status);
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
      status: Value(status),
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
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      taskId: serializer.fromJson<int>(json['taskId']),
      remindAt: serializer.fromJson<DateTime>(json['remindAt']),
      status: serializer.fromJson<String>(json['status']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'taskId': serializer.toJson<int>(taskId),
      'remindAt': serializer.toJson<DateTime>(remindAt),
      'status': serializer.toJson<String>(status),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoReminder copyWith({
    int? id,
    Value<int?> serverId = const Value.absent(),
    int? taskId,
    DateTime? remindAt,
    String? status,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoReminder(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    taskId: taskId ?? this.taskId,
    remindAt: remindAt ?? this.remindAt,
    status: status ?? this.status,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoReminder copyWithCompanion(TodoRemindersCompanion data) {
    return TodoReminder(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      remindAt: data.remindAt.present ? data.remindAt.value : this.remindAt,
      status: data.status.present ? data.status.value : this.status,
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
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, serverId, taskId, remindAt, status, updatedAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoReminder &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.taskId == this.taskId &&
          other.remindAt == this.remindAt &&
          other.status == this.status &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoRemindersCompanion extends UpdateCompanion<TodoReminder> {
  final Value<int> id;
  final Value<int?> serverId;
  final Value<int> taskId;
  final Value<DateTime> remindAt;
  final Value<String> status;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  const TodoRemindersCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.remindAt = const Value.absent(),
    this.status = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TodoRemindersCompanion.insert({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    required int taskId,
    required DateTime remindAt,
    this.status = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
  }) : taskId = Value(taskId),
       remindAt = Value(remindAt),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoReminder> custom({
    Expression<int>? id,
    Expression<int>? serverId,
    Expression<int>? taskId,
    Expression<DateTime>? remindAt,
    Expression<String>? status,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (taskId != null) 'task_id': taskId,
      if (remindAt != null) 'remind_at': remindAt,
      if (status != null) 'status': status,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TodoRemindersCompanion copyWith({
    Value<int>? id,
    Value<int?>? serverId,
    Value<int>? taskId,
    Value<DateTime>? remindAt,
    Value<String>? status,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
  }) {
    return TodoRemindersCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      taskId: taskId ?? this.taskId,
      remindAt: remindAt ?? this.remindAt,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<int>(taskId.value);
    }
    if (remindAt.present) {
      map['remind_at'] = Variable<DateTime>(remindAt.value);
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoRemindersCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('taskId: $taskId, ')
          ..write('remindAt: $remindAt, ')
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
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
  late final GeneratedColumn<int> taskId = GeneratedColumn<int>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _untilMeta = const VerificationMeta('until');
  @override
  late final GeneratedColumn<DateTime> until = GeneratedColumn<DateTime>(
    'until',
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
    taskId,
    freq,
    interval,
    byDay,
    until,
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
    if (data.containsKey('until')) {
      context.handle(
        _untilMeta,
        until.isAcceptableOrUnknown(data['until']!, _untilMeta),
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
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
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
      until: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}until'],
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
  final int id;
  final int? serverId;
  final int taskId;
  final String freq;
  final int interval;
  final String? byDay;
  final DateTime? until;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoRepeatRule({
    required this.id,
    this.serverId,
    required this.taskId,
    required this.freq,
    required this.interval,
    this.byDay,
    this.until,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['task_id'] = Variable<int>(taskId);
    map['freq'] = Variable<String>(freq);
    map['interval'] = Variable<int>(interval);
    if (!nullToAbsent || byDay != null) {
      map['by_day'] = Variable<String>(byDay);
    }
    if (!nullToAbsent || until != null) {
      map['until'] = Variable<DateTime>(until);
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
      until: until == null && nullToAbsent
          ? const Value.absent()
          : Value(until),
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
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      taskId: serializer.fromJson<int>(json['taskId']),
      freq: serializer.fromJson<String>(json['freq']),
      interval: serializer.fromJson<int>(json['interval']),
      byDay: serializer.fromJson<String?>(json['byDay']),
      until: serializer.fromJson<DateTime?>(json['until']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'taskId': serializer.toJson<int>(taskId),
      'freq': serializer.toJson<String>(freq),
      'interval': serializer.toJson<int>(interval),
      'byDay': serializer.toJson<String?>(byDay),
      'until': serializer.toJson<DateTime?>(until),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoRepeatRule copyWith({
    int? id,
    Value<int?> serverId = const Value.absent(),
    int? taskId,
    String? freq,
    int? interval,
    Value<String?> byDay = const Value.absent(),
    Value<DateTime?> until = const Value.absent(),
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoRepeatRule(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    taskId: taskId ?? this.taskId,
    freq: freq ?? this.freq,
    interval: interval ?? this.interval,
    byDay: byDay.present ? byDay.value : this.byDay,
    until: until.present ? until.value : this.until,
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
      until: data.until.present ? data.until.value : this.until,
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
          ..write('until: $until, ')
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
    until,
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
          other.until == this.until &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoRepeatRulesCompanion extends UpdateCompanion<TodoRepeatRule> {
  final Value<int> id;
  final Value<int?> serverId;
  final Value<int> taskId;
  final Value<String> freq;
  final Value<int> interval;
  final Value<String?> byDay;
  final Value<DateTime?> until;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  const TodoRepeatRulesCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.freq = const Value.absent(),
    this.interval = const Value.absent(),
    this.byDay = const Value.absent(),
    this.until = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TodoRepeatRulesCompanion.insert({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    required int taskId,
    required String freq,
    this.interval = const Value.absent(),
    this.byDay = const Value.absent(),
    this.until = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
  }) : taskId = Value(taskId),
       freq = Value(freq),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoRepeatRule> custom({
    Expression<int>? id,
    Expression<int>? serverId,
    Expression<int>? taskId,
    Expression<String>? freq,
    Expression<int>? interval,
    Expression<String>? byDay,
    Expression<DateTime>? until,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (taskId != null) 'task_id': taskId,
      if (freq != null) 'freq': freq,
      if (interval != null) 'interval': interval,
      if (byDay != null) 'by_day': byDay,
      if (until != null) 'until': until,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TodoRepeatRulesCompanion copyWith({
    Value<int>? id,
    Value<int?>? serverId,
    Value<int>? taskId,
    Value<String>? freq,
    Value<int>? interval,
    Value<String?>? byDay,
    Value<DateTime?>? until,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
  }) {
    return TodoRepeatRulesCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      taskId: taskId ?? this.taskId,
      freq: freq ?? this.freq,
      interval: interval ?? this.interval,
      byDay: byDay ?? this.byDay,
      until: until ?? this.until,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<int>(taskId.value);
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
    if (until.present) {
      map['until'] = Variable<DateTime>(until.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
          ..write('until: $until, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
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
  late final GeneratedColumn<int> repeatRuleId = GeneratedColumn<int>(
    'repeat_rule_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      repeatRuleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repeat_rule_id'],
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
  final int id;
  final int? serverId;
  final int repeatRuleId;
  final DateTime occurrenceDate;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoRepeatSkip({
    required this.id,
    this.serverId,
    required this.repeatRuleId,
    required this.occurrenceDate,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['repeat_rule_id'] = Variable<int>(repeatRuleId);
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
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      repeatRuleId: serializer.fromJson<int>(json['repeatRuleId']),
      occurrenceDate: serializer.fromJson<DateTime>(json['occurrenceDate']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'repeatRuleId': serializer.toJson<int>(repeatRuleId),
      'occurrenceDate': serializer.toJson<DateTime>(occurrenceDate),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoRepeatSkip copyWith({
    int? id,
    Value<int?> serverId = const Value.absent(),
    int? repeatRuleId,
    DateTime? occurrenceDate,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoRepeatSkip(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    repeatRuleId: repeatRuleId ?? this.repeatRuleId,
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
          other.occurrenceDate == this.occurrenceDate &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoRepeatSkipsCompanion extends UpdateCompanion<TodoRepeatSkip> {
  final Value<int> id;
  final Value<int?> serverId;
  final Value<int> repeatRuleId;
  final Value<DateTime> occurrenceDate;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  const TodoRepeatSkipsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.repeatRuleId = const Value.absent(),
    this.occurrenceDate = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TodoRepeatSkipsCompanion.insert({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    required int repeatRuleId,
    required DateTime occurrenceDate,
    required DateTime updatedAt,
    required DateTime createdAt,
  }) : repeatRuleId = Value(repeatRuleId),
       occurrenceDate = Value(occurrenceDate),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoRepeatSkip> custom({
    Expression<int>? id,
    Expression<int>? serverId,
    Expression<int>? repeatRuleId,
    Expression<DateTime>? occurrenceDate,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (repeatRuleId != null) 'repeat_rule_id': repeatRuleId,
      if (occurrenceDate != null) 'occurrence_date': occurrenceDate,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TodoRepeatSkipsCompanion copyWith({
    Value<int>? id,
    Value<int?>? serverId,
    Value<int>? repeatRuleId,
    Value<DateTime>? occurrenceDate,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
  }) {
    return TodoRepeatSkipsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      repeatRuleId: repeatRuleId ?? this.repeatRuleId,
      occurrenceDate: occurrenceDate ?? this.occurrenceDate,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (repeatRuleId.present) {
      map['repeat_rule_id'] = Variable<int>(repeatRuleId.value);
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoRepeatSkipsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('repeatRuleId: $repeatRuleId, ')
          ..write('occurrenceDate: $occurrenceDate, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
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
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
    scope,
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
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
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
  TodoViewPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoViewPreference(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
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
  final int id;
  final int? serverId;
  final String scope;
  final String valueJson;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoViewPreference({
    required this.id,
    this.serverId,
    required this.scope,
    required this.valueJson,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['scope'] = Variable<String>(scope);
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
      scope: Value(scope),
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
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      scope: serializer.fromJson<String>(json['scope']),
      valueJson: serializer.fromJson<String>(json['valueJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'scope': serializer.toJson<String>(scope),
      'valueJson': serializer.toJson<String>(valueJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoViewPreference copyWith({
    int? id,
    Value<int?> serverId = const Value.absent(),
    String? scope,
    String? valueJson,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoViewPreference(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    scope: scope ?? this.scope,
    valueJson: valueJson ?? this.valueJson,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TodoViewPreference copyWithCompanion(TodoViewPreferencesCompanion data) {
    return TodoViewPreference(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      scope: data.scope.present ? data.scope.value : this.scope,
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
          ..write('scope: $scope, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, serverId, scope, valueJson, updatedAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoViewPreference &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.scope == this.scope &&
          other.valueJson == this.valueJson &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoViewPreferencesCompanion extends UpdateCompanion<TodoViewPreference> {
  final Value<int> id;
  final Value<int?> serverId;
  final Value<String> scope;
  final Value<String> valueJson;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  const TodoViewPreferencesCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.scope = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TodoViewPreferencesCompanion.insert({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    required String scope,
    required String valueJson,
    required DateTime updatedAt,
    required DateTime createdAt,
  }) : scope = Value(scope),
       valueJson = Value(valueJson),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoViewPreference> custom({
    Expression<int>? id,
    Expression<int>? serverId,
    Expression<String>? scope,
    Expression<String>? valueJson,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (scope != null) 'scope': scope,
      if (valueJson != null) 'value_json': valueJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TodoViewPreferencesCompanion copyWith({
    Value<int>? id,
    Value<int?>? serverId,
    Value<String>? scope,
    Value<String>? valueJson,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
  }) {
    return TodoViewPreferencesCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      scope: scope ?? this.scope,
      valueJson: valueJson ?? this.valueJson,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoViewPreferencesCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('scope: $scope, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
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
        DriftSqlType.int,
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
  final int id;
  final int? serverId;
  final String name;
  final String conditionJson;
  final int sortOrder;
  final DateTime updatedAt;
  final DateTime createdAt;
  const TodoFilter({
    required this.id,
    this.serverId,
    required this.name,
    required this.conditionJson,
    required this.sortOrder,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['name'] = Variable<String>(name);
    map['condition_json'] = Variable<String>(conditionJson);
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
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      name: serializer.fromJson<String>(json['name']),
      conditionJson: serializer.fromJson<String>(json['conditionJson']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'name': serializer.toJson<String>(name),
      'conditionJson': serializer.toJson<String>(conditionJson),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TodoFilter copyWith({
    int? id,
    Value<int?> serverId = const Value.absent(),
    String? name,
    String? conditionJson,
    int? sortOrder,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => TodoFilter(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    name: name ?? this.name,
    conditionJson: conditionJson ?? this.conditionJson,
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
          other.sortOrder == this.sortOrder &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class TodoFiltersCompanion extends UpdateCompanion<TodoFilter> {
  final Value<int> id;
  final Value<int?> serverId;
  final Value<String> name;
  final Value<String> conditionJson;
  final Value<int> sortOrder;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  const TodoFiltersCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.name = const Value.absent(),
    this.conditionJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TodoFiltersCompanion.insert({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    required String name,
    required String conditionJson,
    this.sortOrder = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
  }) : name = Value(name),
       conditionJson = Value(conditionJson),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<TodoFilter> custom({
    Expression<int>? id,
    Expression<int>? serverId,
    Expression<String>? name,
    Expression<String>? conditionJson,
    Expression<int>? sortOrder,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (name != null) 'name': name,
      if (conditionJson != null) 'condition_json': conditionJson,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TodoFiltersCompanion copyWith({
    Value<int>? id,
    Value<int?>? serverId,
    Value<String>? name,
    Value<String>? conditionJson,
    Value<int>? sortOrder,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
  }) {
    return TodoFiltersCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      conditionJson: conditionJson ?? this.conditionJson,
      sortOrder: sortOrder ?? this.sortOrder,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
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
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
          ..write('sortOrder: $sortOrder, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
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
  late final GeneratedColumn<int> entityLocalId = GeneratedColumn<int>(
    'entity_local_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    status,
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
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
        DriftSqlType.int,
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
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
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
  final int? entityLocalId;
  final int? entityServerId;
  final String payloadJson;
  final DateTime createdAt;
  final int attemptCount;
  final String status;
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
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_mutation_id'] = Variable<String>(clientMutationId);
    map['entity'] = Variable<String>(entity);
    map['op'] = Variable<String>(op);
    if (!nullToAbsent || entityLocalId != null) {
      map['entity_local_id'] = Variable<int>(entityLocalId);
    }
    if (!nullToAbsent || entityServerId != null) {
      map['entity_server_id'] = Variable<int>(entityServerId);
    }
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempt_count'] = Variable<int>(attemptCount);
    map['status'] = Variable<String>(status);
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
      status: Value(status),
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
      entityLocalId: serializer.fromJson<int?>(json['entityLocalId']),
      entityServerId: serializer.fromJson<int?>(json['entityServerId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      status: serializer.fromJson<String>(json['status']),
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
      'entityLocalId': serializer.toJson<int?>(entityLocalId),
      'entityServerId': serializer.toJson<int?>(entityServerId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'status': serializer.toJson<String>(status),
    };
  }

  TodoSyncChange copyWith({
    int? id,
    String? clientMutationId,
    String? entity,
    String? op,
    Value<int?> entityLocalId = const Value.absent(),
    Value<int?> entityServerId = const Value.absent(),
    String? payloadJson,
    DateTime? createdAt,
    int? attemptCount,
    String? status,
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
    status: status ?? this.status,
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
      status: data.status.present ? data.status.value : this.status,
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
          ..write('status: $status')
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
    status,
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
          other.status == this.status);
}

class TodoSyncChangesCompanion extends UpdateCompanion<TodoSyncChange> {
  final Value<int> id;
  final Value<String> clientMutationId;
  final Value<String> entity;
  final Value<String> op;
  final Value<int?> entityLocalId;
  final Value<int?> entityServerId;
  final Value<String> payloadJson;
  final Value<DateTime> createdAt;
  final Value<int> attemptCount;
  final Value<String> status;
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
    this.status = const Value.absent(),
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
    this.status = const Value.absent(),
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
    Expression<int>? entityLocalId,
    Expression<int>? entityServerId,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<int>? attemptCount,
    Expression<String>? status,
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
      if (status != null) 'status': status,
    });
  }

  TodoSyncChangesCompanion copyWith({
    Value<int>? id,
    Value<String>? clientMutationId,
    Value<String>? entity,
    Value<String>? op,
    Value<int?>? entityLocalId,
    Value<int?>? entityServerId,
    Value<String>? payloadJson,
    Value<DateTime>? createdAt,
    Value<int>? attemptCount,
    Value<String>? status,
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
      status: status ?? this.status,
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
      map['entity_local_id'] = Variable<int>(entityLocalId.value);
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
    if (status.present) {
      map['status'] = Variable<String>(status.value);
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
          ..write('status: $status')
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
  late final $TodoTasksTable todoTasks = $TodoTasksTable(this);
  late final $TodoFoldersTable todoFolders = $TodoFoldersTable(this);
  late final $TodoTagsTable todoTags = $TodoTagsTable(this);
  late final $TodoTaskTagsTable todoTaskTags = $TodoTaskTagsTable(this);
  late final $TodoRemindersTable todoReminders = $TodoRemindersTable(this);
  late final $TodoRepeatRulesTable todoRepeatRules = $TodoRepeatRulesTable(
    this,
  );
  late final $TodoRepeatSkipsTable todoRepeatSkips = $TodoRepeatSkipsTable(
    this,
  );
  late final $TodoViewPreferencesTable todoViewPreferences =
      $TodoViewPreferencesTable(this);
  late final $TodoFiltersTable todoFilters = $TodoFiltersTable(this);
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
    todoTasks,
    todoFolders,
    todoTags,
    todoTaskTags,
    todoReminders,
    todoRepeatRules,
    todoRepeatSkips,
    todoViewPreferences,
    todoFilters,
    todoSyncChanges,
    todoSyncCursor,
    todoEntityRevisions,
  ];
}

typedef $$TodoListsTableCreateCompanionBuilder =
    TodoListsCompanion Function({
      Value<int> id,
      Value<int?> serverId,
      required String name,
      Value<int?> folderId,
      Value<int> sortOrder,
      required DateTime updatedAt,
      required DateTime createdAt,
    });
typedef $$TodoListsTableUpdateCompanionBuilder =
    TodoListsCompanion Function({
      Value<int> id,
      Value<int?> serverId,
      Value<String> name,
      Value<int?> folderId,
      Value<int> sortOrder,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
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
  ColumnFilters<int> get id => $composableBuilder(
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

  ColumnFilters<int> get folderId => $composableBuilder(
    column: $table.folderId,
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

class $$TodoListsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoListsTable> {
  $$TodoListsTableOrderingComposer({
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

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
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
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

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
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> folderId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TodoListsCompanion(
                id: id,
                serverId: serverId,
                name: name,
                folderId: folderId,
                sortOrder: sortOrder,
                updatedAt: updatedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                required String name,
                Value<int?> folderId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
              }) => TodoListsCompanion.insert(
                id: id,
                serverId: serverId,
                name: name,
                folderId: folderId,
                sortOrder: sortOrder,
                updatedAt: updatedAt,
                createdAt: createdAt,
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
typedef $$TodoTasksTableCreateCompanionBuilder =
    TodoTasksCompanion Function({
      Value<int> id,
      Value<int?> serverId,
      required int listId,
      Value<int?> parentTaskId,
      required String title,
      Value<String?> description,
      Value<bool> completed,
      Value<int> priority,
      Value<bool> isPinned,
      Value<int> sortOrder,
      Value<DateTime?> startAt,
      Value<DateTime?> endAt,
      Value<DateTime?> dueAt,
      required DateTime updatedAt,
      required DateTime createdAt,
    });
typedef $$TodoTasksTableUpdateCompanionBuilder =
    TodoTasksCompanion Function({
      Value<int> id,
      Value<int?> serverId,
      Value<int> listId,
      Value<int?> parentTaskId,
      Value<String> title,
      Value<String?> description,
      Value<bool> completed,
      Value<int> priority,
      Value<bool> isPinned,
      Value<int> sortOrder,
      Value<DateTime?> startAt,
      Value<DateTime?> endAt,
      Value<DateTime?> dueAt,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
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
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parentTaskId => $composableBuilder(
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

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
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
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parentTaskId => $composableBuilder(
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

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
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
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<int> get parentTaskId => $composableBuilder(
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

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

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
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<int> listId = const Value.absent(),
                Value<int?> parentTaskId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime?> startAt = const Value.absent(),
                Value<DateTime?> endAt = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TodoTasksCompanion(
                id: id,
                serverId: serverId,
                listId: listId,
                parentTaskId: parentTaskId,
                title: title,
                description: description,
                completed: completed,
                priority: priority,
                isPinned: isPinned,
                sortOrder: sortOrder,
                startAt: startAt,
                endAt: endAt,
                dueAt: dueAt,
                updatedAt: updatedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                required int listId,
                Value<int?> parentTaskId = const Value.absent(),
                required String title,
                Value<String?> description = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime?> startAt = const Value.absent(),
                Value<DateTime?> endAt = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
              }) => TodoTasksCompanion.insert(
                id: id,
                serverId: serverId,
                listId: listId,
                parentTaskId: parentTaskId,
                title: title,
                description: description,
                completed: completed,
                priority: priority,
                isPinned: isPinned,
                sortOrder: sortOrder,
                startAt: startAt,
                endAt: endAt,
                dueAt: dueAt,
                updatedAt: updatedAt,
                createdAt: createdAt,
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
      Value<int> id,
      Value<int?> serverId,
      required String name,
      Value<int> sortOrder,
      required DateTime updatedAt,
      required DateTime createdAt,
    });
typedef $$TodoFoldersTableUpdateCompanionBuilder =
    TodoFoldersCompanion Function({
      Value<int> id,
      Value<int?> serverId,
      Value<String> name,
      Value<int> sortOrder,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
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
  ColumnFilters<int> get id => $composableBuilder(
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
  ColumnOrderings<int> get id => $composableBuilder(
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
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

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
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TodoFoldersCompanion(
                id: id,
                serverId: serverId,
                name: name,
                sortOrder: sortOrder,
                updatedAt: updatedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                required String name,
                Value<int> sortOrder = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
              }) => TodoFoldersCompanion.insert(
                id: id,
                serverId: serverId,
                name: name,
                sortOrder: sortOrder,
                updatedAt: updatedAt,
                createdAt: createdAt,
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
      Value<int> id,
      Value<int?> serverId,
      required String name,
      Value<String?> color,
      required DateTime updatedAt,
      required DateTime createdAt,
    });
typedef $$TodoTagsTableUpdateCompanionBuilder =
    TodoTagsCompanion Function({
      Value<int> id,
      Value<int?> serverId,
      Value<String> name,
      Value<String?> color,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
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
  ColumnFilters<int> get id => $composableBuilder(
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
  ColumnOrderings<int> get id => $composableBuilder(
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
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

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
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TodoTagsCompanion(
                id: id,
                serverId: serverId,
                name: name,
                color: color,
                updatedAt: updatedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                required String name,
                Value<String?> color = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
              }) => TodoTagsCompanion.insert(
                id: id,
                serverId: serverId,
                name: name,
                color: color,
                updatedAt: updatedAt,
                createdAt: createdAt,
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
      required int taskId,
      required int tagId,
      Value<int> rowid,
    });
typedef $$TodoTaskTagsTableUpdateCompanionBuilder =
    TodoTaskTagsCompanion Function({
      Value<int> taskId,
      Value<int> tagId,
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
  ColumnFilters<int> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tagId => $composableBuilder(
    column: $table.tagId,
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
  ColumnOrderings<int> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tagId => $composableBuilder(
    column: $table.tagId,
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
  GeneratedColumn<int> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<int> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);
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
                Value<int> taskId = const Value.absent(),
                Value<int> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoTaskTagsCompanion(
                taskId: taskId,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int taskId,
                required int tagId,
                Value<int> rowid = const Value.absent(),
              }) => TodoTaskTagsCompanion.insert(
                taskId: taskId,
                tagId: tagId,
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
typedef $$TodoRemindersTableCreateCompanionBuilder =
    TodoRemindersCompanion Function({
      Value<int> id,
      Value<int?> serverId,
      required int taskId,
      required DateTime remindAt,
      Value<String> status,
      required DateTime updatedAt,
      required DateTime createdAt,
    });
typedef $$TodoRemindersTableUpdateCompanionBuilder =
    TodoRemindersCompanion Function({
      Value<int> id,
      Value<int?> serverId,
      Value<int> taskId,
      Value<DateTime> remindAt,
      Value<String> status,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
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
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get remindAt => $composableBuilder(
    column: $table.remindAt,
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

class $$TodoRemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoRemindersTable> {
  $$TodoRemindersTableOrderingComposer({
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

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remindAt => $composableBuilder(
    column: $table.remindAt,
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

class $$TodoRemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoRemindersTable> {
  $$TodoRemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<DateTime> get remindAt =>
      $composableBuilder(column: $table.remindAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

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
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<int> taskId = const Value.absent(),
                Value<DateTime> remindAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TodoRemindersCompanion(
                id: id,
                serverId: serverId,
                taskId: taskId,
                remindAt: remindAt,
                status: status,
                updatedAt: updatedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                required int taskId,
                required DateTime remindAt,
                Value<String> status = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
              }) => TodoRemindersCompanion.insert(
                id: id,
                serverId: serverId,
                taskId: taskId,
                remindAt: remindAt,
                status: status,
                updatedAt: updatedAt,
                createdAt: createdAt,
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
      Value<int> id,
      Value<int?> serverId,
      required int taskId,
      required String freq,
      Value<int> interval,
      Value<String?> byDay,
      Value<DateTime?> until,
      required DateTime updatedAt,
      required DateTime createdAt,
    });
typedef $$TodoRepeatRulesTableUpdateCompanionBuilder =
    TodoRepeatRulesCompanion Function({
      Value<int> id,
      Value<int?> serverId,
      Value<int> taskId,
      Value<String> freq,
      Value<int> interval,
      Value<String?> byDay,
      Value<DateTime?> until,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
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
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taskId => $composableBuilder(
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

  ColumnFilters<DateTime> get until => $composableBuilder(
    column: $table.until,
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
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taskId => $composableBuilder(
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

  ColumnOrderings<DateTime> get until => $composableBuilder(
    column: $table.until,
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
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get freq =>
      $composableBuilder(column: $table.freq, builder: (column) => column);

  GeneratedColumn<int> get interval =>
      $composableBuilder(column: $table.interval, builder: (column) => column);

  GeneratedColumn<String> get byDay =>
      $composableBuilder(column: $table.byDay, builder: (column) => column);

  GeneratedColumn<DateTime> get until =>
      $composableBuilder(column: $table.until, builder: (column) => column);

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
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<int> taskId = const Value.absent(),
                Value<String> freq = const Value.absent(),
                Value<int> interval = const Value.absent(),
                Value<String?> byDay = const Value.absent(),
                Value<DateTime?> until = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TodoRepeatRulesCompanion(
                id: id,
                serverId: serverId,
                taskId: taskId,
                freq: freq,
                interval: interval,
                byDay: byDay,
                until: until,
                updatedAt: updatedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                required int taskId,
                required String freq,
                Value<int> interval = const Value.absent(),
                Value<String?> byDay = const Value.absent(),
                Value<DateTime?> until = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
              }) => TodoRepeatRulesCompanion.insert(
                id: id,
                serverId: serverId,
                taskId: taskId,
                freq: freq,
                interval: interval,
                byDay: byDay,
                until: until,
                updatedAt: updatedAt,
                createdAt: createdAt,
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
      Value<int> id,
      Value<int?> serverId,
      required int repeatRuleId,
      required DateTime occurrenceDate,
      required DateTime updatedAt,
      required DateTime createdAt,
    });
typedef $$TodoRepeatSkipsTableUpdateCompanionBuilder =
    TodoRepeatSkipsCompanion Function({
      Value<int> id,
      Value<int?> serverId,
      Value<int> repeatRuleId,
      Value<DateTime> occurrenceDate,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
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
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repeatRuleId => $composableBuilder(
    column: $table.repeatRuleId,
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
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repeatRuleId => $composableBuilder(
    column: $table.repeatRuleId,
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
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get repeatRuleId => $composableBuilder(
    column: $table.repeatRuleId,
    builder: (column) => column,
  );

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
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<int> repeatRuleId = const Value.absent(),
                Value<DateTime> occurrenceDate = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TodoRepeatSkipsCompanion(
                id: id,
                serverId: serverId,
                repeatRuleId: repeatRuleId,
                occurrenceDate: occurrenceDate,
                updatedAt: updatedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                required int repeatRuleId,
                required DateTime occurrenceDate,
                required DateTime updatedAt,
                required DateTime createdAt,
              }) => TodoRepeatSkipsCompanion.insert(
                id: id,
                serverId: serverId,
                repeatRuleId: repeatRuleId,
                occurrenceDate: occurrenceDate,
                updatedAt: updatedAt,
                createdAt: createdAt,
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
      Value<int> id,
      Value<int?> serverId,
      required String scope,
      required String valueJson,
      required DateTime updatedAt,
      required DateTime createdAt,
    });
typedef $$TodoViewPreferencesTableUpdateCompanionBuilder =
    TodoViewPreferencesCompanion Function({
      Value<int> id,
      Value<int?> serverId,
      Value<String> scope,
      Value<String> valueJson,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
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
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
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
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
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
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

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
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> valueJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TodoViewPreferencesCompanion(
                id: id,
                serverId: serverId,
                scope: scope,
                valueJson: valueJson,
                updatedAt: updatedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                required String scope,
                required String valueJson,
                required DateTime updatedAt,
                required DateTime createdAt,
              }) => TodoViewPreferencesCompanion.insert(
                id: id,
                serverId: serverId,
                scope: scope,
                valueJson: valueJson,
                updatedAt: updatedAt,
                createdAt: createdAt,
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
typedef $$TodoFiltersTableCreateCompanionBuilder =
    TodoFiltersCompanion Function({
      Value<int> id,
      Value<int?> serverId,
      required String name,
      required String conditionJson,
      Value<int> sortOrder,
      required DateTime updatedAt,
      required DateTime createdAt,
    });
typedef $$TodoFiltersTableUpdateCompanionBuilder =
    TodoFiltersCompanion Function({
      Value<int> id,
      Value<int?> serverId,
      Value<String> name,
      Value<String> conditionJson,
      Value<int> sortOrder,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
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
  ColumnFilters<int> get id => $composableBuilder(
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
  ColumnOrderings<int> get id => $composableBuilder(
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
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get conditionJson => $composableBuilder(
    column: $table.conditionJson,
    builder: (column) => column,
  );

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
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> conditionJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TodoFiltersCompanion(
                id: id,
                serverId: serverId,
                name: name,
                conditionJson: conditionJson,
                sortOrder: sortOrder,
                updatedAt: updatedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                required String name,
                required String conditionJson,
                Value<int> sortOrder = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
              }) => TodoFiltersCompanion.insert(
                id: id,
                serverId: serverId,
                name: name,
                conditionJson: conditionJson,
                sortOrder: sortOrder,
                updatedAt: updatedAt,
                createdAt: createdAt,
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
typedef $$TodoSyncChangesTableCreateCompanionBuilder =
    TodoSyncChangesCompanion Function({
      Value<int> id,
      required String clientMutationId,
      required String entity,
      required String op,
      Value<int?> entityLocalId,
      Value<int?> entityServerId,
      required String payloadJson,
      required DateTime createdAt,
      Value<int> attemptCount,
      Value<String> status,
    });
typedef $$TodoSyncChangesTableUpdateCompanionBuilder =
    TodoSyncChangesCompanion Function({
      Value<int> id,
      Value<String> clientMutationId,
      Value<String> entity,
      Value<String> op,
      Value<int?> entityLocalId,
      Value<int?> entityServerId,
      Value<String> payloadJson,
      Value<DateTime> createdAt,
      Value<int> attemptCount,
      Value<String> status,
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

  ColumnFilters<int> get entityLocalId => $composableBuilder(
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

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
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

  ColumnOrderings<int> get entityLocalId => $composableBuilder(
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

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
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

  GeneratedColumn<int> get entityLocalId => $composableBuilder(
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

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
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
                Value<int?> entityLocalId = const Value.absent(),
                Value<int?> entityServerId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String> status = const Value.absent(),
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
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientMutationId,
                required String entity,
                required String op,
                Value<int?> entityLocalId = const Value.absent(),
                Value<int?> entityServerId = const Value.absent(),
                required String payloadJson,
                required DateTime createdAt,
                Value<int> attemptCount = const Value.absent(),
                Value<String> status = const Value.absent(),
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
                status: status,
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
  $$TodoTasksTableTableManager get todoTasks =>
      $$TodoTasksTableTableManager(_db, _db.todoTasks);
  $$TodoFoldersTableTableManager get todoFolders =>
      $$TodoFoldersTableTableManager(_db, _db.todoFolders);
  $$TodoTagsTableTableManager get todoTags =>
      $$TodoTagsTableTableManager(_db, _db.todoTags);
  $$TodoTaskTagsTableTableManager get todoTaskTags =>
      $$TodoTaskTagsTableTableManager(_db, _db.todoTaskTags);
  $$TodoRemindersTableTableManager get todoReminders =>
      $$TodoRemindersTableTableManager(_db, _db.todoReminders);
  $$TodoRepeatRulesTableTableManager get todoRepeatRules =>
      $$TodoRepeatRulesTableTableManager(_db, _db.todoRepeatRules);
  $$TodoRepeatSkipsTableTableManager get todoRepeatSkips =>
      $$TodoRepeatSkipsTableTableManager(_db, _db.todoRepeatSkips);
  $$TodoViewPreferencesTableTableManager get todoViewPreferences =>
      $$TodoViewPreferencesTableTableManager(_db, _db.todoViewPreferences);
  $$TodoFiltersTableTableManager get todoFilters =>
      $$TodoFiltersTableTableManager(_db, _db.todoFilters);
  $$TodoSyncChangesTableTableManager get todoSyncChanges =>
      $$TodoSyncChangesTableTableManager(_db, _db.todoSyncChanges);
  $$TodoSyncCursorTableTableManager get todoSyncCursor =>
      $$TodoSyncCursorTableTableManager(_db, _db.todoSyncCursor);
  $$TodoEntityRevisionsTableTableManager get todoEntityRevisions =>
      $$TodoEntityRevisionsTableTableManager(_db, _db.todoEntityRevisions);
}

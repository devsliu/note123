// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $LocalRecordsTable extends LocalRecords
    with TableInfo<$LocalRecordsTable, LocalRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _batchNoMeta = const VerificationMeta(
    'batchNo',
  );
  @override
  late final GeneratedColumn<int> batchNo = GeneratedColumn<int>(
    'batch_no',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _remoteVersionMeta = const VerificationMeta(
    'remoteVersion',
  );
  @override
  late final GeneratedColumn<int> remoteVersion = GeneratedColumn<int>(
    'remote_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _remoteCreateAtMeta = const VerificationMeta(
    'remoteCreateAt',
  );
  @override
  late final GeneratedColumn<int> remoteCreateAt = GeneratedColumn<int>(
    'remote_create_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _remoteEditAtMeta = const VerificationMeta(
    'remoteEditAt',
  );
  @override
  late final GeneratedColumn<int> remoteEditAt = GeneratedColumn<int>(
    'remote_edit_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _remoteFileEditAtMeta = const VerificationMeta(
    'remoteFileEditAt',
  );
  @override
  late final GeneratedColumn<int> remoteFileEditAt = GeneratedColumn<int>(
    'remote_file_edit_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _remoteDeleteAtMeta = const VerificationMeta(
    'remoteDeleteAt',
  );
  @override
  late final GeneratedColumn<int> remoteDeleteAt = GeneratedColumn<int>(
    'remote_delete_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _remoteLockedMeta = const VerificationMeta(
    'remoteLocked',
  );
  @override
  late final GeneratedColumn<int> remoteLocked = GeneratedColumn<int>(
    'remote_locked',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _remoteMd5Meta = const VerificationMeta(
    'remoteMd5',
  );
  @override
  late final GeneratedColumn<String> remoteMd5 = GeneratedColumn<String>(
    'remote_md5',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _remoteNameMeta = const VerificationMeta(
    'remoteName',
  );
  @override
  late final GeneratedColumn<String> remoteName = GeneratedColumn<String>(
    'remote_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _remotePathMeta = const VerificationMeta(
    'remotePath',
  );
  @override
  late final GeneratedColumn<String> remotePath = GeneratedColumn<String>(
    'remote_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _remoteReminderMeta = const VerificationMeta(
    'remoteReminder',
  );
  @override
  late final GeneratedColumn<String> remoteReminder = GeneratedColumn<String>(
    'remote_reminder',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _remoteFileVersionMeta = const VerificationMeta(
    'remoteFileVersion',
  );
  @override
  late final GeneratedColumn<int> remoteFileVersion = GeneratedColumn<int>(
    'remote_file_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _baseFileVersionMeta = const VerificationMeta(
    'baseFileVersion',
  );
  @override
  late final GeneratedColumn<int> baseFileVersion = GeneratedColumn<int>(
    'base_file_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _localEditTypeMeta = const VerificationMeta(
    'localEditType',
  );
  @override
  late final GeneratedColumn<int> localEditType = GeneratedColumn<int>(
    'local_edit_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _localVersionMeta = const VerificationMeta(
    'localVersion',
  );
  @override
  late final GeneratedColumn<int> localVersion = GeneratedColumn<int>(
    'local_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _localFileVersionMeta = const VerificationMeta(
    'localFileVersion',
  );
  @override
  late final GeneratedColumn<int> localFileVersion = GeneratedColumn<int>(
    'local_file_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _localEditAtMeta = const VerificationMeta(
    'localEditAt',
  );
  @override
  late final GeneratedColumn<int> localEditAt = GeneratedColumn<int>(
    'local_edit_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _localFileEditAtMeta = const VerificationMeta(
    'localFileEditAt',
  );
  @override
  late final GeneratedColumn<int> localFileEditAt = GeneratedColumn<int>(
    'local_file_edit_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _localNameMeta = const VerificationMeta(
    'localName',
  );
  @override
  late final GeneratedColumn<String> localName = GeneratedColumn<String>(
    'local_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _localMd5Meta = const VerificationMeta(
    'localMd5',
  );
  @override
  late final GeneratedColumn<String> localMd5 = GeneratedColumn<String>(
    'local_md5',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _localLockedMeta = const VerificationMeta(
    'localLocked',
  );
  @override
  late final GeneratedColumn<int> localLocked = GeneratedColumn<int>(
    'local_locked',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _localReminderMeta = const VerificationMeta(
    'localReminder',
  );
  @override
  late final GeneratedColumn<String> localReminder = GeneratedColumn<String>(
    'local_reminder',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 1024,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL COLLATE BINARY CHECK (local_path LIKE \'%/\')',
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    batchNo,
    remoteVersion,
    remoteCreateAt,
    remoteEditAt,
    remoteFileEditAt,
    remoteDeleteAt,
    remoteLocked,
    remoteMd5,
    remoteName,
    remotePath,
    remoteReminder,
    remoteFileVersion,
    baseFileVersion,
    localEditType,
    localVersion,
    localFileVersion,
    localEditAt,
    localFileEditAt,
    localName,
    localMd5,
    localLocked,
    localReminder,
    localPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('batch_no')) {
      context.handle(
        _batchNoMeta,
        batchNo.isAcceptableOrUnknown(data['batch_no']!, _batchNoMeta),
      );
    }
    if (data.containsKey('remote_version')) {
      context.handle(
        _remoteVersionMeta,
        remoteVersion.isAcceptableOrUnknown(
          data['remote_version']!,
          _remoteVersionMeta,
        ),
      );
    }
    if (data.containsKey('remote_create_at')) {
      context.handle(
        _remoteCreateAtMeta,
        remoteCreateAt.isAcceptableOrUnknown(
          data['remote_create_at']!,
          _remoteCreateAtMeta,
        ),
      );
    }
    if (data.containsKey('remote_edit_at')) {
      context.handle(
        _remoteEditAtMeta,
        remoteEditAt.isAcceptableOrUnknown(
          data['remote_edit_at']!,
          _remoteEditAtMeta,
        ),
      );
    }
    if (data.containsKey('remote_file_edit_at')) {
      context.handle(
        _remoteFileEditAtMeta,
        remoteFileEditAt.isAcceptableOrUnknown(
          data['remote_file_edit_at']!,
          _remoteFileEditAtMeta,
        ),
      );
    }
    if (data.containsKey('remote_delete_at')) {
      context.handle(
        _remoteDeleteAtMeta,
        remoteDeleteAt.isAcceptableOrUnknown(
          data['remote_delete_at']!,
          _remoteDeleteAtMeta,
        ),
      );
    }
    if (data.containsKey('remote_locked')) {
      context.handle(
        _remoteLockedMeta,
        remoteLocked.isAcceptableOrUnknown(
          data['remote_locked']!,
          _remoteLockedMeta,
        ),
      );
    }
    if (data.containsKey('remote_md5')) {
      context.handle(
        _remoteMd5Meta,
        remoteMd5.isAcceptableOrUnknown(data['remote_md5']!, _remoteMd5Meta),
      );
    }
    if (data.containsKey('remote_name')) {
      context.handle(
        _remoteNameMeta,
        remoteName.isAcceptableOrUnknown(data['remote_name']!, _remoteNameMeta),
      );
    }
    if (data.containsKey('remote_path')) {
      context.handle(
        _remotePathMeta,
        remotePath.isAcceptableOrUnknown(data['remote_path']!, _remotePathMeta),
      );
    }
    if (data.containsKey('remote_reminder')) {
      context.handle(
        _remoteReminderMeta,
        remoteReminder.isAcceptableOrUnknown(
          data['remote_reminder']!,
          _remoteReminderMeta,
        ),
      );
    }
    if (data.containsKey('remote_file_version')) {
      context.handle(
        _remoteFileVersionMeta,
        remoteFileVersion.isAcceptableOrUnknown(
          data['remote_file_version']!,
          _remoteFileVersionMeta,
        ),
      );
    }
    if (data.containsKey('base_file_version')) {
      context.handle(
        _baseFileVersionMeta,
        baseFileVersion.isAcceptableOrUnknown(
          data['base_file_version']!,
          _baseFileVersionMeta,
        ),
      );
    }
    if (data.containsKey('local_edit_type')) {
      context.handle(
        _localEditTypeMeta,
        localEditType.isAcceptableOrUnknown(
          data['local_edit_type']!,
          _localEditTypeMeta,
        ),
      );
    }
    if (data.containsKey('local_version')) {
      context.handle(
        _localVersionMeta,
        localVersion.isAcceptableOrUnknown(
          data['local_version']!,
          _localVersionMeta,
        ),
      );
    }
    if (data.containsKey('local_file_version')) {
      context.handle(
        _localFileVersionMeta,
        localFileVersion.isAcceptableOrUnknown(
          data['local_file_version']!,
          _localFileVersionMeta,
        ),
      );
    }
    if (data.containsKey('local_edit_at')) {
      context.handle(
        _localEditAtMeta,
        localEditAt.isAcceptableOrUnknown(
          data['local_edit_at']!,
          _localEditAtMeta,
        ),
      );
    }
    if (data.containsKey('local_file_edit_at')) {
      context.handle(
        _localFileEditAtMeta,
        localFileEditAt.isAcceptableOrUnknown(
          data['local_file_edit_at']!,
          _localFileEditAtMeta,
        ),
      );
    }
    if (data.containsKey('local_name')) {
      context.handle(
        _localNameMeta,
        localName.isAcceptableOrUnknown(data['local_name']!, _localNameMeta),
      );
    }
    if (data.containsKey('local_md5')) {
      context.handle(
        _localMd5Meta,
        localMd5.isAcceptableOrUnknown(data['local_md5']!, _localMd5Meta),
      );
    }
    if (data.containsKey('local_locked')) {
      context.handle(
        _localLockedMeta,
        localLocked.isAcceptableOrUnknown(
          data['local_locked']!,
          _localLockedMeta,
        ),
      );
    }
    if (data.containsKey('local_reminder')) {
      context.handle(
        _localReminderMeta,
        localReminder.isAcceptableOrUnknown(
          data['local_reminder']!,
          _localReminderMeta,
        ),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  LocalRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalRecord(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      batchNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}batch_no'],
      )!,
      remoteVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_version'],
      )!,
      remoteCreateAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_create_at'],
      )!,
      remoteEditAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_edit_at'],
      )!,
      remoteFileEditAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_file_edit_at'],
      )!,
      remoteDeleteAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_delete_at'],
      )!,
      remoteLocked: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_locked'],
      )!,
      remoteMd5: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_md5'],
      )!,
      remoteName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_name'],
      )!,
      remotePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_path'],
      )!,
      remoteReminder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_reminder'],
      )!,
      remoteFileVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_file_version'],
      )!,
      baseFileVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_file_version'],
      )!,
      localEditType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_edit_type'],
      )!,
      localVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_version'],
      )!,
      localFileVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_file_version'],
      )!,
      localEditAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_edit_at'],
      )!,
      localFileEditAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_file_edit_at'],
      )!,
      localName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_name'],
      )!,
      localMd5: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_md5'],
      )!,
      localLocked: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_locked'],
      )!,
      localReminder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_reminder'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
    );
  }

  @override
  $LocalRecordsTable createAlias(String alias) {
    return $LocalRecordsTable(attachedDatabase, alias);
  }
}

class LocalRecord extends DataClass implements Insertable<LocalRecord> {
  final String uuid;
  final int batchNo;
  final int remoteVersion;
  final int remoteCreateAt;
  final int remoteEditAt;
  final int remoteFileEditAt;
  final int remoteDeleteAt;
  final int remoteLocked;
  final String remoteMd5;
  final String remoteName;
  final String remotePath;
  final String remoteReminder;

  /// Server-side file version number (incremented independently per record, only +1 when file content changes, defaults to 0)
  final int remoteFileVersion;

  /// The server-side fileVersion of the locally downloaded base file.
  /// Written only after downloadBaseFile succeeds, never cleared.
  /// Whether to re-download: remoteFileVersion > baseFileVersion (or file does not exist).
  final int baseFileVersion;

  /// Local edit type: 0=synced, 1=edited, 2=deleted
  final int localEditType;

  /// Local globally-modified version number. Conflict detection: localEditType>0 && localVersion != remoteVersion
  final int localVersion;

  /// Local file edit based on the remote fileVersion. File conflict detection: localFileEdited==1 && localFileVersion != remoteFileVersion
  final int localFileVersion;

  /// Local edit timestamp (optimistic concurrency + server editAt). 0=no edit
  final int localEditAt;

  /// Local file edit timestamp. 0=no file edit
  final int localFileEditAt;

  /// Field values after local edits. Overwritten with remote_* after successful sync (restored to server values)
  final String localName;
  final String localMd5;
  final int localLocked;
  final String localReminder;

  /// Local path: COLLATE BINARY ensures LIKE index works, CHECK constraint guarantees format
  final String localPath;
  const LocalRecord({
    required this.uuid,
    required this.batchNo,
    required this.remoteVersion,
    required this.remoteCreateAt,
    required this.remoteEditAt,
    required this.remoteFileEditAt,
    required this.remoteDeleteAt,
    required this.remoteLocked,
    required this.remoteMd5,
    required this.remoteName,
    required this.remotePath,
    required this.remoteReminder,
    required this.remoteFileVersion,
    required this.baseFileVersion,
    required this.localEditType,
    required this.localVersion,
    required this.localFileVersion,
    required this.localEditAt,
    required this.localFileEditAt,
    required this.localName,
    required this.localMd5,
    required this.localLocked,
    required this.localReminder,
    required this.localPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['batch_no'] = Variable<int>(batchNo);
    map['remote_version'] = Variable<int>(remoteVersion);
    map['remote_create_at'] = Variable<int>(remoteCreateAt);
    map['remote_edit_at'] = Variable<int>(remoteEditAt);
    map['remote_file_edit_at'] = Variable<int>(remoteFileEditAt);
    map['remote_delete_at'] = Variable<int>(remoteDeleteAt);
    map['remote_locked'] = Variable<int>(remoteLocked);
    map['remote_md5'] = Variable<String>(remoteMd5);
    map['remote_name'] = Variable<String>(remoteName);
    map['remote_path'] = Variable<String>(remotePath);
    map['remote_reminder'] = Variable<String>(remoteReminder);
    map['remote_file_version'] = Variable<int>(remoteFileVersion);
    map['base_file_version'] = Variable<int>(baseFileVersion);
    map['local_edit_type'] = Variable<int>(localEditType);
    map['local_version'] = Variable<int>(localVersion);
    map['local_file_version'] = Variable<int>(localFileVersion);
    map['local_edit_at'] = Variable<int>(localEditAt);
    map['local_file_edit_at'] = Variable<int>(localFileEditAt);
    map['local_name'] = Variable<String>(localName);
    map['local_md5'] = Variable<String>(localMd5);
    map['local_locked'] = Variable<int>(localLocked);
    map['local_reminder'] = Variable<String>(localReminder);
    map['local_path'] = Variable<String>(localPath);
    return map;
  }

  LocalRecordsCompanion toCompanion(bool nullToAbsent) {
    return LocalRecordsCompanion(
      uuid: Value(uuid),
      batchNo: Value(batchNo),
      remoteVersion: Value(remoteVersion),
      remoteCreateAt: Value(remoteCreateAt),
      remoteEditAt: Value(remoteEditAt),
      remoteFileEditAt: Value(remoteFileEditAt),
      remoteDeleteAt: Value(remoteDeleteAt),
      remoteLocked: Value(remoteLocked),
      remoteMd5: Value(remoteMd5),
      remoteName: Value(remoteName),
      remotePath: Value(remotePath),
      remoteReminder: Value(remoteReminder),
      remoteFileVersion: Value(remoteFileVersion),
      baseFileVersion: Value(baseFileVersion),
      localEditType: Value(localEditType),
      localVersion: Value(localVersion),
      localFileVersion: Value(localFileVersion),
      localEditAt: Value(localEditAt),
      localFileEditAt: Value(localFileEditAt),
      localName: Value(localName),
      localMd5: Value(localMd5),
      localLocked: Value(localLocked),
      localReminder: Value(localReminder),
      localPath: Value(localPath),
    );
  }

  factory LocalRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalRecord(
      uuid: serializer.fromJson<String>(json['uuid']),
      batchNo: serializer.fromJson<int>(json['batchNo']),
      remoteVersion: serializer.fromJson<int>(json['remoteVersion']),
      remoteCreateAt: serializer.fromJson<int>(json['remoteCreateAt']),
      remoteEditAt: serializer.fromJson<int>(json['remoteEditAt']),
      remoteFileEditAt: serializer.fromJson<int>(json['remoteFileEditAt']),
      remoteDeleteAt: serializer.fromJson<int>(json['remoteDeleteAt']),
      remoteLocked: serializer.fromJson<int>(json['remoteLocked']),
      remoteMd5: serializer.fromJson<String>(json['remoteMd5']),
      remoteName: serializer.fromJson<String>(json['remoteName']),
      remotePath: serializer.fromJson<String>(json['remotePath']),
      remoteReminder: serializer.fromJson<String>(json['remoteReminder']),
      remoteFileVersion: serializer.fromJson<int>(json['remoteFileVersion']),
      baseFileVersion: serializer.fromJson<int>(json['baseFileVersion']),
      localEditType: serializer.fromJson<int>(json['localEditType']),
      localVersion: serializer.fromJson<int>(json['localVersion']),
      localFileVersion: serializer.fromJson<int>(json['localFileVersion']),
      localEditAt: serializer.fromJson<int>(json['localEditAt']),
      localFileEditAt: serializer.fromJson<int>(json['localFileEditAt']),
      localName: serializer.fromJson<String>(json['localName']),
      localMd5: serializer.fromJson<String>(json['localMd5']),
      localLocked: serializer.fromJson<int>(json['localLocked']),
      localReminder: serializer.fromJson<String>(json['localReminder']),
      localPath: serializer.fromJson<String>(json['localPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'batchNo': serializer.toJson<int>(batchNo),
      'remoteVersion': serializer.toJson<int>(remoteVersion),
      'remoteCreateAt': serializer.toJson<int>(remoteCreateAt),
      'remoteEditAt': serializer.toJson<int>(remoteEditAt),
      'remoteFileEditAt': serializer.toJson<int>(remoteFileEditAt),
      'remoteDeleteAt': serializer.toJson<int>(remoteDeleteAt),
      'remoteLocked': serializer.toJson<int>(remoteLocked),
      'remoteMd5': serializer.toJson<String>(remoteMd5),
      'remoteName': serializer.toJson<String>(remoteName),
      'remotePath': serializer.toJson<String>(remotePath),
      'remoteReminder': serializer.toJson<String>(remoteReminder),
      'remoteFileVersion': serializer.toJson<int>(remoteFileVersion),
      'baseFileVersion': serializer.toJson<int>(baseFileVersion),
      'localEditType': serializer.toJson<int>(localEditType),
      'localVersion': serializer.toJson<int>(localVersion),
      'localFileVersion': serializer.toJson<int>(localFileVersion),
      'localEditAt': serializer.toJson<int>(localEditAt),
      'localFileEditAt': serializer.toJson<int>(localFileEditAt),
      'localName': serializer.toJson<String>(localName),
      'localMd5': serializer.toJson<String>(localMd5),
      'localLocked': serializer.toJson<int>(localLocked),
      'localReminder': serializer.toJson<String>(localReminder),
      'localPath': serializer.toJson<String>(localPath),
    };
  }

  LocalRecord copyWith({
    String? uuid,
    int? batchNo,
    int? remoteVersion,
    int? remoteCreateAt,
    int? remoteEditAt,
    int? remoteFileEditAt,
    int? remoteDeleteAt,
    int? remoteLocked,
    String? remoteMd5,
    String? remoteName,
    String? remotePath,
    String? remoteReminder,
    int? remoteFileVersion,
    int? baseFileVersion,
    int? localEditType,
    int? localVersion,
    int? localFileVersion,
    int? localEditAt,
    int? localFileEditAt,
    String? localName,
    String? localMd5,
    int? localLocked,
    String? localReminder,
    String? localPath,
  }) => LocalRecord(
    uuid: uuid ?? this.uuid,
    batchNo: batchNo ?? this.batchNo,
    remoteVersion: remoteVersion ?? this.remoteVersion,
    remoteCreateAt: remoteCreateAt ?? this.remoteCreateAt,
    remoteEditAt: remoteEditAt ?? this.remoteEditAt,
    remoteFileEditAt: remoteFileEditAt ?? this.remoteFileEditAt,
    remoteDeleteAt: remoteDeleteAt ?? this.remoteDeleteAt,
    remoteLocked: remoteLocked ?? this.remoteLocked,
    remoteMd5: remoteMd5 ?? this.remoteMd5,
    remoteName: remoteName ?? this.remoteName,
    remotePath: remotePath ?? this.remotePath,
    remoteReminder: remoteReminder ?? this.remoteReminder,
    remoteFileVersion: remoteFileVersion ?? this.remoteFileVersion,
    baseFileVersion: baseFileVersion ?? this.baseFileVersion,
    localEditType: localEditType ?? this.localEditType,
    localVersion: localVersion ?? this.localVersion,
    localFileVersion: localFileVersion ?? this.localFileVersion,
    localEditAt: localEditAt ?? this.localEditAt,
    localFileEditAt: localFileEditAt ?? this.localFileEditAt,
    localName: localName ?? this.localName,
    localMd5: localMd5 ?? this.localMd5,
    localLocked: localLocked ?? this.localLocked,
    localReminder: localReminder ?? this.localReminder,
    localPath: localPath ?? this.localPath,
  );
  LocalRecord copyWithCompanion(LocalRecordsCompanion data) {
    return LocalRecord(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      batchNo: data.batchNo.present ? data.batchNo.value : this.batchNo,
      remoteVersion: data.remoteVersion.present
          ? data.remoteVersion.value
          : this.remoteVersion,
      remoteCreateAt: data.remoteCreateAt.present
          ? data.remoteCreateAt.value
          : this.remoteCreateAt,
      remoteEditAt: data.remoteEditAt.present
          ? data.remoteEditAt.value
          : this.remoteEditAt,
      remoteFileEditAt: data.remoteFileEditAt.present
          ? data.remoteFileEditAt.value
          : this.remoteFileEditAt,
      remoteDeleteAt: data.remoteDeleteAt.present
          ? data.remoteDeleteAt.value
          : this.remoteDeleteAt,
      remoteLocked: data.remoteLocked.present
          ? data.remoteLocked.value
          : this.remoteLocked,
      remoteMd5: data.remoteMd5.present ? data.remoteMd5.value : this.remoteMd5,
      remoteName: data.remoteName.present
          ? data.remoteName.value
          : this.remoteName,
      remotePath: data.remotePath.present
          ? data.remotePath.value
          : this.remotePath,
      remoteReminder: data.remoteReminder.present
          ? data.remoteReminder.value
          : this.remoteReminder,
      remoteFileVersion: data.remoteFileVersion.present
          ? data.remoteFileVersion.value
          : this.remoteFileVersion,
      baseFileVersion: data.baseFileVersion.present
          ? data.baseFileVersion.value
          : this.baseFileVersion,
      localEditType: data.localEditType.present
          ? data.localEditType.value
          : this.localEditType,
      localVersion: data.localVersion.present
          ? data.localVersion.value
          : this.localVersion,
      localFileVersion: data.localFileVersion.present
          ? data.localFileVersion.value
          : this.localFileVersion,
      localEditAt: data.localEditAt.present
          ? data.localEditAt.value
          : this.localEditAt,
      localFileEditAt: data.localFileEditAt.present
          ? data.localFileEditAt.value
          : this.localFileEditAt,
      localName: data.localName.present ? data.localName.value : this.localName,
      localMd5: data.localMd5.present ? data.localMd5.value : this.localMd5,
      localLocked: data.localLocked.present
          ? data.localLocked.value
          : this.localLocked,
      localReminder: data.localReminder.present
          ? data.localReminder.value
          : this.localReminder,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalRecord(')
          ..write('uuid: $uuid, ')
          ..write('batchNo: $batchNo, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('remoteCreateAt: $remoteCreateAt, ')
          ..write('remoteEditAt: $remoteEditAt, ')
          ..write('remoteFileEditAt: $remoteFileEditAt, ')
          ..write('remoteDeleteAt: $remoteDeleteAt, ')
          ..write('remoteLocked: $remoteLocked, ')
          ..write('remoteMd5: $remoteMd5, ')
          ..write('remoteName: $remoteName, ')
          ..write('remotePath: $remotePath, ')
          ..write('remoteReminder: $remoteReminder, ')
          ..write('remoteFileVersion: $remoteFileVersion, ')
          ..write('baseFileVersion: $baseFileVersion, ')
          ..write('localEditType: $localEditType, ')
          ..write('localVersion: $localVersion, ')
          ..write('localFileVersion: $localFileVersion, ')
          ..write('localEditAt: $localEditAt, ')
          ..write('localFileEditAt: $localFileEditAt, ')
          ..write('localName: $localName, ')
          ..write('localMd5: $localMd5, ')
          ..write('localLocked: $localLocked, ')
          ..write('localReminder: $localReminder, ')
          ..write('localPath: $localPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    uuid,
    batchNo,
    remoteVersion,
    remoteCreateAt,
    remoteEditAt,
    remoteFileEditAt,
    remoteDeleteAt,
    remoteLocked,
    remoteMd5,
    remoteName,
    remotePath,
    remoteReminder,
    remoteFileVersion,
    baseFileVersion,
    localEditType,
    localVersion,
    localFileVersion,
    localEditAt,
    localFileEditAt,
    localName,
    localMd5,
    localLocked,
    localReminder,
    localPath,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalRecord &&
          other.uuid == this.uuid &&
          other.batchNo == this.batchNo &&
          other.remoteVersion == this.remoteVersion &&
          other.remoteCreateAt == this.remoteCreateAt &&
          other.remoteEditAt == this.remoteEditAt &&
          other.remoteFileEditAt == this.remoteFileEditAt &&
          other.remoteDeleteAt == this.remoteDeleteAt &&
          other.remoteLocked == this.remoteLocked &&
          other.remoteMd5 == this.remoteMd5 &&
          other.remoteName == this.remoteName &&
          other.remotePath == this.remotePath &&
          other.remoteReminder == this.remoteReminder &&
          other.remoteFileVersion == this.remoteFileVersion &&
          other.baseFileVersion == this.baseFileVersion &&
          other.localEditType == this.localEditType &&
          other.localVersion == this.localVersion &&
          other.localFileVersion == this.localFileVersion &&
          other.localEditAt == this.localEditAt &&
          other.localFileEditAt == this.localFileEditAt &&
          other.localName == this.localName &&
          other.localMd5 == this.localMd5 &&
          other.localLocked == this.localLocked &&
          other.localReminder == this.localReminder &&
          other.localPath == this.localPath);
}

class LocalRecordsCompanion extends UpdateCompanion<LocalRecord> {
  final Value<String> uuid;
  final Value<int> batchNo;
  final Value<int> remoteVersion;
  final Value<int> remoteCreateAt;
  final Value<int> remoteEditAt;
  final Value<int> remoteFileEditAt;
  final Value<int> remoteDeleteAt;
  final Value<int> remoteLocked;
  final Value<String> remoteMd5;
  final Value<String> remoteName;
  final Value<String> remotePath;
  final Value<String> remoteReminder;
  final Value<int> remoteFileVersion;
  final Value<int> baseFileVersion;
  final Value<int> localEditType;
  final Value<int> localVersion;
  final Value<int> localFileVersion;
  final Value<int> localEditAt;
  final Value<int> localFileEditAt;
  final Value<String> localName;
  final Value<String> localMd5;
  final Value<int> localLocked;
  final Value<String> localReminder;
  final Value<String> localPath;
  final Value<int> rowid;
  const LocalRecordsCompanion({
    this.uuid = const Value.absent(),
    this.batchNo = const Value.absent(),
    this.remoteVersion = const Value.absent(),
    this.remoteCreateAt = const Value.absent(),
    this.remoteEditAt = const Value.absent(),
    this.remoteFileEditAt = const Value.absent(),
    this.remoteDeleteAt = const Value.absent(),
    this.remoteLocked = const Value.absent(),
    this.remoteMd5 = const Value.absent(),
    this.remoteName = const Value.absent(),
    this.remotePath = const Value.absent(),
    this.remoteReminder = const Value.absent(),
    this.remoteFileVersion = const Value.absent(),
    this.baseFileVersion = const Value.absent(),
    this.localEditType = const Value.absent(),
    this.localVersion = const Value.absent(),
    this.localFileVersion = const Value.absent(),
    this.localEditAt = const Value.absent(),
    this.localFileEditAt = const Value.absent(),
    this.localName = const Value.absent(),
    this.localMd5 = const Value.absent(),
    this.localLocked = const Value.absent(),
    this.localReminder = const Value.absent(),
    this.localPath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalRecordsCompanion.insert({
    required String uuid,
    this.batchNo = const Value.absent(),
    this.remoteVersion = const Value.absent(),
    this.remoteCreateAt = const Value.absent(),
    this.remoteEditAt = const Value.absent(),
    this.remoteFileEditAt = const Value.absent(),
    this.remoteDeleteAt = const Value.absent(),
    this.remoteLocked = const Value.absent(),
    this.remoteMd5 = const Value.absent(),
    this.remoteName = const Value.absent(),
    this.remotePath = const Value.absent(),
    this.remoteReminder = const Value.absent(),
    this.remoteFileVersion = const Value.absent(),
    this.baseFileVersion = const Value.absent(),
    this.localEditType = const Value.absent(),
    this.localVersion = const Value.absent(),
    this.localFileVersion = const Value.absent(),
    this.localEditAt = const Value.absent(),
    this.localFileEditAt = const Value.absent(),
    this.localName = const Value.absent(),
    this.localMd5 = const Value.absent(),
    this.localLocked = const Value.absent(),
    this.localReminder = const Value.absent(),
    required String localPath,
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       localPath = Value(localPath);
  static Insertable<LocalRecord> custom({
    Expression<String>? uuid,
    Expression<int>? batchNo,
    Expression<int>? remoteVersion,
    Expression<int>? remoteCreateAt,
    Expression<int>? remoteEditAt,
    Expression<int>? remoteFileEditAt,
    Expression<int>? remoteDeleteAt,
    Expression<int>? remoteLocked,
    Expression<String>? remoteMd5,
    Expression<String>? remoteName,
    Expression<String>? remotePath,
    Expression<String>? remoteReminder,
    Expression<int>? remoteFileVersion,
    Expression<int>? baseFileVersion,
    Expression<int>? localEditType,
    Expression<int>? localVersion,
    Expression<int>? localFileVersion,
    Expression<int>? localEditAt,
    Expression<int>? localFileEditAt,
    Expression<String>? localName,
    Expression<String>? localMd5,
    Expression<int>? localLocked,
    Expression<String>? localReminder,
    Expression<String>? localPath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (batchNo != null) 'batch_no': batchNo,
      if (remoteVersion != null) 'remote_version': remoteVersion,
      if (remoteCreateAt != null) 'remote_create_at': remoteCreateAt,
      if (remoteEditAt != null) 'remote_edit_at': remoteEditAt,
      if (remoteFileEditAt != null) 'remote_file_edit_at': remoteFileEditAt,
      if (remoteDeleteAt != null) 'remote_delete_at': remoteDeleteAt,
      if (remoteLocked != null) 'remote_locked': remoteLocked,
      if (remoteMd5 != null) 'remote_md5': remoteMd5,
      if (remoteName != null) 'remote_name': remoteName,
      if (remotePath != null) 'remote_path': remotePath,
      if (remoteReminder != null) 'remote_reminder': remoteReminder,
      if (remoteFileVersion != null) 'remote_file_version': remoteFileVersion,
      if (baseFileVersion != null) 'base_file_version': baseFileVersion,
      if (localEditType != null) 'local_edit_type': localEditType,
      if (localVersion != null) 'local_version': localVersion,
      if (localFileVersion != null) 'local_file_version': localFileVersion,
      if (localEditAt != null) 'local_edit_at': localEditAt,
      if (localFileEditAt != null) 'local_file_edit_at': localFileEditAt,
      if (localName != null) 'local_name': localName,
      if (localMd5 != null) 'local_md5': localMd5,
      if (localLocked != null) 'local_locked': localLocked,
      if (localReminder != null) 'local_reminder': localReminder,
      if (localPath != null) 'local_path': localPath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalRecordsCompanion copyWith({
    Value<String>? uuid,
    Value<int>? batchNo,
    Value<int>? remoteVersion,
    Value<int>? remoteCreateAt,
    Value<int>? remoteEditAt,
    Value<int>? remoteFileEditAt,
    Value<int>? remoteDeleteAt,
    Value<int>? remoteLocked,
    Value<String>? remoteMd5,
    Value<String>? remoteName,
    Value<String>? remotePath,
    Value<String>? remoteReminder,
    Value<int>? remoteFileVersion,
    Value<int>? baseFileVersion,
    Value<int>? localEditType,
    Value<int>? localVersion,
    Value<int>? localFileVersion,
    Value<int>? localEditAt,
    Value<int>? localFileEditAt,
    Value<String>? localName,
    Value<String>? localMd5,
    Value<int>? localLocked,
    Value<String>? localReminder,
    Value<String>? localPath,
    Value<int>? rowid,
  }) {
    return LocalRecordsCompanion(
      uuid: uuid ?? this.uuid,
      batchNo: batchNo ?? this.batchNo,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      remoteCreateAt: remoteCreateAt ?? this.remoteCreateAt,
      remoteEditAt: remoteEditAt ?? this.remoteEditAt,
      remoteFileEditAt: remoteFileEditAt ?? this.remoteFileEditAt,
      remoteDeleteAt: remoteDeleteAt ?? this.remoteDeleteAt,
      remoteLocked: remoteLocked ?? this.remoteLocked,
      remoteMd5: remoteMd5 ?? this.remoteMd5,
      remoteName: remoteName ?? this.remoteName,
      remotePath: remotePath ?? this.remotePath,
      remoteReminder: remoteReminder ?? this.remoteReminder,
      remoteFileVersion: remoteFileVersion ?? this.remoteFileVersion,
      baseFileVersion: baseFileVersion ?? this.baseFileVersion,
      localEditType: localEditType ?? this.localEditType,
      localVersion: localVersion ?? this.localVersion,
      localFileVersion: localFileVersion ?? this.localFileVersion,
      localEditAt: localEditAt ?? this.localEditAt,
      localFileEditAt: localFileEditAt ?? this.localFileEditAt,
      localName: localName ?? this.localName,
      localMd5: localMd5 ?? this.localMd5,
      localLocked: localLocked ?? this.localLocked,
      localReminder: localReminder ?? this.localReminder,
      localPath: localPath ?? this.localPath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (batchNo.present) {
      map['batch_no'] = Variable<int>(batchNo.value);
    }
    if (remoteVersion.present) {
      map['remote_version'] = Variable<int>(remoteVersion.value);
    }
    if (remoteCreateAt.present) {
      map['remote_create_at'] = Variable<int>(remoteCreateAt.value);
    }
    if (remoteEditAt.present) {
      map['remote_edit_at'] = Variable<int>(remoteEditAt.value);
    }
    if (remoteFileEditAt.present) {
      map['remote_file_edit_at'] = Variable<int>(remoteFileEditAt.value);
    }
    if (remoteDeleteAt.present) {
      map['remote_delete_at'] = Variable<int>(remoteDeleteAt.value);
    }
    if (remoteLocked.present) {
      map['remote_locked'] = Variable<int>(remoteLocked.value);
    }
    if (remoteMd5.present) {
      map['remote_md5'] = Variable<String>(remoteMd5.value);
    }
    if (remoteName.present) {
      map['remote_name'] = Variable<String>(remoteName.value);
    }
    if (remotePath.present) {
      map['remote_path'] = Variable<String>(remotePath.value);
    }
    if (remoteReminder.present) {
      map['remote_reminder'] = Variable<String>(remoteReminder.value);
    }
    if (remoteFileVersion.present) {
      map['remote_file_version'] = Variable<int>(remoteFileVersion.value);
    }
    if (baseFileVersion.present) {
      map['base_file_version'] = Variable<int>(baseFileVersion.value);
    }
    if (localEditType.present) {
      map['local_edit_type'] = Variable<int>(localEditType.value);
    }
    if (localVersion.present) {
      map['local_version'] = Variable<int>(localVersion.value);
    }
    if (localFileVersion.present) {
      map['local_file_version'] = Variable<int>(localFileVersion.value);
    }
    if (localEditAt.present) {
      map['local_edit_at'] = Variable<int>(localEditAt.value);
    }
    if (localFileEditAt.present) {
      map['local_file_edit_at'] = Variable<int>(localFileEditAt.value);
    }
    if (localName.present) {
      map['local_name'] = Variable<String>(localName.value);
    }
    if (localMd5.present) {
      map['local_md5'] = Variable<String>(localMd5.value);
    }
    if (localLocked.present) {
      map['local_locked'] = Variable<int>(localLocked.value);
    }
    if (localReminder.present) {
      map['local_reminder'] = Variable<String>(localReminder.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalRecordsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('batchNo: $batchNo, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('remoteCreateAt: $remoteCreateAt, ')
          ..write('remoteEditAt: $remoteEditAt, ')
          ..write('remoteFileEditAt: $remoteFileEditAt, ')
          ..write('remoteDeleteAt: $remoteDeleteAt, ')
          ..write('remoteLocked: $remoteLocked, ')
          ..write('remoteMd5: $remoteMd5, ')
          ..write('remoteName: $remoteName, ')
          ..write('remotePath: $remotePath, ')
          ..write('remoteReminder: $remoteReminder, ')
          ..write('remoteFileVersion: $remoteFileVersion, ')
          ..write('baseFileVersion: $baseFileVersion, ')
          ..write('localEditType: $localEditType, ')
          ..write('localVersion: $localVersion, ')
          ..write('localFileVersion: $localFileVersion, ')
          ..write('localEditAt: $localEditAt, ')
          ..write('localFileEditAt: $localFileEditAt, ')
          ..write('localName: $localName, ')
          ..write('localMd5: $localMd5, ')
          ..write('localLocked: $localLocked, ')
          ..write('localReminder: $localReminder, ')
          ..write('localPath: $localPath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KVConfigsTable extends KVConfigs
    with TableInfo<$KVConfigsTable, KVConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KVConfigsTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'k_v_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<KVConfig> instance, {
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
  KVConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KVConfig(
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
  $KVConfigsTable createAlias(String alias) {
    return $KVConfigsTable(attachedDatabase, alias);
  }
}

class KVConfig extends DataClass implements Insertable<KVConfig> {
  final String key;
  final String value;
  const KVConfig({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  KVConfigsCompanion toCompanion(bool nullToAbsent) {
    return KVConfigsCompanion(key: Value(key), value: Value(value));
  }

  factory KVConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KVConfig(
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

  KVConfig copyWith({String? key, String? value}) =>
      KVConfig(key: key ?? this.key, value: value ?? this.value);
  KVConfig copyWithCompanion(KVConfigsCompanion data) {
    return KVConfig(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KVConfig(')
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
      (other is KVConfig && other.key == this.key && other.value == this.value);
}

class KVConfigsCompanion extends UpdateCompanion<KVConfig> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const KVConfigsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KVConfigsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<KVConfig> custom({
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

  KVConfigsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return KVConfigsCompanion(
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
    return (StringBuffer('KVConfigsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OperatesTable extends Operates with TableInfo<$OperatesTable, Operate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OperatesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
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
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, type, value, time];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'operates';
  @override
  VerificationContext validateIntegrity(
    Insertable<Operate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Operate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Operate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time'],
      )!,
    );
  }

  @override
  $OperatesTable createAlias(String alias) {
    return $OperatesTable(attachedDatabase, alias);
  }
}

class Operate extends DataClass implements Insertable<Operate> {
  final int id;
  final String type;
  final String value;
  final int time;
  const Operate({
    required this.id,
    required this.type,
    required this.value,
    required this.time,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<String>(type);
    map['value'] = Variable<String>(value);
    map['time'] = Variable<int>(time);
    return map;
  }

  OperatesCompanion toCompanion(bool nullToAbsent) {
    return OperatesCompanion(
      id: Value(id),
      type: Value(type),
      value: Value(value),
      time: Value(time),
    );
  }

  factory Operate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Operate(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      value: serializer.fromJson<String>(json['value']),
      time: serializer.fromJson<int>(json['time']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(type),
      'value': serializer.toJson<String>(value),
      'time': serializer.toJson<int>(time),
    };
  }

  Operate copyWith({int? id, String? type, String? value, int? time}) =>
      Operate(
        id: id ?? this.id,
        type: type ?? this.type,
        value: value ?? this.value,
        time: time ?? this.time,
      );
  Operate copyWithCompanion(OperatesCompanion data) {
    return Operate(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      value: data.value.present ? data.value.value : this.value,
      time: data.time.present ? data.time.value : this.time,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Operate(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('value: $value, ')
          ..write('time: $time')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, type, value, time);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Operate &&
          other.id == this.id &&
          other.type == this.type &&
          other.value == this.value &&
          other.time == this.time);
}

class OperatesCompanion extends UpdateCompanion<Operate> {
  final Value<int> id;
  final Value<String> type;
  final Value<String> value;
  final Value<int> time;
  const OperatesCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.value = const Value.absent(),
    this.time = const Value.absent(),
  });
  OperatesCompanion.insert({
    this.id = const Value.absent(),
    required String type,
    required String value,
    required int time,
  }) : type = Value(type),
       value = Value(value),
       time = Value(time);
  static Insertable<Operate> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<String>? value,
    Expression<int>? time,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (value != null) 'value': value,
      if (time != null) 'time': time,
    });
  }

  OperatesCompanion copyWith({
    Value<int>? id,
    Value<String>? type,
    Value<String>? value,
    Value<int>? time,
  }) {
    return OperatesCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      value: value ?? this.value,
      time: time ?? this.time,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OperatesCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('value: $value, ')
          ..write('time: $time')
          ..write(')'))
        .toString();
  }
}

class PathRecordCount extends DataClass {
  final String localPath;
  final int? recordCount;
  const PathRecordCount({required this.localPath, this.recordCount});
  factory PathRecordCount.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PathRecordCount(
      localPath: serializer.fromJson<String>(json['localPath']),
      recordCount: serializer.fromJson<int?>(json['recordCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localPath': serializer.toJson<String>(localPath),
      'recordCount': serializer.toJson<int?>(recordCount),
    };
  }

  PathRecordCount copyWith({
    String? localPath,
    Value<int?> recordCount = const Value.absent(),
  }) => PathRecordCount(
    localPath: localPath ?? this.localPath,
    recordCount: recordCount.present ? recordCount.value : this.recordCount,
  );
  @override
  String toString() {
    return (StringBuffer('PathRecordCount(')
          ..write('localPath: $localPath, ')
          ..write('recordCount: $recordCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(localPath, recordCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PathRecordCount &&
          other.localPath == this.localPath &&
          other.recordCount == this.recordCount);
}

class $PathRecordCountsView
    extends ViewInfo<$PathRecordCountsView, PathRecordCount>
    implements HasResultSet {
  final String? _alias;
  @override
  final _$AppDatabase attachedDatabase;
  $PathRecordCountsView(this.attachedDatabase, [this._alias]);
  $LocalRecordsTable get records =>
      attachedDatabase.localRecords.createAlias('t0');
  @override
  List<GeneratedColumn> get $columns => [localPath, recordCount];
  @override
  String get aliasedName => _alias ?? entityName;
  @override
  String get entityName => 'PathRecordCounts';
  @override
  Map<SqlDialect, String>? get createViewStatements => null;
  @override
  $PathRecordCountsView get asDslTable => this;
  @override
  PathRecordCount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PathRecordCount(
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      recordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}record_count'],
      ),
    );
  }

  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    generatedAs: GeneratedAs(records.localPath, false),
    type: DriftSqlType.string,
  );
  late final GeneratedColumn<int> recordCount = GeneratedColumn<int>(
    'record_count',
    aliasedName,
    true,
    generatedAs: GeneratedAs(BaseAggregate(records.uuid).count(), false),
    type: DriftSqlType.int,
  );
  @override
  $PathRecordCountsView createAlias(String alias) {
    return $PathRecordCountsView(attachedDatabase, alias);
  }

  @override
  Query? get query =>
      (attachedDatabase.selectOnly(records)..addColumns($columns))
        ..groupBy([records.localPath]);
  @override
  Set<String> get readTables => const {'local_records'};
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalRecordsTable localRecords = $LocalRecordsTable(this);
  late final $KVConfigsTable kVConfigs = $KVConfigsTable(this);
  late final $OperatesTable operates = $OperatesTable(this);
  late final $PathRecordCountsView pathRecordCounts = $PathRecordCountsView(
    this,
  );
  late final Index recordsPathIdx = Index(
    'records_path_idx',
    'CREATE INDEX records_path_idx ON local_records (local_path)',
  );
  late final Index recordsVersionIdx = Index(
    'records_version_idx',
    'CREATE INDEX records_version_idx ON local_records (remote_version)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localRecords,
    kVConfigs,
    operates,
    pathRecordCounts,
    recordsPathIdx,
    recordsVersionIdx,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$LocalRecordsTableCreateCompanionBuilder =
    LocalRecordsCompanion Function({
      required String uuid,
      Value<int> batchNo,
      Value<int> remoteVersion,
      Value<int> remoteCreateAt,
      Value<int> remoteEditAt,
      Value<int> remoteFileEditAt,
      Value<int> remoteDeleteAt,
      Value<int> remoteLocked,
      Value<String> remoteMd5,
      Value<String> remoteName,
      Value<String> remotePath,
      Value<String> remoteReminder,
      Value<int> remoteFileVersion,
      Value<int> baseFileVersion,
      Value<int> localEditType,
      Value<int> localVersion,
      Value<int> localFileVersion,
      Value<int> localEditAt,
      Value<int> localFileEditAt,
      Value<String> localName,
      Value<String> localMd5,
      Value<int> localLocked,
      Value<String> localReminder,
      required String localPath,
      Value<int> rowid,
    });
typedef $$LocalRecordsTableUpdateCompanionBuilder =
    LocalRecordsCompanion Function({
      Value<String> uuid,
      Value<int> batchNo,
      Value<int> remoteVersion,
      Value<int> remoteCreateAt,
      Value<int> remoteEditAt,
      Value<int> remoteFileEditAt,
      Value<int> remoteDeleteAt,
      Value<int> remoteLocked,
      Value<String> remoteMd5,
      Value<String> remoteName,
      Value<String> remotePath,
      Value<String> remoteReminder,
      Value<int> remoteFileVersion,
      Value<int> baseFileVersion,
      Value<int> localEditType,
      Value<int> localVersion,
      Value<int> localFileVersion,
      Value<int> localEditAt,
      Value<int> localFileEditAt,
      Value<String> localName,
      Value<String> localMd5,
      Value<int> localLocked,
      Value<String> localReminder,
      Value<String> localPath,
      Value<int> rowid,
    });

class $$LocalRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalRecordsTable> {
  $$LocalRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get batchNo => $composableBuilder(
    column: $table.batchNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteCreateAt => $composableBuilder(
    column: $table.remoteCreateAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteEditAt => $composableBuilder(
    column: $table.remoteEditAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteFileEditAt => $composableBuilder(
    column: $table.remoteFileEditAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteDeleteAt => $composableBuilder(
    column: $table.remoteDeleteAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteLocked => $composableBuilder(
    column: $table.remoteLocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteMd5 => $composableBuilder(
    column: $table.remoteMd5,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteName => $composableBuilder(
    column: $table.remoteName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remotePath => $composableBuilder(
    column: $table.remotePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteReminder => $composableBuilder(
    column: $table.remoteReminder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteFileVersion => $composableBuilder(
    column: $table.remoteFileVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseFileVersion => $composableBuilder(
    column: $table.baseFileVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localEditType => $composableBuilder(
    column: $table.localEditType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localFileVersion => $composableBuilder(
    column: $table.localFileVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localEditAt => $composableBuilder(
    column: $table.localEditAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localFileEditAt => $composableBuilder(
    column: $table.localFileEditAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localName => $composableBuilder(
    column: $table.localName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localMd5 => $composableBuilder(
    column: $table.localMd5,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localLocked => $composableBuilder(
    column: $table.localLocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localReminder => $composableBuilder(
    column: $table.localReminder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalRecordsTable> {
  $$LocalRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get batchNo => $composableBuilder(
    column: $table.batchNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteCreateAt => $composableBuilder(
    column: $table.remoteCreateAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteEditAt => $composableBuilder(
    column: $table.remoteEditAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteFileEditAt => $composableBuilder(
    column: $table.remoteFileEditAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteDeleteAt => $composableBuilder(
    column: $table.remoteDeleteAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteLocked => $composableBuilder(
    column: $table.remoteLocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteMd5 => $composableBuilder(
    column: $table.remoteMd5,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteName => $composableBuilder(
    column: $table.remoteName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remotePath => $composableBuilder(
    column: $table.remotePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteReminder => $composableBuilder(
    column: $table.remoteReminder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteFileVersion => $composableBuilder(
    column: $table.remoteFileVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseFileVersion => $composableBuilder(
    column: $table.baseFileVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localEditType => $composableBuilder(
    column: $table.localEditType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localFileVersion => $composableBuilder(
    column: $table.localFileVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localEditAt => $composableBuilder(
    column: $table.localEditAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localFileEditAt => $composableBuilder(
    column: $table.localFileEditAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localName => $composableBuilder(
    column: $table.localName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localMd5 => $composableBuilder(
    column: $table.localMd5,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localLocked => $composableBuilder(
    column: $table.localLocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localReminder => $composableBuilder(
    column: $table.localReminder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalRecordsTable> {
  $$LocalRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<int> get batchNo =>
      $composableBuilder(column: $table.batchNo, builder: (column) => column);

  GeneratedColumn<int> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteCreateAt => $composableBuilder(
    column: $table.remoteCreateAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteEditAt => $composableBuilder(
    column: $table.remoteEditAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteFileEditAt => $composableBuilder(
    column: $table.remoteFileEditAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteDeleteAt => $composableBuilder(
    column: $table.remoteDeleteAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteLocked => $composableBuilder(
    column: $table.remoteLocked,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteMd5 =>
      $composableBuilder(column: $table.remoteMd5, builder: (column) => column);

  GeneratedColumn<String> get remoteName => $composableBuilder(
    column: $table.remoteName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remotePath => $composableBuilder(
    column: $table.remotePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteReminder => $composableBuilder(
    column: $table.remoteReminder,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteFileVersion => $composableBuilder(
    column: $table.remoteFileVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get baseFileVersion => $composableBuilder(
    column: $table.baseFileVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get localEditType => $composableBuilder(
    column: $table.localEditType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get localFileVersion => $composableBuilder(
    column: $table.localFileVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get localEditAt => $composableBuilder(
    column: $table.localEditAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get localFileEditAt => $composableBuilder(
    column: $table.localFileEditAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localName =>
      $composableBuilder(column: $table.localName, builder: (column) => column);

  GeneratedColumn<String> get localMd5 =>
      $composableBuilder(column: $table.localMd5, builder: (column) => column);

  GeneratedColumn<int> get localLocked => $composableBuilder(
    column: $table.localLocked,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localReminder => $composableBuilder(
    column: $table.localReminder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);
}

class $$LocalRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalRecordsTable,
          LocalRecord,
          $$LocalRecordsTableFilterComposer,
          $$LocalRecordsTableOrderingComposer,
          $$LocalRecordsTableAnnotationComposer,
          $$LocalRecordsTableCreateCompanionBuilder,
          $$LocalRecordsTableUpdateCompanionBuilder,
          (
            LocalRecord,
            BaseReferences<_$AppDatabase, $LocalRecordsTable, LocalRecord>,
          ),
          LocalRecord,
          PrefetchHooks Function()
        > {
  $$LocalRecordsTableTableManager(_$AppDatabase db, $LocalRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<int> batchNo = const Value.absent(),
                Value<int> remoteVersion = const Value.absent(),
                Value<int> remoteCreateAt = const Value.absent(),
                Value<int> remoteEditAt = const Value.absent(),
                Value<int> remoteFileEditAt = const Value.absent(),
                Value<int> remoteDeleteAt = const Value.absent(),
                Value<int> remoteLocked = const Value.absent(),
                Value<String> remoteMd5 = const Value.absent(),
                Value<String> remoteName = const Value.absent(),
                Value<String> remotePath = const Value.absent(),
                Value<String> remoteReminder = const Value.absent(),
                Value<int> remoteFileVersion = const Value.absent(),
                Value<int> baseFileVersion = const Value.absent(),
                Value<int> localEditType = const Value.absent(),
                Value<int> localVersion = const Value.absent(),
                Value<int> localFileVersion = const Value.absent(),
                Value<int> localEditAt = const Value.absent(),
                Value<int> localFileEditAt = const Value.absent(),
                Value<String> localName = const Value.absent(),
                Value<String> localMd5 = const Value.absent(),
                Value<int> localLocked = const Value.absent(),
                Value<String> localReminder = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalRecordsCompanion(
                uuid: uuid,
                batchNo: batchNo,
                remoteVersion: remoteVersion,
                remoteCreateAt: remoteCreateAt,
                remoteEditAt: remoteEditAt,
                remoteFileEditAt: remoteFileEditAt,
                remoteDeleteAt: remoteDeleteAt,
                remoteLocked: remoteLocked,
                remoteMd5: remoteMd5,
                remoteName: remoteName,
                remotePath: remotePath,
                remoteReminder: remoteReminder,
                remoteFileVersion: remoteFileVersion,
                baseFileVersion: baseFileVersion,
                localEditType: localEditType,
                localVersion: localVersion,
                localFileVersion: localFileVersion,
                localEditAt: localEditAt,
                localFileEditAt: localFileEditAt,
                localName: localName,
                localMd5: localMd5,
                localLocked: localLocked,
                localReminder: localReminder,
                localPath: localPath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                Value<int> batchNo = const Value.absent(),
                Value<int> remoteVersion = const Value.absent(),
                Value<int> remoteCreateAt = const Value.absent(),
                Value<int> remoteEditAt = const Value.absent(),
                Value<int> remoteFileEditAt = const Value.absent(),
                Value<int> remoteDeleteAt = const Value.absent(),
                Value<int> remoteLocked = const Value.absent(),
                Value<String> remoteMd5 = const Value.absent(),
                Value<String> remoteName = const Value.absent(),
                Value<String> remotePath = const Value.absent(),
                Value<String> remoteReminder = const Value.absent(),
                Value<int> remoteFileVersion = const Value.absent(),
                Value<int> baseFileVersion = const Value.absent(),
                Value<int> localEditType = const Value.absent(),
                Value<int> localVersion = const Value.absent(),
                Value<int> localFileVersion = const Value.absent(),
                Value<int> localEditAt = const Value.absent(),
                Value<int> localFileEditAt = const Value.absent(),
                Value<String> localName = const Value.absent(),
                Value<String> localMd5 = const Value.absent(),
                Value<int> localLocked = const Value.absent(),
                Value<String> localReminder = const Value.absent(),
                required String localPath,
                Value<int> rowid = const Value.absent(),
              }) => LocalRecordsCompanion.insert(
                uuid: uuid,
                batchNo: batchNo,
                remoteVersion: remoteVersion,
                remoteCreateAt: remoteCreateAt,
                remoteEditAt: remoteEditAt,
                remoteFileEditAt: remoteFileEditAt,
                remoteDeleteAt: remoteDeleteAt,
                remoteLocked: remoteLocked,
                remoteMd5: remoteMd5,
                remoteName: remoteName,
                remotePath: remotePath,
                remoteReminder: remoteReminder,
                remoteFileVersion: remoteFileVersion,
                baseFileVersion: baseFileVersion,
                localEditType: localEditType,
                localVersion: localVersion,
                localFileVersion: localFileVersion,
                localEditAt: localEditAt,
                localFileEditAt: localFileEditAt,
                localName: localName,
                localMd5: localMd5,
                localLocked: localLocked,
                localReminder: localReminder,
                localPath: localPath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalRecordsTable, LocalRecord>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalRecordsTable,
                    LocalRecord
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalRecordsTable,
      LocalRecord,
      $$LocalRecordsTableFilterComposer,
      $$LocalRecordsTableOrderingComposer,
      $$LocalRecordsTableAnnotationComposer,
      $$LocalRecordsTableCreateCompanionBuilder,
      $$LocalRecordsTableUpdateCompanionBuilder,
      (
        LocalRecord,
        BaseReferences<_$AppDatabase, $LocalRecordsTable, LocalRecord>,
      ),
      LocalRecord,
      PrefetchHooks Function()
    >;
typedef $$KVConfigsTableCreateCompanionBuilder =
    KVConfigsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$KVConfigsTableUpdateCompanionBuilder =
    KVConfigsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$KVConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $KVConfigsTable> {
  $$KVConfigsTableFilterComposer({
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

class $$KVConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $KVConfigsTable> {
  $$KVConfigsTableOrderingComposer({
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

class $$KVConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $KVConfigsTable> {
  $$KVConfigsTableAnnotationComposer({
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

class $$KVConfigsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KVConfigsTable,
          KVConfig,
          $$KVConfigsTableFilterComposer,
          $$KVConfigsTableOrderingComposer,
          $$KVConfigsTableAnnotationComposer,
          $$KVConfigsTableCreateCompanionBuilder,
          $$KVConfigsTableUpdateCompanionBuilder,
          (KVConfig, BaseReferences<_$AppDatabase, $KVConfigsTable, KVConfig>),
          KVConfig,
          PrefetchHooks Function()
        > {
  $$KVConfigsTableTableManager(_$AppDatabase db, $KVConfigsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KVConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KVConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KVConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KVConfigsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => KVConfigsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KVConfigsTable, KVConfig>(table),
                  BaseReferences<_$AppDatabase, $KVConfigsTable, KVConfig>(
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

typedef $$KVConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KVConfigsTable,
      KVConfig,
      $$KVConfigsTableFilterComposer,
      $$KVConfigsTableOrderingComposer,
      $$KVConfigsTableAnnotationComposer,
      $$KVConfigsTableCreateCompanionBuilder,
      $$KVConfigsTableUpdateCompanionBuilder,
      (KVConfig, BaseReferences<_$AppDatabase, $KVConfigsTable, KVConfig>),
      KVConfig,
      PrefetchHooks Function()
    >;
typedef $$OperatesTableCreateCompanionBuilder =
    OperatesCompanion Function({
      Value<int> id,
      required String type,
      required String value,
      required int time,
    });
typedef $$OperatesTableUpdateCompanionBuilder =
    OperatesCompanion Function({
      Value<int> id,
      Value<String> type,
      Value<String> value,
      Value<int> time,
    });

class $$OperatesTableFilterComposer
    extends Composer<_$AppDatabase, $OperatesTable> {
  $$OperatesTableFilterComposer({
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

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OperatesTableOrderingComposer
    extends Composer<_$AppDatabase, $OperatesTable> {
  $$OperatesTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OperatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OperatesTable> {
  $$OperatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);
}

class $$OperatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OperatesTable,
          Operate,
          $$OperatesTableFilterComposer,
          $$OperatesTableOrderingComposer,
          $$OperatesTableAnnotationComposer,
          $$OperatesTableCreateCompanionBuilder,
          $$OperatesTableUpdateCompanionBuilder,
          (Operate, BaseReferences<_$AppDatabase, $OperatesTable, Operate>),
          Operate,
          PrefetchHooks Function()
        > {
  $$OperatesTableTableManager(_$AppDatabase db, $OperatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OperatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OperatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OperatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> time = const Value.absent(),
              }) => OperatesCompanion(
                id: id,
                type: type,
                value: value,
                time: time,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String type,
                required String value,
                required int time,
              }) => OperatesCompanion.insert(
                id: id,
                type: type,
                value: value,
                time: time,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OperatesTable, Operate>(table),
                  BaseReferences<_$AppDatabase, $OperatesTable, Operate>(
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

typedef $$OperatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OperatesTable,
      Operate,
      $$OperatesTableFilterComposer,
      $$OperatesTableOrderingComposer,
      $$OperatesTableAnnotationComposer,
      $$OperatesTableCreateCompanionBuilder,
      $$OperatesTableUpdateCompanionBuilder,
      (Operate, BaseReferences<_$AppDatabase, $OperatesTable, Operate>),
      Operate,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalRecordsTableTableManager get localRecords =>
      $$LocalRecordsTableTableManager(_db, _db.localRecords);
  $$KVConfigsTableTableManager get kVConfigs =>
      $$KVConfigsTableTableManager(_db, _db.kVConfigs);
  $$OperatesTableTableManager get operates =>
      $$OperatesTableTableManager(_db, _db.operates);
}

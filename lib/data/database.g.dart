// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TownsTable extends Towns with TableInfo<$TownsTable, TownRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TownsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workerCountMeta = const VerificationMeta(
    'workerCount',
  );
  @override
  late final GeneratedColumn<int> workerCount = GeneratedColumn<int>(
    'worker_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plotsUnlockedMeta = const VerificationMeta(
    'plotsUnlocked',
  );
  @override
  late final GeneratedColumn<int> plotsUnlocked = GeneratedColumn<int>(
    'plots_unlocked',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xpMeta = const VerificationMeta('xp');
  @override
  late final GeneratedColumn<int> xp = GeneratedColumn<int>(
    'xp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _streakCountMeta = const VerificationMeta(
    'streakCount',
  );
  @override
  late final GeneratedColumn<int> streakCount = GeneratedColumn<int>(
    'streak_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastStreakDateMeta = const VerificationMeta(
    'lastStreakDate',
  );
  @override
  late final GeneratedColumn<String> lastStreakDate = GeneratedColumn<String>(
    'last_streak_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastPlotGrantDateMeta = const VerificationMeta(
    'lastPlotGrantDate',
  );
  @override
  late final GeneratedColumn<String> lastPlotGrantDate =
      GeneratedColumn<String>(
        'last_plot_grant_date',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _inRecoveryModeMeta = const VerificationMeta(
    'inRecoveryMode',
  );
  @override
  late final GeneratedColumn<bool> inRecoveryMode = GeneratedColumn<bool>(
    'in_recovery_mode',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("in_recovery_mode" IN (0, 1))',
    ),
  );
  static const VerificationMeta _onboardingDoneMeta = const VerificationMeta(
    'onboardingDone',
  );
  @override
  late final GeneratedColumn<bool> onboardingDone = GeneratedColumn<bool>(
    'onboarding_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("onboarding_done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _lastDurationMinutesMeta =
      const VerificationMeta('lastDurationMinutes');
  @override
  late final GeneratedColumn<int> lastDurationMinutes = GeneratedColumn<int>(
    'last_duration_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(25),
  );
  static const VerificationMeta _tipPassShownMeta = const VerificationMeta(
    'tipPassShown',
  );
  @override
  late final GeneratedColumn<bool> tipPassShown = GeneratedColumn<bool>(
    'tip_pass_shown',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tip_pass_shown" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _tipGrowthShownMeta = const VerificationMeta(
    'tipGrowthShown',
  );
  @override
  late final GeneratedColumn<bool> tipGrowthShown = GeneratedColumn<bool>(
    'tip_growth_shown',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tip_growth_shown" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _tipRecoveryShownMeta = const VerificationMeta(
    'tipRecoveryShown',
  );
  @override
  late final GeneratedColumn<bool> tipRecoveryShown = GeneratedColumn<bool>(
    'tip_recovery_shown',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tip_recovery_shown" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _notificationNoteShownMeta =
      const VerificationMeta('notificationNoteShown');
  @override
  late final GeneratedColumn<bool> notificationNoteShown =
      GeneratedColumn<bool>(
        'notification_note_shown',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("notification_note_shown" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workerCount,
    plotsUnlocked,
    xp,
    streakCount,
    lastStreakDate,
    lastPlotGrantDate,
    inRecoveryMode,
    onboardingDone,
    createdAt,
    lastDurationMinutes,
    tipPassShown,
    tipGrowthShown,
    tipRecoveryShown,
    notificationNoteShown,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'towns';
  @override
  VerificationContext validateIntegrity(
    Insertable<TownRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('worker_count')) {
      context.handle(
        _workerCountMeta,
        workerCount.isAcceptableOrUnknown(
          data['worker_count']!,
          _workerCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workerCountMeta);
    }
    if (data.containsKey('plots_unlocked')) {
      context.handle(
        _plotsUnlockedMeta,
        plotsUnlocked.isAcceptableOrUnknown(
          data['plots_unlocked']!,
          _plotsUnlockedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_plotsUnlockedMeta);
    }
    if (data.containsKey('xp')) {
      context.handle(_xpMeta, xp.isAcceptableOrUnknown(data['xp']!, _xpMeta));
    } else if (isInserting) {
      context.missing(_xpMeta);
    }
    if (data.containsKey('streak_count')) {
      context.handle(
        _streakCountMeta,
        streakCount.isAcceptableOrUnknown(
          data['streak_count']!,
          _streakCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_streakCountMeta);
    }
    if (data.containsKey('last_streak_date')) {
      context.handle(
        _lastStreakDateMeta,
        lastStreakDate.isAcceptableOrUnknown(
          data['last_streak_date']!,
          _lastStreakDateMeta,
        ),
      );
    }
    if (data.containsKey('last_plot_grant_date')) {
      context.handle(
        _lastPlotGrantDateMeta,
        lastPlotGrantDate.isAcceptableOrUnknown(
          data['last_plot_grant_date']!,
          _lastPlotGrantDateMeta,
        ),
      );
    }
    if (data.containsKey('in_recovery_mode')) {
      context.handle(
        _inRecoveryModeMeta,
        inRecoveryMode.isAcceptableOrUnknown(
          data['in_recovery_mode']!,
          _inRecoveryModeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_inRecoveryModeMeta);
    }
    if (data.containsKey('onboarding_done')) {
      context.handle(
        _onboardingDoneMeta,
        onboardingDone.isAcceptableOrUnknown(
          data['onboarding_done']!,
          _onboardingDoneMeta,
        ),
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
    if (data.containsKey('last_duration_minutes')) {
      context.handle(
        _lastDurationMinutesMeta,
        lastDurationMinutes.isAcceptableOrUnknown(
          data['last_duration_minutes']!,
          _lastDurationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('tip_pass_shown')) {
      context.handle(
        _tipPassShownMeta,
        tipPassShown.isAcceptableOrUnknown(
          data['tip_pass_shown']!,
          _tipPassShownMeta,
        ),
      );
    }
    if (data.containsKey('tip_growth_shown')) {
      context.handle(
        _tipGrowthShownMeta,
        tipGrowthShown.isAcceptableOrUnknown(
          data['tip_growth_shown']!,
          _tipGrowthShownMeta,
        ),
      );
    }
    if (data.containsKey('tip_recovery_shown')) {
      context.handle(
        _tipRecoveryShownMeta,
        tipRecoveryShown.isAcceptableOrUnknown(
          data['tip_recovery_shown']!,
          _tipRecoveryShownMeta,
        ),
      );
    }
    if (data.containsKey('notification_note_shown')) {
      context.handle(
        _notificationNoteShownMeta,
        notificationNoteShown.isAcceptableOrUnknown(
          data['notification_note_shown']!,
          _notificationNoteShownMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TownRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TownRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      workerCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}worker_count'],
      )!,
      plotsUnlocked: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plots_unlocked'],
      )!,
      xp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}xp'],
      )!,
      streakCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}streak_count'],
      )!,
      lastStreakDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_streak_date'],
      ),
      lastPlotGrantDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_plot_grant_date'],
      ),
      inRecoveryMode: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}in_recovery_mode'],
      )!,
      onboardingDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}onboarding_done'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      lastDurationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_duration_minutes'],
      )!,
      tipPassShown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tip_pass_shown'],
      )!,
      tipGrowthShown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tip_growth_shown'],
      )!,
      tipRecoveryShown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tip_recovery_shown'],
      )!,
      notificationNoteShown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notification_note_shown'],
      )!,
    );
  }

  @override
  $TownsTable createAlias(String alias) {
    return $TownsTable(attachedDatabase, alias);
  }
}

class TownRow extends DataClass implements Insertable<TownRow> {
  final int id;
  final int workerCount;
  final int plotsUnlocked;
  final int xp;
  final int streakCount;
  final String? lastStreakDate;
  final String? lastPlotGrantDate;
  final bool inRecoveryMode;
  final bool onboardingDone;
  final int createdAt;
  final int lastDurationMinutes;
  final bool tipPassShown;
  final bool tipGrowthShown;
  final bool tipRecoveryShown;
  final bool notificationNoteShown;
  const TownRow({
    required this.id,
    required this.workerCount,
    required this.plotsUnlocked,
    required this.xp,
    required this.streakCount,
    this.lastStreakDate,
    this.lastPlotGrantDate,
    required this.inRecoveryMode,
    required this.onboardingDone,
    required this.createdAt,
    required this.lastDurationMinutes,
    required this.tipPassShown,
    required this.tipGrowthShown,
    required this.tipRecoveryShown,
    required this.notificationNoteShown,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['worker_count'] = Variable<int>(workerCount);
    map['plots_unlocked'] = Variable<int>(plotsUnlocked);
    map['xp'] = Variable<int>(xp);
    map['streak_count'] = Variable<int>(streakCount);
    if (!nullToAbsent || lastStreakDate != null) {
      map['last_streak_date'] = Variable<String>(lastStreakDate);
    }
    if (!nullToAbsent || lastPlotGrantDate != null) {
      map['last_plot_grant_date'] = Variable<String>(lastPlotGrantDate);
    }
    map['in_recovery_mode'] = Variable<bool>(inRecoveryMode);
    map['onboarding_done'] = Variable<bool>(onboardingDone);
    map['created_at'] = Variable<int>(createdAt);
    map['last_duration_minutes'] = Variable<int>(lastDurationMinutes);
    map['tip_pass_shown'] = Variable<bool>(tipPassShown);
    map['tip_growth_shown'] = Variable<bool>(tipGrowthShown);
    map['tip_recovery_shown'] = Variable<bool>(tipRecoveryShown);
    map['notification_note_shown'] = Variable<bool>(notificationNoteShown);
    return map;
  }

  TownsCompanion toCompanion(bool nullToAbsent) {
    return TownsCompanion(
      id: Value(id),
      workerCount: Value(workerCount),
      plotsUnlocked: Value(plotsUnlocked),
      xp: Value(xp),
      streakCount: Value(streakCount),
      lastStreakDate: lastStreakDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastStreakDate),
      lastPlotGrantDate: lastPlotGrantDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlotGrantDate),
      inRecoveryMode: Value(inRecoveryMode),
      onboardingDone: Value(onboardingDone),
      createdAt: Value(createdAt),
      lastDurationMinutes: Value(lastDurationMinutes),
      tipPassShown: Value(tipPassShown),
      tipGrowthShown: Value(tipGrowthShown),
      tipRecoveryShown: Value(tipRecoveryShown),
      notificationNoteShown: Value(notificationNoteShown),
    );
  }

  factory TownRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TownRow(
      id: serializer.fromJson<int>(json['id']),
      workerCount: serializer.fromJson<int>(json['workerCount']),
      plotsUnlocked: serializer.fromJson<int>(json['plotsUnlocked']),
      xp: serializer.fromJson<int>(json['xp']),
      streakCount: serializer.fromJson<int>(json['streakCount']),
      lastStreakDate: serializer.fromJson<String?>(json['lastStreakDate']),
      lastPlotGrantDate: serializer.fromJson<String?>(
        json['lastPlotGrantDate'],
      ),
      inRecoveryMode: serializer.fromJson<bool>(json['inRecoveryMode']),
      onboardingDone: serializer.fromJson<bool>(json['onboardingDone']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      lastDurationMinutes: serializer.fromJson<int>(
        json['lastDurationMinutes'],
      ),
      tipPassShown: serializer.fromJson<bool>(json['tipPassShown']),
      tipGrowthShown: serializer.fromJson<bool>(json['tipGrowthShown']),
      tipRecoveryShown: serializer.fromJson<bool>(json['tipRecoveryShown']),
      notificationNoteShown: serializer.fromJson<bool>(
        json['notificationNoteShown'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'workerCount': serializer.toJson<int>(workerCount),
      'plotsUnlocked': serializer.toJson<int>(plotsUnlocked),
      'xp': serializer.toJson<int>(xp),
      'streakCount': serializer.toJson<int>(streakCount),
      'lastStreakDate': serializer.toJson<String?>(lastStreakDate),
      'lastPlotGrantDate': serializer.toJson<String?>(lastPlotGrantDate),
      'inRecoveryMode': serializer.toJson<bool>(inRecoveryMode),
      'onboardingDone': serializer.toJson<bool>(onboardingDone),
      'createdAt': serializer.toJson<int>(createdAt),
      'lastDurationMinutes': serializer.toJson<int>(lastDurationMinutes),
      'tipPassShown': serializer.toJson<bool>(tipPassShown),
      'tipGrowthShown': serializer.toJson<bool>(tipGrowthShown),
      'tipRecoveryShown': serializer.toJson<bool>(tipRecoveryShown),
      'notificationNoteShown': serializer.toJson<bool>(notificationNoteShown),
    };
  }

  TownRow copyWith({
    int? id,
    int? workerCount,
    int? plotsUnlocked,
    int? xp,
    int? streakCount,
    Value<String?> lastStreakDate = const Value.absent(),
    Value<String?> lastPlotGrantDate = const Value.absent(),
    bool? inRecoveryMode,
    bool? onboardingDone,
    int? createdAt,
    int? lastDurationMinutes,
    bool? tipPassShown,
    bool? tipGrowthShown,
    bool? tipRecoveryShown,
    bool? notificationNoteShown,
  }) => TownRow(
    id: id ?? this.id,
    workerCount: workerCount ?? this.workerCount,
    plotsUnlocked: plotsUnlocked ?? this.plotsUnlocked,
    xp: xp ?? this.xp,
    streakCount: streakCount ?? this.streakCount,
    lastStreakDate: lastStreakDate.present
        ? lastStreakDate.value
        : this.lastStreakDate,
    lastPlotGrantDate: lastPlotGrantDate.present
        ? lastPlotGrantDate.value
        : this.lastPlotGrantDate,
    inRecoveryMode: inRecoveryMode ?? this.inRecoveryMode,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    createdAt: createdAt ?? this.createdAt,
    lastDurationMinutes: lastDurationMinutes ?? this.lastDurationMinutes,
    tipPassShown: tipPassShown ?? this.tipPassShown,
    tipGrowthShown: tipGrowthShown ?? this.tipGrowthShown,
    tipRecoveryShown: tipRecoveryShown ?? this.tipRecoveryShown,
    notificationNoteShown: notificationNoteShown ?? this.notificationNoteShown,
  );
  TownRow copyWithCompanion(TownsCompanion data) {
    return TownRow(
      id: data.id.present ? data.id.value : this.id,
      workerCount: data.workerCount.present
          ? data.workerCount.value
          : this.workerCount,
      plotsUnlocked: data.plotsUnlocked.present
          ? data.plotsUnlocked.value
          : this.plotsUnlocked,
      xp: data.xp.present ? data.xp.value : this.xp,
      streakCount: data.streakCount.present
          ? data.streakCount.value
          : this.streakCount,
      lastStreakDate: data.lastStreakDate.present
          ? data.lastStreakDate.value
          : this.lastStreakDate,
      lastPlotGrantDate: data.lastPlotGrantDate.present
          ? data.lastPlotGrantDate.value
          : this.lastPlotGrantDate,
      inRecoveryMode: data.inRecoveryMode.present
          ? data.inRecoveryMode.value
          : this.inRecoveryMode,
      onboardingDone: data.onboardingDone.present
          ? data.onboardingDone.value
          : this.onboardingDone,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastDurationMinutes: data.lastDurationMinutes.present
          ? data.lastDurationMinutes.value
          : this.lastDurationMinutes,
      tipPassShown: data.tipPassShown.present
          ? data.tipPassShown.value
          : this.tipPassShown,
      tipGrowthShown: data.tipGrowthShown.present
          ? data.tipGrowthShown.value
          : this.tipGrowthShown,
      tipRecoveryShown: data.tipRecoveryShown.present
          ? data.tipRecoveryShown.value
          : this.tipRecoveryShown,
      notificationNoteShown: data.notificationNoteShown.present
          ? data.notificationNoteShown.value
          : this.notificationNoteShown,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TownRow(')
          ..write('id: $id, ')
          ..write('workerCount: $workerCount, ')
          ..write('plotsUnlocked: $plotsUnlocked, ')
          ..write('xp: $xp, ')
          ..write('streakCount: $streakCount, ')
          ..write('lastStreakDate: $lastStreakDate, ')
          ..write('lastPlotGrantDate: $lastPlotGrantDate, ')
          ..write('inRecoveryMode: $inRecoveryMode, ')
          ..write('onboardingDone: $onboardingDone, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastDurationMinutes: $lastDurationMinutes, ')
          ..write('tipPassShown: $tipPassShown, ')
          ..write('tipGrowthShown: $tipGrowthShown, ')
          ..write('tipRecoveryShown: $tipRecoveryShown, ')
          ..write('notificationNoteShown: $notificationNoteShown')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    workerCount,
    plotsUnlocked,
    xp,
    streakCount,
    lastStreakDate,
    lastPlotGrantDate,
    inRecoveryMode,
    onboardingDone,
    createdAt,
    lastDurationMinutes,
    tipPassShown,
    tipGrowthShown,
    tipRecoveryShown,
    notificationNoteShown,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TownRow &&
          other.id == this.id &&
          other.workerCount == this.workerCount &&
          other.plotsUnlocked == this.plotsUnlocked &&
          other.xp == this.xp &&
          other.streakCount == this.streakCount &&
          other.lastStreakDate == this.lastStreakDate &&
          other.lastPlotGrantDate == this.lastPlotGrantDate &&
          other.inRecoveryMode == this.inRecoveryMode &&
          other.onboardingDone == this.onboardingDone &&
          other.createdAt == this.createdAt &&
          other.lastDurationMinutes == this.lastDurationMinutes &&
          other.tipPassShown == this.tipPassShown &&
          other.tipGrowthShown == this.tipGrowthShown &&
          other.tipRecoveryShown == this.tipRecoveryShown &&
          other.notificationNoteShown == this.notificationNoteShown);
}

class TownsCompanion extends UpdateCompanion<TownRow> {
  final Value<int> id;
  final Value<int> workerCount;
  final Value<int> plotsUnlocked;
  final Value<int> xp;
  final Value<int> streakCount;
  final Value<String?> lastStreakDate;
  final Value<String?> lastPlotGrantDate;
  final Value<bool> inRecoveryMode;
  final Value<bool> onboardingDone;
  final Value<int> createdAt;
  final Value<int> lastDurationMinutes;
  final Value<bool> tipPassShown;
  final Value<bool> tipGrowthShown;
  final Value<bool> tipRecoveryShown;
  final Value<bool> notificationNoteShown;
  const TownsCompanion({
    this.id = const Value.absent(),
    this.workerCount = const Value.absent(),
    this.plotsUnlocked = const Value.absent(),
    this.xp = const Value.absent(),
    this.streakCount = const Value.absent(),
    this.lastStreakDate = const Value.absent(),
    this.lastPlotGrantDate = const Value.absent(),
    this.inRecoveryMode = const Value.absent(),
    this.onboardingDone = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastDurationMinutes = const Value.absent(),
    this.tipPassShown = const Value.absent(),
    this.tipGrowthShown = const Value.absent(),
    this.tipRecoveryShown = const Value.absent(),
    this.notificationNoteShown = const Value.absent(),
  });
  TownsCompanion.insert({
    this.id = const Value.absent(),
    required int workerCount,
    required int plotsUnlocked,
    required int xp,
    required int streakCount,
    this.lastStreakDate = const Value.absent(),
    this.lastPlotGrantDate = const Value.absent(),
    required bool inRecoveryMode,
    this.onboardingDone = const Value.absent(),
    required int createdAt,
    this.lastDurationMinutes = const Value.absent(),
    this.tipPassShown = const Value.absent(),
    this.tipGrowthShown = const Value.absent(),
    this.tipRecoveryShown = const Value.absent(),
    this.notificationNoteShown = const Value.absent(),
  }) : workerCount = Value(workerCount),
       plotsUnlocked = Value(plotsUnlocked),
       xp = Value(xp),
       streakCount = Value(streakCount),
       inRecoveryMode = Value(inRecoveryMode),
       createdAt = Value(createdAt);
  static Insertable<TownRow> custom({
    Expression<int>? id,
    Expression<int>? workerCount,
    Expression<int>? plotsUnlocked,
    Expression<int>? xp,
    Expression<int>? streakCount,
    Expression<String>? lastStreakDate,
    Expression<String>? lastPlotGrantDate,
    Expression<bool>? inRecoveryMode,
    Expression<bool>? onboardingDone,
    Expression<int>? createdAt,
    Expression<int>? lastDurationMinutes,
    Expression<bool>? tipPassShown,
    Expression<bool>? tipGrowthShown,
    Expression<bool>? tipRecoveryShown,
    Expression<bool>? notificationNoteShown,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workerCount != null) 'worker_count': workerCount,
      if (plotsUnlocked != null) 'plots_unlocked': plotsUnlocked,
      if (xp != null) 'xp': xp,
      if (streakCount != null) 'streak_count': streakCount,
      if (lastStreakDate != null) 'last_streak_date': lastStreakDate,
      if (lastPlotGrantDate != null) 'last_plot_grant_date': lastPlotGrantDate,
      if (inRecoveryMode != null) 'in_recovery_mode': inRecoveryMode,
      if (onboardingDone != null) 'onboarding_done': onboardingDone,
      if (createdAt != null) 'created_at': createdAt,
      if (lastDurationMinutes != null)
        'last_duration_minutes': lastDurationMinutes,
      if (tipPassShown != null) 'tip_pass_shown': tipPassShown,
      if (tipGrowthShown != null) 'tip_growth_shown': tipGrowthShown,
      if (tipRecoveryShown != null) 'tip_recovery_shown': tipRecoveryShown,
      if (notificationNoteShown != null)
        'notification_note_shown': notificationNoteShown,
    });
  }

  TownsCompanion copyWith({
    Value<int>? id,
    Value<int>? workerCount,
    Value<int>? plotsUnlocked,
    Value<int>? xp,
    Value<int>? streakCount,
    Value<String?>? lastStreakDate,
    Value<String?>? lastPlotGrantDate,
    Value<bool>? inRecoveryMode,
    Value<bool>? onboardingDone,
    Value<int>? createdAt,
    Value<int>? lastDurationMinutes,
    Value<bool>? tipPassShown,
    Value<bool>? tipGrowthShown,
    Value<bool>? tipRecoveryShown,
    Value<bool>? notificationNoteShown,
  }) {
    return TownsCompanion(
      id: id ?? this.id,
      workerCount: workerCount ?? this.workerCount,
      plotsUnlocked: plotsUnlocked ?? this.plotsUnlocked,
      xp: xp ?? this.xp,
      streakCount: streakCount ?? this.streakCount,
      lastStreakDate: lastStreakDate ?? this.lastStreakDate,
      lastPlotGrantDate: lastPlotGrantDate ?? this.lastPlotGrantDate,
      inRecoveryMode: inRecoveryMode ?? this.inRecoveryMode,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      createdAt: createdAt ?? this.createdAt,
      lastDurationMinutes: lastDurationMinutes ?? this.lastDurationMinutes,
      tipPassShown: tipPassShown ?? this.tipPassShown,
      tipGrowthShown: tipGrowthShown ?? this.tipGrowthShown,
      tipRecoveryShown: tipRecoveryShown ?? this.tipRecoveryShown,
      notificationNoteShown:
          notificationNoteShown ?? this.notificationNoteShown,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (workerCount.present) {
      map['worker_count'] = Variable<int>(workerCount.value);
    }
    if (plotsUnlocked.present) {
      map['plots_unlocked'] = Variable<int>(plotsUnlocked.value);
    }
    if (xp.present) {
      map['xp'] = Variable<int>(xp.value);
    }
    if (streakCount.present) {
      map['streak_count'] = Variable<int>(streakCount.value);
    }
    if (lastStreakDate.present) {
      map['last_streak_date'] = Variable<String>(lastStreakDate.value);
    }
    if (lastPlotGrantDate.present) {
      map['last_plot_grant_date'] = Variable<String>(lastPlotGrantDate.value);
    }
    if (inRecoveryMode.present) {
      map['in_recovery_mode'] = Variable<bool>(inRecoveryMode.value);
    }
    if (onboardingDone.present) {
      map['onboarding_done'] = Variable<bool>(onboardingDone.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (lastDurationMinutes.present) {
      map['last_duration_minutes'] = Variable<int>(lastDurationMinutes.value);
    }
    if (tipPassShown.present) {
      map['tip_pass_shown'] = Variable<bool>(tipPassShown.value);
    }
    if (tipGrowthShown.present) {
      map['tip_growth_shown'] = Variable<bool>(tipGrowthShown.value);
    }
    if (tipRecoveryShown.present) {
      map['tip_recovery_shown'] = Variable<bool>(tipRecoveryShown.value);
    }
    if (notificationNoteShown.present) {
      map['notification_note_shown'] = Variable<bool>(
        notificationNoteShown.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TownsCompanion(')
          ..write('id: $id, ')
          ..write('workerCount: $workerCount, ')
          ..write('plotsUnlocked: $plotsUnlocked, ')
          ..write('xp: $xp, ')
          ..write('streakCount: $streakCount, ')
          ..write('lastStreakDate: $lastStreakDate, ')
          ..write('lastPlotGrantDate: $lastPlotGrantDate, ')
          ..write('inRecoveryMode: $inRecoveryMode, ')
          ..write('onboardingDone: $onboardingDone, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastDurationMinutes: $lastDurationMinutes, ')
          ..write('tipPassShown: $tipPassShown, ')
          ..write('tipGrowthShown: $tipGrowthShown, ')
          ..write('tipRecoveryShown: $tipRecoveryShown, ')
          ..write('notificationNoteShown: $notificationNoteShown')
          ..write(')'))
        .toString();
  }
}

class $BuildingsTable extends Buildings
    with TableInfo<$BuildingsTable, BuildingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BuildingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tierMeta = const VerificationMeta('tier');
  @override
  late final GeneratedColumn<String> tier = GeneratedColumn<String>(
    'tier',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plotIndexMeta = const VerificationMeta(
    'plotIndex',
  );
  @override
  late final GeneratedColumn<int> plotIndex = GeneratedColumn<int>(
    'plot_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tier,
    status,
    plotIndex,
    sessionId,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'buildings';
  @override
  VerificationContext validateIntegrity(
    Insertable<BuildingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    } else if (isInserting) {
      context.missing(_tierMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('plot_index')) {
      context.handle(
        _plotIndexMeta,
        plotIndex.isAcceptableOrUnknown(data['plot_index']!, _plotIndexMeta),
      );
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
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
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BuildingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BuildingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tier'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      plotIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plot_index'],
      ),
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      )!,
    );
  }

  @override
  $BuildingsTable createAlias(String alias) {
    return $BuildingsTable(attachedDatabase, alias);
  }
}

class BuildingRow extends DataClass implements Insertable<BuildingRow> {
  final String id;
  final String tier;
  final String status;
  final int? plotIndex;
  final String? sessionId;
  final int completedAt;
  const BuildingRow({
    required this.id,
    required this.tier,
    required this.status,
    this.plotIndex,
    this.sessionId,
    required this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tier'] = Variable<String>(tier);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || plotIndex != null) {
      map['plot_index'] = Variable<int>(plotIndex);
    }
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    map['completed_at'] = Variable<int>(completedAt);
    return map;
  }

  BuildingsCompanion toCompanion(bool nullToAbsent) {
    return BuildingsCompanion(
      id: Value(id),
      tier: Value(tier),
      status: Value(status),
      plotIndex: plotIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(plotIndex),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      completedAt: Value(completedAt),
    );
  }

  factory BuildingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BuildingRow(
      id: serializer.fromJson<String>(json['id']),
      tier: serializer.fromJson<String>(json['tier']),
      status: serializer.fromJson<String>(json['status']),
      plotIndex: serializer.fromJson<int?>(json['plotIndex']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      completedAt: serializer.fromJson<int>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tier': serializer.toJson<String>(tier),
      'status': serializer.toJson<String>(status),
      'plotIndex': serializer.toJson<int?>(plotIndex),
      'sessionId': serializer.toJson<String?>(sessionId),
      'completedAt': serializer.toJson<int>(completedAt),
    };
  }

  BuildingRow copyWith({
    String? id,
    String? tier,
    String? status,
    Value<int?> plotIndex = const Value.absent(),
    Value<String?> sessionId = const Value.absent(),
    int? completedAt,
  }) => BuildingRow(
    id: id ?? this.id,
    tier: tier ?? this.tier,
    status: status ?? this.status,
    plotIndex: plotIndex.present ? plotIndex.value : this.plotIndex,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    completedAt: completedAt ?? this.completedAt,
  );
  BuildingRow copyWithCompanion(BuildingsCompanion data) {
    return BuildingRow(
      id: data.id.present ? data.id.value : this.id,
      tier: data.tier.present ? data.tier.value : this.tier,
      status: data.status.present ? data.status.value : this.status,
      plotIndex: data.plotIndex.present ? data.plotIndex.value : this.plotIndex,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BuildingRow(')
          ..write('id: $id, ')
          ..write('tier: $tier, ')
          ..write('status: $status, ')
          ..write('plotIndex: $plotIndex, ')
          ..write('sessionId: $sessionId, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, tier, status, plotIndex, sessionId, completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BuildingRow &&
          other.id == this.id &&
          other.tier == this.tier &&
          other.status == this.status &&
          other.plotIndex == this.plotIndex &&
          other.sessionId == this.sessionId &&
          other.completedAt == this.completedAt);
}

class BuildingsCompanion extends UpdateCompanion<BuildingRow> {
  final Value<String> id;
  final Value<String> tier;
  final Value<String> status;
  final Value<int?> plotIndex;
  final Value<String?> sessionId;
  final Value<int> completedAt;
  final Value<int> rowid;
  const BuildingsCompanion({
    this.id = const Value.absent(),
    this.tier = const Value.absent(),
    this.status = const Value.absent(),
    this.plotIndex = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BuildingsCompanion.insert({
    required String id,
    required String tier,
    required String status,
    this.plotIndex = const Value.absent(),
    this.sessionId = const Value.absent(),
    required int completedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tier = Value(tier),
       status = Value(status),
       completedAt = Value(completedAt);
  static Insertable<BuildingRow> custom({
    Expression<String>? id,
    Expression<String>? tier,
    Expression<String>? status,
    Expression<int>? plotIndex,
    Expression<String>? sessionId,
    Expression<int>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tier != null) 'tier': tier,
      if (status != null) 'status': status,
      if (plotIndex != null) 'plot_index': plotIndex,
      if (sessionId != null) 'session_id': sessionId,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BuildingsCompanion copyWith({
    Value<String>? id,
    Value<String>? tier,
    Value<String>? status,
    Value<int?>? plotIndex,
    Value<String?>? sessionId,
    Value<int>? completedAt,
    Value<int>? rowid,
  }) {
    return BuildingsCompanion(
      id: id ?? this.id,
      tier: tier ?? this.tier,
      status: status ?? this.status,
      plotIndex: plotIndex ?? this.plotIndex,
      sessionId: sessionId ?? this.sessionId,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tier.present) {
      map['tier'] = Variable<String>(tier.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (plotIndex.present) {
      map['plot_index'] = Variable<int>(plotIndex.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BuildingsCompanion(')
          ..write('id: $id, ')
          ..write('tier: $tier, ')
          ..write('status: $status, ')
          ..write('plotIndex: $plotIndex, ')
          ..write('sessionId: $sessionId, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions
    with TableInfo<$SessionsTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plannedMinutesMeta = const VerificationMeta(
    'plannedMinutes',
  );
  @override
  late final GeneratedColumn<int> plannedMinutes = GeneratedColumn<int>(
    'planned_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tierMeta = const VerificationMeta('tier');
  @override
  late final GeneratedColumn<String> tier = GeneratedColumn<String>(
    'tier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workersAssignedMeta = const VerificationMeta(
    'workersAssigned',
  );
  @override
  late final GeneratedColumn<int> workersAssigned = GeneratedColumn<int>(
    'workers_assigned',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtWallMeta = const VerificationMeta(
    'startedAtWall',
  );
  @override
  late final GeneratedColumn<int> startedAtWall = GeneratedColumn<int>(
    'started_at_wall',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtUptimeMsMeta = const VerificationMeta(
    'startedAtUptimeMs',
  );
  @override
  late final GeneratedColumn<int> startedAtUptimeMs = GeneratedColumn<int>(
    'started_at_uptime_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leftAtWallMeta = const VerificationMeta(
    'leftAtWall',
  );
  @override
  late final GeneratedColumn<int> leftAtWall = GeneratedColumn<int>(
    'left_at_wall',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leftAtUptimeMsMeta = const VerificationMeta(
    'leftAtUptimeMs',
  );
  @override
  late final GeneratedColumn<int> leftAtUptimeMs = GeneratedColumn<int>(
    'left_at_uptime_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _awayTotalMsMeta = const VerificationMeta(
    'awayTotalMs',
  );
  @override
  late final GeneratedColumn<int> awayTotalMs = GeneratedColumn<int>(
    'away_total_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _passUsedMeta = const VerificationMeta(
    'passUsed',
  );
  @override
  late final GeneratedColumn<bool> passUsed = GeneratedColumn<bool>(
    'pass_used',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pass_used" IN (0, 1))',
    ),
  );
  static const VerificationMeta _outcomeReasonMeta = const VerificationMeta(
    'outcomeReason',
  );
  @override
  late final GeneratedColumn<String> outcomeReason = GeneratedColumn<String>(
    'outcome_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<int> resolvedAt = GeneratedColumn<int>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plotIndexMeta = const VerificationMeta(
    'plotIndex',
  );
  @override
  late final GeneratedColumn<int> plotIndex = GeneratedColumn<int>(
    'plot_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repairPlotIndexMeta = const VerificationMeta(
    'repairPlotIndex',
  );
  @override
  late final GeneratedColumn<int> repairPlotIndex = GeneratedColumn<int>(
    'repair_plot_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    plannedMinutes,
    tier,
    workersAssigned,
    state,
    startedAtWall,
    startedAtUptimeMs,
    leftAtWall,
    leftAtUptimeMs,
    awayTotalMs,
    passUsed,
    outcomeReason,
    resolvedAt,
    plotIndex,
    repairPlotIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('planned_minutes')) {
      context.handle(
        _plannedMinutesMeta,
        plannedMinutes.isAcceptableOrUnknown(
          data['planned_minutes']!,
          _plannedMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_plannedMinutesMeta);
    }
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    } else if (isInserting) {
      context.missing(_tierMeta);
    }
    if (data.containsKey('workers_assigned')) {
      context.handle(
        _workersAssignedMeta,
        workersAssigned.isAcceptableOrUnknown(
          data['workers_assigned']!,
          _workersAssignedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workersAssignedMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('started_at_wall')) {
      context.handle(
        _startedAtWallMeta,
        startedAtWall.isAcceptableOrUnknown(
          data['started_at_wall']!,
          _startedAtWallMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtWallMeta);
    }
    if (data.containsKey('started_at_uptime_ms')) {
      context.handle(
        _startedAtUptimeMsMeta,
        startedAtUptimeMs.isAcceptableOrUnknown(
          data['started_at_uptime_ms']!,
          _startedAtUptimeMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtUptimeMsMeta);
    }
    if (data.containsKey('left_at_wall')) {
      context.handle(
        _leftAtWallMeta,
        leftAtWall.isAcceptableOrUnknown(
          data['left_at_wall']!,
          _leftAtWallMeta,
        ),
      );
    }
    if (data.containsKey('left_at_uptime_ms')) {
      context.handle(
        _leftAtUptimeMsMeta,
        leftAtUptimeMs.isAcceptableOrUnknown(
          data['left_at_uptime_ms']!,
          _leftAtUptimeMsMeta,
        ),
      );
    }
    if (data.containsKey('away_total_ms')) {
      context.handle(
        _awayTotalMsMeta,
        awayTotalMs.isAcceptableOrUnknown(
          data['away_total_ms']!,
          _awayTotalMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_awayTotalMsMeta);
    }
    if (data.containsKey('pass_used')) {
      context.handle(
        _passUsedMeta,
        passUsed.isAcceptableOrUnknown(data['pass_used']!, _passUsedMeta),
      );
    } else if (isInserting) {
      context.missing(_passUsedMeta);
    }
    if (data.containsKey('outcome_reason')) {
      context.handle(
        _outcomeReasonMeta,
        outcomeReason.isAcceptableOrUnknown(
          data['outcome_reason']!,
          _outcomeReasonMeta,
        ),
      );
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    if (data.containsKey('plot_index')) {
      context.handle(
        _plotIndexMeta,
        plotIndex.isAcceptableOrUnknown(data['plot_index']!, _plotIndexMeta),
      );
    }
    if (data.containsKey('repair_plot_index')) {
      context.handle(
        _repairPlotIndexMeta,
        repairPlotIndex.isAcceptableOrUnknown(
          data['repair_plot_index']!,
          _repairPlotIndexMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      plannedMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}planned_minutes'],
      )!,
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tier'],
      )!,
      workersAssigned: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}workers_assigned'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      startedAtWall: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_wall'],
      )!,
      startedAtUptimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_uptime_ms'],
      )!,
      leftAtWall: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}left_at_wall'],
      ),
      leftAtUptimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}left_at_uptime_ms'],
      ),
      awayTotalMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}away_total_ms'],
      )!,
      passUsed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pass_used'],
      )!,
      outcomeReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome_reason'],
      ),
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resolved_at'],
      ),
      plotIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plot_index'],
      ),
      repairPlotIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repair_plot_index'],
      ),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final String id;
  final int plannedMinutes;
  final String tier;
  final int workersAssigned;
  final String state;
  final int startedAtWall;
  final int startedAtUptimeMs;
  final int? leftAtWall;
  final int? leftAtUptimeMs;
  final int awayTotalMs;
  final bool passUsed;
  final String? outcomeReason;
  final int? resolvedAt;
  final int? plotIndex;
  final int? repairPlotIndex;
  const SessionRow({
    required this.id,
    required this.plannedMinutes,
    required this.tier,
    required this.workersAssigned,
    required this.state,
    required this.startedAtWall,
    required this.startedAtUptimeMs,
    this.leftAtWall,
    this.leftAtUptimeMs,
    required this.awayTotalMs,
    required this.passUsed,
    this.outcomeReason,
    this.resolvedAt,
    this.plotIndex,
    this.repairPlotIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['planned_minutes'] = Variable<int>(plannedMinutes);
    map['tier'] = Variable<String>(tier);
    map['workers_assigned'] = Variable<int>(workersAssigned);
    map['state'] = Variable<String>(state);
    map['started_at_wall'] = Variable<int>(startedAtWall);
    map['started_at_uptime_ms'] = Variable<int>(startedAtUptimeMs);
    if (!nullToAbsent || leftAtWall != null) {
      map['left_at_wall'] = Variable<int>(leftAtWall);
    }
    if (!nullToAbsent || leftAtUptimeMs != null) {
      map['left_at_uptime_ms'] = Variable<int>(leftAtUptimeMs);
    }
    map['away_total_ms'] = Variable<int>(awayTotalMs);
    map['pass_used'] = Variable<bool>(passUsed);
    if (!nullToAbsent || outcomeReason != null) {
      map['outcome_reason'] = Variable<String>(outcomeReason);
    }
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<int>(resolvedAt);
    }
    if (!nullToAbsent || plotIndex != null) {
      map['plot_index'] = Variable<int>(plotIndex);
    }
    if (!nullToAbsent || repairPlotIndex != null) {
      map['repair_plot_index'] = Variable<int>(repairPlotIndex);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      plannedMinutes: Value(plannedMinutes),
      tier: Value(tier),
      workersAssigned: Value(workersAssigned),
      state: Value(state),
      startedAtWall: Value(startedAtWall),
      startedAtUptimeMs: Value(startedAtUptimeMs),
      leftAtWall: leftAtWall == null && nullToAbsent
          ? const Value.absent()
          : Value(leftAtWall),
      leftAtUptimeMs: leftAtUptimeMs == null && nullToAbsent
          ? const Value.absent()
          : Value(leftAtUptimeMs),
      awayTotalMs: Value(awayTotalMs),
      passUsed: Value(passUsed),
      outcomeReason: outcomeReason == null && nullToAbsent
          ? const Value.absent()
          : Value(outcomeReason),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
      plotIndex: plotIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(plotIndex),
      repairPlotIndex: repairPlotIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(repairPlotIndex),
    );
  }

  factory SessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      id: serializer.fromJson<String>(json['id']),
      plannedMinutes: serializer.fromJson<int>(json['plannedMinutes']),
      tier: serializer.fromJson<String>(json['tier']),
      workersAssigned: serializer.fromJson<int>(json['workersAssigned']),
      state: serializer.fromJson<String>(json['state']),
      startedAtWall: serializer.fromJson<int>(json['startedAtWall']),
      startedAtUptimeMs: serializer.fromJson<int>(json['startedAtUptimeMs']),
      leftAtWall: serializer.fromJson<int?>(json['leftAtWall']),
      leftAtUptimeMs: serializer.fromJson<int?>(json['leftAtUptimeMs']),
      awayTotalMs: serializer.fromJson<int>(json['awayTotalMs']),
      passUsed: serializer.fromJson<bool>(json['passUsed']),
      outcomeReason: serializer.fromJson<String?>(json['outcomeReason']),
      resolvedAt: serializer.fromJson<int?>(json['resolvedAt']),
      plotIndex: serializer.fromJson<int?>(json['plotIndex']),
      repairPlotIndex: serializer.fromJson<int?>(json['repairPlotIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'plannedMinutes': serializer.toJson<int>(plannedMinutes),
      'tier': serializer.toJson<String>(tier),
      'workersAssigned': serializer.toJson<int>(workersAssigned),
      'state': serializer.toJson<String>(state),
      'startedAtWall': serializer.toJson<int>(startedAtWall),
      'startedAtUptimeMs': serializer.toJson<int>(startedAtUptimeMs),
      'leftAtWall': serializer.toJson<int?>(leftAtWall),
      'leftAtUptimeMs': serializer.toJson<int?>(leftAtUptimeMs),
      'awayTotalMs': serializer.toJson<int>(awayTotalMs),
      'passUsed': serializer.toJson<bool>(passUsed),
      'outcomeReason': serializer.toJson<String?>(outcomeReason),
      'resolvedAt': serializer.toJson<int?>(resolvedAt),
      'plotIndex': serializer.toJson<int?>(plotIndex),
      'repairPlotIndex': serializer.toJson<int?>(repairPlotIndex),
    };
  }

  SessionRow copyWith({
    String? id,
    int? plannedMinutes,
    String? tier,
    int? workersAssigned,
    String? state,
    int? startedAtWall,
    int? startedAtUptimeMs,
    Value<int?> leftAtWall = const Value.absent(),
    Value<int?> leftAtUptimeMs = const Value.absent(),
    int? awayTotalMs,
    bool? passUsed,
    Value<String?> outcomeReason = const Value.absent(),
    Value<int?> resolvedAt = const Value.absent(),
    Value<int?> plotIndex = const Value.absent(),
    Value<int?> repairPlotIndex = const Value.absent(),
  }) => SessionRow(
    id: id ?? this.id,
    plannedMinutes: plannedMinutes ?? this.plannedMinutes,
    tier: tier ?? this.tier,
    workersAssigned: workersAssigned ?? this.workersAssigned,
    state: state ?? this.state,
    startedAtWall: startedAtWall ?? this.startedAtWall,
    startedAtUptimeMs: startedAtUptimeMs ?? this.startedAtUptimeMs,
    leftAtWall: leftAtWall.present ? leftAtWall.value : this.leftAtWall,
    leftAtUptimeMs: leftAtUptimeMs.present
        ? leftAtUptimeMs.value
        : this.leftAtUptimeMs,
    awayTotalMs: awayTotalMs ?? this.awayTotalMs,
    passUsed: passUsed ?? this.passUsed,
    outcomeReason: outcomeReason.present
        ? outcomeReason.value
        : this.outcomeReason,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
    plotIndex: plotIndex.present ? plotIndex.value : this.plotIndex,
    repairPlotIndex: repairPlotIndex.present
        ? repairPlotIndex.value
        : this.repairPlotIndex,
  );
  SessionRow copyWithCompanion(SessionsCompanion data) {
    return SessionRow(
      id: data.id.present ? data.id.value : this.id,
      plannedMinutes: data.plannedMinutes.present
          ? data.plannedMinutes.value
          : this.plannedMinutes,
      tier: data.tier.present ? data.tier.value : this.tier,
      workersAssigned: data.workersAssigned.present
          ? data.workersAssigned.value
          : this.workersAssigned,
      state: data.state.present ? data.state.value : this.state,
      startedAtWall: data.startedAtWall.present
          ? data.startedAtWall.value
          : this.startedAtWall,
      startedAtUptimeMs: data.startedAtUptimeMs.present
          ? data.startedAtUptimeMs.value
          : this.startedAtUptimeMs,
      leftAtWall: data.leftAtWall.present
          ? data.leftAtWall.value
          : this.leftAtWall,
      leftAtUptimeMs: data.leftAtUptimeMs.present
          ? data.leftAtUptimeMs.value
          : this.leftAtUptimeMs,
      awayTotalMs: data.awayTotalMs.present
          ? data.awayTotalMs.value
          : this.awayTotalMs,
      passUsed: data.passUsed.present ? data.passUsed.value : this.passUsed,
      outcomeReason: data.outcomeReason.present
          ? data.outcomeReason.value
          : this.outcomeReason,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
      plotIndex: data.plotIndex.present ? data.plotIndex.value : this.plotIndex,
      repairPlotIndex: data.repairPlotIndex.present
          ? data.repairPlotIndex.value
          : this.repairPlotIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('id: $id, ')
          ..write('plannedMinutes: $plannedMinutes, ')
          ..write('tier: $tier, ')
          ..write('workersAssigned: $workersAssigned, ')
          ..write('state: $state, ')
          ..write('startedAtWall: $startedAtWall, ')
          ..write('startedAtUptimeMs: $startedAtUptimeMs, ')
          ..write('leftAtWall: $leftAtWall, ')
          ..write('leftAtUptimeMs: $leftAtUptimeMs, ')
          ..write('awayTotalMs: $awayTotalMs, ')
          ..write('passUsed: $passUsed, ')
          ..write('outcomeReason: $outcomeReason, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('plotIndex: $plotIndex, ')
          ..write('repairPlotIndex: $repairPlotIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    plannedMinutes,
    tier,
    workersAssigned,
    state,
    startedAtWall,
    startedAtUptimeMs,
    leftAtWall,
    leftAtUptimeMs,
    awayTotalMs,
    passUsed,
    outcomeReason,
    resolvedAt,
    plotIndex,
    repairPlotIndex,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.id == this.id &&
          other.plannedMinutes == this.plannedMinutes &&
          other.tier == this.tier &&
          other.workersAssigned == this.workersAssigned &&
          other.state == this.state &&
          other.startedAtWall == this.startedAtWall &&
          other.startedAtUptimeMs == this.startedAtUptimeMs &&
          other.leftAtWall == this.leftAtWall &&
          other.leftAtUptimeMs == this.leftAtUptimeMs &&
          other.awayTotalMs == this.awayTotalMs &&
          other.passUsed == this.passUsed &&
          other.outcomeReason == this.outcomeReason &&
          other.resolvedAt == this.resolvedAt &&
          other.plotIndex == this.plotIndex &&
          other.repairPlotIndex == this.repairPlotIndex);
}

class SessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<String> id;
  final Value<int> plannedMinutes;
  final Value<String> tier;
  final Value<int> workersAssigned;
  final Value<String> state;
  final Value<int> startedAtWall;
  final Value<int> startedAtUptimeMs;
  final Value<int?> leftAtWall;
  final Value<int?> leftAtUptimeMs;
  final Value<int> awayTotalMs;
  final Value<bool> passUsed;
  final Value<String?> outcomeReason;
  final Value<int?> resolvedAt;
  final Value<int?> plotIndex;
  final Value<int?> repairPlotIndex;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.plannedMinutes = const Value.absent(),
    this.tier = const Value.absent(),
    this.workersAssigned = const Value.absent(),
    this.state = const Value.absent(),
    this.startedAtWall = const Value.absent(),
    this.startedAtUptimeMs = const Value.absent(),
    this.leftAtWall = const Value.absent(),
    this.leftAtUptimeMs = const Value.absent(),
    this.awayTotalMs = const Value.absent(),
    this.passUsed = const Value.absent(),
    this.outcomeReason = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.plotIndex = const Value.absent(),
    this.repairPlotIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    required int plannedMinutes,
    required String tier,
    required int workersAssigned,
    required String state,
    required int startedAtWall,
    required int startedAtUptimeMs,
    this.leftAtWall = const Value.absent(),
    this.leftAtUptimeMs = const Value.absent(),
    required int awayTotalMs,
    required bool passUsed,
    this.outcomeReason = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.plotIndex = const Value.absent(),
    this.repairPlotIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       plannedMinutes = Value(plannedMinutes),
       tier = Value(tier),
       workersAssigned = Value(workersAssigned),
       state = Value(state),
       startedAtWall = Value(startedAtWall),
       startedAtUptimeMs = Value(startedAtUptimeMs),
       awayTotalMs = Value(awayTotalMs),
       passUsed = Value(passUsed);
  static Insertable<SessionRow> custom({
    Expression<String>? id,
    Expression<int>? plannedMinutes,
    Expression<String>? tier,
    Expression<int>? workersAssigned,
    Expression<String>? state,
    Expression<int>? startedAtWall,
    Expression<int>? startedAtUptimeMs,
    Expression<int>? leftAtWall,
    Expression<int>? leftAtUptimeMs,
    Expression<int>? awayTotalMs,
    Expression<bool>? passUsed,
    Expression<String>? outcomeReason,
    Expression<int>? resolvedAt,
    Expression<int>? plotIndex,
    Expression<int>? repairPlotIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (plannedMinutes != null) 'planned_minutes': plannedMinutes,
      if (tier != null) 'tier': tier,
      if (workersAssigned != null) 'workers_assigned': workersAssigned,
      if (state != null) 'state': state,
      if (startedAtWall != null) 'started_at_wall': startedAtWall,
      if (startedAtUptimeMs != null) 'started_at_uptime_ms': startedAtUptimeMs,
      if (leftAtWall != null) 'left_at_wall': leftAtWall,
      if (leftAtUptimeMs != null) 'left_at_uptime_ms': leftAtUptimeMs,
      if (awayTotalMs != null) 'away_total_ms': awayTotalMs,
      if (passUsed != null) 'pass_used': passUsed,
      if (outcomeReason != null) 'outcome_reason': outcomeReason,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (plotIndex != null) 'plot_index': plotIndex,
      if (repairPlotIndex != null) 'repair_plot_index': repairPlotIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<int>? plannedMinutes,
    Value<String>? tier,
    Value<int>? workersAssigned,
    Value<String>? state,
    Value<int>? startedAtWall,
    Value<int>? startedAtUptimeMs,
    Value<int?>? leftAtWall,
    Value<int?>? leftAtUptimeMs,
    Value<int>? awayTotalMs,
    Value<bool>? passUsed,
    Value<String?>? outcomeReason,
    Value<int?>? resolvedAt,
    Value<int?>? plotIndex,
    Value<int?>? repairPlotIndex,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      plannedMinutes: plannedMinutes ?? this.plannedMinutes,
      tier: tier ?? this.tier,
      workersAssigned: workersAssigned ?? this.workersAssigned,
      state: state ?? this.state,
      startedAtWall: startedAtWall ?? this.startedAtWall,
      startedAtUptimeMs: startedAtUptimeMs ?? this.startedAtUptimeMs,
      leftAtWall: leftAtWall ?? this.leftAtWall,
      leftAtUptimeMs: leftAtUptimeMs ?? this.leftAtUptimeMs,
      awayTotalMs: awayTotalMs ?? this.awayTotalMs,
      passUsed: passUsed ?? this.passUsed,
      outcomeReason: outcomeReason ?? this.outcomeReason,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      plotIndex: plotIndex ?? this.plotIndex,
      repairPlotIndex: repairPlotIndex ?? this.repairPlotIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (plannedMinutes.present) {
      map['planned_minutes'] = Variable<int>(plannedMinutes.value);
    }
    if (tier.present) {
      map['tier'] = Variable<String>(tier.value);
    }
    if (workersAssigned.present) {
      map['workers_assigned'] = Variable<int>(workersAssigned.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (startedAtWall.present) {
      map['started_at_wall'] = Variable<int>(startedAtWall.value);
    }
    if (startedAtUptimeMs.present) {
      map['started_at_uptime_ms'] = Variable<int>(startedAtUptimeMs.value);
    }
    if (leftAtWall.present) {
      map['left_at_wall'] = Variable<int>(leftAtWall.value);
    }
    if (leftAtUptimeMs.present) {
      map['left_at_uptime_ms'] = Variable<int>(leftAtUptimeMs.value);
    }
    if (awayTotalMs.present) {
      map['away_total_ms'] = Variable<int>(awayTotalMs.value);
    }
    if (passUsed.present) {
      map['pass_used'] = Variable<bool>(passUsed.value);
    }
    if (outcomeReason.present) {
      map['outcome_reason'] = Variable<String>(outcomeReason.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<int>(resolvedAt.value);
    }
    if (plotIndex.present) {
      map['plot_index'] = Variable<int>(plotIndex.value);
    }
    if (repairPlotIndex.present) {
      map['repair_plot_index'] = Variable<int>(repairPlotIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('plannedMinutes: $plannedMinutes, ')
          ..write('tier: $tier, ')
          ..write('workersAssigned: $workersAssigned, ')
          ..write('state: $state, ')
          ..write('startedAtWall: $startedAtWall, ')
          ..write('startedAtUptimeMs: $startedAtUptimeMs, ')
          ..write('leftAtWall: $leftAtWall, ')
          ..write('leftAtUptimeMs: $leftAtUptimeMs, ')
          ..write('awayTotalMs: $awayTotalMs, ')
          ..write('passUsed: $passUsed, ')
          ..write('outcomeReason: $outcomeReason, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('plotIndex: $plotIndex, ')
          ..write('repairPlotIndex: $repairPlotIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TownsTable towns = $TownsTable(this);
  late final $BuildingsTable buildings = $BuildingsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    towns,
    buildings,
    sessions,
  ];
}

typedef $$TownsTableCreateCompanionBuilder = TownsCompanion Function({
  Value<int> id,
  required int workerCount,
  required int plotsUnlocked,
  required int xp,
  required int streakCount,
  Value<String?> lastStreakDate,
  Value<String?> lastPlotGrantDate,
  required bool inRecoveryMode,
  Value<bool> onboardingDone,
  required int createdAt,
  Value<int> lastDurationMinutes,
  Value<bool> tipPassShown,
  Value<bool> tipGrowthShown,
  Value<bool> tipRecoveryShown,
  Value<bool> notificationNoteShown,
});
typedef $$TownsTableUpdateCompanionBuilder = TownsCompanion Function({
  Value<int> id,
  Value<int> workerCount,
  Value<int> plotsUnlocked,
  Value<int> xp,
  Value<int> streakCount,
  Value<String?> lastStreakDate,
  Value<String?> lastPlotGrantDate,
  Value<bool> inRecoveryMode,
  Value<bool> onboardingDone,
  Value<int> createdAt,
  Value<int> lastDurationMinutes,
  Value<bool> tipPassShown,
  Value<bool> tipGrowthShown,
  Value<bool> tipRecoveryShown,
  Value<bool> notificationNoteShown,
});

class $$TownsTableFilterComposer extends Composer<_$AppDatabase, $TownsTable> {
  $$TownsTableFilterComposer({
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

  ColumnFilters<int> get workerCount => $composableBuilder(
    column: $table.workerCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plotsUnlocked => $composableBuilder(
    column: $table.plotsUnlocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get xp => $composableBuilder(
    column: $table.xp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get streakCount => $composableBuilder(
    column: $table.streakCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastStreakDate => $composableBuilder(
    column: $table.lastStreakDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastPlotGrantDate => $composableBuilder(
    column: $table.lastPlotGrantDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get inRecoveryMode => $composableBuilder(
    column: $table.inRecoveryMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onboardingDone => $composableBuilder(
    column: $table.onboardingDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastDurationMinutes => $composableBuilder(
    column: $table.lastDurationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get tipPassShown => $composableBuilder(
    column: $table.tipPassShown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get tipGrowthShown => $composableBuilder(
    column: $table.tipGrowthShown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get tipRecoveryShown => $composableBuilder(
    column: $table.tipRecoveryShown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notificationNoteShown => $composableBuilder(
    column: $table.notificationNoteShown,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TownsTableOrderingComposer
    extends Composer<_$AppDatabase, $TownsTable> {
  $$TownsTableOrderingComposer({
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

  ColumnOrderings<int> get workerCount => $composableBuilder(
    column: $table.workerCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plotsUnlocked => $composableBuilder(
    column: $table.plotsUnlocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get xp => $composableBuilder(
    column: $table.xp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get streakCount => $composableBuilder(
    column: $table.streakCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastStreakDate => $composableBuilder(
    column: $table.lastStreakDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastPlotGrantDate => $composableBuilder(
    column: $table.lastPlotGrantDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get inRecoveryMode => $composableBuilder(
    column: $table.inRecoveryMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onboardingDone => $composableBuilder(
    column: $table.onboardingDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastDurationMinutes => $composableBuilder(
    column: $table.lastDurationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get tipPassShown => $composableBuilder(
    column: $table.tipPassShown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get tipGrowthShown => $composableBuilder(
    column: $table.tipGrowthShown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get tipRecoveryShown => $composableBuilder(
    column: $table.tipRecoveryShown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notificationNoteShown => $composableBuilder(
    column: $table.notificationNoteShown,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TownsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TownsTable> {
  $$TownsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get workerCount => $composableBuilder(
    column: $table.workerCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get plotsUnlocked => $composableBuilder(
    column: $table.plotsUnlocked,
    builder: (column) => column,
  );

  GeneratedColumn<int> get xp =>
      $composableBuilder(column: $table.xp, builder: (column) => column);

  GeneratedColumn<int> get streakCount => $composableBuilder(
    column: $table.streakCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastStreakDate => $composableBuilder(
    column: $table.lastStreakDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastPlotGrantDate => $composableBuilder(
    column: $table.lastPlotGrantDate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get inRecoveryMode => $composableBuilder(
    column: $table.inRecoveryMode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get onboardingDone => $composableBuilder(
    column: $table.onboardingDone,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get lastDurationMinutes => $composableBuilder(
    column: $table.lastDurationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get tipPassShown => $composableBuilder(
    column: $table.tipPassShown,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get tipGrowthShown => $composableBuilder(
    column: $table.tipGrowthShown,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get tipRecoveryShown => $composableBuilder(
    column: $table.tipRecoveryShown,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get notificationNoteShown => $composableBuilder(
    column: $table.notificationNoteShown,
    builder: (column) => column,
  );
}

class $$TownsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TownsTable,
          TownRow,
          $$TownsTableFilterComposer,
          $$TownsTableOrderingComposer,
          $$TownsTableAnnotationComposer,
          $$TownsTableCreateCompanionBuilder,
          $$TownsTableUpdateCompanionBuilder,
          (TownRow, BaseReferences<_$AppDatabase, $TownsTable, TownRow>),
          TownRow,
          PrefetchHooks Function()
        > {
  $$TownsTableTableManager(_$AppDatabase db, $TownsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TownsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TownsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TownsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> workerCount = const Value.absent(),
                Value<int> plotsUnlocked = const Value.absent(),
                Value<int> xp = const Value.absent(),
                Value<int> streakCount = const Value.absent(),
                Value<String?> lastStreakDate = const Value.absent(),
                Value<String?> lastPlotGrantDate = const Value.absent(),
                Value<bool> inRecoveryMode = const Value.absent(),
                Value<bool> onboardingDone = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> lastDurationMinutes = const Value.absent(),
                Value<bool> tipPassShown = const Value.absent(),
                Value<bool> tipGrowthShown = const Value.absent(),
                Value<bool> tipRecoveryShown = const Value.absent(),
                Value<bool> notificationNoteShown = const Value.absent(),
              }) => TownsCompanion(
                id: id,
                workerCount: workerCount,
                plotsUnlocked: plotsUnlocked,
                xp: xp,
                streakCount: streakCount,
                lastStreakDate: lastStreakDate,
                lastPlotGrantDate: lastPlotGrantDate,
                inRecoveryMode: inRecoveryMode,
                onboardingDone: onboardingDone,
                createdAt: createdAt,
                lastDurationMinutes: lastDurationMinutes,
                tipPassShown: tipPassShown,
                tipGrowthShown: tipGrowthShown,
                tipRecoveryShown: tipRecoveryShown,
                notificationNoteShown: notificationNoteShown,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int workerCount,
                required int plotsUnlocked,
                required int xp,
                required int streakCount,
                Value<String?> lastStreakDate = const Value.absent(),
                Value<String?> lastPlotGrantDate = const Value.absent(),
                required bool inRecoveryMode,
                Value<bool> onboardingDone = const Value.absent(),
                required int createdAt,
                Value<int> lastDurationMinutes = const Value.absent(),
                Value<bool> tipPassShown = const Value.absent(),
                Value<bool> tipGrowthShown = const Value.absent(),
                Value<bool> tipRecoveryShown = const Value.absent(),
                Value<bool> notificationNoteShown = const Value.absent(),
              }) => TownsCompanion.insert(
                id: id,
                workerCount: workerCount,
                plotsUnlocked: plotsUnlocked,
                xp: xp,
                streakCount: streakCount,
                lastStreakDate: lastStreakDate,
                lastPlotGrantDate: lastPlotGrantDate,
                inRecoveryMode: inRecoveryMode,
                onboardingDone: onboardingDone,
                createdAt: createdAt,
                lastDurationMinutes: lastDurationMinutes,
                tipPassShown: tipPassShown,
                tipGrowthShown: tipGrowthShown,
                tipRecoveryShown: tipRecoveryShown,
                notificationNoteShown: notificationNoteShown,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TownsTable, TownRow>(table),
                  BaseReferences<_$AppDatabase, $TownsTable, TownRow>(
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

typedef $$TownsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TownsTable,
      TownRow,
      $$TownsTableFilterComposer,
      $$TownsTableOrderingComposer,
      $$TownsTableAnnotationComposer,
      $$TownsTableCreateCompanionBuilder,
      $$TownsTableUpdateCompanionBuilder,
      (TownRow, BaseReferences<_$AppDatabase, $TownsTable, TownRow>),
      TownRow,
      PrefetchHooks Function()
    >;
typedef $$BuildingsTableCreateCompanionBuilder = BuildingsCompanion Function({
  required String id,
  required String tier,
  required String status,
  Value<int?> plotIndex,
  Value<String?> sessionId,
  required int completedAt,
  Value<int> rowid,
});
typedef $$BuildingsTableUpdateCompanionBuilder = BuildingsCompanion Function({
  Value<String> id,
  Value<String> tier,
  Value<String> status,
  Value<int?> plotIndex,
  Value<String?> sessionId,
  Value<int> completedAt,
  Value<int> rowid,
});

class $$BuildingsTableFilterComposer
    extends Composer<_$AppDatabase, $BuildingsTable> {
  $$BuildingsTableFilterComposer({
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

  ColumnFilters<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plotIndex => $composableBuilder(
    column: $table.plotIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BuildingsTableOrderingComposer
    extends Composer<_$AppDatabase, $BuildingsTable> {
  $$BuildingsTableOrderingComposer({
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

  ColumnOrderings<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plotIndex => $composableBuilder(
    column: $table.plotIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BuildingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BuildingsTable> {
  $$BuildingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get plotIndex =>
      $composableBuilder(column: $table.plotIndex, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$BuildingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BuildingsTable,
          BuildingRow,
          $$BuildingsTableFilterComposer,
          $$BuildingsTableOrderingComposer,
          $$BuildingsTableAnnotationComposer,
          $$BuildingsTableCreateCompanionBuilder,
          $$BuildingsTableUpdateCompanionBuilder,
          (
            BuildingRow,
            BaseReferences<_$AppDatabase, $BuildingsTable, BuildingRow>,
          ),
          BuildingRow,
          PrefetchHooks Function()
        > {
  $$BuildingsTableTableManager(_$AppDatabase db, $BuildingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BuildingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BuildingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BuildingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> plotIndex = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<int> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BuildingsCompanion(
                id: id,
                tier: tier,
                status: status,
                plotIndex: plotIndex,
                sessionId: sessionId,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tier,
                required String status,
                Value<int?> plotIndex = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                required int completedAt,
                Value<int> rowid = const Value.absent(),
              }) => BuildingsCompanion.insert(
                id: id,
                tier: tier,
                status: status,
                plotIndex: plotIndex,
                sessionId: sessionId,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BuildingsTable, BuildingRow>(table),
                  BaseReferences<_$AppDatabase, $BuildingsTable, BuildingRow>(
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

typedef $$BuildingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BuildingsTable,
      BuildingRow,
      $$BuildingsTableFilterComposer,
      $$BuildingsTableOrderingComposer,
      $$BuildingsTableAnnotationComposer,
      $$BuildingsTableCreateCompanionBuilder,
      $$BuildingsTableUpdateCompanionBuilder,
      (
        BuildingRow,
        BaseReferences<_$AppDatabase, $BuildingsTable, BuildingRow>,
      ),
      BuildingRow,
      PrefetchHooks Function()
    >;
typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  required String id,
  required int plannedMinutes,
  required String tier,
  required int workersAssigned,
  required String state,
  required int startedAtWall,
  required int startedAtUptimeMs,
  Value<int?> leftAtWall,
  Value<int?> leftAtUptimeMs,
  required int awayTotalMs,
  required bool passUsed,
  Value<String?> outcomeReason,
  Value<int?> resolvedAt,
  Value<int?> plotIndex,
  Value<int?> repairPlotIndex,
  Value<int> rowid,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<String> id,
  Value<int> plannedMinutes,
  Value<String> tier,
  Value<int> workersAssigned,
  Value<String> state,
  Value<int> startedAtWall,
  Value<int> startedAtUptimeMs,
  Value<int?> leftAtWall,
  Value<int?> leftAtUptimeMs,
  Value<int> awayTotalMs,
  Value<bool> passUsed,
  Value<String?> outcomeReason,
  Value<int?> resolvedAt,
  Value<int?> plotIndex,
  Value<int?> repairPlotIndex,
  Value<int> rowid,
});

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
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

  ColumnFilters<int> get plannedMinutes => $composableBuilder(
    column: $table.plannedMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get workersAssigned => $composableBuilder(
    column: $table.workersAssigned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtWall => $composableBuilder(
    column: $table.startedAtWall,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtUptimeMs => $composableBuilder(
    column: $table.startedAtUptimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get leftAtWall => $composableBuilder(
    column: $table.leftAtWall,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get leftAtUptimeMs => $composableBuilder(
    column: $table.leftAtUptimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get awayTotalMs => $composableBuilder(
    column: $table.awayTotalMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get passUsed => $composableBuilder(
    column: $table.passUsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcomeReason => $composableBuilder(
    column: $table.outcomeReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plotIndex => $composableBuilder(
    column: $table.plotIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repairPlotIndex => $composableBuilder(
    column: $table.repairPlotIndex,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
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

  ColumnOrderings<int> get plannedMinutes => $composableBuilder(
    column: $table.plannedMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get workersAssigned => $composableBuilder(
    column: $table.workersAssigned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtWall => $composableBuilder(
    column: $table.startedAtWall,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtUptimeMs => $composableBuilder(
    column: $table.startedAtUptimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get leftAtWall => $composableBuilder(
    column: $table.leftAtWall,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get leftAtUptimeMs => $composableBuilder(
    column: $table.leftAtUptimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get awayTotalMs => $composableBuilder(
    column: $table.awayTotalMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get passUsed => $composableBuilder(
    column: $table.passUsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcomeReason => $composableBuilder(
    column: $table.outcomeReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plotIndex => $composableBuilder(
    column: $table.plotIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repairPlotIndex => $composableBuilder(
    column: $table.repairPlotIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get plannedMinutes => $composableBuilder(
    column: $table.plannedMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumn<int> get workersAssigned => $composableBuilder(
    column: $table.workersAssigned,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get startedAtWall => $composableBuilder(
    column: $table.startedAtWall,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startedAtUptimeMs => $composableBuilder(
    column: $table.startedAtUptimeMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get leftAtWall => $composableBuilder(
    column: $table.leftAtWall,
    builder: (column) => column,
  );

  GeneratedColumn<int> get leftAtUptimeMs => $composableBuilder(
    column: $table.leftAtUptimeMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get awayTotalMs => $composableBuilder(
    column: $table.awayTotalMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get passUsed =>
      $composableBuilder(column: $table.passUsed, builder: (column) => column);

  GeneratedColumn<String> get outcomeReason => $composableBuilder(
    column: $table.outcomeReason,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get plotIndex =>
      $composableBuilder(column: $table.plotIndex, builder: (column) => column);

  GeneratedColumn<int> get repairPlotIndex => $composableBuilder(
    column: $table.repairPlotIndex,
    builder: (column) => column,
  );
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          SessionRow,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (
            SessionRow,
            BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>,
          ),
          SessionRow,
          PrefetchHooks Function()
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> plannedMinutes = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<int> workersAssigned = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> startedAtWall = const Value.absent(),
                Value<int> startedAtUptimeMs = const Value.absent(),
                Value<int?> leftAtWall = const Value.absent(),
                Value<int?> leftAtUptimeMs = const Value.absent(),
                Value<int> awayTotalMs = const Value.absent(),
                Value<bool> passUsed = const Value.absent(),
                Value<String?> outcomeReason = const Value.absent(),
                Value<int?> resolvedAt = const Value.absent(),
                Value<int?> plotIndex = const Value.absent(),
                Value<int?> repairPlotIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                plannedMinutes: plannedMinutes,
                tier: tier,
                workersAssigned: workersAssigned,
                state: state,
                startedAtWall: startedAtWall,
                startedAtUptimeMs: startedAtUptimeMs,
                leftAtWall: leftAtWall,
                leftAtUptimeMs: leftAtUptimeMs,
                awayTotalMs: awayTotalMs,
                passUsed: passUsed,
                outcomeReason: outcomeReason,
                resolvedAt: resolvedAt,
                plotIndex: plotIndex,
                repairPlotIndex: repairPlotIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int plannedMinutes,
                required String tier,
                required int workersAssigned,
                required String state,
                required int startedAtWall,
                required int startedAtUptimeMs,
                Value<int?> leftAtWall = const Value.absent(),
                Value<int?> leftAtUptimeMs = const Value.absent(),
                required int awayTotalMs,
                required bool passUsed,
                Value<String?> outcomeReason = const Value.absent(),
                Value<int?> resolvedAt = const Value.absent(),
                Value<int?> plotIndex = const Value.absent(),
                Value<int?> repairPlotIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                plannedMinutes: plannedMinutes,
                tier: tier,
                workersAssigned: workersAssigned,
                state: state,
                startedAtWall: startedAtWall,
                startedAtUptimeMs: startedAtUptimeMs,
                leftAtWall: leftAtWall,
                leftAtUptimeMs: leftAtUptimeMs,
                awayTotalMs: awayTotalMs,
                passUsed: passUsed,
                outcomeReason: outcomeReason,
                resolvedAt: resolvedAt,
                plotIndex: plotIndex,
                repairPlotIndex: repairPlotIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionsTable, SessionRow>(table),
                  BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>(
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

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      SessionRow,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (SessionRow, BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>),
      SessionRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TownsTableTableManager get towns =>
      $$TownsTableTableManager(_db, _db.towns);
  $$BuildingsTableTableManager get buildings =>
      $$BuildingsTableTableManager(_db, _db.buildings);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
}

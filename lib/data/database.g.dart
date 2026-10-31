// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $WalletsTable extends Wallets with TableInfo<$WalletsTable, Wallet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 100),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 50),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _balanceMeta =
      const VerificationMeta('balance');
  @override
  late final GeneratedColumn<double> balance = GeneratedColumn<double>(
      'balance', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('VND'));
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
      'icon', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Wallet'));
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('#10B981'));
  static const VerificationMeta _isExcludedFromTotalMeta =
      const VerificationMeta('isExcludedFromTotal');
  @override
  late final GeneratedColumn<bool> isExcludedFromTotal = GeneratedColumn<bool>(
      'is_excluded_from_total', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_excluded_from_total" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _creditLimitMeta =
      const VerificationMeta('creditLimit');
  @override
  late final GeneratedColumn<double> creditLimit = GeneratedColumn<double>(
      'credit_limit', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _statementDayMeta =
      const VerificationMeta('statementDay');
  @override
  late final GeneratedColumn<int> statementDay = GeneratedColumn<int>(
      'statement_day', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _paymentDueDayMeta =
      const VerificationMeta('paymentDueDay');
  @override
  late final GeneratedColumn<int> paymentDueDay = GeneratedColumn<int>(
      'payment_due_day', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _isDefaultMeta =
      const VerificationMeta('isDefault');
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
      'is_default', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_default" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isArchivedMeta =
      const VerificationMeta('isArchived');
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
      'is_archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        type,
        balance,
        currency,
        icon,
        color,
        isExcludedFromTotal,
        creditLimit,
        statementDay,
        paymentDueDay,
        isDefault,
        isArchived,
        sortOrder,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallets';
  @override
  VerificationContext validateIntegrity(Insertable<Wallet> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('balance')) {
      context.handle(_balanceMeta,
          balance.isAcceptableOrUnknown(data['balance']!, _balanceMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('icon')) {
      context.handle(
          _iconMeta, icon.isAcceptableOrUnknown(data['icon']!, _iconMeta));
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('is_excluded_from_total')) {
      context.handle(
          _isExcludedFromTotalMeta,
          isExcludedFromTotal.isAcceptableOrUnknown(
              data['is_excluded_from_total']!, _isExcludedFromTotalMeta));
    }
    if (data.containsKey('credit_limit')) {
      context.handle(
          _creditLimitMeta,
          creditLimit.isAcceptableOrUnknown(
              data['credit_limit']!, _creditLimitMeta));
    }
    if (data.containsKey('statement_day')) {
      context.handle(
          _statementDayMeta,
          statementDay.isAcceptableOrUnknown(
              data['statement_day']!, _statementDayMeta));
    }
    if (data.containsKey('payment_due_day')) {
      context.handle(
          _paymentDueDayMeta,
          paymentDueDay.isAcceptableOrUnknown(
              data['payment_due_day']!, _paymentDueDayMeta));
    }
    if (data.containsKey('is_default')) {
      context.handle(_isDefaultMeta,
          isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta));
    }
    if (data.containsKey('is_archived')) {
      context.handle(
          _isArchivedMeta,
          isArchived.isAcceptableOrUnknown(
              data['is_archived']!, _isArchivedMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Wallet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Wallet(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      balance: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}balance'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      icon: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon'])!,
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color'])!,
      isExcludedFromTotal: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_excluded_from_total'])!,
      creditLimit: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}credit_limit']),
      statementDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}statement_day']),
      paymentDueDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}payment_due_day']),
      isDefault: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_default'])!,
      isArchived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_archived'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $WalletsTable createAlias(String alias) {
    return $WalletsTable(attachedDatabase, alias);
  }
}

class Wallet extends DataClass implements Insertable<Wallet> {
  final String id;
  final String name;
  final String type;
  final double balance;
  final String currency;
  final String icon;
  final String color;
  final bool isExcludedFromTotal;
  final double? creditLimit;
  final int? statementDay;
  final int? paymentDueDay;
  final bool isDefault;
  final bool isArchived;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Wallet(
      {required this.id,
      required this.name,
      required this.type,
      required this.balance,
      required this.currency,
      required this.icon,
      required this.color,
      required this.isExcludedFromTotal,
      this.creditLimit,
      this.statementDay,
      this.paymentDueDay,
      required this.isDefault,
      required this.isArchived,
      required this.sortOrder,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['balance'] = Variable<double>(balance);
    map['currency'] = Variable<String>(currency);
    map['icon'] = Variable<String>(icon);
    map['color'] = Variable<String>(color);
    map['is_excluded_from_total'] = Variable<bool>(isExcludedFromTotal);
    if (!nullToAbsent || creditLimit != null) {
      map['credit_limit'] = Variable<double>(creditLimit);
    }
    if (!nullToAbsent || statementDay != null) {
      map['statement_day'] = Variable<int>(statementDay);
    }
    if (!nullToAbsent || paymentDueDay != null) {
      map['payment_due_day'] = Variable<int>(paymentDueDay);
    }
    map['is_default'] = Variable<bool>(isDefault);
    map['is_archived'] = Variable<bool>(isArchived);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WalletsCompanion toCompanion(bool nullToAbsent) {
    return WalletsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      balance: Value(balance),
      currency: Value(currency),
      icon: Value(icon),
      color: Value(color),
      isExcludedFromTotal: Value(isExcludedFromTotal),
      creditLimit: creditLimit == null && nullToAbsent
          ? const Value.absent()
          : Value(creditLimit),
      statementDay: statementDay == null && nullToAbsent
          ? const Value.absent()
          : Value(statementDay),
      paymentDueDay: paymentDueDay == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentDueDay),
      isDefault: Value(isDefault),
      isArchived: Value(isArchived),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Wallet.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Wallet(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      balance: serializer.fromJson<double>(json['balance']),
      currency: serializer.fromJson<String>(json['currency']),
      icon: serializer.fromJson<String>(json['icon']),
      color: serializer.fromJson<String>(json['color']),
      isExcludedFromTotal:
          serializer.fromJson<bool>(json['isExcludedFromTotal']),
      creditLimit: serializer.fromJson<double?>(json['creditLimit']),
      statementDay: serializer.fromJson<int?>(json['statementDay']),
      paymentDueDay: serializer.fromJson<int?>(json['paymentDueDay']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'balance': serializer.toJson<double>(balance),
      'currency': serializer.toJson<String>(currency),
      'icon': serializer.toJson<String>(icon),
      'color': serializer.toJson<String>(color),
      'isExcludedFromTotal': serializer.toJson<bool>(isExcludedFromTotal),
      'creditLimit': serializer.toJson<double?>(creditLimit),
      'statementDay': serializer.toJson<int?>(statementDay),
      'paymentDueDay': serializer.toJson<int?>(paymentDueDay),
      'isDefault': serializer.toJson<bool>(isDefault),
      'isArchived': serializer.toJson<bool>(isArchived),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Wallet copyWith(
          {String? id,
          String? name,
          String? type,
          double? balance,
          String? currency,
          String? icon,
          String? color,
          bool? isExcludedFromTotal,
          Value<double?> creditLimit = const Value.absent(),
          Value<int?> statementDay = const Value.absent(),
          Value<int?> paymentDueDay = const Value.absent(),
          bool? isDefault,
          bool? isArchived,
          int? sortOrder,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Wallet(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        balance: balance ?? this.balance,
        currency: currency ?? this.currency,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        isExcludedFromTotal: isExcludedFromTotal ?? this.isExcludedFromTotal,
        creditLimit: creditLimit.present ? creditLimit.value : this.creditLimit,
        statementDay:
            statementDay.present ? statementDay.value : this.statementDay,
        paymentDueDay:
            paymentDueDay.present ? paymentDueDay.value : this.paymentDueDay,
        isDefault: isDefault ?? this.isDefault,
        isArchived: isArchived ?? this.isArchived,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Wallet copyWithCompanion(WalletsCompanion data) {
    return Wallet(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      balance: data.balance.present ? data.balance.value : this.balance,
      currency: data.currency.present ? data.currency.value : this.currency,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      isExcludedFromTotal: data.isExcludedFromTotal.present
          ? data.isExcludedFromTotal.value
          : this.isExcludedFromTotal,
      creditLimit:
          data.creditLimit.present ? data.creditLimit.value : this.creditLimit,
      statementDay: data.statementDay.present
          ? data.statementDay.value
          : this.statementDay,
      paymentDueDay: data.paymentDueDay.present
          ? data.paymentDueDay.value
          : this.paymentDueDay,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      isArchived:
          data.isArchived.present ? data.isArchived.value : this.isArchived,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Wallet(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('balance: $balance, ')
          ..write('currency: $currency, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('isExcludedFromTotal: $isExcludedFromTotal, ')
          ..write('creditLimit: $creditLimit, ')
          ..write('statementDay: $statementDay, ')
          ..write('paymentDueDay: $paymentDueDay, ')
          ..write('isDefault: $isDefault, ')
          ..write('isArchived: $isArchived, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      type,
      balance,
      currency,
      icon,
      color,
      isExcludedFromTotal,
      creditLimit,
      statementDay,
      paymentDueDay,
      isDefault,
      isArchived,
      sortOrder,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Wallet &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.balance == this.balance &&
          other.currency == this.currency &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.isExcludedFromTotal == this.isExcludedFromTotal &&
          other.creditLimit == this.creditLimit &&
          other.statementDay == this.statementDay &&
          other.paymentDueDay == this.paymentDueDay &&
          other.isDefault == this.isDefault &&
          other.isArchived == this.isArchived &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WalletsCompanion extends UpdateCompanion<Wallet> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<double> balance;
  final Value<String> currency;
  final Value<String> icon;
  final Value<String> color;
  final Value<bool> isExcludedFromTotal;
  final Value<double?> creditLimit;
  final Value<int?> statementDay;
  final Value<int?> paymentDueDay;
  final Value<bool> isDefault;
  final Value<bool> isArchived;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WalletsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.balance = const Value.absent(),
    this.currency = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.isExcludedFromTotal = const Value.absent(),
    this.creditLimit = const Value.absent(),
    this.statementDay = const Value.absent(),
    this.paymentDueDay = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WalletsCompanion.insert({
    required String id,
    required String name,
    required String type,
    this.balance = const Value.absent(),
    this.currency = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.isExcludedFromTotal = const Value.absent(),
    this.creditLimit = const Value.absent(),
    this.statementDay = const Value.absent(),
    this.paymentDueDay = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        type = Value(type);
  static Insertable<Wallet> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<double>? balance,
    Expression<String>? currency,
    Expression<String>? icon,
    Expression<String>? color,
    Expression<bool>? isExcludedFromTotal,
    Expression<double>? creditLimit,
    Expression<int>? statementDay,
    Expression<int>? paymentDueDay,
    Expression<bool>? isDefault,
    Expression<bool>? isArchived,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (balance != null) 'balance': balance,
      if (currency != null) 'currency': currency,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (isExcludedFromTotal != null)
        'is_excluded_from_total': isExcludedFromTotal,
      if (creditLimit != null) 'credit_limit': creditLimit,
      if (statementDay != null) 'statement_day': statementDay,
      if (paymentDueDay != null) 'payment_due_day': paymentDueDay,
      if (isDefault != null) 'is_default': isDefault,
      if (isArchived != null) 'is_archived': isArchived,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WalletsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? type,
      Value<double>? balance,
      Value<String>? currency,
      Value<String>? icon,
      Value<String>? color,
      Value<bool>? isExcludedFromTotal,
      Value<double?>? creditLimit,
      Value<int?>? statementDay,
      Value<int?>? paymentDueDay,
      Value<bool>? isDefault,
      Value<bool>? isArchived,
      Value<int>? sortOrder,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return WalletsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isExcludedFromTotal: isExcludedFromTotal ?? this.isExcludedFromTotal,
      creditLimit: creditLimit ?? this.creditLimit,
      statementDay: statementDay ?? this.statementDay,
      paymentDueDay: paymentDueDay ?? this.paymentDueDay,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (balance.present) {
      map['balance'] = Variable<double>(balance.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (isExcludedFromTotal.present) {
      map['is_excluded_from_total'] = Variable<bool>(isExcludedFromTotal.value);
    }
    if (creditLimit.present) {
      map['credit_limit'] = Variable<double>(creditLimit.value);
    }
    if (statementDay.present) {
      map['statement_day'] = Variable<int>(statementDay.value);
    }
    if (paymentDueDay.present) {
      map['payment_due_day'] = Variable<int>(paymentDueDay.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('balance: $balance, ')
          ..write('currency: $currency, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('isExcludedFromTotal: $isExcludedFromTotal, ')
          ..write('creditLimit: $creditLimit, ')
          ..write('statementDay: $statementDay, ')
          ..write('paymentDueDay: $paymentDueDay, ')
          ..write('isDefault: $isDefault, ')
          ..write('isArchived: $isArchived, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES categories (id) ON DELETE CASCADE'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 100),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<CategoryType, int> type =
      GeneratedColumn<int>('type', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<CategoryType>($CategoriesTable.$convertertype);
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
      'icon', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Folder'));
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('#6366F1'));
  static const VerificationMeta _budgetLimitMeta =
      const VerificationMeta('budgetLimit');
  @override
  late final GeneratedColumn<double> budgetLimit = GeneratedColumn<double>(
      'budget_limit', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isSystemMeta =
      const VerificationMeta('isSystem');
  @override
  late final GeneratedColumn<bool> isSystem = GeneratedColumn<bool>(
      'is_system', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_system" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        parentId,
        name,
        type,
        icon,
        color,
        budgetLimit,
        sortOrder,
        isSystem,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(Insertable<Category> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
          _iconMeta, icon.isAcceptableOrUnknown(data['icon']!, _iconMeta));
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('budget_limit')) {
      context.handle(
          _budgetLimitMeta,
          budgetLimit.isAcceptableOrUnknown(
              data['budget_limit']!, _budgetLimitMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('is_system')) {
      context.handle(_isSystemMeta,
          isSystem.isAcceptableOrUnknown(data['is_system']!, _isSystemMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_id']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: $CategoriesTable.$convertertype.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!),
      icon: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon'])!,
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color'])!,
      budgetLimit: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}budget_limit']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      isSystem: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_system'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CategoryType, int, int> $convertertype =
      const EnumIndexConverter<CategoryType>(CategoryType.values);
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final String? parentId;
  final String name;
  final CategoryType type;
  final String icon;
  final String color;
  final double? budgetLimit;
  final int sortOrder;
  final bool isSystem;
  final DateTime createdAt;
  const Category(
      {required this.id,
      this.parentId,
      required this.name,
      required this.type,
      required this.icon,
      required this.color,
      this.budgetLimit,
      required this.sortOrder,
      required this.isSystem,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    {
      map['type'] = Variable<int>($CategoriesTable.$convertertype.toSql(type));
    }
    map['icon'] = Variable<String>(icon);
    map['color'] = Variable<String>(color);
    if (!nullToAbsent || budgetLimit != null) {
      map['budget_limit'] = Variable<double>(budgetLimit);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_system'] = Variable<bool>(isSystem);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      type: Value(type),
      icon: Value(icon),
      color: Value(color),
      budgetLimit: budgetLimit == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetLimit),
      sortOrder: Value(sortOrder),
      isSystem: Value(isSystem),
      createdAt: Value(createdAt),
    );
  }

  factory Category.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      name: serializer.fromJson<String>(json['name']),
      type: $CategoriesTable.$convertertype
          .fromJson(serializer.fromJson<int>(json['type'])),
      icon: serializer.fromJson<String>(json['icon']),
      color: serializer.fromJson<String>(json['color']),
      budgetLimit: serializer.fromJson<double?>(json['budgetLimit']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isSystem: serializer.fromJson<bool>(json['isSystem']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'parentId': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'type':
          serializer.toJson<int>($CategoriesTable.$convertertype.toJson(type)),
      'icon': serializer.toJson<String>(icon),
      'color': serializer.toJson<String>(color),
      'budgetLimit': serializer.toJson<double?>(budgetLimit),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isSystem': serializer.toJson<bool>(isSystem),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Category copyWith(
          {String? id,
          Value<String?> parentId = const Value.absent(),
          String? name,
          CategoryType? type,
          String? icon,
          String? color,
          Value<double?> budgetLimit = const Value.absent(),
          int? sortOrder,
          bool? isSystem,
          DateTime? createdAt}) =>
      Category(
        id: id ?? this.id,
        parentId: parentId.present ? parentId.value : this.parentId,
        name: name ?? this.name,
        type: type ?? this.type,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        budgetLimit: budgetLimit.present ? budgetLimit.value : this.budgetLimit,
        sortOrder: sortOrder ?? this.sortOrder,
        isSystem: isSystem ?? this.isSystem,
        createdAt: createdAt ?? this.createdAt,
      );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      budgetLimit:
          data.budgetLimit.present ? data.budgetLimit.value : this.budgetLimit,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isSystem: data.isSystem.present ? data.isSystem.value : this.isSystem,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('budgetLimit: $budgetLimit, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isSystem: $isSystem, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, parentId, name, type, icon, color,
      budgetLimit, sortOrder, isSystem, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.type == this.type &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.budgetLimit == this.budgetLimit &&
          other.sortOrder == this.sortOrder &&
          other.isSystem == this.isSystem &&
          other.createdAt == this.createdAt);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<CategoryType> type;
  final Value<String> icon;
  final Value<String> color;
  final Value<double?> budgetLimit;
  final Value<int> sortOrder;
  final Value<bool> isSystem;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.budgetLimit = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    this.parentId = const Value.absent(),
    required String name,
    required CategoryType type,
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.budgetLimit = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        type = Value(type);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<int>? type,
    Expression<String>? icon,
    Expression<String>? color,
    Expression<double>? budgetLimit,
    Expression<int>? sortOrder,
    Expression<bool>? isSystem,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (budgetLimit != null) 'budget_limit': budgetLimit,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isSystem != null) 'is_system': isSystem,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith(
      {Value<String>? id,
      Value<String?>? parentId,
      Value<String>? name,
      Value<CategoryType>? type,
      Value<String>? icon,
      Value<String>? color,
      Value<double?>? budgetLimit,
      Value<int>? sortOrder,
      Value<bool>? isSystem,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return CategoriesCompanion(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      budgetLimit: budgetLimit ?? this.budgetLimit,
      sortOrder: sortOrder ?? this.sortOrder,
      isSystem: isSystem ?? this.isSystem,
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
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] =
          Variable<int>($CategoriesTable.$convertertype.toSql(type.value));
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (budgetLimit.present) {
      map['budget_limit'] = Variable<double>(budgetLimit.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isSystem.present) {
      map['is_system'] = Variable<bool>(isSystem.value);
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
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('budgetLimit: $budgetLimit, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isSystem: $isSystem, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectBudgetsTable extends ProjectBudgets
    with TableInfo<$ProjectBudgetsTable, ProjectBudget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectBudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
      'tag', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
      'icon', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('🌴'));
  static const VerificationMeta _colorHexMeta =
      const VerificationMeta('colorHex');
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
      'color_hex', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('#0EA5E9'));
  static const VerificationMeta _targetAmountMeta =
      const VerificationMeta('targetAmount');
  @override
  late final GeneratedColumn<double> targetAmount = GeneratedColumn<double>(
      'target_amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _startDateMeta =
      const VerificationMeta('startDate');
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
      'start_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endDateMeta =
      const VerificationMeta('endDate');
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
      'end_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('ACTIVE'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        tag,
        icon,
        colorHex,
        targetAmount,
        startDate,
        endDate,
        status,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_budgets';
  @override
  VerificationContext validateIntegrity(Insertable<ProjectBudget> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
          _tagMeta, tag.isAcceptableOrUnknown(data['tag']!, _tagMeta));
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
          _iconMeta, icon.isAcceptableOrUnknown(data['icon']!, _iconMeta));
    }
    if (data.containsKey('color_hex')) {
      context.handle(_colorHexMeta,
          colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta));
    }
    if (data.containsKey('target_amount')) {
      context.handle(
          _targetAmountMeta,
          targetAmount.isAcceptableOrUnknown(
              data['target_amount']!, _targetAmountMeta));
    } else if (isInserting) {
      context.missing(_targetAmountMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(_startDateMeta,
          startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta));
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(_endDateMeta,
          endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta));
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectBudget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectBudget(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      tag: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tag'])!,
      icon: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon'])!,
      colorHex: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color_hex'])!,
      targetAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}target_amount'])!,
      startDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_date'])!,
      endDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_date'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ProjectBudgetsTable createAlias(String alias) {
    return $ProjectBudgetsTable(attachedDatabase, alias);
  }
}

class ProjectBudget extends DataClass implements Insertable<ProjectBudget> {
  final String id;
  final String title;
  final String tag;
  final String icon;
  final String colorHex;
  final double targetAmount;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ProjectBudget(
      {required this.id,
      required this.title,
      required this.tag,
      required this.icon,
      required this.colorHex,
      required this.targetAmount,
      required this.startDate,
      required this.endDate,
      required this.status,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['tag'] = Variable<String>(tag);
    map['icon'] = Variable<String>(icon);
    map['color_hex'] = Variable<String>(colorHex);
    map['target_amount'] = Variable<double>(targetAmount);
    map['start_date'] = Variable<DateTime>(startDate);
    map['end_date'] = Variable<DateTime>(endDate);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProjectBudgetsCompanion toCompanion(bool nullToAbsent) {
    return ProjectBudgetsCompanion(
      id: Value(id),
      title: Value(title),
      tag: Value(tag),
      icon: Value(icon),
      colorHex: Value(colorHex),
      targetAmount: Value(targetAmount),
      startDate: Value(startDate),
      endDate: Value(endDate),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProjectBudget.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectBudget(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      tag: serializer.fromJson<String>(json['tag']),
      icon: serializer.fromJson<String>(json['icon']),
      colorHex: serializer.fromJson<String>(json['colorHex']),
      targetAmount: serializer.fromJson<double>(json['targetAmount']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime>(json['endDate']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'tag': serializer.toJson<String>(tag),
      'icon': serializer.toJson<String>(icon),
      'colorHex': serializer.toJson<String>(colorHex),
      'targetAmount': serializer.toJson<double>(targetAmount),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime>(endDate),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProjectBudget copyWith(
          {String? id,
          String? title,
          String? tag,
          String? icon,
          String? colorHex,
          double? targetAmount,
          DateTime? startDate,
          DateTime? endDate,
          String? status,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      ProjectBudget(
        id: id ?? this.id,
        title: title ?? this.title,
        tag: tag ?? this.tag,
        icon: icon ?? this.icon,
        colorHex: colorHex ?? this.colorHex,
        targetAmount: targetAmount ?? this.targetAmount,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ProjectBudget copyWithCompanion(ProjectBudgetsCompanion data) {
    return ProjectBudget(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      tag: data.tag.present ? data.tag.value : this.tag,
      icon: data.icon.present ? data.icon.value : this.icon,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      targetAmount: data.targetAmount.present
          ? data.targetAmount.value
          : this.targetAmount,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectBudget(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('tag: $tag, ')
          ..write('icon: $icon, ')
          ..write('colorHex: $colorHex, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, tag, icon, colorHex, targetAmount,
      startDate, endDate, status, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectBudget &&
          other.id == this.id &&
          other.title == this.title &&
          other.tag == this.tag &&
          other.icon == this.icon &&
          other.colorHex == this.colorHex &&
          other.targetAmount == this.targetAmount &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProjectBudgetsCompanion extends UpdateCompanion<ProjectBudget> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> tag;
  final Value<String> icon;
  final Value<String> colorHex;
  final Value<double> targetAmount;
  final Value<DateTime> startDate;
  final Value<DateTime> endDate;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProjectBudgetsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.tag = const Value.absent(),
    this.icon = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.targetAmount = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectBudgetsCompanion.insert({
    required String id,
    required String title,
    required String tag,
    this.icon = const Value.absent(),
    this.colorHex = const Value.absent(),
    required double targetAmount,
    required DateTime startDate,
    required DateTime endDate,
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        tag = Value(tag),
        targetAmount = Value(targetAmount),
        startDate = Value(startDate),
        endDate = Value(endDate);
  static Insertable<ProjectBudget> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? tag,
    Expression<String>? icon,
    Expression<String>? colorHex,
    Expression<double>? targetAmount,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (tag != null) 'tag': tag,
      if (icon != null) 'icon': icon,
      if (colorHex != null) 'color_hex': colorHex,
      if (targetAmount != null) 'target_amount': targetAmount,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectBudgetsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? tag,
      Value<String>? icon,
      Value<String>? colorHex,
      Value<double>? targetAmount,
      Value<DateTime>? startDate,
      Value<DateTime>? endDate,
      Value<String>? status,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ProjectBudgetsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      tag: tag ?? this.tag,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      targetAmount: targetAmount ?? this.targetAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (targetAmount.present) {
      map['target_amount'] = Variable<double>(targetAmount.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectBudgetsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('tag: $tag, ')
          ..write('icon: $icon, ')
          ..write('colorHex: $colorHex, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavingsGoalsTable extends SavingsGoals
    with TableInfo<$SavingsGoalsTable, SavingsGoal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavingsGoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
      'icon', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('🐖'));
  static const VerificationMeta _colorHexMeta =
      const VerificationMeta('colorHex');
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
      'color_hex', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('#10B981'));
  static const VerificationMeta _targetAmountMeta =
      const VerificationMeta('targetAmount');
  @override
  late final GeneratedColumn<double> targetAmount = GeneratedColumn<double>(
      'target_amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _currentAmountMeta =
      const VerificationMeta('currentAmount');
  @override
  late final GeneratedColumn<double> currentAmount = GeneratedColumn<double>(
      'current_amount', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _targetDateMeta =
      const VerificationMeta('targetDate');
  @override
  late final GeneratedColumn<DateTime> targetDate = GeneratedColumn<DateTime>(
      'target_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        icon,
        colorHex,
        targetAmount,
        currentAmount,
        targetDate,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'savings_goals';
  @override
  VerificationContext validateIntegrity(Insertable<SavingsGoal> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
          _iconMeta, icon.isAcceptableOrUnknown(data['icon']!, _iconMeta));
    }
    if (data.containsKey('color_hex')) {
      context.handle(_colorHexMeta,
          colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta));
    }
    if (data.containsKey('target_amount')) {
      context.handle(
          _targetAmountMeta,
          targetAmount.isAcceptableOrUnknown(
              data['target_amount']!, _targetAmountMeta));
    } else if (isInserting) {
      context.missing(_targetAmountMeta);
    }
    if (data.containsKey('current_amount')) {
      context.handle(
          _currentAmountMeta,
          currentAmount.isAcceptableOrUnknown(
              data['current_amount']!, _currentAmountMeta));
    }
    if (data.containsKey('target_date')) {
      context.handle(
          _targetDateMeta,
          targetDate.isAcceptableOrUnknown(
              data['target_date']!, _targetDateMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavingsGoal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavingsGoal(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      icon: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon'])!,
      colorHex: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color_hex'])!,
      targetAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}target_amount'])!,
      currentAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}current_amount'])!,
      targetDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}target_date']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SavingsGoalsTable createAlias(String alias) {
    return $SavingsGoalsTable(attachedDatabase, alias);
  }
}

class SavingsGoal extends DataClass implements Insertable<SavingsGoal> {
  final String id;
  final String title;
  final String icon;
  final String colorHex;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final DateTime createdAt;
  const SavingsGoal(
      {required this.id,
      required this.title,
      required this.icon,
      required this.colorHex,
      required this.targetAmount,
      required this.currentAmount,
      this.targetDate,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['icon'] = Variable<String>(icon);
    map['color_hex'] = Variable<String>(colorHex);
    map['target_amount'] = Variable<double>(targetAmount);
    map['current_amount'] = Variable<double>(currentAmount);
    if (!nullToAbsent || targetDate != null) {
      map['target_date'] = Variable<DateTime>(targetDate);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SavingsGoalsCompanion toCompanion(bool nullToAbsent) {
    return SavingsGoalsCompanion(
      id: Value(id),
      title: Value(title),
      icon: Value(icon),
      colorHex: Value(colorHex),
      targetAmount: Value(targetAmount),
      currentAmount: Value(currentAmount),
      targetDate: targetDate == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDate),
      createdAt: Value(createdAt),
    );
  }

  factory SavingsGoal.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavingsGoal(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      icon: serializer.fromJson<String>(json['icon']),
      colorHex: serializer.fromJson<String>(json['colorHex']),
      targetAmount: serializer.fromJson<double>(json['targetAmount']),
      currentAmount: serializer.fromJson<double>(json['currentAmount']),
      targetDate: serializer.fromJson<DateTime?>(json['targetDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'icon': serializer.toJson<String>(icon),
      'colorHex': serializer.toJson<String>(colorHex),
      'targetAmount': serializer.toJson<double>(targetAmount),
      'currentAmount': serializer.toJson<double>(currentAmount),
      'targetDate': serializer.toJson<DateTime?>(targetDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SavingsGoal copyWith(
          {String? id,
          String? title,
          String? icon,
          String? colorHex,
          double? targetAmount,
          double? currentAmount,
          Value<DateTime?> targetDate = const Value.absent(),
          DateTime? createdAt}) =>
      SavingsGoal(
        id: id ?? this.id,
        title: title ?? this.title,
        icon: icon ?? this.icon,
        colorHex: colorHex ?? this.colorHex,
        targetAmount: targetAmount ?? this.targetAmount,
        currentAmount: currentAmount ?? this.currentAmount,
        targetDate: targetDate.present ? targetDate.value : this.targetDate,
        createdAt: createdAt ?? this.createdAt,
      );
  SavingsGoal copyWithCompanion(SavingsGoalsCompanion data) {
    return SavingsGoal(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      icon: data.icon.present ? data.icon.value : this.icon,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      targetAmount: data.targetAmount.present
          ? data.targetAmount.value
          : this.targetAmount,
      currentAmount: data.currentAmount.present
          ? data.currentAmount.value
          : this.currentAmount,
      targetDate:
          data.targetDate.present ? data.targetDate.value : this.targetDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavingsGoal(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('icon: $icon, ')
          ..write('colorHex: $colorHex, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('currentAmount: $currentAmount, ')
          ..write('targetDate: $targetDate, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, icon, colorHex, targetAmount,
      currentAmount, targetDate, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavingsGoal &&
          other.id == this.id &&
          other.title == this.title &&
          other.icon == this.icon &&
          other.colorHex == this.colorHex &&
          other.targetAmount == this.targetAmount &&
          other.currentAmount == this.currentAmount &&
          other.targetDate == this.targetDate &&
          other.createdAt == this.createdAt);
}

class SavingsGoalsCompanion extends UpdateCompanion<SavingsGoal> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> icon;
  final Value<String> colorHex;
  final Value<double> targetAmount;
  final Value<double> currentAmount;
  final Value<DateTime?> targetDate;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SavingsGoalsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.icon = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.targetAmount = const Value.absent(),
    this.currentAmount = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavingsGoalsCompanion.insert({
    required String id,
    required String title,
    this.icon = const Value.absent(),
    this.colorHex = const Value.absent(),
    required double targetAmount,
    this.currentAmount = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        targetAmount = Value(targetAmount);
  static Insertable<SavingsGoal> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? icon,
    Expression<String>? colorHex,
    Expression<double>? targetAmount,
    Expression<double>? currentAmount,
    Expression<DateTime>? targetDate,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (icon != null) 'icon': icon,
      if (colorHex != null) 'color_hex': colorHex,
      if (targetAmount != null) 'target_amount': targetAmount,
      if (currentAmount != null) 'current_amount': currentAmount,
      if (targetDate != null) 'target_date': targetDate,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavingsGoalsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? icon,
      Value<String>? colorHex,
      Value<double>? targetAmount,
      Value<double>? currentAmount,
      Value<DateTime?>? targetDate,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return SavingsGoalsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
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
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (targetAmount.present) {
      map['target_amount'] = Variable<double>(targetAmount.value);
    }
    if (currentAmount.present) {
      map['current_amount'] = Variable<double>(currentAmount.value);
    }
    if (targetDate.present) {
      map['target_date'] = Variable<DateTime>(targetDate.value);
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
    return (StringBuffer('SavingsGoalsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('icon: $icon, ')
          ..write('colorHex: $colorHex, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('currentAmount: $currentAmount, ')
          ..write('targetDate: $targetDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _walletIdMeta =
      const VerificationMeta('walletId');
  @override
  late final GeneratedColumn<String> walletId = GeneratedColumn<String>(
      'wallet_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES wallets (id) ON DELETE CASCADE'));
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
      'category_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES categories (id) ON DELETE RESTRICT'));
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<CategoryType, int> type =
      GeneratedColumn<int>('type', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<CategoryType>($TransactionsTable.$convertertype);
  static const VerificationMeta _envelopeTypeMeta =
      const VerificationMeta('envelopeType');
  @override
  late final GeneratedColumn<String> envelopeType = GeneratedColumn<String>(
      'envelope_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _merchantMeta =
      const VerificationMeta('merchant');
  @override
  late final GeneratedColumn<String> merchant = GeneratedColumn<String>(
      'merchant', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isAiParsedMeta =
      const VerificationMeta('isAiParsed');
  @override
  late final GeneratedColumn<bool> isAiParsed = GeneratedColumn<bool>(
      'is_ai_parsed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_ai_parsed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _rawReceiptTextMeta =
      const VerificationMeta('rawReceiptText');
  @override
  late final GeneratedColumn<String> rawReceiptText = GeneratedColumn<String>(
      'raw_receipt_text', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _isCycleStartMeta =
      const VerificationMeta('isCycleStart');
  @override
  late final GeneratedColumn<bool> isCycleStart = GeneratedColumn<bool>(
      'is_cycle_start', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_cycle_start" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _projectBudgetIdMeta =
      const VerificationMeta('projectBudgetId');
  @override
  late final GeneratedColumn<String> projectBudgetId = GeneratedColumn<String>(
      'project_budget_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES project_budgets (id) ON DELETE SET NULL'));
  static const VerificationMeta _toWalletIdMeta =
      const VerificationMeta('toWalletId');
  @override
  late final GeneratedColumn<String> toWalletId = GeneratedColumn<String>(
      'to_wallet_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES wallets (id) ON DELETE SET NULL'));
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
      'goal_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES savings_goals (id) ON DELETE CASCADE'));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        walletId,
        categoryId,
        amount,
        type,
        envelopeType,
        date,
        note,
        merchant,
        isAiParsed,
        rawReceiptText,
        createdAt,
        isCycleStart,
        projectBudgetId,
        toWalletId,
        goalId,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(Insertable<Transaction> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('wallet_id')) {
      context.handle(_walletIdMeta,
          walletId.isAcceptableOrUnknown(data['wallet_id']!, _walletIdMeta));
    } else if (isInserting) {
      context.missing(_walletIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('envelope_type')) {
      context.handle(
          _envelopeTypeMeta,
          envelopeType.isAcceptableOrUnknown(
              data['envelope_type']!, _envelopeTypeMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('merchant')) {
      context.handle(_merchantMeta,
          merchant.isAcceptableOrUnknown(data['merchant']!, _merchantMeta));
    }
    if (data.containsKey('is_ai_parsed')) {
      context.handle(
          _isAiParsedMeta,
          isAiParsed.isAcceptableOrUnknown(
              data['is_ai_parsed']!, _isAiParsedMeta));
    }
    if (data.containsKey('raw_receipt_text')) {
      context.handle(
          _rawReceiptTextMeta,
          rawReceiptText.isAcceptableOrUnknown(
              data['raw_receipt_text']!, _rawReceiptTextMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('is_cycle_start')) {
      context.handle(
          _isCycleStartMeta,
          isCycleStart.isAcceptableOrUnknown(
              data['is_cycle_start']!, _isCycleStartMeta));
    }
    if (data.containsKey('project_budget_id')) {
      context.handle(
          _projectBudgetIdMeta,
          projectBudgetId.isAcceptableOrUnknown(
              data['project_budget_id']!, _projectBudgetIdMeta));
    }
    if (data.containsKey('to_wallet_id')) {
      context.handle(
          _toWalletIdMeta,
          toWalletId.isAcceptableOrUnknown(
              data['to_wallet_id']!, _toWalletIdMeta));
    }
    if (data.containsKey('goal_id')) {
      context.handle(_goalIdMeta,
          goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      walletId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}wallet_id'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_id'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      type: $TransactionsTable.$convertertype.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!),
      envelopeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}envelope_type']),
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      merchant: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}merchant']),
      isAiParsed: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_ai_parsed'])!,
      rawReceiptText: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}raw_receipt_text']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      isCycleStart: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_cycle_start'])!,
      projectBudgetId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}project_budget_id']),
      toWalletId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}to_wallet_id']),
      goalId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}goal_id']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CategoryType, int, int> $convertertype =
      const EnumIndexConverter<CategoryType>(CategoryType.values);
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final String id;
  final String walletId;
  final String categoryId;
  final double amount;
  final CategoryType type;
  final String? envelopeType;
  final DateTime date;
  final String? note;
  final String? merchant;
  final bool isAiParsed;
  final String? rawReceiptText;
  final DateTime createdAt;
  final bool isCycleStart;
  final String? projectBudgetId;
  final String? toWalletId;
  final String? goalId;
  final DateTime? deletedAt;
  const Transaction(
      {required this.id,
      required this.walletId,
      required this.categoryId,
      required this.amount,
      required this.type,
      this.envelopeType,
      required this.date,
      this.note,
      this.merchant,
      required this.isAiParsed,
      this.rawReceiptText,
      required this.createdAt,
      required this.isCycleStart,
      this.projectBudgetId,
      this.toWalletId,
      this.goalId,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['wallet_id'] = Variable<String>(walletId);
    map['category_id'] = Variable<String>(categoryId);
    map['amount'] = Variable<double>(amount);
    {
      map['type'] =
          Variable<int>($TransactionsTable.$convertertype.toSql(type));
    }
    if (!nullToAbsent || envelopeType != null) {
      map['envelope_type'] = Variable<String>(envelopeType);
    }
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || merchant != null) {
      map['merchant'] = Variable<String>(merchant);
    }
    map['is_ai_parsed'] = Variable<bool>(isAiParsed);
    if (!nullToAbsent || rawReceiptText != null) {
      map['raw_receipt_text'] = Variable<String>(rawReceiptText);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_cycle_start'] = Variable<bool>(isCycleStart);
    if (!nullToAbsent || projectBudgetId != null) {
      map['project_budget_id'] = Variable<String>(projectBudgetId);
    }
    if (!nullToAbsent || toWalletId != null) {
      map['to_wallet_id'] = Variable<String>(toWalletId);
    }
    if (!nullToAbsent || goalId != null) {
      map['goal_id'] = Variable<String>(goalId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      walletId: Value(walletId),
      categoryId: Value(categoryId),
      amount: Value(amount),
      type: Value(type),
      envelopeType: envelopeType == null && nullToAbsent
          ? const Value.absent()
          : Value(envelopeType),
      date: Value(date),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      merchant: merchant == null && nullToAbsent
          ? const Value.absent()
          : Value(merchant),
      isAiParsed: Value(isAiParsed),
      rawReceiptText: rawReceiptText == null && nullToAbsent
          ? const Value.absent()
          : Value(rawReceiptText),
      createdAt: Value(createdAt),
      isCycleStart: Value(isCycleStart),
      projectBudgetId: projectBudgetId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectBudgetId),
      toWalletId: toWalletId == null && nullToAbsent
          ? const Value.absent()
          : Value(toWalletId),
      goalId:
          goalId == null && nullToAbsent ? const Value.absent() : Value(goalId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Transaction.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<String>(json['id']),
      walletId: serializer.fromJson<String>(json['walletId']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      amount: serializer.fromJson<double>(json['amount']),
      type: $TransactionsTable.$convertertype
          .fromJson(serializer.fromJson<int>(json['type'])),
      envelopeType: serializer.fromJson<String?>(json['envelopeType']),
      date: serializer.fromJson<DateTime>(json['date']),
      note: serializer.fromJson<String?>(json['note']),
      merchant: serializer.fromJson<String?>(json['merchant']),
      isAiParsed: serializer.fromJson<bool>(json['isAiParsed']),
      rawReceiptText: serializer.fromJson<String?>(json['rawReceiptText']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isCycleStart: serializer.fromJson<bool>(json['isCycleStart']),
      projectBudgetId: serializer.fromJson<String?>(json['projectBudgetId']),
      toWalletId: serializer.fromJson<String?>(json['toWalletId']),
      goalId: serializer.fromJson<String?>(json['goalId']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'walletId': serializer.toJson<String>(walletId),
      'categoryId': serializer.toJson<String>(categoryId),
      'amount': serializer.toJson<double>(amount),
      'type': serializer
          .toJson<int>($TransactionsTable.$convertertype.toJson(type)),
      'envelopeType': serializer.toJson<String?>(envelopeType),
      'date': serializer.toJson<DateTime>(date),
      'note': serializer.toJson<String?>(note),
      'merchant': serializer.toJson<String?>(merchant),
      'isAiParsed': serializer.toJson<bool>(isAiParsed),
      'rawReceiptText': serializer.toJson<String?>(rawReceiptText),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isCycleStart': serializer.toJson<bool>(isCycleStart),
      'projectBudgetId': serializer.toJson<String?>(projectBudgetId),
      'toWalletId': serializer.toJson<String?>(toWalletId),
      'goalId': serializer.toJson<String?>(goalId),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Transaction copyWith(
          {String? id,
          String? walletId,
          String? categoryId,
          double? amount,
          CategoryType? type,
          Value<String?> envelopeType = const Value.absent(),
          DateTime? date,
          Value<String?> note = const Value.absent(),
          Value<String?> merchant = const Value.absent(),
          bool? isAiParsed,
          Value<String?> rawReceiptText = const Value.absent(),
          DateTime? createdAt,
          bool? isCycleStart,
          Value<String?> projectBudgetId = const Value.absent(),
          Value<String?> toWalletId = const Value.absent(),
          Value<String?> goalId = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      Transaction(
        id: id ?? this.id,
        walletId: walletId ?? this.walletId,
        categoryId: categoryId ?? this.categoryId,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        envelopeType:
            envelopeType.present ? envelopeType.value : this.envelopeType,
        date: date ?? this.date,
        note: note.present ? note.value : this.note,
        merchant: merchant.present ? merchant.value : this.merchant,
        isAiParsed: isAiParsed ?? this.isAiParsed,
        rawReceiptText:
            rawReceiptText.present ? rawReceiptText.value : this.rawReceiptText,
        createdAt: createdAt ?? this.createdAt,
        isCycleStart: isCycleStart ?? this.isCycleStart,
        projectBudgetId: projectBudgetId.present
            ? projectBudgetId.value
            : this.projectBudgetId,
        toWalletId: toWalletId.present ? toWalletId.value : this.toWalletId,
        goalId: goalId.present ? goalId.value : this.goalId,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      walletId: data.walletId.present ? data.walletId.value : this.walletId,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      amount: data.amount.present ? data.amount.value : this.amount,
      type: data.type.present ? data.type.value : this.type,
      envelopeType: data.envelopeType.present
          ? data.envelopeType.value
          : this.envelopeType,
      date: data.date.present ? data.date.value : this.date,
      note: data.note.present ? data.note.value : this.note,
      merchant: data.merchant.present ? data.merchant.value : this.merchant,
      isAiParsed:
          data.isAiParsed.present ? data.isAiParsed.value : this.isAiParsed,
      rawReceiptText: data.rawReceiptText.present
          ? data.rawReceiptText.value
          : this.rawReceiptText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isCycleStart: data.isCycleStart.present
          ? data.isCycleStart.value
          : this.isCycleStart,
      projectBudgetId: data.projectBudgetId.present
          ? data.projectBudgetId.value
          : this.projectBudgetId,
      toWalletId:
          data.toWalletId.present ? data.toWalletId.value : this.toWalletId,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('walletId: $walletId, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('type: $type, ')
          ..write('envelopeType: $envelopeType, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('merchant: $merchant, ')
          ..write('isAiParsed: $isAiParsed, ')
          ..write('rawReceiptText: $rawReceiptText, ')
          ..write('createdAt: $createdAt, ')
          ..write('isCycleStart: $isCycleStart, ')
          ..write('projectBudgetId: $projectBudgetId, ')
          ..write('toWalletId: $toWalletId, ')
          ..write('goalId: $goalId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      walletId,
      categoryId,
      amount,
      type,
      envelopeType,
      date,
      note,
      merchant,
      isAiParsed,
      rawReceiptText,
      createdAt,
      isCycleStart,
      projectBudgetId,
      toWalletId,
      goalId,
      deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.walletId == this.walletId &&
          other.categoryId == this.categoryId &&
          other.amount == this.amount &&
          other.type == this.type &&
          other.envelopeType == this.envelopeType &&
          other.date == this.date &&
          other.note == this.note &&
          other.merchant == this.merchant &&
          other.isAiParsed == this.isAiParsed &&
          other.rawReceiptText == this.rawReceiptText &&
          other.createdAt == this.createdAt &&
          other.isCycleStart == this.isCycleStart &&
          other.projectBudgetId == this.projectBudgetId &&
          other.toWalletId == this.toWalletId &&
          other.goalId == this.goalId &&
          other.deletedAt == this.deletedAt);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<String> id;
  final Value<String> walletId;
  final Value<String> categoryId;
  final Value<double> amount;
  final Value<CategoryType> type;
  final Value<String?> envelopeType;
  final Value<DateTime> date;
  final Value<String?> note;
  final Value<String?> merchant;
  final Value<bool> isAiParsed;
  final Value<String?> rawReceiptText;
  final Value<DateTime> createdAt;
  final Value<bool> isCycleStart;
  final Value<String?> projectBudgetId;
  final Value<String?> toWalletId;
  final Value<String?> goalId;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.walletId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amount = const Value.absent(),
    this.type = const Value.absent(),
    this.envelopeType = const Value.absent(),
    this.date = const Value.absent(),
    this.note = const Value.absent(),
    this.merchant = const Value.absent(),
    this.isAiParsed = const Value.absent(),
    this.rawReceiptText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isCycleStart = const Value.absent(),
    this.projectBudgetId = const Value.absent(),
    this.toWalletId = const Value.absent(),
    this.goalId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required String id,
    required String walletId,
    required String categoryId,
    required double amount,
    required CategoryType type,
    this.envelopeType = const Value.absent(),
    required DateTime date,
    this.note = const Value.absent(),
    this.merchant = const Value.absent(),
    this.isAiParsed = const Value.absent(),
    this.rawReceiptText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isCycleStart = const Value.absent(),
    this.projectBudgetId = const Value.absent(),
    this.toWalletId = const Value.absent(),
    this.goalId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        walletId = Value(walletId),
        categoryId = Value(categoryId),
        amount = Value(amount),
        type = Value(type),
        date = Value(date);
  static Insertable<Transaction> custom({
    Expression<String>? id,
    Expression<String>? walletId,
    Expression<String>? categoryId,
    Expression<double>? amount,
    Expression<int>? type,
    Expression<String>? envelopeType,
    Expression<DateTime>? date,
    Expression<String>? note,
    Expression<String>? merchant,
    Expression<bool>? isAiParsed,
    Expression<String>? rawReceiptText,
    Expression<DateTime>? createdAt,
    Expression<bool>? isCycleStart,
    Expression<String>? projectBudgetId,
    Expression<String>? toWalletId,
    Expression<String>? goalId,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (walletId != null) 'wallet_id': walletId,
      if (categoryId != null) 'category_id': categoryId,
      if (amount != null) 'amount': amount,
      if (type != null) 'type': type,
      if (envelopeType != null) 'envelope_type': envelopeType,
      if (date != null) 'date': date,
      if (note != null) 'note': note,
      if (merchant != null) 'merchant': merchant,
      if (isAiParsed != null) 'is_ai_parsed': isAiParsed,
      if (rawReceiptText != null) 'raw_receipt_text': rawReceiptText,
      if (createdAt != null) 'created_at': createdAt,
      if (isCycleStart != null) 'is_cycle_start': isCycleStart,
      if (projectBudgetId != null) 'project_budget_id': projectBudgetId,
      if (toWalletId != null) 'to_wallet_id': toWalletId,
      if (goalId != null) 'goal_id': goalId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? walletId,
      Value<String>? categoryId,
      Value<double>? amount,
      Value<CategoryType>? type,
      Value<String?>? envelopeType,
      Value<DateTime>? date,
      Value<String?>? note,
      Value<String?>? merchant,
      Value<bool>? isAiParsed,
      Value<String?>? rawReceiptText,
      Value<DateTime>? createdAt,
      Value<bool>? isCycleStart,
      Value<String?>? projectBudgetId,
      Value<String?>? toWalletId,
      Value<String?>? goalId,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return TransactionsCompanion(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      envelopeType: envelopeType ?? this.envelopeType,
      date: date ?? this.date,
      note: note ?? this.note,
      merchant: merchant ?? this.merchant,
      isAiParsed: isAiParsed ?? this.isAiParsed,
      rawReceiptText: rawReceiptText ?? this.rawReceiptText,
      createdAt: createdAt ?? this.createdAt,
      isCycleStart: isCycleStart ?? this.isCycleStart,
      projectBudgetId: projectBudgetId ?? this.projectBudgetId,
      toWalletId: toWalletId ?? this.toWalletId,
      goalId: goalId ?? this.goalId,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (walletId.present) {
      map['wallet_id'] = Variable<String>(walletId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (type.present) {
      map['type'] =
          Variable<int>($TransactionsTable.$convertertype.toSql(type.value));
    }
    if (envelopeType.present) {
      map['envelope_type'] = Variable<String>(envelopeType.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (merchant.present) {
      map['merchant'] = Variable<String>(merchant.value);
    }
    if (isAiParsed.present) {
      map['is_ai_parsed'] = Variable<bool>(isAiParsed.value);
    }
    if (rawReceiptText.present) {
      map['raw_receipt_text'] = Variable<String>(rawReceiptText.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isCycleStart.present) {
      map['is_cycle_start'] = Variable<bool>(isCycleStart.value);
    }
    if (projectBudgetId.present) {
      map['project_budget_id'] = Variable<String>(projectBudgetId.value);
    }
    if (toWalletId.present) {
      map['to_wallet_id'] = Variable<String>(toWalletId.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
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
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('walletId: $walletId, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('type: $type, ')
          ..write('envelopeType: $envelopeType, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('merchant: $merchant, ')
          ..write('isAiParsed: $isAiParsed, ')
          ..write('rawReceiptText: $rawReceiptText, ')
          ..write('createdAt: $createdAt, ')
          ..write('isCycleStart: $isCycleStart, ')
          ..write('projectBudgetId: $projectBudgetId, ')
          ..write('toWalletId: $toWalletId, ')
          ..write('goalId: $goalId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetsTable extends Budgets with TableInfo<$BudgetsTable, Budget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
      'category_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES categories (id) ON DELETE CASCADE'));
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _cycleStartDayMeta =
      const VerificationMeta('cycleStartDay');
  @override
  late final GeneratedColumn<int> cycleStartDay = GeneratedColumn<int>(
      'cycle_start_day', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _periodMonthMeta =
      const VerificationMeta('periodMonth');
  @override
  late final GeneratedColumn<DateTime> periodMonth = GeneratedColumn<DateTime>(
      'period_month', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, categoryId, amount, cycleStartDay, periodMonth, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(Insertable<Budget> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('cycle_start_day')) {
      context.handle(
          _cycleStartDayMeta,
          cycleStartDay.isAcceptableOrUnknown(
              data['cycle_start_day']!, _cycleStartDayMeta));
    }
    if (data.containsKey('period_month')) {
      context.handle(
          _periodMonthMeta,
          periodMonth.isAcceptableOrUnknown(
              data['period_month']!, _periodMonthMeta));
    } else if (isInserting) {
      context.missing(_periodMonthMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Budget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Budget(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_id'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      cycleStartDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cycle_start_day'])!,
      periodMonth: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}period_month'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $BudgetsTable createAlias(String alias) {
    return $BudgetsTable(attachedDatabase, alias);
  }
}

class Budget extends DataClass implements Insertable<Budget> {
  final String id;
  final String categoryId;
  final double amount;
  final int cycleStartDay;
  final DateTime periodMonth;
  final DateTime createdAt;
  const Budget(
      {required this.id,
      required this.categoryId,
      required this.amount,
      required this.cycleStartDay,
      required this.periodMonth,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category_id'] = Variable<String>(categoryId);
    map['amount'] = Variable<double>(amount);
    map['cycle_start_day'] = Variable<int>(cycleStartDay);
    map['period_month'] = Variable<DateTime>(periodMonth);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BudgetsCompanion toCompanion(bool nullToAbsent) {
    return BudgetsCompanion(
      id: Value(id),
      categoryId: Value(categoryId),
      amount: Value(amount),
      cycleStartDay: Value(cycleStartDay),
      periodMonth: Value(periodMonth),
      createdAt: Value(createdAt),
    );
  }

  factory Budget.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Budget(
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      amount: serializer.fromJson<double>(json['amount']),
      cycleStartDay: serializer.fromJson<int>(json['cycleStartDay']),
      periodMonth: serializer.fromJson<DateTime>(json['periodMonth']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'categoryId': serializer.toJson<String>(categoryId),
      'amount': serializer.toJson<double>(amount),
      'cycleStartDay': serializer.toJson<int>(cycleStartDay),
      'periodMonth': serializer.toJson<DateTime>(periodMonth),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Budget copyWith(
          {String? id,
          String? categoryId,
          double? amount,
          int? cycleStartDay,
          DateTime? periodMonth,
          DateTime? createdAt}) =>
      Budget(
        id: id ?? this.id,
        categoryId: categoryId ?? this.categoryId,
        amount: amount ?? this.amount,
        cycleStartDay: cycleStartDay ?? this.cycleStartDay,
        periodMonth: periodMonth ?? this.periodMonth,
        createdAt: createdAt ?? this.createdAt,
      );
  Budget copyWithCompanion(BudgetsCompanion data) {
    return Budget(
      id: data.id.present ? data.id.value : this.id,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      amount: data.amount.present ? data.amount.value : this.amount,
      cycleStartDay: data.cycleStartDay.present
          ? data.cycleStartDay.value
          : this.cycleStartDay,
      periodMonth:
          data.periodMonth.present ? data.periodMonth.value : this.periodMonth,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Budget(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('cycleStartDay: $cycleStartDay, ')
          ..write('periodMonth: $periodMonth, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, categoryId, amount, cycleStartDay, periodMonth, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Budget &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.amount == this.amount &&
          other.cycleStartDay == this.cycleStartDay &&
          other.periodMonth == this.periodMonth &&
          other.createdAt == this.createdAt);
}

class BudgetsCompanion extends UpdateCompanion<Budget> {
  final Value<String> id;
  final Value<String> categoryId;
  final Value<double> amount;
  final Value<int> cycleStartDay;
  final Value<DateTime> periodMonth;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BudgetsCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amount = const Value.absent(),
    this.cycleStartDay = const Value.absent(),
    this.periodMonth = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetsCompanion.insert({
    required String id,
    required String categoryId,
    required double amount,
    this.cycleStartDay = const Value.absent(),
    required DateTime periodMonth,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        categoryId = Value(categoryId),
        amount = Value(amount),
        periodMonth = Value(periodMonth);
  static Insertable<Budget> custom({
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<double>? amount,
    Expression<int>? cycleStartDay,
    Expression<DateTime>? periodMonth,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (amount != null) 'amount': amount,
      if (cycleStartDay != null) 'cycle_start_day': cycleStartDay,
      if (periodMonth != null) 'period_month': periodMonth,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetsCompanion copyWith(
      {Value<String>? id,
      Value<String>? categoryId,
      Value<double>? amount,
      Value<int>? cycleStartDay,
      Value<DateTime>? periodMonth,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return BudgetsCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      cycleStartDay: cycleStartDay ?? this.cycleStartDay,
      periodMonth: periodMonth ?? this.periodMonth,
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
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (cycleStartDay.present) {
      map['cycle_start_day'] = Variable<int>(cycleStartDay.value);
    }
    if (periodMonth.present) {
      map['period_month'] = Variable<DateTime>(periodMonth.value);
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
    return (StringBuffer('BudgetsCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('cycleStartDay: $cycleStartDay, ')
          ..write('periodMonth: $periodMonth, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetRhythmsTable extends BudgetRhythms
    with TableInfo<$BudgetRhythmsTable, BudgetRhythm> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetRhythmsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _budgetIdMeta =
      const VerificationMeta('budgetId');
  @override
  late final GeneratedColumn<String> budgetId = GeneratedColumn<String>(
      'budget_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES budgets (id) ON DELETE CASCADE'));
  static const VerificationMeta _rhythmMeta = const VerificationMeta('rhythm');
  @override
  late final GeneratedColumn<String> rhythm = GeneratedColumn<String>(
      'rhythm', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _weekStartMeta =
      const VerificationMeta('weekStart');
  @override
  late final GeneratedColumn<int> weekStart = GeneratedColumn<int>(
      'week_start', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _carryRuleMeta =
      const VerificationMeta('carryRule');
  @override
  late final GeneratedColumn<String> carryRule = GeneratedColumn<String>(
      'carry_rule', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('none'));
  static const VerificationMeta _remainingUsesMeta =
      const VerificationMeta('remainingUses');
  @override
  late final GeneratedColumn<int> remainingUses = GeneratedColumn<int>(
      'remaining_uses', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
      'pinned', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("pinned" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [budgetId, rhythm, weekStart, carryRule, remainingUses, pinned];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budget_rhythms';
  @override
  VerificationContext validateIntegrity(Insertable<BudgetRhythm> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('budget_id')) {
      context.handle(_budgetIdMeta,
          budgetId.isAcceptableOrUnknown(data['budget_id']!, _budgetIdMeta));
    } else if (isInserting) {
      context.missing(_budgetIdMeta);
    }
    if (data.containsKey('rhythm')) {
      context.handle(_rhythmMeta,
          rhythm.isAcceptableOrUnknown(data['rhythm']!, _rhythmMeta));
    } else if (isInserting) {
      context.missing(_rhythmMeta);
    }
    if (data.containsKey('week_start')) {
      context.handle(_weekStartMeta,
          weekStart.isAcceptableOrUnknown(data['week_start']!, _weekStartMeta));
    }
    if (data.containsKey('carry_rule')) {
      context.handle(_carryRuleMeta,
          carryRule.isAcceptableOrUnknown(data['carry_rule']!, _carryRuleMeta));
    }
    if (data.containsKey('remaining_uses')) {
      context.handle(
          _remainingUsesMeta,
          remainingUses.isAcceptableOrUnknown(
              data['remaining_uses']!, _remainingUsesMeta));
    }
    if (data.containsKey('pinned')) {
      context.handle(_pinnedMeta,
          pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {budgetId};
  @override
  BudgetRhythm map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BudgetRhythm(
      budgetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}budget_id'])!,
      rhythm: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rhythm'])!,
      weekStart: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}week_start'])!,
      carryRule: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}carry_rule'])!,
      remainingUses: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}remaining_uses']),
      pinned: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}pinned'])!,
    );
  }

  @override
  $BudgetRhythmsTable createAlias(String alias) {
    return $BudgetRhythmsTable(attachedDatabase, alias);
  }
}

class BudgetRhythm extends DataClass implements Insertable<BudgetRhythm> {
  final String budgetId;
  final String rhythm;
  final int weekStart;
  final String carryRule;
  final int? remainingUses;
  final bool pinned;
  const BudgetRhythm(
      {required this.budgetId,
      required this.rhythm,
      required this.weekStart,
      required this.carryRule,
      this.remainingUses,
      required this.pinned});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['budget_id'] = Variable<String>(budgetId);
    map['rhythm'] = Variable<String>(rhythm);
    map['week_start'] = Variable<int>(weekStart);
    map['carry_rule'] = Variable<String>(carryRule);
    if (!nullToAbsent || remainingUses != null) {
      map['remaining_uses'] = Variable<int>(remainingUses);
    }
    map['pinned'] = Variable<bool>(pinned);
    return map;
  }

  BudgetRhythmsCompanion toCompanion(bool nullToAbsent) {
    return BudgetRhythmsCompanion(
      budgetId: Value(budgetId),
      rhythm: Value(rhythm),
      weekStart: Value(weekStart),
      carryRule: Value(carryRule),
      remainingUses: remainingUses == null && nullToAbsent
          ? const Value.absent()
          : Value(remainingUses),
      pinned: Value(pinned),
    );
  }

  factory BudgetRhythm.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BudgetRhythm(
      budgetId: serializer.fromJson<String>(json['budgetId']),
      rhythm: serializer.fromJson<String>(json['rhythm']),
      weekStart: serializer.fromJson<int>(json['weekStart']),
      carryRule: serializer.fromJson<String>(json['carryRule']),
      remainingUses: serializer.fromJson<int?>(json['remainingUses']),
      pinned: serializer.fromJson<bool>(json['pinned']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'budgetId': serializer.toJson<String>(budgetId),
      'rhythm': serializer.toJson<String>(rhythm),
      'weekStart': serializer.toJson<int>(weekStart),
      'carryRule': serializer.toJson<String>(carryRule),
      'remainingUses': serializer.toJson<int?>(remainingUses),
      'pinned': serializer.toJson<bool>(pinned),
    };
  }

  BudgetRhythm copyWith(
          {String? budgetId,
          String? rhythm,
          int? weekStart,
          String? carryRule,
          Value<int?> remainingUses = const Value.absent(),
          bool? pinned}) =>
      BudgetRhythm(
        budgetId: budgetId ?? this.budgetId,
        rhythm: rhythm ?? this.rhythm,
        weekStart: weekStart ?? this.weekStart,
        carryRule: carryRule ?? this.carryRule,
        remainingUses:
            remainingUses.present ? remainingUses.value : this.remainingUses,
        pinned: pinned ?? this.pinned,
      );
  BudgetRhythm copyWithCompanion(BudgetRhythmsCompanion data) {
    return BudgetRhythm(
      budgetId: data.budgetId.present ? data.budgetId.value : this.budgetId,
      rhythm: data.rhythm.present ? data.rhythm.value : this.rhythm,
      weekStart: data.weekStart.present ? data.weekStart.value : this.weekStart,
      carryRule: data.carryRule.present ? data.carryRule.value : this.carryRule,
      remainingUses: data.remainingUses.present
          ? data.remainingUses.value
          : this.remainingUses,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BudgetRhythm(')
          ..write('budgetId: $budgetId, ')
          ..write('rhythm: $rhythm, ')
          ..write('weekStart: $weekStart, ')
          ..write('carryRule: $carryRule, ')
          ..write('remainingUses: $remainingUses, ')
          ..write('pinned: $pinned')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      budgetId, rhythm, weekStart, carryRule, remainingUses, pinned);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetRhythm &&
          other.budgetId == this.budgetId &&
          other.rhythm == this.rhythm &&
          other.weekStart == this.weekStart &&
          other.carryRule == this.carryRule &&
          other.remainingUses == this.remainingUses &&
          other.pinned == this.pinned);
}

class BudgetRhythmsCompanion extends UpdateCompanion<BudgetRhythm> {
  final Value<String> budgetId;
  final Value<String> rhythm;
  final Value<int> weekStart;
  final Value<String> carryRule;
  final Value<int?> remainingUses;
  final Value<bool> pinned;
  final Value<int> rowid;
  const BudgetRhythmsCompanion({
    this.budgetId = const Value.absent(),
    this.rhythm = const Value.absent(),
    this.weekStart = const Value.absent(),
    this.carryRule = const Value.absent(),
    this.remainingUses = const Value.absent(),
    this.pinned = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetRhythmsCompanion.insert({
    required String budgetId,
    required String rhythm,
    this.weekStart = const Value.absent(),
    this.carryRule = const Value.absent(),
    this.remainingUses = const Value.absent(),
    this.pinned = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : budgetId = Value(budgetId),
        rhythm = Value(rhythm);
  static Insertable<BudgetRhythm> custom({
    Expression<String>? budgetId,
    Expression<String>? rhythm,
    Expression<int>? weekStart,
    Expression<String>? carryRule,
    Expression<int>? remainingUses,
    Expression<bool>? pinned,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (budgetId != null) 'budget_id': budgetId,
      if (rhythm != null) 'rhythm': rhythm,
      if (weekStart != null) 'week_start': weekStart,
      if (carryRule != null) 'carry_rule': carryRule,
      if (remainingUses != null) 'remaining_uses': remainingUses,
      if (pinned != null) 'pinned': pinned,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetRhythmsCompanion copyWith(
      {Value<String>? budgetId,
      Value<String>? rhythm,
      Value<int>? weekStart,
      Value<String>? carryRule,
      Value<int?>? remainingUses,
      Value<bool>? pinned,
      Value<int>? rowid}) {
    return BudgetRhythmsCompanion(
      budgetId: budgetId ?? this.budgetId,
      rhythm: rhythm ?? this.rhythm,
      weekStart: weekStart ?? this.weekStart,
      carryRule: carryRule ?? this.carryRule,
      remainingUses: remainingUses ?? this.remainingUses,
      pinned: pinned ?? this.pinned,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (budgetId.present) {
      map['budget_id'] = Variable<String>(budgetId.value);
    }
    if (rhythm.present) {
      map['rhythm'] = Variable<String>(rhythm.value);
    }
    if (weekStart.present) {
      map['week_start'] = Variable<int>(weekStart.value);
    }
    if (carryRule.present) {
      map['carry_rule'] = Variable<String>(carryRule.value);
    }
    if (remainingUses.present) {
      map['remaining_uses'] = Variable<int>(remainingUses.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetRhythmsCompanion(')
          ..write('budgetId: $budgetId, ')
          ..write('rhythm: $rhythm, ')
          ..write('weekStart: $weekStart, ')
          ..write('carryRule: $carryRule, ')
          ..write('remainingUses: $remainingUses, ')
          ..write('pinned: $pinned, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DebtContactsTable extends DebtContacts
    with TableInfo<$DebtContactsTable, DebtContact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DebtContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 120),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _avatarUrlMeta =
      const VerificationMeta('avatarUrl');
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
      'avatar_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _netBalanceMeta =
      const VerificationMeta('netBalance');
  @override
  late final GeneratedColumn<double> netBalance = GeneratedColumn<double>(
      'net_balance', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, phone, avatarUrl, netBalance, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'debt_contacts';
  @override
  VerificationContext validateIntegrity(Insertable<DebtContact> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('avatar_url')) {
      context.handle(_avatarUrlMeta,
          avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta));
    }
    if (data.containsKey('net_balance')) {
      context.handle(
          _netBalanceMeta,
          netBalance.isAcceptableOrUnknown(
              data['net_balance']!, _netBalanceMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DebtContact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DebtContact(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone']),
      avatarUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_url']),
      netBalance: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}net_balance'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $DebtContactsTable createAlias(String alias) {
    return $DebtContactsTable(attachedDatabase, alias);
  }
}

class DebtContact extends DataClass implements Insertable<DebtContact> {
  final String id;
  final String name;
  final String? phone;
  final String? avatarUrl;
  final double netBalance;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DebtContact(
      {required this.id,
      required this.name,
      this.phone,
      this.avatarUrl,
      required this.netBalance,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    map['net_balance'] = Variable<double>(netBalance);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DebtContactsCompanion toCompanion(bool nullToAbsent) {
    return DebtContactsCompanion(
      id: Value(id),
      name: Value(name),
      phone:
          phone == null && nullToAbsent ? const Value.absent() : Value(phone),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
      netBalance: Value(netBalance),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DebtContact.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DebtContact(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
      netBalance: serializer.fromJson<double>(json['netBalance']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String?>(phone),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
      'netBalance': serializer.toJson<double>(netBalance),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DebtContact copyWith(
          {String? id,
          String? name,
          Value<String?> phone = const Value.absent(),
          Value<String?> avatarUrl = const Value.absent(),
          double? netBalance,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      DebtContact(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone.present ? phone.value : this.phone,
        avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
        netBalance: netBalance ?? this.netBalance,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  DebtContact copyWithCompanion(DebtContactsCompanion data) {
    return DebtContact(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      netBalance:
          data.netBalance.present ? data.netBalance.value : this.netBalance,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DebtContact(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('netBalance: $netBalance, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, phone, avatarUrl, netBalance, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DebtContact &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.avatarUrl == this.avatarUrl &&
          other.netBalance == this.netBalance &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DebtContactsCompanion extends UpdateCompanion<DebtContact> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> phone;
  final Value<String?> avatarUrl;
  final Value<double> netBalance;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DebtContactsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.netBalance = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DebtContactsCompanion.insert({
    required String id,
    required String name,
    this.phone = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.netBalance = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<DebtContact> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? avatarUrl,
    Expression<double>? netBalance,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (netBalance != null) 'net_balance': netBalance,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DebtContactsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? phone,
      Value<String?>? avatarUrl,
      Value<double>? netBalance,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return DebtContactsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      netBalance: netBalance ?? this.netBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (netBalance.present) {
      map['net_balance'] = Variable<double>(netBalance.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DebtContactsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('netBalance: $netBalance, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DebtTransactionsTable extends DebtTransactions
    with TableInfo<$DebtTransactionsTable, DebtTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DebtTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contactIdMeta =
      const VerificationMeta('contactId');
  @override
  late final GeneratedColumn<String> contactId = GeneratedColumn<String>(
      'contact_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES debt_contacts (id) ON DELETE CASCADE'));
  static const VerificationMeta _walletIdMeta =
      const VerificationMeta('walletId');
  @override
  late final GeneratedColumn<String> walletId = GeneratedColumn<String>(
      'wallet_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES wallets (id)'));
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _dueDateMeta =
      const VerificationMeta('dueDate');
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
      'due_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isSettledMeta =
      const VerificationMeta('isSettled');
  @override
  late final GeneratedColumn<bool> isSettled = GeneratedColumn<bool>(
      'is_settled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_settled" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        contactId,
        walletId,
        type,
        amount,
        date,
        dueDate,
        note,
        isSettled,
        createdAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'debt_transactions';
  @override
  VerificationContext validateIntegrity(Insertable<DebtTransaction> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('contact_id')) {
      context.handle(_contactIdMeta,
          contactId.isAcceptableOrUnknown(data['contact_id']!, _contactIdMeta));
    } else if (isInserting) {
      context.missing(_contactIdMeta);
    }
    if (data.containsKey('wallet_id')) {
      context.handle(_walletIdMeta,
          walletId.isAcceptableOrUnknown(data['wallet_id']!, _walletIdMeta));
    } else if (isInserting) {
      context.missing(_walletIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('due_date')) {
      context.handle(_dueDateMeta,
          dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('is_settled')) {
      context.handle(_isSettledMeta,
          isSettled.isAcceptableOrUnknown(data['is_settled']!, _isSettledMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DebtTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DebtTransaction(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      contactId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contact_id'])!,
      walletId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}wallet_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      dueDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}due_date']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      isSettled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_settled'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $DebtTransactionsTable createAlias(String alias) {
    return $DebtTransactionsTable(attachedDatabase, alias);
  }
}

class DebtTransaction extends DataClass implements Insertable<DebtTransaction> {
  final String id;
  final String contactId;
  final String walletId;
  final String type;
  final double amount;
  final DateTime date;
  final DateTime? dueDate;
  final String? note;
  final bool isSettled;
  final DateTime createdAt;
  final DateTime? deletedAt;
  const DebtTransaction(
      {required this.id,
      required this.contactId,
      required this.walletId,
      required this.type,
      required this.amount,
      required this.date,
      this.dueDate,
      this.note,
      required this.isSettled,
      required this.createdAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['contact_id'] = Variable<String>(contactId);
    map['wallet_id'] = Variable<String>(walletId);
    map['type'] = Variable<String>(type);
    map['amount'] = Variable<double>(amount);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['is_settled'] = Variable<bool>(isSettled);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  DebtTransactionsCompanion toCompanion(bool nullToAbsent) {
    return DebtTransactionsCompanion(
      id: Value(id),
      contactId: Value(contactId),
      walletId: Value(walletId),
      type: Value(type),
      amount: Value(amount),
      date: Value(date),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      isSettled: Value(isSettled),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory DebtTransaction.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DebtTransaction(
      id: serializer.fromJson<String>(json['id']),
      contactId: serializer.fromJson<String>(json['contactId']),
      walletId: serializer.fromJson<String>(json['walletId']),
      type: serializer.fromJson<String>(json['type']),
      amount: serializer.fromJson<double>(json['amount']),
      date: serializer.fromJson<DateTime>(json['date']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      note: serializer.fromJson<String?>(json['note']),
      isSettled: serializer.fromJson<bool>(json['isSettled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'contactId': serializer.toJson<String>(contactId),
      'walletId': serializer.toJson<String>(walletId),
      'type': serializer.toJson<String>(type),
      'amount': serializer.toJson<double>(amount),
      'date': serializer.toJson<DateTime>(date),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'note': serializer.toJson<String?>(note),
      'isSettled': serializer.toJson<bool>(isSettled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  DebtTransaction copyWith(
          {String? id,
          String? contactId,
          String? walletId,
          String? type,
          double? amount,
          DateTime? date,
          Value<DateTime?> dueDate = const Value.absent(),
          Value<String?> note = const Value.absent(),
          bool? isSettled,
          DateTime? createdAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      DebtTransaction(
        id: id ?? this.id,
        contactId: contactId ?? this.contactId,
        walletId: walletId ?? this.walletId,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        dueDate: dueDate.present ? dueDate.value : this.dueDate,
        note: note.present ? note.value : this.note,
        isSettled: isSettled ?? this.isSettled,
        createdAt: createdAt ?? this.createdAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  DebtTransaction copyWithCompanion(DebtTransactionsCompanion data) {
    return DebtTransaction(
      id: data.id.present ? data.id.value : this.id,
      contactId: data.contactId.present ? data.contactId.value : this.contactId,
      walletId: data.walletId.present ? data.walletId.value : this.walletId,
      type: data.type.present ? data.type.value : this.type,
      amount: data.amount.present ? data.amount.value : this.amount,
      date: data.date.present ? data.date.value : this.date,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      note: data.note.present ? data.note.value : this.note,
      isSettled: data.isSettled.present ? data.isSettled.value : this.isSettled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DebtTransaction(')
          ..write('id: $id, ')
          ..write('contactId: $contactId, ')
          ..write('walletId: $walletId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('date: $date, ')
          ..write('dueDate: $dueDate, ')
          ..write('note: $note, ')
          ..write('isSettled: $isSettled, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, contactId, walletId, type, amount, date,
      dueDate, note, isSettled, createdAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DebtTransaction &&
          other.id == this.id &&
          other.contactId == this.contactId &&
          other.walletId == this.walletId &&
          other.type == this.type &&
          other.amount == this.amount &&
          other.date == this.date &&
          other.dueDate == this.dueDate &&
          other.note == this.note &&
          other.isSettled == this.isSettled &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class DebtTransactionsCompanion extends UpdateCompanion<DebtTransaction> {
  final Value<String> id;
  final Value<String> contactId;
  final Value<String> walletId;
  final Value<String> type;
  final Value<double> amount;
  final Value<DateTime> date;
  final Value<DateTime?> dueDate;
  final Value<String?> note;
  final Value<bool> isSettled;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const DebtTransactionsCompanion({
    this.id = const Value.absent(),
    this.contactId = const Value.absent(),
    this.walletId = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.date = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.note = const Value.absent(),
    this.isSettled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DebtTransactionsCompanion.insert({
    required String id,
    required String contactId,
    required String walletId,
    required String type,
    required double amount,
    required DateTime date,
    this.dueDate = const Value.absent(),
    this.note = const Value.absent(),
    this.isSettled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        contactId = Value(contactId),
        walletId = Value(walletId),
        type = Value(type),
        amount = Value(amount),
        date = Value(date);
  static Insertable<DebtTransaction> custom({
    Expression<String>? id,
    Expression<String>? contactId,
    Expression<String>? walletId,
    Expression<String>? type,
    Expression<double>? amount,
    Expression<DateTime>? date,
    Expression<DateTime>? dueDate,
    Expression<String>? note,
    Expression<bool>? isSettled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (contactId != null) 'contact_id': contactId,
      if (walletId != null) 'wallet_id': walletId,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (date != null) 'date': date,
      if (dueDate != null) 'due_date': dueDate,
      if (note != null) 'note': note,
      if (isSettled != null) 'is_settled': isSettled,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DebtTransactionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? contactId,
      Value<String>? walletId,
      Value<String>? type,
      Value<double>? amount,
      Value<DateTime>? date,
      Value<DateTime?>? dueDate,
      Value<String?>? note,
      Value<bool>? isSettled,
      Value<DateTime>? createdAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return DebtTransactionsCompanion(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      walletId: walletId ?? this.walletId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      note: note ?? this.note,
      isSettled: isSettled ?? this.isSettled,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (contactId.present) {
      map['contact_id'] = Variable<String>(contactId.value);
    }
    if (walletId.present) {
      map['wallet_id'] = Variable<String>(walletId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (isSettled.present) {
      map['is_settled'] = Variable<bool>(isSettled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('DebtTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('contactId: $contactId, ')
          ..write('walletId: $walletId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('date: $date, ')
          ..write('dueDate: $dueDate, ')
          ..write('note: $note, ')
          ..write('isSettled: $isSettled, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppNotificationsTable extends AppNotifications
    with TableInfo<$AppNotificationsTable, AppNotification> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppNotificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dedupKeyMeta =
      const VerificationMeta('dedupKey');
  @override
  late final GeneratedColumn<String> dedupKey = GeneratedColumn<String>(
      'dedup_key', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 150),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _relatedEntityIdMeta =
      const VerificationMeta('relatedEntityId');
  @override
  late final GeneratedColumn<String> relatedEntityId = GeneratedColumn<String>(
      'related_entity_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
      'is_read', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_read" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isDismissedMeta =
      const VerificationMeta('isDismissed');
  @override
  late final GeneratedColumn<bool> isDismissed = GeneratedColumn<bool>(
      'is_dismissed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_dismissed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        dedupKey,
        title,
        body,
        type,
        payload,
        relatedEntityId,
        isRead,
        isDismissed,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_notifications';
  @override
  VerificationContext validateIntegrity(Insertable<AppNotification> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dedup_key')) {
      context.handle(_dedupKeyMeta,
          dedupKey.isAcceptableOrUnknown(data['dedup_key']!, _dedupKeyMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    }
    if (data.containsKey('related_entity_id')) {
      context.handle(
          _relatedEntityIdMeta,
          relatedEntityId.isAcceptableOrUnknown(
              data['related_entity_id']!, _relatedEntityIdMeta));
    }
    if (data.containsKey('is_read')) {
      context.handle(_isReadMeta,
          isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta));
    }
    if (data.containsKey('is_dismissed')) {
      context.handle(
          _isDismissedMeta,
          isDismissed.isAcceptableOrUnknown(
              data['is_dismissed']!, _isDismissedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppNotification map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppNotification(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      dedupKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dedup_key']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload']),
      relatedEntityId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}related_entity_id']),
      isRead: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_read'])!,
      isDismissed: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_dismissed'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AppNotificationsTable createAlias(String alias) {
    return $AppNotificationsTable(attachedDatabase, alias);
  }
}

class AppNotification extends DataClass implements Insertable<AppNotification> {
  final String id;
  final String? dedupKey;
  final String title;
  final String body;
  final String type;
  final String? payload;
  final String? relatedEntityId;
  final bool isRead;
  final bool isDismissed;
  final DateTime createdAt;
  const AppNotification(
      {required this.id,
      this.dedupKey,
      required this.title,
      required this.body,
      required this.type,
      this.payload,
      this.relatedEntityId,
      required this.isRead,
      required this.isDismissed,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || dedupKey != null) {
      map['dedup_key'] = Variable<String>(dedupKey);
    }
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    if (!nullToAbsent || relatedEntityId != null) {
      map['related_entity_id'] = Variable<String>(relatedEntityId);
    }
    map['is_read'] = Variable<bool>(isRead);
    map['is_dismissed'] = Variable<bool>(isDismissed);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AppNotificationsCompanion toCompanion(bool nullToAbsent) {
    return AppNotificationsCompanion(
      id: Value(id),
      dedupKey: dedupKey == null && nullToAbsent
          ? const Value.absent()
          : Value(dedupKey),
      title: Value(title),
      body: Value(body),
      type: Value(type),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      relatedEntityId: relatedEntityId == null && nullToAbsent
          ? const Value.absent()
          : Value(relatedEntityId),
      isRead: Value(isRead),
      isDismissed: Value(isDismissed),
      createdAt: Value(createdAt),
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppNotification(
      id: serializer.fromJson<String>(json['id']),
      dedupKey: serializer.fromJson<String?>(json['dedupKey']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      type: serializer.fromJson<String>(json['type']),
      payload: serializer.fromJson<String?>(json['payload']),
      relatedEntityId: serializer.fromJson<String?>(json['relatedEntityId']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      isDismissed: serializer.fromJson<bool>(json['isDismissed']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dedupKey': serializer.toJson<String?>(dedupKey),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'type': serializer.toJson<String>(type),
      'payload': serializer.toJson<String?>(payload),
      'relatedEntityId': serializer.toJson<String?>(relatedEntityId),
      'isRead': serializer.toJson<bool>(isRead),
      'isDismissed': serializer.toJson<bool>(isDismissed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AppNotification copyWith(
          {String? id,
          Value<String?> dedupKey = const Value.absent(),
          String? title,
          String? body,
          String? type,
          Value<String?> payload = const Value.absent(),
          Value<String?> relatedEntityId = const Value.absent(),
          bool? isRead,
          bool? isDismissed,
          DateTime? createdAt}) =>
      AppNotification(
        id: id ?? this.id,
        dedupKey: dedupKey.present ? dedupKey.value : this.dedupKey,
        title: title ?? this.title,
        body: body ?? this.body,
        type: type ?? this.type,
        payload: payload.present ? payload.value : this.payload,
        relatedEntityId: relatedEntityId.present
            ? relatedEntityId.value
            : this.relatedEntityId,
        isRead: isRead ?? this.isRead,
        isDismissed: isDismissed ?? this.isDismissed,
        createdAt: createdAt ?? this.createdAt,
      );
  AppNotification copyWithCompanion(AppNotificationsCompanion data) {
    return AppNotification(
      id: data.id.present ? data.id.value : this.id,
      dedupKey: data.dedupKey.present ? data.dedupKey.value : this.dedupKey,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      type: data.type.present ? data.type.value : this.type,
      payload: data.payload.present ? data.payload.value : this.payload,
      relatedEntityId: data.relatedEntityId.present
          ? data.relatedEntityId.value
          : this.relatedEntityId,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      isDismissed:
          data.isDismissed.present ? data.isDismissed.value : this.isDismissed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppNotification(')
          ..write('id: $id, ')
          ..write('dedupKey: $dedupKey, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('type: $type, ')
          ..write('payload: $payload, ')
          ..write('relatedEntityId: $relatedEntityId, ')
          ..write('isRead: $isRead, ')
          ..write('isDismissed: $isDismissed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dedupKey, title, body, type, payload,
      relatedEntityId, isRead, isDismissed, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppNotification &&
          other.id == this.id &&
          other.dedupKey == this.dedupKey &&
          other.title == this.title &&
          other.body == this.body &&
          other.type == this.type &&
          other.payload == this.payload &&
          other.relatedEntityId == this.relatedEntityId &&
          other.isRead == this.isRead &&
          other.isDismissed == this.isDismissed &&
          other.createdAt == this.createdAt);
}

class AppNotificationsCompanion extends UpdateCompanion<AppNotification> {
  final Value<String> id;
  final Value<String?> dedupKey;
  final Value<String> title;
  final Value<String> body;
  final Value<String> type;
  final Value<String?> payload;
  final Value<String?> relatedEntityId;
  final Value<bool> isRead;
  final Value<bool> isDismissed;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AppNotificationsCompanion({
    this.id = const Value.absent(),
    this.dedupKey = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.type = const Value.absent(),
    this.payload = const Value.absent(),
    this.relatedEntityId = const Value.absent(),
    this.isRead = const Value.absent(),
    this.isDismissed = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppNotificationsCompanion.insert({
    required String id,
    this.dedupKey = const Value.absent(),
    required String title,
    required String body,
    required String type,
    this.payload = const Value.absent(),
    this.relatedEntityId = const Value.absent(),
    this.isRead = const Value.absent(),
    this.isDismissed = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        body = Value(body),
        type = Value(type);
  static Insertable<AppNotification> custom({
    Expression<String>? id,
    Expression<String>? dedupKey,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? type,
    Expression<String>? payload,
    Expression<String>? relatedEntityId,
    Expression<bool>? isRead,
    Expression<bool>? isDismissed,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dedupKey != null) 'dedup_key': dedupKey,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (type != null) 'type': type,
      if (payload != null) 'payload': payload,
      if (relatedEntityId != null) 'related_entity_id': relatedEntityId,
      if (isRead != null) 'is_read': isRead,
      if (isDismissed != null) 'is_dismissed': isDismissed,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppNotificationsCompanion copyWith(
      {Value<String>? id,
      Value<String?>? dedupKey,
      Value<String>? title,
      Value<String>? body,
      Value<String>? type,
      Value<String?>? payload,
      Value<String?>? relatedEntityId,
      Value<bool>? isRead,
      Value<bool>? isDismissed,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return AppNotificationsCompanion(
      id: id ?? this.id,
      dedupKey: dedupKey ?? this.dedupKey,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      relatedEntityId: relatedEntityId ?? this.relatedEntityId,
      isRead: isRead ?? this.isRead,
      isDismissed: isDismissed ?? this.isDismissed,
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
    if (dedupKey.present) {
      map['dedup_key'] = Variable<String>(dedupKey.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (relatedEntityId.present) {
      map['related_entity_id'] = Variable<String>(relatedEntityId.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (isDismissed.present) {
      map['is_dismissed'] = Variable<bool>(isDismissed.value);
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
    return (StringBuffer('AppNotificationsCompanion(')
          ..write('id: $id, ')
          ..write('dedupKey: $dedupKey, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('type: $type, ')
          ..write('payload: $payload, ')
          ..write('relatedEntityId: $relatedEntityId, ')
          ..write('isRead: $isRead, ')
          ..write('isDismissed: $isDismissed, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationReceiptsTable extends NotificationReceipts
    with TableInfo<$NotificationReceiptsTable, NotificationReceipt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationReceiptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dedupKeyMeta =
      const VerificationMeta('dedupKey');
  @override
  late final GeneratedColumn<String> dedupKey = GeneratedColumn<String>(
      'dedup_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [dedupKey];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_receipts';
  @override
  VerificationContext validateIntegrity(
      Insertable<NotificationReceipt> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('dedup_key')) {
      context.handle(_dedupKeyMeta,
          dedupKey.isAcceptableOrUnknown(data['dedup_key']!, _dedupKeyMeta));
    } else if (isInserting) {
      context.missing(_dedupKeyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dedupKey};
  @override
  NotificationReceipt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationReceipt(
      dedupKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dedup_key'])!,
    );
  }

  @override
  $NotificationReceiptsTable createAlias(String alias) {
    return $NotificationReceiptsTable(attachedDatabase, alias);
  }
}

class NotificationReceipt extends DataClass
    implements Insertable<NotificationReceipt> {
  final String dedupKey;
  const NotificationReceipt({required this.dedupKey});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['dedup_key'] = Variable<String>(dedupKey);
    return map;
  }

  NotificationReceiptsCompanion toCompanion(bool nullToAbsent) {
    return NotificationReceiptsCompanion(
      dedupKey: Value(dedupKey),
    );
  }

  factory NotificationReceipt.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationReceipt(
      dedupKey: serializer.fromJson<String>(json['dedupKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dedupKey': serializer.toJson<String>(dedupKey),
    };
  }

  NotificationReceipt copyWith({String? dedupKey}) => NotificationReceipt(
        dedupKey: dedupKey ?? this.dedupKey,
      );
  NotificationReceipt copyWithCompanion(NotificationReceiptsCompanion data) {
    return NotificationReceipt(
      dedupKey: data.dedupKey.present ? data.dedupKey.value : this.dedupKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationReceipt(')
          ..write('dedupKey: $dedupKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => dedupKey.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationReceipt && other.dedupKey == this.dedupKey);
}

class NotificationReceiptsCompanion
    extends UpdateCompanion<NotificationReceipt> {
  final Value<String> dedupKey;
  final Value<int> rowid;
  const NotificationReceiptsCompanion({
    this.dedupKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationReceiptsCompanion.insert({
    required String dedupKey,
    this.rowid = const Value.absent(),
  }) : dedupKey = Value(dedupKey);
  static Insertable<NotificationReceipt> custom({
    Expression<String>? dedupKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dedupKey != null) 'dedup_key': dedupKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationReceiptsCompanion copyWith(
      {Value<String>? dedupKey, Value<int>? rowid}) {
    return NotificationReceiptsCompanion(
      dedupKey: dedupKey ?? this.dedupKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dedupKey.present) {
      map['dedup_key'] = Variable<String>(dedupKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationReceiptsCompanion(')
          ..write('dedupKey: $dedupKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntityArchivesTable extends EntityArchives
    with TableInfo<$EntityArchivesTable, EntityArchive> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntityArchivesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _archivedAtMeta =
      const VerificationMeta('archivedAt');
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
      'archived_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [entityId, entityType, archivedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entity_archives';
  @override
  VerificationContext validateIntegrity(Insertable<EntityArchive> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
          _archivedAtMeta,
          archivedAt.isAcceptableOrUnknown(
              data['archived_at']!, _archivedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entityId, entityType};
  @override
  EntityArchive map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntityArchive(
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      archivedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}archived_at'])!,
    );
  }

  @override
  $EntityArchivesTable createAlias(String alias) {
    return $EntityArchivesTable(attachedDatabase, alias);
  }
}

class EntityArchive extends DataClass implements Insertable<EntityArchive> {
  final String entityId;
  final String entityType;
  final DateTime archivedAt;
  const EntityArchive(
      {required this.entityId,
      required this.entityType,
      required this.archivedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity_id'] = Variable<String>(entityId);
    map['entity_type'] = Variable<String>(entityType);
    map['archived_at'] = Variable<DateTime>(archivedAt);
    return map;
  }

  EntityArchivesCompanion toCompanion(bool nullToAbsent) {
    return EntityArchivesCompanion(
      entityId: Value(entityId),
      entityType: Value(entityType),
      archivedAt: Value(archivedAt),
    );
  }

  factory EntityArchive.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntityArchive(
      entityId: serializer.fromJson<String>(json['entityId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      archivedAt: serializer.fromJson<DateTime>(json['archivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entityId': serializer.toJson<String>(entityId),
      'entityType': serializer.toJson<String>(entityType),
      'archivedAt': serializer.toJson<DateTime>(archivedAt),
    };
  }

  EntityArchive copyWith(
          {String? entityId, String? entityType, DateTime? archivedAt}) =>
      EntityArchive(
        entityId: entityId ?? this.entityId,
        entityType: entityType ?? this.entityType,
        archivedAt: archivedAt ?? this.archivedAt,
      );
  EntityArchive copyWithCompanion(EntityArchivesCompanion data) {
    return EntityArchive(
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      archivedAt:
          data.archivedAt.present ? data.archivedAt.value : this.archivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntityArchive(')
          ..write('entityId: $entityId, ')
          ..write('entityType: $entityType, ')
          ..write('archivedAt: $archivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entityId, entityType, archivedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntityArchive &&
          other.entityId == this.entityId &&
          other.entityType == this.entityType &&
          other.archivedAt == this.archivedAt);
}

class EntityArchivesCompanion extends UpdateCompanion<EntityArchive> {
  final Value<String> entityId;
  final Value<String> entityType;
  final Value<DateTime> archivedAt;
  final Value<int> rowid;
  const EntityArchivesCompanion({
    this.entityId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntityArchivesCompanion.insert({
    required String entityId,
    required String entityType,
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : entityId = Value(entityId),
        entityType = Value(entityType);
  static Insertable<EntityArchive> custom({
    Expression<String>? entityId,
    Expression<String>? entityType,
    Expression<DateTime>? archivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entityId != null) 'entity_id': entityId,
      if (entityType != null) 'entity_type': entityType,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntityArchivesCompanion copyWith(
      {Value<String>? entityId,
      Value<String>? entityType,
      Value<DateTime>? archivedAt,
      Value<int>? rowid}) {
    return EntityArchivesCompanion(
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
      archivedAt: archivedAt ?? this.archivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntityArchivesCompanion(')
          ..write('entityId: $entityId, ')
          ..write('entityType: $entityType, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WalletsTable wallets = $WalletsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $ProjectBudgetsTable projectBudgets = $ProjectBudgetsTable(this);
  late final $SavingsGoalsTable savingsGoals = $SavingsGoalsTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $BudgetsTable budgets = $BudgetsTable(this);
  late final $BudgetRhythmsTable budgetRhythms = $BudgetRhythmsTable(this);
  late final $DebtContactsTable debtContacts = $DebtContactsTable(this);
  late final $DebtTransactionsTable debtTransactions =
      $DebtTransactionsTable(this);
  late final $AppNotificationsTable appNotifications =
      $AppNotificationsTable(this);
  late final $NotificationReceiptsTable notificationReceipts =
      $NotificationReceiptsTable(this);
  late final $EntityArchivesTable entityArchives = $EntityArchivesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        wallets,
        categories,
        projectBudgets,
        savingsGoals,
        transactions,
        budgets,
        budgetRhythms,
        debtContacts,
        debtTransactions,
        appNotifications,
        notificationReceipts,
        entityArchives
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('categories',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('categories', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('wallets',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('transactions', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('project_budgets',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('transactions', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('wallets',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('transactions', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('savings_goals',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('transactions', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('categories',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('budgets', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('budgets',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('budget_rhythms', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('debt_contacts',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('debt_transactions', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$WalletsTableCreateCompanionBuilder = WalletsCompanion Function({
  required String id,
  required String name,
  required String type,
  Value<double> balance,
  Value<String> currency,
  Value<String> icon,
  Value<String> color,
  Value<bool> isExcludedFromTotal,
  Value<double?> creditLimit,
  Value<int?> statementDay,
  Value<int?> paymentDueDay,
  Value<bool> isDefault,
  Value<bool> isArchived,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$WalletsTableUpdateCompanionBuilder = WalletsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> type,
  Value<double> balance,
  Value<String> currency,
  Value<String> icon,
  Value<String> color,
  Value<bool> isExcludedFromTotal,
  Value<double?> creditLimit,
  Value<int?> statementDay,
  Value<int?> paymentDueDay,
  Value<bool> isDefault,
  Value<bool> isArchived,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$WalletsTableReferences
    extends BaseReferences<_$AppDatabase, $WalletsTable, Wallet> {
  $$WalletsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DebtTransactionsTable, List<DebtTransaction>>
      _debtTransactionsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.debtTransactions,
              aliasName: 'wallets__id__debt_transactions__wallet_id');

  $$DebtTransactionsTableProcessedTableManager get debtTransactionsRefs {
    final manager = $$DebtTransactionsTableTableManager(
            $_db, $_db.debtTransactions)
        .filter((f) => f.walletId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_debtTransactionsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$WalletsTableFilterComposer
    extends Composer<_$AppDatabase, $WalletsTable> {
  $$WalletsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get balance => $composableBuilder(
      column: $table.balance, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isExcludedFromTotal => $composableBuilder(
      column: $table.isExcludedFromTotal,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get creditLimit => $composableBuilder(
      column: $table.creditLimit, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get statementDay => $composableBuilder(
      column: $table.statementDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get paymentDueDay => $composableBuilder(
      column: $table.paymentDueDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> debtTransactionsRefs(
      Expression<bool> Function($$DebtTransactionsTableFilterComposer f) f) {
    final $$DebtTransactionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.debtTransactions,
        getReferencedColumn: (t) => t.walletId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DebtTransactionsTableFilterComposer(
              $db: $db,
              $table: $db.debtTransactions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$WalletsTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletsTable> {
  $$WalletsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get balance => $composableBuilder(
      column: $table.balance, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isExcludedFromTotal => $composableBuilder(
      column: $table.isExcludedFromTotal,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get creditLimit => $composableBuilder(
      column: $table.creditLimit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get statementDay => $composableBuilder(
      column: $table.statementDay,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get paymentDueDay => $composableBuilder(
      column: $table.paymentDueDay,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$WalletsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletsTable> {
  $$WalletsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get balance =>
      $composableBuilder(column: $table.balance, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<bool> get isExcludedFromTotal => $composableBuilder(
      column: $table.isExcludedFromTotal, builder: (column) => column);

  GeneratedColumn<double> get creditLimit => $composableBuilder(
      column: $table.creditLimit, builder: (column) => column);

  GeneratedColumn<int> get statementDay => $composableBuilder(
      column: $table.statementDay, builder: (column) => column);

  GeneratedColumn<int> get paymentDueDay => $composableBuilder(
      column: $table.paymentDueDay, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> debtTransactionsRefs<T extends Object>(
      Expression<T> Function($$DebtTransactionsTableAnnotationComposer a) f) {
    final $$DebtTransactionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.debtTransactions,
        getReferencedColumn: (t) => t.walletId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DebtTransactionsTableAnnotationComposer(
              $db: $db,
              $table: $db.debtTransactions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$WalletsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WalletsTable,
    Wallet,
    $$WalletsTableFilterComposer,
    $$WalletsTableOrderingComposer,
    $$WalletsTableAnnotationComposer,
    $$WalletsTableCreateCompanionBuilder,
    $$WalletsTableUpdateCompanionBuilder,
    (Wallet, $$WalletsTableReferences),
    Wallet,
    PrefetchHooks Function({bool debtTransactionsRefs})> {
  $$WalletsTableTableManager(_$AppDatabase db, $WalletsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<double> balance = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String> icon = const Value.absent(),
            Value<String> color = const Value.absent(),
            Value<bool> isExcludedFromTotal = const Value.absent(),
            Value<double?> creditLimit = const Value.absent(),
            Value<int?> statementDay = const Value.absent(),
            Value<int?> paymentDueDay = const Value.absent(),
            Value<bool> isDefault = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WalletsCompanion(
            id: id,
            name: name,
            type: type,
            balance: balance,
            currency: currency,
            icon: icon,
            color: color,
            isExcludedFromTotal: isExcludedFromTotal,
            creditLimit: creditLimit,
            statementDay: statementDay,
            paymentDueDay: paymentDueDay,
            isDefault: isDefault,
            isArchived: isArchived,
            sortOrder: sortOrder,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String type,
            Value<double> balance = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String> icon = const Value.absent(),
            Value<String> color = const Value.absent(),
            Value<bool> isExcludedFromTotal = const Value.absent(),
            Value<double?> creditLimit = const Value.absent(),
            Value<int?> statementDay = const Value.absent(),
            Value<int?> paymentDueDay = const Value.absent(),
            Value<bool> isDefault = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WalletsCompanion.insert(
            id: id,
            name: name,
            type: type,
            balance: balance,
            currency: currency,
            icon: icon,
            color: color,
            isExcludedFromTotal: isExcludedFromTotal,
            creditLimit: creditLimit,
            statementDay: statementDay,
            paymentDueDay: paymentDueDay,
            isDefault: isDefault,
            isArchived: isArchived,
            sortOrder: sortOrder,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$WalletsTable, Wallet>(table),
                    $$WalletsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({debtTransactionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (debtTransactionsRefs) db.debtTransactions
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (debtTransactionsRefs)
                    await $_getPrefetchedData<Wallet, $WalletsTable,
                            DebtTransaction>(
                        currentTable: table,
                        referencedTable: $$WalletsTableReferences
                            ._debtTransactionsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$WalletsTableReferences(db, table, p0)
                                .debtTransactionsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.walletId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$WalletsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WalletsTable,
    Wallet,
    $$WalletsTableFilterComposer,
    $$WalletsTableOrderingComposer,
    $$WalletsTableAnnotationComposer,
    $$WalletsTableCreateCompanionBuilder,
    $$WalletsTableUpdateCompanionBuilder,
    (Wallet, $$WalletsTableReferences),
    Wallet,
    PrefetchHooks Function({bool debtTransactionsRefs})>;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String id,
  Value<String?> parentId,
  required String name,
  required CategoryType type,
  Value<String> icon,
  Value<String> color,
  Value<double?> budgetLimit,
  Value<int> sortOrder,
  Value<bool> isSystem,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> id,
  Value<String?> parentId,
  Value<String> name,
  Value<CategoryType> type,
  Value<String> icon,
  Value<String> color,
  Value<double?> budgetLimit,
  Value<int> sortOrder,
  Value<bool> isSystem,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _parentIdTable(_$AppDatabase db) =>
      db.categories.createAlias('categories__parent_id__categories__id');

  $$CategoriesTableProcessedTableManager? get parentId {
    final $_column = $_itemColumn<String>('parent_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager($_db, $_db.categories)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
      _transactionsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.transactions,
              aliasName: 'categories__id__transactions__category_id');

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager($_db, $_db.transactions)
        .filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$BudgetsTable, List<Budget>> _budgetsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.budgets,
          aliasName: 'categories__id__budgets__category_id');

  $$BudgetsTableProcessedTableManager get budgetsRefs {
    final manager = $$BudgetsTableTableManager($_db, $_db.budgets)
        .filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_budgetsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<CategoryType, CategoryType, int> get type =>
      $composableBuilder(
          column: $table.type,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get budgetLimit => $composableBuilder(
      column: $table.budgetLimit, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isSystem => $composableBuilder(
      column: $table.isSystem, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$CategoriesTableFilterComposer get parentId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableFilterComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> transactionsRefs(
      Expression<bool> Function($$TransactionsTableFilterComposer f) f) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.transactions,
        getReferencedColumn: (t) => t.categoryId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TransactionsTableFilterComposer(
              $db: $db,
              $table: $db.transactions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> budgetsRefs(
      Expression<bool> Function($$BudgetsTableFilterComposer f) f) {
    final $$BudgetsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.budgets,
        getReferencedColumn: (t) => t.categoryId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BudgetsTableFilterComposer(
              $db: $db,
              $table: $db.budgets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get budgetLimit => $composableBuilder(
      column: $table.budgetLimit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isSystem => $composableBuilder(
      column: $table.isSystem, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$CategoriesTableOrderingComposer get parentId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableOrderingComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CategoryType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<double> get budgetLimit => $composableBuilder(
      column: $table.budgetLimit, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isSystem =>
      $composableBuilder(column: $table.isSystem, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get parentId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableAnnotationComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> transactionsRefs<T extends Object>(
      Expression<T> Function($$TransactionsTableAnnotationComposer a) f) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.transactions,
        getReferencedColumn: (t) => t.categoryId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TransactionsTableAnnotationComposer(
              $db: $db,
              $table: $db.transactions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> budgetsRefs<T extends Object>(
      Expression<T> Function($$BudgetsTableAnnotationComposer a) f) {
    final $$BudgetsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.budgets,
        getReferencedColumn: (t) => t.categoryId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BudgetsTableAnnotationComposer(
              $db: $db,
              $table: $db.budgets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CategoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CategoriesTable,
    Category,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (Category, $$CategoriesTableReferences),
    Category,
    PrefetchHooks Function(
        {bool parentId, bool transactionsRefs, bool budgetsRefs})> {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> parentId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<CategoryType> type = const Value.absent(),
            Value<String> icon = const Value.absent(),
            Value<String> color = const Value.absent(),
            Value<double?> budgetLimit = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<bool> isSystem = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CategoriesCompanion(
            id: id,
            parentId: parentId,
            name: name,
            type: type,
            icon: icon,
            color: color,
            budgetLimit: budgetLimit,
            sortOrder: sortOrder,
            isSystem: isSystem,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> parentId = const Value.absent(),
            required String name,
            required CategoryType type,
            Value<String> icon = const Value.absent(),
            Value<String> color = const Value.absent(),
            Value<double?> budgetLimit = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<bool> isSystem = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CategoriesCompanion.insert(
            id: id,
            parentId: parentId,
            name: name,
            type: type,
            icon: icon,
            color: color,
            budgetLimit: budgetLimit,
            sortOrder: sortOrder,
            isSystem: isSystem,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CategoriesTable, Category>(table),
                    $$CategoriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {parentId = false,
              transactionsRefs = false,
              budgetsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (transactionsRefs) db.transactions,
                if (budgetsRefs) db.budgets
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (parentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.parentId,
                    referencedTable:
                        $$CategoriesTableReferences._parentIdTable(db),
                    referencedColumn:
                        $$CategoriesTableReferences._parentIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (transactionsRefs)
                    await $_getPrefetchedData<Category, $CategoriesTable,
                            Transaction>(
                        currentTable: table,
                        referencedTable: $$CategoriesTableReferences
                            ._transactionsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CategoriesTableReferences(db, table, p0)
                                .transactionsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.categoryId == item.id),
                        typedResults: items),
                  if (budgetsRefs)
                    await $_getPrefetchedData<Category, $CategoriesTable,
                            Budget>(
                        currentTable: table,
                        referencedTable:
                            $$CategoriesTableReferences._budgetsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CategoriesTableReferences(db, table, p0)
                                .budgetsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.categoryId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$CategoriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CategoriesTable,
    Category,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (Category, $$CategoriesTableReferences),
    Category,
    PrefetchHooks Function(
        {bool parentId, bool transactionsRefs, bool budgetsRefs})>;
typedef $$ProjectBudgetsTableCreateCompanionBuilder = ProjectBudgetsCompanion
    Function({
  required String id,
  required String title,
  required String tag,
  Value<String> icon,
  Value<String> colorHex,
  required double targetAmount,
  required DateTime startDate,
  required DateTime endDate,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$ProjectBudgetsTableUpdateCompanionBuilder = ProjectBudgetsCompanion
    Function({
  Value<String> id,
  Value<String> title,
  Value<String> tag,
  Value<String> icon,
  Value<String> colorHex,
  Value<double> targetAmount,
  Value<DateTime> startDate,
  Value<DateTime> endDate,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$ProjectBudgetsTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectBudgetsTable, ProjectBudget> {
  $$ProjectBudgetsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
      _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.transactions,
          aliasName: 'project_budgets__id__transactions__project_budget_id');

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager($_db, $_db.transactions)
        .filter(
            (f) => f.projectBudgetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ProjectBudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectBudgetsTable> {
  $$ProjectBudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tag => $composableBuilder(
      column: $table.tag, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get colorHex => $composableBuilder(
      column: $table.colorHex, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get targetAmount => $composableBuilder(
      column: $table.targetAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endDate => $composableBuilder(
      column: $table.endDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> transactionsRefs(
      Expression<bool> Function($$TransactionsTableFilterComposer f) f) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.transactions,
        getReferencedColumn: (t) => t.projectBudgetId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TransactionsTableFilterComposer(
              $db: $db,
              $table: $db.transactions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProjectBudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectBudgetsTable> {
  $$ProjectBudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tag => $composableBuilder(
      column: $table.tag, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get colorHex => $composableBuilder(
      column: $table.colorHex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get targetAmount => $composableBuilder(
      column: $table.targetAmount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
      column: $table.endDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ProjectBudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectBudgetsTable> {
  $$ProjectBudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<double> get targetAmount => $composableBuilder(
      column: $table.targetAmount, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> transactionsRefs<T extends Object>(
      Expression<T> Function($$TransactionsTableAnnotationComposer a) f) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.transactions,
        getReferencedColumn: (t) => t.projectBudgetId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TransactionsTableAnnotationComposer(
              $db: $db,
              $table: $db.transactions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProjectBudgetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProjectBudgetsTable,
    ProjectBudget,
    $$ProjectBudgetsTableFilterComposer,
    $$ProjectBudgetsTableOrderingComposer,
    $$ProjectBudgetsTableAnnotationComposer,
    $$ProjectBudgetsTableCreateCompanionBuilder,
    $$ProjectBudgetsTableUpdateCompanionBuilder,
    (ProjectBudget, $$ProjectBudgetsTableReferences),
    ProjectBudget,
    PrefetchHooks Function({bool transactionsRefs})> {
  $$ProjectBudgetsTableTableManager(
      _$AppDatabase db, $ProjectBudgetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectBudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectBudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectBudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> tag = const Value.absent(),
            Value<String> icon = const Value.absent(),
            Value<String> colorHex = const Value.absent(),
            Value<double> targetAmount = const Value.absent(),
            Value<DateTime> startDate = const Value.absent(),
            Value<DateTime> endDate = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectBudgetsCompanion(
            id: id,
            title: title,
            tag: tag,
            icon: icon,
            colorHex: colorHex,
            targetAmount: targetAmount,
            startDate: startDate,
            endDate: endDate,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String tag,
            Value<String> icon = const Value.absent(),
            Value<String> colorHex = const Value.absent(),
            required double targetAmount,
            required DateTime startDate,
            required DateTime endDate,
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectBudgetsCompanion.insert(
            id: id,
            title: title,
            tag: tag,
            icon: icon,
            colorHex: colorHex,
            targetAmount: targetAmount,
            startDate: startDate,
            endDate: endDate,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ProjectBudgetsTable, ProjectBudget>(table),
                    $$ProjectBudgetsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({transactionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (transactionsRefs) db.transactions],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (transactionsRefs)
                    await $_getPrefetchedData<ProjectBudget,
                            $ProjectBudgetsTable, Transaction>(
                        currentTable: table,
                        referencedTable: $$ProjectBudgetsTableReferences
                            ._transactionsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProjectBudgetsTableReferences(db, table, p0)
                                .transactionsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.projectBudgetId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ProjectBudgetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProjectBudgetsTable,
    ProjectBudget,
    $$ProjectBudgetsTableFilterComposer,
    $$ProjectBudgetsTableOrderingComposer,
    $$ProjectBudgetsTableAnnotationComposer,
    $$ProjectBudgetsTableCreateCompanionBuilder,
    $$ProjectBudgetsTableUpdateCompanionBuilder,
    (ProjectBudget, $$ProjectBudgetsTableReferences),
    ProjectBudget,
    PrefetchHooks Function({bool transactionsRefs})>;
typedef $$SavingsGoalsTableCreateCompanionBuilder = SavingsGoalsCompanion
    Function({
  required String id,
  required String title,
  Value<String> icon,
  Value<String> colorHex,
  required double targetAmount,
  Value<double> currentAmount,
  Value<DateTime?> targetDate,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$SavingsGoalsTableUpdateCompanionBuilder = SavingsGoalsCompanion
    Function({
  Value<String> id,
  Value<String> title,
  Value<String> icon,
  Value<String> colorHex,
  Value<double> targetAmount,
  Value<double> currentAmount,
  Value<DateTime?> targetDate,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$SavingsGoalsTableReferences
    extends BaseReferences<_$AppDatabase, $SavingsGoalsTable, SavingsGoal> {
  $$SavingsGoalsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
      _transactionsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.transactions,
              aliasName: 'savings_goals__id__transactions__goal_id');

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager($_db, $_db.transactions)
        .filter((f) => f.goalId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SavingsGoalsTableFilterComposer
    extends Composer<_$AppDatabase, $SavingsGoalsTable> {
  $$SavingsGoalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get colorHex => $composableBuilder(
      column: $table.colorHex, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get targetAmount => $composableBuilder(
      column: $table.targetAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get currentAmount => $composableBuilder(
      column: $table.currentAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get targetDate => $composableBuilder(
      column: $table.targetDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> transactionsRefs(
      Expression<bool> Function($$TransactionsTableFilterComposer f) f) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.transactions,
        getReferencedColumn: (t) => t.goalId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TransactionsTableFilterComposer(
              $db: $db,
              $table: $db.transactions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SavingsGoalsTableOrderingComposer
    extends Composer<_$AppDatabase, $SavingsGoalsTable> {
  $$SavingsGoalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get colorHex => $composableBuilder(
      column: $table.colorHex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get targetAmount => $composableBuilder(
      column: $table.targetAmount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get currentAmount => $composableBuilder(
      column: $table.currentAmount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get targetDate => $composableBuilder(
      column: $table.targetDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$SavingsGoalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavingsGoalsTable> {
  $$SavingsGoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<double> get targetAmount => $composableBuilder(
      column: $table.targetAmount, builder: (column) => column);

  GeneratedColumn<double> get currentAmount => $composableBuilder(
      column: $table.currentAmount, builder: (column) => column);

  GeneratedColumn<DateTime> get targetDate => $composableBuilder(
      column: $table.targetDate, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> transactionsRefs<T extends Object>(
      Expression<T> Function($$TransactionsTableAnnotationComposer a) f) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.transactions,
        getReferencedColumn: (t) => t.goalId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TransactionsTableAnnotationComposer(
              $db: $db,
              $table: $db.transactions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SavingsGoalsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SavingsGoalsTable,
    SavingsGoal,
    $$SavingsGoalsTableFilterComposer,
    $$SavingsGoalsTableOrderingComposer,
    $$SavingsGoalsTableAnnotationComposer,
    $$SavingsGoalsTableCreateCompanionBuilder,
    $$SavingsGoalsTableUpdateCompanionBuilder,
    (SavingsGoal, $$SavingsGoalsTableReferences),
    SavingsGoal,
    PrefetchHooks Function({bool transactionsRefs})> {
  $$SavingsGoalsTableTableManager(_$AppDatabase db, $SavingsGoalsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavingsGoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavingsGoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavingsGoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> icon = const Value.absent(),
            Value<String> colorHex = const Value.absent(),
            Value<double> targetAmount = const Value.absent(),
            Value<double> currentAmount = const Value.absent(),
            Value<DateTime?> targetDate = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SavingsGoalsCompanion(
            id: id,
            title: title,
            icon: icon,
            colorHex: colorHex,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            targetDate: targetDate,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            Value<String> icon = const Value.absent(),
            Value<String> colorHex = const Value.absent(),
            required double targetAmount,
            Value<double> currentAmount = const Value.absent(),
            Value<DateTime?> targetDate = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SavingsGoalsCompanion.insert(
            id: id,
            title: title,
            icon: icon,
            colorHex: colorHex,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            targetDate: targetDate,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SavingsGoalsTable, SavingsGoal>(table),
                    $$SavingsGoalsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({transactionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (transactionsRefs) db.transactions],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (transactionsRefs)
                    await $_getPrefetchedData<SavingsGoal, $SavingsGoalsTable,
                            Transaction>(
                        currentTable: table,
                        referencedTable: $$SavingsGoalsTableReferences
                            ._transactionsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SavingsGoalsTableReferences(db, table, p0)
                                .transactionsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.goalId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SavingsGoalsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SavingsGoalsTable,
    SavingsGoal,
    $$SavingsGoalsTableFilterComposer,
    $$SavingsGoalsTableOrderingComposer,
    $$SavingsGoalsTableAnnotationComposer,
    $$SavingsGoalsTableCreateCompanionBuilder,
    $$SavingsGoalsTableUpdateCompanionBuilder,
    (SavingsGoal, $$SavingsGoalsTableReferences),
    SavingsGoal,
    PrefetchHooks Function({bool transactionsRefs})>;
typedef $$TransactionsTableCreateCompanionBuilder = TransactionsCompanion
    Function({
  required String id,
  required String walletId,
  required String categoryId,
  required double amount,
  required CategoryType type,
  Value<String?> envelopeType,
  required DateTime date,
  Value<String?> note,
  Value<String?> merchant,
  Value<bool> isAiParsed,
  Value<String?> rawReceiptText,
  Value<DateTime> createdAt,
  Value<bool> isCycleStart,
  Value<String?> projectBudgetId,
  Value<String?> toWalletId,
  Value<String?> goalId,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$TransactionsTableUpdateCompanionBuilder = TransactionsCompanion
    Function({
  Value<String> id,
  Value<String> walletId,
  Value<String> categoryId,
  Value<double> amount,
  Value<CategoryType> type,
  Value<String?> envelopeType,
  Value<DateTime> date,
  Value<String?> note,
  Value<String?> merchant,
  Value<bool> isAiParsed,
  Value<String?> rawReceiptText,
  Value<DateTime> createdAt,
  Value<bool> isCycleStart,
  Value<String?> projectBudgetId,
  Value<String?> toWalletId,
  Value<String?> goalId,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$TransactionsTableReferences
    extends BaseReferences<_$AppDatabase, $TransactionsTable, Transaction> {
  $$TransactionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WalletsTable _walletIdTable(_$AppDatabase db) =>
      db.wallets.createAlias('transactions__wallet_id__wallets__id');

  $$WalletsTableProcessedTableManager get walletId {
    final $_column = $_itemColumn<String>('wallet_id')!;

    final manager = $$WalletsTableTableManager($_db, $_db.wallets)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_walletIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('transactions__category_id__categories__id');

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$CategoriesTableTableManager($_db, $_db.categories)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ProjectBudgetsTable _projectBudgetIdTable(_$AppDatabase db) =>
      db.projectBudgets
          .createAlias('transactions__project_budget_id__project_budgets__id');

  $$ProjectBudgetsTableProcessedTableManager? get projectBudgetId {
    final $_column = $_itemColumn<String>('project_budget_id');
    if ($_column == null) return null;
    final manager = $$ProjectBudgetsTableTableManager($_db, $_db.projectBudgets)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectBudgetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $WalletsTable _toWalletIdTable(_$AppDatabase db) =>
      db.wallets.createAlias('transactions__to_wallet_id__wallets__id');

  $$WalletsTableProcessedTableManager? get toWalletId {
    final $_column = $_itemColumn<String>('to_wallet_id');
    if ($_column == null) return null;
    final manager = $$WalletsTableTableManager($_db, $_db.wallets)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_toWalletIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $SavingsGoalsTable _goalIdTable(_$AppDatabase db) =>
      db.savingsGoals.createAlias('transactions__goal_id__savings_goals__id');

  $$SavingsGoalsTableProcessedTableManager? get goalId {
    final $_column = $_itemColumn<String>('goal_id');
    if ($_column == null) return null;
    final manager = $$SavingsGoalsTableTableManager($_db, $_db.savingsGoals)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_goalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<CategoryType, CategoryType, int> get type =>
      $composableBuilder(
          column: $table.type,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get envelopeType => $composableBuilder(
      column: $table.envelopeType, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get merchant => $composableBuilder(
      column: $table.merchant, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isAiParsed => $composableBuilder(
      column: $table.isAiParsed, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rawReceiptText => $composableBuilder(
      column: $table.rawReceiptText,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isCycleStart => $composableBuilder(
      column: $table.isCycleStart, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  $$WalletsTableFilterComposer get walletId {
    final $$WalletsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.walletId,
        referencedTable: $db.wallets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WalletsTableFilterComposer(
              $db: $db,
              $table: $db.wallets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableFilterComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProjectBudgetsTableFilterComposer get projectBudgetId {
    final $$ProjectBudgetsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectBudgetId,
        referencedTable: $db.projectBudgets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectBudgetsTableFilterComposer(
              $db: $db,
              $table: $db.projectBudgets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$WalletsTableFilterComposer get toWalletId {
    final $$WalletsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.toWalletId,
        referencedTable: $db.wallets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WalletsTableFilterComposer(
              $db: $db,
              $table: $db.wallets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SavingsGoalsTableFilterComposer get goalId {
    final $$SavingsGoalsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.goalId,
        referencedTable: $db.savingsGoals,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SavingsGoalsTableFilterComposer(
              $db: $db,
              $table: $db.savingsGoals,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get envelopeType => $composableBuilder(
      column: $table.envelopeType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get merchant => $composableBuilder(
      column: $table.merchant, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isAiParsed => $composableBuilder(
      column: $table.isAiParsed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rawReceiptText => $composableBuilder(
      column: $table.rawReceiptText,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isCycleStart => $composableBuilder(
      column: $table.isCycleStart,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  $$WalletsTableOrderingComposer get walletId {
    final $$WalletsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.walletId,
        referencedTable: $db.wallets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WalletsTableOrderingComposer(
              $db: $db,
              $table: $db.wallets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableOrderingComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProjectBudgetsTableOrderingComposer get projectBudgetId {
    final $$ProjectBudgetsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectBudgetId,
        referencedTable: $db.projectBudgets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectBudgetsTableOrderingComposer(
              $db: $db,
              $table: $db.projectBudgets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$WalletsTableOrderingComposer get toWalletId {
    final $$WalletsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.toWalletId,
        referencedTable: $db.wallets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WalletsTableOrderingComposer(
              $db: $db,
              $table: $db.wallets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SavingsGoalsTableOrderingComposer get goalId {
    final $$SavingsGoalsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.goalId,
        referencedTable: $db.savingsGoals,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SavingsGoalsTableOrderingComposer(
              $db: $db,
              $table: $db.savingsGoals,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CategoryType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get envelopeType => $composableBuilder(
      column: $table.envelopeType, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get merchant =>
      $composableBuilder(column: $table.merchant, builder: (column) => column);

  GeneratedColumn<bool> get isAiParsed => $composableBuilder(
      column: $table.isAiParsed, builder: (column) => column);

  GeneratedColumn<String> get rawReceiptText => $composableBuilder(
      column: $table.rawReceiptText, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isCycleStart => $composableBuilder(
      column: $table.isCycleStart, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$WalletsTableAnnotationComposer get walletId {
    final $$WalletsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.walletId,
        referencedTable: $db.wallets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WalletsTableAnnotationComposer(
              $db: $db,
              $table: $db.wallets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableAnnotationComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProjectBudgetsTableAnnotationComposer get projectBudgetId {
    final $$ProjectBudgetsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectBudgetId,
        referencedTable: $db.projectBudgets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectBudgetsTableAnnotationComposer(
              $db: $db,
              $table: $db.projectBudgets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$WalletsTableAnnotationComposer get toWalletId {
    final $$WalletsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.toWalletId,
        referencedTable: $db.wallets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WalletsTableAnnotationComposer(
              $db: $db,
              $table: $db.wallets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SavingsGoalsTableAnnotationComposer get goalId {
    final $$SavingsGoalsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.goalId,
        referencedTable: $db.savingsGoals,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SavingsGoalsTableAnnotationComposer(
              $db: $db,
              $table: $db.savingsGoals,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TransactionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TransactionsTable,
    Transaction,
    $$TransactionsTableFilterComposer,
    $$TransactionsTableOrderingComposer,
    $$TransactionsTableAnnotationComposer,
    $$TransactionsTableCreateCompanionBuilder,
    $$TransactionsTableUpdateCompanionBuilder,
    (Transaction, $$TransactionsTableReferences),
    Transaction,
    PrefetchHooks Function(
        {bool walletId,
        bool categoryId,
        bool projectBudgetId,
        bool toWalletId,
        bool goalId})> {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> walletId = const Value.absent(),
            Value<String> categoryId = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<CategoryType> type = const Value.absent(),
            Value<String?> envelopeType = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> merchant = const Value.absent(),
            Value<bool> isAiParsed = const Value.absent(),
            Value<String?> rawReceiptText = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isCycleStart = const Value.absent(),
            Value<String?> projectBudgetId = const Value.absent(),
            Value<String?> toWalletId = const Value.absent(),
            Value<String?> goalId = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TransactionsCompanion(
            id: id,
            walletId: walletId,
            categoryId: categoryId,
            amount: amount,
            type: type,
            envelopeType: envelopeType,
            date: date,
            note: note,
            merchant: merchant,
            isAiParsed: isAiParsed,
            rawReceiptText: rawReceiptText,
            createdAt: createdAt,
            isCycleStart: isCycleStart,
            projectBudgetId: projectBudgetId,
            toWalletId: toWalletId,
            goalId: goalId,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String walletId,
            required String categoryId,
            required double amount,
            required CategoryType type,
            Value<String?> envelopeType = const Value.absent(),
            required DateTime date,
            Value<String?> note = const Value.absent(),
            Value<String?> merchant = const Value.absent(),
            Value<bool> isAiParsed = const Value.absent(),
            Value<String?> rawReceiptText = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isCycleStart = const Value.absent(),
            Value<String?> projectBudgetId = const Value.absent(),
            Value<String?> toWalletId = const Value.absent(),
            Value<String?> goalId = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TransactionsCompanion.insert(
            id: id,
            walletId: walletId,
            categoryId: categoryId,
            amount: amount,
            type: type,
            envelopeType: envelopeType,
            date: date,
            note: note,
            merchant: merchant,
            isAiParsed: isAiParsed,
            rawReceiptText: rawReceiptText,
            createdAt: createdAt,
            isCycleStart: isCycleStart,
            projectBudgetId: projectBudgetId,
            toWalletId: toWalletId,
            goalId: goalId,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$TransactionsTable, Transaction>(table),
                    $$TransactionsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {walletId = false,
              categoryId = false,
              projectBudgetId = false,
              toWalletId = false,
              goalId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (walletId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.walletId,
                    referencedTable:
                        $$TransactionsTableReferences._walletIdTable(db),
                    referencedColumn:
                        $$TransactionsTableReferences._walletIdTable(db).id,
                  ) as T;
                }
                if (categoryId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.categoryId,
                    referencedTable:
                        $$TransactionsTableReferences._categoryIdTable(db),
                    referencedColumn:
                        $$TransactionsTableReferences._categoryIdTable(db).id,
                  ) as T;
                }
                if (projectBudgetId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.projectBudgetId,
                    referencedTable:
                        $$TransactionsTableReferences._projectBudgetIdTable(db),
                    referencedColumn: $$TransactionsTableReferences
                        ._projectBudgetIdTable(db)
                        .id,
                  ) as T;
                }
                if (toWalletId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.toWalletId,
                    referencedTable:
                        $$TransactionsTableReferences._toWalletIdTable(db),
                    referencedColumn:
                        $$TransactionsTableReferences._toWalletIdTable(db).id,
                  ) as T;
                }
                if (goalId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.goalId,
                    referencedTable:
                        $$TransactionsTableReferences._goalIdTable(db),
                    referencedColumn:
                        $$TransactionsTableReferences._goalIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$TransactionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TransactionsTable,
    Transaction,
    $$TransactionsTableFilterComposer,
    $$TransactionsTableOrderingComposer,
    $$TransactionsTableAnnotationComposer,
    $$TransactionsTableCreateCompanionBuilder,
    $$TransactionsTableUpdateCompanionBuilder,
    (Transaction, $$TransactionsTableReferences),
    Transaction,
    PrefetchHooks Function(
        {bool walletId,
        bool categoryId,
        bool projectBudgetId,
        bool toWalletId,
        bool goalId})>;
typedef $$BudgetsTableCreateCompanionBuilder = BudgetsCompanion Function({
  required String id,
  required String categoryId,
  required double amount,
  Value<int> cycleStartDay,
  required DateTime periodMonth,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$BudgetsTableUpdateCompanionBuilder = BudgetsCompanion Function({
  Value<String> id,
  Value<String> categoryId,
  Value<double> amount,
  Value<int> cycleStartDay,
  Value<DateTime> periodMonth,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$BudgetsTableReferences
    extends BaseReferences<_$AppDatabase, $BudgetsTable, Budget> {
  $$BudgetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('budgets__category_id__categories__id');

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$CategoriesTableTableManager($_db, $_db.categories)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$BudgetRhythmsTable, List<BudgetRhythm>>
      _budgetRhythmsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.budgetRhythms,
              aliasName: 'budgets__id__budget_rhythms__budget_id');

  $$BudgetRhythmsTableProcessedTableManager get budgetRhythmsRefs {
    final manager = $$BudgetRhythmsTableTableManager($_db, $_db.budgetRhythms)
        .filter((f) => f.budgetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_budgetRhythmsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$BudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cycleStartDay => $composableBuilder(
      column: $table.cycleStartDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get periodMonth => $composableBuilder(
      column: $table.periodMonth, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableFilterComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> budgetRhythmsRefs(
      Expression<bool> Function($$BudgetRhythmsTableFilterComposer f) f) {
    final $$BudgetRhythmsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.budgetRhythms,
        getReferencedColumn: (t) => t.budgetId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BudgetRhythmsTableFilterComposer(
              $db: $db,
              $table: $db.budgetRhythms,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cycleStartDay => $composableBuilder(
      column: $table.cycleStartDay,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get periodMonth => $composableBuilder(
      column: $table.periodMonth, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableOrderingComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<int> get cycleStartDay => $composableBuilder(
      column: $table.cycleStartDay, builder: (column) => column);

  GeneratedColumn<DateTime> get periodMonth => $composableBuilder(
      column: $table.periodMonth, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableAnnotationComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> budgetRhythmsRefs<T extends Object>(
      Expression<T> Function($$BudgetRhythmsTableAnnotationComposer a) f) {
    final $$BudgetRhythmsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.budgetRhythms,
        getReferencedColumn: (t) => t.budgetId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BudgetRhythmsTableAnnotationComposer(
              $db: $db,
              $table: $db.budgetRhythms,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BudgetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BudgetsTable,
    Budget,
    $$BudgetsTableFilterComposer,
    $$BudgetsTableOrderingComposer,
    $$BudgetsTableAnnotationComposer,
    $$BudgetsTableCreateCompanionBuilder,
    $$BudgetsTableUpdateCompanionBuilder,
    (Budget, $$BudgetsTableReferences),
    Budget,
    PrefetchHooks Function({bool categoryId, bool budgetRhythmsRefs})> {
  $$BudgetsTableTableManager(_$AppDatabase db, $BudgetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> categoryId = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<int> cycleStartDay = const Value.absent(),
            Value<DateTime> periodMonth = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BudgetsCompanion(
            id: id,
            categoryId: categoryId,
            amount: amount,
            cycleStartDay: cycleStartDay,
            periodMonth: periodMonth,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String categoryId,
            required double amount,
            Value<int> cycleStartDay = const Value.absent(),
            required DateTime periodMonth,
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BudgetsCompanion.insert(
            id: id,
            categoryId: categoryId,
            amount: amount,
            cycleStartDay: cycleStartDay,
            periodMonth: periodMonth,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$BudgetsTable, Budget>(table),
                    $$BudgetsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {categoryId = false, budgetRhythmsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (budgetRhythmsRefs) db.budgetRhythms
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (categoryId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.categoryId,
                    referencedTable:
                        $$BudgetsTableReferences._categoryIdTable(db),
                    referencedColumn:
                        $$BudgetsTableReferences._categoryIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (budgetRhythmsRefs)
                    await $_getPrefetchedData<Budget, $BudgetsTable,
                            BudgetRhythm>(
                        currentTable: table,
                        referencedTable: $$BudgetsTableReferences
                            ._budgetRhythmsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BudgetsTableReferences(db, table, p0)
                                .budgetRhythmsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.budgetId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$BudgetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BudgetsTable,
    Budget,
    $$BudgetsTableFilterComposer,
    $$BudgetsTableOrderingComposer,
    $$BudgetsTableAnnotationComposer,
    $$BudgetsTableCreateCompanionBuilder,
    $$BudgetsTableUpdateCompanionBuilder,
    (Budget, $$BudgetsTableReferences),
    Budget,
    PrefetchHooks Function({bool categoryId, bool budgetRhythmsRefs})>;
typedef $$BudgetRhythmsTableCreateCompanionBuilder = BudgetRhythmsCompanion
    Function({
  required String budgetId,
  required String rhythm,
  Value<int> weekStart,
  Value<String> carryRule,
  Value<int?> remainingUses,
  Value<bool> pinned,
  Value<int> rowid,
});
typedef $$BudgetRhythmsTableUpdateCompanionBuilder = BudgetRhythmsCompanion
    Function({
  Value<String> budgetId,
  Value<String> rhythm,
  Value<int> weekStart,
  Value<String> carryRule,
  Value<int?> remainingUses,
  Value<bool> pinned,
  Value<int> rowid,
});

final class $$BudgetRhythmsTableReferences
    extends BaseReferences<_$AppDatabase, $BudgetRhythmsTable, BudgetRhythm> {
  $$BudgetRhythmsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $BudgetsTable _budgetIdTable(_$AppDatabase db) =>
      db.budgets.createAlias('budget_rhythms__budget_id__budgets__id');

  $$BudgetsTableProcessedTableManager get budgetId {
    final $_column = $_itemColumn<String>('budget_id')!;

    final manager = $$BudgetsTableTableManager($_db, $_db.budgets)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_budgetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$BudgetRhythmsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetRhythmsTable> {
  $$BudgetRhythmsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get rhythm => $composableBuilder(
      column: $table.rhythm, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get weekStart => $composableBuilder(
      column: $table.weekStart, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get carryRule => $composableBuilder(
      column: $table.carryRule, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get remainingUses => $composableBuilder(
      column: $table.remainingUses, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get pinned => $composableBuilder(
      column: $table.pinned, builder: (column) => ColumnFilters(column));

  $$BudgetsTableFilterComposer get budgetId {
    final $$BudgetsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.budgetId,
        referencedTable: $db.budgets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BudgetsTableFilterComposer(
              $db: $db,
              $table: $db.budgets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BudgetRhythmsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetRhythmsTable> {
  $$BudgetRhythmsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get rhythm => $composableBuilder(
      column: $table.rhythm, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get weekStart => $composableBuilder(
      column: $table.weekStart, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get carryRule => $composableBuilder(
      column: $table.carryRule, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get remainingUses => $composableBuilder(
      column: $table.remainingUses,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get pinned => $composableBuilder(
      column: $table.pinned, builder: (column) => ColumnOrderings(column));

  $$BudgetsTableOrderingComposer get budgetId {
    final $$BudgetsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.budgetId,
        referencedTable: $db.budgets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BudgetsTableOrderingComposer(
              $db: $db,
              $table: $db.budgets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BudgetRhythmsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetRhythmsTable> {
  $$BudgetRhythmsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get rhythm =>
      $composableBuilder(column: $table.rhythm, builder: (column) => column);

  GeneratedColumn<int> get weekStart =>
      $composableBuilder(column: $table.weekStart, builder: (column) => column);

  GeneratedColumn<String> get carryRule =>
      $composableBuilder(column: $table.carryRule, builder: (column) => column);

  GeneratedColumn<int> get remainingUses => $composableBuilder(
      column: $table.remainingUses, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  $$BudgetsTableAnnotationComposer get budgetId {
    final $$BudgetsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.budgetId,
        referencedTable: $db.budgets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BudgetsTableAnnotationComposer(
              $db: $db,
              $table: $db.budgets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BudgetRhythmsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BudgetRhythmsTable,
    BudgetRhythm,
    $$BudgetRhythmsTableFilterComposer,
    $$BudgetRhythmsTableOrderingComposer,
    $$BudgetRhythmsTableAnnotationComposer,
    $$BudgetRhythmsTableCreateCompanionBuilder,
    $$BudgetRhythmsTableUpdateCompanionBuilder,
    (BudgetRhythm, $$BudgetRhythmsTableReferences),
    BudgetRhythm,
    PrefetchHooks Function({bool budgetId})> {
  $$BudgetRhythmsTableTableManager(_$AppDatabase db, $BudgetRhythmsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetRhythmsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetRhythmsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetRhythmsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> budgetId = const Value.absent(),
            Value<String> rhythm = const Value.absent(),
            Value<int> weekStart = const Value.absent(),
            Value<String> carryRule = const Value.absent(),
            Value<int?> remainingUses = const Value.absent(),
            Value<bool> pinned = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BudgetRhythmsCompanion(
            budgetId: budgetId,
            rhythm: rhythm,
            weekStart: weekStart,
            carryRule: carryRule,
            remainingUses: remainingUses,
            pinned: pinned,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String budgetId,
            required String rhythm,
            Value<int> weekStart = const Value.absent(),
            Value<String> carryRule = const Value.absent(),
            Value<int?> remainingUses = const Value.absent(),
            Value<bool> pinned = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BudgetRhythmsCompanion.insert(
            budgetId: budgetId,
            rhythm: rhythm,
            weekStart: weekStart,
            carryRule: carryRule,
            remainingUses: remainingUses,
            pinned: pinned,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$BudgetRhythmsTable, BudgetRhythm>(table),
                    $$BudgetRhythmsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({budgetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (budgetId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.budgetId,
                    referencedTable:
                        $$BudgetRhythmsTableReferences._budgetIdTable(db),
                    referencedColumn:
                        $$BudgetRhythmsTableReferences._budgetIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$BudgetRhythmsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BudgetRhythmsTable,
    BudgetRhythm,
    $$BudgetRhythmsTableFilterComposer,
    $$BudgetRhythmsTableOrderingComposer,
    $$BudgetRhythmsTableAnnotationComposer,
    $$BudgetRhythmsTableCreateCompanionBuilder,
    $$BudgetRhythmsTableUpdateCompanionBuilder,
    (BudgetRhythm, $$BudgetRhythmsTableReferences),
    BudgetRhythm,
    PrefetchHooks Function({bool budgetId})>;
typedef $$DebtContactsTableCreateCompanionBuilder = DebtContactsCompanion
    Function({
  required String id,
  required String name,
  Value<String?> phone,
  Value<String?> avatarUrl,
  Value<double> netBalance,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$DebtContactsTableUpdateCompanionBuilder = DebtContactsCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String?> phone,
  Value<String?> avatarUrl,
  Value<double> netBalance,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$DebtContactsTableReferences
    extends BaseReferences<_$AppDatabase, $DebtContactsTable, DebtContact> {
  $$DebtContactsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DebtTransactionsTable, List<DebtTransaction>>
      _debtTransactionsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.debtTransactions,
              aliasName: 'debt_contacts__id__debt_transactions__contact_id');

  $$DebtTransactionsTableProcessedTableManager get debtTransactionsRefs {
    final manager = $$DebtTransactionsTableTableManager(
            $_db, $_db.debtTransactions)
        .filter((f) => f.contactId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_debtTransactionsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$DebtContactsTableFilterComposer
    extends Composer<_$AppDatabase, $DebtContactsTable> {
  $$DebtContactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get netBalance => $composableBuilder(
      column: $table.netBalance, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> debtTransactionsRefs(
      Expression<bool> Function($$DebtTransactionsTableFilterComposer f) f) {
    final $$DebtTransactionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.debtTransactions,
        getReferencedColumn: (t) => t.contactId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DebtTransactionsTableFilterComposer(
              $db: $db,
              $table: $db.debtTransactions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$DebtContactsTableOrderingComposer
    extends Composer<_$AppDatabase, $DebtContactsTable> {
  $$DebtContactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get netBalance => $composableBuilder(
      column: $table.netBalance, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$DebtContactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DebtContactsTable> {
  $$DebtContactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<double> get netBalance => $composableBuilder(
      column: $table.netBalance, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> debtTransactionsRefs<T extends Object>(
      Expression<T> Function($$DebtTransactionsTableAnnotationComposer a) f) {
    final $$DebtTransactionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.debtTransactions,
        getReferencedColumn: (t) => t.contactId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DebtTransactionsTableAnnotationComposer(
              $db: $db,
              $table: $db.debtTransactions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$DebtContactsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DebtContactsTable,
    DebtContact,
    $$DebtContactsTableFilterComposer,
    $$DebtContactsTableOrderingComposer,
    $$DebtContactsTableAnnotationComposer,
    $$DebtContactsTableCreateCompanionBuilder,
    $$DebtContactsTableUpdateCompanionBuilder,
    (DebtContact, $$DebtContactsTableReferences),
    DebtContact,
    PrefetchHooks Function({bool debtTransactionsRefs})> {
  $$DebtContactsTableTableManager(_$AppDatabase db, $DebtContactsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DebtContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DebtContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DebtContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String?> avatarUrl = const Value.absent(),
            Value<double> netBalance = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DebtContactsCompanion(
            id: id,
            name: name,
            phone: phone,
            avatarUrl: avatarUrl,
            netBalance: netBalance,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> phone = const Value.absent(),
            Value<String?> avatarUrl = const Value.absent(),
            Value<double> netBalance = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DebtContactsCompanion.insert(
            id: id,
            name: name,
            phone: phone,
            avatarUrl: avatarUrl,
            netBalance: netBalance,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$DebtContactsTable, DebtContact>(table),
                    $$DebtContactsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({debtTransactionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (debtTransactionsRefs) db.debtTransactions
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (debtTransactionsRefs)
                    await $_getPrefetchedData<DebtContact, $DebtContactsTable,
                            DebtTransaction>(
                        currentTable: table,
                        referencedTable: $$DebtContactsTableReferences
                            ._debtTransactionsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$DebtContactsTableReferences(db, table, p0)
                                .debtTransactionsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.contactId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$DebtContactsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DebtContactsTable,
    DebtContact,
    $$DebtContactsTableFilterComposer,
    $$DebtContactsTableOrderingComposer,
    $$DebtContactsTableAnnotationComposer,
    $$DebtContactsTableCreateCompanionBuilder,
    $$DebtContactsTableUpdateCompanionBuilder,
    (DebtContact, $$DebtContactsTableReferences),
    DebtContact,
    PrefetchHooks Function({bool debtTransactionsRefs})>;
typedef $$DebtTransactionsTableCreateCompanionBuilder
    = DebtTransactionsCompanion Function({
  required String id,
  required String contactId,
  required String walletId,
  required String type,
  required double amount,
  required DateTime date,
  Value<DateTime?> dueDate,
  Value<String?> note,
  Value<bool> isSettled,
  Value<DateTime> createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$DebtTransactionsTableUpdateCompanionBuilder
    = DebtTransactionsCompanion Function({
  Value<String> id,
  Value<String> contactId,
  Value<String> walletId,
  Value<String> type,
  Value<double> amount,
  Value<DateTime> date,
  Value<DateTime?> dueDate,
  Value<String?> note,
  Value<bool> isSettled,
  Value<DateTime> createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$DebtTransactionsTableReferences extends BaseReferences<
    _$AppDatabase, $DebtTransactionsTable, DebtTransaction> {
  $$DebtTransactionsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $DebtContactsTable _contactIdTable(_$AppDatabase db) => db.debtContacts
      .createAlias('debt_transactions__contact_id__debt_contacts__id');

  $$DebtContactsTableProcessedTableManager get contactId {
    final $_column = $_itemColumn<String>('contact_id')!;

    final manager = $$DebtContactsTableTableManager($_db, $_db.debtContacts)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_contactIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $WalletsTable _walletIdTable(_$AppDatabase db) =>
      db.wallets.createAlias('debt_transactions__wallet_id__wallets__id');

  $$WalletsTableProcessedTableManager get walletId {
    final $_column = $_itemColumn<String>('wallet_id')!;

    final manager = $$WalletsTableTableManager($_db, $_db.wallets)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_walletIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$DebtTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $DebtTransactionsTable> {
  $$DebtTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
      column: $table.dueDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isSettled => $composableBuilder(
      column: $table.isSettled, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  $$DebtContactsTableFilterComposer get contactId {
    final $$DebtContactsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.contactId,
        referencedTable: $db.debtContacts,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DebtContactsTableFilterComposer(
              $db: $db,
              $table: $db.debtContacts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$WalletsTableFilterComposer get walletId {
    final $$WalletsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.walletId,
        referencedTable: $db.wallets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WalletsTableFilterComposer(
              $db: $db,
              $table: $db.wallets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DebtTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $DebtTransactionsTable> {
  $$DebtTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
      column: $table.dueDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isSettled => $composableBuilder(
      column: $table.isSettled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  $$DebtContactsTableOrderingComposer get contactId {
    final $$DebtContactsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.contactId,
        referencedTable: $db.debtContacts,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DebtContactsTableOrderingComposer(
              $db: $db,
              $table: $db.debtContacts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$WalletsTableOrderingComposer get walletId {
    final $$WalletsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.walletId,
        referencedTable: $db.wallets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WalletsTableOrderingComposer(
              $db: $db,
              $table: $db.wallets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DebtTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DebtTransactionsTable> {
  $$DebtTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get isSettled =>
      $composableBuilder(column: $table.isSettled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$DebtContactsTableAnnotationComposer get contactId {
    final $$DebtContactsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.contactId,
        referencedTable: $db.debtContacts,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DebtContactsTableAnnotationComposer(
              $db: $db,
              $table: $db.debtContacts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$WalletsTableAnnotationComposer get walletId {
    final $$WalletsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.walletId,
        referencedTable: $db.wallets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WalletsTableAnnotationComposer(
              $db: $db,
              $table: $db.wallets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DebtTransactionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DebtTransactionsTable,
    DebtTransaction,
    $$DebtTransactionsTableFilterComposer,
    $$DebtTransactionsTableOrderingComposer,
    $$DebtTransactionsTableAnnotationComposer,
    $$DebtTransactionsTableCreateCompanionBuilder,
    $$DebtTransactionsTableUpdateCompanionBuilder,
    (DebtTransaction, $$DebtTransactionsTableReferences),
    DebtTransaction,
    PrefetchHooks Function({bool contactId, bool walletId})> {
  $$DebtTransactionsTableTableManager(
      _$AppDatabase db, $DebtTransactionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DebtTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DebtTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DebtTransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> contactId = const Value.absent(),
            Value<String> walletId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<DateTime?> dueDate = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<bool> isSettled = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DebtTransactionsCompanion(
            id: id,
            contactId: contactId,
            walletId: walletId,
            type: type,
            amount: amount,
            date: date,
            dueDate: dueDate,
            note: note,
            isSettled: isSettled,
            createdAt: createdAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String contactId,
            required String walletId,
            required String type,
            required double amount,
            required DateTime date,
            Value<DateTime?> dueDate = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<bool> isSettled = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DebtTransactionsCompanion.insert(
            id: id,
            contactId: contactId,
            walletId: walletId,
            type: type,
            amount: amount,
            date: date,
            dueDate: dueDate,
            note: note,
            isSettled: isSettled,
            createdAt: createdAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$DebtTransactionsTable, DebtTransaction>(table),
                    $$DebtTransactionsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({contactId = false, walletId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (contactId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.contactId,
                    referencedTable:
                        $$DebtTransactionsTableReferences._contactIdTable(db),
                    referencedColumn: $$DebtTransactionsTableReferences
                        ._contactIdTable(db)
                        .id,
                  ) as T;
                }
                if (walletId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.walletId,
                    referencedTable:
                        $$DebtTransactionsTableReferences._walletIdTable(db),
                    referencedColumn:
                        $$DebtTransactionsTableReferences._walletIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$DebtTransactionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DebtTransactionsTable,
    DebtTransaction,
    $$DebtTransactionsTableFilterComposer,
    $$DebtTransactionsTableOrderingComposer,
    $$DebtTransactionsTableAnnotationComposer,
    $$DebtTransactionsTableCreateCompanionBuilder,
    $$DebtTransactionsTableUpdateCompanionBuilder,
    (DebtTransaction, $$DebtTransactionsTableReferences),
    DebtTransaction,
    PrefetchHooks Function({bool contactId, bool walletId})>;
typedef $$AppNotificationsTableCreateCompanionBuilder
    = AppNotificationsCompanion Function({
  required String id,
  Value<String?> dedupKey,
  required String title,
  required String body,
  required String type,
  Value<String?> payload,
  Value<String?> relatedEntityId,
  Value<bool> isRead,
  Value<bool> isDismissed,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$AppNotificationsTableUpdateCompanionBuilder
    = AppNotificationsCompanion Function({
  Value<String> id,
  Value<String?> dedupKey,
  Value<String> title,
  Value<String> body,
  Value<String> type,
  Value<String?> payload,
  Value<String?> relatedEntityId,
  Value<bool> isRead,
  Value<bool> isDismissed,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$AppNotificationsTableFilterComposer
    extends Composer<_$AppDatabase, $AppNotificationsTable> {
  $$AppNotificationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dedupKey => $composableBuilder(
      column: $table.dedupKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get relatedEntityId => $composableBuilder(
      column: $table.relatedEntityId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isRead => $composableBuilder(
      column: $table.isRead, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDismissed => $composableBuilder(
      column: $table.isDismissed, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AppNotificationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppNotificationsTable> {
  $$AppNotificationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dedupKey => $composableBuilder(
      column: $table.dedupKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get relatedEntityId => $composableBuilder(
      column: $table.relatedEntityId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isRead => $composableBuilder(
      column: $table.isRead, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDismissed => $composableBuilder(
      column: $table.isDismissed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AppNotificationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppNotificationsTable> {
  $$AppNotificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dedupKey =>
      $composableBuilder(column: $table.dedupKey, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get relatedEntityId => $composableBuilder(
      column: $table.relatedEntityId, builder: (column) => column);

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);

  GeneratedColumn<bool> get isDismissed => $composableBuilder(
      column: $table.isDismissed, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AppNotificationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppNotificationsTable,
    AppNotification,
    $$AppNotificationsTableFilterComposer,
    $$AppNotificationsTableOrderingComposer,
    $$AppNotificationsTableAnnotationComposer,
    $$AppNotificationsTableCreateCompanionBuilder,
    $$AppNotificationsTableUpdateCompanionBuilder,
    (
      AppNotification,
      BaseReferences<_$AppDatabase, $AppNotificationsTable, AppNotification>
    ),
    AppNotification,
    PrefetchHooks Function()> {
  $$AppNotificationsTableTableManager(
      _$AppDatabase db, $AppNotificationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppNotificationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppNotificationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppNotificationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> dedupKey = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String?> payload = const Value.absent(),
            Value<String?> relatedEntityId = const Value.absent(),
            Value<bool> isRead = const Value.absent(),
            Value<bool> isDismissed = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppNotificationsCompanion(
            id: id,
            dedupKey: dedupKey,
            title: title,
            body: body,
            type: type,
            payload: payload,
            relatedEntityId: relatedEntityId,
            isRead: isRead,
            isDismissed: isDismissed,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> dedupKey = const Value.absent(),
            required String title,
            required String body,
            required String type,
            Value<String?> payload = const Value.absent(),
            Value<String?> relatedEntityId = const Value.absent(),
            Value<bool> isRead = const Value.absent(),
            Value<bool> isDismissed = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppNotificationsCompanion.insert(
            id: id,
            dedupKey: dedupKey,
            title: title,
            body: body,
            type: type,
            payload: payload,
            relatedEntityId: relatedEntityId,
            isRead: isRead,
            isDismissed: isDismissed,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$AppNotificationsTable, AppNotification>(table),
                    BaseReferences<_$AppDatabase, $AppNotificationsTable,
                        AppNotification>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppNotificationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppNotificationsTable,
    AppNotification,
    $$AppNotificationsTableFilterComposer,
    $$AppNotificationsTableOrderingComposer,
    $$AppNotificationsTableAnnotationComposer,
    $$AppNotificationsTableCreateCompanionBuilder,
    $$AppNotificationsTableUpdateCompanionBuilder,
    (
      AppNotification,
      BaseReferences<_$AppDatabase, $AppNotificationsTable, AppNotification>
    ),
    AppNotification,
    PrefetchHooks Function()>;
typedef $$NotificationReceiptsTableCreateCompanionBuilder
    = NotificationReceiptsCompanion Function({
  required String dedupKey,
  Value<int> rowid,
});
typedef $$NotificationReceiptsTableUpdateCompanionBuilder
    = NotificationReceiptsCompanion Function({
  Value<String> dedupKey,
  Value<int> rowid,
});

class $$NotificationReceiptsTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationReceiptsTable> {
  $$NotificationReceiptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dedupKey => $composableBuilder(
      column: $table.dedupKey, builder: (column) => ColumnFilters(column));
}

class $$NotificationReceiptsTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationReceiptsTable> {
  $$NotificationReceiptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dedupKey => $composableBuilder(
      column: $table.dedupKey, builder: (column) => ColumnOrderings(column));
}

class $$NotificationReceiptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationReceiptsTable> {
  $$NotificationReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dedupKey =>
      $composableBuilder(column: $table.dedupKey, builder: (column) => column);
}

class $$NotificationReceiptsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NotificationReceiptsTable,
    NotificationReceipt,
    $$NotificationReceiptsTableFilterComposer,
    $$NotificationReceiptsTableOrderingComposer,
    $$NotificationReceiptsTableAnnotationComposer,
    $$NotificationReceiptsTableCreateCompanionBuilder,
    $$NotificationReceiptsTableUpdateCompanionBuilder,
    (
      NotificationReceipt,
      BaseReferences<_$AppDatabase, $NotificationReceiptsTable,
          NotificationReceipt>
    ),
    NotificationReceipt,
    PrefetchHooks Function()> {
  $$NotificationReceiptsTableTableManager(
      _$AppDatabase db, $NotificationReceiptsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationReceiptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotificationReceiptsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotificationReceiptsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> dedupKey = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NotificationReceiptsCompanion(
            dedupKey: dedupKey,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String dedupKey,
            Value<int> rowid = const Value.absent(),
          }) =>
              NotificationReceiptsCompanion.insert(
            dedupKey: dedupKey,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$NotificationReceiptsTable,
                        NotificationReceipt>(table),
                    BaseReferences<_$AppDatabase, $NotificationReceiptsTable,
                        NotificationReceipt>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NotificationReceiptsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $NotificationReceiptsTable,
        NotificationReceipt,
        $$NotificationReceiptsTableFilterComposer,
        $$NotificationReceiptsTableOrderingComposer,
        $$NotificationReceiptsTableAnnotationComposer,
        $$NotificationReceiptsTableCreateCompanionBuilder,
        $$NotificationReceiptsTableUpdateCompanionBuilder,
        (
          NotificationReceipt,
          BaseReferences<_$AppDatabase, $NotificationReceiptsTable,
              NotificationReceipt>
        ),
        NotificationReceipt,
        PrefetchHooks Function()>;
typedef $$EntityArchivesTableCreateCompanionBuilder = EntityArchivesCompanion
    Function({
  required String entityId,
  required String entityType,
  Value<DateTime> archivedAt,
  Value<int> rowid,
});
typedef $$EntityArchivesTableUpdateCompanionBuilder = EntityArchivesCompanion
    Function({
  Value<String> entityId,
  Value<String> entityType,
  Value<DateTime> archivedAt,
  Value<int> rowid,
});

class $$EntityArchivesTableFilterComposer
    extends Composer<_$AppDatabase, $EntityArchivesTable> {
  $$EntityArchivesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
      column: $table.archivedAt, builder: (column) => ColumnFilters(column));
}

class $$EntityArchivesTableOrderingComposer
    extends Composer<_$AppDatabase, $EntityArchivesTable> {
  $$EntityArchivesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
      column: $table.archivedAt, builder: (column) => ColumnOrderings(column));
}

class $$EntityArchivesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntityArchivesTable> {
  $$EntityArchivesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
      column: $table.archivedAt, builder: (column) => column);
}

class $$EntityArchivesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $EntityArchivesTable,
    EntityArchive,
    $$EntityArchivesTableFilterComposer,
    $$EntityArchivesTableOrderingComposer,
    $$EntityArchivesTableAnnotationComposer,
    $$EntityArchivesTableCreateCompanionBuilder,
    $$EntityArchivesTableUpdateCompanionBuilder,
    (
      EntityArchive,
      BaseReferences<_$AppDatabase, $EntityArchivesTable, EntityArchive>
    ),
    EntityArchive,
    PrefetchHooks Function()> {
  $$EntityArchivesTableTableManager(
      _$AppDatabase db, $EntityArchivesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntityArchivesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntityArchivesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntityArchivesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> entityId = const Value.absent(),
            Value<String> entityType = const Value.absent(),
            Value<DateTime> archivedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EntityArchivesCompanion(
            entityId: entityId,
            entityType: entityType,
            archivedAt: archivedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String entityId,
            required String entityType,
            Value<DateTime> archivedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EntityArchivesCompanion.insert(
            entityId: entityId,
            entityType: entityType,
            archivedAt: archivedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$EntityArchivesTable, EntityArchive>(table),
                    BaseReferences<_$AppDatabase, $EntityArchivesTable,
                        EntityArchive>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$EntityArchivesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $EntityArchivesTable,
    EntityArchive,
    $$EntityArchivesTableFilterComposer,
    $$EntityArchivesTableOrderingComposer,
    $$EntityArchivesTableAnnotationComposer,
    $$EntityArchivesTableCreateCompanionBuilder,
    $$EntityArchivesTableUpdateCompanionBuilder,
    (
      EntityArchive,
      BaseReferences<_$AppDatabase, $EntityArchivesTable, EntityArchive>
    ),
    EntityArchive,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WalletsTableTableManager get wallets =>
      $$WalletsTableTableManager(_db, _db.wallets);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$ProjectBudgetsTableTableManager get projectBudgets =>
      $$ProjectBudgetsTableTableManager(_db, _db.projectBudgets);
  $$SavingsGoalsTableTableManager get savingsGoals =>
      $$SavingsGoalsTableTableManager(_db, _db.savingsGoals);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db, _db.budgets);
  $$BudgetRhythmsTableTableManager get budgetRhythms =>
      $$BudgetRhythmsTableTableManager(_db, _db.budgetRhythms);
  $$DebtContactsTableTableManager get debtContacts =>
      $$DebtContactsTableTableManager(_db, _db.debtContacts);
  $$DebtTransactionsTableTableManager get debtTransactions =>
      $$DebtTransactionsTableTableManager(_db, _db.debtTransactions);
  $$AppNotificationsTableTableManager get appNotifications =>
      $$AppNotificationsTableTableManager(_db, _db.appNotifications);
  $$NotificationReceiptsTableTableManager get notificationReceipts =>
      $$NotificationReceiptsTableTableManager(_db, _db.notificationReceipts);
  $$EntityArchivesTableTableManager get entityArchives =>
      $$EntityArchivesTableTableManager(_db, _db.entityArchives);
}

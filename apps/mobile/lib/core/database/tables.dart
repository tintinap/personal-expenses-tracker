import 'package:drift/drift.dart';

/// PRD §20 — Transactions table (unified: expense, income, exchange)
@DataClassName('TransactionData')
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get transactionType => text().named('transaction_type')();
  RealColumn get amountBase => real().named('amount_base')();
  RealColumn get originalAmount => real().named('original_amount')();
  TextColumn get originalCurrency =>
      text().named('original_currency').withLength(max: 3)();
  RealColumn get exchangeRate => real().named('exchange_rate')();
  DateTimeColumn get rateDate => dateTime().named('rate_date')();
  BoolColumn get rateEstimated =>
      boolean().named('rate_estimated').withDefault(const Constant(false))();
  TextColumn get rateSource =>
      text().named('rate_source').withDefault(const Constant('frankfurter'))();
  TextColumn get exchangeEventId =>
      text().named('exchange_event_id').nullable()();
  TextColumn get categoryId => text().named('category_id').nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get sourceLabel => text().named('source_label').nullable()();
  DateTimeColumn get transactionDate => dateTime().named('transaction_date')();
  BoolColumn get isRecurring =>
      boolean().named('is_recurring').withDefault(const Constant(false))();
  TextColumn get recurrenceType => text().named('recurrence_type').nullable()();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('pending'))();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// PRD §20 — Categories table
@DataClassName('CategoryData')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(max: 50)();
  TextColumn get colourHex => text().named('colour_hex').withLength(max: 7)();

  /// [IconData.codePoint] for `fontFamily: MaterialIcons` (user-selectable in category editor).
  IntColumn get iconCodePoint => integer().named('icon_code_point').withDefault(
        const Constant(0xe148), // Icons.category
      )();
  BoolColumn get isDefault =>
      boolean().named('is_default').withDefault(const Constant(false))();
  BoolColumn get isHidden =>
      boolean().named('is_hidden').withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().named('sort_order')();
  TextColumn get parentId => text().named('parent_id').nullable()();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// PRD §20 — Budgets table
@DataClassName('BudgetData')
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get scope => text().withLength(max: 10)();
  TextColumn get categoryId => text().named('category_id').nullable()();
  RealColumn get amountBase => real().named('amount_base')();
  TextColumn get periodType =>
      text().named('period_type').withLength(max: 12)();
  DateTimeColumn get startDate => dateTime().named('start_date')();
  DateTimeColumn get endDate => dateTime().named('end_date').nullable()();
  BoolColumn get isActive =>
      boolean().named('is_active').withDefault(const Constant(true))();
  BoolColumn get notified80 =>
      boolean().named('notified_80').withDefault(const Constant(false))();
  BoolColumn get notified100 =>
      boolean().named('notified_100').withDefault(const Constant(false))();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// PRD §20 — Exchange Rates cache
@DataClassName('ExchangeRateData')
class ExchangeRates extends Table {
  TextColumn get id => text()();
  TextColumn get baseCurrency =>
      text().named('base_currency').withLength(max: 3)();
  TextColumn get quoteCurrency =>
      text().named('quote_currency').withLength(max: 3)();
  RealColumn get rate => real()();
  DateTimeColumn get rateDate => dateTime().named('rate_date')();
  DateTimeColumn get fetchedAt =>
      dateTime().named('fetched_at').withDefault(currentDateAndTime)();
  TextColumn get source => text().withDefault(const Constant('frankfurter'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// PRD §20 — Currency Balances (derived running balance)
@DataClassName('CurrencyBalanceData')
class CurrencyBalances extends Table {
  TextColumn get id => text()();
  TextColumn get currency => text().withLength(max: 3)();
  RealColumn get balance => real()();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// PRD §20 — Sync Queue (pending sync operations)
@DataClassName('SyncQueueData')
class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get recordType => text().named('record_type')();
  TextColumn get recordId => text().named('record_id')();
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().named('last_error').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// PRD §20 — Settings (key-value store)
@DataClassName('SettingData')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

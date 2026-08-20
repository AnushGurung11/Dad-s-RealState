abstract final class AppConfig {
  static const String appName = 'renttrack';

  /// App-wide currency symbol. Every amount-display widget must go through
  /// this constant — never hardcode a currency string per-screen.
  static const String currencySymbol = 'AED';

  static const int schemaVersion = 1;

  static const String metaFileName = 'schema.json';
  static const String flatsFileName = 'flats.json';
  static const String bedsFileName = 'beds.json';
  static const String peopleFileName = 'people.json';
  static const String paymentsFileName = 'payments.json';
  static const String expensesFileName = 'expenses.json';
  static const String leaseCheckSettingsFileName = 'lease_check_settings.json';
  static const String leaseCheckRecordsFileName = 'lease_check_records.json';

  static const String prefKeyCurrentMonth = 'currentMonth';
}

/// Helper for building a `YYYY-MM` month string from a [DateTime].
String monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
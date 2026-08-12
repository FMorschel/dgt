/// The timezone the date columns are rendered in.
///
/// Timestamps reach dgt as absolute instants: git prints a UTC offset in its
/// `%ci` format, and Gerrit documents its timestamps as UTC. Both are
/// therefore converted for display rather than shown verbatim, so the local
/// and Gerrit columns always refer to the same clock.
enum DateDisplay {
  /// Render timestamps in the machine's local timezone. The default, since it
  /// matches the wall clock the user was looking at when they committed.
  local(cliValue: 'local', description: "The machine's local timezone"),

  /// Render timestamps in UTC.
  utc(cliValue: 'utc', description: 'Coordinated Universal Time');

  const DateDisplay({required this.cliValue, required this.description});

  /// The default used when neither the CLI nor the config file says otherwise.
  static const DateDisplay defaultValue = local;

  /// Finds the display mode a `--dates` value selects, ignoring case.
  ///
  /// Returns null for values this enum does not know about.
  static DateDisplay? fromCliValue(String? value) {
    if (value == null) return null;

    final lowerValue = value.toLowerCase();
    for (final display in values) {
      if (display.cliValue == lowerValue) {
        return display;
      }
    }
    return null;
  }

  /// The `--dates` value that selects this mode.
  final String cliValue;

  /// Help text shown for [cliValue].
  final String description;

  /// Converts [timestamp] into the timezone this mode displays.
  DateTime apply(DateTime timestamp) => switch (this) {
    .local => timestamp.toLocal(),
    .utc => timestamp.toUtc(),
  };
}

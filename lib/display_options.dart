import 'package:args/args.dart';

import 'config_service.dart';

/// Configuration options for controlling what information to display in the
/// branch table output.
///
/// This class encapsulates all display-related flags that control which columns
/// and information should be shown when listing branches.
class DisplayOptions {
  /// Creates a new DisplayOptions instance.
  ///
  /// All parameters default to their most common values:
  /// - [showGerrit]: true - Show Gerrit information by default
  /// - [showLocal]: true - Show local Git information by default
  /// - [showTiming]: false - Don't show timing by default
  /// - [showUrl]: false - Don't show URLs by default
  const DisplayOptions({
    this.showGerrit = true,
    this.showLocal = true,
    this.showTiming = false,
    this.showUrl = false,
  });

  /// Creates a DisplayOptions instance by resolving values from CLI arguments,
  /// config file, and defaults.
  ///
  /// Resolution precedence: CLI flags > Config file > Built-in defaults
  ///
  /// [results] - Parsed command-line arguments
  /// [config] - Configuration loaded from file (optional)
  factory DisplayOptions.resolve({
    required ArgResults results,
    required DgtConfig? config,
  }) {
    return DisplayOptions(
      showGerrit: config.resolveFlag(results, 'gerrit', true),
      showLocal: config.resolveFlag(results, 'local', true),
      showTiming: results.flag('timing'),
      showUrl: config.resolveFlag(results, 'url', false),
    );
  }

  /// Whether to display Gerrit-related columns (hash, date).
  final bool showGerrit;

  /// Whether to display local Git columns (hash, date).
  final bool showLocal;

  /// Whether to display performance timing information.
  final bool showTiming;

  /// Whether to display the Gerrit URL column.
  final bool showUrl;

  /// Creates a copy of this DisplayOptions with the specified fields replaced.
  DisplayOptions copyWith({
    bool? showGerrit,
    bool? showLocal,
    bool? showTiming,
    bool? showUrl,
  }) {
    return DisplayOptions(
      showGerrit: showGerrit ?? this.showGerrit,
      showLocal: showLocal ?? this.showLocal,
      showTiming: showTiming ?? this.showTiming,
      showUrl: showUrl ?? this.showUrl,
    );
  }

  @override
  String toString() {
    return 'DisplayOptions('
        'showGerrit: $showGerrit, '
        'showLocal: $showLocal, '
        'showTiming: $showTiming, '
        'showUrl: $showUrl'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DisplayOptions &&
        other.showGerrit == showGerrit &&
        other.showLocal == showLocal &&
        other.showTiming == showTiming &&
        other.showUrl == showUrl;
  }

  @override
  int get hashCode {
    return Object.hash(showGerrit, showLocal, showTiming, showUrl);
  }
}

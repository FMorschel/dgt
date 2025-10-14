import 'config_service.dart';
import 'terminal.dart';

/// Utilities for verbose output throughout the application.
///
/// This is a singleton that should be initialized once at application startup.
/// Use [VerboseOutput.instance] to access it throughout the application.
class VerboseOutput {
  /// Private constructor for singleton pattern.
  VerboseOutput._(this.isVerbose);

  /// The singleton instance.
  static VerboseOutput? _instance;

  /// Gets the singleton instance.
  ///
  /// Throws a [StateError] if [initialize] hasn't been called first.
  static VerboseOutput get instance {
    if (_instance == null) {
      throw StateError(
        'VerboseOutput has not been initialized. Call '
        'VerboseOutput.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Initializes the singleton with the verbose flag.
  ///
  /// This should be called once at application startup.
  /// [isVerbose] - Whether verbose output is enabled
  static void initialize(bool isVerbose) {
    _instance = VerboseOutput._(isVerbose);
  }

  /// Whether verbose output is enabled for this instance.
  final bool isVerbose;

  /// Displays the loaded configuration settings in verbose mode.
  void printConfigSettings(DgtConfig? config) {
    if (!isVerbose || config == null) return;

    Terminal.info('[VERBOSE] Using config file settings:');
    if (config.showLocal != null) {
      Terminal.info('[VERBOSE]   local: ${config.showLocal}');
    }
    if (config.showGerrit != null) {
      Terminal.info('[VERBOSE]   gerrit: ${config.showGerrit}');
    }
    if (config.showUrl != null) {
      Terminal.info('[VERBOSE]   url: ${config.showUrl}');
    }
    if (config.filterStatuses != null && config.filterStatuses!.isNotEmpty) {
      Terminal.info('[VERBOSE]   filterStatuses: ${config.filterStatuses}');
    }
    if (config.filterSince != null) {
      Terminal.info('[VERBOSE]   filterSince: ${config.filterSince}');
    }
    if (config.filterBefore != null) {
      Terminal.info('[VERBOSE]   filterBefore: ${config.filterBefore}');
    }
    if (config.filterDiverged != null) {
      Terminal.info('[VERBOSE]   filterDiverged: ${config.filterDiverged}');
    }
    if (config.sortField != null) {
      Terminal.info('[VERBOSE]   sortField: ${config.sortField}');
    }
    if (config.sortDirection != null) {
      Terminal.info('[VERBOSE]   sortDirection: ${config.sortDirection}');
    }
  }

  /// Prints verbose info if verbose mode is enabled.
  void info(String message) {
    if (isVerbose) {
      Terminal.info(message);
    }
  }

  /// Prints verbose warning if verbose mode is enabled.
  void warning(String message) {
    if (isVerbose) {
      Terminal.warning(message);
    }
  }

  /// Prints verbose error if verbose mode is enabled.
  void error(String message) {
    if (isVerbose) {
      Terminal.error(message);
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

/// Configuration options for the dgt tool
class DgtConfig {
  DgtConfig({
    this.showLocal,
    this.showGerrit,
    this.showUrl,
    this.filterStatuses,
    this.filterSince,
    this.filterBefore,
    this.filterDiverged,
    this.sortField,
    this.sortDirection,
  });

  factory DgtConfig.fromJson(Map<String, dynamic> json) {
    return DgtConfig(
      showLocal: json['local'] as bool?,
      showGerrit: json['gerrit'] as bool?,
      showUrl: json['url'] as bool?,
      filterStatuses: (json['filterStatuses'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      filterSince: json['filterSince'] as String?,
      filterBefore: json['filterBefore'] as String?,
      filterDiverged: json['filterDiverged'] as bool?,
      sortField: json['sortField'] as String?,
      sortDirection: json['sortDirection'] as String?,
    );
  }

  /// Creates a DgtConfig from command-line arguments for the config command.
  ///
  /// Only extracts values that were explicitly provided by the user.
  /// Returns null for values that were not specified.
  ///
  /// Handles the special case of --no-sort flag which clears sort configuration
  /// by setting empty strings.
  factory DgtConfig.fromArgResults(ArgResults results) {
    // Handle --no-sort flag (clears sort configuration)
    String? configSortField;
    String? configSortDirection;
    if (results.wasParsed('no-sort') && results.flag('no-sort')) {
      // User wants to clear sort configuration
      configSortField = ''; // Empty string signals to clear
      configSortDirection = '';
    } else if (results.wasParsed('sort')) {
      configSortField = results.option('sort');
      // Only set direction if sort field is also set
      if (results.wasParsed('desc')) {
        configSortDirection = 'desc';
      } else if (results.wasParsed('asc')) {
        configSortDirection = 'asc';
      }
    }

    return DgtConfig(
      showGerrit: _extractFlag(results, 'gerrit'),
      showLocal: _extractFlag(results, 'local'),
      showUrl: _extractFlag(results, 'url'),
      filterStatuses: _extractMultiOption(results, 'status'),
      filterSince: _extractOption(results, 'since'),
      filterBefore: _extractOption(results, 'before'),
      filterDiverged: _extractFlag(results, 'diverged'),
      sortField: configSortField,
      sortDirection: configSortDirection,
    );
  }

  /// Helper to extract a flag value if it was parsed, otherwise returns null.
  static bool? _extractFlag(ArgResults results, String flagName) =>
      results.wasParsed(flagName) ? results.flag(flagName) : null;

  /// Helper to extract an option value if it was parsed, otherwise returns
  /// null.
  static String? _extractOption(ArgResults results, String optionName) =>
      results.wasParsed(optionName) ? results.option(optionName) : null;

  /// Helper to extract a multi-option value if it was parsed, otherwise returns
  /// null.
  static List<String>? _extractMultiOption(
    ArgResults results,
    String optionName,
  ) => results.wasParsed(optionName) ? results.multiOption(optionName) : null;

  final bool? showLocal;
  final bool? showGerrit;
  final bool? showUrl;
  final List<String>? filterStatuses;
  final String? filterSince;
  final String? filterBefore;
  final bool? filterDiverged;
  final String? sortField;
  final String? sortDirection;

  Map<String, dynamic> toJson() {
    return {
      if (showLocal != null) 'local': showLocal,
      if (showGerrit != null) 'gerrit': showGerrit,
      if (showUrl != null) 'url': showUrl,
      if (filterStatuses != null && filterStatuses!.isNotEmpty)
        'filterStatuses': filterStatuses,
      if (filterSince != null) 'filterSince': filterSince,
      if (filterBefore != null) 'filterBefore': filterBefore,
      if (filterDiverged != null) 'filterDiverged': filterDiverged,
      if (sortField != null) 'sortField': sortField,
      if (sortDirection != null) 'sortDirection': sortDirection,
    };
  }
}

extension DgtConfigExtensions on DgtConfig? {
  /// Resolve a boolean flag value with precedence:
  /// 1. CLI flag (if explicitly provided by user)
  /// 2. Config file value (if available)
  /// 3. Default value
  ///
  /// Example:
  /// ```dart
  /// final showTiming = config.resolveFlag(
  ///   argResults,
  ///   'timing',
  ///   false,
  /// );
  /// ```
  bool resolveFlag(ArgResults argResults, String flagName, bool defaultValue) {
    // Check if flag was explicitly provided by the user
    if (argResults.wasParsed(flagName)) {
      return argResults.flag(flagName);
    }

    // Check config file based on flag name
    final configValue = _getConfigFlagValue(flagName);
    if (configValue != null) {
      return configValue;
    }

    // Return default value
    return defaultValue;
  }

  /// Resolve an option value with precedence:
  /// 1. CLI option (if explicitly provided by user)
  /// 2. Config file value (if available)
  /// 3. Default value
  ///
  /// Example:
  /// ```dart
  /// final sortField = config.resolveOption<String>(
  ///   argResults,
  ///   'sort',
  ///   null,
  /// );
  /// ```
  String? resolveOption(
    ArgResults argResults,
    String optionName,
    String? defaultValue,
  ) {
    // Check if option was explicitly provided by the user
    if (argResults.wasParsed(optionName)) {
      return argResults.option(optionName);
    }

    // Check config file based on option name
    final configValue = _getConfigOptionValue(optionName);
    if (configValue != null) {
      return configValue;
    }

    // Return default value
    return defaultValue;
  }

  /// Resolve a multi-option value with precedence:
  /// 1. CLI multi-option (if explicitly provided by user)
  /// 2. Config file value (if available)
  /// 3. Default value
  ///
  /// Example:
  /// ```dart
  /// final statusFilters = config.resolveMultiOption<String>(
  ///   argResults,
  ///   'status',
  ///   [],
  /// );
  /// ```
  List<String> resolveMultiOption(
    ArgResults argResults,
    String optionName,
    List<String> defaultValue,
  ) {
    // Check if multi-option was explicitly provided by the user
    if (argResults.wasParsed(optionName)) {
      final values = argResults.multiOption(optionName);
      return values;
    }

    // Check config file based on option name
    final configValue = _getConfigMultiOptionValue(optionName);
    if (configValue != null && configValue.isNotEmpty) {
      return configValue;
    }

    // Return default value
    return defaultValue;
  }

  /// Internal helper to get flag value from config based on flag name
  bool? _getConfigFlagValue(String flagName) {
    switch (flagName) {
      case 'gerrit':
        return this?.showGerrit;
      case 'local':
        return this?.showLocal;
      case 'url':
        return this?.showUrl;
      case 'diverged':
        return this?.filterDiverged;
      default:
        return null;
    }
  }

  /// Internal helper to get option value from config based on option name
  String? _getConfigOptionValue(String optionName) {
    switch (optionName) {
      case 'sort':
        return this?.sortField;
      case 'since':
        return this?.filterSince;
      case 'before':
        return this?.filterBefore;
      default:
        return null;
    }
  }

  /// Internal helper to get multi-option value from config based on option name
  List<String>? _getConfigMultiOptionValue(String optionName) {
    switch (optionName) {
      case 'status':
        return this?.filterStatuses;
      default:
        return null;
    }
  }
}

/// Service for reading and managing the dgt configuration file
class ConfigService {
  /// Get the path to the config file (~/.dgt/.config)
  static String getConfigFilePath() {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return '$home${Platform.pathSeparator}.dgt${Platform.pathSeparator}.config';
  }

  /// Read the configuration from ~/.dgt/.config
  /// Returns null if the file doesn't exist or can't be parsed
  static Future<DgtConfig?> readConfig({bool verbose = false}) async {
    try {
      final configPath = getConfigFilePath();
      final configFile = File(configPath);

      if (!await configFile.exists()) {
        if (verbose) {
          print('[VERBOSE] Config file not found at: $configPath');
        }
        return null;
      }

      final contents = await configFile.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      final config = DgtConfig.fromJson(json);

      if (verbose) {
        print('[VERBOSE] Loaded config from: $configPath');
        if (config.showLocal != null) {
          print('[VERBOSE]   local: ${config.showLocal}');
        }
        if (config.showGerrit != null) {
          print('[VERBOSE]   gerrit: ${config.showGerrit}');
        }
        if (config.showUrl != null) {
          print('[VERBOSE]   url: ${config.showUrl}');
        }
        if (config.filterStatuses != null &&
            config.filterStatuses!.isNotEmpty) {
          print('[VERBOSE]   filterStatuses: ${config.filterStatuses}');
        }
        if (config.filterSince != null) {
          print('[VERBOSE]   filterSince: ${config.filterSince}');
        }
        if (config.filterBefore != null) {
          print('[VERBOSE]   filterBefore: ${config.filterBefore}');
        }
        if (config.filterDiverged != null) {
          print('[VERBOSE]   filterDiverged: ${config.filterDiverged}');
        }
        if (config.sortField != null) {
          print('[VERBOSE]   sortField: ${config.sortField}');
        }
        if (config.sortDirection != null) {
          print('[VERBOSE]   sortDirection: ${config.sortDirection}');
        }
      }

      return config;
    } catch (e) {
      if (verbose) {
        print('[VERBOSE] Error reading config file: $e');
      }
      return null;
    }
  }

  /// Write configuration to ~/.dgt/.config
  static Future<void> writeConfig(
    DgtConfig config, {
    bool verbose = false,
  }) async {
    try {
      final configPath = getConfigFilePath();
      final configFile = File(configPath);
      final configDir = configFile.parent;

      // Create directory if it doesn't exist
      if (!await configDir.exists()) {
        await configDir.create(recursive: true);

        // On Windows, set the .dgt folder as hidden
        if (Platform.isWindows) {
          try {
            final result = await Process.run('attrib', [
              '+H',
              configDir.path,
            ], runInShell: true);
            if (verbose) {
              if (result.exitCode == 0) {
                print('[VERBOSE] Set .dgt folder as hidden on Windows');
              } else {
                print(
                  '[VERBOSE] Failed to set .dgt folder as hidden: '
                  '${result.stderr}',
                );
              }
            }
          } catch (e) {
            if (verbose) {
              print('[VERBOSE] Could not set hidden attribute: $e');
            }
            // Non-critical error, continue anyway
          }
        }
      }

      // Write the config as JSON
      final json = jsonEncode(config.toJson());
      await configFile.writeAsString(json);

      if (verbose) {
        print('[VERBOSE] Wrote config to: $configPath');
      }
    } catch (e) {
      if (verbose) {
        print('[VERBOSE] Error writing config file: $e');
      }
      rethrow;
    }
  }
}

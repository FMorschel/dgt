import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import 'cli_options.dart';
import 'verbose_output.dart';

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
    } else {
      // Handle standalone --asc or --desc flags without --sort
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
  T resolveOption<T extends String?>(
    ArgResults argResults,
    String optionName,
    T defaultValue,
  ) {
    // Check if option was explicitly provided by the user
    if (argResults.wasParsed(optionName)) {
      return argResults.option(optionName) as T;
    }

    // Check config file based on option name
    final configValue = _getConfigOptionValue(optionName);
    if (configValue != null) {
      return configValue as T;
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

  /// Resolve sort direction with special handling for asc/desc flags.
  ///
  /// Precedence:
  /// 1. --desc flag (if explicitly provided)
  /// 2. --asc flag (if explicitly provided)
  /// 3. Config file value (if available)
  /// 4. Default value
  ///
  /// Example:
  /// ```dart
  /// final sortDirection = config.resolveSortDirection(
  ///   argResults,
  ///   'asc', // default
  /// );
  /// ```
  String resolveSortDirection(ArgResults argResults, String defaultValue) {
    // Check if desc flag was explicitly provided
    if (argResults.wasParsed('desc') && argResults.flag('desc')) {
      return 'desc';
    }

    // Check if asc flag was explicitly provided
    if (argResults.wasParsed('asc') && argResults.flag('asc')) {
      return 'asc';
    }

    // Check config file value
    if (this?.sortDirection case var direction?) {
      return direction;
    }

    // Return default value
    return defaultValue;
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
  static Future<DgtConfig?> readConfig() async {
    try {
      final configPath = getConfigFilePath();
      final configFile = File(configPath);

      if (!await configFile.exists()) {
        VerboseOutput.instance.info(
          '[VERBOSE] Config file not found at: $configPath',
        );
        return null;
      }

      final contents = await configFile.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      final config = DgtConfig.fromJson(json);

      VerboseOutput.instance.info('[VERBOSE] Loaded config from: $configPath');
      if (config.showLocal != null) {
        VerboseOutput.instance.info('[VERBOSE]   local: ${config.showLocal}');
      }
      if (config.showGerrit != null) {
        VerboseOutput.instance.info('[VERBOSE]   gerrit: ${config.showGerrit}');
      }
      if (config.showUrl != null) {
        VerboseOutput.instance.info('[VERBOSE]   url: ${config.showUrl}');
      }
      if (config.filterStatuses != null && config.filterStatuses!.isNotEmpty) {
        VerboseOutput.instance.info(
          '[VERBOSE]   filterStatuses: ${config.filterStatuses}',
        );
      }
      if (config.filterSince != null) {
        VerboseOutput.instance.info(
          '[VERBOSE]   filterSince: ${config.filterSince}',
        );
      }
      if (config.filterBefore != null) {
        VerboseOutput.instance.info(
          '[VERBOSE]   filterBefore: ${config.filterBefore}',
        );
      }
      if (config.filterDiverged != null) {
        VerboseOutput.instance.info(
          '[VERBOSE]   filterDiverged: ${config.filterDiverged}',
        );
      }
      if (config.sortField != null) {
        VerboseOutput.instance.info(
          '[VERBOSE]   sortField: ${config.sortField}',
        );
      }
      if (config.sortDirection != null) {
        VerboseOutput.instance.info(
          '[VERBOSE]   sortDirection: ${config.sortDirection}',
        );
      }

      return config;
    } catch (e) {
      VerboseOutput.instance.info('[VERBOSE] Error reading config file: $e');
      return null;
    }
  }

  /// Write configuration to ~/.dgt/.config
  static Future<void> writeConfig(DgtConfig config) async {
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
            if (result.exitCode == 0) {
              VerboseOutput.instance.info(
                '[VERBOSE] Set .dgt folder as hidden on Windows',
              );
            } else {
              VerboseOutput.instance.info(
                '[VERBOSE] Failed to set .dgt folder as hidden: '
                '${result.stderr}',
              );
            }
          } catch (e) {
            VerboseOutput.instance.info(
              '[VERBOSE] Could not set hidden attribute: $e',
            );
            // Non-critical error, continue anyway
          }
        }
      }

      // Write the config as JSON
      final json = jsonEncode(config.toJson());
      await configFile.writeAsString(json);

      VerboseOutput.instance.info('[VERBOSE] Wrote config to: $configPath');
    } catch (e) {
      VerboseOutput.instance.info('[VERBOSE] Error writing config file: $e');
      rethrow;
    }
  }

  /// Display the current configuration to the console
  static Future<void> showConfig() async {
    try {
      final configPath = getConfigFilePath();
      final configFile = File(configPath);

      if (!await configFile.exists()) {
        print('No configuration file found at: $configPath');
        print('');
        print('To create a configuration file, use:');
        print('  dgt config --gerrit --local');
        print('  dgt config --status active');
        print('  dgt config --sort local-date --desc');
        return;
      }

      final contents = await configFile.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      final config = DgtConfig.fromJson(json);

      print('Configuration file: $configPath');
      print('');

      if (json.isEmpty) {
        print('Configuration is empty (using all defaults).');
        return;
      }

      print('Current settings:');
      print('');

      // Display settings
      if (config.showLocal != null) {
        print('  local:  ${config.showLocal}');
      }
      if (config.showGerrit != null) {
        print('  gerrit: ${config.showGerrit}');
      }
      if (config.showUrl != null) {
        print('  url:    ${config.showUrl}');
      }
      if (config.filterStatuses != null && config.filterStatuses!.isNotEmpty) {
        print('  filterStatuses: ${config.filterStatuses}');
      }
      if (config.filterSince != null) {
        print('  filterSince:    ${config.filterSince}');
      }
      if (config.filterBefore != null) {
        print('  filterBefore:   ${config.filterBefore}');
      }
      if (config.filterDiverged != null) {
        print('  filterDiverged: ${config.filterDiverged}');
      }
      if (config.sortField != null) {
        print('  sortField:      ${config.sortField}');
      }
      if (config.sortDirection != null) {
        print('  sortDirection:  ${config.sortDirection}');
      }

      print('');
      print('These settings are used as defaults.');
      print('Override with command-line flags when needed.');
    } catch (e) {
      VerboseOutput.instance.info('[VERBOSE] Error reading config file: $e');
      print('Error reading configuration file: $e');
    }
  }

  /// Clean (reset) the configuration file to defaults
  static Future<void> cleanConfig({bool force = false}) async {
    try {
      final configPath = getConfigFilePath();
      final configFile = File(configPath);

      if (!await configFile.exists()) {
        print('No configuration file found at: $configPath');
        print('Nothing to clean.');
        return;
      }

      // Prompt for confirmation unless force flag is set
      if (!force) {
        stdout.write(
          'This will reset all configuration to defaults. Continue? (y/N): ',
        );
        final response = stdin.readLineSync()?.toLowerCase().trim();
        if (response != 'y' && response != 'yes') {
          print('Cancelled.');
          return;
        }
      }

      // Delete the config file
      await configFile.delete();

      VerboseOutput.instance.info('[VERBOSE] Deleted config file: $configPath');

      print('Configuration reset to defaults.');
      print('Config file deleted: $configPath');
    } catch (e) {
      VerboseOutput.instance.info('[VERBOSE] Error cleaning config file: $e');
      print('Error cleaning configuration: $e');
    }
  }

  /// Remove specific options from the configuration
  ///
  /// If [removals] is null or empty, all configuration is removed (same as
  /// cleanConfig).
  /// If [removals] contains specific items, only those options are removed.
  ///
  /// For list-based options (status), provide a value to remove only that item.
  /// For conditional options (sort), provide a value to remove only if it
  /// matches.
  static Future<void> removeOptions(
    List<({RemovableConfigOption option, String? value})>? removals,
  ) async {
    try {
      // If no options specified, perform full clean
      if (removals == null || removals.isEmpty) {
        await cleanConfig(force: true);
        return;
      }

      // Read existing config
      final existingConfig = await readConfig();

      if (existingConfig == null) {
        print('No configuration file found. Nothing to remove.');
        return;
      }

      // Start with existing config and remove each requested option
      var newConfig = existingConfig;
      final removedItems = <String>[];

      for (final removal in removals) {
        final option = removal.option;
        final value = removal.value;

        // Create a new config with the specified option removed
        // Using exhaustive switch expression
        final updated = switch (option) {
          RemovableConfigOption.status => () {
            // For status, support removing specific values from the list
            if (value != null && newConfig.filterStatuses != null) {
              final updatedList = newConfig.filterStatuses!
                  .where((status) => status != value)
                  .toList();
              // If list becomes empty, set to null to remove from config
              final newStatuses = updatedList.isEmpty ? null : updatedList;
              removedItems.add(
                newStatuses == null ? 'status' : 'status:$value',
              );
              return DgtConfig(
                showLocal: newConfig.showLocal,
                showGerrit: newConfig.showGerrit,
                showUrl: newConfig.showUrl,
                filterStatuses: newStatuses,
                filterSince: newConfig.filterSince,
                filterBefore: newConfig.filterBefore,
                filterDiverged: newConfig.filterDiverged,
                sortField: newConfig.sortField,
                sortDirection: newConfig.sortDirection,
              );
            } else {
              // No value specified or no existing statuses, remove entire
              // option
              removedItems.add('status');
              return DgtConfig(
                showLocal: newConfig.showLocal,
                showGerrit: newConfig.showGerrit,
                showUrl: newConfig.showUrl,
                filterStatuses: null, // Remove status filters
                filterSince: newConfig.filterSince,
                filterBefore: newConfig.filterBefore,
                filterDiverged: newConfig.filterDiverged,
                sortField: newConfig.sortField,
                sortDirection: newConfig.sortDirection,
              );
            }
          }(),
          RemovableConfigOption.diverged => () {
            removedItems.add('diverged');
            return DgtConfig(
              showLocal: newConfig.showLocal,
              showGerrit: newConfig.showGerrit,
              showUrl: newConfig.showUrl,
              filterStatuses: newConfig.filterStatuses,
              filterSince: newConfig.filterSince,
              filterBefore: newConfig.filterBefore,
              filterDiverged: null, // Remove diverged filter
              sortField: newConfig.sortField,
              sortDirection: newConfig.sortDirection,
            );
          }(),
          RemovableConfigOption.sort => () {
            // For sort, support conditional removal based on current value
            if (value != null) {
              // Only remove if current sort field matches the specified value
              if (newConfig.sortField == value) {
                removedItems.add('sort:$value');
                return DgtConfig(
                  showLocal: newConfig.showLocal,
                  showGerrit: newConfig.showGerrit,
                  showUrl: newConfig.showUrl,
                  filterStatuses: newConfig.filterStatuses,
                  filterSince: newConfig.filterSince,
                  filterBefore: newConfig.filterBefore,
                  filterDiverged: newConfig.filterDiverged,
                  sortField: null, // Remove sort options
                  sortDirection: null,
                );
              } else {
                // Value doesn't match, don't remove
                return newConfig;
              }
            } else {
              // No value specified, remove entire sort configuration
              removedItems.add('sort');
              return DgtConfig(
                showLocal: newConfig.showLocal,
                showGerrit: newConfig.showGerrit,
                showUrl: newConfig.showUrl,
                filterStatuses: newConfig.filterStatuses,
                filterSince: newConfig.filterSince,
                filterBefore: newConfig.filterBefore,
                filterDiverged: newConfig.filterDiverged,
                sortField: null, // Remove sort options
                sortDirection: null,
              );
            }
          }(),
          RemovableConfigOption.local => () {
            removedItems.add('local');
            return DgtConfig(
              showLocal: null, // Remove local display setting
              showGerrit: newConfig.showGerrit,
              showUrl: newConfig.showUrl,
              filterStatuses: newConfig.filterStatuses,
              filterSince: newConfig.filterSince,
              filterBefore: newConfig.filterBefore,
              filterDiverged: newConfig.filterDiverged,
              sortField: newConfig.sortField,
              sortDirection: newConfig.sortDirection,
            );
          }(),
          RemovableConfigOption.gerrit => () {
            removedItems.add('gerrit');
            return DgtConfig(
              showLocal: newConfig.showLocal,
              showGerrit: null, // Remove gerrit display setting
              showUrl: newConfig.showUrl,
              filterStatuses: newConfig.filterStatuses,
              filterSince: newConfig.filterSince,
              filterBefore: newConfig.filterBefore,
              filterDiverged: newConfig.filterDiverged,
              sortField: newConfig.sortField,
              sortDirection: newConfig.sortDirection,
            );
          }(),
          RemovableConfigOption.url => () {
            removedItems.add('url');
            return DgtConfig(
              showLocal: newConfig.showLocal,
              showGerrit: newConfig.showGerrit,
              showUrl: null, // Remove url display setting
              filterStatuses: newConfig.filterStatuses,
              filterSince: newConfig.filterSince,
              filterBefore: newConfig.filterBefore,
              filterDiverged: newConfig.filterDiverged,
              sortField: newConfig.sortField,
              sortDirection: newConfig.sortDirection,
            );
          }(),
          RemovableConfigOption.since => () {
            removedItems.add('since');
            return DgtConfig(
              showLocal: newConfig.showLocal,
              showGerrit: newConfig.showGerrit,
              showUrl: newConfig.showUrl,
              filterStatuses: newConfig.filterStatuses,
              filterSince: null, // Remove since filter
              filterBefore: newConfig.filterBefore,
              filterDiverged: newConfig.filterDiverged,
              sortField: newConfig.sortField,
              sortDirection: newConfig.sortDirection,
            );
          }(),
          RemovableConfigOption.before => () {
            removedItems.add('before');
            return DgtConfig(
              showLocal: newConfig.showLocal,
              showGerrit: newConfig.showGerrit,
              showUrl: newConfig.showUrl,
              filterStatuses: newConfig.filterStatuses,
              filterSince: newConfig.filterSince,
              filterBefore: null, // Remove before filter
              filterDiverged: newConfig.filterDiverged,
              sortField: newConfig.sortField,
              sortDirection: newConfig.sortDirection,
            );
          }(),
        };

        newConfig = updated;
      }

      // Write the updated config
      await writeConfig(newConfig);

      if (removedItems.isNotEmpty) {
        print('Removed [${removedItems.join(', ')}] from configuration.');
      } else {
        print('No matching configuration items to remove.');
      }

      VerboseOutput.instance.info('[VERBOSE] Updated config file');
    } catch (e) {
      VerboseOutput.instance.info('[VERBOSE] Error removing options: $e');
      print('Error removing options: $e');
    }
  }
}

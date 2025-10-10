import 'dart:convert';
import 'dart:io';

/// Configuration options for the dgt tool
class DgtConfig {
  DgtConfig({
    this.showLocal,
    this.showGerrit,
    this.filterStatuses,
    this.filterSince,
    this.filterBefore,
    this.filterDiverged,
  });

  factory DgtConfig.fromJson(Map<String, dynamic> json) {
    return DgtConfig(
      showLocal: json['local'] as bool?,
      showGerrit: json['gerrit'] as bool?,
      filterStatuses: (json['filterStatuses'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      filterSince: json['filterSince'] as String?,
      filterBefore: json['filterBefore'] as String?,
      filterDiverged: json['filterDiverged'] as bool?,
    );
  }

  final bool? showLocal;
  final bool? showGerrit;
  final List<String>? filterStatuses;
  final String? filterSince;
  final String? filterBefore;
  final bool? filterDiverged;

  Map<String, dynamic> toJson() {
    return {
      if (showLocal != null) 'local': showLocal,
      if (showGerrit != null) 'gerrit': showGerrit,
      if (filterStatuses != null && filterStatuses!.isNotEmpty)
        'filterStatuses': filterStatuses,
      if (filterSince != null) 'filterSince': filterSince,
      if (filterBefore != null) 'filterBefore': filterBefore,
      if (filterDiverged != null) 'filterDiverged': filterDiverged,
    };
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
        print('[VERBOSE]   local: ${config.showLocal}');
        print('[VERBOSE]   gerrit: ${config.showGerrit}');
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

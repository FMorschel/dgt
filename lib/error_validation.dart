import 'package:args/args.dart';

import 'cli_options.dart';
import 'terminal.dart';

/// Validates that conflicting flags are not used together.
/// Returns true if validation passes, false if there's a conflict.
class FlagValidator {
  /// Validates that --status and --no-status are not both specified.
  static bool validateStatusFlags(ArgResults results) {
    if (results.wasParsed('status') && results.wasParsed('no-status')) {
      Terminal.error(
        'Error: Cannot specify both --status and --no-status flags.',
      );
      Terminal.info(
        'Use --status to filter by status, or --no-status to show all '
        'branches.',
      );
      return false;
    }
    return true;
  }

  /// Validates that --diverged and --no-diverged are not both specified.
  static bool validateDivergedFlags(ArgResults results) {
    if (results.wasParsed('diverged') && results.wasParsed('no-diverged')) {
      Terminal.error(
        'Error: Cannot specify both --diverged and --no-diverged flags.',
      );
      Terminal.info(
        'Use --diverged to filter, or --no-diverged to disable the filter.',
      );
      return false;
    }
    return true;
  }

  /// Validates that --sort and --no-sort are not both specified.
  static bool validateSortFlags(ArgResults results) {
    if (results.wasParsed('sort') && results.wasParsed('no-sort')) {
      Terminal.error('Error: Cannot specify both --sort and --no-sort flags.');
      Terminal.info(
        'Use --sort to sort by a field, or --no-sort to disable sorting.',
      );
      return false;
    }
    return true;
  }

  /// Validates that --asc and --desc are not both specified.
  static bool validateSortDirectionFlags(ArgResults results) {
    if (results.wasParsed('asc') && results.wasParsed('desc')) {
      Terminal.error('Error: Cannot specify both --asc and --desc flags.');
      Terminal.info('Please use only one sort direction flag.');
      return false;
    }
    return true;
  }

  /// Validates all common flag conflicts.
  /// Returns true if all validations pass, false if any fail.
  static bool validateAllFlags(ArgResults results) {
    return validateStatusFlags(results) &&
        validateDivergedFlags(results) &&
        validateSortFlags(results) &&
        validateSortDirectionFlags(results);
  }

  /// Checks if the config command has at least one flag specified.
  static bool hasConfigFlags(ArgResults results) {
    // Flags that should be ignored for config command
    // (these are global or command-specific flags, not config options)
    const ignoredFlags = {
      'help',
      'verbose',
      'version',
      'timing',
      'force', // config-specific flag
    };

    // Check if any option was parsed, excluding the ignored flags
    return results.options.any(
      (option) => !ignoredFlags.contains(option) && results.wasParsed(option),
    );
  }

  /// Prints help for available sort fields.
  /// Dynamically generates the list from the actual allowed values.
  static void printSortHelp() {
    Terminal.info('');
    Terminal.info('Available sort fields:');

    // Find the longest field name for alignment
    final maxLength = CliOptions.allowedSortFields
        .map((f) => f.length)
        .reduce((a, b) => a > b ? a : b);

    // Print each field with its description, properly aligned
    for (final field in CliOptions.allowedSortFields) {
      final description =
          CliOptions.sortFieldDescriptions[field] ?? 'No description';
      final padding = ' ' * (maxLength - field.length + 3);
      Terminal.info('  $field$padding- $description');
    }

    Terminal.info('');
    Terminal.info('Run "dgt --help" for more information.');
    Terminal.info('');
  }

  /// Prints help for available status values.
  static void printStatusHelp() {
    Terminal.info('');
    Terminal.info('Allowed values:');

    // Print regular status values (not including special values)
    for (final status in CliOptions.allowedStatusValues) {
      final description = CliOptions.statusDescriptions[status];
      if (description != null) {
        // Regular status values with descriptions
        final padding = ' ' * (11 - status.length); // 'abandoned' is longest at 9 chars
        Terminal.info('  $status$padding- $description');
      } else {
        // Special values like 'gerrit' and 'local'
        if (status == 'gerrit') {
          Terminal.info('  gerrit     - All Gerrit statuses');
        } else if (status == 'local') {
          Terminal.info('  local      - Branches without Gerrit configuration');
        }
      }
    }

    Terminal.info('');
    Terminal.info('Run "dgt --help" for more information.');
    Terminal.info('');
  }
}

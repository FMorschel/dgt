import 'package:args/args.dart';

/// Metadata for CLI options used across the application.
/// This centralizes option definitions so they can be reused for:
/// - Building the ArgParser
/// - Generating help text
/// - Validation
class CliOptions {
  // Display option names
  static const String gerrit = 'gerrit';
  static const String local = 'local';
  static const String url = 'url';

  // Filter option names
  static const String status = 'status';
  static const String since = 'since';
  static const String before = 'before';
  static const String diverged = 'diverged';
  static const String noStatus = 'no-status';
  static const String noDiverged = 'no-diverged';

  // Sort option names
  static const String sort = 'sort';
  static const String noSort = 'no-sort';
  static const String asc = 'asc';
  static const String desc = 'desc';

  // Global option names
  static const String help = 'help';
  static const String verbose = 'verbose';
  static const String version = 'version';
  static const String timing = 'timing';

  // Command-specific option names
  static const String path = 'path';
  static const String force = 'force';

  /// Allowed status values for filtering.
  static const List<String> allowedStatusValues = [
    'wip',
    'active',
    'merged',
    'abandoned',
    'conflict',
    'gerrit',
    'local',
  ];

  /// Maps CLI-friendly status values to display values.
  static const Map<String, String> statusMapping = {
    'wip': 'WIP',
    'active': 'Active',
    'merged': 'Merged',
    'abandoned': 'Abandoned',
    'conflict': 'Merge conflict',
    // Special values
    'gerrit': '',
    'local': '',
  };

  /// Human-readable descriptions for status values.
  static const Map<String, String> statusDescriptions = {
    'wip': 'Work in Progress',
    'active': 'Ready for review',
    'merged': 'Successfully merged',
    'abandoned': 'Abandoned changes',
    'conflict': 'Has merge conflicts',
    'gerrit': 'All Gerrit statuses',
    'local': 'Branches without Gerrit configuration',
  };

  /// All accepted Gerrit status values (for --status gerrit)
  static const List<String> allGerritStatuses = [
    'WIP',
    'Active',
    'Merged',
    'Abandoned',
    'Merge conflict',
  ];

  /// Special status value to indicate local-only branches
  static const String localStatusValue = 'local';

  /// Allowed sort field values.
  static const List<String> allowedSortFields = [
    'local-date',
    'gerrit-date',
    'status',
    'divergences',
    'name',
  ];

  /// Human-readable descriptions for sort fields.
  static const Map<String, String> sortFieldDescriptions = {
    'local-date': 'Local commit date',
    'gerrit-date': 'Gerrit update date',
    'status': 'Gerrit status',
    'divergences': 'Divergence state (both, one side, in sync)',
    'name': 'Branch name',
  };

  /// Adds common display, filter, and sort options to a parser.
  /// Used by both 'list' and 'config' subcommands.
  static void addCommonOptions(ArgParser parser) {
    // Display options
    parser
      ..addFlag(
        gerrit,
        defaultsTo: true,
        negatable: true,
        help: 'Display Gerrit hash and date columns.',
      )
      ..addFlag(
        local,
        defaultsTo: true,
        negatable: true,
        help: 'Display local hash and date columns.',
      )
      ..addFlag(
        url,
        negatable: true,
        defaultsTo: false,
        help: 'Show Gerrit URL column in the output.',
      );

    // Filter options
    parser
      ..addMultiOption(
        status,
        help:
            'Filter branches by Gerrit status. '
            'Allowed: ${allowedStatusValues.join(", ")}',
        allowed: allowedStatusValues,
        valueHelp: 'status',
      )
      ..addOption(
        since,
        help: 'Filter branches with commits after this date (ISO 8601 format).',
        valueHelp: 'date',
      )
      ..addOption(
        before,
        help:
            'Filter branches with commits before this date (ISO 8601 format).',
        valueHelp: 'date',
      )
      ..addFlag(
        diverged,
        negatable: true,
        help: 'Filter to show only branches with local or remote differences.',
      )
      ..addFlag(
        noStatus,
        negatable: false,
        help:
            'Ignore status filters (overrides config; cannot use with '
            '--$status).',
      )
      ..addFlag(
        noDiverged,
        negatable: false,
        help:
            'Ignore diverged filter (overrides config; cannot use with '
            '--$diverged).',
      );

    // Sort options
    parser
      ..addOption(
        sort,
        help:
            'Sort branches by field. '
            'Allowed: ${CliOptions.allowedSortFields.join(", ")}',
        allowed: CliOptions.allowedSortFields,
        valueHelp: 'field',
      )
      ..addFlag(
        noSort,
        negatable: false,
        help:
            'Disable sorting (shows unsorted output; cannot use with --$sort).',
      )
      ..addFlag(
        asc,
        negatable: false,
        help: 'Sort in ascending order (default when --$sort is used).',
      )
      ..addFlag(desc, negatable: false, help: 'Sort in descending order.');
  }

  /// Builds the main argument parser with all commands and options.
  static ArgParser buildParser() {
    final parser = ArgParser()
      ..addFlag(
        help,
        abbr: 'h',
        negatable: false,
        help: 'Print this usage information.',
      )
      ..addFlag(
        verbose,
        abbr: 'v',
        negatable: false,
        help: 'Show additional command output.',
      )
      ..addFlag(version, negatable: false, help: 'Print the tool version.')
      ..addFlag(
        timing,
        abbr: 't',
        negatable: false,
        help: 'Display performance timing summary.',
      );

    // Add 'list' subcommand (default command)
    final listParser = parser.addCommand('list');
    listParser.addOption(
      path,
      abbr: 'p',
      help: 'Path to the Git repository to analyze.',
      valueHelp: 'path',
    );
    addCommonOptions(listParser);

    // Add 'config' subcommand
    final configParser = parser.addCommand('config');
    configParser.addFlag(
      force,
      abbr: 'f',
      negatable: false,
      help: 'Force operation without confirmation (for config clean).',
    );
    addCommonOptions(configParser);

    return parser;
  }
}

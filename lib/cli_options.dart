import 'package:args/args.dart';

import 'branch_status.dart';
import 'date_display.dart';

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
  static const String dates = 'dates';

  // Filter option names
  static const String status = 'status';
  static const String since = 'since';
  static const String before = 'before';
  static const String diverged = 'diverged';
  static const String noStatus = 'no-status';

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

  /// Special status value selecting every branch that has a Gerrit change.
  static const String gerritStatusValue = 'gerrit';

  /// Special status value to indicate local-only branches
  static const String localStatusValue = 'local';

  /// Allowed status values for filtering.
  ///
  /// The real statuses come from [BranchStatus]; the two special values select
  /// groups of branches rather than a single status.
  static final List<String> allowedStatusValues = [
    for (final status in BranchStatus.values) ?status.cliValue,
    gerritStatusValue,
    localStatusValue,
  ];

  /// Maps CLI-friendly status values to the text a display status starts with.
  ///
  /// Only real statuses appear here. [gerritStatusValue] and
  /// [localStatusValue] are deliberately absent: they have no display prefix,
  /// and an empty prefix would match every status.
  static final Map<String, String> statusMapping = {
    for (final status in BranchStatus.values)
      ?status.cliValue: status.displayPrefix,
  };

  /// Human-readable descriptions for status values.
  static final Map<String, String> statusDescriptions = {
    for (final status in BranchStatus.values)
      ?status.cliValue: ?status.description,
    gerritStatusValue: 'All Gerrit statuses',
    localStatusValue: 'Branches without Gerrit configuration',
  };

  /// Allowed values for the `--dates` option.
  static final List<String> allowedDateDisplays = [
    for (final display in DateDisplay.values) display.cliValue,
  ];

  /// Human-readable descriptions for `--dates` values.
  static final Map<String, String> dateDisplayDescriptions = {
    for (final display in DateDisplay.values)
      display.cliValue: display.description,
  };

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
  static void addCommonOptions(ArgParser parser, {bool allowNegated = true}) {
    // Display options
    parser
      ..addFlag(
        gerrit,
        defaultsTo: true,
        negatable: allowNegated,
        help: 'Display Gerrit hash and date columns.',
      )
      ..addFlag(
        local,
        defaultsTo: true,
        negatable: allowNegated,
        help: 'Display local hash and date columns.',
      )
      ..addFlag(
        url,
        defaultsTo: false,
        negatable: allowNegated,
        help: 'Show Gerrit URL column in the output.',
      )
      ..addOption(
        dates,
        help:
            'Timezone for the date columns. '
            'Allowed: ${allowedDateDisplays.join(", ")}',
        allowed: allowedDateDisplays,
        valueHelp: 'timezone',
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
        negatable: allowNegated,
        help: 'Filter to show only branches with local or remote differences.',
      )
      ..addFlag(
        noStatus,
        negatable: false,
        help:
            'Ignore status filters (overrides config; cannot use with '
            '--$status).',
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
    listParser
      ..addFlag(
        help,
        abbr: 'h',
        negatable: false,
        help: 'Print help for the list command.',
      )
      ..addOption(
        path,
        abbr: 'p',
        help: 'Path to the Git repository to analyze.',
        valueHelp: 'path',
      );
    addCommonOptions(listParser);

    // Add 'config' subcommand
    final configParser = parser.addCommand('config');
    configParser
      ..addFlag(
        help,
        abbr: 'h',
        negatable: false,
        help: 'Print help for the config command.',
      )
      ..addFlag(
        force,
        abbr: 'f',
        negatable: false,
        help: 'Force operation without confirmation (for config clean).',
      );

    // Add subcommands under config: show and clean
    final configShow = configParser.addCommand('show');
    configShow.addFlag(
      help,
      abbr: 'h',
      negatable: false,
      help: 'Print help for config show.',
    );

    final configClean = configParser.addCommand('clean');
    configClean
      ..addFlag(
        help,
        abbr: 'h',
        negatable: false,
        help: 'Print help for config clean.',
      )
      ..addFlag(
        force,
        abbr: 'f',
        negatable: false,
        help: 'Force operation without confirmation.',
      );

    // For the top-level config command (used to set defaults), use the
    // full set of common options. For the 'config clean' subcommand we want
    // only affirmative options (no --no- forms).
    addCommonOptions(configParser);
    addCommonOptions(configClean, allowNegated: false);

    // Add 'clean' subcommand
    // This command wraps 'git cl archive' and passes through all arguments
    // We don't define any options here because all arguments (including flags)
    // should be forwarded to 'git cl archive'. The parser will treat everything
    // after 'clean' as rest arguments that can be passed through.
    parser.addCommand('clean', ArgParser(allowTrailingOptions: false));

    return parser;
  }
}

/// Represents removable configuration options
/// This enum ensures exhaustive handling of all removable options
enum RemovableConfigOption {
  status,
  diverged,
  sort,
  local,
  gerrit,
  url,
  dates,
  since,
  before;

  /// Create from string representation
  /// Returns null if the option name is not valid
  static RemovableConfigOption? fromString(String optionName) {
    return switch (optionName) {
      'status' => .status,
      'diverged' => .diverged,
      'sort' => .sort,
      'local' => .local,
      'gerrit' => .gerrit,
      'url' => .url,
      'dates' => .dates,
      'since' => .since,
      'before' => .before,
      _ => null,
    };
  }

  /// Display name for this option
  String get displayName => switch (this) {
    .status => 'status',
    .diverged => 'diverged',
    .sort => 'sort',
    .local => 'local',
    .gerrit => 'gerrit',
    .url => 'url',
    .dates => 'dates',
    .since => 'since',
    .before => 'before',
  };
}

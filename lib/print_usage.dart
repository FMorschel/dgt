import 'package:args/args.dart';

import 'terminal.dart';

void printUsage(ArgParser argParser) {
  Terminal.info('Usage: dgt [options] [command]');
  Terminal.info('');
  Terminal.info(
    'A tool to list local Git branches with their Gerrit review status.',
  );
  Terminal.info('');

  // Global options
  Terminal.info('Global options:');
  Terminal.info('  -h, --help       Print this usage information.');
  Terminal.info('  -v, --verbose    Show additional command output.');
  Terminal.info('  --version        Print the tool version.');
  Terminal.info('  -t, --timing     Display performance timing summary.');
  Terminal.info('');

  Terminal.info('Commands:');
  Terminal.info(
    '  list         List all local branches with Gerrit status (default)',
  );
  Terminal.info(
    '  config       Set default configuration options in ~/.dgt/.config',
  );
  Terminal.info(
    '  clean        Archive merged branches (wraps git cl archive)',
  );
  Terminal.info('');
  Terminal.info(
    'Run "dgt <command> --help" for more information on a command.',
  );
  Terminal.info('');

  // List command options
  Terminal.info('List command options:');
  Terminal.info('  -h, --help           Print help for the list command.');
  Terminal.info(
    '  -p, --path <path>    Path to the Git repository to analyze.',
  );
  Terminal.info('');
  Terminal.info('  Display options:');
  Terminal.info(
    '      --[no-]gerrit    Display Gerrit hash and date columns (default: on)',
  );
  Terminal.info(
    '      --[no-]local     Display local hash and date columns (default: on)',
  );
  Terminal.info(
    '      --[no-]url       Show Gerrit URL column in the output (default: '
    'off)',
  );
  Terminal.info('');
  Terminal.info('  Filter options:');
  Terminal.info('      --status <status>    Filter branches by Gerrit status');
  Terminal.info(
    '                           (wip, active, merged, abandoned, conflict, '
    'gerrit, local)',
  );
  Terminal.info(
    '      --since <date>       Filter branches with commits after this date '
    '(ISO 8601)',
  );
  Terminal.info(
    '      --before <date>      Filter branches with commits before this date '
    '(ISO 8601)',
  );
  Terminal.info(
    '      --[no-]diverged      Filter to show only branches with local/remote '
    'differences',
  );
  Terminal.info(
    '      --no-status          Ignore status filters (overrides config)',
  );
  Terminal.info('');
  Terminal.info('  Sort options:');
  Terminal.info('      --sort <field>       Sort branches by field');
  Terminal.info(
    '                           (local-date, gerrit-date, status, divergences, '
    'name)',
  );
  Terminal.info('      --asc                Sort in ascending order (default)');
  Terminal.info('      --desc               Sort in descending order');
  Terminal.info(
    '      --no-sort            Disable sorting (shows unsorted output)',
  );
  Terminal.info('');

  // Config command options
  Terminal.info('Config command options:');
  Terminal.info('  -h, --help           Print help for the config command.');
  Terminal.info(
    '  -f, --force          Force operation without confirmation (for config '
    'clean)',
  );
  Terminal.info('');
  Terminal.info('  Subcommands:');
  Terminal.info('      show             Display current configuration');
  Terminal.info('      clean            Reset configuration to defaults');
  Terminal.info('');
  Terminal.info('  Display options (same as list command)');
  Terminal.info('  Filter options (same as list command)');
  Terminal.info('  Sort options (same as list command)');
  Terminal.info('');

  // Clean command options
  Terminal.info('Clean command options:');
  Terminal.info('  -h, --help           Print help for the clean command.');
  Terminal.info('');
  Terminal.info('  Note: All other arguments are passed to "git cl archive".');
  Terminal.info('');

  Terminal.info('Examples:');
  Terminal.info('');
  Terminal.info('  Basic usage:');
  Terminal.info(
    '    dgt                                  # List branches in current '
    'directory',
  );
  Terminal.info(
    '    dgt list                             # Explicit list command (same as '
    'above)',
  );
  Terminal.info(
    '    dgt --verbose                        # List with verbose output',
  );
  Terminal.info(
    '    dgt list --path D:\\repo              # List branches in specific '
    'repository',
  );
  Terminal.info(
    '    dgt -v -t                            # Verbose output with timing',
  );
  Terminal.info('');

  Terminal.info('  Display options:');
  Terminal.info(
    '    dgt --no-gerrit                      # Hide Gerrit hash and date '
    'columns',
  );
  Terminal.info(
    '    dgt list --no-local                  # Hide local hash and date '
    'columns',
  );
  Terminal.info(
    '    dgt list --url                       # Show Gerrit URL column',
  );
  Terminal.info('');

  Terminal.info('  Filtering:');
  Terminal.info(
    '    dgt --status active                  # Show only Active branches',
  );
  Terminal.info(
    '    dgt list --status wip --status active    # Show WIP and Active '
    'branches',
  );
  Terminal.info(
    '    dgt list --status local              # Show only local branches (no '
    'Gerrit)',
  );
  Terminal.info(
    '    dgt list --since 2025-10-01          # Branches with commits after '
    'this date',
  );
  Terminal.info(
    '    dgt list --before 2025-10-10         # Branches with commits before '
    'this date',
  );
  Terminal.info(
    '    dgt list --diverged                  # Show only diverged branches',
  );
  Terminal.info(
    '    dgt list --no-status                 # Ignore config status filters',
  );
  Terminal.info('');

  Terminal.info('  Sorting:');
  Terminal.info(
    '    dgt list --sort local-date --desc    # Sort by local date, newest '
    'first',
  );
  Terminal.info(
    '    dgt list --sort status               # Sort by status (ascending)',
  );
  Terminal.info(
    '    dgt list --sort name --asc           # Sort by branch name '
    'alphabetically',
  );
  Terminal.info(
    '    dgt list --no-sort                   # Disable default sort',
  );
  Terminal.info('');

  Terminal.info('  Configuration:');
  Terminal.info(
    '    dgt config show                      # Display current configuration',
  );
  Terminal.info(
    '    dgt config clean                     # Reset config to defaults',
  );
  Terminal.info(
    '    dgt config --no-gerrit               # Set default to hide Gerrit '
    'columns',
  );
  Terminal.info(
    '    dgt config --status active --diverged    # Set default filters',
  );
  Terminal.info(
    '    dgt config --sort local-date --desc  # Set default sort options',
  );
  Terminal.info(
    '    dgt config --no-status               # Remove status filters from '
    'config',
  );
  Terminal.info(
    '    dgt config --no-sort                 # Remove sort from config',
  );
  Terminal.info('');

  Terminal.info('  Clean command:');
  Terminal.info(
    '    dgt clean                            # Archive merged branches',
  );
  Terminal.info(
    '    dgt -v -t clean                      # Archive with verbose output '
    'and timing',
  );
  Terminal.info(
    '    dgt clean --help                     # Show git cl archive help',
  );
  Terminal.info('');

  Terminal.info('Available status values:');
  Terminal.info('  wip       - Work in Progress');
  Terminal.info('  active    - Ready for review');
  Terminal.info('  merged    - Successfully merged');
  Terminal.info('  abandoned - Abandoned changes');
  Terminal.info('  conflict  - Has merge conflicts');
  Terminal.info('  gerrit    - All Gerrit statuses');
  Terminal.info('  local     - Branches without Gerrit configuration');
  Terminal.info('');

  Terminal.info('Available sort fields:');
  Terminal.info('  local-date    - Local commit date');
  Terminal.info('  gerrit-date   - Gerrit update date');
  Terminal.info('  status        - Gerrit status');
  Terminal.info('  divergences   - Divergence state');
  Terminal.info('  name          - Branch name (default)');
  Terminal.info('');

  Terminal.info('Notes:');
  Terminal.info('  • Cannot use --status with --no-status');
  Terminal.info(
    '  • Use --[no-]diverged to set the default for the diverged filter',
  );
  Terminal.info('  • Cannot use --sort with --no-sort');
  Terminal.info('  • Cannot use --asc with --desc');
  Terminal.info('  • Config command requires at least one flag');
  Terminal.info('  • If no command is specified, "list" is assumed');
  Terminal.info('  • Clean command passes all arguments to "git cl archive"');
  Terminal.info(
    '  • Use "dgt -v -t clean" for verbose/timing, not "dgt clean -v"',
  );
}

/// Prints help text specifically for the list command.
void printListHelp() {
  Terminal.info('Usage: dgt list [options]');
  Terminal.info('');
  Terminal.info('List all local Git branches with their Gerrit review status.');
  Terminal.info('');
  Terminal.info('Options:');
  Terminal.info('  -h, --help           Print this help information.');
  Terminal.info(
    '  -p, --path <path>    Path to the Git repository to analyze.',
  );
  Terminal.info('');
  Terminal.info('Display options:');
  Terminal.info(
    '  --[no-]gerrit        Display Gerrit hash and date columns (default: on)',
  );
  Terminal.info(
    '  --[no-]local         Display local hash and date columns (default: on)',
  );
  Terminal.info(
    '  --[no-]url           Show Gerrit URL column in the output (default: '
    'off)',
  );
  Terminal.info('');
  Terminal.info('Filter options:');
  Terminal.info('  --status <status>    Filter branches by Gerrit status');
  Terminal.info(
    '                       (wip, active, merged, abandoned, conflict, gerrit, '
    'local)',
  );
  Terminal.info(
    '  --since <date>       Filter branches with commits after this date '
    '(ISO 8601)',
  );
  Terminal.info(
    '  --before <date>      Filter branches with commits before this date '
    '(ISO 8601)',
  );
  Terminal.info(
    '  --[no-]diverged      Filter to show only branches with local/remote '
    'differences',
  );
  Terminal.info(
    '  --no-status          Ignore status filters (overrides config)',
  );
  // The --[no-]diverged flag is negatable and sets the diverged filter
  Terminal.info(
    '  --[no-]diverged      Set or clear the diverged filter (overrides '
    'config)',
  );
  Terminal.info('');
  Terminal.info('Sort options:');
  Terminal.info('  --sort <field>       Sort branches by field');
  Terminal.info(
    '                       (local-date, gerrit-date, status, divergences, '
    'name)',
  );
  Terminal.info('  --asc                Sort in ascending order (default)');
  Terminal.info('  --desc               Sort in descending order');
  Terminal.info(
    '  --no-sort            Disable sorting (shows unsorted output)',
  );
  Terminal.info('');
  Terminal.info('Examples:');
  Terminal.info('  dgt list                             # List branches');
  Terminal.info(
    '  dgt list --status active             # Show only Active branches',
  );
  Terminal.info(
    '  dgt list --sort local-date --desc    # Sort by date, newest first',
  );
  Terminal.info(
    '  dgt list --path D:\\repo              # List branches in specific repo',
  );
  Terminal.info('');
  Terminal.info('For more information, use: dgt --help');
}

/// Prints help text specifically for the config command.
void printConfigCommandHelp() {
  Terminal.info('Usage: dgt config [options|subcommand]');
  Terminal.info('');
  Terminal.info('Set default configuration options in ~/.dgt/.config');
  Terminal.info('');
  Terminal.info('Subcommands:');
  Terminal.info('  show             Display current configuration');
  Terminal.info('  clean            Reset configuration to defaults');
  Terminal.info('');
  Terminal.info('Options:');
  Terminal.info('  -h, --help       Print this help information.');
  Terminal.info(
    '  -f, --force      Force operation without confirmation (for config '
    'clean)',
  );
  Terminal.info('');
  Terminal.info('Display options:');
  Terminal.info(
    '  --[no-]gerrit    Set default for displaying Gerrit hash and date '
    'columns',
  );
  Terminal.info(
    '  --[no-]local     Set default for displaying local hash and date columns',
  );
  Terminal.info('  --[no-]url       Set default for showing Gerrit URL column');
  Terminal.info('');
  Terminal.info('Filter options:');
  Terminal.info('  --status <status>    Set default status filters');
  Terminal.info(
    '                       (wip, active, merged, abandoned, conflict, gerrit, '
    'local)',
  );
  Terminal.info(
    '  --no-status          Remove status filters from configuration',
  );
  Terminal.info(
    '  --since <date>       Set default for filtering commits after this date',
  );
  Terminal.info(
    '  --before <date>      Set default for filtering commits before this date',
  );
  Terminal.info('  --[no-]diverged      Set default for diverged filter');
  Terminal.info('');
  Terminal.info('Sort options:');
  Terminal.info('  --sort <field>       Set default sort field');
  Terminal.info(
    '                       (local-date, gerrit-date, status, divergences, '
    'name)',
  );
  Terminal.info('  --asc                Set default to ascending order');
  Terminal.info('  --desc               Set default to descending order');
  Terminal.info('  --no-sort            Remove sort from configuration');
  Terminal.info('');
  Terminal.info('Note for subcommands:');
  Terminal.info(
    '  The `config clean` subcommand accepts the same display/filter/sort '
    'options as the `list` command but only the affirmative forms. '
    'Negative/`--no-` forms are not accepted by `config clean`.',
  );
  Terminal.info('');
  Terminal.info('Examples (config subcommands):');
  Terminal.info(
    '  dgt config clean --sort local-date   # Allowed (affirmative only)',
  );
  Terminal.info(
    '  dgt config clean --no-sort          # Not allowed (rejected)',
  );
  Terminal.info('');
  Terminal.info('Examples:');
  Terminal.info(
    '  dgt config show                      # Display current config',
  );
  Terminal.info('  dgt config clean                     # Reset to defaults');
  Terminal.info(
    '  dgt config --no-gerrit               # Hide Gerrit columns by default',
  );
  Terminal.info(
    '  dgt config --status active --diverged    # Set default filters',
  );
  Terminal.info('  dgt config --sort local-date --desc  # Set default sort');
  Terminal.info(
    '  dgt config --no-status               # Remove status filters',
  );
  Terminal.info('');
  Terminal.info('For more information, use: dgt --help');
}

/// Prints help specifically for `dgt config show`.
void printConfigShowHelp() {
  Terminal.info('Usage: dgt config show');
  Terminal.info('');
  Terminal.info('Display the current configuration stored in ~/.dgt/.config');
  Terminal.info('');
  Terminal.info('Options:');
  Terminal.info('  -h, --help    Print this help information.');
  Terminal.info('');
  Terminal.info('Examples:');
  Terminal.info('  dgt config show        # Display current configuration');
  Terminal.info(
    '  dgt -v config show     # Verbose display of current configuration',
  );
  Terminal.info('');
}

/// Prints help specifically for `dgt config clean`.
void printConfigCleanHelp() {
  Terminal.info('Usage: dgt config clean [options]');
  Terminal.info('');
  Terminal.info('Reset configuration to defaults or remove specific defaults.');
  Terminal.info('');
  Terminal.info(
    'This subcommand accepts the same display/filter/sort options as ',
  );
  Terminal.info(
    'the `list` command but only the affirmative forms (no `--no-` forms).',
  );
  Terminal.info('');
  Terminal.info('Options:');
  Terminal.info('  -h, --help    Print this help information.');
  Terminal.info('  -f, --force   Force operation without confirmation.');
  Terminal.info('');
  Terminal.info('Examples:');
  Terminal.info(
    '  dgt config clean                     # Reset entire config to defaults',
  );
  Terminal.info('');
  Terminal.info('  Removing specific options:');
  Terminal.info(
    '  dgt config clean --local             # Remove only the --local setting',
  );
  Terminal.info(
    '  dgt config clean --gerrit            # Remove only the --gerrit setting',
  );
  Terminal.info(
    '  dgt config clean --url               # Remove only the --url setting',
  );
  Terminal.info(
    '  dgt config clean --diverged          # Remove only the --diverged '
    'filter',
  );
  Terminal.info('');
  Terminal.info('  Sort removal:');
  Terminal.info(
    '  dgt config clean --sort              # Remove entire sort configuration',
  );
  Terminal.info(
    '  dgt config clean --sort local-date   # Remove sort ONLY if field is '
    '"local-date"',
  );
  Terminal.info(
    '  dgt config clean --sort status       # Remove sort ONLY if field is '
    '"status"',
  );
  Terminal.info(
    '                                       # (conditional removal)',
  );
  Terminal.info('');
  Terminal.info('  Status removal:');
  Terminal.info(
    '  dgt config clean --status active     # Remove "active" from status list',
  );
  Terminal.info(
    '  dgt config clean --status merged     # Remove "merged" from status list',
  );
  Terminal.info('  dgt config clean --status active --status merged');
  Terminal.info(
    '                                       # Remove both from status list',
  );
  Terminal.info(
    '                                       # (if list becomes empty, removes '
    'entire filter)',
  );
  Terminal.info('');
  Terminal.info('  Multiple removals:');
  Terminal.info('  dgt config clean --local --gerrit --sort');
  Terminal.info(
    '                                       # Remove multiple settings at once',
  );
  Terminal.info('');
  Terminal.info('  Not allowed (negative forms):');
  Terminal.info(
    '  dgt config clean --no-sort           # ERROR: --no- forms not accepted',
  );
  Terminal.info(
    '  dgt config clean --no-local          # ERROR: --no- forms not accepted',
  );
  Terminal.info('');
}

/// Prints help text specifically for the clean command.
void printCleanHelp() {
  Terminal.info('Usage: dgt clean [git-cl-archive-options]');
  Terminal.info('');
  Terminal.info(
    'Archive merged branches by wrapping the "git cl archive" command.',
  );
  Terminal.info('');
  Terminal.info(
    'This command passes all arguments directly to "git cl archive".',
  );
  Terminal.info('');
  Terminal.info('Options:');
  Terminal.info('  -h, --help    Print this help information.');
  Terminal.info('');
  Terminal.info('Note:');
  Terminal.info(
    '  To use dgt wrapper features (verbose, timing), place flags before '
    'clean:',
  );
  Terminal.info('    dgt -v -t clean       # dgt tracks verbose and timing');
  Terminal.info('    dgt clean -v          # -v is passed to git cl archive');
  Terminal.info('');
  Terminal.info('Examples:');
  Terminal.info('  dgt clean                # Archive merged branches');
  Terminal.info(
    '  dgt clean -f             # Force archive without confirmation',
  );
  Terminal.info(
    '  dgt -v -t clean          # Archive with verbose output and timing',
  );
  Terminal.info('');
  Terminal.info('For git cl archive help:');
  Terminal.info('  dgt clean --help         # Passes --help to git cl archive');
  Terminal.info('');
  Terminal.info('For more information about dgt, use: dgt --help');
}

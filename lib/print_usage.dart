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
  Terminal.info('');

  // List command options
  Terminal.info('List command options:');
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
  Terminal.info(
    '      --no-diverged        Ignore diverged filter (overrides config)',
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
  Terminal.info('  • Cannot use --diverged with --no-diverged');
  Terminal.info('  • Cannot use --sort with --no-sort');
  Terminal.info('  • Cannot use --asc with --desc');
  Terminal.info('  • Config command requires at least one flag');
  Terminal.info('  • If no command is specified, "list" is assumed');
}

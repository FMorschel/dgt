import 'package:args/args.dart';
import 'terminal.dart';

void printUsage(ArgParser argParser) {
  Terminal.info('Usage: dgt [command] [options]');
  Terminal.info('');
  Terminal.info(
    'A tool to list local Git branches with their Gerrit review status.',
  );
  Terminal.info('');
  Terminal.info('Commands:');
  Terminal.info(
    '  list         List all local branches with Gerrit status (default)',
  );
  Terminal.info(
    '  config       Set default configuration options in ~/.dgt/.config',
  );
  Terminal.info('  config show  Display current configuration');
  Terminal.info('  config clean Reset configuration to defaults');
  Terminal.info('');
  Terminal.info('Options:');
  Terminal.info(argParser.usage);
  Terminal.info('');
  Terminal.info('Examples:');
  Terminal.info(
    '  dgt                                    # List branches in current '
    'directory',
  );
  Terminal.info(
    '  dgt --verbose                          # List with verbose output',
  );
  Terminal.info(
    '  dgt --path D:\\repo                     # List branches in specific '
    'repository',
  );
  Terminal.info('  dgt -v -p /path/to/repo                # Combined options');
  Terminal.info(
    '  dgt --no-gerrit                        # Hide Gerrit hash and date '
    'columns',
  );
  Terminal.info(
    '  dgt --no-local                         # Hide local hash and date '
    'columns',
  );
  Terminal.info(
    '  dgt --timing                           # Display performance timing '
    'summary',
  );
  Terminal.info(
    '  dgt -v -t                              # Verbose output with timing',
  );
  Terminal.info('');
  Terminal.info('Filtering examples:');
  Terminal.info(
    '  dgt --status active                    # Show only Active branches',
  );
  Terminal.info(
    '  dgt --status wip --status active       # Show WIP and Active branches',
  );
  Terminal.info(
    '  dgt --status all                       # Show all Gerrit statuses',
  );
  Terminal.info(
    '  dgt --status local                     # Show only local branches '
    '(no Gerrit)',
  );
  Terminal.info(
    '  dgt --status local --status active     # Show local and Active branches',
  );
  Terminal.info(
    '  dgt --since 2025-10-01                 # Show branches with commits '
    'after this date',
  );
  Terminal.info(
    '  dgt --before 2025-10-10                # Show branches with commits '
    'before this date',
  );
  Terminal.info(
    '  dgt --diverged                         # Show only diverged branches',
  );
  Terminal.info(
    '  dgt --status active --diverged         # Show Active branches that '
    'have diverged',
  );
  Terminal.info(
    '  dgt --no-status                        # Ignore config status filters '
    '(show all branches)',
  );
  Terminal.info(
    '  dgt --no-diverged                      # Ignore config diverged filter',
  );
  Terminal.info('');
  Terminal.info(
    'Note: Cannot use --status with --no-status, --diverged with '
    '--no-diverged,',
  );
  Terminal.info('      or --sort with --no-sort.');
  Terminal.info('');
  Terminal.info('Sorting examples (default: name, ascending):');
  Terminal.info(
    '  dgt --sort local-date --desc           # Sort by local date, newest '
    'first',
  );
  Terminal.info(
    '  dgt --sort status                      # Sort by status (ascending)',
  );
  Terminal.info(
    '  dgt --sort divergences --desc          # Sort by divergences, most '
    'diverged first',
  );
  Terminal.info(
    '  dgt --sort name --asc                  # Sort by branch name '
    'alphabetically',
  );
  Terminal.info(
    '  dgt --status active --sort local-date  # Combine filtering and sorting',
  );
  Terminal.info(
    '  dgt --no-sort                          # Disable default sort (show '
    'unsorted)',
  );
  Terminal.info('');
  Terminal.info('Available sort fields (default: name):');
  Terminal.info('  local-date    - Local commit date');
  Terminal.info('  gerrit-date   - Gerrit update date');
  Terminal.info('  status        - Gerrit status');
  Terminal.info('  divergences   - Divergence state');
  Terminal.info('  name          - Branch name (default)');
  Terminal.info('');
  Terminal.info('Available status values:');
  Terminal.info('  wip       - Work in Progress');
  Terminal.info('  active    - Ready for review');
  Terminal.info('  merged    - Successfully merged');
  Terminal.info('  abandoned - Abandoned changes');
  Terminal.info('  conflict  - Has merge conflicts');
  Terminal.info('  all       - All Gerrit statuses');
  Terminal.info('  local     - Branches without Gerrit configuration');
  Terminal.info('');
  Terminal.info('Config command examples:');
  Terminal.info(
    '  dgt config show                        # Display current configuration',
  );
  Terminal.info(
    '  dgt config clean                       # Reset config to defaults',
  );
  Terminal.info(
    '  dgt config --no-gerrit                 # Set default to hide Gerrit '
    'columns',
  );
  Terminal.info(
    '  dgt config --no-local                  # Set default to hide local '
    'columns',
  );
  Terminal.info(
    '  dgt config --gerrit --local            # Set default to show both '
    'columns',
  );
  Terminal.info(
    '  dgt config --no-gerrit --no-local      # Set default to hide both '
    'columns',
  );
  Terminal.info(
    '  dgt config --status active --diverged  # Set default filters',
  );
  Terminal.info(
    '  dgt config --no-status                 # Remove status filters from '
    'config',
  );
  Terminal.info(
    '  dgt config --no-diverged               # Remove diverged filter from '
    'config',
  );
  Terminal.info(
    '  dgt config --no-sort                   # Remove sort configuration from '
    'config',
  );
  Terminal.info('');
  Terminal.info(
    'Note: Use --no-status, --no-diverged, and --no-sort flags with list '
    'command to',
  );
  Terminal.info(
    '      temporarily override config, or with config command to permanently '
    'remove them.',
  );
  Terminal.info(
    '  dgt config --sort local-date --desc    # Set default sort options',
  );
  Terminal.info(
    '  dgt config --sort name                 # Set default sort by name',
  );
  Terminal.info('');
  Terminal.info(
    'Note: The config command requires at least one flag to be set.',
  );
}

import 'terminal.dart';

/// Prints help text for the config command when no flags are provided.
void printConfigHelp() {
  Terminal.error(
    'Error: You must specify at least one flag for the config command.',
  );
  Terminal.info('');
  Terminal.info('Subcommands:');
  Terminal.info('  dgt config show   # Display current configuration');
  Terminal.info('  dgt config clean  # Reset configuration to defaults');
  Terminal.info('');
  Terminal.info('Display options:');
  Terminal.info('  dgt config --no-gerrit --local');
  Terminal.info('');
  Terminal.info('Filter options:');
  Terminal.info('  dgt config --status active --diverged');
  Terminal.info('  dgt config --since 2025-10-01');
  Terminal.info('  dgt config --no-status        # Remove all status filters');
  Terminal.info('  dgt config --no-diverged      # Remove diverged filter');
  Terminal.info('');
  Terminal.info('Sort options:');
  Terminal.info('  dgt config --sort local-date --desc');
  Terminal.info('  dgt config --no-sort          # Remove sort configuration');
  Terminal.info('');
  Terminal.info(
    'Use --gerrit/--no-gerrit, --local/--no-local, --url/--no-url, '
    '--status, --since, --before, --diverged, --sort, --asc, --desc to '
    'set defaults.',
  );
}

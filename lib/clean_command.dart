import 'dart:io';

import 'performance_tracker.dart';
import 'terminal.dart';
import 'verbose_output.dart';

/// Handles the clean command which wraps 'git cl archive'
///
/// This command passes all arguments to 'git cl archive' while optionally
/// providing verbose output and performance tracking.
Future<void> runCleanCommand(
  List<String> arguments, {
  PerformanceTracker? tracker,
}) async {
  tracker?.startTimer('clean_command');

  VerboseOutput.instance.info('[VERBOSE] Running git cl archive command');
  VerboseOutput.instance.info('[VERBOSE] Arguments: ${arguments.join(' ')}');

  try {
    // Build the command to run
    final command = 'git';
    final args = ['cl', 'archive', ...arguments];

    VerboseOutput.instance.info(
      '[VERBOSE] Executing: $command ${args.join(' ')}',
    );

    // Run the git cl archive command
    final result = await Process.run(command, args, runInShell: true);

    // Display the output from git cl archive
    if (result.stdout.toString().isNotEmpty) {
      Terminal.info(result.stdout.toString().trim());
    }

    // Display any errors
    if (result.stderr.toString().isNotEmpty) {
      Terminal.error(result.stderr.toString().trim());
    }

    // Check exit code
    if (result.exitCode != 0) {
      VerboseOutput.instance.warning(
        '[VERBOSE] Command exited with code: ${result.exitCode}',
      );
      tracker?.endTimer('clean_command');
      exit(result.exitCode);
    }

    VerboseOutput.instance.info('[VERBOSE] Command completed successfully');
  } catch (e) {
    Terminal.error('Error running git cl archive: $e');
    tracker?.endTimer('clean_command');
    exit(1);
  }

  tracker?.endTimer('clean_command');
}

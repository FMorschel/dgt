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

    // Start the git cl archive command with interactive mode
    final process = await Process.start(
      command,
      args,
      mode: ProcessStartMode.inheritStdio,
    );

    // Wait for the process to complete
    final exitCode = await process.exitCode;

    // Check exit code
    if (exitCode != 0) {
      VerboseOutput.instance.warning(
        '[VERBOSE] Command exited with code: $exitCode',
      );
      tracker?.endTimer('clean_command');
      exit(exitCode);
    }

    VerboseOutput.instance.info('[VERBOSE] Command completed successfully');
  } catch (e) {
    Terminal.error('Error running git cl archive: $e');
    tracker?.endTimer('clean_command');
    exit(1);
  }

  tracker?.endTimer('clean_command');
}

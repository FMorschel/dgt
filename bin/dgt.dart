import 'dart:io';

import 'package:args/args.dart';
import 'package:dgt/branch_info.dart';
import 'package:dgt/config_command.dart';
import 'package:dgt/config_service.dart';
import 'package:dgt/gerrit_service.dart';
import 'package:dgt/git_service.dart';
import 'package:dgt/git_service_batch.dart';
import 'package:dgt/output_formatter.dart';
import 'package:dgt/performance_tracker.dart';
import 'package:dgt/terminal.dart';

const String version = '0.0.1';

ArgParser buildParser() {
  return ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show additional command output.',
    )
    ..addFlag('version', negatable: false, help: 'Print the tool version.')
    ..addFlag(
      'timing',
      abbr: 't',
      negatable: false,
      help: 'Display performance timing summary.',
    )
    ..addOption(
      'path',
      abbr: 'p',
      help: 'Path to the Git repository to analyze.',
      valueHelp: 'path',
    )
    ..addFlag(
      'gerrit',
      defaultsTo: true,
      negatable: true,
      help: 'Display Gerrit hash and date columns.',
    )
    ..addFlag(
      'local',
      defaultsTo: true,
      negatable: true,
      help: 'Display local hash and date columns.',
    );
}

void printUsage(ArgParser argParser) {
  Terminal.info('Usage: dgt [command] [options]');
  Terminal.info('');
  Terminal.info(
    'A tool to list local Git branches with their Gerrit review status.',
  );
  Terminal.info('');
  Terminal.info('Commands:');
  Terminal.info(
    '  list      List all local branches with Gerrit status (default)',
  );
  Terminal.info(
    '  config    Set default configuration options in ~/.dgt/.config',
  );
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
  Terminal.info('Config command examples:');
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
  Terminal.info('');
  Terminal.info(
    'Note: The config command requires at least one --local or --gerrit flag.',
  );
}

Future<void> runListCommand(
  bool verbose,
  String? repositoryPath,
  bool showGerrit,
  bool showLocal,
  bool showTiming,
) async {
  // Initialize performance tracker if timing is requested
  PerformanceTracker? tracker;
  if (showTiming) {
    tracker = PerformanceTracker();
  }

  try {
    // Change to the specified repository path if provided
    if (repositoryPath != null) {
      if (verbose) {
        Terminal.info('[VERBOSE] Changing directory to: $repositoryPath');
      }
      try {
        Directory.current = repositoryPath;
      } catch (e) {
        Terminal.error('Error: Could not change to directory: $repositoryPath');
        Terminal.error('Details: $e');
        return;
      }
    }

    // Check if we're in a Git repository
    if (!await GitService.isGitRepository()) {
      Terminal.error('Error: Not a Git repository');
      Terminal.info('Please run this command from within a Git repository.');
      return;
    }

    if (verbose) {
      Terminal.info('[VERBOSE] Fetching local branches...');
    }

    // Get all local branches
    tracker?.startTimer('branch_discovery');
    final branches = await GitService.getAllBranches();
    tracker?.endTimer('branch_discovery');

    if (branches.isEmpty) {
      Terminal.info('No branches found in this repository.');
      return;
    }

    if (verbose) {
      Terminal.info('[VERBOSE] Found ${branches.length} branch(es)');
    }

    // Collect branch information
    final branchInfoList = <BranchInfo>[];

    // Batch fetch all Git information at once to minimize git process spawns
    // This uses git for-each-ref and git config --get-regexp to get data for
    // all branches in just 2 git commands instead of 2*N commands.
    if (verbose) {
      Terminal.info('[VERBOSE] Batch fetching Git information for all branches...');
    }

    tracker?.startTimer('git_operations');
    
    // Fetch commit info and Gerrit config for all branches in parallel
    final results = await Future.wait([
      GitServiceBatch.getBatchCommitInfo(branches),
      GitServiceBatch.getBatchGerritConfig(branches),
    ]);
    
    final commitInfoMap = results[0] as Map<String, ({String hash, String date})>;
    final gerritConfigMap = results[1] as Map<String, GerritBranchConfig>;
    
    // Build branch data list
    final branchDataList = <({
      String branch,
      String localHash,
      String localDate,
      GerritBranchConfig gerritConfig,
      Object? error,
    })>[];
    
    for (final branch in branches) {
      final commitInfo = commitInfoMap[branch];
      final gerritConfig = gerritConfigMap[branch] ?? GerritBranchConfig();
      
      if (commitInfo != null) {
        if (verbose) {
          Terminal.info('[VERBOSE] Processing branch: $branch');
        }
        
        branchDataList.add((
          branch: branch,
          localHash: commitInfo.hash,
          localDate: commitInfo.date,
          gerritConfig: gerritConfig,
          error: null,
        ));
      } else {
        if (verbose) {
          Terminal.warning('[VERBOSE] Failed to get commit info for branch $branch');
        }
        branchDataList.add((
          branch: branch,
          localHash: '',
          localDate: '',
          gerritConfig: gerritConfig,
          error: 'Missing commit info',
        ));
      }
    }
    
    tracker?.endTimer('git_operations');

    // Build issue number mapping
    final issueNumbersToBranches = <String, List<String>>{};
    for (var branchData in branchDataList) {
      // Skip branches that had errors
      if (branchData.error != null) {
        continue;
      }

      // Collect issue numbers for batch query
      if (branchData.gerritConfig.hasGerritConfig &&
          branchData.gerritConfig.gerritIssue != null) {
        if (verbose) {
          Terminal.info('[VERBOSE] Branch ${branchData.branch}:');
          Terminal.info(
            '[VERBOSE]   Gerrit Issue: ${branchData.gerritConfig.gerritIssue}',
          );
          Terminal.info(
            '[VERBOSE]   Gerrit Server: '
            '${branchData.gerritConfig.gerritServer}',
          );
        }

        final issue = branchData.gerritConfig.gerritIssue!;
        issueNumbersToBranches
            .putIfAbsent(issue, () => <String>[])
            .add(branchData.branch);
      } else if (verbose) {
        Terminal.info('[VERBOSE] Branch ${branchData.branch}:');
        Terminal.info(
          '[VERBOSE]   No Gerrit configuration found for this branch',
        );
      }
    }

    // Second pass: batch query Gerrit for all issues at once
    // Instead of making N individual API calls for N branches, we batch them
    // into groups of up to 10 (Gerrit API limitation) and execute each batch
    // in a separate isolate for maximum parallelism and performance.
    // This reduces API round-trips and total execution time significantly.
    var gerritChanges = <String, GerritChange?>{};
    if (issueNumbersToBranches.isNotEmpty) {
      if (verbose) {
        Terminal.info(
          '[VERBOSE] Batch querying Gerrit for '
          '${issueNumbersToBranches.length} issue(s)...',
        );
      }

      try {
        tracker?.startTimer('gerrit_queries');
        final issueNumbers = issueNumbersToBranches.keys.toList();
        gerritChanges = await GerritService.getBatchChangesByIssueNumbers(
          issueNumbers,
        );
        tracker?.endTimer('gerrit_queries');

        if (verbose) {
          final foundCount = gerritChanges.values
              .where((GerritChange? c) => c != null)
              .length;
          Terminal.info(
            '[VERBOSE] Batch query completed: $foundCount/'
            '${issueNumbers.length} changes found',
          );
        }
      } catch (e) {
        tracker?.endTimer('gerrit_queries');
        if (verbose) {
          Terminal.warning('[VERBOSE] Batch Gerrit query failed: $e');
        }
        // Continue with empty results (partial success)
      }
    }

    // Third pass: create BranchInfo objects with Gerrit data
    tracker?.startTimer('result_processing');
    for (var branchData in branchDataList) {
      // Skip branches that had errors during Git operations
      if (branchData.error != null) {
        continue;
      }

      // Find the Gerrit change for this branch
      GerritChange? gerritChange;
      if (branchData.gerritConfig.hasGerritConfig &&
          branchData.gerritConfig.gerritIssue != null) {
        gerritChange = gerritChanges[branchData.gerritConfig.gerritIssue!];

        if (verbose && gerritChange != null) {
          Terminal.info(
            '[VERBOSE] Branch ${branchData.branch}: Gerrit status = '
            '${gerritChange.getUserFriendlyStatus()}',
          );
        }
      }

      // Create BranchInfo object
      final branchInfo = BranchInfo(
        branchName: branchData.branch,
        localHash: branchData.localHash,
        localDate: branchData.localDate,
        gerritConfig: branchData.gerritConfig,
        gerritChange: gerritChange,
      );

      branchInfoList.add(branchInfo);
    }
    tracker?.endTimer('result_processing');

    // Display results in a formatted table
    Terminal.info('');
    OutputFormatter.displayBranchTable(
      branchInfoList,
      verbose: verbose,
      showGerrit: showGerrit,
      showLocal: showLocal,
    );

    // Display performance summary if timing was requested
    if (showTiming && tracker != null) {
      OutputFormatter.displayPerformanceSummary(tracker);
    }
  } catch (e) {
    Terminal.error('Error: $e');
    if (verbose) {
      Terminal.error('Stack trace: ${StackTrace.current}');
    }
  }
}

Future<void> main(List<String> arguments) async {
  final argParser = buildParser();
  try {
    final results = argParser.parse(arguments);

    // Process the parsed arguments.
    if (results.flag('help')) {
      printUsage(argParser);
      return;
    }

    if (results.flag('version')) {
      Terminal.info('dgt version: $version');
      return;
    }

    final verbose = results.flag('verbose');
    final showTiming = results.flag('timing');

    // Get the repository path if specified
    final repositoryPath = results.option('path');

    // Load config from ~/.dgt/.config
    final config = await ConfigService.readConfig(verbose: verbose);

    // Determine display options with priority:
    // 1. Command-line flags (if explicitly set)
    // 2. Config file settings (if available)
    // 3. Default values (true for both)
    bool showGerrit;
    bool showLocal;

    // Check if flags were explicitly provided by the user
    final gerritWasParsed = results.wasParsed('gerrit');
    final localWasParsed = results.wasParsed('local');

    if (gerritWasParsed) {
      // Command-line flag takes priority
      showGerrit = results.flag('gerrit');
    } else if (config?.showGerrit != null) {
      // Config file overrides default
      showGerrit = config!.showGerrit!;
    } else {
      // Use default value
      showGerrit = true;
    }

    if (localWasParsed) {
      // Command-line flag takes priority
      showLocal = results.flag('local');
    } else if (config?.showLocal != null) {
      // Config file overrides default
      showLocal = config!.showLocal!;
    } else {
      // Use default value
      showLocal = true;
    }

    if (verbose && config != null) {
      Terminal.info('[VERBOSE] Using config file settings:');
      if (config.showLocal != null) {
        Terminal.info('[VERBOSE]   local: ${config.showLocal}');
      }
      if (config.showGerrit != null) {
        Terminal.info('[VERBOSE]   gerrit: ${config.showGerrit}');
      }
    }

    // Determine which command to run
    final command = results.rest.isNotEmpty ? results.rest.first : 'list';

    // Execute the appropriate command
    switch (command) {
      case 'list':
        await runListCommand(
          verbose,
          repositoryPath,
          showGerrit,
          showLocal,
          showTiming,
        );
      case 'config':
        // For the config command, user must explicitly provide flags
        if (!results.wasParsed('gerrit') && !results.wasParsed('local')) {
          Terminal.error(
            'Error: You must specify at least one flag for the config command.',
          );
          Terminal.info('');
          Terminal.info('Example: dgt config --no-gerrit --local');
          Terminal.info(
            'Use --gerrit/--no-gerrit and/or --local/--no-local to set defaults.',
          );
          return;
        }

        // Only save values that were explicitly provided
        final configShowGerrit = results.wasParsed('gerrit')
            ? results.flag('gerrit')
            : null;
        final configShowLocal = results.wasParsed('local')
            ? results.flag('local')
            : null;
        await runConfigCommand(verbose, configShowGerrit, configShowLocal);
      default:
        Terminal.error('Unknown command: $command');
        Terminal.info('');
        printUsage(argParser);
    }
  } on FormatException catch (e) {
    // Print usage information if an invalid argument was provided.
    Terminal.error(e.message);
    Terminal.info('');
    printUsage(argParser);
  }
}

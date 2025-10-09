import 'dart:io';

import 'package:args/args.dart';
import 'package:dgt/branch_info.dart';
import 'package:dgt/gerrit_service.dart';
import 'package:dgt/git_service.dart';
import 'package:dgt/output_formatter.dart';
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
    ..addOption(
      'path',
      abbr: 'p',
      help: 'Path to the Git repository to analyze.',
      valueHelp: 'path',
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
    '  list    List all local branches with Gerrit status (default)',
  );
  Terminal.info('');
  Terminal.info('Options:');
  Terminal.info(argParser.usage);
  Terminal.info('');
  Terminal.info('Examples:');
  Terminal.info(
    '  dgt                                    # List branches in current directory',
  );
  Terminal.info(
    '  dgt --verbose                          # List with verbose output',
  );
  Terminal.info(
    '  dgt --path D:\\repo                     # List branches in specific repository',
  );
  Terminal.info('  dgt -v -p /path/to/repo                # Combined options');
}

Future<void> runListCommand(bool verbose, String? repositoryPath) async {
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
    final branches = await GitService.getAllBranches();

    if (branches.isEmpty) {
      Terminal.info('No branches found in this repository.');
      return;
    }

    if (verbose) {
      Terminal.info('[VERBOSE] Found ${branches.length} branch(es)');
    }

    // Collect branch information
    final branchInfoList = <BranchInfo>[];

    // First pass: collect all branch info in parallel using Future.wait
    // This significantly improves performance by running Git commands concurrently
    // rather than sequentially. For a repo with N branches, this reduces execution
    // time from N*T to approximately T (where T is the time for one Git operation).
    if (verbose) {
      Terminal.info(
        '[VERBOSE] Fetching Git information for all branches in parallel...',
      );
    }

    final branchFutures = branches.map((String branch) async {
      if (verbose) {
        Terminal.info('[VERBOSE] Processing branch: $branch');
      }

      try {
        // Fetch all Git information for this branch in parallel
        final results = await Future.wait(<Future<Object>>[
          GitService.getCommitHash(branch),
          GitService.getCommitDate(branch),
          GitService.getGerritConfig(branch),
        ]);

        final localHash = results[0] as String;
        final localDate = results[1] as String;
        final gerritConfig = results[2] as GerritBranchConfig;

        return (
          branch: branch,
          localHash: localHash,
          localDate: localDate,
          gerritConfig: gerritConfig,
          error: null,
        );
      } catch (e) {
        if (verbose) {
          Terminal.warning('[VERBOSE] Failed to process branch $branch: $e');
        }
        // Return error marker to handle gracefully
        return (
          branch: branch,
          localHash: '',
          localDate: '',
          gerritConfig: GerritBranchConfig(),
          error: e,
        );
      }
    });

    // Wait for all branch data to be collected
    final branchDataList = await Future.wait(branchFutures);

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
            '[VERBOSE]   Gerrit Server: ${branchData.gerritConfig.gerritServer}',
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
          '[VERBOSE] Batch querying Gerrit for ${issueNumbersToBranches.length} issue(s)...',
        );
      }

      try {
        final issueNumbers = issueNumbersToBranches.keys.toList();
        gerritChanges = await GerritService.getBatchChangesByIssueNumbers(
          issueNumbers,
        );

        if (verbose) {
          final foundCount = gerritChanges.values
              .where((GerritChange? c) => c != null)
              .length;
          Terminal.info(
            '[VERBOSE] Batch query completed: $foundCount/${issueNumbers.length} changes found',
          );
        }
      } catch (e) {
        if (verbose) {
          Terminal.warning('[VERBOSE] Batch Gerrit query failed: $e');
        }
        // Continue with empty results (partial success)
      }
    }

    // Third pass: create BranchInfo objects with Gerrit data
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
            '[VERBOSE] Branch ${branchData.branch}: Gerrit status = ${gerritChange.getUserFriendlyStatus()}',
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

    // Display results in a formatted table
    Terminal.info('');
    OutputFormatter.displayBranchTable(branchInfoList, verbose: verbose);
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

    // Get the repository path if specified
    final repositoryPath = results.option('path');

    // Determine which command to run
    final command = results.rest.isNotEmpty ? results.rest.first : 'list';

    // Execute the appropriate command
    switch (command) {
      case 'list':
        await runListCommand(verbose, repositoryPath);
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

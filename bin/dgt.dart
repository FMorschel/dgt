import 'dart:io';

import 'package:args/args.dart';
import 'package:dgt/branch_info.dart';
import 'package:dgt/config_command.dart';
import 'package:dgt/config_service.dart';
import 'package:dgt/display_options.dart';
import 'package:dgt/filtering.dart';
import 'package:dgt/gerrit_service.dart';
import 'package:dgt/git_service.dart';
import 'package:dgt/git_service_batch.dart';
import 'package:dgt/output_formatter.dart';
import 'package:dgt/performance_tracker.dart';
import 'package:dgt/print_usage.dart';
import 'package:dgt/sorting.dart';
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
    )
    ..addMultiOption(
      'status',
      help:
          'Filter branches by Gerrit status. '
          'Allowed: wip, active, merged, abandoned, conflict, all, local',
      allowed: [
        'wip',
        'active',
        'merged',
        'abandoned',
        'conflict',
        'all',
        'local',
      ],
      valueHelp: 'status',
    )
    ..addOption(
      'since',
      help: 'Filter branches with commits after this date (ISO 8601 format).',
      valueHelp: 'date',
    )
    ..addOption(
      'before',
      help: 'Filter branches with commits before this date (ISO 8601 format).',
      valueHelp: 'date',
    )
    ..addFlag(
      'diverged',
      negatable: true,
      help: 'Filter to show only branches with local or remote differences.',
    )
    ..addFlag(
      'no-status',
      negatable: false,
      help:
          'Ignore status filters (overrides config; cannot use with --status).',
    )
    ..addFlag(
      'no-diverged',
      negatable: false,
      help:
          'Ignore diverged filter (overrides config; cannot use with '
          '--diverged).',
    )
    ..addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Force operation without confirmation (for config clean).',
    )
    ..addFlag(
      'url',
      negatable: true,
      defaultsTo: false,
      help: 'Show Gerrit URL column in the output.',
    )
    ..addOption(
      'sort',
      help:
          'Sort branches by field. '
          'Allowed: local-date, gerrit-date, status, divergences, name',
      allowed: ['local-date', 'gerrit-date', 'status', 'divergences', 'name'],
      valueHelp: 'field',
    )
    ..addFlag(
      'no-sort',
      negatable: false,
      help: 'Disable sorting (shows unsorted output; cannot use with --sort).',
    )
    ..addFlag(
      'asc',
      negatable: false,
      help: 'Sort in ascending order (default when --sort is used).',
    )
    ..addFlag('desc', negatable: false, help: 'Sort in descending order.');
}

Future<void> runListCommand(
  bool verbose,
  String? repositoryPath,
  DisplayOptions displayOptions,
  FilterOptions filters,
  SortOptions sortOptions,
) async {
  // Initialize performance tracker if timing is requested
  PerformanceTracker? tracker;
  if (displayOptions.showTiming) {
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
      final branchText = branches.length == 1 ? 'branch' : 'branches';
      Terminal.info('[VERBOSE] Found ${branches.length} $branchText');
    }

    // Collect branch information
    var branchInfoList = <BranchInfo>[];

    // Batch fetch all Git information at once to minimize git process spawns
    // This uses git for-each-ref and git config --get-regexp to get data for
    // all branches in just 2 git commands instead of 2*N commands.
    if (verbose) {
      Terminal.info(
        '[VERBOSE] Batch fetching Git information for all branches...',
      );
    }

    tracker?.startTimer('git_operations');

    // Fetch commit info and Gerrit config for all branches in parallel
    final results = await Future.wait([
      GitServiceBatch.getBatchCommitInfo(branches),
      GitServiceBatch.getBatchGerritConfig(branches),
    ]);

    final commitInfoMap =
        results[0] as Map<String, ({String hash, String date})>;
    final gerritConfigMap = results[1] as Map<String, GerritBranchConfig>;

    // Build branch data list
    final branchDataList =
        <
          ({
            String branch,
            String localHash,
            String localDate,
            GerritBranchConfig gerritConfig,
            Object? error,
          })
        >[];

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
          Terminal.warning(
            '[VERBOSE] Failed to get commit info for branch $branch',
          );
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
      // Build a Gerrit URL if possible
      String? changeUrl;
      if (branchData.gerritConfig.hasGerritConfig &&
          branchData.gerritConfig.gerritIssue != null) {
        changeUrl = GerritService.getChangeUrl(
          branchData.gerritConfig.gerritServer,
          branchData.gerritConfig.gerritIssue,
        );
      }

      final branchInfo = BranchInfo(
        branchName: branchData.branch,
        localHash: branchData.localHash,
        localDate: branchData.localDate,
        gerritConfig: branchData.gerritConfig,
        gerritChange: gerritChange,
        gerritUrl: changeUrl,
      );

      branchInfoList.add(branchInfo);
    }
    tracker?.endTimer('result_processing');

    // Apply filters
    if (!filters.isEmpty) {
      if (verbose) {
        Terminal.info('[VERBOSE] Applying filters...');
        Terminal.info(
          '[VERBOSE] Branches before filtering: ${branchInfoList.length}',
        );
      }

      tracker?.startTimer('filtering');
      branchInfoList = applyFilters(branchInfoList, filters);
      tracker?.endTimer('filtering');

      if (verbose) {
        Terminal.info(
          '[VERBOSE] Branches after filtering: ${branchInfoList.length}',
        );
      }
    }

    // Apply sorting
    if (!sortOptions.isEmpty) {
      if (verbose) {
        Terminal.info('[VERBOSE] Applying sorting...');
        Terminal.info(
          '[VERBOSE] Sort field: ${sortOptions.field}, '
          'direction: ${sortOptions.direction ?? "asc"}',
        );
      }

      tracker?.startTimer('sorting');
      branchInfoList = applySort(branchInfoList, sortOptions);
      tracker?.endTimer('sorting');
    }

    // Display results in a formatted table
    Terminal.info('');
    final formatter = OutputFormatter(displayOptions);
    formatter.displayBranchTable(
      branchInfoList,
      verbose: verbose,
      sortField: sortOptions.field,
      sortDirection: sortOptions.direction,
    );

    // Display performance summary if timing was requested
    if (displayOptions.showTiming && tracker != null) {
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

    // Get the repository path if specified
    final repositoryPath = results.option('path');

    // Load config from ~/.dgt/.config
    final config = await ConfigService.readConfig(verbose: verbose);

    if (verbose && config != null) {
      Terminal.info('[VERBOSE] Using config file settings:');
      if (config.showLocal != null) {
        Terminal.info('[VERBOSE]   local: ${config.showLocal}');
      }
      if (config.showGerrit != null) {
        Terminal.info('[VERBOSE]   gerrit: ${config.showGerrit}');
      }
      if (config.showUrl != null) {
        Terminal.info('[VERBOSE]   url: ${config.showUrl}');
      }
      if (config.filterStatuses != null && config.filterStatuses!.isNotEmpty) {
        Terminal.info('[VERBOSE]   filterStatuses: ${config.filterStatuses}');
      }
      if (config.filterSince != null) {
        Terminal.info('[VERBOSE]   filterSince: ${config.filterSince}');
      }
      if (config.filterBefore != null) {
        Terminal.info('[VERBOSE]   filterBefore: ${config.filterBefore}');
      }
      if (config.filterDiverged != null) {
        Terminal.info('[VERBOSE]   filterDiverged: ${config.filterDiverged}');
      }
      if (config.sortField != null) {
        Terminal.info('[VERBOSE]   sortField: ${config.sortField}');
      }
      if (config.sortDirection != null) {
        Terminal.info('[VERBOSE]   sortDirection: ${config.sortDirection}');
      }
    }

    // Validate that conflicting flags are not used together
    if (results.wasParsed('status') && results.wasParsed('no-status')) {
      Terminal.error(
        'Error: Cannot specify both --status and --no-status flags.',
      );
      Terminal.info(
        'Use --status to filter by status, or --no-status to show all '
        'branches.',
      );
      return;
    }

    if (results.wasParsed('diverged') && results.wasParsed('no-diverged')) {
      Terminal.error(
        'Error: Cannot specify both --diverged and --no-diverged flags.',
      );
      Terminal.info(
        'Use --diverged to filter, or --no-diverged to disable the filter.',
      );
      return;
    }

    if (results.wasParsed('sort') && results.wasParsed('no-sort')) {
      Terminal.error('Error: Cannot specify both --sort and --no-sort flags.');
      Terminal.info(
        'Use --sort to sort by a field, or --no-sort to disable sorting.',
      );
      return;
    }

    // Use centralized resolution helpers for filters and sort options
    // Handle --no-status flag to override config
    List<String> statusFilters;
    if (results.wasParsed('no-status') && results.flag('no-status')) {
      // User explicitly wants to ignore status filters
      statusFilters = [];
    } else {
      statusFilters = config.resolveMultiOption(results, 'status', []);
    }

    final sinceStr = config.resolveOption<String?>(results, 'since', null);
    final beforeStr = config.resolveOption<String?>(results, 'before', null);

    // Handle --no-diverged flag to override config
    bool divergedFilter;
    if (results.wasParsed('no-diverged') && results.flag('no-diverged')) {
      // User explicitly wants to ignore diverged filter
      divergedFilter = false;
    } else {
      divergedFilter = config.resolveFlag(results, 'diverged', false);
    }

    // Resolve sort options using centralized helpers
    // Handle --no-sort flag to override config
    String? sortField;
    String? sortDirection;

    if (results.wasParsed('no-sort') && results.flag('no-sort')) {
      // User explicitly wants to disable sorting
      sortField = null;
      sortDirection = null;
    } else {
      sortField = config.resolveOption(results, 'sort', 'name');

      // Handle sort direction using centralized helper
      sortDirection = config.resolveSortDirection(results, 'asc');
    }

    // Validate status filters (from CLI or config file)
    try {
      statusFilters.forEach(validateStatus);
    } catch (e) {
      Terminal.error('$e');
      Terminal.info('');
      Terminal.info('Run "dgt --help" to see available status values.');
      return;
    }

    // Validate sort field (from CLI or config file)
    try {
      if (sortField != null) {
        validateSortField(sortField);
      }
      if (sortDirection != null) {
        validateSortDirection(sortDirection);
      }
    } catch (e) {
      Terminal.error('Error: $e');
      return;
    }

    // Validate and parse dates
    DateTime? sinceDate;
    DateTime? beforeDate;

    try {
      sinceDate = parseDate(sinceStr);
      beforeDate = parseDate(beforeStr);
    } catch (e) {
      Terminal.error('Error: $e');
      return;
    }

    final filters = FilterOptions(
      statuses: statusFilters.isNotEmpty ? statusFilters : null,
      since: sinceDate,
      before: beforeDate,
      diverged: divergedFilter,
    );

    final sortOptions = SortOptions(field: sortField, direction: sortDirection);

    // Determine which command to run
    final command = results.rest.isNotEmpty ? results.rest.first : 'list';

    // Execute the appropriate command
    switch (command) {
      case 'list':
        // Create DisplayOptions instance using factory constructor
        // which resolves values from CLI flags, config file, and defaults
        final displayOptions = DisplayOptions.resolve(
          results: results,
          config: config,
        );

        await runListCommand(
          verbose,
          repositoryPath,
          displayOptions,
          filters,
          sortOptions,
        );
      case 'config':
        // Check for subcommands
        final subcommand = results.rest.length > 1 ? results.rest[1] : null;

        if (subcommand == 'show') {
          await runConfigShowCommand(verbose);
          return;
        }

        if (subcommand == 'clean') {
          final force = results.wasParsed('force') && results.flag('force');
          await runConfigCleanCommand(verbose, force);
          return;
        }

        // For the config command, user must explicitly provide at least one
        // flag or valid subcommand
        final hasDisplayFlags =
            results.wasParsed('gerrit') ||
            results.wasParsed('local') ||
            results.wasParsed('url');
        final hasFilterFlags =
            results.wasParsed('status') ||
            results.wasParsed('since') ||
            results.wasParsed('before') ||
            results.wasParsed('diverged') ||
            results.wasParsed('no-status') ||
            results.wasParsed('no-diverged');
        final hasSortFlags =
            results.wasParsed('sort') ||
            results.wasParsed('no-sort') ||
            results.wasParsed('asc') ||
            results.wasParsed('desc');

        if (!hasDisplayFlags && !hasFilterFlags && !hasSortFlags) {
          Terminal.error(
            'Error: You must specify at least one flag for the config command.',
          );
          Terminal.info('');
          Terminal.info('Subcommands:');
          Terminal.info('  dgt config show   # Display current configuration');
          Terminal.info(
            '  dgt config clean  # Reset configuration to defaults',
          );
          Terminal.info('');
          Terminal.info('Display options:');
          Terminal.info('  dgt config --no-gerrit --local');
          Terminal.info('');
          Terminal.info('Filter options:');
          Terminal.info('  dgt config --status active --diverged');
          Terminal.info('  dgt config --since 2025-10-01');
          Terminal.info(
            '  dgt config --no-status        # Remove all status filters',
          );
          Terminal.info(
            '  dgt config --no-diverged      # Remove diverged filter',
          );
          Terminal.info('');
          Terminal.info('Sort options:');
          Terminal.info('  dgt config --sort local-date --desc');
          Terminal.info(
            '  dgt config --no-sort          # Remove sort configuration',
          );
          Terminal.info('');
          Terminal.info(
            'Use --gerrit/--no-gerrit, --local/--no-local, --url/--no-url, '
            '--status, --since, --before, --diverged, --sort, --asc, --desc to '
            'set defaults.',
          );
          return;
        }

        // Validate that asc and desc are not both specified
        if (results.wasParsed('asc') && results.wasParsed('desc')) {
          Terminal.error('Error: Cannot specify both --asc and --desc flags.');
          Terminal.info('Please use only one sort direction flag.');
          return;
        }

        // Check for removal flags
        final removeStatus =
            results.wasParsed('no-status') && results.flag('no-status');
        final removeDiverged =
            results.wasParsed('no-diverged') && results.flag('no-diverged');

        // Extract config values from parsed arguments
        final configToSave = DgtConfig.fromArgResults(results);

        await runConfigCommand(
          verbose,
          configToSave,
          removeStatus,
          removeDiverged,
        );
      default:
        Terminal.error('Unknown command: $command');
        Terminal.info('');
        printUsage(argParser);
    }
  } on FormatException catch (e) {
    // Print usage information if an invalid argument was provided.
    Terminal.error(e.message);

    // If it's about an invalid status value, show the available options
    if (e.message.contains('--status')) {
      Terminal.info('');
      Terminal.info('Available status values:');
      Terminal.info('  wip       - Work in Progress');
      Terminal.info('  active    - Ready for review');
      Terminal.info('  merged    - Successfully merged');
      Terminal.info('  abandoned - Abandoned changes');
      Terminal.info('  conflict  - Has merge conflicts');
      Terminal.info('');
      Terminal.info('Run "dgt --help" for more information.');
    } else if (e.message.contains('--sort')) {
      Terminal.info('');
      Terminal.info('Available sort fields:');
      Terminal.info('  local-date   - Sort by local date');
      Terminal.info('  gerrit-date  - Sort by Gerrit date');
      Terminal.info('  status       - Sort by Gerrit status');
      Terminal.info('  name         - Sort by branch name');
      Terminal.info('');
      Terminal.info('Run "dgt --help" for more information.');
      Terminal.info('');
    } else {
      Terminal.info('');
      printUsage(argParser);
    }
  }
}

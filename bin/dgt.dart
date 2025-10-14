import 'dart:io';

import 'package:dgt/branch_info.dart';
import 'package:dgt/clean_command.dart';
import 'package:dgt/cli_options.dart';
import 'package:dgt/config_command.dart';
import 'package:dgt/config_service.dart';
import 'package:dgt/display_options.dart';
import 'package:dgt/error_validation.dart';
import 'package:dgt/filtering.dart';
import 'package:dgt/gerrit_service.dart';
import 'package:dgt/git_service.dart';
import 'package:dgt/git_service_batch.dart';
import 'package:dgt/output_formatter.dart';
import 'package:dgt/performance_tracker.dart';
import 'package:dgt/print_config.dart';
import 'package:dgt/print_usage.dart';
import 'package:dgt/sorting.dart';
import 'package:dgt/terminal.dart';
import 'package:dgt/verbose_output.dart';

const String version = '0.0.1';

Future<void> runListCommand(
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
      VerboseOutput.instance.info(
        '[VERBOSE] Changing directory to: $repositoryPath',
      );
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

    VerboseOutput.instance.info('[VERBOSE] Fetching local branches...');

    // Get all local branches
    tracker?.startTimer('branch_discovery');
    final branches = await GitService.getAllBranches();
    tracker?.endTimer('branch_discovery');

    if (branches.isEmpty) {
      Terminal.info('No branches found in this repository.');
      return;
    }

    final branchText = branches.length == 1 ? 'branch' : 'branches';
    VerboseOutput.instance.info(
      '[VERBOSE] Found ${branches.length} $branchText',
    );

    // Collect branch information
    var branchInfoList = <BranchInfo>[];

    // Batch fetch all Git information at once to minimize git process spawns
    // This uses git for-each-ref and git config --get-regexp to get data for
    // all branches in just 2 git commands instead of 2*N commands.
    VerboseOutput.instance.info(
      '[VERBOSE] Batch fetching Git information for all branches...',
    );

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
        VerboseOutput.instance.info('[VERBOSE] Processing branch: $branch');

        branchDataList.add((
          branch: branch,
          localHash: commitInfo.hash,
          localDate: commitInfo.date,
          gerritConfig: gerritConfig,
          error: null,
        ));
      } else {
        VerboseOutput.instance.warning(
          '[VERBOSE] Failed to get commit info for branch $branch',
        );
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
        VerboseOutput.instance.info('[VERBOSE] Branch ${branchData.branch}:');
        VerboseOutput.instance.info(
          '[VERBOSE]   Gerrit Issue: ${branchData.gerritConfig.gerritIssue}',
        );
        VerboseOutput.instance.info(
          '[VERBOSE]   Gerrit Server: '
          '${branchData.gerritConfig.gerritServer}',
        );

        final issue = branchData.gerritConfig.gerritIssue!;
        issueNumbersToBranches
            .putIfAbsent(issue, () => <String>[])
            .add(branchData.branch);
      } else {
        VerboseOutput.instance.info('[VERBOSE] Branch ${branchData.branch}:');
        VerboseOutput.instance.info(
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
      VerboseOutput.instance.info(
        '[VERBOSE] Batch querying Gerrit for '
        '${issueNumbersToBranches.length} issue(s)...',
      );

      try {
        tracker?.startTimer('gerrit_queries');
        final issueNumbers = issueNumbersToBranches.keys.toList();
        gerritChanges = await GerritService.getBatchChangesByIssueNumbers(
          issueNumbers,
        );
        tracker?.endTimer('gerrit_queries');

        final foundCount = gerritChanges.values
            .where((GerritChange? c) => c != null)
            .length;
        VerboseOutput.instance.info(
          '[VERBOSE] Batch query completed: $foundCount/'
          '${issueNumbers.length} changes found',
        );
      } catch (e) {
        tracker?.endTimer('gerrit_queries');
        VerboseOutput.instance.warning(
          '[VERBOSE] Batch Gerrit query failed: $e',
        );
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

        if (gerritChange != null) {
          VerboseOutput.instance.info(
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
      VerboseOutput.instance.info('[VERBOSE] Applying filters...');
      VerboseOutput.instance.info(
        '[VERBOSE] Branches before filtering: ${branchInfoList.length}',
      );

      tracker?.startTimer('filtering');
      branchInfoList = applyFilters(branchInfoList, filters);
      tracker?.endTimer('filtering');

      VerboseOutput.instance.info(
        '[VERBOSE] Branches after filtering: ${branchInfoList.length}',
      );
    }

    // Apply sorting
    if (!sortOptions.isEmpty) {
      VerboseOutput.instance.info('[VERBOSE] Applying sorting...');
      VerboseOutput.instance.info(
        '[VERBOSE] Sort field: ${sortOptions.field}, '
        'direction: ${sortOptions.direction ?? "asc"}',
      );

      tracker?.startTimer('sorting');
      branchInfoList = applySort(branchInfoList, sortOptions);
      tracker?.endTimer('sorting');
    }

    // Display results in a formatted table
    Terminal.info('');
    final formatter = OutputFormatter(displayOptions);
    formatter.displayBranchTable(
      branchInfoList,
      sortField: sortOptions.field,
      sortDirection: sortOptions.direction,
    );

    // Display performance summary if timing was requested
    if (displayOptions.showTiming && tracker != null) {
      OutputFormatter.displayPerformanceSummary(tracker);
    }
  } catch (e) {
    Terminal.error('Error: $e');
    Terminal.error('Stack trace: ${StackTrace.current}');
  }
}

Future<void> main(List<String> arguments) async {
  final argParser = CliOptions.buildParser();
  try {
    // Special handling for 'clean' command:
    // - Parse only arguments before 'clean' (global flags)
    // - Pass everything after 'clean' directly to git cl archive
    // We need to find 'clean' as a command, not as a subcommand (e.g., not in
    // 'config clean')

    // Find where 'clean' appears as a top-level command
    var cleanIndex = -1;
    for (var i = 0; i < arguments.length; i++) {
      if (arguments[i] == 'clean') {
        // Check if this is a top-level command (not a subcommand)
        // It's a top-level command if:
        // - It's the first argument, OR
        // - All previous arguments start with '-' (are flags)
        if (i == 0 ||
            arguments.sublist(0, i).every((arg) => arg.startsWith('-'))) {
          cleanIndex = i;
          break;
        }
      }
    }

    final argsToparse = cleanIndex >= 0
        ? arguments.sublist(0, cleanIndex + 1) // Include 'clean' in parsing
        : arguments;

    // Check if the first argument is a known command
    final knownCommands = ['list', 'config', 'clean'];
    final hasCommand =
        argsToparse.isNotEmpty && knownCommands.contains(argsToparse.first);

    // If no command specified, default to 'list' by prepending it
    final finalArgs = hasCommand ? argsToparse : ['list', ...argsToparse];

    final results = argParser.parse(finalArgs);

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
    final timing = results.flag('timing');

    // Initialize verbose output singleton
    VerboseOutput.initialize(verbose);

    // Determine which command to run (should always have a command now)
    final command = results.command?.name ?? 'list';

    // Get subcommand results
    final subResults = results.command!;

    // Execute the appropriate command
    switch (command) {
      case 'list':
        // Check if help flag is provided for list command
        if (subResults.flag('help')) {
          printListHelp();
          return;
        }

        // Load config from ~/.dgt/.config
        final config = await ConfigService.readConfig();

        VerboseOutput.instance.printConfigSettings(config);

        // Validate that conflicting flags are not used together
        if (!FlagValidator.validateAllFlags(subResults)) {
          return;
        }

        // Use centralized resolution helpers for filters and sort options
        // Handle --no-status flag to override config
        List<String> statusFilters;
        if (subResults.wasParsed('no-status') && subResults.flag('no-status')) {
          // User explicitly wants to ignore status filters
          statusFilters = [];
        } else {
          statusFilters = config.resolveMultiOption(subResults, 'status', []);
        }

        final sinceStr = config.resolveOption<String?>(
          subResults,
          'since',
          null,
        );
        final beforeStr = config.resolveOption<String?>(
          subResults,
          'before',
          null,
        );

        // Handle --diverged/--no-diverged negatable flag to override config
        // If user explicitly provided the flag, use that boolean; otherwise
        // resolve the value from the config with default false.
        final divergedFilter = subResults.wasParsed('diverged')
            ? subResults.flag('diverged')
            : config.resolveFlag(subResults, 'diverged', false);

        // Resolve sort options using centralized helpers
        // Handle --no-sort flag to override config
        String? sortField;
        String? sortDirection;

        if (subResults.wasParsed('no-sort') && subResults.flag('no-sort')) {
          // User explicitly wants to disable sorting
          sortField = null;
          sortDirection = null;
        } else {
          sortField = config.resolveOption(subResults, 'sort', 'name');

          // Handle sort direction using centralized helper
          sortDirection = config.resolveSortDirection(subResults, 'asc');
        }

        // Validate status filters (from CLI or config file)
        statusFilters.forEach(validateStatus);

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

        final sortOptions = SortOptions(
          field: sortField,
          direction: sortDirection,
        );

        // Get the repository path if specified
        final repositoryPath = subResults.option('path');

        // Create DisplayOptions instance using factory constructor
        // which resolves values from CLI flags, config file, and defaults
        final displayOptions = DisplayOptions.resolve(
          results: subResults,
          config: config,
          showTiming: timing,
        );

        await runListCommand(
          repositoryPath,
          displayOptions,
          filters,
          sortOptions,
        );
      case 'config':
        // Check if help flag is provided for config command
        if (subResults.flag('help')) {
          printConfigCommandHelp();
          return;
        }

        // Initialize performance tracker if timing is requested
        PerformanceTracker? configTracker;
        if (timing) {
          configTracker = PerformanceTracker();
        }

        // Check for nested subcommands (config show / config clean)
        final nested = subResults.command;
        final nestedName = nested?.name;

        if (nestedName == 'show') {
          final showResults = nested!;
          // If user requested help on the sub-subcommand, show config help
          if (showResults.flag('help')) {
            printConfigShowHelp();
            if (timing && configTracker != null) {
              OutputFormatter.displayPerformanceSummary(configTracker);
            }
            return;
          }

          await runConfigShowCommand(tracker: configTracker);

          if (timing && configTracker != null) {
            OutputFormatter.displayPerformanceSummary(configTracker);
          }
          return;
        }

        if (nestedName == 'clean') {
          final cleanResults = nested!;
          // If user requested help on the sub-subcommand, show config help
          if (cleanResults.flag('help')) {
            printConfigCleanHelp();
            if (timing && configTracker != null) {
              OutputFormatter.displayPerformanceSummary(configTracker);
            }
            return;
          }

          // For config clean, use the nested ArgResults so affirmative-only
          // flags are respected (we attached affirmative-only options to the
          // 'clean' subcommand parser).
          // Note: 'force' flag is on the parent subResults (config), not
          // cleanResults
          final force =
              subResults.wasParsed('force') && subResults.flag('force');

          // Build list of removals based on what flags were passed
          final removals = <({RemovableConfigOption option, String? value})>[];

          // Check each possible option
          if (cleanResults.wasParsed('local') && cleanResults.flag('local')) {
            removals.add((option: RemovableConfigOption.local, value: null));
          }
          if (cleanResults.wasParsed('gerrit') && cleanResults.flag('gerrit')) {
            removals.add((option: RemovableConfigOption.gerrit, value: null));
          }
          if (cleanResults.wasParsed('url') && cleanResults.flag('url')) {
            removals.add((option: RemovableConfigOption.url, value: null));
          }
          if (cleanResults.wasParsed('diverged') &&
              cleanResults.flag('diverged')) {
            removals.add((option: RemovableConfigOption.diverged, value: null));
          }
          if (cleanResults.wasParsed('sort')) {
            final sortValue = cleanResults.option('sort');
            removals.add((
              option: RemovableConfigOption.sort,
              value: sortValue,
            ));
          }
          if (cleanResults.wasParsed('status')) {
            final statusValues = cleanResults.multiOption('status');
            for (final value in statusValues) {
              removals.add((
                option: RemovableConfigOption.status,
                value: value,
              ));
            }
          }
          if (cleanResults.wasParsed('since')) {
            removals.add((option: RemovableConfigOption.since, value: null));
          }
          if (cleanResults.wasParsed('before')) {
            removals.add((option: RemovableConfigOption.before, value: null));
          }

          // If any specific options were requested, remove them
          if (removals.isNotEmpty) {
            await ConfigService.removeOptions(removals);
            if (timing && configTracker != null) {
              OutputFormatter.displayPerformanceSummary(configTracker);
            }
            return;
          }

          // Default: perform full config clean (reset to defaults)
          await runConfigCleanCommand(force, tracker: configTracker);

          if (timing && configTracker != null) {
            OutputFormatter.displayPerformanceSummary(configTracker);
          }
          return;
        }

        // For the config command, user must explicitly provide at least one
        // flag or valid subcommand
        if (!FlagValidator.hasConfigFlags(subResults)) {
          printConfigHelp();
          return;
        }

        // Validate that asc and desc are not both specified
        if (!FlagValidator.validateSortDirectionFlags(subResults)) {
          return;
        }

        // Check for removal flags
        final removeStatus =
            subResults.wasParsed('no-status') && subResults.flag('no-status');
        final removeSort =
            subResults.wasParsed('no-sort') && subResults.flag('no-sort');

        // Extract config values from parsed arguments
        final configToSave = DgtConfig.fromArgResults(subResults);

        await runConfigCommand(
          configToSave,
          removeStatus,
          removeSort,
          tracker: configTracker,
        );

        // Display performance summary if timing was requested
        if (timing && configTracker != null) {
          OutputFormatter.displayPerformanceSummary(configTracker);
        }
      case 'clean':
        // Initialize performance tracker if timing is requested
        PerformanceTracker? cleanTracker;
        if (timing) {
          cleanTracker = PerformanceTracker();
        }

        // Get all arguments after 'clean' from the original arguments list
        // These will be passed directly to 'git cl archive'
        final cleanArgs = cleanIndex >= 0
            ? arguments.sublist(cleanIndex + 1)
            : <String>[];

        await runCleanCommand(cleanArgs, tracker: cleanTracker);

        // Display performance summary if timing was requested
        if (timing && cleanTracker != null) {
          OutputFormatter.displayPerformanceSummary(cleanTracker);
        }
      default:
        Terminal.error('Unknown command: $command');
        Terminal.info('');
        printUsage(argParser);
    }
  } on FormatException catch (e) {
    // Print usage information if an invalid argument was provided.
    Terminal.error(e.message);

    // If it's about an invalid status value, show the available options
    if (e.message.contains('--sort')) {
      FlagValidator.printSortHelp();
    } else if (e.message.contains('--status')) {
      FlagValidator.printStatusHelp();
    } else {
      Terminal.info('');
      printUsage(argParser);
    }
  }
}

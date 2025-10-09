import 'dart:io';

/// Represents Gerrit metadata stored in Git config for a branch.
class GerritBranchConfig {
  GerritBranchConfig({
    this.gerritIssue,
    this.gerritServer,
    this.gerritPatchset,
    this.gerritSquashHash,
    this.lastUploadHash,
  });

  /// The Gerrit issue/change number (e.g., 389423)
  final String? gerritIssue;

  /// The Gerrit server URL (e.g., https://dart-review.googlesource.com)
  final String? gerritServer;

  /// The patchset number
  final String? gerritPatchset;

  /// The squash hash from Gerrit
  final String? gerritSquashHash;

  /// The last upload hash
  final String? lastUploadHash;

  /// Returns true if this branch has Gerrit configuration
  bool get hasGerritConfig => gerritIssue != null && gerritServer != null;
}

/// Service for interacting with Git repository.
///
/// This class provides methods to execute Git commands and extract information
/// from the local Git repository, such as branch names, commit hashes, dates,
/// and messages.
class GitService {
  /// Regular expression to match Change-ID in commit messages.
  /// Format: Change-Id: I[40 hex characters]
  static final RegExp _changeIdRegex = RegExp('Change-Id: (I[a-f0-9]{40})');

  /// Cache for Git command results to avoid redundant executions.
  /// Key: concatenated command arguments (e.g., "rev-parse^main")
  /// Value: command output
  static final Map<String, String> _cache = <String, String>{};

  /// Clears the Git command cache.
  ///
  /// This can be useful if the repository state has changed and
  /// cached results are no longer valid.
  static void clearCache() {
    _cache.clear();
  }

  /// Generates a cache key from Git command arguments.
  static String _getCacheKey(List<String> arguments) {
    return arguments.join('^');
  }

  /// Executes a Git command and returns the output.
  ///
  /// Results are cached to avoid redundant Git command executions.
  /// Throws a [ProcessException] if the command fails.
  static Future<String> _runGitCommand(List<String> arguments) async {
    // Check cache first
    final cacheKey = _getCacheKey(arguments);
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // Execute the Git command
    final result = await Process.run('git', arguments);

    if (result.exitCode != 0) {
      throw ProcessException(
        'git',
        arguments,
        'Git command failed: ${result.stderr}',
        result.exitCode,
      );
    }

    final output = (result.stdout as String).trim();

    // Cache successful results
    _cache[cacheKey] = output;

    return output;
  }

  /// Gets a list of all local branches.
  ///
  /// Returns a list of branch names.
  /// Example: ['main', 'feature/new-api', 'bugfix/memory-leak']
  static Future<List<String>> getAllBranches() async {
    final output = await _runGitCommand(<String>['branch', '--list']);

    if (output.isEmpty) {
      return <String>[];
    }

    // Parse branch list - format is "* current-branch" or "  other-branch"
    return output
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .map(
          (String line) =>
              line.startsWith('*') ? line.substring(1).trim() : line,
        )
        .toList();
  }

  /// Gets the name of the current branch.
  ///
  /// Returns the current branch name or throws an exception if not in a Git repo.
  static Future<String> getCurrentBranch() async {
    return await _runGitCommand(<String>['branch', '--show-current']);
  }

  /// Gets the commit hash for a given branch.
  ///
  /// [branch] - The branch name to get the commit hash for.
  /// Returns the full commit hash (40 characters).
  static Future<String> getCommitHash(String branch) async {
    return await _runGitCommand(<String>['rev-parse', branch]);
  }

  /// Gets the commit date for a given branch.
  ///
  /// [branch] - The branch name to get the commit date for.
  /// Returns the commit date in ISO 8601 format.
  /// Example: "2025-10-07 14:30:45 -0400"
  static Future<String> getCommitDate(String branch) async {
    return await _runGitCommand(<String>['log', '-1', '--format=%ci', branch]);
  }

  /// Gets the commit message for a given branch.
  ///
  /// [branch] - The branch name to get the commit message for.
  /// Returns the full commit message (including body and trailers).
  static Future<String> getCommitMessage(String branch) async {
    return await _runGitCommand(<String>['log', '-1', '--format=%B', branch]);
  }

  /// Extracts the Change-ID from a commit message.
  ///
  /// [commitMessage] - The commit message to extract the Change-ID from.
  /// Returns the Change-ID (including the 'I' prefix) or null if not found.
  /// Example: "Iabc123..." or null
  static String? extractChangeId(String commitMessage) {
    final match = _changeIdRegex.firstMatch(commitMessage);
    return match?.group(1);
  }

  /// Gets the Change-ID for a given branch by reading its commit message.
  ///
  /// [branch] - The branch name to get the Change-ID for.
  /// [commitMessage] - Optional pre-fetched commit message to avoid redundant Git calls.
  /// Returns the Change-ID or null if not found in the commit message.
  static Future<String?> getChangeId(
    String branch, {
    String? commitMessage,
  }) async {
    final message = commitMessage ?? await getCommitMessage(branch);
    return extractChangeId(message);
  }

  /// Checks if the current directory is inside a Git repository.
  ///
  /// Returns true if inside a Git repo, false otherwise.
  static Future<bool> isGitRepository() async {
    try {
      await _runGitCommand(<String>['rev-parse', '--git-dir']);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Gets Gerrit configuration for a specific branch from Git config.
  ///
  /// Reads branch-specific Gerrit metadata that is stored in the Git config file
  /// when changes are uploaded to Gerrit. This metadata includes the change number,
  /// server URL, patchset number, and various hashes used for tracking.
  ///
  /// The Git config stores these values in the format:
  /// ```
  /// [branch "branch-name"]
  ///     gerritissue = 389423
  ///     gerritserver = https://dart-review.googlesource.com
  ///     gerritpatchset = 3
  ///     gerritsquashhash = abc123...
  ///     last-upload-hash = def456...
  /// ```
  ///
  /// [branch] - The branch name to get Gerrit config for.
  /// Returns a [GerritBranchConfig] object with the Gerrit metadata.
  /// If the branch has no Gerrit config, returns an empty config object.
  static Future<GerritBranchConfig> getGerritConfig(String branch) async {
    try {
      // Use git config to get branch-specific Gerrit settings
      // These are typically set by Gerrit upload tools (e.g., git-cl, repo)
      final gerritIssue = await _getConfigValue('branch.$branch.gerritissue');
      final gerritServer = await _getConfigValue('branch.$branch.gerritserver');
      final gerritPatchset = await _getConfigValue(
        'branch.$branch.gerritpatchset',
      );
      final gerritSquashHash = await _getConfigValue(
        'branch.$branch.gerritsquashhash',
      );
      final lastUploadHash = await _getConfigValue(
        'branch.$branch.last-upload-hash',
      );

      return GerritBranchConfig(
        gerritIssue: gerritIssue,
        gerritServer: gerritServer,
        gerritPatchset: gerritPatchset,
        gerritSquashHash: gerritSquashHash,
        lastUploadHash: lastUploadHash,
      );
    } catch (e) {
      // Return empty config if any error occurs (e.g., not in a Git repo)
      return GerritBranchConfig();
    }
  }

  /// Gets a single config value from Git config.
  ///
  /// [key] - The config key to retrieve (e.g., 'branch.main.gerritissue').
  /// Returns the config value or null if not found.
  static Future<String?> _getConfigValue(String key) async {
    try {
      final value = await _runGitCommand(<String>['config', '--get', key]);
      return value.isNotEmpty ? value : null;
    } catch (e) {
      // Config key doesn't exist
      return null;
    }
  }
}

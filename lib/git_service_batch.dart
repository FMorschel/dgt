import 'dart:io';
import 'package:dgt/git_service.dart';

/// Batch operations for GitService to reduce process spawn overhead.
class GitServiceBatch {
  /// Gets commit info for multiple branches in a single git command.
  ///
  /// This uses git's for-each-ref to batch-query multiple branches at once,
  /// which is more efficient than spawning separate git processes per branch.
  ///
  /// Returns a map of branch name to (hash, date) tuples.
  static Future<Map<String, ({String hash, String date})>>
      getBatchCommitInfo(List<String> branches) async {
    if (branches.isEmpty) {
      return {};
    }

    // Use git for-each-ref to get all branch info at once
    // Format: <refname>|<objectname>|<committerdate:iso8601>
    final result = await Process.run(
      'git',
      [
        'for-each-ref',
        '--format=%(refname:short)|%(objectname)|%(committerdate:iso8601)',
        ...branches.map((b) => 'refs/heads/$b'),
      ],
    );

    if (result.exitCode != 0) {
      throw ProcessException(
        'git',
        ['for-each-ref', '...'],
        'Git command failed: ${result.stderr}',
        result.exitCode,
      );
    }

    final output = (result.stdout as String).trim();
    final resultMap = <String, ({String hash, String date})>{};

    for (final line in output.split('\n')) {
      if (line.isEmpty) continue;

      final parts = line.split('|');
      if (parts.length != 3) continue;

      final branchName = parts[0];
      final hash = parts[1];
      final date = parts[2];

      resultMap[branchName] = (hash: hash, date: date);
    }

    return resultMap;
  }

  /// Gets Gerrit config for all branches in fewer git commands.
  ///
  /// Instead of calling git config once per branch, this gets all branch
  /// configs at once and parses them.
  ///
  /// Returns a map of branch name to GerritBranchConfig.
  static Future<Map<String, GerritBranchConfig>> getBatchGerritConfig(
    List<String> branches,
  ) async {
    if (branches.isEmpty) {
      return {};
    }

    try {
      // Get all branch configs at once
      // We need both gerrit* keys and last-upload-hash
      final result = await Process.run(
        'git',
        ['config', '--get-regexp', '^branch\\..*\\.(gerrit|last-upload-hash)'],
      );

      if (result.exitCode != 0) {
        // No gerrit config found
        return {};
      }

      final output = (result.stdout as String).trim();
      final configsByBranch = <String, Map<String, String>>{};

      // Parse all config lines
      for (final line in output.split('\n')) {
        if (line.isEmpty) continue;

        final parts = line.split(' ');
        if (parts.length < 2) continue;

        // Extract branch name and config key
        // Format: branch.<name>.<key> <value>
        final keyParts = parts[0].split('.');
        if (keyParts.length < 3) continue;

        final branchName = keyParts[1];
        final configKey = keyParts[2];
        final configValue = parts.sublist(1).join(' ');

        configsByBranch
            .putIfAbsent(branchName, () => {})
            [configKey] = configValue;
      }

      // Convert to GerritBranchConfig objects
      final resultMap = <String, GerritBranchConfig>{};
      for (final branch in branches) {
        final config = configsByBranch[branch] ?? {};
        resultMap[branch] = GerritBranchConfig(
          gerritIssue: config['gerritissue'],
          gerritServer: config['gerritserver'],
          gerritPatchset: config['gerritpatchset'],
          gerritSquashHash: config['gerritsquashhash'],
          lastUploadHash: config['last-upload-hash'],
        );
      }

      return resultMap;
    } catch (e) {
      // Return empty configs on error
      return {};
    }
  }
}

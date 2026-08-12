import 'dart:io';

import 'package:dgt/git_service.dart';
import 'package:path/path.dart' as p;

/// A throwaway Git repository for exercising [GitService] against real Git
/// output.
///
/// Points [GitService.workingDirectory] at the temporary repository rather
/// than changing [Directory.current], so nothing process-wide is disturbed and
/// test files stay independent of one another.
class TempGitRepo {
  TempGitRepo._(this.directory, this._previousWorkingDirectory);

  /// Creates an initialised repository and points [GitService] at it.
  static Future<TempGitRepo> create() async {
    final previous = GitService.workingDirectory;
    final directory = await Directory.systemTemp.createTemp('dgt_test_');
    GitService.workingDirectory = directory.path;

    final repo = TempGitRepo._(directory, previous);
    await repo._git(['init', '--initial-branch=main']);
    // Keep the repository independent of whatever the developer or CI has in
    // their global Git config.
    await repo._git(['config', 'user.email', 'test@example.com']);
    await repo._git(['config', 'user.name', 'DGT Test']);
    await repo._git(['config', 'commit.gpgsign', 'false']);

    // GitService caches by argument list only, so entries from another
    // repository would otherwise be served here.
    GitService.clearCache();

    return repo;
  }

  /// The repository root.
  final Directory directory;

  final String? _previousWorkingDirectory;

  /// Restores the previous working directory and deletes the repository.
  Future<void> dispose() async {
    GitService.workingDirectory = _previousWorkingDirectory;
    GitService.clearCache();
    try {
      await directory.delete(recursive: true);
    } on FileSystemException {
      // Windows can still hold a handle to the freshly used repository; a
      // leftover temp directory is not worth failing a test over.
    }
  }

  /// Writes [content] to [fileName] and commits it with [message].
  Future<void> commitFile({
    required String fileName,
    required String message,
    String content = 'content',
  }) async {
    File(p.join(directory.path, fileName)).writeAsStringSync(content);
    await _git(['add', fileName]);
    await _git(['commit', '-m', message]);
    GitService.clearCache();
  }

  /// Creates [name] and switches to it.
  Future<void> createBranch(String name) async {
    await _git(['checkout', '-b', name]);
    GitService.clearCache();
  }

  /// Switches to an existing branch.
  Future<void> checkout(String name) async {
    await _git(['checkout', name]);
    GitService.clearCache();
  }

  /// Sets `branch.<branch>.<key>` to [value].
  Future<void> setBranchConfig(String branch, String key, String value) async {
    await _git(['config', 'branch.$branch.$key', value]);
    GitService.clearCache();
  }

  /// Returns the full commit hash of [revision].
  Future<String> revParse(String revision) async {
    final result = await _git(['rev-parse', revision]);
    return result.trim();
  }

  Future<String> _git(List<String> arguments) async {
    final result = await Process.run(
      'git',
      arguments,
      workingDirectory: directory.path,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        'git',
        arguments,
        result.stderr.toString(),
        result.exitCode,
      );
    }
    return result.stdout.toString();
  }
}

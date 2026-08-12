import 'dart:io';

import 'package:dgt/git_service.dart';
import 'package:dgt/git_service_batch.dart';
import 'package:test/test.dart';

import 'temp_git_repo.dart';

void main() {
  group('GitService.extractChangeId', () {
    const changeId = 'I0123456789abcdef0123456789abcdef01234567';

    test('pulls the Change-Id trailer out of a commit message', () {
      const message =
          'Fix the thing\n'
          '\n'
          'A longer explanation.\n'
          '\n'
          'Change-Id: $changeId\n';

      expect(GitService.extractChangeId(message), changeId);
    });

    test('returns null when there is no trailer', () {
      expect(GitService.extractChangeId('Fix the thing'), isNull);
    });

    test('requires exactly 40 lowercase hex digits after the I', () {
      expect(
        GitService.extractChangeId('Change-Id: I0123456789abcdef'),
        isNull,
      );
      expect(
        GitService.extractChangeId(
          'Change-Id: I0123456789ABCDEF0123456789ABCDEF01234567',
        ),
        isNull,
      );
    });

    test('returns the first trailer when a message carries several', () {
      const second = 'Iffffffffffffffffffffffffffffffffffffffff';
      const message = 'Squashed\n\nChange-Id: $changeId\nChange-Id: $second\n';

      expect(GitService.extractChangeId(message), changeId);
    });
  });

  group('against a real repository', () {
    late TempGitRepo repo;

    setUp(() async {
      repo = await TempGitRepo.create();
      await repo.commitFile(fileName: 'a.txt', message: 'initial commit');
    });

    tearDown(() async {
      await repo.dispose();
    });

    test('isGitRepository is true inside a repository', () async {
      expect(await GitService.isGitRepository(), isTrue);
    });

    test('getCurrentBranch reports the checked out branch', () async {
      expect(await GitService.getCurrentBranch(), 'main');

      await repo.createBranch('feature/new-api');

      expect(await GitService.getCurrentBranch(), 'feature/new-api');
    });

    test('getAllBranches strips the current-branch marker', () async {
      await repo.createBranch('feature/new-api');
      await repo.createBranch('bugfix/memory-leak');

      final branches = await GitService.getAllBranches();

      expect(
        branches,
        unorderedEquals(['main', 'feature/new-api', 'bugfix/memory-leak']),
      );
      expect(branches, everyElement(isNot(startsWith('*'))));
    });

    test('getCommitHash returns the full 40 character hash', () async {
      final hash = await GitService.getCommitHash('main');

      expect(hash, hasLength(40));
      expect(hash, await repo.revParse('main'));
    });

    test('getCommitDate returns a parseable ISO 8601 date', () async {
      final date = await GitService.getCommitDate('main');

      // git's %ci format, e.g. "2025-10-07 14:30:45 -0400".
      expect(date, matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} ')));
      expect(DateTime.parse(date.substring(0, 19)), isA<DateTime>());
    });

    test('getCommitHashAndDate agrees with the single-value getters', () async {
      final combined = await GitService.getCommitHashAndDate('main');

      expect(combined.hash, await GitService.getCommitHash('main'));
      expect(combined.date, await GitService.getCommitDate('main'));
    });

    test('getCommitMessage returns the full message body', () async {
      await repo.commitFile(
        fileName: 'b.txt',
        message:
            'Add b\n\nChange-Id: '
            'I0123456789abcdef0123456789abcdef01234567',
      );

      final message = await GitService.getCommitMessage('main');

      expect(message, startsWith('Add b'));
      expect(message, contains('Change-Id: I0123456789'));
    });

    test('getChangeId reads the trailer off the branch commit', () async {
      const changeId = 'I0123456789abcdef0123456789abcdef01234567';
      await repo.commitFile(
        fileName: 'c.txt',
        message: 'Add c\n\nChange-Id: $changeId',
      );

      expect(await GitService.getChangeId('main'), changeId);
    });

    test(
      'getChangeId prefers a pre-fetched message over another git call',
      () async {
        const changeId = 'Iaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

        expect(
          await GitService.getChangeId(
            'no-such-branch',
            commitMessage: 'Subject\n\nChange-Id: $changeId',
          ),
          changeId,
        );
      },
    );

    test('throws a ProcessException for an unknown branch', () {
      expect(
        () => GitService.getCommitHash('no-such-branch'),
        throwsA(isA<ProcessException>()),
      );
    });

    group('getGerritConfig', () {
      test('reads every Gerrit key for a branch', () async {
        await repo.setBranchConfig('main', 'gerritissue', '389423');
        await repo.setBranchConfig(
          'main',
          'gerritserver',
          'https://dart-review.googlesource.com',
        );
        await repo.setBranchConfig('main', 'gerritpatchset', '3');
        await repo.setBranchConfig('main', 'gerritsquashhash', 'abc123');
        await repo.setBranchConfig('main', 'last-upload-hash', 'def456');

        final config = await GitService.getGerritConfig('main');

        expect(config.gerritIssue, '389423');
        expect(config.gerritServer, 'https://dart-review.googlesource.com');
        expect(config.gerritPatchset, '3');
        expect(config.gerritSquashHash, 'abc123');
        expect(config.lastUploadHash, 'def456');
        expect(config.hasGerritConfig, isTrue);
      });

      test(
        'returns an empty config for a branch with no Gerrit data',
        () async {
          final config = await GitService.getGerritConfig('main');

          expect(config.gerritIssue, isNull);
          expect(config.hasGerritConfig, isFalse);
        },
      );

      test('handles branch names containing dots', () async {
        await repo.createBranch('release/1.2.3');
        await repo.setBranchConfig('release/1.2.3', 'gerritissue', '111');
        await repo.setBranchConfig(
          'release/1.2.3',
          'gerritserver',
          'https://gerrit.test',
        );

        final config = await GitService.getGerritConfig('release/1.2.3');

        expect(config.gerritIssue, '111');
        expect(config.gerritServer, 'https://gerrit.test');
      });

      test('does not leak config from a similarly named branch', () async {
        await repo.createBranch('feature');
        await repo.createBranch('feature-two');
        await repo.setBranchConfig('feature-two', 'gerritissue', '222');
        await repo.setBranchConfig(
          'feature-two',
          'gerritserver',
          'https://gerrit.test',
        );

        final config = await GitService.getGerritConfig('feature');

        expect(config.gerritIssue, isNull);
      });
    });

    group('caching', () {
      test('serves repeated calls from the cache', () async {
        final first = await GitService.getCurrentBranch();

        // Switching branches without clearing the cache still reports the
        // original answer, which is what makes clearCache necessary.
        await Process.run('git', [
          'checkout',
          '-b',
          'cached-away',
        ], workingDirectory: repo.directory.path);

        expect(await GitService.getCurrentBranch(), first);

        GitService.clearCache();

        expect(await GitService.getCurrentBranch(), 'cached-away');
      });
    });
  });

  group('GitServiceBatch', () {
    late TempGitRepo repo;

    setUp(() async {
      repo = await TempGitRepo.create();
      await repo.commitFile(fileName: 'a.txt', message: 'initial commit');
    });

    tearDown(() async {
      await repo.dispose();
    });

    test('returns empty maps for an empty branch list', () async {
      expect(await GitServiceBatch.getBatchCommitInfo([]), isEmpty);
      expect(await GitServiceBatch.getBatchGerritConfig([]), isEmpty);
    });

    test('getBatchCommitInfo matches the single-branch getters', () async {
      await repo.createBranch('feature');
      await repo.commitFile(fileName: 'b.txt', message: 'second');

      final info = await GitServiceBatch.getBatchCommitInfo([
        'main',
        'feature',
      ]);

      expect(info.keys, unorderedEquals(['main', 'feature']));
      expect(info['main']!.hash, await repo.revParse('main'));
      expect(info['feature']!.hash, await repo.revParse('feature'));
      expect(info['main']!.hash, isNot(info['feature']!.hash));
      expect(info['feature']!.date, isNotEmpty);
    });

    test('getBatchGerritConfig reads config for several branches', () async {
      await repo.createBranch('feature');
      await repo.setBranchConfig('main', 'gerritissue', '111');
      await repo.setBranchConfig('main', 'gerritserver', 'https://a.test');
      await repo.setBranchConfig('feature', 'gerritissue', '222');
      await repo.setBranchConfig('feature', 'gerritserver', 'https://b.test');
      await repo.setBranchConfig('feature', 'last-upload-hash', 'abc');

      final configs = await GitServiceBatch.getBatchGerritConfig([
        'main',
        'feature',
      ]);

      expect(configs['main']!.gerritIssue, '111');
      expect(configs['main']!.gerritServer, 'https://a.test');
      expect(configs['main']!.lastUploadHash, isNull);
      expect(configs['feature']!.gerritIssue, '222');
      expect(configs['feature']!.lastUploadHash, 'abc');
    });

    test('includes requested branches that have no Gerrit config', () async {
      await repo.createBranch('feature');
      await repo.setBranchConfig('main', 'gerritissue', '111');
      await repo.setBranchConfig('main', 'gerritserver', 'https://a.test');

      final configs = await GitServiceBatch.getBatchGerritConfig([
        'main',
        'feature',
      ]);

      expect(configs.keys, unorderedEquals(['main', 'feature']));
      expect(configs['feature']!.hasGerritConfig, isFalse);
    });

    test('keeps branch names that contain dots intact', () async {
      await repo.createBranch('release/1.2.3');
      await repo.setBranchConfig('release/1.2.3', 'gerritissue', '333');
      await repo.setBranchConfig(
        'release/1.2.3',
        'gerritserver',
        'https://gerrit.test',
      );

      final configs = await GitServiceBatch.getBatchGerritConfig([
        'release/1.2.3',
      ]);

      expect(configs['release/1.2.3']!.gerritIssue, '333');
      expect(configs['release/1.2.3']!.gerritServer, 'https://gerrit.test');
    });

    test('preserves config values containing spaces', () async {
      await repo.setBranchConfig('main', 'gerritissue', '444');
      await repo.setBranchConfig(
        'main',
        'gerritserver',
        'https://gerrit.test/a b',
      );

      final configs = await GitServiceBatch.getBatchGerritConfig(['main']);

      expect(configs['main']!.gerritServer, 'https://gerrit.test/a b');
    });

    test(
      'returns empty configs when the repository has no Gerrit data',
      () async {
        final configs = await GitServiceBatch.getBatchGerritConfig(['main']);

        expect(configs, isEmpty);
      },
    );
  });
}

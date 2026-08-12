import 'package:test/test.dart';

import 'package:dgt/branch_status.dart';
import 'package:dgt/gerrit_service.dart';

import 'fixtures.dart';

void main() {
  group('BranchInfo.hasLocalChanges', () {
    test('is true when local HEAD differs from the last upload', () {
      final branch = makeBranch(localHash: 'aaa', lastUploadHash: 'bbb');

      expect(branch.hasLocalChanges(), isTrue);
    });

    test('is false when local HEAD matches the last upload', () {
      final branch = makeBranch(localHash: 'aaa', lastUploadHash: 'aaa');

      expect(branch.hasLocalChanges(), isFalse);
    });

    test('is false without Gerrit config, even with a last upload hash', () {
      final branch = makeBranch(
        localHash: 'aaa',
        lastUploadHash: 'bbb',
        gerritIssue: null,
        gerritServer: null,
      );

      expect(branch.hasLocalChanges(), isFalse);
    });

    test('is false when the last upload hash is missing or empty', () {
      expect(makeBranch(localHash: 'aaa').hasLocalChanges(), isFalse);
      expect(
        makeBranch(localHash: 'aaa', lastUploadHash: '').hasLocalChanges(),
        isFalse,
      );
    });
  });

  group('BranchInfo.hasRemoteChanges', () {
    test('is true when Gerrit revision differs from the squash hash', () {
      final branch = makeBranch(
        gerritSquashHash: 'ccc',
        change: makeChange(currentRevision: 'ddd'),
      );

      expect(branch.hasRemoteChanges(), isTrue);
    });

    test('is false when Gerrit revision matches the squash hash', () {
      final branch = makeBranch(
        gerritSquashHash: 'ccc',
        change: makeChange(currentRevision: 'ccc'),
      );

      expect(branch.hasRemoteChanges(), isFalse);
    });

    test('is false without a fetched change', () {
      final branch = makeBranch(gerritSquashHash: 'ccc');

      expect(branch.hasRemoteChanges(), isFalse);
    });

    test('is false when either hash is missing or empty', () {
      expect(
        makeBranch(
          change: makeChange(currentRevision: 'ddd'),
        ).hasRemoteChanges(),
        isFalse,
      );
      expect(
        makeBranch(
          gerritSquashHash: '',
          change: makeChange(currentRevision: 'ddd'),
        ).hasRemoteChanges(),
        isFalse,
      );
      expect(
        makeBranch(
          gerritSquashHash: 'ccc',
          change: makeChange(currentRevision: null),
        ).hasRemoteChanges(),
        isFalse,
      );
    });
  });

  group('BranchInfo.diverged', () {
    test('is the union of local and remote divergence', () {
      final localOnly = makeBranch(localHash: 'aaa', lastUploadHash: 'bbb');
      final remoteOnly = makeBranch(
        gerritSquashHash: 'ccc',
        change: makeChange(currentRevision: 'ddd'),
      );
      final both = makeBranch(
        localHash: 'aaa',
        lastUploadHash: 'bbb',
        gerritSquashHash: 'ccc',
        change: makeChange(currentRevision: 'ddd'),
      );
      final neither = makeBranch(
        localHash: 'aaa',
        lastUploadHash: 'aaa',
        gerritSquashHash: 'ccc',
        change: makeChange(currentRevision: 'ccc'),
      );

      expect(localOnly.diverged, isTrue);
      expect(remoteOnly.diverged, isTrue);
      expect(both.diverged, isTrue);
      expect(neither.diverged, isFalse);
    });
  });

  group('BranchInfo.branchStatus', () {
    test('is none when no Gerrit change was found', () {
      expect(makeBranch().branchStatus, BranchStatus.none);
      expect(makeBranch().getDisplayStatus(), BranchStatus.none.displayPrefix);
    });

    test('comes from the change when there is one', () {
      expect(
        makeBranch(change: makeChange(status: 'MERGED')).branchStatus,
        BranchStatus.merged,
      );
      expect(
        makeBranch(change: makeChange(mergeable: false)).branchStatus,
        BranchStatus.mergeConflict,
      );
    });

    test('is null when Gerrit reports a status we do not model', () {
      expect(
        makeBranch(change: makeChange(status: 'DRAFT')).branchStatus,
        isNull,
      );
    });

    test('is unaffected by the detail in the displayed text', () {
      final branch = makeBranch(
        change: makeChange(
          lgtm: LgtmStatus(approved: true, positiveVotes: 1, negativeVotes: 0),
        ),
      );

      expect(branch.getDisplayStatus(), 'Active (LGTM +1)');
      expect(branch.branchStatus, BranchStatus.active);
    });
  });

  group('BranchInfo display getters', () {
    test('fall back to "-" when there is no change or URL', () {
      final branch = makeBranch();

      expect(branch.getDisplayStatus(), '-');
      expect(branch.getGerritHash(), '-');
      expect(branch.getGerritDate(), '-');
      expect(branch.getGerritUrl(), '-');
    });

    test('surface the change values when one was fetched', () {
      final branch = makeBranch(
        change: makeChange(
          status: 'MERGED',
          currentRevision: 'rev9',
          updated: '2025-10-02 08:00:00.000000000',
        ),
        gerritUrl: 'https://gerrit.test/c/1',
      );

      expect(branch.getDisplayStatus(), 'Merged');
      expect(branch.getGerritHash(), 'rev9');
      expect(branch.getGerritDate(), '2025-10-02 08:00:00.000000000');
      expect(branch.getGerritUrl(), 'https://gerrit.test/c/1');
    });
  });
}

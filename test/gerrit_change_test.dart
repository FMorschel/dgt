import 'package:dgt/branch_status.dart';
import 'package:dgt/gerrit_service.dart';
import 'package:test/test.dart';

import 'fake_gerrit_server.dart';

void main() {
  group('LgtmStatus.toString', () {
    test('renders positive, negative, mixed and empty vote counts', () {
      expect(LgtmStatus.empty().toString(), '');
      expect(
        LgtmStatus(
          approved: false,
          positiveVotes: 2,
          negativeVotes: 0,
        ).toString(),
        '+2',
      );
      expect(
        LgtmStatus(
          approved: false,
          positiveVotes: 0,
          negativeVotes: 3,
        ).toString(),
        '-3',
      );
      expect(
        LgtmStatus(
          approved: false,
          positiveVotes: 1,
          negativeVotes: 1,
        ).toString(),
        '+1/-1',
      );
    });

    test('ignores the approved flag, which only affects status text', () {
      expect(
        LgtmStatus(
          approved: true,
          positiveVotes: 0,
          negativeVotes: 0,
        ).toString(),
        '',
      );
    });
  });

  group('GerritChange.fromJson', () {
    test('counts positive and negative Code-Review votes separately', () {
      final change = GerritChange.fromJson(
        gerritChangeJson(
          number: '1',
          approved: true,
          codeReviewVotes: const [1, 2, -1, 0],
        ),
      );

      expect(change.lgtm.approved, isTrue);
      expect(change.lgtm.positiveVotes, 2);
      expect(change.lgtm.negativeVotes, 1);
    });

    test('treats a change with only the owner as reviewer as unsent', () {
      final change = GerritChange.fromJson(gerritChangeJson(number: '1'));

      expect(change.unsent, isTrue);
      expect(change.getUserFriendlyStatus(), 'Active (Unsent)');
    });

    test('is sent once somebody other than the owner is a reviewer', () {
      final change = GerritChange.fromJson(
        gerritChangeJson(number: '1', reviewerIds: const [2001]),
      );

      expect(change.unsent, isFalse);
    });

    test('takes the highest Commit-Queue vote', () {
      final change = GerritChange.fromJson(
        gerritChangeJson(number: '1', commitQueueVotes: const [0, 2, 1]),
      );

      expect(change.commitQueueStatus, 2);
    });

    test('sorts messages by date', () {
      final json = gerritChangeJson(
        number: '1',
        messages: const [
          (authorId: 1000, tag: 'first'),
          (authorId: 2001, tag: 'second'),
        ],
      );
      // Reverse them on the wire; parsing must put them back in date order.
      json['messages'] = (json['messages']! as List<dynamic>).reversed.toList();

      final change = GerritChange.fromJson(json);

      expect(change.messages.map((message) => message['tag']), [
        'first',
        'second',
      ]);
    });

    test('defaults sensibly when optional fields are absent', () {
      final change = GerritChange.fromJson(<String, dynamic>{
        'change_id': 'I1',
        'status': 'NEW',
        'updated': '2025-10-01 12:00:00.000000000',
      });

      expect(change.workInProgress, isFalse);
      expect(change.mergeable, isTrue);
      expect(change.currentRevision, isNull);
      expect(change.ownerId, isNull);
      expect(change.commitQueueStatus, 0);
      expect(change.messages, isEmpty);
      expect(change.lgtm.approved, isFalse);
      // Without a reviewers map the change is not reported as unsent.
      expect(change.unsent, isFalse);
    });
  });

  group('GerritChange.branchStatus', () {
    GerritChange change({
      String status = 'NEW',
      bool workInProgress = false,
      bool mergeable = true,
    }) {
      return GerritChange.fromJson(
        gerritChangeJson(
          number: '1',
          status: status,
          workInProgress: workInProgress,
        ),
      ).copyWithMergeable(mergeable);
    }

    test('reports the state behind the displayed text', () {
      expect(change(status: 'MERGED').branchStatus, BranchStatus.merged);
      expect(change(status: 'ABANDONED').branchStatus, BranchStatus.abandoned);
      expect(change(mergeable: false).branchStatus, BranchStatus.mergeConflict);
      expect(change(workInProgress: true).branchStatus, BranchStatus.wip);
      expect(change().branchStatus, BranchStatus.active);
    });

    test('follows the same priority order as the displayed text', () {
      // Merged outranks a conflict; a conflict outranks WIP.
      expect(
        change(status: 'MERGED', mergeable: false).branchStatus,
        BranchStatus.merged,
      );
      expect(
        change(mergeable: false, workInProgress: true).branchStatus,
        BranchStatus.mergeConflict,
      );
    });

    test('is null for a status this tool does not model', () {
      expect(change(status: 'DRAFT').branchStatus, isNull);
    });

    test('ignores the detail that decorates the displayed text', () {
      // Two changes that display differently are the same state.
      final unsent = GerritChange.fromJson(gerritChangeJson(number: '1'));
      final sent = GerritChange.fromJson(
        gerritChangeJson(number: '1', reviewerIds: const [2001]),
      );

      expect(unsent.getUserFriendlyStatus(), 'Active (Unsent)');
      expect(sent.getUserFriendlyStatus(), 'Active');
      expect(unsent.branchStatus, BranchStatus.active);
      expect(sent.branchStatus, BranchStatus.active);
    });

    test('agrees with the text it produces', () {
      for (final status in ['NEW', 'MERGED', 'ABANDONED']) {
        for (final wip in [true, false]) {
          for (final mergeable in [true, false]) {
            final result = change(
              status: status,
              workInProgress: wip,
              mergeable: mergeable,
            );

            expect(
              result.getUserFriendlyStatus(),
              startsWith(result.branchStatus!.displayPrefix),
              reason: 'status: $status, wip: $wip, mergeable: $mergeable',
            );
          }
        }
      }
    });
  });

  group('GerritChange.getUserFriendlyStatus', () {
    GerritChange change({
      String status = 'NEW',
      bool workInProgress = false,
      bool mergeable = true,
      bool approved = false,
      List<int> codeReviewVotes = const [],
      List<int> commitQueueVotes = const [],
      List<int> reviewerIds = const [2001],
      List<ChangeMessage> messages = const [],
    }) {
      return GerritChange.fromJson(
        gerritChangeJson(
          number: '1',
          status: status,
          workInProgress: workInProgress,
          approved: approved,
          codeReviewVotes: codeReviewVotes,
          commitQueueVotes: commitQueueVotes,
          reviewerIds: reviewerIds,
          messages: messages,
        ),
      ).copyWithMergeable(mergeable);
    }

    test('merged and abandoned outrank everything else', () {
      expect(
        change(status: 'MERGED', mergeable: false).getUserFriendlyStatus(),
        'Merged',
      );
      expect(
        change(
          status: 'ABANDONED',
          workInProgress: true,
        ).getUserFriendlyStatus(),
        'Abandoned',
      );
    });

    test('merge conflicts are qualified by WIP, LGTM and unsent', () {
      expect(
        change(mergeable: false, workInProgress: true).getUserFriendlyStatus(),
        'Merge conflict (WIP)',
      );
      expect(
        change(
          mergeable: false,
          approved: true,
          codeReviewVotes: const [1],
        ).getUserFriendlyStatus(),
        'Merge conflict (LGTM +1)',
      );
      expect(
        change(mergeable: false, reviewerIds: const []).getUserFriendlyStatus(),
        'Merge conflict (Unsent)',
      );
      expect(
        change(mergeable: false).getUserFriendlyStatus(),
        'Merge conflict',
      );
    });

    test('unsent is reported before the message history is consulted', () {
      // Uploading a patch set posts an owner-authored message, which would
      // otherwise read as "waiting for reviewers" on a change nobody was
      // ever added to.
      final result = change(
        reviewerIds: const [],
        messages: const [(authorId: 1000, tag: '')],
      );

      expect(result.getUserFriendlyStatus(), 'Active (Unsent)');
    });

    test('ignores autogenerated CQ and CV messages', () {
      final result = change(
        messages: const [
          (authorId: 2001, tag: ''),
          (authorId: 1000, tag: 'autogenerated:cq-do-not-match'),
          (authorId: 1000, tag: 'autogenerated:cv-do-not-match'),
        ],
      );

      // The last human message is the reviewer's, so the owner must reply.
      expect(result.getUserFriendlyStatus(), 'Active (Reply)');
    });

    test('reports plain Active when no message history exists', () {
      expect(change().getUserFriendlyStatus(), 'Active');
    });

    test('commit queue +2 wins over the message history', () {
      final result = change(
        commitQueueVotes: const [2],
        messages: const [(authorId: 2001, tag: '')],
      );

      expect(result.getUserFriendlyStatus(), 'Active (Commit)');
    });

    test('falls back to the raw status for anything unexpected', () {
      expect(change(status: 'DRAFT').getUserFriendlyStatus(), 'DRAFT');
    });
  });

  group('GerritService.getChangeUrl', () {
    test('builds a change URL', () {
      expect(
        GerritService.getChangeUrl('https://gerrit.test', '389423'),
        'https://gerrit.test/c/389423',
      );
    });

    test('strips a trailing slash from the server', () {
      expect(
        GerritService.getChangeUrl('https://gerrit.test/', '389423'),
        'https://gerrit.test/c/389423',
      );
    });

    test('returns null for missing or empty inputs', () {
      expect(GerritService.getChangeUrl(null, '389423'), isNull);
      expect(GerritService.getChangeUrl('', '389423'), isNull);
      expect(GerritService.getChangeUrl('https://gerrit.test', null), isNull);
      expect(GerritService.getChangeUrl('https://gerrit.test', ''), isNull);
    });
  });
}

/// [GerritChange] has no `copyWith`, and `mergeable` is not part of the batch
/// query payload, so rebuild the change with the flag the mergeable endpoint
/// would have supplied.
extension on GerritChange {
  GerritChange copyWithMergeable(bool mergeable) {
    return GerritChange(
      changeId: changeId,
      status: status,
      workInProgress: workInProgress,
      mergeable: mergeable,
      updated: updated,
      currentRevision: currentRevision,
      lgtm: lgtm,
      unsent: unsent,
      commitQueueStatus: commitQueueStatus,
      messages: messages,
      ownerId: ownerId,
    );
  }
}

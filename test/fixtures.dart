import 'package:dgt/branch_info.dart';
import 'package:dgt/gerrit_service.dart';
import 'package:dgt/git_service.dart';

/// Builds a [GerritChange] directly, skipping JSON parsing.
///
/// Defaults describe a plain open change that has been sent for review, so
/// tests only state the fields they actually care about.
GerritChange makeChange({
  String changeId = 'I1',
  String status = 'NEW',
  bool workInProgress = false,
  bool mergeable = true,
  String updated = '2025-10-01 12:00:00.000000000',
  String? currentRevision = 'rev1',
  LgtmStatus? lgtm,
  bool unsent = false,
  int commitQueueStatus = 0,
  List<Map<String, dynamic>> messages = const [],
  int? ownerId = 1000,
}) {
  return GerritChange(
    changeId: changeId,
    status: status,
    workInProgress: workInProgress,
    mergeable: mergeable,
    updated: updated,
    currentRevision: currentRevision,
    lgtm: lgtm ?? LgtmStatus.empty(),
    unsent: unsent,
    commitQueueStatus: commitQueueStatus,
    messages: messages,
    ownerId: ownerId,
  );
}

/// Builds a [BranchInfo] with Gerrit config attached by default.
///
/// Pass `gerritIssue: null` (or `gerritServer: null`) to model a local-only
/// branch, which is what `--status local` selects on.
BranchInfo makeBranch({
  String name = 'branch',
  String localHash = 'localhash',
  String localDate = '2025-10-01T12:00:00Z',
  String? gerritIssue = '1',
  String? gerritServer = 'https://gerrit.test',
  String? gerritSquashHash,
  String? lastUploadHash,
  GerritChange? change,
  String? gerritUrl,
}) {
  return BranchInfo(
    branchName: name,
    localHash: localHash,
    localDate: localDate,
    gerritConfig: GerritBranchConfig(
      gerritIssue: gerritIssue,
      gerritServer: gerritServer,
      gerritSquashHash: gerritSquashHash,
      lastUploadHash: lastUploadHash,
    ),
    gerritChange: change,
    gerritUrl: gerritUrl,
  );
}

/// A branch whose display status is "Merged".
BranchInfo mergedBranch({String name = 'merged'}) => makeBranch(
  name: name,
  change: makeChange(status: 'MERGED'),
);

/// A branch whose display status is "Abandoned".
BranchInfo abandonedBranch({String name = 'abandoned'}) => makeBranch(
  name: name,
  change: makeChange(status: 'ABANDONED'),
);

/// A branch whose display status is "WIP".
BranchInfo wipBranch({String name = 'wip'}) =>
    makeBranch(name: name, change: makeChange(workInProgress: true));

/// A branch whose display status is "Active".
BranchInfo activeBranch({String name = 'active'}) =>
    makeBranch(name: name, change: makeChange());

/// A branch whose display status is "Active (LGTM +1)", i.e. a decorated
/// status that only matches "Active" by prefix.
BranchInfo lgtmBranch({String name = 'lgtm'}) => makeBranch(
  name: name,
  change: makeChange(
    lgtm: LgtmStatus(approved: true, positiveVotes: 1, negativeVotes: 0),
  ),
);

/// A branch whose display status is "Merge conflict".
BranchInfo conflictBranch({String name = 'conflict'}) =>
    makeBranch(name: name, change: makeChange(mergeable: false));

/// A branch with no Gerrit configuration, displayed as "-".
BranchInfo localOnlyBranch({String name = 'local-only'}) =>
    makeBranch(name: name, gerritIssue: null, gerritServer: null);

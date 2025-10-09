import 'gerrit_service.dart';
import 'git_service.dart';

/// Represents information about a Git branch including both local
/// and Gerrit change data.
///
/// This class combines data from the local Git repository with
/// information from Gerrit code review system.
class BranchInfo {

  BranchInfo({
    required this.branchName,
    required this.localHash,
    required this.localDate,
    required this.gerritConfig,
    required this.gerritChange,
  });
  /// The name of the branch
  final String branchName;

  /// The local commit hash
  final String localHash;

  /// The local commit date (in ISO 8601 format from git log)
  final String localDate;

  /// The Gerrit configuration from Git config
  final GerritBranchConfig gerritConfig;

  /// The Gerrit change object (nullable if no Gerrit change found)
  final GerritChange? gerritChange;

  /// Gets the user-friendly status for display.
  /// Returns the Gerrit status or "-" if no Gerrit change exists.
  String getDisplayStatus() {
    if (gerritChange == null) {
      return '-';
    }
    return gerritChange!.getUserFriendlyStatus();
  }

  /// Gets the Gerrit commit hash for display.
  /// Returns the current revision from Gerrit or "-" if not available.
  String getGerritHash() {
    return gerritChange?.currentRevision ?? '-';
  }

  /// Gets the Gerrit updated date for display.
  /// Returns the updated timestamp from Gerrit or "-" if not available.
  String getGerritDate() {
    return gerritChange?.updated ?? '-';
  }
}

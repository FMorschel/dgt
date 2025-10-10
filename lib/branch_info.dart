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

  /// Checks if this branch has local changes not yet uploaded to Gerrit.
  ///
  /// Returns true when the local HEAD commit differs from the last uploaded
  /// commit (as tracked by `last-upload-hash` in Git config).
  ///
  /// This indicates that you have made new commits locally since the last
  /// upload to Gerrit, and you should upload your changes.
  ///
  /// Returns false if:
  /// - No Gerrit config exists (branch not associated with Gerrit)
  /// - last-upload-hash is not set in config
  /// - Local HEAD matches the last upload hash (in sync)
  bool hasLocalChanges() {
    // No Gerrit config means no tracking of uploads
    if (!gerritConfig.hasGerritConfig) {
      return false;
    }

    // If last-upload-hash is not set, we can't determine if there are local
    // changes. Treat as no local changes to avoid false positives
    final lastUpload = gerritConfig.lastUploadHash;
    if (lastUpload == null || lastUpload.isEmpty) {
      return false;
    }

    // Compare local HEAD with last upload hash
    // If they differ, we have local changes not yet uploaded
    return localHash != lastUpload;
  }

  /// Checks if Gerrit has changes that differ from the local branch state.
  ///
  /// Returns true when Gerrit's current revision differs from the squash hash
  /// stored in Git config (gerritsquashhash).
  ///
  /// This indicates that:
  /// - The Gerrit change has been updated (new patchset, rebase, amend)
  /// - Your local branch is based on an older version of the change
  /// - You may need to pull/rebase to get the latest changes
  ///
  /// Returns false if:
  /// - No Gerrit change exists
  /// - gerritsquashhash is not set in config
  /// - Gerrit's current revision matches the squash hash (in sync)
  bool hasRemoteChanges() {
    // No Gerrit change means no remote to compare against
    if (gerritChange == null) {
      return false;
    }

    // If gerritsquashhash is not set, we can't determine if there are remote
    // changes. Treat as no remote changes to avoid false positives
    final squashHash = gerritConfig.gerritSquashHash;
    if (squashHash == null || squashHash.isEmpty) {
      return false;
    }

    // Get Gerrit's current revision
    final gerritRevision = gerritChange!.currentRevision;
    if (gerritRevision == null || gerritRevision.isEmpty) {
      return false;
    }

    // Compare Gerrit's current revision with the squash hash from config
    // If they differ, Gerrit has been updated since our last sync
    return gerritRevision != squashHash;
  }

  /// Checks if this branch has diverged from its Gerrit state.
  ///
  /// Returns true if the branch has either local changes not yet uploaded
  /// or remote changes not yet pulled/rebased.
  ///
  /// This is a convenience method equivalent to:
  /// `hasLocalChanges() || hasRemoteChanges()`
  bool get diverged => hasLocalChanges() || hasRemoteChanges();
}

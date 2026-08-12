/// The state a branch is in, and the single source of truth for the status
/// vocabulary shared by filtering, sorting and the CLI.
///
/// This is what code should decide on. `GerritChange.getUserFriendlyStatus`
/// derives the displayed text from it — `Active (LGTM +1)`, `Merge conflict
/// (WIP)` — and only the Status column should depend on that wording.
enum BranchStatus {
  /// Work in progress, not yet ready for review.
  wip(
    displayPrefix: 'WIP',
    sortPriority: 1,
    cliValue: 'wip',
    description: 'Work in Progress',
  ),

  /// Open and ready for review.
  active(
    displayPrefix: 'Active',
    sortPriority: 2,
    cliValue: 'active',
    description: 'Ready for review',
  ),

  /// Landed.
  merged(
    displayPrefix: 'Merged',
    sortPriority: 3,
    cliValue: 'merged',
    description: 'Successfully merged',
  ),

  /// Abandoned by its owner.
  abandoned(
    displayPrefix: 'Abandoned',
    sortPriority: 4,
    cliValue: 'abandoned',
    description: 'Abandoned changes',
  ),

  /// Cannot be merged without resolving conflicts. Sorts first because it is
  /// the state that needs attention soonest.
  mergeConflict(
    displayPrefix: 'Merge conflict',
    sortPriority: 0,
    cliValue: 'conflict',
    description: 'Has merge conflicts',
  ),

  /// A branch with no Gerrit change attached. Not selectable via `--status`;
  /// use the `local` filter for those branches instead.
  none(displayPrefix: '-', sortPriority: 5);

  const BranchStatus({
    required this.displayPrefix,
    required this.sortPriority,
    this.cliValue,
    this.description,
  });

  /// Every state a Gerrit change can be in, i.e. all but [none].
  static final List<BranchStatus> gerritStatuses = [
    for (final status in values)
      if (status != BranchStatus.none) status,
  ];

  /// Finds the status a `--status` value selects, ignoring case.
  ///
  /// Returns null for the special `gerrit` and `local` values, which select
  /// groups of branches rather than a single status.
  static BranchStatus? fromCliValue(String value) {
    final lowerValue = value.toLowerCase();
    for (final status in values) {
      if (status.cliValue == lowerValue) {
        return status;
      }
    }
    return null;
  }

  /// The text a displayed status starts with, e.g. `Merge conflict`.
  final String displayPrefix;

  /// Position in the `--sort status` order; lower sorts first.
  ///
  /// Kept separate from the declaration order so the CLI can list statuses in
  /// its own order without changing how they sort.
  final int sortPriority;

  /// The `--status` value that selects this status, if any.
  final String? cliValue;

  /// Help text shown for [cliValue].
  final String? description;
}

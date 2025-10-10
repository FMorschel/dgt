import 'branch_info.dart';

/// Options for sorting branches.
class SortOptions {
  SortOptions({this.field, this.direction});

  /// Field to sort by.
  final String? field;

  /// Sort direction: 'asc' for ascending, 'desc' for descending.
  final String? direction;

  /// Returns true if no sort options are active.
  bool get isEmpty => field == null || field!.isEmpty;

  /// Returns true if direction is descending.
  bool get isDescending => direction == 'desc';

  /// Returns true if direction is ascending (default when field is set).
  bool get isAscending => !isDescending;
}

/// Allowed sort field values.
const List<String> allowedSortFields = [
  'local-date',
  'gerrit-date',
  'status',
  'divergences',
  'name',
];

/// Human-readable descriptions for sort fields.
const Map<String, String> sortFieldDescriptions = {
  'local-date': 'Local commit date',
  'gerrit-date': 'Gerrit update date',
  'status': 'Gerrit status',
  'divergences': 'Divergence state (both, one side, in sync)',
  'name': 'Branch name',
};

/// Validates sort field against allowed values.
///
/// Throws FormatException if field is invalid.
void validateSortField(String field) {
  if (!allowedSortFields.contains(field.toLowerCase())) {
    final allowedValues = allowedSortFields
        .map((key) {
          return '$key (${sortFieldDescriptions[key]})';
        })
        .join('\n    ');

    throw FormatException(
      'Invalid sort field: "$field".\n'
      'Allowed values:\n'
      '    $allowedValues',
    );
  }
}

/// Validates sort direction.
///
/// Throws FormatException if direction is invalid.
void validateSortDirection(String direction) {
  if (direction != 'asc' && direction != 'desc') {
    throw FormatException(
      'Invalid sort direction: "$direction".\n'
      'Allowed values: asc, desc',
    );
  }
}

/// Computes a divergence score for sorting.
///
/// Returns:
/// - 2 = both sides diverged (local and remote changes)
/// - 1 = one side diverged (either local or remote changes)
/// - 0 = in sync (no changes)
int _getDivergenceScore(BranchInfo branch) {
  final hasLocal = branch.hasLocalChanges();
  final hasRemote = branch.hasRemoteChanges();

  if (hasLocal && hasRemote) {
    return 2; // Both diverged
  } else if (hasLocal || hasRemote) {
    return 1; // One side diverged
  } else {
    return 0; // In sync
  }
}

/// Applies sorting to a list of branches.
///
/// Returns the sorted list of branches.
List<BranchInfo> applySort(List<BranchInfo> branches, SortOptions sortOptions) {
  if (sortOptions.isEmpty) {
    return branches;
  }

  // Create a copy to avoid modifying the original list
  final sorted = List<BranchInfo>.from(branches);

  // Determine sort direction multiplier
  final multiplier = sortOptions.isDescending ? -1 : 1;

  // Sort based on field
  switch (sortOptions.field!.toLowerCase()) {
    case 'local-date':
      sorted.sort((a, b) {
        try {
          final dateA = DateTime.parse(a.localDate);
          final dateB = DateTime.parse(b.localDate);
          return multiplier * dateA.compareTo(dateB);
        } catch (e) {
          // If dates can't be parsed, treat them as equal
          return 0;
        }
      });

    case 'gerrit-date':
      sorted.sort((a, b) {
        final dateA = a.gerritChange?.updated;
        final dateB = b.gerritChange?.updated;

        // Handle null dates (put them at the end)
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;

        try {
          final parsedA = DateTime.parse(dateA);
          final parsedB = DateTime.parse(dateB);
          return multiplier * parsedA.compareTo(parsedB);
        } catch (e) {
          return 0;
        }
      });

    case 'status':
      // Define status priority for sorting
      const statusPriority = {
        'Merge conflict': 0,
        'WIP': 1,
        'Active': 2,
        'Merged': 3,
        '-': 4, // Branches without Gerrit status
      };

      sorted.sort((a, b) {
        final statusA = a.getDisplayStatus();
        final statusB = b.getDisplayStatus();
        final priorityA = statusPriority[statusA] ?? 99;
        final priorityB = statusPriority[statusB] ?? 99;
        return multiplier * priorityA.compareTo(priorityB);
      });

    case 'divergences':
      sorted.sort((a, b) {
        final scoreA = _getDivergenceScore(a);
        final scoreB = _getDivergenceScore(b);
        return multiplier * scoreA.compareTo(scoreB);
      });

    case 'name':
      sorted.sort((a, b) {
        return multiplier * a.branchName.compareTo(b.branchName);
      });

    default:
      // Should never happen due to validation, but handle gracefully
      return branches;
  }

  return sorted;
}

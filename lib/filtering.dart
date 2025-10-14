import 'branch_info.dart';

/// Options for filtering branches.
class FilterOptions {
  FilterOptions({this.statuses, this.since, this.before, this.diverged});

  /// Filter by Gerrit status (can have multiple statuses).
  final List<String>? statuses;

  /// Filter branches with commits after this date (ISO 8601 format).
  final DateTime? since;

  /// Filter branches with commits before this date (ISO 8601 format).
  final DateTime? before;

  /// Filter to show only diverged branches (with local or remote differences).
  final bool? diverged;

  /// Returns true if no filters are active.
  bool get isEmpty =>
      (statuses == null || statuses!.isEmpty) &&
      since == null &&
      before == null &&
      (diverged == null || !diverged!);
}

/// Validates and parses date string in ISO 8601 format.
///
/// Returns the parsed DateTime or null if invalid.
/// Throws FormatException with helpful message if parsing fails.
DateTime? parseDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) {
    return null;
  }

  try {
    return DateTime.parse(dateStr);
  } catch (e) {
    throw FormatException(
      'Invalid date format: "$dateStr". Expected ISO 8601 format '
      '(e.g., 2025-10-10 or 2025-10-10T14:30:00)',
    );
  }
}

/// Maps CLI-friendly status values to display values.
const Map<String, String> statusMapping = {
  'wip': 'WIP',
  'active': 'Active',
  'merged': 'Merged',
  'abandoned': 'Abandoned',
  'conflict': 'Merge conflict',
};

/// Human-readable descriptions for status values.
const Map<String, String> statusDescriptions = {
  'wip': 'Work in Progress',
  'active': 'Ready for review',
  'merged': 'Successfully merged',
  'abandoned': 'Abandoned changes',
  'conflict': 'Has merge conflicts',
};

/// All accepted Gerrit status values (for --status all)
const List<String> allGerritStatuses = [
  'WIP',
  'Active',
  'Merged',
  'Abandoned',
  'Merge conflict',
];

/// Special status value to indicate local-only branches
const String localStatusValue = 'local';

/// Validates status value against allowed values.
///
/// Throws FormatException if status is invalid.
/// Allows special values: 'all' and 'local'
void validateStatus(String status) {
  final lowerStatus = status.toLowerCase();

  // Allow special status values
  if (lowerStatus == 'all' || lowerStatus == 'local') {
    return;
  }

  if (!statusMapping.containsKey(lowerStatus)) {
    final allowedValues = statusMapping.keys
        .map((key) {
          return '$key (${statusDescriptions[key]})';
        })
        .join('\n    ');

    throw FormatException(
      'Invalid status: "$status".\n'
      'Allowed values:\n'
      '    $allowedValues\n'
      '    all (All Gerrit statuses)\n'
      '    local (Branches without Gerrit configuration)',
    );
  }
}

/// Applies filters to a list of branches.
///
/// Filters are applied in this order:
/// 1. Status filter (if specified)
/// 2. Date filters (since/before, if specified)
/// 3. Diverged filter (if specified)
///
/// Returns the filtered list of branches.
List<BranchInfo> applyFilters(
  List<BranchInfo> branches,
  FilterOptions filters,
) {
  if (filters.isEmpty) {
    return branches;
  }

  var filtered = branches;

  // Apply status filter
  if (filters.statuses != null && filters.statuses!.isNotEmpty) {
    // Check if 'all' is in the statuses
    final hasAll = filters.statuses!.any((s) => s.toLowerCase() == 'all');

    // Check if 'local' is in the statuses
    final hasLocal = filters.statuses!.any((s) => s.toLowerCase() == 'local');

    // Get the regular status filters (excluding 'all' and 'local')
    final regularStatuses = filters.statuses!
        .where((s) => s.toLowerCase() != 'all' && s.toLowerCase() != 'local')
        .map((s) => statusMapping[s.toLowerCase()] ?? s)
        .toList();

    // Build the combined status list
    final displayStatuses = <String>[];

    if (hasAll) {
      // Add all Gerrit statuses
      displayStatuses.addAll(allGerritStatuses);
    }

    // Add regular statuses (if not already included via 'all')
    for (final status in regularStatuses) {
      if (!displayStatuses.contains(status)) {
        displayStatuses.add(status);
      }
    }

    filtered = filtered.where((branch) {
      // Handle 'local' status (branches without Gerrit config)
      final hasGerritConfig = branch.gerritConfig.hasGerritConfig;

      if (hasLocal && !hasGerritConfig) {
        return true;
      }

      // If 'all' is specified, include all branches with Gerrit config
      if (hasAll && hasGerritConfig) {
        return true;
      }

      // Handle regular Gerrit statuses
      if (displayStatuses.isNotEmpty && hasGerritConfig) {
        final status = branch.getDisplayStatus();
        return displayStatuses.contains(status);
      }

      return false;
    }).toList();
  }

  // Apply date filters
  if (filters.since != null || filters.before != null) {
    filtered = filtered.where((branch) {
      // Parse the branch's local date (ISO 8601 format from git log)
      try {
        final branchDate = DateTime.parse(branch.localDate);

        if (filters.since != null && branchDate.isBefore(filters.since!)) {
          return false;
        }

        if (filters.before != null && branchDate.isAfter(filters.before!)) {
          return false;
        }

        return true;
      } catch (e) {
        // If we can't parse the date, keep the branch (don't filter it out)
        return true;
      }
    }).toList();
  }

  // Apply diverged filter
  if (filters.diverged ?? false) {
    filtered = filtered.where((branch) => branch.diverged).toList();
  }

  return filtered;
}

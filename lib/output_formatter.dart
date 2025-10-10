import 'branch_info.dart';
import 'performance_tracker.dart';
import 'terminal.dart';

/// Handles formatting and displaying branch information in a table format.
class OutputFormatter {
  /// Formats and displays a list of branch information.
  ///
  /// [branchInfoList] - List of BranchInfo objects to display
  /// [verbose] - Whether to show verbose output
  /// [showGerrit] - Whether to display Gerrit hash and date columns
  /// [showLocal] - Whether to display local hash and date columns
  static void displayBranchTable(
    List<BranchInfo> branchInfoList, {
    bool verbose = false,
    bool showGerrit = true,
    bool showLocal = true,
  }) {
    if (branchInfoList.isEmpty) {
      Terminal.info('No branches found.');
      return;
    }

    // Define column headers and widths based on what should be displayed
    final headers = <String>['Branch Name', 'Status'];
    final columnWidths = <int>[20, 17];

    if (showLocal) {
      headers.addAll(['Local Hash', 'Local Date']);
      columnWidths.addAll([12, 17]);
    }

    if (showGerrit) {
      headers.addAll(['Gerrit Hash', 'Gerrit Date']);
      columnWidths.addAll([12, 17]);
    }

    // Print header
    _printTableHeader(headers, columnWidths);
    _printSeparatorLine(columnWidths);

    // Print each branch as a row
    for (final branchInfo in branchInfoList) {
      _printBranchRow(branchInfo, columnWidths, showGerrit, showLocal);
    }

    // Print summary
    Terminal.info('');
    Terminal.info('Total: ${branchInfoList.length} branch(es)');
  }

  /// Prints the table header row.
  static void _printTableHeader(List<String> headers, List<int> columnWidths) {
    final headerRow = StringBuffer();
    for (var i = 0; i < headers.length; i++) {
      headerRow.write(_padString(headers[i], columnWidths[i]));
      if (i < headers.length - 1) {
        headerRow.write(' | ');
      }
    }
    Terminal.info(headerRow.toString());
  }

  /// Prints a separator line between header and data.
  static void _printSeparatorLine(List<int> columnWidths) {
    final separator = StringBuffer();
    for (var i = 0; i < columnWidths.length; i++) {
      separator.write('-' * columnWidths[i]);
      if (i < columnWidths.length - 1) {
        separator.write('-+-');
      }
    }
    Terminal.info(separator.toString());
  }

  /// Prints a single branch as a table row with color coding.
  ///
  /// This method handles the complex logic of displaying branch information
  /// with:
  /// - Status-based color coding (green for Active, yellow for WIP, etc.)
  /// - Difference highlighting using Git config metadata:
  ///   * Yellow local hash: local HEAD ≠ last-upload-hash (unpushed changes)
  ///   * Yellow Gerrit hash: gerritsquashhash ≠ Gerrit current_revision
  ///     (remote updates)
  /// - Mixed-color output within a single row (different parts can have
  ///   different colors)
  /// - Arrow indicators in status column: ↑ for local changes, ↓ for remote
  ///   changes
  ///
  /// The highlighting logic helps users quickly identify:
  /// - Branches where local changes need to be uploaded to Gerrit
  /// - Branches where Gerrit has updates that need to be pulled/rebased locally
  static void _printBranchRow(
    BranchInfo branchInfo,
    List<int> columnWidths,
    bool showGerrit,
    bool showLocal,
  ) {
    final status = branchInfo.getDisplayStatus();

    // Check for sync state differences using Git config metadata
    // These checks use last-upload-hash and gerritsquashhash for accurate
    // detection
    final hasLocalChanges = branchInfo.hasLocalChanges();
    final hasRemoteChanges = branchInfo.hasRemoteChanges();

    // Format the data
    final branchName = _padString(branchInfo.branchName, columnWidths[0]);

    // Build status string with arrow indicators as last characters
    // Pad the status first, then replace trailing spaces with arrows
    var statusStr = _padString(status, columnWidths[1]);

    // Add arrows at the end of the column (replacing padding spaces)
    var arrowSuffix = '';
    if (hasLocalChanges) {
      arrowSuffix += '↑'; // Upward arrow for local changes to upload
    }
    if (hasRemoteChanges) {
      arrowSuffix += '↓'; // Downward arrow for remote changes to pull
    }

    if (arrowSuffix.isNotEmpty) {
      // Replace the last characters of the padded string with arrows
      final statusLength = status.length;
      final paddingLength = columnWidths[1] - statusLength - arrowSuffix.length;
      if (paddingLength >= 0) {
        statusStr = status + (' ' * paddingLength) + arrowSuffix;
      } else {
        // If status is too long, just append arrows
        statusStr = status + arrowSuffix;
      }
    }

    // Track column index as we build the row
    var colIndex = 2;

    String? localHash;
    String? localDate;
    if (showLocal) {
      localHash = _padString(
        _truncateHash(branchInfo.localHash),
        columnWidths[colIndex],
      );
      localDate = _padString(
        _formatDate(branchInfo.localDate),
        columnWidths[colIndex + 1],
      );
      colIndex += 2;
    }

    String? gerritHash;
    String? gerritDate;
    if (showGerrit) {
      gerritHash = _padString(
        _truncateHash(branchInfo.getGerritHash()),
        columnWidths[colIndex],
      );
      gerritDate = _padString(
        _formatDate(branchInfo.getGerritDate()),
        columnWidths[colIndex + 1],
      );
    }

    // Build the row with highlighting for differences
    _printRowWithHighlighting(
      branchName,
      statusStr,
      localHash,
      localDate,
      gerritHash,
      gerritDate,
      status,
      hasLocalChanges,
      hasRemoteChanges,
      showLocal,
      showGerrit,
    );
  }

  /// Prints a row with color coding and highlights differences.
  ///
  /// This method creates a single table row with mixed colors:
  /// - Most of the row uses the status color (green/yellow/red/cyan)
  /// - Local hash and date are highlighted in yellow if there are unpushed
  /// local changes
  /// - Gerrit hash and date are highlighted in yellow if Gerrit has remote
  /// updates
  ///
  /// The mixed-color approach is achieved by building the row as separate
  /// colored string segments and concatenating them with print().
  ///
  /// Terminal color codes work by wrapping text in ANSI escape sequences,
  /// so we can mix different colored segments in a single print statement.
  ///
  /// [hasLocalChanges] - True when local HEAD ≠ last-upload-hash
  /// [hasRemoteChanges] - True when gerritsquashhash ≠ Gerrit current_revision
  static void _printRowWithHighlighting(
    String branchName,
    String statusStr,
    String? localHash,
    String? localDate,
    String? gerritHash,
    String? gerritDate,
    String status,
    bool hasLocalChanges,
    bool hasRemoteChanges,
    bool showLocal,
    bool showGerrit,
  ) {
    // Get the appropriate color function for the status
    var colorText = _getStatusColorTextFunction(status);

    // Build the row parts with appropriate coloring
    final rowParts = <String>[];

    // First part - branch name and status (always shown with status color)
    rowParts.add(colorText(branchName));
    rowParts.add(' | '); // Separator in default color
    rowParts.add(colorText(statusStr));

    // Add local hash and date if requested (in default color or yellow)
    if (showLocal && localHash != null && localDate != null) {
      rowParts.add(' | '); // Separator in default color

      // Local hash - highlight in yellow if there are unpushed local changes
      if (hasLocalChanges) {
        rowParts.add(Terminal.yellowText(localHash));
      } else {
        rowParts.add(localHash); // Default terminal color
      }

      rowParts.add(' | '); // Separator in default color

      // Local date - use same highlighting as local hash
      if (hasLocalChanges) {
        rowParts.add(Terminal.yellowText(localDate));
      } else {
        rowParts.add(localDate); // Default terminal color
      }
    }

    // Add Gerrit hash and date if requested (in default color or yellow)
    if (showGerrit && gerritHash != null && gerritDate != null) {
      rowParts.add(' | '); // Separator in default color

      // Gerrit hash - highlight in yellow if Gerrit has remote updates
      if (hasRemoteChanges) {
        rowParts.add(Terminal.yellowText(gerritHash));
      } else {
        rowParts.add(gerritHash); // Default terminal color
      }

      rowParts.add(' | '); // Separator in default color

      // Gerrit date - use same highlighting as Gerrit hash
      if (hasRemoteChanges) {
        rowParts.add(Terminal.yellowText(gerritDate));
      } else {
        rowParts.add(gerritDate); // Default terminal color
      }
    }

    // Print the combined row with all color segments
    print(rowParts.join(''));
  }

  /// Gets the color text function for a status.
  static String Function(String) _getStatusColorTextFunction(String status) {
    switch (status) {
      case 'Active':
        return Terminal.greenText;
      case 'WIP':
        return Terminal.yellowText;
      case 'Merge conflict':
        return Terminal.redText;
      case 'Merged':
        return Terminal.cyanText;
      default:
        return (String text) => text; // No color for default
    }
  }

  /// Pads a string to the specified width.
  static String _padString(String text, int width) {
    if (text.length >= width) {
      return text.substring(0, width);
    }
    return text.padRight(width);
  }

  /// Truncates a commit hash for display.
  ///
  /// Shows first 8 characters of the hash.
  static String _truncateHash(String hash) {
    if (hash == '-' || hash.length <= 8) {
      return hash;
    }
    return hash.substring(0, 8);
  }

  /// Formats a date string to a consistent format.
  ///
  /// Handles date strings from both Git and Gerrit, which use different
  /// formats:
  /// - Git format: "2025-10-07 14:30:45 -0400" (includes timezone offset)
  /// - Gerrit format: "2025-10-07 14:30:45.000000000" (includes microseconds)
  ///
  /// Both are converted to the simplified format: "yyyy-MM-dd HH:mm"
  /// This provides a consistent, readable display format regardless of source.
  ///
  /// [dateStr] - The date string to format
  /// Returns the formatted date string or "-" if the input is "-".
  /// If parsing fails, returns the original string truncated to 16 characters.
  static String _formatDate(String dateStr) {
    if (dateStr == '-') {
      return '-';
    }

    try {
      // Git format: "2025-10-07 14:30:45 -0400"
      // Gerrit format: "2025-10-07 14:30:45.000000000" or ISO 8601

      // Try to parse the date
      DateTime? dateTime;

      // Try parsing as ISO 8601 first (Gerrit format)
      try {
        dateTime = DateTime.parse(dateStr);
      } catch (e) {
        // If that fails, try to extract just the date/time part (Git format)
        final parts = dateStr.split(' ');
        if (parts.length >= 2) {
          final datePart = parts[0];
          final timePart = parts[1].split(
            '.',
          )[0]; // Remove microseconds if present
          dateTime = DateTime.parse('$datePart $timePart');
        }
      }

      if (dateTime != null) {
        // Format as "yyyy-MM-dd HH:mm"
        final year = dateTime.year.toString();
        final month = dateTime.month.toString().padLeft(2, '0');
        final day = dateTime.day.toString().padLeft(2, '0');
        final hour = dateTime.hour.toString().padLeft(2, '0');
        final minute = dateTime.minute.toString().padLeft(2, '0');
        return '$year-$month-$day $hour:$minute';
      }
    } catch (e) {
      // If parsing fails, return the original string truncated to fit column
      // width
      if (dateStr.length > 16) {
        return dateStr.substring(0, 16);
      }
    }

    return dateStr;
  }

  /// Displays a performance summary showing timing breakdown of operations.
  ///
  /// [tracker] - The PerformanceTracker instance containing timing data
  static void displayPerformanceSummary(PerformanceTracker tracker) {
    if (!tracker.hasTimings) {
      return;
    }

    Terminal.info('');
    Terminal.info('Performance Summary:');

    final timings = tracker.getTimings();
    final totalTime = tracker.getTotalTime();

    // Define the order and display names for operations
    final operationOrder = [
      ('branch_discovery', 'Branch discovery'),
      ('git_operations', 'Git operations'),
      ('gerrit_queries', 'Gerrit API queries'),
      ('result_processing', 'Result processing'),
      ('filtering', 'Filtering'),
    ];

    // Find the longest operation name for alignment
    var maxNameLength = 0;
    for (final (_, displayName) in operationOrder) {
      if (displayName.length > maxNameLength) {
        maxNameLength = displayName.length;
      }
    }

    // Display each operation timing
    for (final (operationKey, displayName) in operationOrder) {
      final duration = timings[operationKey];
      if (duration != null) {
        final paddedName = displayName.padRight(maxNameLength);
        Terminal.info('  $paddedName: ${duration.toString().padLeft(5)}ms');
      }
    }

    // Display total time
    final paddedTotal = 'Total execution time'.padRight(maxNameLength);
    Terminal.info('  $paddedTotal: ${totalTime.toString().padLeft(5)}ms');
  }
}

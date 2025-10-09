import 'branch_info.dart';
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
    final columnWidths = <int>[20, 15];

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
  /// This method handles the complex logic of displaying branch information with:
  /// - Status-based color coding (green for Active, yellow for WIP, etc.)
  /// - Difference highlighting (yellow highlight when Gerrit hash/date differs from local)
  /// - Mixed-color output within a single row (different parts can have different colors)
  ///
  /// The highlighting logic helps users quickly identify:
  /// - Branches where local changes differ from what's uploaded to Gerrit
  /// - Branches that need to be re-uploaded or synced
  static void _printBranchRow(
    BranchInfo branchInfo,
    List<int> columnWidths,
    bool showGerrit,
    bool showLocal,
  ) {
    final status = branchInfo.getDisplayStatus();

    // Format the data
    final branchName = _padString(branchInfo.branchName, columnWidths[0]);
    final statusStr = _padString(status, columnWidths[1]);

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
    var gerritHashRaw = '-';
    var gerritDateRaw = '-';
    if (showGerrit) {
      gerritHashRaw = branchInfo.getGerritHash();
      gerritHash = _padString(
        _truncateHash(gerritHashRaw),
        columnWidths[colIndex],
      );
      gerritDateRaw = branchInfo.getGerritDate();
      gerritDate = _padString(
        _formatDate(gerritDateRaw),
        columnWidths[colIndex + 1],
      );
    }

    // Check if Gerrit hash/date differ from local values
    // This indicates that the local branch has changes not yet uploaded,
    // or the Gerrit change has been updated since the last sync
    final hashDiffers =
        showLocal &&
        showGerrit &&
        gerritHashRaw != '-' &&
        _truncateHash(branchInfo.localHash) != _truncateHash(gerritHashRaw);
    final dateDiffers =
        showLocal &&
        showGerrit &&
        gerritDateRaw != '-' &&
        _formatDate(branchInfo.localDate) != _formatDate(gerritDateRaw);

    // Build the row with highlighting for differences
    _printRowWithHighlighting(
      branchName,
      statusStr,
      localHash,
      localDate,
      gerritHash,
      gerritDate,
      status,
      hashDiffers,
      dateDiffers,
      showLocal,
      showGerrit,
    );
  }

  /// Prints a row with color coding and highlights differences.
  ///
  /// This method creates a single table row with mixed colors:
  /// - Most of the row uses the status color (green/yellow/red/cyan)
  /// - Gerrit hash is highlighted in yellow if it differs from local hash
  /// - Gerrit date is highlighted in yellow if it differs from local date
  ///
  /// The mixed-color approach is achieved by building the row as separate
  /// colored string segments and concatenating them with print().
  ///
  /// Terminal color codes work by wrapping text in ANSI escape sequences,
  /// so we can mix different colored segments in a single print statement.
  static void _printRowWithHighlighting(
    String branchName,
    String statusStr,
    String? localHash,
    String? localDate,
    String? gerritHash,
    String? gerritDate,
    String status,
    bool hashDiffers,
    bool dateDiffers,
    bool showLocal,
    bool showGerrit,
  ) {
    // Get the appropriate color function for the status
    var colorText = _getStatusColorTextFunction(status);

    // Build the row parts with appropriate coloring
    final rowParts = <String>[];

    // First part - branch name and status (always shown)
    rowParts.add(colorText('$branchName | $statusStr'));

    // Add local hash and date if requested
    if (showLocal && localHash != null && localDate != null) {
      rowParts.add(colorText(' | $localHash | $localDate'));
    }

    // Add Gerrit hash and date if requested
    if (showGerrit && gerritHash != null && gerritDate != null) {
      rowParts.add(colorText(' | '));

      // Gerrit hash - highlight in yellow if different from local
      if (hashDiffers) {
        rowParts.add(Terminal.yellowText(gerritHash));
      } else {
        rowParts.add(colorText(gerritHash));
      }

      // Separator
      rowParts.add(colorText(' | '));

      // Gerrit date - highlight in yellow if different from local
      if (dateDiffers) {
        rowParts.add(Terminal.yellowText(gerritDate));
      } else {
        rowParts.add(colorText(gerritDate));
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
  /// Handles date strings from both Git and Gerrit, which use different formats:
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
      // If parsing fails, return the original string truncated to fit column width
      if (dateStr.length > 16) {
        return dateStr.substring(0, 16);
      }
    }

    return dateStr;
  }
}

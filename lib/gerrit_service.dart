import 'dart:convert';
import 'dart:isolate';

import 'package:http/http.dart' as http;

/// Represents a Gerrit change with its status and metadata.
class GerritChange {
  GerritChange({
    required this.changeId,
    required this.status,
    required this.workInProgress,
    required this.mergeable,
    required this.updated,
    required this.currentRevision,
  });

  /// Creates a GerritChange from a JSON map.
  factory GerritChange.fromJson(Map<String, dynamic> json) {
    // Extract the current revision hash from the revisions map
    String? currentRevision;
    final currentRevisionKey = json['current_revision'] as String?;
    if (currentRevisionKey != null) {
      currentRevision = currentRevisionKey;
    }

    return GerritChange(
      changeId: json['change_id'] as String,
      status: json['status'] as String,
      workInProgress: json['work_in_progress'] as bool? ?? false,
      mergeable: json['mergeable'] as bool? ?? true,
      updated: json['updated'] as String,
      currentRevision: currentRevision,
    );
  }

  /// The change ID (e.g., "Iabc123...")
  final String changeId;

  /// The change status (e.g., "NEW", "MERGED", "ABANDONED")
  final String status;

  /// Whether the change is marked as work in progress
  final bool workInProgress;

  /// Whether the change can be merged without conflicts
  final bool mergeable;

  /// The last updated timestamp in ISO 8601 format
  final String updated;

  /// The current revision hash (commit SHA)
  final String? currentRevision;

  /// Maps the Gerrit change to a user-friendly status string.
  ///
  /// Priority order (when multiple conditions match):
  /// 1. Merged (highest priority)
  /// 2. Merge conflict
  /// 3. WIP
  /// 4. Active
  String getUserFriendlyStatus() {
    // Priority 1: Merged
    if (status == 'MERGED') {
      return 'Merged';
    }

    // Priority 2: Merge conflict
    if (!mergeable) {
      return 'Merge conflict';
    }

    // Priority 3: WIP
    if (workInProgress) {
      return 'WIP';
    }

    // Priority 4: Active (NEW status and not WIP)
    if (status == 'NEW') {
      return 'Active';
    }

    // Fallback for other statuses
    return status;
  }
}

/// Service for interacting with Gerrit REST API.
///
/// This class provides methods to query Gerrit for change information
/// and parse the responses.
class GerritService {
  /// The base URL for the Gerrit API
  static const String baseUrl = 'https://dart-review.googlesource.com';

  /// The XSSI protection prefix that Gerrit adds to JSON responses
  static const String xssiPrefix = ")]}'\n";

  /// Maximum number of issues per batch query (Gerrit API limitation).
  static const int maxIssuesPerBatch = 10;

  /// Data class for passing batch query parameters to isolate.
  static Map<String, dynamic> _createBatchQueryParams({
    required List<String> issueNumbers,
    required String serverUrl,
  }) {
    return <String, dynamic>{
      'issueNumbers': issueNumbers,
      'serverUrl': serverUrl,
      'xssiPrefix': xssiPrefix,
    };
  }

  /// Executes a single batch query in an isolate.
  ///
  /// This function runs in a separate isolate to avoid blocking the main thread
  /// during network I/O and JSON parsing operations. Each isolate handles one
  /// batch of up to 10 issue numbers.
  ///
  /// The Gerrit batch query API uses multiple query parameters:
  /// GET /changes/?q={issue1}&q={issue2}&q={issue3}&o=CURRENT_REVISION
  ///
  /// The response is a JSON array where each element corresponds to one query.
  /// Each query result is itself an array containing 0 or 1 change objects.
  /// Example response structure:
  /// ```json
  /// [
  ///   [{"_number": 389423, "change_id": "Iabc...", ...}],  // Results for issue1
  ///   [],                                                    // No results for issue2
  ///   [{"_number": 389425, "change_id": "Idef...", ...}]   // Results for issue3
  /// ]
  /// ```
  ///
  /// [params] - Map containing issueNumbers, serverUrl, and xssiPrefix
  /// Returns a map of issue number to GerritChange (or null if not found).
  static Future<Map<String, GerritChange?>> _executeBatchQueryInIsolate(
    Map<String, dynamic> params,
  ) async {
    return await Isolate.run(() async {
      final issueNumbers = params['issueNumbers'] as List<String>;
      final serverUrl = params['serverUrl'] as String;
      final xssiPrefix = params['xssiPrefix'] as String;

      // Build the batch query URL with multiple ?q= parameters
      final queryParams = issueNumbers
          .map((String issue) => 'q=$issue')
          .join('&');
      final url = '$serverUrl/changes/?$queryParams&o=CURRENT_REVISION';

      try {
        final response = await http.get(Uri.parse(url));

        if (response.statusCode != 200) {
          // Return null results on error (partial success approach)
          final results = <String, GerritChange?>{};
          for (final issue in issueNumbers) {
            results[issue] = null;
          }
          return results;
        }

        // Handle Gerrit's XSSI protection prefix: ")]}'\n"
        var jsonBody = response.body;
        if (jsonBody.startsWith(xssiPrefix)) {
          jsonBody = jsonBody.substring(xssiPrefix.length);
        }

        // Parse the JSON response (already in isolate, so direct decode is
        // fine)
        final jsonData = jsonDecode(jsonBody);

        // Initialize all results as null (not found)
        final results = <String, GerritChange?>{};
        for (final issue in issueNumbers) {
          results[issue] = null;
        }

        // Process the response - Gerrit returns an array where each element
        // contains the results for one query (as an array with 0 or 1 items)
        if (jsonData is List) {
          for (final queryResult in jsonData) {
            if (queryResult is List && queryResult.isNotEmpty) {
              // Each query returns an array with at most one change
              final changeJson = queryResult[0] as Map<String, dynamic>;
              final change = GerritChange.fromJson(changeJson);

              // Match the change back to the issue number using the _number
              // field. This field contains the Gerrit change number (same as
              //issue number)
              final changeNumber = changeJson['_number']?.toString();
              if (changeNumber != null && results.containsKey(changeNumber)) {
                results[changeNumber] = change;
              }
            }
          }
        }

        // Fetch mergeable data for all found changes in parallel
        // Note: mergeable info requires separate API calls to /revisions/current/mergeable
        final mergeableFutures = <String, Future<bool>>{};
        for (final entry in results.entries) {
          if (entry.value != null) {
            final issueNumber = entry.key;
            final mergeableUrl =
                '$serverUrl/changes/$issueNumber/revisions/current/mergeable';

            mergeableFutures[issueNumber] = Future(() async {
              try {
                final mergeableResponse = await http.get(
                  Uri.parse(mergeableUrl),
                );

                if (mergeableResponse.statusCode == 200) {
                  var mergeableBody = mergeableResponse.body;
                  if (mergeableBody.startsWith(xssiPrefix)) {
                    mergeableBody = mergeableBody.substring(xssiPrefix.length);
                  }

                  final mergeableData = jsonDecode(mergeableBody);
                  if (mergeableData is Map<String, dynamic>) {
                    return mergeableData['mergeable'] as bool? ?? true;
                  }
                }
                return true; // Default to true if fetch fails
              } catch (e) {
                return true; // Default to true if error occurs
              }
            });
          }
        }

        // Wait for all mergeable requests to complete in parallel
        if (mergeableFutures.isNotEmpty) {
          final mergeableResults = await Future.wait(
            mergeableFutures.entries.map((entry) async {
              final issueNumber = entry.key;
              final mergeable = await entry.value;
              return MapEntry(issueNumber, mergeable);
            }),
          );

          // Update the GerritChange objects with the correct mergeable status
          for (final mergeableEntry in mergeableResults) {
            final issueNumber = mergeableEntry.key;
            final mergeable = mergeableEntry.value;
            final existingChange = results[issueNumber];

            if (existingChange != null) {
              // Create a new GerritChange with the updated mergeable value
              results[issueNumber] = GerritChange(
                changeId: existingChange.changeId,
                status: existingChange.status,
                workInProgress: existingChange.workInProgress,
                mergeable: mergeable,
                updated: existingChange.updated,
                currentRevision: existingChange.currentRevision,
              );
            }
          }
        }

        return results;
      } catch (e) {
        // On error, return all nulls (partial success approach)
        final results = <String, GerritChange?>{};
        for (final issue in issueNumbers) {
          results[issue] = null;
        }
        return results;
      }
    });
  }

  /// Queries the Gerrit API for multiple changes by their issue numbers in
  /// batch requests.
  ///
  /// Uses the multi-query pattern:
  /// GET /changes/?q={query_1}&q={query_2}&q={query_3}...
  /// This is more efficient than making individual API calls for each issue.
  ///
  /// Automatically splits large requests into batches of up to 10 issues per
  /// request
  /// (Gerrit API limitation) and executes each batch in a separate isolate for
  /// optimal performance.
  ///
  /// For each batch:
  /// 1. Fetches up to 10 changes in a single batched HTTP request
  /// 2. Fetches mergeable status for all found changes in parallel (separate
  /// requests required)
  ///
  /// Total HTTP requests per batch: 1 batch query + N mergeable queries (where
  /// N ≤ 10)
  /// All mergeable requests execute in parallel to minimize total time.
  ///
  /// [issueNumbers] - List of Gerrit issue/change numbers to look up
  /// [serverUrl] - The Gerrit server URL (optional, defaults to
  /// dart-review.googlesource.com)
  /// Returns a map of issue number to GerritChange (or null if not found).
  /// This allows partial success - some changes may be found while others are
  /// not.
  static Future<Map<String, GerritChange?>> getBatchChangesByIssueNumbers(
    List<String> issueNumbers, [
    String? serverUrl,
  ]) async {
    if (issueNumbers.isEmpty) {
      return <String, GerritChange?>{};
    }

    final server = serverUrl ?? baseUrl;

    // Split issue numbers into batches of maxIssuesPerBatch
    final batches = <List<String>>[];
    for (var i = 0; i < issueNumbers.length; i += maxIssuesPerBatch) {
      final end = (i + maxIssuesPerBatch < issueNumbers.length)
          ? i + maxIssuesPerBatch
          : issueNumbers.length;
      batches.add(issueNumbers.sublist(i, end));
    }

    // Execute all batches in parallel, each in its own isolate
    final batchFutures = batches.map((List<String> batch) {
      final params = _createBatchQueryParams(
        issueNumbers: batch,
        serverUrl: server,
      );
      return _executeBatchQueryInIsolate(params);
    });

    // Wait for all batches to complete
    final batchResults = await Future.wait(batchFutures);

    // Merge all batch results into a single map
    final results = <String, GerritChange?>{};
    batchResults.forEach(results.addAll);

    return results;
  }
}

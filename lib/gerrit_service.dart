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

  /// Decodes JSON in a separate isolate to avoid blocking the main isolate.
  ///
  /// Large JSON responses can cause the UI to freeze if decoded on the main thread.
  /// By running the decode operation in a separate isolate, we prevent blocking
  /// the main event loop, ensuring smooth execution even with large payloads.
  ///
  /// [jsonString] - The JSON string to decode
  /// Returns the decoded JSON data (typically a Map or List).
  static Future<dynamic> _decodeJsonInIsolate(String jsonString) async {
    return await Isolate.run(() => jsonDecode(jsonString));
  }

  /// Constructs the Gerrit API URL for looking up a change by Change-ID.
  ///
  /// [changeId] - The Change-ID to look up (e.g., "Iabc123...")
  /// Returns the full API URL.
  static String buildChangeUrl(String changeId) {
    // URL encode the change ID to handle special characters
    final encodedChangeId = Uri.encodeComponent(changeId);
    return '$baseUrl/changes/?q=change:$encodedChangeId';
  }

  /// Constructs the Gerrit API URL for looking up a change by issue number.
  ///
  /// [issueNumber] - The Gerrit issue/change number (e.g., "389423")
  /// [serverUrl] - The Gerrit server URL (defaults to dart-review.googlesource.com)
  /// Returns the full API URL.
  static String buildChangeUrlByIssue(String issueNumber, [String? serverUrl]) {
    final server = serverUrl ?? baseUrl;
    return '$server/changes/$issueNumber/?o=CURRENT_REVISION';
  }

  /// Constructs the Gerrit API URL for fetching mergeable info for a change.
  ///
  /// [issueNumber] - The Gerrit issue/change number (e.g., "389423")
  /// [serverUrl] - The Gerrit server URL (defaults to dart-review.googlesource.com)
  /// Returns the full API URL for the mergeable endpoint.
  static String buildMergeableUrl(String issueNumber, [String? serverUrl]) {
    final server = serverUrl ?? baseUrl;
    return '$server/changes/$issueNumber/revisions/current/mergeable';
  }

  /// Queries the Gerrit API for a change by its issue number.
  ///
  /// This is the preferred method for querying Gerrit when you have the issue number
  /// from Git config, as it's more efficient than searching by Change-ID.
  ///
  /// The API endpoint format is: GET /changes/{issue}?o=CURRENT_REVISION
  /// The CURRENT_REVISION option includes the current commit hash in the response.
  ///
  /// Gerrit's JSON responses include an XSSI protection prefix ")]}'\n" which must
  /// be stripped before parsing. This prevents the response from being executable
  /// as JavaScript, protecting against cross-site scripting attacks.
  ///
  /// [issueNumber] - The Gerrit issue/change number to look up (e.g., "389423")
  /// [serverUrl] - The Gerrit server URL (optional, defaults to dart-review.googlesource.com)
  /// Returns a [GerritChange] object or null if not found (HTTP 404).
  /// Throws an exception if the API request fails with other errors.
  static Future<GerritChange?> getChangeByIssueNumber(
    String issueNumber, [
    String? serverUrl,
  ]) async {
    final url = buildChangeUrlByIssue(issueNumber, serverUrl);

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 404) {
        // Change not found - this is a normal case (branch might not be uploaded yet)
        return null;
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Gerrit API request failed with status ${response.statusCode}: ${response.body}',
        );
      }

      // Handle Gerrit's XSSI protection prefix: ")]}'\n"
      // This prefix prevents the JSON from being executed as JavaScript
      var jsonBody = response.body;
      if (jsonBody.startsWith(xssiPrefix)) {
        jsonBody = jsonBody.substring(xssiPrefix.length);
      }

      // Parse the JSON response in a separate isolate to avoid blocking
      final jsonData = await _decodeJsonInIsolate(jsonBody);

      if (jsonData is Map<String, dynamic>) {
        // Direct change object returned
        return GerritChange.fromJson(jsonData);
      }

      throw Exception('Unexpected Gerrit API response format');
    } catch (e) {
      // Re-throw with more context to help debugging
      throw Exception('Failed to query Gerrit API for issue $issueNumber: $e');
    }
  }

  /// Queries the Gerrit API for a change by its Change-ID.
  ///
  /// [changeId] - The Change-ID to look up
  /// Returns a [GerritChange] object or null if not found.
  /// Throws an exception if the API request fails.
  static Future<GerritChange?> getChangeByChangeId(String changeId) async {
    final url = buildChangeUrl(changeId);

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception(
          'Gerrit API request failed with status ${response.statusCode}: ${response.body}',
        );
      }

      // Handle Gerrit's XSSI protection prefix
      var jsonBody = response.body;
      if (jsonBody.startsWith(xssiPrefix)) {
        jsonBody = jsonBody.substring(xssiPrefix.length);
      }

      // Parse the JSON response in a separate isolate
      final jsonData = await _decodeJsonInIsolate(jsonBody);

      // Gerrit returns an array of changes
      if (jsonData is List && jsonData.isEmpty) {
        // No change found
        return null;
      }

      if (jsonData is List && jsonData.isNotEmpty) {
        // Return the first matching change
        return GerritChange.fromJson(jsonData[0] as Map<String, dynamic>);
      }

      throw Exception('Unexpected Gerrit API response format');
    } catch (e) {
      // Re-throw with more context
      throw Exception('Failed to query Gerrit API for change $changeId: $e');
    }
  }

  /// Queries the Gerrit API for multiple changes by their Change-IDs.
  ///
  /// [changeIds] - List of Change-IDs to look up
  /// Returns a map of Change-ID to GerritChange (or null if not found).
  /// This allows partial success - some changes may be found while others are not.
  static Future<Map<String, GerritChange?>> getChangesByChangeIds(
    List<String> changeIds,
  ) async {
    final results = <String, GerritChange?>{};

    // Query each change individually
    for (final changeId in changeIds) {
      try {
        results[changeId] = await getChangeByChangeId(changeId);
      } catch (e) {
        // Allow partial success - if one query fails, continue with others
        results[changeId] = null;
      }
    }

    return results;
  }

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

        // Parse the JSON response (already in isolate, so direct decode is fine)
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

              // Match the change back to the issue number using the _number field
              // This field contains the Gerrit change number (same as issue number)
              final changeNumber = changeJson['_number']?.toString();
              if (changeNumber != null && results.containsKey(changeNumber)) {
                results[changeNumber] = change;
              }
            }
          }
        }

        // Fetch mergeable data for all found changes in parallel
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

        // Wait for all mergeable requests to complete
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

  /// Queries the Gerrit API for multiple changes by their issue numbers in batch requests.
  ///
  /// Uses the multi-query pattern: GET /changes/?q={query_1}&q={query_2}&q={query_3}...
  /// This is more efficient than making individual API calls for each issue.
  ///
  /// Automatically splits large requests into batches of up to 10 issues per request
  /// (Gerrit API limitation) and executes each batch in a separate isolate for
  /// optimal performance.
  ///
  /// [issueNumbers] - List of Gerrit issue/change numbers to look up
  /// [serverUrl] - The Gerrit server URL (optional, defaults to dart-review.googlesource.com)
  /// Returns a map of issue number to GerritChange (or null if not found).
  /// This allows partial success - some changes may be found while others are not.
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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dgt/gerrit_service.dart';

/// A stand-in for a real Gerrit instance.
///
/// [GerritService] performs its HTTP calls inside [Isolate.run], so an
/// in-process `http.Client` mock cannot reach them: the isolate boundary only
/// carries sendable values. Binding a real loopback server and passing its URL
/// through the existing `serverUrl` parameter keeps the production code path
/// (isolates, batching, XSSI stripping) intact while still serving canned
/// responses.
class FakeGerritServer {
  FakeGerritServer._(this._server) {
    _server.listen((request) => unawaited(_handle(request)));
  }

  /// Binds the fake server to an ephemeral loopback port.
  static Future<FakeGerritServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return FakeGerritServer._(server);
  }

  final HttpServer _server;

  /// Every URI the server has been asked for, in arrival order.
  final List<Uri> requests = [];

  /// Change payloads keyed by issue number. Anything not present here is
  /// reported as "not found", the same as a Gerrit query with no match.
  final Map<String, Map<String, dynamic>> changes = {};

  /// Mergeable answers keyed by issue number. Missing entries default to true.
  final Map<String, bool> mergeable = {};

  /// Status code returned for `/changes/` batch queries.
  int batchStatusCode = 200;

  /// Status code returned for the per-change mergeable endpoint.
  int mergeableStatusCode = 200;

  /// When true, `/changes/` answers a single query with a flat array of
  /// changes instead of the nested array Gerrit uses for multi-query requests.
  bool useFlatSingleQueryShape = false;

  /// The base URL to hand to [GerritService.getBatchChangesByIssueNumbers].
  String get url => 'http://${_server.address.address}:${_server.port}';

  /// The `q` parameters of each `/changes/` batch query, in arrival order.
  List<List<String>> get batchQueries => [
    for (final uri in requests)
      if (uri.path == '/changes/') uri.queryParametersAll['q'] ?? const [],
  ];

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    requests.add(request.uri);
    final response = request.response;

    final mergeableMatch = RegExp(
      r'^/changes/([^/]+)/revisions/current/mergeable$',
    ).firstMatch(request.uri.path);

    if (mergeableMatch != null) {
      response.statusCode = mergeableStatusCode;
      if (mergeableStatusCode == 200) {
        final issue = mergeableMatch.group(1)!;
        _writeJson(response, <String, dynamic>{
          'mergeable': mergeable[issue] ?? true,
        });
      }
      await response.close();
      return;
    }

    if (request.uri.path == '/changes/') {
      response.statusCode = batchStatusCode;
      if (batchStatusCode == 200) {
        final queries = request.uri.queryParametersAll['q'] ?? const <String>[];
        final results = [
          for (final query in queries) <Map<String, dynamic>>[?changes[query]],
        ];
        _writeJson(
          response,
          useFlatSingleQueryShape && results.length == 1
              ? results.single
              : results,
        );
      }
      await response.close();
      return;
    }

    response.statusCode = HttpStatus.notFound;
    await response.close();
  }

  void _writeJson(HttpResponse response, Object body) {
    response.headers.contentType = ContentType.json;
    // Gerrit guards its JSON with an XSSI prefix that clients must strip.
    response.write('${GerritService.xssiPrefix}${jsonEncode(body)}');
  }
}

/// A single message in a change's history, as authored by [authorId].
typedef ChangeMessage = ({int authorId, String tag});

/// Builds a Gerrit change payload shaped like the REST API's response.
///
/// Note that Gerrit lists the change owner in `REVIEWER` too, so [reviewerIds]
/// only needs the *other* accounts; the owner is added automatically.
Map<String, dynamic> gerritChangeJson({
  required String number,
  String? changeId,
  String status = 'NEW',
  bool workInProgress = false,
  String updated = '2025-10-01 12:00:00.000000000',
  String currentRevision = 'deadbeef',
  int ownerId = 1000,
  bool approved = false,
  List<int> codeReviewVotes = const [],
  List<int> commitQueueVotes = const [],
  List<int> reviewerIds = const [],
  List<ChangeMessage> messages = const [],
}) {
  return <String, dynamic>{
    '_number': int.parse(number),
    'change_id': changeId ?? 'I$number',
    'status': status,
    'work_in_progress': workInProgress,
    'updated': updated,
    'current_revision': currentRevision,
    'owner': <String, dynamic>{'_account_id': ownerId},
    'reviewers': <String, dynamic>{
      'REVIEWER': [
        <String, dynamic>{'_account_id': ownerId},
        for (final id in reviewerIds) <String, dynamic>{'_account_id': id},
      ],
    },
    'labels': <String, dynamic>{
      'Code-Review': <String, dynamic>{
        if (approved) 'approved': <String, dynamic>{'_account_id': 2000},
        'all': [
          for (final vote in codeReviewVotes)
            <String, dynamic>{'value': vote, '_account_id': 2000 + vote},
        ],
      },
      if (commitQueueVotes.isNotEmpty)
        'Commit-Queue': <String, dynamic>{
          'all': [
            for (final vote in commitQueueVotes)
              <String, dynamic>{'value': vote},
          ],
        },
    },
    'messages': [
      for (final (index, message) in messages.indexed)
        <String, dynamic>{
          'date': '2025-10-01 ${'$index'.padLeft(2, '0')}:00:00.000000000',
          'tag': message.tag,
          'author': <String, dynamic>{'_account_id': message.authorId},
        },
    ],
  };
}

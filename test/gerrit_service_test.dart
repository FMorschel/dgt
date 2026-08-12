import 'package:dgt/gerrit_service.dart';
import 'package:test/test.dart';

import 'fake_gerrit_server.dart';

void main() {
  group('GerritService.getBatchChangesByIssueNumbers', () {
    late FakeGerritServer server;

    setUp(() async {
      server = await FakeGerritServer.start();
    });

    tearDown(() async {
      await server.close();
    });

    test(
      'parses a batched response into changes keyed by issue number',
      () async {
        server.changes['389423'] = gerritChangeJson(
          number: '389423',
          currentRevision: 'aaa111',
          reviewerIds: const [2001],
        );
        server.changes['389425'] = gerritChangeJson(
          number: '389425',
          status: 'MERGED',
          currentRevision: 'bbb222',
        );

        final result = await GerritService.getBatchChangesByIssueNumbers([
          '389423',
          '389425',
        ], server.url);

        expect(result.keys, unorderedEquals(['389423', '389425']));
        expect(result['389423']!.changeId, 'I389423');
        expect(result['389423']!.status, 'NEW');
        expect(result['389423']!.currentRevision, 'aaa111');
        expect(result['389425']!.status, 'MERGED');
        expect(result['389425']!.getUserFriendlyStatus(), 'Merged');
      },
    );

    test(
      'requests the revision, label and message options in one query',
      () async {
        server.changes['1'] = gerritChangeJson(number: '1');

        await GerritService.getBatchChangesByIssueNumbers(['1'], server.url);

        final batch = server.requests.firstWhere(
          (uri) => uri.path == '/changes/',
        );
        expect(batch.queryParametersAll['q'], ['1']);
        expect(
          batch.queryParametersAll['o'],
          containsAll(['CURRENT_REVISION', 'DETAILED_LABELS', 'MESSAGES']),
        );
      },
    );

    test('maps issues the server does not know about to null', () async {
      server.changes['389423'] = gerritChangeJson(number: '389423');

      final result = await GerritService.getBatchChangesByIssueNumbers([
        '389423',
        '999999',
      ], server.url);

      expect(result, hasLength(2));
      expect(result['389423'], isNotNull);
      expect(result.containsKey('999999'), isTrue);
      expect(result['999999'], isNull);
    });

    test(
      'normalizes the flat array Gerrit returns for a single query',
      () async {
        server.useFlatSingleQueryShape = true;
        server.changes['389423'] = gerritChangeJson(number: '389423');

        final result = await GerritService.getBatchChangesByIssueNumbers([
          '389423',
        ], server.url);

        expect(result['389423']!.changeId, 'I389423');
      },
    );

    test('applies the separately fetched mergeable status', () async {
      server.changes['389423'] = gerritChangeJson(
        number: '389423',
        reviewerIds: const [2001],
      );
      server.mergeable['389423'] = false;

      final result = await GerritService.getBatchChangesByIssueNumbers([
        '389423',
      ], server.url);

      expect(result['389423']!.mergeable, isFalse);
      expect(result['389423']!.getUserFriendlyStatus(), 'Merge conflict');
      expect(
        server.requests.map((uri) => uri.path),
        contains('/changes/389423/revisions/current/mergeable'),
      );
    });

    test('defaults to mergeable when that endpoint fails', () async {
      server.changes['389423'] = gerritChangeJson(
        number: '389423',
        reviewerIds: const [2001],
      );
      server.mergeableStatusCode = 500;

      final result = await GerritService.getBatchChangesByIssueNumbers([
        '389423',
      ], server.url);

      expect(result['389423']!.mergeable, isTrue);
    });

    test('returns nulls for every issue when the batch query fails', () async {
      server.changes['389423'] = gerritChangeJson(number: '389423');
      server.batchStatusCode = 500;

      final result = await GerritService.getBatchChangesByIssueNumbers([
        '389423',
        '389425',
      ], server.url);

      expect(result, hasLength(2));
      expect(result.values, everyElement(isNull));
    });

    test('splits more than ten issues across batched queries', () async {
      final issues = [for (var i = 1; i <= 23; i++) '$i'];
      for (final issue in issues) {
        server.changes[issue] = gerritChangeJson(number: issue);
      }

      final result = await GerritService.getBatchChangesByIssueNumbers(
        issues,
        server.url,
      );

      expect(result, hasLength(23));
      expect(result.values, everyElement(isNotNull));

      final batches = server.batchQueries;
      expect(batches, hasLength(3));
      expect(
        batches,
        everyElement(
          hasLength(lessThanOrEqualTo(GerritService.maxIssuesPerBatch)),
        ),
      );
      expect(batches.expand((batch) => batch), unorderedEquals(issues));
    });

    test('does not hit the server for an empty issue list', () async {
      final result = await GerritService.getBatchChangesByIssueNumbers(
        [],
        server.url,
      );

      expect(result, isEmpty);
      expect(server.requests, isEmpty);
    });

    test('derives user friendly statuses from the served payload', () async {
      server.changes['1'] = gerritChangeJson(number: '1', workInProgress: true);
      server.changes['2'] = gerritChangeJson(number: '2');
      server.changes['3'] = gerritChangeJson(
        number: '3',
        reviewerIds: const [2001],
        commitQueueVotes: const [2],
      );
      server.changes['4'] = gerritChangeJson(
        number: '4',
        approved: true,
        codeReviewVotes: const [1],
        reviewerIds: const [2001],
        messages: const [(authorId: 1000, tag: '')],
      );
      server.changes['5'] = gerritChangeJson(
        number: '5',
        reviewerIds: const [2001],
        messages: const [(authorId: 1000, tag: ''), (authorId: 2001, tag: '')],
      );

      final result = await GerritService.getBatchChangesByIssueNumbers([
        '1',
        '2',
        '3',
        '4',
        '5',
      ], server.url);

      expect(result['1']!.getUserFriendlyStatus(), 'WIP');
      expect(result['2']!.getUserFriendlyStatus(), 'Active (Unsent)');
      expect(result['3']!.getUserFriendlyStatus(), 'Active (Commit)');
      expect(result['4']!.getUserFriendlyStatus(), 'Active (LGTM +1, Waiting)');
      expect(result['5']!.getUserFriendlyStatus(), 'Active (Reply)');
    });
  });
}

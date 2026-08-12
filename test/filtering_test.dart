import 'package:dgt/filtering.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  group('FilterOptions.isEmpty', () {
    test('is true for no filters and for explicitly empty ones', () {
      expect(FilterOptions().isEmpty, isTrue);
      expect(FilterOptions(statuses: []).isEmpty, isTrue);
      // diverged: false means "not filtering", not "show non-diverged".
      expect(FilterOptions(diverged: false).isEmpty, isTrue);
    });

    test('is false once any filter is set', () {
      expect(FilterOptions(statuses: ['wip']).isEmpty, isFalse);
      expect(FilterOptions(since: DateTime(2025)).isEmpty, isFalse);
      expect(FilterOptions(before: DateTime(2025)).isEmpty, isFalse);
      expect(FilterOptions(diverged: true).isEmpty, isFalse);
    });
  });

  group('applyFilters status', () {
    test('returns the branches untouched when no filter is active', () {
      final branches = [activeBranch(), mergedBranch()];

      expect(applyFilters(branches, FilterOptions()), same(branches));
    });

    test('maps CLI status values to display statuses', () {
      final branches = [
        wipBranch(),
        activeBranch(),
        mergedBranch(),
        abandonedBranch(),
        conflictBranch(),
      ];

      List<String> namesFor(String status) => applyFilters(
        branches,
        FilterOptions(statuses: [status]),
      ).map((branch) => branch.branchName).toList();

      expect(namesFor('wip'), ['wip']);
      expect(namesFor('active'), ['active']);
      expect(namesFor('merged'), ['merged']);
      expect(namesFor('abandoned'), ['abandoned']);
      expect(namesFor('conflict'), ['conflict']);
    });

    test('matches decorated statuses by prefix', () {
      // "Active (LGTM +1)" has to be selected by --status active.
      final branches = [lgtmBranch(), mergedBranch()];

      final filtered = applyFilters(
        branches,
        FilterOptions(statuses: ['active']),
      );

      expect(filtered.map((branch) => branch.branchName), ['lgtm']);
    });

    test('accepts status values case-insensitively', () {
      final branches = [wipBranch(), mergedBranch()];

      final filtered = applyFilters(branches, FilterOptions(statuses: ['WIP']));

      expect(filtered.map((branch) => branch.branchName), ['wip']);
    });

    test('"gerrit" selects every branch that has Gerrit config', () {
      final branches = [activeBranch(), mergedBranch(), localOnlyBranch()];

      final filtered = applyFilters(
        branches,
        FilterOptions(statuses: ['gerrit']),
      );

      expect(filtered.map((branch) => branch.branchName), ['active', 'merged']);
    });

    test('"local" selects only branches without Gerrit config', () {
      final branches = [activeBranch(), localOnlyBranch()];

      final filtered = applyFilters(
        branches,
        FilterOptions(statuses: ['local']),
      );

      expect(filtered.map((branch) => branch.branchName), ['local-only']);
    });

    test('combines "local" with a regular status', () {
      final branches = [wipBranch(), mergedBranch(), localOnlyBranch()];

      final filtered = applyFilters(
        branches,
        FilterOptions(statuses: ['wip', 'local']),
      );

      expect(filtered.map((branch) => branch.branchName), [
        'wip',
        'local-only',
      ]);
    });

    test('drops branches with Gerrit config but no fetched change', () {
      // Display status is "-", which no Gerrit status matches.
      final branches = [makeBranch(name: 'pending'), mergedBranch()];

      final filtered = applyFilters(
        branches,
        FilterOptions(statuses: ['merged']),
      );

      expect(filtered.map((branch) => branch.branchName), ['merged']);
    });
  });

  group('applyFilters dates', () {
    test('keeps branches after --since', () {
      final branches = [
        makeBranch(name: 'old', localDate: '2025-01-01T00:00:00Z'),
        makeBranch(name: 'new', localDate: '2025-06-01T00:00:00Z'),
      ];

      final filtered = applyFilters(
        branches,
        FilterOptions(since: DateTime.utc(2025, 3)),
      );

      expect(filtered.map((branch) => branch.branchName), ['new']);
    });

    test('keeps branches before --before', () {
      final branches = [
        makeBranch(name: 'old', localDate: '2025-01-01T00:00:00Z'),
        makeBranch(name: 'new', localDate: '2025-06-01T00:00:00Z'),
      ];

      final filtered = applyFilters(
        branches,
        FilterOptions(before: DateTime.utc(2025, 3)),
      );

      expect(filtered.map((branch) => branch.branchName), ['old']);
    });

    test('applies since and before together as a window', () {
      final branches = [
        makeBranch(name: 'before', localDate: '2025-01-01T00:00:00Z'),
        makeBranch(name: 'inside', localDate: '2025-03-15T00:00:00Z'),
        makeBranch(name: 'after', localDate: '2025-06-01T00:00:00Z'),
      ];

      final filtered = applyFilters(
        branches,
        FilterOptions(
          since: DateTime.utc(2025, 2),
          before: DateTime.utc(2025, 4),
        ),
      );

      expect(filtered.map((branch) => branch.branchName), ['inside']);
    });

    test('keeps a branch whose date cannot be parsed', () {
      final branches = [makeBranch(name: 'weird', localDate: 'not-a-date')];

      final filtered = applyFilters(
        branches,
        FilterOptions(since: DateTime.utc(2025, 3)),
      );

      expect(filtered.map((branch) => branch.branchName), ['weird']);
    });
  });

  group('applyFilters diverged', () {
    test('keeps only branches with local or remote divergence', () {
      final branches = [
        makeBranch(name: 'unpushed', localHash: 'aaa', lastUploadHash: 'bbb'),
        makeBranch(
          name: 'stale',
          gerritSquashHash: 'ccc',
          change: makeChange(currentRevision: 'ddd'),
        ),
        makeBranch(
          name: 'in-sync',
          localHash: 'aaa',
          lastUploadHash: 'aaa',
          gerritSquashHash: 'ccc',
          change: makeChange(currentRevision: 'ccc'),
        ),
      ];

      final filtered = applyFilters(branches, FilterOptions(diverged: true));

      expect(filtered.map((branch) => branch.branchName), [
        'unpushed',
        'stale',
      ]);
    });

    test('applies after the status filter rather than instead of it', () {
      final branches = [
        makeBranch(
          name: 'wip-diverged',
          localHash: 'aaa',
          lastUploadHash: 'bbb',
          change: makeChange(workInProgress: true),
        ),
        makeBranch(
          name: 'wip-synced',
          change: makeChange(workInProgress: true),
        ),
        makeBranch(
          name: 'merged-diverged',
          localHash: 'aaa',
          lastUploadHash: 'bbb',
          change: makeChange(status: 'MERGED'),
        ),
      ];

      final filtered = applyFilters(
        branches,
        FilterOptions(statuses: ['wip'], diverged: true),
      );

      expect(filtered.map((branch) => branch.branchName), ['wip-diverged']);
    });
  });

  group('parseDate', () {
    test('returns null for null and empty input', () {
      expect(parseDate(null), isNull);
      expect(parseDate(''), isNull);
    });

    test('parses date-only and full ISO 8601 timestamps', () {
      expect(parseDate('2025-10-10'), DateTime(2025, 10, 10));
      expect(parseDate('2025-10-10T14:30:00'), DateTime(2025, 10, 10, 14, 30));
    });

    test('throws a FormatException naming the bad value', () {
      expect(
        () => parseDate('10/10/2025'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains('10/10/2025'), contains('ISO 8601')),
          ),
        ),
      );
    });
  });

  group('validateStatus', () {
    test('accepts every allowed value, in any case', () {
      const allowed = [
        'wip',
        'active',
        'merged',
        'abandoned',
        'conflict',
        'gerrit',
        'local',
      ];

      for (final status in allowed) {
        expect(() => validateStatus(status), returnsNormally);
        expect(() => validateStatus(status.toUpperCase()), returnsNormally);
      }
    });

    test('rejects unknown values', () {
      expect(() => validateStatus('bogus'), throwsA(isA<FormatException>()));
    });
  });
}

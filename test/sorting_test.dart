import 'package:dgt/sorting.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  group('SortOptions', () {
    test('is empty without a field, regardless of direction', () {
      expect(SortOptions().isEmpty, isTrue);
      expect(SortOptions(field: '').isEmpty, isTrue);
      expect(SortOptions(direction: 'desc').isEmpty, isTrue);
      expect(SortOptions(field: 'name').isEmpty, isFalse);
    });

    test('defaults to ascending unless direction is exactly "desc"', () {
      expect(SortOptions(field: 'name').isAscending, isTrue);
      expect(SortOptions(field: 'name', direction: 'asc').isAscending, isTrue);
      expect(
        SortOptions(field: 'name', direction: 'desc').isDescending,
        isTrue,
      );
      expect(
        SortOptions(field: 'name', direction: 'desc').isAscending,
        isFalse,
      );
    });
  });

  group('applySort', () {
    test('returns the original list when no sort field is set', () {
      final branches = [makeBranch(name: 'b'), makeBranch(name: 'a')];

      expect(applySort(branches, SortOptions()), same(branches));
    });

    test('does not mutate the caller list', () {
      final branches = [makeBranch(name: 'b'), makeBranch(name: 'a')];

      final sorted = applySort(branches, SortOptions(field: 'name'));

      expect(sorted, isNot(same(branches)));
      expect(branches.map((branch) => branch.branchName), ['b', 'a']);
    });

    test('sorts by name in both directions', () {
      final branches = [
        makeBranch(name: 'charlie'),
        makeBranch(name: 'alpha'),
        makeBranch(name: 'bravo'),
      ];

      expect(
        applySort(
          branches,
          SortOptions(field: 'name'),
        ).map((branch) => branch.branchName),
        ['alpha', 'bravo', 'charlie'],
      );
      expect(
        applySort(
          branches,
          SortOptions(field: 'name', direction: 'desc'),
        ).map((branch) => branch.branchName),
        ['charlie', 'bravo', 'alpha'],
      );
    });

    test('sorts by local date', () {
      final branches = [
        makeBranch(name: 'mid', localDate: '2025-03-01T00:00:00Z'),
        makeBranch(name: 'new', localDate: '2025-06-01T00:00:00Z'),
        makeBranch(name: 'old', localDate: '2025-01-01T00:00:00Z'),
      ];

      expect(
        applySort(
          branches,
          SortOptions(field: 'local-date'),
        ).map((branch) => branch.branchName),
        ['old', 'mid', 'new'],
      );
      expect(
        applySort(
          branches,
          SortOptions(field: 'local-date', direction: 'desc'),
        ).map((branch) => branch.branchName),
        ['new', 'mid', 'old'],
      );
    });

    test('sorts by gerrit date', () {
      final branches = [
        makeBranch(
          name: 'new',
          change: makeChange(updated: '2025-06-01 00:00:00.000000000'),
        ),
        makeBranch(
          name: 'old',
          change: makeChange(updated: '2025-01-01 00:00:00.000000000'),
        ),
      ];

      expect(
        applySort(
          branches,
          SortOptions(field: 'gerrit-date'),
        ).map((branch) => branch.branchName),
        ['old', 'new'],
      );
    });

    test('keeps branches without a gerrit date last in both directions', () {
      final branches = [
        makeBranch(name: 'none'),
        makeBranch(
          name: 'dated',
          change: makeChange(updated: '2025-01-01 00:00:00.000000000'),
        ),
      ];

      // Null dates are pinned to the end deliberately: the direction
      // multiplier is not applied to them.
      expect(
        applySort(
          branches,
          SortOptions(field: 'gerrit-date'),
        ).map((branch) => branch.branchName),
        ['dated', 'none'],
      );
      expect(
        applySort(
          branches,
          SortOptions(field: 'gerrit-date', direction: 'desc'),
        ).map((branch) => branch.branchName),
        ['dated', 'none'],
      );
    });

    test('sorts by divergence score, both sides diverged last', () {
      final branches = [
        makeBranch(name: 'one-side', localHash: 'aaa', lastUploadHash: 'bbb'),
        makeBranch(
          name: 'both',
          localHash: 'aaa',
          lastUploadHash: 'bbb',
          gerritSquashHash: 'ccc',
          change: makeChange(currentRevision: 'ddd'),
        ),
        makeBranch(name: 'in-sync', localHash: 'aaa', lastUploadHash: 'aaa'),
      ];

      expect(
        applySort(
          branches,
          SortOptions(field: 'divergences'),
        ).map((branch) => branch.branchName),
        ['in-sync', 'one-side', 'both'],
      );
      expect(
        applySort(
          branches,
          SortOptions(field: 'divergences', direction: 'desc'),
        ).map((branch) => branch.branchName),
        ['both', 'one-side', 'in-sync'],
      );
    });
  });

  group('applySort by status', () {
    test('orders plain statuses by urgency', () {
      final branches = [
        mergedBranch(),
        activeBranch(),
        conflictBranch(),
        wipBranch(),
      ];

      expect(
        applySort(
          branches,
          SortOptions(field: 'status'),
        ).map((branch) => branch.branchName),
        ['conflict', 'wip', 'active', 'merged'],
      );
    });

    test('gives decorated statuses the same priority as their base', () {
      // Regression: the priority table used to be matched exactly, so
      // "Active (LGTM +1)" and "Merge conflict (WIP)" fell into the unknown
      // bucket and tied with each other instead of sorting by urgency.
      final branches = [
        mergedBranch(),
        lgtmBranch(),
        makeBranch(
          name: 'conflict-wip',
          change: makeChange(mergeable: false, workInProgress: true),
        ),
      ];

      expect(
        applySort(
          branches,
          SortOptions(field: 'status'),
        ).map((branch) => branch.branchName),
        ['conflict-wip', 'lgtm', 'merged'],
      );
    });

    test('sorts abandoned after merged and local-only branches last', () {
      final branches = [
        localOnlyBranch(),
        abandonedBranch(),
        mergedBranch(),
        wipBranch(),
      ];

      expect(
        applySort(
          branches,
          SortOptions(field: 'status'),
        ).map((branch) => branch.branchName),
        ['wip', 'merged', 'abandoned', 'local-only'],
      );
    });

    test('reverses the priority order when descending', () {
      final branches = [wipBranch(), conflictBranch(), mergedBranch()];

      expect(
        applySort(
          branches,
          SortOptions(field: 'status', direction: 'desc'),
        ).map((branch) => branch.branchName),
        ['merged', 'wip', 'conflict'],
      );
    });
  });

  group('sort validation', () {
    test('validateSortField accepts every allowed field, in any case', () {
      const allowed = [
        'local-date',
        'gerrit-date',
        'status',
        'divergences',
        'name',
      ];

      for (final field in allowed) {
        expect(() => validateSortField(field), returnsNormally);
        expect(() => validateSortField(field.toUpperCase()), returnsNormally);
      }
    });

    test('validateSortField lists the allowed values when rejecting', () {
      expect(
        () => validateSortField('bogus'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains('bogus'), contains('local-date')),
          ),
        ),
      );
    });

    test('validateSortDirection accepts only asc and desc', () {
      expect(() => validateSortDirection('asc'), returnsNormally);
      expect(() => validateSortDirection('desc'), returnsNormally);
      expect(
        () => validateSortDirection('ASC'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => validateSortDirection('up'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

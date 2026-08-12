import 'package:dgt/branch_status.dart';
import 'package:dgt/cli_options.dart';
import 'package:test/test.dart';

void main() {
  group('BranchStatus.gerritStatuses', () {
    test('is every status a Gerrit change can be in', () {
      expect(BranchStatus.gerritStatuses, <BranchStatus>[
        .wip,
        .active,
        .merged,
        .abandoned,
        .mergeConflict,
      ]);
    });

    test('excludes the no-change state', () {
      expect(BranchStatus.gerritStatuses, isNot(contains(BranchStatus.none)));
    });

    test('is exactly the statuses that have a CLI value', () {
      expect(
        BranchStatus.gerritStatuses,
        everyElement(
          isA<BranchStatus>().having(
            (status) => status.cliValue,
            'cliValue',
            isNotNull,
          ),
        ),
      );
    });
  });

  group('BranchStatus.fromCliValue', () {
    test('maps every CLI value back to its status', () {
      for (final status in BranchStatus.values) {
        if (status.cliValue case final value?) {
          expect(BranchStatus.fromCliValue(value), status);
          expect(BranchStatus.fromCliValue(value.toUpperCase()), status);
        }
      }
    });

    test('returns null for the group selectors and unknown values', () {
      expect(BranchStatus.fromCliValue('gerrit'), isNull);
      expect(BranchStatus.fromCliValue('local'), isNull);
      expect(BranchStatus.fromCliValue('bogus'), isNull);
    });
  });

  group('BranchStatus sort priorities', () {
    test('are unique', () {
      final priorities = BranchStatus.values
          .map((status) => status.sortPriority)
          .toList();

      expect(priorities.toSet(), hasLength(priorities.length));
    });

    test('order merge conflicts first and unattached branches last', () {
      final byPriority = [...BranchStatus.values]
        ..sort((a, b) => a.sortPriority.compareTo(b.sortPriority));

      expect(byPriority.first, BranchStatus.mergeConflict);
      expect(byPriority.last, BranchStatus.none);
    });
  });

  group('CliOptions status metadata', () {
    test('derives the allowed values from the enum plus the selectors', () {
      expect(CliOptions.allowedStatusValues, [
        'wip',
        'active',
        'merged',
        'abandoned',
        'conflict',
        CliOptions.gerritStatusValue,
        CliOptions.localStatusValue,
      ]);
    });

    test('maps every CLI value to its display prefix', () {
      expect(CliOptions.statusMapping, {
        'wip': 'WIP',
        'active': 'Active',
        'merged': 'Merged',
        'abandoned': 'Abandoned',
        'conflict': 'Merge conflict',
      });
    });

    test('keeps the group selectors out of the prefix mapping', () {
      // An empty prefix would match every status, which is what made
      // `--status local` return everything.
      expect(
        CliOptions.statusMapping.containsKey(CliOptions.gerritStatusValue),
        isFalse,
      );
      expect(
        CliOptions.statusMapping.containsKey(CliOptions.localStatusValue),
        isFalse,
      );
      expect(CliOptions.statusMapping.values, everyElement(isNotEmpty));
    });

    test('describes every allowed value', () {
      for (final value in CliOptions.allowedStatusValues) {
        expect(CliOptions.statusDescriptions[value], isNotNull);
        expect(CliOptions.statusDescriptions[value], isNotEmpty);
      }
    });
  });

}

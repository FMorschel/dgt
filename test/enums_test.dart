import 'package:dgt/branch_status.dart';
import 'package:dgt/cli_options.dart';
import 'package:dgt/date_display.dart';
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

  group('DateDisplay', () {
    test('defaults to local time', () {
      expect(DateDisplay.defaultValue, DateDisplay.local);
    });

    test('maps CLI values back to modes, ignoring case', () {
      expect(DateDisplay.fromCliValue('local'), DateDisplay.local);
      expect(DateDisplay.fromCliValue('utc'), DateDisplay.utc);
      expect(DateDisplay.fromCliValue('UTC'), DateDisplay.utc);
    });

    test('returns null for unknown and missing values', () {
      expect(DateDisplay.fromCliValue('mars'), isNull);
      expect(DateDisplay.fromCliValue(null), isNull);
    });

    test('converts an instant into the mode it names', () {
      final instant = DateTime.utc(2025, 10, 7, 18, 30);

      expect(DateDisplay.utc.apply(instant), instant);
      expect(DateDisplay.utc.apply(instant).isUtc, isTrue);
      expect(DateDisplay.local.apply(instant).isUtc, isFalse);
      // Converting changes the wall clock, never the instant.
      expect(DateDisplay.local.apply(instant).toUtc(), instant);
    });

    test('is exposed to the CLI with descriptions', () {
      expect(CliOptions.allowedDateDisplays, ['local', 'utc']);
      for (final value in CliOptions.allowedDateDisplays) {
        expect(CliOptions.dateDisplayDescriptions[value], isNotEmpty);
      }
    });
  });
}

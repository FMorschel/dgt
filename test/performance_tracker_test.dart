import 'package:dgt/performance_tracker.dart';
import 'package:test/test.dart';

void main() {
  group('PerformanceTracker', () {
    late PerformanceTracker tracker;

    setUp(() {
      tracker = PerformanceTracker();
    });

    test('starts out empty', () {
      expect(tracker.hasTimings, isFalse);
      expect(tracker.hasActiveTimers, isFalse);
      expect(tracker.getTimings(), isEmpty);
      expect(tracker.getTotalTime(), 0);
    });

    test('records a timing once an operation ends', () {
      tracker.startTimer('fetch');
      expect(tracker.hasActiveTimers, isTrue);
      expect(tracker.hasTimings, isFalse);

      tracker.endTimer('fetch');

      expect(tracker.hasActiveTimers, isFalse);
      expect(tracker.hasTimings, isTrue);
      expect(tracker.getTimings().keys, ['fetch']);
      expect(tracker.getTimings()['fetch'], greaterThanOrEqualTo(0));
    });

    test('tracks several operations independently', () {
      tracker
        ..startTimer('git')
        ..startTimer('gerrit')
        ..endTimer('git');

      expect(tracker.hasActiveTimers, isTrue, reason: 'gerrit still running');
      expect(tracker.getTimings().keys, ['git']);

      tracker.endTimer('gerrit');

      expect(tracker.getTimings().keys, unorderedEquals(['git', 'gerrit']));
    });

    test('rejects starting the same operation twice', () {
      tracker.startTimer('fetch');

      expect(() => tracker.startTimer('fetch'), throwsStateError);
    });

    test('rejects ending an operation that was never started', () {
      expect(() => tracker.endTimer('fetch'), throwsStateError);
    });

    test('allows re-timing an operation after it ended', () {
      tracker
        ..startTimer('fetch')
        ..endTimer('fetch');

      expect(() => tracker.startTimer('fetch'), returnsNormally);
    });

    test('returns an unmodifiable view of the timings', () {
      tracker
        ..startTimer('fetch')
        ..endTimer('fetch');

      expect(() => tracker.getTimings()['other'] = 1, throwsUnsupportedError);
    });

    test('reports a total time once any timer has started', () {
      tracker.startTimer('fetch');

      expect(tracker.getTotalTime(), greaterThanOrEqualTo(0));
    });

    test('reset clears timings, active timers and the total', () {
      tracker
        ..startTimer('done')
        ..endTimer('done')
        ..startTimer('running')
        ..reset();

      expect(tracker.hasTimings, isFalse);
      expect(tracker.hasActiveTimers, isFalse);
      expect(tracker.getTotalTime(), 0);
      // A previously running timer is gone, not merely detached.
      expect(() => tracker.endTimer('running'), throwsStateError);
    });
  });
}

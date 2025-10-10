/// A utility class for tracking and reporting performance metrics of
/// operations.
///
/// This class helps measure execution time of different operations in the CLI
/// tool, providing insights into performance bottlenecks and execution
/// patterns.
class PerformanceTracker {
  /// Map storing operation names to their durations in milliseconds.
  final Map<String, int> _timings = {};

  /// Map storing operation names to their start times.
  final Map<String, DateTime> _startTimes = {};

  /// The overall start time for tracking total execution.
  DateTime? _totalStartTime;

  /// Starts timing an operation with the given [operationName].
  ///
  /// If this is the first operation being timed, also starts the total timer.
  /// Throws [StateError] if the operation is already being timed.
  void startTimer(String operationName) {
    if (_startTimes.containsKey(operationName)) {
      throw StateError(
        'Timer for operation "$operationName" is already running',
      );
    }

    // Start total timer on first operation
    _totalStartTime ??= DateTime.now();

    _startTimes[operationName] = DateTime.now();
  }

  /// Ends timing for the operation with the given [operationName].
  ///
  /// Calculates and stores the duration in milliseconds.
  /// Throws [StateError] if the operation was not started.
  void endTimer(String operationName) {
    if (!_startTimes.containsKey(operationName)) {
      throw StateError('Timer for operation "$operationName" was not started');
    }

    final startTime = _startTimes.remove(operationName)!;
    final duration = DateTime.now().difference(startTime).inMilliseconds;
    _timings[operationName] = duration;
  }

  /// Returns a map of all recorded timings.
  ///
  /// The map keys are operation names and values are durations in milliseconds.
  Map<String, int> getTimings() {
    return Map.unmodifiable(_timings);
  }

  /// Returns the total execution time in milliseconds.
  ///
  /// This is calculated from when the first timer was started to now.
  /// Returns 0 if no timers have been started.
  int getTotalTime() {
    if (_totalStartTime == null) {
      return 0;
    }
    return DateTime.now().difference(_totalStartTime!).inMilliseconds;
  }

  /// Clears all recorded timings and resets the tracker.
  void reset() {
    _timings.clear();
    _startTimes.clear();
    _totalStartTime = null;
  }

  /// Returns true if any timers are currently running.
  bool get hasActiveTimers => _startTimes.isNotEmpty;

  /// Returns true if any timings have been recorded.
  bool get hasTimings => _timings.isNotEmpty;
}

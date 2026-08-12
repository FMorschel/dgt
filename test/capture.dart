import 'dart:async';

/// Runs [body] and returns everything it printed, one entry per line.
///
/// `Terminal` and the config service write through `print`, so a zone with a
/// custom print handler is enough to inspect their output without changing
/// production code.
List<String> capturePrints(void Function() body) {
  final lines = <String>[];
  runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return lines;
}

/// Asynchronous counterpart of [capturePrints].
Future<List<String>> capturePrintsAsync(Future<void> Function() body) async {
  final lines = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return lines;
}

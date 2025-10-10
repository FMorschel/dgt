import 'package:ansicolor/ansicolor.dart';

/// A utility class for colored terminal output.
///
/// This class provides static methods to print colored text to the terminal
/// using ANSI color codes. It's designed to make status messages more visually
/// distinct and easier to read.
class Terminal {
  // Define color pens for different message types
  static final AnsiPen _greenPen = AnsiPen()..green();
  static final AnsiPen _yellowPen = AnsiPen()..yellow();
  static final AnsiPen _redPen = AnsiPen()..red();
  static final AnsiPen _cyanPen = AnsiPen()..cyan();
  static final AnsiPen _bluePen = AnsiPen()..blue();

  /// Print text in green color (typically for success/active status).
  static void green(String text) {
    print(_greenPen(text));
  }

  /// Print text in green color (alias for success messages).
  static void success(String text) {
    print(_greenPen(text));
  }

  /// Print text in yellow color (typically for warnings/WIP status).
  static void yellow(String text) {
    print(_yellowPen(text));
  }

  /// Print text in yellow color (alias for warning messages).
  static void warning(String text) {
    print(_yellowPen(text));
  }

  /// Print text in red color (typically for errors/merge conflicts).
  static void red(String text) {
    print(_redPen(text));
  }

  /// Print text in red color (alias for error messages).
  static void error(String text) {
    print(_redPen(text));
  }

  /// Print text in cyan color (typically for merged status).
  static void cyan(String text) {
    print(_cyanPen(text));
  }

  /// Print text in blue color.
  static void blue(String text) {
    print(_bluePen(text));
  }

  /// Print text in default terminal color (no color applied).
  static void info(String text) {
    print(text);
  }

  /// Print text in default terminal color (alias for info).
  static void plain(String text) {
    print(text);
  }

  // ==== Color string methods (return colored strings without printing) ====

  /// Returns a string colored in green.
  static String greenText(String text) {
    return _greenPen(text);
  }

  /// Returns a string colored in yellow.
  static String yellowText(String text) {
    return _yellowPen(text);
  }

  /// Returns a string colored in red.
  static String redText(String text) {
    return _redPen(text);
  }

  /// Returns a string colored in cyan.
  static String cyanText(String text) {
    return _cyanPen(text);
  }

  /// Returns a string colored in blue.
  static String blueText(String text) {
    return _bluePen(text);
  }
}

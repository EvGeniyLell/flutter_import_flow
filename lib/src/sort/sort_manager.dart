import 'package:flutter_import_flow/src/sort/sort_strategies_exports.dart';
import 'package:flutter_import_flow/src/sort/sort_strategies_imports.dart';
import 'package:flutter_import_flow/src/sort/sort_strategies_parts.dart';
import 'package:flutter_import_flow/src/sort/sort_strategy.dart';

class SortManager {
  factory SortManager({
    required String packageName,
  }) {
    return SortManager._(
      strategies: [
        ...ImportSortStrategy.all(packageName),
        ...ExportSortStrategy.all(packageName),
        PartSortStrategy.parts(),
      ],
    );
  }

  SortManager._({required this.strategies});

  final List<SortStrategy> strategies;
  String _smartLine = '';

  /// Return null if not sorted
  String? sort({
    required List<String> lines,
    required bool useComments,
  }) {
    _smartLine = '';
    strategies.forEach((s) {
      s.clearList();
    });

    final beforeLines = <String>[];
    final afterLines = <String>[];
    var isMultiLineString = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (_isMultiline(line)) {
        isMultiLineString = !isMultiLineString;
      }

      final wasEmpty = strategies.everyListIsEmpty;

      void remove(int count) {
        if (wasEmpty) {
          for (var i = 1; i < count; i += 1) {
            beforeLines.removeLast();
          }
        } else {
          for (var i = 1; i < count; i += 1) {
            afterLines.removeLast();
          }
        }
      }

      if ((!isMultiLineString && !_tryAdd(line, remove)) || isMultiLineString) {
        if (strategies.everyListIsEmpty) {
          beforeLines.add(line);
        } else {
          afterLines.add(line);
        }
      }
    }

    // If no imports return null
    if (strategies.everyListIsEmpty) {
      return null;
    }

    final resultLinesBlocks = <List<String>>[];

    // Before Lines
    if (beforeLines.isNotEmpty) {
      if (beforeLines.last.trim() == '') {
        beforeLines.removeLast();
      }
      if (beforeLines.isNotEmpty) {
        resultLinesBlocks.add(beforeLines);
      }
    }

    // Sorted Lines
    strategies.forEach((strategy) {
      final strategyList = strategy.getList();
      if (strategyList.isNotEmpty) {
        final list = <String>[];
        if (useComments) {
          list.add(strategy.comment);
        }
        list.addAll(strategyList);
        resultLinesBlocks.add(list);
      }
    });

    // After Lines
    if (afterLines.isNotEmpty) {
      if (afterLines.isNotEmpty) {
        resultLinesBlocks.add(afterLines);
      }
    }

    // Convert to string
    final result = '${resultLinesBlocks.reduce((value, element) {
      if (element.isNotEmpty) {
        value
          ..add('')
          ..addAll(element);
      }
      return value;
    }).smartJoin()}\n';
    final original = '${lines.join('\n')}\n';

    if (original == result) {
      return null;
    }
    return result;
  }

  bool _tryAdd(String string, void Function(int count) callback) {
    final result = strategies.tryAdd(string);
    if (result) {
      _smartLine = '';
      return true;
    }
    if (_smartLine.isEmpty) {
      if (string.startsWith('import ')) {
        _smartLine = string;
      }
    } else {
      _smartLine += '\n$string';
      if (string.endsWith(';')) {
        final result = strategies.tryAdd(_smartLine);
        if (result) {
          callback(_smartLine.split('\n').length);
        }
        _smartLine = '';
        return result;
      }
    }
    return false;
  }

  bool _isMultiline(String string) {
    int _count(String string, String looking) {
      return string.split(looking).length - 1;
    }

    return _count(string, "'''") == 1 || _count(string, '"""') == 1;
  }
}

extension _SortStrategyListExtension on List<SortStrategy> {
  bool get everyListIsEmpty => every((strategy) => strategy.getList().isEmpty);

  bool tryAdd(String string) {
    for (final strategy in this) {
      if (strategy.tryAdd(string)) {
        return true;
      }
    }
    return false;
  }
}

extension _StringListExtension on List<String> {
  String smartJoin() {
    var canBeDouble = false;
    for (var i = 0; i < length; i += 1) {
      final s = this[i].trim();
      if (s == '') {
        if (canBeDouble) {
          removeAt(i);
          i -= 1;
        }
        canBeDouble = true;
      } else {
        canBeDouble = false;
      }
    }
    smartStartTrim();
    smartEndTrim();
    return join('\n');
  }

  void smartStartTrim() {
    for (var i = 0; i < length; i += 1) {
      final s = this[i].trim();
      if (s == '') {
        removeAt(i);
        i -= 1;
      } else {
        return;
      }
    }
    return;
  }

  void smartEndTrim() {
    for (var i = length - 1; i >= 0; i -= 1) {
      final s = this[i].trim();
      if (s == '') {
        removeAt(i);
      } else {
        return;
      }
    }
    return;
  }
}

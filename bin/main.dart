import 'dart:io';

import 'package:args/args.dart';
import 'package:tint/tint.dart';
import 'package:yaml/yaml.dart';

import 'package:flutter_import_sorter/args.dart' as local_args;
import 'package:flutter_import_sorter/files.dart' as files;
import 'package:flutter_import_sorter/sort_manager.dart';

void main(List<String> args) {
  // Parsing arguments
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addFlag('ignore-config', negatable: false)
    ..addFlag('exit-if-changed', negatable: false)
    ..addFlag('use-comments', negatable: false);

  final argResults = parser.parse(args).arguments;
  if (argResults.contains('-h') || argResults.contains('--help')) {
    local_args.outputHelp();
    exit(0);
  }

  /*
  Getting the package name and dependencies/dev_dependencies
  Package name is one factor used to identify project imports
  Dependencies/dev_dependencies names are used to identify package imports
  */
  final currentPath = Directory.current.path;
  final pubspecYamlFile = File('$currentPath/pubspec.yaml');
  final pubspecYaml = loadYaml(pubspecYamlFile.readAsStringSync());

  // Getting all dependencies and project package name
  final packageName = pubspecYaml['name'];
  final dependencies = [];

  final stopwatch = Stopwatch()..start();

  final pubspecLockFile = File('$currentPath/pubspec.lock');
  final pubspecLock = loadYaml(pubspecLockFile.readAsStringSync());
  dependencies.addAll(pubspecLock['packages'].keys);

  var useComments = false;
  var exitOnChange = false;
  final ignoredFiles = [];

  // Reading from config in pubspec.yaml safely
  if (!argResults.contains('--ignore-config') &&
      pubspecYaml.containsKey('flutter_import_sorter')) {
    final config = pubspecYaml['flutter_import_sorter'];

    if (config.containsKey('comments')) {
      useComments = config['comments'];
    }
    if (config.containsKey('ignored_files')) {
      ignoredFiles.addAll(config['ignored_files']);
    }
  } else {
    useComments = argResults.contains('--use-comments');
    exitOnChange = argResults.contains('--exit-if-changed');
  }

  // Getting all the dart files for the project
  final dartFiles = files.dartFiles(currentPath, args);
  final containsFlutter = dependencies.contains('flutter');
  final containsRegistrant = dartFiles
      .containsKey('$currentPath/lib/generated_plugin_registrant.dart');

  stdout
    ..writeln('contains flutter: $containsFlutter')
    ..writeln('contains registrant: $containsRegistrant');

  if (containsFlutter && containsRegistrant) {
    dartFiles.remove('$currentPath/lib/generated_plugin_registrant.dart');
  }

  for (final pattern in ignoredFiles) {
    dartFiles.removeWhere(
      (key, _) => RegExp(pattern).hasMatch(key.replaceFirst(currentPath, '')),
    );
  }

  stdout.write('┏━━ Sorting ${dartFiles.length} dart files');

  // Sorting and writing to files
  final sortedFiles = [];
  final success = '✔'.green();
  final sortManager = SortManager(
    packageName: packageName,
  );

  for (final filePath in dartFiles.keys) {
    final file = dartFiles[filePath];
    if (file == null) {
      continue;
    }

    final sortResult = sortManager.sort(
      lines: file.readAsLinesSync(),
      useComments: useComments,
    );

    if (sortResult == null) {
      continue;
    }

    if (exitOnChange) {
      stdout
          .writeln('\n┗━━🚨 File $filePath does not have its imports sorted.');
      exit(1);
    }

    dartFiles[filePath]?.writeAsStringSync(sortResult);
    sortedFiles.add(filePath);
  }

  stopwatch.stop();

  // Outputting results
  if (sortedFiles.length > 1) {
    stdout.write('\n');
  }
  for (int i = 0; i < sortedFiles.length; i++) {
    final file = dartFiles[sortedFiles[i]];
    stdout.write(
      '${sortedFiles.length == 1 ? '\n' : ''}┃  '
      '${i == sortedFiles.length - 1 ? '┗' : '┣'}━━ '
      '$success Sorted imports for '
      '${file?.path.replaceFirst(currentPath, '')}/',
    );
    final filename = file!.path.split(Platform.pathSeparator).last;
    stdout.write('$filename\n');
  }

  if (sortedFiles.isEmpty) {
    stdout.write('\n');
  }
  stdout.write(
    '┗━━ $success Sorted '
    '${sortedFiles.length} files in '
    '${stopwatch.elapsed.inSeconds}.'
    '${stopwatch.elapsedMilliseconds} seconds\n',
  );
}

#!/usr/bin/env dart

library dapublock;

import 'dart:io';
import 'package:yaml/yaml.dart';

Future<void> main(List<String> args) async {
  final File pubspecYaml = File('${args[0]}/pubspec.yaml');
  final List<Dependency> declaredDependencies = <Dependency>[];
  declaredDependencies
      .addAll(await getDeclaredDependencies(pubspecYaml, 'dependencies'));
  declaredDependencies
      .addAll(await getDeclaredDependencies(pubspecYaml, 'dev_dependencies'));

  final File pubspecLock = File('${args[0]}/pubspec.lock');
  final List<Dependency> lockedDependencies = <Dependency>[];
  lockedDependencies.addAll(await getLockedDependencies(pubspecLock));

  final List<DependencyUpdate> updates =
      getUpdates(declaredDependencies, lockedDependencies);
  await updateFile(pubspecYaml, updates);
}

Future<List<Dependency>> getDeclaredDependencies(
    File file, String section) async {
  final List<Dependency> list = <Dependency>[];

  final String content = await file.readAsString();
  final dynamic yaml = loadYaml(content);

  if (yaml[section] != null) {
    final YamlMap dependencies = yaml[section];

    for (final MapEntry<dynamic, dynamic> entry in dependencies.entries) {
      if (entry.value is String) {
        final String name = entry.key.toString();
        final String value = entry.value.toString();

        if (name.isNotEmpty && value.isNotEmpty) {
          list.add(Dependency(name, value));
        }
      }
    }
  }

  return list;
}

Future<List<Dependency>> getLockedDependencies(File file) async {
  final List<Dependency> list = <Dependency>[];

  final String content = await file.readAsString();
  final List<String> lines =
      content.split('\n').map((String e) => e.trim()).toList();

  String lastName = '';

  for (final String line in lines) {
    if (line.startsWith('name:')) {
      lastName = line.replaceAll('name: ', '').trim();
    } else if (line.startsWith('version:')) {
      final String version =
          line.replaceAll('version: ', '').replaceAll('"', '').trim();
      list.add(Dependency(lastName, version));
    }
  }

  return list;
}

List<DependencyUpdate> getUpdates(List<Dependency> declaredDependencies,
    List<Dependency> lockedDependencies) {
  final List<DependencyUpdate> list = <DependencyUpdate>[];

  for (final Dependency declared in declaredDependencies) {
    final Dependency locked =
        getDependencyByName(declared.name, lockedDependencies);

    if (declared.versionCode != locked.version) {
      list.add(DependencyUpdate(declared, locked));
    }
  }

  return list;
}

Dependency getDependencyByName(String name, List<Dependency> list) {
  for (final Dependency dependency in list) {
    if (dependency.name == name) {
      return dependency;
    }
  }

  throw Error();
}

Future<void> updateFile(File file, List<DependencyUpdate> updates) async {
  String yaml = await file.readAsString();

  for (final DependencyUpdate update in updates) {
    final Dependency newVersion =
        update.declared.withVersion(update.locked.version);

    final String search = '${update.declared.name}: ${update.declared.version}';
    final String replace = '${newVersion.name}: ${newVersion.version}';

    yaml = yaml.replaceFirst(search, replace);
  }

  file.writeAsStringSync(yaml);
}

class Dependency {
  final String name;
  final String version;

  String get versionCode => version.replaceAll('^', '');

  Dependency(this.name, this.version);

  Dependency withVersion(String newVersion) =>
      Dependency(name, version.replaceAll(versionCode, newVersion));

  @override
  String toString() => '$name: $version';
}

class DependencyUpdate {
  final Dependency declared;
  final Dependency locked;

  DependencyUpdate(this.declared, this.locked);

  @override
  String toString() => '$declared => $locked';
}

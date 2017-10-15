/*
 * # Copyright (c) 2016-2017 The Khronos Group Inc.
 * # Copyright (c) 2016 Alexey Knyazev
 * #
 * # Licensed under the Apache License, Version 2.0 (the "License");
 * # you may not use this file except in compliance with the License.
 * # You may obtain a copy of the License at
 * #
 * #     http://www.apache.org/licenses/LICENSE-2.0
 * #
 * # Unless required by applicable law or agreed to in writing, software
 * # distributed under the License is distributed on an "AS IS" BASIS,
 * # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * # See the License for the specific language governing permissions and
 * # limitations under the License.
 */

library gltf.context;

import 'dart:collection';

import 'base/gltf_property.dart';
import 'errors.dart';
import 'ext/extensions.dart';

class Context {
  final bool validate;
  final int maxIssues;
  final Set<String> ignoredIssues = new Set<String>();
  final Map<String, Severity> severityOverrides;

  final List<String> path = <String>[];

  Context(
      {this.validate: true,
      this.maxIssues: 0,
      List<String> ignoredIssues,
      this.severityOverrides}) {
    _extensionsLoadedView = new UnmodifiableListView(_extensionsLoaded);
    _extensionsUsedView = new UnmodifiableListView(_extensionsUsed);
    _extensionsFunctionsView = new UnmodifiableMapView(_extensionsFunctions);
    _resourcesView = new UnmodifiableListView(_resources);

    if (ignoredIssues != null) {
      this.ignoredIssues.addAll(ignoredIssues);
    }
  }

  final Map<ExtensionTuple, ExtFuncs> _extensionsFunctions =
      <ExtensionTuple, ExtFuncs>{};
  Map<ExtensionTuple, ExtFuncs> _extensionsFunctionsView;
  Map<ExtensionTuple, ExtFuncs> get extensionsFunctions =>
      _extensionsFunctionsView;

  final List<String> _extensionsUsed = <String>[];
  List<String> _extensionsUsedView;
  List<String> get extensionsUsed => _extensionsUsedView;

  final List<String> _extensionsLoaded = <String>[];
  List<String> _extensionsLoadedView;
  List<String> get extensionsLoaded => _extensionsLoadedView;

  final List<Map<String, Object>> _resources = <Map<String, Object>>[];
  List<Map<String, Object>> _resourcesView;
  List<Map<String, Object>> get resources => _resourcesView;

  final Set<Extension> _userExtensions = new Set<Extension>();

  final List<Issue> _issues = <Issue>[];

  List<Issue> get issues => _issues;

  Iterable<Issue> get errors => getErrors();

  List<Issue> getErrors() =>
      _issues.where((issue) => issue.severity == Severity.Error).toList();

  Iterable<Issue> get warnings => getWarnings();

  List<Issue> getWarnings() =>
      _issues.where((issue) => issue.severity == Severity.Warning).toList();

  List<Issue> getInfos() =>
      _issues.where((issue) => issue.severity == Severity.Information).toList();

  List<Issue> getHints() =>
      _issues.where((issue) => issue.severity == Severity.Hint).toList();

  String getPointerString([String token]) {
    if (path.isEmpty) {
      return token == null ? '/' : '/$token';
    }

    var i = 0;
    final sb = new StringBuffer('/')..write(path[0]);
    while (++i < path.length) {
      sb..write('/')..write(path[i]);
    }

    if (token != null) {
      sb..write('/')..write(token);
    }

    return sb.toString();
  }

  void registerExtensions(List<Extension> userExtensions) {
    _userExtensions.addAll(userExtensions);
  }

  void initExtensions(List<String> extensionsUsed) {
    _extensionsUsed.addAll(extensionsUsed);

    for (final extensionName in extensionsUsed) {
      final extension = _userExtensions.firstWhere(
          (extension) => extension.name == extensionName,
          orElse: () => defaultExtensions.firstWhere(
              (extension) => extension.name == extensionName,
              orElse: () => null));

      if (extension == null) {
        addIssue(LinkError.unsupportedExtension,
            name: EXTENSIONS_USED, args: [extensionName]);
        continue;
      }

      extension.functions?.forEach((type, funcs) {
        _extensionsFunctions[new ExtensionTuple(type, extension.name)] = funcs;
      });
      _extensionsLoaded.add(extensionName);
    }
  }

  void addIssue(IssueType issueType,
      {String name, List<Object> args, int offset, int index}) {
    if (ignoredIssues.contains(issueType.code)) {
      return;
    }

    if (maxIssues > 0 && _issues.length == maxIssues) {
      throw const IssuesLimitExceededException();
    }

    final severityOverride =
        (severityOverrides != null) ? severityOverrides[issueType.code] : null;

    if (offset != null) {
      _issues.add(new Issue(issueType, args,
          offset: offset, severityOverride: severityOverride));
    } else {
      final token = index != null ? index.toString() : name;
      _issues.add(new Issue(issueType, args,
          pointer: getPointerString(token),
          severityOverride: severityOverride));
    }
  }

  void addResource(Map<String, Object> info) => _resources.add(info);
}

class IssuesLimitExceededException implements Exception {
  const IssuesLimitExceededException();
}

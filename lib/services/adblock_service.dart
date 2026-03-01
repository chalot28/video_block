import 'dart:async';
import 'dart:io';

import '../utils/constants.dart';

class AdBlockService {
  bool enabled;

  final Set<String> _blockedDomains = <String>{};
  final Set<String> _allowedDomains = <String>{};
  final Set<String> _blockedKeywords = <String>{};

  DateTime? _lastUpdated;
  String _status = 'Loaded bundled rules';

  Completer<void>? _initCompleter;

  AdBlockService({this.enabled = true});

  int get ruleCount =>
      _blockedDomains.length + _allowedDomains.length + _blockedKeywords.length;

  DateTime? get lastUpdated => _lastUpdated;

  String get status => _status;

  Future<void> initialize({bool refreshRemoteRules = true}) {
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();

    _loadBundledRules();
    if (!refreshRemoteRules) {
      _initCompleter!.complete();
      return _initCompleter!.future;
    }

    refreshFilterLists().whenComplete(() {
      if (!(_initCompleter?.isCompleted ?? true)) {
        _initCompleter!.complete();
      }
    });

    return _initCompleter!.future;
  }

  Future<void> refreshFilterLists() async {
    final nextBlockedDomains = <String>{..._blockedDomains};
    final nextAllowedDomains = <String>{..._allowedDomains};
    final nextBlockedKeywords = <String>{..._blockedKeywords};

    var loadedLists = 0;

    for (final source in AppConstants.adFilterListUrls) {
      final content = await _downloadFilterList(source);
      if (content == null || content.isEmpty) {
        continue;
      }

      _parseFilterListContent(
        content,
        blockedDomains: nextBlockedDomains,
        allowedDomains: nextAllowedDomains,
        blockedKeywords: nextBlockedKeywords,
      );
      loadedLists++;
    }

    if (loadedLists > 0) {
      _blockedDomains
        ..clear()
        ..addAll(nextBlockedDomains);
      _allowedDomains
        ..clear()
        ..addAll(nextAllowedDomains);
      _blockedKeywords
        ..clear()
        ..addAll(nextBlockedKeywords);
      _lastUpdated = DateTime.now();
      _status = 'Loaded $loadedLists remote filter lists';
    } else {
      _status = 'Remote update failed, using bundled rules';
    }
  }

  void _loadBundledRules() {
    _blockedDomains
      ..clear()
      ..addAll(AppConstants.adHostFilters.map((entry) => entry.toLowerCase()));
    _allowedDomains
      ..clear()
      ..addAll(AppConstants.videoHostAllowList.map((entry) => entry.toLowerCase()));
    _blockedKeywords
      ..clear()
      ..addAll(AppConstants.adPathKeywords.map((entry) => entry.toLowerCase()));
    _lastUpdated ??= DateTime.now();
  }

  Future<String?> _downloadFilterList(String sourceUrl) async {
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null) {
      return null;
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'VideoBlock/1.0');
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return await response.transform(SystemEncoding().decoder).join();
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  void _parseFilterListContent(
    String content, {
    required Set<String> blockedDomains,
    required Set<String> allowedDomains,
    required Set<String> blockedKeywords,
  }) {
    final lines = content.split('\n');
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty ||
          line.startsWith('!') ||
          line.startsWith('[') ||
          line.startsWith('#')) {
        continue;
      }

      if (line.startsWith('@@')) {
        final allowDomain = _extractDomainFromRule(line.substring(2));
        if (allowDomain != null) {
          allowedDomains.add(allowDomain);
        }
        continue;
      }

      final hostsEntry = _extractDomainFromHostsLine(line);
      if (hostsEntry != null) {
        blockedDomains.add(hostsEntry);
        continue;
      }

      final ruleDomain = _extractDomainFromRule(line);
      if (ruleDomain != null) {
        blockedDomains.add(ruleDomain);
        continue;
      }

      final keyword = _extractKeywordToken(line);
      if (keyword != null) {
        blockedKeywords.add(keyword);
      }
    }
  }

  String? _extractDomainFromHostsLine(String line) {
    final normalized = line.split('#').first.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final parts = normalized.split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return null;
    }

    final first = parts.first;
    if (first != '0.0.0.0' && first != '127.0.0.1' && first != '::1') {
      return null;
    }

    final host = parts[1].trim().toLowerCase();
    if (_isDomainLike(host)) {
      return host;
    }
    return null;
  }

  String? _extractDomainFromRule(String line) {
    var normalized = line.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    if (normalized.startsWith('||')) {
      normalized = normalized.substring(2);
    }

    if (normalized.startsWith('|')) {
      normalized = normalized.substring(1);
    }

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      final uri = Uri.tryParse(normalized.replaceAll('|', ''));
      if (uri?.host case final String host?) {
        return host.toLowerCase();
      }
      return null;
    }

    final stopIndex = normalized.indexOf(RegExp(r'[\^\/$*]'));
    if (stopIndex > 0) {
      normalized = normalized.substring(0, stopIndex);
    }

    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9.-]'), '');
    if (_isDomainLike(normalized)) {
      return normalized;
    }
    return null;
  }

  String? _extractKeywordToken(String ruleLine) {
    final candidate = ruleLine
        .toLowerCase()
        .replaceAll('||', '')
        .replaceAll('^', '')
        .replaceAll('|', '')
        .replaceAll('*', '')
        .trim();

    if (candidate.length < 5) {
      return null;
    }

    final containsSignals =
        candidate.contains('ad') ||
            candidate.contains('sponsor') ||
            candidate.contains('track') ||
            candidate.contains('analytics') ||
            candidate.contains('doubleclick');

    if (!containsSignals) {
      return null;
    }

    if (candidate.contains(' ') || candidate.contains(',')) {
      return null;
    }

    return candidate;
  }

  bool _isDomainLike(String value) {
    if (value.isEmpty || value.startsWith('.') || value.endsWith('.')) {
      return false;
    }
    if (!value.contains('.')) {
      return false;
    }
    if (value.contains('..')) {
      return false;
    }
    return RegExp(r'^[a-z0-9.-]+$').hasMatch(value);
  }

  bool _matchesDomain(String host, Set<String> domains) {
    if (domains.isEmpty) return false;
    if (domains.contains(host)) return true;

    var index = host.indexOf('.');
    while (index >= 0) {
      final parent = host.substring(index + 1);
      if (domains.contains(parent)) return true;
      index = host.indexOf('.', index + 1);
    }
    return false;
  }

  bool shouldBlockUri(Uri? uri) {
    if (!enabled || uri == null) {
      return false;
    }

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final fullUrl = uri.toString().toLowerCase();

    final isAllowListed = _matchesDomain(host, _allowedDomains);

    if (isAllowListed) {
      return false;
    }

    final blockedHost = _matchesDomain(host, _blockedDomains);

    if (blockedHost) {
      return true;
    }

    return _blockedKeywords.any((token) => path.contains(token) || fullUrl.contains(token));
  }

  bool shouldBlockRequestUrl(String url) {
    final uri = Uri.tryParse(url);
    return shouldBlockUri(uri);
  }
}

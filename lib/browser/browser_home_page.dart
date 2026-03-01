import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/adblock_service.dart';

enum SearchEngine {
  google,
  bing,
  duckDuckGo,
}

extension SearchEngineX on SearchEngine {
  String get label {
    switch (this) {
      case SearchEngine.google:
        return 'Google';
      case SearchEngine.bing:
        return 'Bing';
      case SearchEngine.duckDuckGo:
        return 'DuckDuckGo';
    }
  }

  Uri get homeUri {
    switch (this) {
      case SearchEngine.google:
        return Uri.parse('https://www.google.com');
      case SearchEngine.bing:
        return Uri.parse('https://www.bing.com');
      case SearchEngine.duckDuckGo:
        return Uri.parse('https://duckduckgo.com');
    }
  }

  Uri searchUri(String query) {
    switch (this) {
      case SearchEngine.google:
        return Uri.https('www.google.com', '/search', {'q': query});
      case SearchEngine.bing:
        return Uri.https('www.bing.com', '/search', {'q': query});
      case SearchEngine.duckDuckGo:
        return Uri.https('duckduckgo.com', '/', {'q': query});
    }
  }
}

class BrowserTab {
  final String id;
  final GlobalKey webViewKey = GlobalKey();

  String url;
  String title;
  double progress;
  bool canGoBack;
  bool canGoForward;
  Uint8List? favicon;
  String memoryUsage;

  InAppWebViewController? controller;
  PullToRefreshController? pullToRefreshController;

  BrowserTab({
    required this.id,
    required this.url,
    this.title = 'Trang mới',
    this.progress = 0,
    this.canGoBack = false,
    this.canGoForward = false,
    this.memoryUsage = 'N/A',
  });
}

class BrowserHomePage extends StatefulWidget {
  final WebViewEnvironment? webViewEnvironment;
  const BrowserHomePage({super.key, this.webViewEnvironment});

  @override
  State<BrowserHomePage> createState() => _BrowserHomePageState();
}

class _BrowserHomePageState extends State<BrowserHomePage> {
  static final Uri _defaultHomeUri = SearchEngine.google.homeUri;
  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36';

  final TextEditingController _addressController =
      TextEditingController(text: _defaultHomeUri.toString());

  // ── Tab state ──
  final List<BrowserTab> _tabs = [];
  int _currentTabIndex = 0;

  SearchEngine _searchEngine = SearchEngine.google;

  // ── Fullscreen state ──
  bool _isFullscreen = false;
  bool _toolbarVisible = true;
  Timer? _hideTimer;

  // ── Ad-block state ──
  final AdBlockService _adBlockService = AdBlockService(enabled: true);
  int _blockedCount = 0;
  bool _showAdPanel = false;
  bool _adBlockInitializing = true;
  String _adEngineStatus = 'Đang khởi tạo bộ lọc...';

  // ── Translation state ──
  String _translateTargetLang = 'vi'; // Ngôn ngữ dịch mặc định
  static const Map<String, String> _supportedLangs = {
    'vi': 'Tiếng Việt',
    'en': 'Tiếng Anh',
    'zh-CN': 'Tiếng Trung (Giản thể)',
    'ja': 'Tiếng Nhật',
    'ko': 'Tiếng Hàn',
    'fr': 'Tiếng Pháp',
    'de': 'Tiếng Đức',
    'ru': 'Tiếng Nga',
    'es': 'Tiếng Tây Ban Nha',
  };

  static const String _youtubeAntiAdsScript = r'''
(() => {
  if (window.__videoBlockAntiAdsInstalled) {
    return;
  }
  window.__videoBlockAntiAdsInstalled = true;

  const adSelectors = [
    '.ytp-ad-module',
    '.ytp-ad-player-overlay',
    '.ytp-ad-overlay-container',
    '.video-ads',
    'ytd-display-ad-renderer',
    'ytd-promoted-sparkles-web-renderer',
    'ytd-companion-slot-renderer',
    'ytd-ad-slot-renderer',
    'ytd-reel-shelf-renderer[is-shorts][aria-label*="Sponsored"]',
    'ytd-rich-item-renderer:has([aria-label*="Sponsored"])'
  ];

  const hideAds = () => {
    for (const selector of adSelectors) {
      document.querySelectorAll(selector).forEach((node) => {
        if (node && node.style) {
          node.style.display = 'none';
        }
        if (node && typeof node.remove === 'function') {
          node.remove();
        }
      });
    }

    const skipButton = document.querySelector('.ytp-ad-skip-button, .ytp-skip-ad-button');
    if (skipButton && typeof skipButton.click === 'function') {
      skipButton.click();
    }

    const adBadge = document.querySelector('.ytp-ad-text, .ytp-ad-simple-ad-badge');
    const video = document.querySelector('video');
    if (adBadge && video && Number.isFinite(video.duration)) {
      video.currentTime = Math.max(video.duration - 0.05, 0);
    }
  };

  hideAds();
  const observer = new MutationObserver(hideAds);
  observer.observe(document.documentElement || document.body, {
    childList: true,
    subtree: true,
  });
  window.setInterval(hideAds, 2000);
})();
''';

  @override
  void initState() {
    super.initState();
    _addNewTab(url: _defaultHomeUri.toString());
    unawaited(_bootstrapAdBlock());
  }

  @override
  void dispose() {
    _addressController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  BrowserTab get _currentTab => _tabs[_currentTabIndex];

  Future<void> _bootstrapAdBlock() async {
    await _adBlockService.initialize();
    if (!mounted) return;
    setState(() {
      _adBlockInitializing = false;
      _adEngineStatus = _adBlockService.status;
    });
  }

  // ── Tab Management ──
  void _addNewTab({String? url}) {
    final newTab = BrowserTab(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: url ?? _searchEngine.homeUri.toString(),
    );

    // Init PullToRefresh for this tab
    if (Platform.isAndroid || Platform.isIOS) {
      newTab.pullToRefreshController = PullToRefreshController(
        settings: PullToRefreshSettings(color: Colors.blueAccent),
        onRefresh: () async {
          await newTab.controller?.reload();
        },
      );
    }

    setState(() {
      _tabs.add(newTab);
      _currentTabIndex = _tabs.length - 1;
      _updateAddressBar();
    });
  }

  void _closeTab(int index) {
    if (_tabs.length <= 1) {
      // Nếu đóng tab cuối cùng, tạo một tab mới thay thế
      _addNewTab();
      setState(() {
        _tabs.removeAt(0);
        _currentTabIndex = 0;
      });
      return;
    }

    setState(() {
      _tabs.removeAt(index);
      if (_currentTabIndex >= index && _currentTabIndex > 0) {
        _currentTabIndex--;
      }
      _updateAddressBar();
    });
  }

  void _switchToTab(int index) {
    setState(() {
      _currentTabIndex = index;
      _updateAddressBar();
    });
  }

  // ── Fullscreen helpers ──
  void _exitFullscreen() {
    _hideTimer?.cancel();
    setState(() {
      _isFullscreen = false;
      _toolbarVisible = true;
      _showAdPanel = false;
    });
  }

  void _enterFullscreen() {
    _hideTimer?.cancel();
    setState(() {
      _isFullscreen = true;
      _toolbarVisible = true;
      _showAdPanel = false;
    });
  }

  void _onMouseEnterToolbar() {
    _hideTimer?.cancel();
    if (!_toolbarVisible) setState(() => _toolbarVisible = true);
  }

  void _onMouseExitToolbar() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted && _isFullscreen && !_showAdPanel) {
        setState(() => _toolbarVisible = false);
      }
    });
  }

  // ── Navigation ──
  void _updateAddressBar() {
    if (_tabs.isEmpty) return;
    _addressController.text = _currentTab.url;
  }

  Future<void> _updateTabState(BrowserTab tab) async {
    final controller = tab.controller;
    if (controller == null || !mounted) return;

    final canGoBack = await controller.canGoBack();
    final canGoForward = await controller.canGoForward();
    
    if (mounted) {
      setState(() {
        tab.canGoBack = canGoBack;
        tab.canGoForward = canGoForward;
      });
    }
  }

  bool _isYouTubeUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(rawUrl);
    final host = uri?.host.toLowerCase() ?? '';
    return host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtu.be' ||
        host.endsWith('.youtu.be');
  }

  Future<void> _injectYouTubeAdBlock(InAppWebViewController controller, String? currentUrl) async {
    if (!_adBlockService.enabled || !_isYouTubeUrl(currentUrl)) {
      return;
    }
    try {
      await controller.evaluateJavascript(source: _youtubeAntiAdsScript);
    } catch (_) {
      // Ignore JS injection failures for restricted pages.
    }
  }

  Future<void> _goHome() async {
    final home = _searchEngine.homeUri;
    _addressController.text = home.toString();
    await _currentTab.controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri.uri(home)),
    );
  }

  Future<void> _navigateFromAddressBar(String value) async {
    final input = value.trim();
    if (input.isEmpty) return;

    Uri? targetUri;
    final parsed = Uri.tryParse(input);

    if (parsed != null && parsed.hasScheme) {
      targetUri = parsed;
    } else {
      final looksLikeDomain =
          !input.contains(' ') && RegExp(r'^[^\s]+\.[^\s]+').hasMatch(input);
      if (looksLikeDomain) {
        targetUri = Uri.tryParse('https://$input');
      }
    }

    targetUri ??= _searchEngine.searchUri(input);
    final destination = targetUri.toString();

    _addressController.text = destination;
    await _currentTab.controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri(destination)),
    );
  }

  // ── Shared WebView ──
  Widget _buildWebViewForTab(BrowserTab tab) {
    return InAppWebView(
      key: tab.webViewKey,
      webViewEnvironment: widget.webViewEnvironment,
      initialUrlRequest: URLRequest(
        url: WebUri(tab.url),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        userAgent: _desktopUserAgent,
        mediaPlaybackRequiresUserGesture: false,
        supportZoom: true,
        transparentBackground: false,
        useShouldOverrideUrlLoading: true,
        allowsInlineMediaPlayback: true,
        preferredContentMode: UserPreferredContentMode.DESKTOP,
        isInspectable: kDebugMode,
        javaScriptCanOpenWindowsAutomatically: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
        // hardwareAcceleration: true  ← KHÔNG dùng, gây xung đột trên một số GPU driver
        cacheEnabled: true,
      ),
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final url = navigationAction.request.url?.toString();
        if (url != null && _adBlockService.shouldBlockRequestUrl(url)) {
          setState(() => _blockedCount++);
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
      onPermissionRequest: (controller, request) async {
        return PermissionResponse(
          resources: request.resources,
          action: PermissionResponseAction.GRANT,
        );
      },
      onGeolocationPermissionsShowPrompt: (controller, origin) async {
        return GeolocationPermissionShowPromptResponse(
          origin: origin,
          allow: true,
          retain: true,
        );
      },
      onCreateWindow: (controller, createWindowAction) async {
        if (createWindowAction.request.url != null) {
          _addNewTab(url: createWindowAction.request.url.toString());
          return true;
        }
        return false;
      },
      pullToRefreshController: tab.pullToRefreshController,
      onWebViewCreated: (controller) {
        tab.controller = controller;
      },
      onLoadStart: (controller, url) {
        if (url != null) {
          setState(() {
            tab.url = url.toString();
            if (tab == _currentTab) {
              _addressController.text = tab.url;
            }
          });
        }
        _updateTabState(tab);
      },
      onLoadStop: (controller, url) async {
        tab.pullToRefreshController?.endRefreshing();
        if (url != null) {
          tab.url = url.toString();
        }
        await _injectYouTubeAdBlock(controller, tab.url);
        final title = await controller.getTitle();
        final normalizedTitle = title?.trim();
        if (mounted) {
          setState(() {
            tab.title = normalizedTitle?.isNotEmpty == true
                ? normalizedTitle!
                : tab.url;
            tab.progress = 100;
            if (tab == _currentTab) {
              _addressController.text = tab.url;
            }
          });
        }
        _updateTabState(tab);
      },
      onReceivedError: (controller, request, error) {
        tab.pullToRefreshController?.endRefreshing();
        final failedUrl = request.url.toString();
        if (mounted) {
          setState(() {
            tab.url = failedUrl;
          });
        }
      },
      onProgressChanged: (controller, progress) {
        setState(() => tab.progress = progress.toDouble());
      },
      onUpdateVisitedHistory: (controller, url, isReload) {
        if (url != null) {
          setState(() {
            tab.url = url.toString();
            if (tab == _currentTab) {
              _addressController.text = tab.url;
            }
          });
        }
        _updateTabState(tab);
      },
      onTitleChanged: (controller, title) {
        if ((title ?? '').trim().isEmpty) return;
        setState(() => tab.title = title!.trim());
      },
      onReceivedIcon: (controller, icon) {
        setState(() => tab.favicon = icon);
      },
    );
  }

  Future<void> _checkTabMemory(BrowserTab tab) async {
    if (tab.controller == null) return;
    try {
      // Thử lấy JS Heap Size (chỉ hoạt động trên các WebView dựa trên Chromium và có hỗ trợ API này)
      final result = await tab.controller!.evaluateJavascript(source: """
        (function() {
          if (window.performance && window.performance.memory) {
            return window.performance.memory.usedJSHeapSize;
          }
          return -1;
        })();
      """);

      if (result != null && result is num && result > 0) {
        final mb = (result / (1024 * 1024)).toStringAsFixed(1);
        setState(() {
          tab.memoryUsage = '$mb MB (JS Heap)';
        });
      } else {
        setState(() {
          tab.memoryUsage = 'Không xác định';
        });
      }
    } catch (e) {
      // Bỏ qua lỗi nếu không lấy được
    }
  }

  // ── Tab Bar UI ──
  Widget _buildTabBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.45)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fullWidth = constraints.maxWidth;
                final availableWidth = fullWidth - 50.0;
                double tabWidth = 200.0;
                if (_tabs.isNotEmpty) {
                  tabWidth = (availableWidth / _tabs.length).clamp(60.0, 200.0);
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _tabs.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _tabs.length) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: IconButton.filledTonal(
                          tooltip: 'Tab mới',
                          onPressed: _addNewTab,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          style: IconButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      );
                    }
                    final tab = _tabs[index];
                    final isActive = index == _currentTabIndex;

                    return MouseRegion(
                      onEnter: (_) => _checkTabMemory(tab),
                      child: Tooltip(
                        message: '${tab.title}\nRAM: ${tab.memoryUsage}',
                        waitDuration: const Duration(milliseconds: 500),
                        child: GestureDetector(
                          onTap: () => _switchToTab(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            width: tabWidth,
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.only(left: 8, right: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? colorScheme.primaryContainer.withValues(alpha: 0.66)
                                  : colorScheme.surfaceContainerHigh.withValues(alpha: 0.56),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isActive
                                    ? colorScheme.primary.withValues(alpha: 0.3)
                                    : colorScheme.outlineVariant.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (isActive)
                                  Container(
                                    width: 3,
                                    height: 18,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                if (tab.favicon != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Image.memory(
                                      tab.favicon!,
                                      width: 16,
                                      height: 16,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.public, size: 16, color: Colors.grey),
                                    ),
                                  )
                                else
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(Icons.public, size: 16, color: Colors.grey),
                                  ),
                                Expanded(
                                  child: Text(
                                    tab.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                      color: isActive
                                          ? colorScheme.onSurface
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                if (tabWidth > 80 || isActive)
                                  IconButton(
                                    tooltip: 'Đóng tab',
                                    onPressed: () => _closeTab(index),
                                    iconSize: 14,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints:
                                        const BoxConstraints(minWidth: 24, minHeight: 24),
                                    splashRadius: 14,
                                    hoverColor: colorScheme.errorContainer.withValues(alpha: 0.6),
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: isActive
                                          ? colorScheme.onSurfaceVariant
                                          : colorScheme.outline,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          _navBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: 'Back',
            onPressed: _currentTab.canGoBack ? () => _currentTab.controller?.goBack() : null,
          ),
          _navBtn(
            icon: Icons.arrow_forward_ios_rounded,
            tooltip: 'Forward',
            onPressed: _currentTab.canGoForward
                ? () => _currentTab.controller?.goForward()
                : null,
          ),
          _navBtn(
            icon: Icons.refresh_rounded,
            tooltip: 'Reload',
            onPressed: () => _currentTab.controller?.reload(),
          ),
        ],
      ),
    );
  }

  Widget _adBlockButton({bool floating = false}) {
    final isOn = _adBlockService.enabled;
    return IconButton(
      tooltip: isOn
          ? 'Ad-block: BẬT • ${_adBlockService.ruleCount} luật'
          : 'Ad-block: TẮT',
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      onPressed: () => setState(() => _showAdPanel = !_showAdPanel),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            isOn ? Icons.shield_rounded : Icons.shield_outlined,
            color: isOn
                ? (floating ? Colors.greenAccent : Colors.green)
                : (floating ? Colors.white38 : Colors.grey),
          ),
          if (_blockedCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                child: Text(
                  _blockedCount > 99 ? '99+' : '$_blockedCount',
                  style: const TextStyle(color: Colors.white, fontSize: 8),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchEngineButton({bool floating = false}) {
    return PopupMenuButton<SearchEngine>(
      tooltip: 'Bộ máy tìm kiếm: ${_searchEngine.label}',
      onSelected: (engine) async {
        if (_searchEngine == engine) return;
        setState(() => _searchEngine = engine);
        await _goHome();
      },
      itemBuilder: (context) => SearchEngine.values
          .map(
            (engine) => PopupMenuItem<SearchEngine>(
              value: engine,
              child: Row(
                children: [
                  Icon(
                    engine == _searchEngine
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(engine.label),
                ],
              ),
            ),
          )
          .toList(),
      icon: Icon(
        Icons.travel_explore_rounded,
        color: floating ? Colors.white70 : null,
      ),
    );
  }

  Future<void> _translatePage(String targetLang) async {
    final controller = _currentTab.controller;
    final currentUrl = await controller?.getUrl();
    if (controller == null || currentUrl == null) return;

    // Không dịch các trang của Google Translate
    if (currentUrl.host.contains('translate.google.com')) {
      return;
    }

    final translationUrl = Uri.https('translate.google.com', '/translate', {
      'sl': 'auto', // Ngôn ngữ nguồn: tự động phát hiện
      'tl': targetLang, // Ngôn ngữ đích
      'u': currentUrl.toString(),
    });

    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri.uri(translationUrl)),
    );
  }

  Widget _translateButton({bool floating = false}) {
    final langName = _supportedLangs[_translateTargetLang] ?? '...';
    return PopupMenuButton<String>(
      tooltip: 'Dịch trang (hiện tại: $langName)',
      icon: Icon(
        Icons.translate_rounded,
        color: floating ? Colors.white70 : null,
      ),
      onSelected: (lang) {
        setState(() {
          _translateTargetLang = lang;
        });
        _translatePage(lang);
      },
      itemBuilder: (context) => _supportedLangs.entries
          .map(
            (entry) => PopupMenuItem<String>(
              value: entry.key,
              child: Row(
                children: [
                  Icon(
                    entry.key == _translateTargetLang
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(entry.value),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAdPanel() {
    final lastUpdated = _adBlockService.lastUpdated;
    final lastUpdatedText = lastUpdated == null
        ? 'Chưa cập nhật'
        : '${lastUpdated.hour.toString().padLeft(2, '0')}:${lastUpdated.minute.toString().padLeft(2, '0')}';

    return Positioned(
      top: _isFullscreen ? 48 : 108,
      right: 8,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: _isFullscreen
            ? Colors.grey[900]!.withOpacity(0.95)
            : Theme.of(context).colorScheme.surfaceContainer,
        child: Container(
          width: 260,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_rounded,
                      size: 18,
                      color: _adBlockService.enabled
                          ? Colors.green
                          : Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Ad-Block',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isFullscreen ? Colors.white : null,
                    ),
                  ),
                  const Spacer(),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: _adBlockService.enabled,
                      activeColor: Colors.green,
                      onChanged: (v) => setState(() {
                        _adBlockService.enabled = v;
                        _adEngineStatus = v
                            ? _adBlockService.status
                            : 'Ad-block đang tắt';
                      }),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                children: [
                  Icon(
                    _adBlockInitializing
                        ? Icons.sync_rounded
                        : Icons.rule_folder_rounded,
                    size: 16,
                    color: _isFullscreen ? Colors.white70 : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _adEngineStatus,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: _isFullscreen ? Colors.white70 : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.dataset_linked_rounded,
                      size: 16, color: _isFullscreen ? Colors.white70 : Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Luật lọc:',
                    style: TextStyle(
                      color: _isFullscreen ? Colors.white70 : null,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _adBlockService.ruleCount.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isFullscreen ? Colors.white : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.block_rounded,
                      size: 16, color: Colors.redAccent.withOpacity(0.8)),
                  const SizedBox(width: 8),
                  Text(
                    'Đã chặn:',
                    style: TextStyle(
                      color: _isFullscreen ? Colors.white70 : null,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$_blockedCount quảng cáo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _blockedCount > 0
                          ? Colors.redAccent
                          : (_isFullscreen ? Colors.white38 : Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 16, color: _isFullscreen ? Colors.white54 : Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Cập nhật:',
                    style: TextStyle(
                      color: _isFullscreen ? Colors.white70 : null,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    lastUpdatedText,
                    style: TextStyle(
                      color: _isFullscreen ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _adBlockInitializing
                      ? null
                      : () async {
                          setState(() {
                            _adBlockInitializing = true;
                            _adEngineStatus = 'Đang cập nhật danh sách lọc...';
                          });
                          await _adBlockService.refreshFilterLists();
                          if (!mounted) return;
                          setState(() {
                            _adBlockInitializing = false;
                            _adEngineStatus = _adBlockService.status;
                          });
                        },
                  icon: _adBlockInitializing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_rounded, size: 16),
                  label: const Text('Cập nhật filter list'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => setState(() => _blockedCount = 0),
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Đặt lại bộ đếm',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool floating = false,
  }) {
    return IconButton(
      tooltip: tooltip,
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: Icon(icon, color: floating ? Colors.white70 : null),
    );
  }

  Widget _buildAddressBar({bool floating = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = floating ? Colors.white : colorScheme.onSurface;
    final hintColor = floating ? Colors.white54 : colorScheme.onSurfaceVariant;

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: floating ? Colors.white12 : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: floating
              ? Colors.white24
              : colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(
            Icons.language_rounded,
            size: 16,
            color: floating ? Colors.white70 : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _addressController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              enableSuggestions: false,
              style: TextStyle(fontSize: 13, color: textColor),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Nhập URL hoặc từ khóa tìm kiếm',
                hintStyle: TextStyle(color: hintColor),
              ),
              onTap: () {
                _addressController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _addressController.text.length,
                );
              },
              onSubmitted: _navigateFromAddressBar,
            ),
          ),
          IconButton(
            tooltip: 'Đi đến',
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: () => _navigateFromAddressBar(_addressController.text),
            icon: Icon(
              Icons.arrow_forward_rounded,
              color: floating ? Colors.white70 : null,
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    return _isFullscreen ? _buildFullscreenLayout() : _buildNormalLayout();
  }

  Widget _buildNormalLayout() {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      if (!_isFullscreen) _buildTabBar(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                        child: Row(
                          children: [
                            _searchEngineButton(),
                            _translateButton(),
                            const SizedBox(width: 4),
                            Expanded(child: _buildAddressBar()),
                            _adBlockButton(),
                            IconButton(
                              tooltip: 'Toàn màn hình',
                              iconSize: 20,
                              visualDensity: VisualDensity.compact,
                              onPressed: _enterFullscreen,
                              icon: const Icon(Icons.fullscreen_rounded),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  // QUAN TRỌNG: Không bọc InAppWebView (Platform View trên Windows)
                  // bằng ClipRRect/ClipPath — sẽ khiến webview render màu đen.
                  // Platform Views trên Windows không hỗ trợ Flutter clip operations.
                  child: IndexedStack(
                    index: _currentTabIndex,
                    children: _tabs.map((tab) => _buildWebViewForTab(tab)).toList(),
                  ),
                ),
              ],
            ),
            if (_showAdPanel) ...[              
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _showAdPanel = false),
                ),
              ),
              _buildAdPanel(),
            ],
          ],
        ),
      ),
    );
  }

  // ── Fullscreen nav bar (no URL bar, nav buttons only) ──
  Widget _buildFullscreenNavBar() {
    if (_tabs.isEmpty) return const SizedBox.shrink();
    
    return Material(
      color: Colors.black.withOpacity(0.72),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            _navBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Back',
              onPressed: _currentTab.canGoBack
                  ? () => _currentTab.controller?.goBack()
                  : null,
              floating: true,
            ),
            _navBtn(
              icon: Icons.arrow_forward_ios_rounded,
              tooltip: 'Forward',
              onPressed: _currentTab.canGoForward
                  ? () => _currentTab.controller?.goForward()
                  : null,
              floating: true,
            ),
            _navBtn(
              icon: Icons.refresh_rounded,
              tooltip: 'Reload',
              onPressed: () => _currentTab.controller?.reload(),
              floating: true,
            ),
            _navBtn(
              icon: Icons.home_rounded,
              tooltip: 'Home',
              onPressed: _goHome,
              floating: true,
            ),
            _searchEngineButton(floating: true),
            _translateButton(floating: true),
            const SizedBox(width: 4),
            Expanded(child: _buildAddressBar(floating: true)),
            _adBlockButton(floating: true),
            IconButton(
              tooltip: 'Thoát toàn màn hình',
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              onPressed: _exitFullscreen,
              icon: const Icon(
                Icons.fullscreen_exit_rounded,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullscreenLayout() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // WebView chiếm toàn bộ màn hình
          Positioned.fill(child: IndexedStack(
            index: _currentTabIndex,
            children: _tabs.map((tab) => _buildWebViewForTab(tab)).toList(),
          )),

          // Nav overlay – chỉ hiện khi rê chuột vào vùng trên cùng
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MouseRegion(
              onEnter: (_) => _onMouseEnterToolbar(),
              onExit: (_) => _onMouseExitToolbar(),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _toolbarVisible ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_toolbarVisible,
                  child: _buildFullscreenNavBar(),
                ),
              ),
            ),
          ),

          // Ad panel overlay
          if (_showAdPanel) ...[            
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(() => _showAdPanel = false),
              ),
            ),
            _buildAdPanel(),
          ],
        ],
      ),
    );
  }
}

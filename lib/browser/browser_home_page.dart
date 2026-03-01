import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/adblock_service.dart';

class BrowserHomePage extends StatefulWidget {
  const BrowserHomePage({super.key});

  @override
  State<BrowserHomePage> createState() => _BrowserHomePageState();
}

class _BrowserHomePageState extends State<BrowserHomePage> {
  final TextEditingController _addressController =
      TextEditingController(text: 'https://www.google.com');

  InAppWebViewController? _webViewController;
  PullToRefreshController? _pullToRefreshController;

  String _currentUrl = 'https://www.google.com';
  String _pageTitle = 'Mini Browser';
  int _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;

  // ── Fullscreen state ──
  bool _isFullscreen = false;
  bool _toolbarVisible = true;
  Timer? _hideTimer;

  // ── Ad-block state ──
  final AdBlockService _adBlockService = AdBlockService(enabled: true);
  int _blockedCount = 0;
  bool _showAdPanel = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid || Platform.isIOS) {
      _pullToRefreshController = PullToRefreshController(
        settings: PullToRefreshSettings(color: Colors.blueAccent),
        onRefresh: () async {
          await _webViewController?.reload();
        },
      );
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  // ── Fullscreen helpers ──
  void _enterFullscreen() {
    setState(() {
      _isFullscreen = true;
      _toolbarVisible = false;
      _showAdPanel = false;
    });
  }

  void _exitFullscreen() {
    _hideTimer?.cancel();
    setState(() {
      _isFullscreen = false;
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
  Future<void> _updateNavigationState() async {
    final controller = _webViewController;
    if (controller == null || !mounted) return;

    final canGoBack = await controller.canGoBack();
    final canGoForward = await controller.canGoForward();

    if (!mounted) return;
    setState(() {
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }

  Future<void> _navigateToInput() async {
    final rawInput = _addressController.text.trim();
    if (rawInput.isEmpty) return;

    final target = _normalizeInputToUrl(rawInput);
    final uri = WebUri.uri(target);
    await _webViewController?.loadUrl(urlRequest: URLRequest(url: uri));
  }

  Uri _normalizeInputToUrl(String value) {
    final hasScheme =
        value.startsWith('http://') || value.startsWith('https://');
    if (hasScheme) return Uri.parse(value);

    final looksLikeDomain =
        value.contains('.') && !value.contains(' ') && !value.startsWith('/');
    if (looksLikeDomain) return Uri.parse('https://$value');

    return Uri.https('www.google.com', '/search', {'q': value});
  }

  // ── Shared WebView ──
  Widget _buildWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri.uri(Uri.parse('https://www.google.com')),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        supportZoom: true,
        transparentBackground: false,
        useShouldOverrideUrlLoading: true,
        allowsInlineMediaPlayback: true,
      ),
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final url = navigationAction.request.url?.toString();
        if (url != null && _adBlockService.shouldBlockRequestUrl(url)) {
          setState(() => _blockedCount++);
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
      pullToRefreshController: _pullToRefreshController,
      onWebViewCreated: (controller) {
        _webViewController = controller;
      },
      onLoadStart: (controller, url) {
        if (url != null) {
          setState(() {
            _currentUrl = url.toString();
            _addressController.text = _currentUrl;
          });
        }
        _updateNavigationState();
      },
      onLoadStop: (controller, url) async {
        _pullToRefreshController?.endRefreshing();
        if (url != null) _currentUrl = url.toString();
        final title = await controller.getTitle();
        if (mounted) {
          setState(() {
            _pageTitle = title?.trim().isNotEmpty == true
                ? title!.trim()
                : _currentUrl;
            _addressController.text = _currentUrl;
            _progress = 100;
          });
        }
        _updateNavigationState();
      },
      onReceivedError: (controller, request, error) {
        _pullToRefreshController?.endRefreshing();
      },
      onProgressChanged: (controller, progress) {
        setState(() => _progress = progress);
      },
      onUpdateVisitedHistory: (controller, url, isReload) {
        if (url != null) {
          setState(() {
            _currentUrl = url.toString();
            _addressController.text = _currentUrl;
          });
        }
        _updateNavigationState();
      },
      onTitleChanged: (controller, title) {
        if ((title ?? '').trim().isEmpty) return;
        setState(() => _pageTitle = title!.trim());
      },
    );
  }

  // ── Toolbar (normal & fullscreen overlay) ──
  Widget _buildToolbar({bool floating = false}) {
    final progressValue = _progress / 100;
    final bg = floating
        ? Colors.black.withOpacity(0.72)
        : Theme.of(context).scaffoldBackgroundColor;

    return Material(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Address bar
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: floating
                          ? Colors.white.withOpacity(0.15)
                          : Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: _addressController,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _navigateToInput(),
                      style: floating
                          ? const TextStyle(color: Colors.white)
                          : null,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        hintText: 'Nhập URL hoặc từ khóa tìm kiếm',
                        hintStyle: floating
                            ? TextStyle(color: Colors.white.withOpacity(0.5))
                            : null,
                        prefixIcon: Icon(
                          _currentUrl.startsWith('https://')
                              ? Icons.lock_rounded
                              : Icons.search_rounded,
                          size: 20,
                          color: floating ? Colors.white70 : null,
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'Tải trang',
                          onPressed: _navigateToInput,
                          icon: Icon(
                            Icons.arrow_circle_right_rounded,
                            color: floating ? Colors.white70 : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Nav buttons row
            Row(
              children: [
                _navBtn(
                  icon: Icons.arrow_back_ios_new_rounded,
                  tooltip: 'Back',
                  onPressed:
                      _canGoBack ? () => _webViewController?.goBack() : null,
                  floating: floating,
                ),
                _navBtn(
                  icon: Icons.arrow_forward_ios_rounded,
                  tooltip: 'Forward',
                  onPressed: _canGoForward
                      ? () => _webViewController?.goForward()
                      : null,
                  floating: floating,
                ),
                _navBtn(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Reload',
                  onPressed: () => _webViewController?.reload(),
                  floating: floating,
                ),
                _navBtn(
                  icon: Icons.home_rounded,
                  tooltip: 'Home',
                  onPressed: () {
                    _addressController.text = 'https://www.google.com';
                    _navigateToInput();
                  },
                  floating: floating,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _pageTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: floating
                        ? Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white70)
                        : Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                // Ad-block toggle button
                _adBlockButton(floating: floating),
                // Fullscreen toggle
                IconButton(
                  tooltip: _isFullscreen
                      ? 'Thoát toàn màn hình'
                      : 'Toàn màn hình',
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  onPressed: _isFullscreen ? _exitFullscreen : _enterFullscreen,
                  icon: Icon(
                    _isFullscreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    color: floating ? Colors.white : null,
                  ),
                ),
              ],
            ),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                minHeight: 3,
                value: _progress == 100 ? 1.0 : math.max(progressValue, 0.02),
                backgroundColor: floating
                    ? Colors.white.withOpacity(0.15)
                    : Theme.of(context).colorScheme.surfaceContainer,
                valueColor: floating
                    ? const AlwaysStoppedAnimation<Color>(Colors.blueAccent)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adBlockButton({bool floating = false}) {
    final isOn = _adBlockService.enabled;
    return IconButton(
      tooltip: isOn ? 'Ad-block: BẬT (nhấn để xem thống kê)' : 'Ad-block: TẮT',
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

  Widget _buildAdPanel() {
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
          width: 220,
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
                      }),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
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

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    return _isFullscreen ? _buildFullscreenLayout() : _buildNormalLayout();
  }

  Widget _buildNormalLayout() {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildToolbar(floating: false),
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: _buildWebView(),
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
    return Material(
      color: Colors.black.withOpacity(0.72),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            _navBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Back',
              onPressed:
                  _canGoBack ? () => _webViewController?.goBack() : null,
              floating: true,
            ),
            _navBtn(
              icon: Icons.arrow_forward_ios_rounded,
              tooltip: 'Forward',
              onPressed: _canGoForward
                  ? () => _webViewController?.goForward()
                  : null,
              floating: true,
            ),
            _navBtn(
              icon: Icons.refresh_rounded,
              tooltip: 'Reload',
              onPressed: () => _webViewController?.reload(),
              floating: true,
            ),
            _navBtn(
              icon: Icons.home_rounded,
              tooltip: 'Home',
              onPressed: () {
                _addressController.text = 'https://www.google.com';
                _navigateToInput();
              },
              floating: true,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _pageTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white70),
              ),
            ),
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
          Positioned.fill(child: _buildWebView()),

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

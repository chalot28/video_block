import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'browser/browser_home_page.dart';

// ─── Kiểm tra Microsoft Edge WebView2 Runtime ───────────────────────────────
// flutter_inappwebview trên Windows dùng WebView2 làm engine.
// Nếu máy chưa cài, webview sẽ không load được (màn trắng, không báo lỗi rõ).
// ────────────────────────────────────────────────────────────────────────────
Future<bool> _isWebView2Available() async {
  if (!Platform.isWindows) return true;
  const registryPaths = [
    r'HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
    r'HKLM\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
    r'HKCU\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
  ];
  for (final path in registryPaths) {
    try {
      final result = await Process.run('reg', ['query', path, '/v', 'pv']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        // Trích version từ output: "    pv    REG_SZ    1.0.2045.28"
        final match = RegExp(r'pv\s+REG_SZ\s+(\S+)').firstMatch(output);
        final version = match?.group(1) ?? '';
        if (version.isNotEmpty && version != '0.0.0.0') return true;
      }
    } catch (_) {
      // Registry query thất bại → thử key tiếp theo
    }
  }
  return false;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(titleBarStyle: TitleBarStyle.normal);
    await windowManager.waitUntilReadyToShow(options);
    await windowManager.show();
    await windowManager.focus();
  }

  final webView2Available = await _isWebView2Available();

  // ─── QUAN TRỌNG: Bắt buộc khởi tạo WebViewEnvironment trên Windows ─────────
  // flutter_inappwebview 6.x Windows yêu cầu explicit WebViewEnvironment.
  // Không có nó → mọi InAppWebView render màu đen, không ném exception.
  // ───────────────────────────────────────────────────────────────────────────
  WebViewEnvironment? webViewEnvironment;
  if (defaultTargetPlatform == TargetPlatform.windows && webView2Available) {
    try {
      final appSupport = await getApplicationSupportDirectory();
      final userDataFolder = '${appSupport.path}\\WebView2UserData';
      webViewEnvironment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(userDataFolder: userDataFolder),
      );
      debugPrint('[WebViewEnv] Created → $userDataFolder');
    } catch (e, st) {
      debugPrint('[WebViewEnv] FAILED: $e\n$st');
    }
  }

  runApp(MiniBrowserApp(
    webView2Available: webView2Available,
    webViewEnvironment: webViewEnvironment,
  ));
}

class MiniBrowserApp extends StatelessWidget {
  final bool webView2Available;
  final WebViewEnvironment? webViewEnvironment;
  const MiniBrowserApp({
    super.key,
    required this.webView2Available,
    required this.webViewEnvironment,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mini Browser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6)),
        scaffoldBackgroundColor: const Color(0xFFF3F6FC),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF60A5FA),
          brightness: Brightness.dark,
        ),
      ),
      home: webView2Available
          ? BrowserHomePage(webViewEnvironment: webViewEnvironment)
          : const _WebView2MissingScreen(),
    );
  }
}

// ─── Màn hình hiển thị khi WebView2 chưa được cài ───────────────────────────
class _WebView2MissingScreen extends StatelessWidget {
  const _WebView2MissingScreen();

  void _openWebView2Download() {
    Process.run('rundll32', [
      'url.dll,FileProtocolHandler',
      'https://developer.microsoft.com/en-us/microsoft-edge/webview2/',
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 64, color: Colors.orange),
                const SizedBox(height: 24),
                Text(
                  'Microsoft Edge WebView2 Runtime chưa được cài đặt',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Ứng dụng cần WebView2 Runtime để hiển thị trình duyệt web. '
                  'Thành phần này thường đã có sẵn trên Windows 11 và Windows 10 '
                  'phiên bản mới. Vui lòng tải và cài đặt từ trang chính thức của Microsoft.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _openWebView2Download,
                  icon: const Icon(Icons.download),
                  label: const Text('Tải WebView2 Runtime'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sau khi cài xong, khởi động lại ứng dụng.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


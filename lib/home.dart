import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';

class TradezoneWebview extends StatefulWidget {
  const TradezoneWebview({super.key});

  @override
  State<TradezoneWebview> createState() => _TradezoneWebviewState();
}

class _TradezoneWebviewState extends State<TradezoneWebview> {
  late InAppWebViewController inAppWebViewController;
  // WebNotificationController? webNotificationController;
  final GlobalKey webViewKey = GlobalKey();
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> connectivitySubscription;
  PullToRefreshController? pullToRefreshController;
  bool pullToRefreshEnabled = true;
  double loadingPercentage = 0;
  bool noInternet = false;

  Future<void> initConnectivity() async {
    late ConnectivityResult result;
    try {
      result = await _connectivity.checkConnectivity();
    } on PlatformException catch (e) {
      debugPrint("tidak dapat mengecek koneksi internet, ${e.toString()}");
      return;
    }
    if (!mounted) {
      return Future.value(null);
    }
    return _updateConnectionStatus(result);
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    setState(() {
      _connectionStatus = result;
      if (_connectionStatus == ConnectivityResult.none) {
        noInternet = true;
      } else {
        noInternet = false;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    initConnectivity();
    connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    pullToRefreshController = PullToRefreshController(
        options: PullToRefreshOptions(
          color: Colors.green,
          backgroundColor: Colors.white,
        ),
        onRefresh: () async {
          if (defaultTargetPlatform == TargetPlatform.android) {
            inAppWebViewController.reload();
          } else if (defaultTargetPlatform == TargetPlatform.iOS) {
            inAppWebViewController.loadUrl(
                urlRequest:
                    URLRequest(url: await inAppWebViewController.getUrl()));
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (value) async {
        if (await inAppWebViewController.canGoBack()) {
          inAppWebViewController.goBack();
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('History not found'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              noInternet == true
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Lottie.asset('images/no-internet.json',
                                height: 260),
                            const Text(
                              "No Internet Connections",
                              // style: kTextStye(),
                            )
                          ]),
                    )
                  : InAppWebView(
                      // Global Key
                      key: webViewKey,

                      shouldOverrideUrlLoading:
                          (controller, navigationAction) async {
                        return NavigationActionPolicy.ALLOW;
                      },

                      // initialOptions
                      initialOptions: InAppWebViewGroupOptions(
                          ios: IOSInAppWebViewOptions(
                              sharedCookiesEnabled: true,
                              allowsLinkPreview: true,
                              minimumZoomScale: 1.0,
                              maximumZoomScale: 1.0),
                          android: AndroidInAppWebViewOptions(
                              domStorageEnabled: true,
                              databaseEnabled: true,
                              useHybridComposition: true,
                              allowFileAccess: true,
                              saveFormData: true,
                              allowContentAccess: true,
                              cacheMode:
                                  AndroidCacheMode.LOAD_CACHE_ELSE_NETWORK),
                          crossPlatform: InAppWebViewOptions(
                              useOnDownloadStart: true,
                              cacheEnabled: true,
                              allowFileAccessFromFileURLs: true,
                              javaScriptCanOpenWindowsAutomatically: true,
                              javaScriptEnabled: true,
                              supportZoom: false)),

                      // Initial Request URL
                      initialUrlRequest: URLRequest(
                        url: Uri.parse("tradezone.ametaz.com"),
                      ),

                      // Pull Refresh Controller
                      pullToRefreshController: pullToRefreshController,

                      // On Webview Creted
                      onWebViewCreated:
                          (InAppWebViewController controller) async {
                        inAppWebViewController = controller;
                        setState(() {
                          loadingPercentage = 0;
                        });
                      },
                      //  Android Permission Request
                      androidOnPermissionRequest:
                          (InAppWebViewController controller, String origin,
                              List<String> resources) async {
                        permissionHandling();
                        return PermissionRequestResponse(
                            resources: resources,
                            action: PermissionRequestResponseAction.GRANT);
                      },

                      // On Load Stop
                      onLoadStop: (controller, url) {
                        setState(() async {
                          pullToRefreshController?.endRefreshing();
                        });
                      },

                      // On Progress Changed
                      onProgressChanged:
                          (InAppWebViewController controller, int progress) {
                        setState(() {
                          loadingPercentage = progress / 100;
                          if (progress == 100) {
                            pullToRefreshController?.endRefreshing();
                            loadingPercentage = 0;
                          }
                        });
                      },

                      // On Load  Start
                      onLoadStart: (controller, url) async {
                        debugPrint("Started to load : $url");
                      },

                      // On Load Error
                      onLoadError: (inAppWebViewController, request, error,
                          onloaderror) {
                        pullToRefreshController?.endRefreshing();
                      },
                    ),
              // Linear Progress Indicator
              loadingPercentage < 100
                  ? LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      color: Colors.brown.shade600,
                      value: loadingPercentage,
                    )
                  : const SizedBox()
            ],
          ),
        ),
      ),
    );
  }

  void permissionHandling() async {
    WidgetsFlutterBinding.ensureInitialized();
    PermissionStatus status = await Permission.microphone.request();
    PermissionStatus status2 = await Permission.camera.request();
    if (status != PermissionStatus.granted ||
        status2 != PermissionStatus.granted) {
      debugPrint("Permission granted");
      return;
    }
  }
}

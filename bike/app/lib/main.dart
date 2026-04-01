import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

const double kFeePerMinute = 0.5;
const AppCoordinate kDefaultTestCoordinate = AppCoordinate(
  39.904200,
  116.407400,
);
const List<String> kPaymentMethods = <String>['微信支付', '支付宝', '银行卡'];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await BikeController.bootstrap();
  runApp(BikeApp(controller: controller));
}

class BikeApp extends StatefulWidget {
  const BikeApp({super.key, required this.controller});

  final BikeController controller;

  @override
  State<BikeApp> createState() => _BikeAppState();
}

class _BikeAppState extends State<BikeApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.controller.warmUpAfterLaunch());
    });
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '共享单车锁',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0E6B55),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF4F1E8),
            useMaterial3: true,
          ),
          home: BikeHomeShell(controller: widget.controller),
        );
      },
    );
  }
}

class BikeHomeShell extends StatefulWidget {
  const BikeHomeShell({super.key, required this.controller});

  final BikeController controller;

  @override
  State<BikeHomeShell> createState() => _BikeHomeShellState();
}

class _BikeHomeShellState extends State<BikeHomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(controller: widget.controller),
      GeofencePage(controller: widget.controller),
      HistoryPage(controller: widget.controller),
      DebugPage(controller: widget.controller),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('共享单车锁控制台'),
        actions: [
          IconButton(
            onPressed: () => showErrorSheet(context, widget.controller),
            icon: const Icon(Icons.error_outline),
            tooltip: '错误面板',
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.lock_open), label: '首页'),
          NavigationDestination(icon: Icon(Icons.polyline), label: '围栏'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: '记录'),
          NavigationDestination(icon: Icon(Icons.developer_mode), label: '调试'),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller});

  final BikeController controller;

  @override
  Widget build(BuildContext context) {
    final currentLocation = controller.currentLocation;
    final activeRide = controller.activeSession;
    final pendingPaymentRide = controller.latestUnpaidRide;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(
          title: '车辆信息',
          children: [
            Text('蓝牙状态：${controller.bluetoothStateLabel}'),
            Text('单片机锁状态：${controller.lockStateLabel}'),
            Text('解析出的 MAC：${controller.parsedMac ?? '未解析'}'),
            Text('最近二维码内容：${controller.lastQrRaw ?? '无'}'),
          ],
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: '当前信息',
          children: [
            Text('时间：${controller.nowText}'),
            Text('位置：${currentLocation?.label ?? '不可用'}'),
            Text('当前预估费用：¥${controller.estimatedFee.toStringAsFixed(2)}'),
            Text('待支付订单：${controller.unpaidRideCount} 笔'),
            if (activeRide != null)
              Text(
                '骑行时长：${formatDuration(activeRide.durationTo(DateTime.now()))}',
              ),
          ],
        ),
        if (pendingPaymentRide != null) ...[
          const SizedBox(height: 12),
          _InfoCard(
            title: '待支付结算',
            children: [
              Text('订单金额：¥${pendingPaymentRide.feeYuan.toStringAsFixed(2)}'),
              Text(
                '骑行区间：${pendingPaymentRide.startTimeText} -> '
                '${pendingPaymentRide.endTimeText}',
              ),
              Text(
                '骑行时长：${formatDuration(Duration(seconds: pendingPaymentRide.durationSec))}',
              ),
              Text('支付状态：${pendingPaymentRide.paymentStatusLabel}'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      await showRidePaymentDialog(
                        context,
                        controller,
                        pendingPaymentRide,
                      );
                    },
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('立即支付'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      showAppSnackBar(context, '订单已保留，可稍后支付。');
                    },
                    icon: const Icon(Icons.schedule),
                    label: const Text('稍后支付'),
                  ),
                ],
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () async {
                final code = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (_) => const QrScannerPage()),
                );
                if (code != null && context.mounted) {
                  await controller.setQrRaw(code);
                  if (context.mounted) {
                    showAppSnackBar(context, '二维码解析成功。');
                  }
                }
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('扫码'),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                final pasted = await showTextInputDialog(
                  context,
                  title: '粘贴二维码文本',
                  hintText: '可直接粘贴 MAC，或包含 MAC 的任意文本',
                  initialValue: controller.lastQrRaw ?? '',
                );
                if (pasted != null) {
                  await controller.setQrRaw(pasted);
                  if (context.mounted) {
                    showAppSnackBar(context, '二维码文本已保存。');
                  }
                }
              },
              icon: const Icon(Icons.paste),
              label: const Text('粘贴二维码'),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                final ok = await controller.connect();
                if (context.mounted) {
                  showAppSnackBar(context, ok ? '已发起蓝牙连接。' : '蓝牙连接失败。');
                }
              },
              icon: const Icon(Icons.bluetooth_connected),
              label: const Text('连接蓝牙'),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                await controller.disconnect();
                if (context.mounted) {
                  showAppSnackBar(context, '已断开连接。');
                }
              },
              icon: const Icon(Icons.bluetooth_disabled),
              label: const Text('断开连接'),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                await controller.refreshLocation();
                if (context.mounted) {
                  showAppSnackBar(context, controller.displayStatusMessage);
                }
              },
              icon: const Icon(Icons.location_searching),
              label: const Text('刷新定位'),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                final response = await controller.queryStatus();
                if (context.mounted && response != null) {
                  showAppSnackBar(
                    context,
                    describeMessage(response) ?? response,
                  );
                }
              },
              icon: const Icon(Icons.sync),
              label: const Text('查询状态'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: '操作',
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: () async {
                    final response = await controller.unlock();
                    if (context.mounted) {
                      showAppSnackBar(
                        context,
                        describeMessage(response) ?? '开锁请求失败。',
                      );
                    }
                  },
                  child: const Text('开锁'),
                ),
                FilledButton(
                  onPressed: () async {
                    final response = await controller.lock();
                    if (context.mounted) {
                      if (response == 'L,OK' &&
                          controller.latestUnpaidRide != null) {
                        showAppSnackBar(context, '关锁成功，请完成支付结算。');
                        await showRidePaymentDialog(
                          context,
                          controller,
                          controller.latestUnpaidRide!,
                        );
                        return;
                      }
                      showAppSnackBar(
                        context,
                        describeMessage(response) ?? '关锁请求失败。',
                      );
                    }
                  },
                  child: const Text('关锁'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    final response = await controller.playTrack(1);
                    if (context.mounted) {
                      showAppSnackBar(
                        context,
                        describeMessage(response) ?? '提示音命令失败。',
                      );
                    }
                  },
                  child: const Text('测试 001'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    final response = await controller.openBluetoothSettings();
                    if (context.mounted) {
                      showAppSnackBar(
                        context,
                        response ? '已打开蓝牙设置。' : '无法打开蓝牙设置。',
                      );
                    }
                  },
                  child: const Text('蓝牙设置'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              controller.displayStatusMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }
}

class GeofencePage extends StatelessWidget {
  const GeofencePage({super.key, required this.controller});

  final BikeController controller;

  @override
  Widget build(BuildContext context) {
    final currentLocation = controller.currentLocation;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('启用围栏限制'),
          subtitle: const Text('关闭后，开锁和关锁将跳过区域校验。'),
          value: controller.debugOverrides.geofenceEnabled,
          onChanged: (value) => controller.setGeofenceEnabled(value),
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: '圆形围栏',
          action: FilledButton.tonalIcon(
            onPressed: () => showCircleEditor(context, controller),
            icon: const Icon(Icons.add),
            label: const Text('新增圆形'),
          ),
          children: [
            if (controller.circles.isEmpty) const Text('暂无圆形围栏。'),
            for (final circle in controller.circles)
              Card(
                child: ListTile(
                  title: Text(circle.name),
                  subtitle: Text(
                    '${circle.center.label}，半径 ${circle.radiusM.toStringAsFixed(0)} 米',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: circle.enabled,
                        onChanged: (value) => controller.saveCircle(
                          circle.copyWith(enabled: value),
                        ),
                      ),
                      IconButton(
                        onPressed: () => showCircleEditor(
                          context,
                          controller,
                          initial: circle,
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        onPressed: () => controller.deleteCircle(circle.id),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: '多边形围栏',
          action: FilledButton.tonalIcon(
            onPressed: () => showPolygonEditor(context, controller),
            icon: const Icon(Icons.add),
            label: const Text('新增多边形'),
          ),
          children: [
            Text('当前用于填充的定位：${currentLocation?.label ?? '不可用'}'),
            if (controller.polygons.isEmpty) const Text('暂无多边形围栏。'),
            for (final polygon in controller.polygons)
              Card(
                child: ListTile(
                  title: Text(polygon.name),
                  subtitle: Text('共 ${polygon.points.length} 个顶点'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: polygon.enabled,
                        onChanged: (value) => controller.savePolygon(
                          polygon.copyWith(enabled: value),
                        ),
                      ),
                      IconButton(
                        onPressed: () => showPolygonEditor(
                          context,
                          controller,
                          initial: polygon,
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        onPressed: () => controller.deletePolygon(polygon.id),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.controller});

  final BikeController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(
          title: '结算情况',
          children: [
            Text('待支付订单：${controller.unpaidRideCount} 笔'),
            Text(
              '已结算订单：${controller.rides.where((item) => item.isPaid).length} 笔',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (controller.rides.isEmpty)
          const _InfoCard(title: '骑行记录', children: [Text('暂无骑行记录。')]),
        for (final ride in controller.rides)
          Card(
            child: ListTile(
              title: Text(
                '${ride.bikeMac}  ¥${ride.feeYuan.toStringAsFixed(2)}',
              ),
              subtitle: Text(
                '${ride.startTimeText} -> ${ride.endTimeText}\n'
                '时长 ${formatDuration(Duration(seconds: ride.durationSec))} | '
                '${ride.distanceM.toStringAsFixed(1)} 米 | ${ride.paymentStatusLabel}',
              ),
              trailing: Chip(label: Text(ride.paymentStatusLabel)),
              isThreeLine: true,
              onTap: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('骑行详情'),
                    content: SelectableText(ride.detailText),
                    actions: [
                      if (!ride.isPaid)
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await showRidePaymentDialog(
                              context,
                              controller,
                              ride,
                            );
                          },
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('立即支付'),
                        ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class DebugPage extends StatelessWidget {
  const DebugPage({super.key, required this.controller});

  final BikeController controller;

  @override
  Widget build(BuildContext context) {
    final overrides = controller.debugOverrides;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(
          title: '调试覆盖',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('关闭围栏校验'),
              value: !overrides.geofenceEnabled,
              onChanged: (value) => controller.setGeofenceEnabled(!value),
            ),
            _CoordinateTile(
              title: '模拟当前位置',
              value: overrides.mockCurrentLocation,
              onEdit: () => showCoordinateEditor(
                context,
                title: '模拟当前位置',
                initial: overrides.mockCurrentLocation,
                controller: controller,
                onSaved: (coord) => controller.setMockCurrentLocation(coord),
              ),
              onClear: () => controller.setMockCurrentLocation(null),
            ),
            _CoordinateTile(
              title: '模拟开锁位置',
              value: overrides.mockUnlockLocation,
              onEdit: () => showCoordinateEditor(
                context,
                title: '模拟开锁位置',
                initial: overrides.mockUnlockLocation,
                controller: controller,
                onSaved: (coord) => controller.setMockUnlockLocation(coord),
              ),
              onClear: () => controller.setMockUnlockLocation(null),
            ),
            _CoordinateTile(
              title: '模拟关锁位置',
              value: overrides.mockLockLocation,
              onEdit: () => showCoordinateEditor(
                context,
                title: '模拟关锁位置',
                initial: overrides.mockLockLocation,
                controller: controller,
                onSaved: (coord) => controller.setMockLockLocation(coord),
              ),
              onClear: () => controller.setMockLockLocation(null),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: '调试操作',
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.tonal(
                  onPressed: () async {
                    await controller.clearActiveRide();
                    if (context.mounted) {
                      showAppSnackBar(context, '当前骑行已清除。');
                    }
                  },
                  child: const Text('清除当前骑行'),
                ),
                for (final track in [1, 2, 3, 4, 5])
                  FilledButton.tonal(
                    onPressed: () async {
                      final response = await controller.playTrack(track);
                      if (context.mounted) {
                        showAppSnackBar(
                          context,
                          describeMessage(response) ?? '提示音命令失败。',
                        );
                      }
                    },
                    child: Text('播放 00$track'),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _CoordinateTile extends StatelessWidget {
  const _CoordinateTile({
    required this.title,
    required this.value,
    required this.onEdit,
    required this.onClear,
  });

  final String title;
  final AppCoordinate? value;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(value?.label ?? '未设置'),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
          IconButton(onPressed: onClear, icon: const Icon(Icons.clear)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children, this.action});

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (action case final actionWidget?) actionWidget,
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫描车辆二维码')),
      body: MobileScanner(
        controller: _scannerController,
        onDetect: (capture) {
          if (_handled) {
            return;
          }
          final barcodes = capture.barcodes;
          final code = barcodes.isEmpty ? null : barcodes.first.rawValue;
          if (code != null && code.isNotEmpty) {
            _handled = true;
            Navigator.of(context).pop(code);
          }
        },
      ),
    );
  }
}

class BikeController extends ChangeNotifier {
  BikeController._(this._repo, this._prefs);

  static Future<BikeController> bootstrap() async {
    final repo = await BikeRepository.open();
    final prefs = await SharedPreferences.getInstance();
    final controller = BikeController._(repo, prefs);
    await controller._restore();
    controller._bindBluetoothStreams();
    controller._startTicker();
    return controller;
  }

  final BikeRepository _repo;
  final SharedPreferences _prefs;

  final List<AppErrorLog> errors = <AppErrorLog>[];
  final List<GeofenceCircle> circles = <GeofenceCircle>[];
  final List<GeofencePolygon> polygons = <GeofencePolygon>[];
  final List<RideRecord> rides = <RideRecord>[];

  StreamSubscription<String>? _connectionSub;
  StreamSubscription<String>? _lineSub;
  StreamSubscription<String>? _errorSub;
  Timer? _ticker;
  int _tickerCount = 0;

  String bluetoothState = 'disconnected';
  String lockState = 'unknown';
  String? parsedMac;
  String? lastQrRaw;
  String? lastStatusMessage;
  AppCoordinate? currentLocation;
  DebugOverrides debugOverrides = const DebugOverrides();
  RideSession? activeSession;

  DateTime _now = DateTime.now();
  DateTime? _pendingUnlockTime;
  DateTime? _pendingLockTime;
  AppCoordinate? _pendingUnlockLocation;
  AppCoordinate? _pendingLockLocation;
  Completer<String>? _pendingResponseCompleter;
  String? _pendingResponsePrefix;

  String get nowText =>
      _now.toLocal().toString().replaceFirst('T', ' ').split('.').first;

  String get bluetoothStateLabel {
    switch (bluetoothState) {
      case 'connected':
        return '已连接';
      case 'connecting':
        return '连接中';
      case 'disconnected':
        return '未连接';
      default:
        return bluetoothState;
    }
  }

  String get lockStateLabel {
    switch (lockState) {
      case 'locked':
        return '已锁定';
      case 'unlocked':
        return '骑行中';
      default:
        return '未知';
    }
  }

  String get displayStatusMessage =>
      describeMessage(lastStatusMessage) ?? '就绪。';

  int get unpaidRideCount => rides.where((item) => !item.isPaid).length;

  RideRecord? get latestUnpaidRide {
    for (final ride in rides) {
      if (!ride.isPaid) {
        return ride;
      }
    }
    return null;
  }

  double get estimatedFee {
    if (activeSession == null) {
      return 0;
    }
    return calculateFee(activeSession!.durationTo(_now));
  }

  Future<void> _restore() async {
    circles
      ..clear()
      ..addAll(await _repo.loadCircles());
    polygons
      ..clear()
      ..addAll(await _repo.loadPolygons());
    rides
      ..clear()
      ..addAll(await _repo.loadRides());
    activeSession = await _repo.loadActiveSession();
    lastQrRaw = _prefs.getString('last_qr_raw');
    parsedMac = _prefs.getString('last_mac');
    debugOverrides = DebugOverrides.fromJson(
      jsonDecode(_prefs.getString('debug_overrides') ?? '{}')
          as Map<String, dynamic>,
    );
    currentLocation = debugOverrides.mockCurrentLocation;
    if (activeSession != null) {
      lockState = 'unlocked';
    }
    notifyListeners();
  }

  Future<void> warmUpAfterLaunch() async {
    await refreshLocation(silent: true);
  }

  void _bindBluetoothStreams() {
    _connectionSub = BikeBluetoothPlatform.connectionStates.listen((event) {
      bluetoothState = event;
      notifyListeners();
    });
    _lineSub = BikeBluetoothPlatform.receivedLines.listen(_handleIncomingLine);
    _errorSub = BikeBluetoothPlatform.errors.listen((message) {
      _pushError('bluetooth', message);
    });
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      _tickerCount++;
      _now = DateTime.now();
      if (_tickerCount % 5 == 0 && activeSession != null) {
        await refreshLocation(silent: true);
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _connectionSub?.cancel();
    _lineSub?.cancel();
    _errorSub?.cancel();
    super.dispose();
  }

  Future<void> setQrRaw(String value) async {
    final mac = parseMac(value);
    if (mac == null) {
      _pushError('qr', '无法从输入文本中解析出蓝牙 MAC 地址。');
      return;
    }
    lastQrRaw = value;
    parsedMac = mac;
    await _prefs.setString('last_qr_raw', value);
    await _prefs.setString('last_mac', mac);
    lastStatusMessage = '已解析出 MAC：$mac';
    notifyListeners();
  }

  Future<void> refreshLocation({bool silent = false}) async {
    try {
      if (debugOverrides.mockCurrentLocation != null) {
        currentLocation = debugOverrides.mockCurrentLocation;
        if (!silent) {
          lastStatusMessage = '当前使用的是模拟位置。';
        }
        notifyListeners();
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent) {
          _pushError('location', '定位服务未开启。');
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!silent) {
          _pushError('location', '定位权限未授予。');
        }
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        if (!silent) {
          _pushError('location', '暂时无法获取当前位置。');
        }
        return;
      }

      currentLocation = AppCoordinate(position.latitude, position.longitude);
      if (!silent) {
        lastStatusMessage = '当前位置已刷新。';
      }
      notifyListeners();
    } catch (error) {
      if (!silent) {
        _pushError('location', '刷新定位失败：$error');
      }
    }
  }

  Future<bool> ensureBluetoothReady() async {
    final permissionsGranted = await BikeBluetoothPlatform.ensurePermissions();
    final enabled = await BikeBluetoothPlatform.isBluetoothEnabled();
    if (!permissionsGranted) {
      _pushError('bluetooth', '蓝牙权限尚未授予。');
      return false;
    }
    if (!enabled) {
      _pushError('bluetooth', '蓝牙未开启。');
      return false;
    }
    return true;
  }

  Future<bool> openBluetoothSettings() =>
      BikeBluetoothPlatform.openBluetoothSettings();

  Future<bool> connect() async {
    if (bluetoothState == 'connected') {
      return true;
    }
    if (parsedMac == null) {
      _pushError('bluetooth', '尚未解析出车辆蓝牙 MAC 地址。');
      return false;
    }
    if (!await ensureBluetoothReady()) {
      return false;
    }
    final requested = await BikeBluetoothPlatform.connect(parsedMac!);
    if (!requested) {
      return false;
    }
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (DateTime.now().isBefore(deadline)) {
      if (bluetoothState == 'connected') {
        lastStatusMessage = '蓝牙已连接。';
        notifyListeners();
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    _pushError('bluetooth', '蓝牙连接超时。');
    return false;
  }

  Future<void> disconnect() async {
    await BikeBluetoothPlatform.disconnect();
    bluetoothState = 'disconnected';
    notifyListeners();
  }

  Future<String?> queryStatus() async {
    try {
      if (!await connect()) {
        return null;
      }
      final response = await _sendCommandWithRetry(
        'S',
        'S,',
        const Duration(seconds: 3),
      );
      lastStatusMessage = response;
      return response;
    } catch (error) {
      _pushError('status', '$error');
      return null;
    }
  }

  Future<String?> playTrack(int track) async {
    try {
      if (!await connect()) {
        return null;
      }
      final response = await _sendCommandWithRetry(
        'P,$track',
        'P,',
        const Duration(seconds: 3),
      );
      lastStatusMessage = response;
      notifyListeners();
      return response;
    } catch (error) {
      _pushError('mp3', '$error');
      return null;
    }
  }

  Future<String?> unlock() async {
    if (latestUnpaidRide != null) {
      lastStatusMessage = '存在待支付订单，请先完成支付结算。';
      notifyListeners();
      return lastStatusMessage;
    }

    final operationLocation = await _resolveOperationLocation(
      scene: 'unlock',
      preferredLocation: debugOverrides.mockUnlockLocation,
      failureMessage: '当前无法获取开锁位置。',
    );
    if (operationLocation == null) {
      return null;
    }

    if (!_isAllowedLocation(operationLocation)) {
      await playTrack(5);
      lastStatusMessage = '当前位置不在允许区域内，已拒绝开锁。';
      notifyListeners();
      return '当前位置不在允许区域内，已拒绝开锁。';
    }

    if (!await connect()) {
      return null;
    }

    _pendingUnlockTime = DateTime.now();
    _pendingUnlockLocation = operationLocation;

    try {
      final response = await _sendCommandWithRetry(
        'U',
        'U,',
        const Duration(seconds: 15),
      );
      if (response == 'U,OK') {
        final session = RideSession(
          bikeMac: parsedMac!,
          unlockTime: _pendingUnlockTime!,
          unlockLocation: _pendingUnlockLocation!,
          lastLocation: operationLocation,
        );
        activeSession = session;
        await _repo.saveActiveSession(session);
        lockState = 'unlocked';
      }
      lastStatusMessage = response;
      notifyListeners();
      return response;
    } catch (error) {
      _pushError('unlock', '$error');
      return null;
    } finally {
      _pendingUnlockTime = null;
      _pendingUnlockLocation = null;
    }
  }

  Future<String?> lock() async {
    if (!await _ensureActiveSessionForLock()) {
      _pushError('lock', '当前没有进行中的骑行记录。');
      return null;
    }

    final operationLocation = await _resolveOperationLocation(
      scene: 'lock',
      preferredLocation: debugOverrides.mockLockLocation,
      failureMessage: '当前无法获取关锁位置。',
    );
    if (operationLocation == null) {
      return null;
    }

    if (!_isAllowedLocation(operationLocation)) {
      await playTrack(5);
      lastStatusMessage = '当前位置不在允许区域内，已拒绝关锁。';
      notifyListeners();
      return '当前位置不在允许区域内，已拒绝关锁。';
    }

    if (!await connect()) {
      return null;
    }

    _pendingLockTime = DateTime.now();
    _pendingLockLocation = operationLocation;

    try {
      final response = await _sendCommandWithRetry(
        'L',
        'L,',
        const Duration(seconds: 15),
      );
      if (response == 'L,OK') {
        final endTime = _pendingLockTime!;
        final endLocation = _pendingLockLocation!;
        final session = activeSession!;
        final duration = endTime.difference(session.unlockTime);
        final distanceM = Geolocator.distanceBetween(
          session.unlockLocation.lat,
          session.unlockLocation.lng,
          endLocation.lat,
          endLocation.lng,
        );
        final record = RideRecord(
          id: null,
          bikeMac: session.bikeMac,
          startTime: session.unlockTime,
          endTime: endTime,
          startLocation: session.unlockLocation,
          endLocation: endLocation,
          durationSec: duration.inSeconds,
          distanceM: distanceM,
          feeYuan: calculateFee(duration),
          paymentStatus: 'unpaid',
          paymentMethod: null,
          paidAt: null,
        );
        final savedRecord = await _repo.insertRide(record);
        rides.insert(0, savedRecord);
        activeSession = null;
        await _repo.clearActiveSession();
        lockState = 'locked';
      }
      lastStatusMessage = response;
      notifyListeners();
      return response;
    } catch (error) {
      _pushError('lock', '$error');
      return null;
    } finally {
      _pendingLockTime = null;
      _pendingLockLocation = null;
    }
  }

  Future<bool> settleRidePayment(
    RideRecord ride, {
    required String paymentMethod,
  }) async {
    if (ride.id == null) {
      _pushError('payment', '订单缺少编号，无法完成支付结算。');
      return false;
    }
    if (ride.isPaid) {
      lastStatusMessage = '该订单已完成支付。';
      notifyListeners();
      return true;
    }

    final updated = ride.copyWith(
      paymentStatus: 'paid',
      paymentMethod: paymentMethod,
      paidAt: DateTime.now(),
    );
    await _repo.updateRide(updated);
    final index = rides.indexWhere((item) => item.id == ride.id);
    if (index >= 0) {
      rides[index] = updated;
    }
    lastStatusMessage = '订单已完成支付并结算。';
    notifyListeners();
    return true;
  }

  Future<bool> _ensureActiveSessionForLock() async {
    RideSession? session;
    AppCoordinate unlockLocation;
    String? status;

    if (activeSession != null) {
      return true;
    }

    session = await _repo.loadActiveSession();
    if (session != null) {
      activeSession = session;
      lockState = 'unlocked';
      notifyListeners();
      return true;
    }

    if (parsedMac == null) {
      return false;
    }

    if (lockState != 'unlocked') {
      status = await queryStatus();
      if (status != 'S,1') {
        return false;
      }
    }

    unlockLocation =
        debugOverrides.mockUnlockLocation ??
        debugOverrides.mockCurrentLocation ??
        currentLocation ??
        kDefaultTestCoordinate;

    session = RideSession(
      bikeMac: parsedMac!,
      unlockTime: DateTime.now(),
      unlockLocation: unlockLocation,
      lastLocation: unlockLocation,
    );
    activeSession = session;
    await _repo.saveActiveSession(session);
    lastStatusMessage = '本地骑行记录已自动恢复。';
    notifyListeners();
    return true;
  }

  Future<void> clearActiveRide() async {
    activeSession = null;
    lockState = 'locked';
    await _repo.clearActiveSession();
    notifyListeners();
  }

  Future<void> saveCircle(GeofenceCircle circle) async {
    final saved = await _repo.upsertCircle(circle);
    final index = circles.indexWhere((item) => item.id == saved.id);
    if (index >= 0) {
      circles[index] = saved;
    } else {
      circles.add(saved);
    }
    notifyListeners();
  }

  Future<void> deleteCircle(int? id) async {
    if (id == null) {
      return;
    }
    await _repo.deleteCircle(id);
    circles.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  Future<void> savePolygon(GeofencePolygon polygon) async {
    final saved = await _repo.upsertPolygon(polygon);
    final index = polygons.indexWhere((item) => item.id == saved.id);
    if (index >= 0) {
      polygons[index] = saved;
    } else {
      polygons.add(saved);
    }
    notifyListeners();
  }

  Future<void> deletePolygon(int? id) async {
    if (id == null) {
      return;
    }
    await _repo.deletePolygon(id);
    polygons.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  Future<void> setGeofenceEnabled(bool enabled) async {
    debugOverrides = DebugOverrides(
      geofenceEnabled: enabled,
      mockCurrentLocation: debugOverrides.mockCurrentLocation,
      mockUnlockLocation: debugOverrides.mockUnlockLocation,
      mockLockLocation: debugOverrides.mockLockLocation,
    );
    await _persistOverrides();
  }

  Future<void> setMockCurrentLocation(AppCoordinate? value) async {
    debugOverrides = DebugOverrides(
      geofenceEnabled: debugOverrides.geofenceEnabled,
      mockCurrentLocation: value,
      mockUnlockLocation: debugOverrides.mockUnlockLocation,
      mockLockLocation: debugOverrides.mockLockLocation,
    );
    await _persistOverrides();
    if (value != null) {
      currentLocation = value;
    }
    notifyListeners();
  }

  Future<void> setMockUnlockLocation(AppCoordinate? value) async {
    debugOverrides = DebugOverrides(
      geofenceEnabled: debugOverrides.geofenceEnabled,
      mockCurrentLocation: debugOverrides.mockCurrentLocation,
      mockUnlockLocation: value,
      mockLockLocation: debugOverrides.mockLockLocation,
    );
    await _persistOverrides();
  }

  Future<void> setMockLockLocation(AppCoordinate? value) async {
    debugOverrides = DebugOverrides(
      geofenceEnabled: debugOverrides.geofenceEnabled,
      mockCurrentLocation: debugOverrides.mockCurrentLocation,
      mockUnlockLocation: debugOverrides.mockUnlockLocation,
      mockLockLocation: value,
    );
    await _persistOverrides();
  }

  Future<void> _persistOverrides() async {
    await _prefs.setString(
      'debug_overrides',
      jsonEncode(debugOverrides.toJson()),
    );
    notifyListeners();
  }

  bool _isAllowedLocation(AppCoordinate location) {
    if (!debugOverrides.geofenceEnabled) {
      return true;
    }
    if (circles.isEmpty && polygons.isEmpty) {
      return true;
    }
    for (final circle in circles) {
      if (!circle.enabled) {
        continue;
      }
      final distance = Geolocator.distanceBetween(
        location.lat,
        location.lng,
        circle.center.lat,
        circle.center.lng,
      );
      if (distance <= circle.radiusM) {
        return true;
      }
    }
    for (final polygon in polygons) {
      if (polygon.enabled && isPointInPolygon(location, polygon.points)) {
        return true;
      }
    }
    return false;
  }

  Future<AppCoordinate?> _resolveOperationLocation({
    required String scene,
    required String failureMessage,
    AppCoordinate? preferredLocation,
  }) async {
    var location = preferredLocation ?? currentLocation;
    if (location != null) {
      return location;
    }

    await refreshLocation(silent: false);
    location = preferredLocation ?? currentLocation;
    if (location != null) {
      return location;
    }

    if (!debugOverrides.geofenceEnabled ||
        (circles.isEmpty && polygons.isEmpty)) {
      currentLocation ??= kDefaultTestCoordinate;
      lastStatusMessage = '定位不可用，已使用默认测试坐标。';
      notifyListeners();
      return kDefaultTestCoordinate;
    }

    _pushError(scene, failureMessage);
    return null;
  }

  Future<String> _sendCommandExpecting(
    String command,
    String prefix,
    Duration timeout,
  ) async {
    if (_pendingResponseCompleter != null) {
      throw Exception('上一条命令仍在等待设备响应。');
    }
    final completer = Completer<String>();
    _pendingResponseCompleter = completer;
    _pendingResponsePrefix = prefix;

    final sent = await BikeBluetoothPlatform.sendLine(command);
    if (!sent) {
      _pendingResponseCompleter = null;
      _pendingResponsePrefix = null;
      throw Exception('命令发送失败。');
    }

    Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(Exception('命令超时：$command'));
        _pendingResponseCompleter = null;
        _pendingResponsePrefix = null;
      }
    });

    return completer.future;
  }

  Future<String> _sendCommandWithRetry(
    String command,
    String prefix,
    Duration timeout,
  ) async {
    var attempt = 0;
    String? response;

    while (attempt < 2) {
      response = await _sendCommandExpecting(command, prefix, timeout);
      if (response != 'E,BAD') {
        return response;
      }
      attempt++;
      if (attempt < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }

    return response!;
  }

  void _handleIncomingLine(String line) {
    if (line.startsWith('S,')) {
      lockState = line == 'S,0'
          ? 'locked'
          : line == 'S,1'
          ? 'unlocked'
          : lockState;
    } else if (line.startsWith('U,')) {
      if (line == 'U,OK') {
        lockState = 'unlocked';
      }
    } else if (line.startsWith('L,')) {
      if (line == 'L,OK') {
        lockState = 'locked';
      }
    }

    if (_pendingResponseCompleter != null &&
        _pendingResponsePrefix != null &&
        !_pendingResponseCompleter!.isCompleted &&
        (line.startsWith(_pendingResponsePrefix!) || line == 'E,BAD')) {
      _pendingResponseCompleter!.complete(line);
      _pendingResponseCompleter = null;
      _pendingResponsePrefix = null;
    }

    lastStatusMessage = line;
    notifyListeners();
  }

  void _pushError(String scene, String detail) {
    errors.insert(
      0,
      AppErrorLog(time: DateTime.now(), scene: scene, detail: detail),
    );
    if (errors.length > 40) {
      errors.removeRange(40, errors.length);
    }
    lastStatusMessage = detail;
    notifyListeners();
  }
}

class BikeBluetoothPlatform {
  static const MethodChannel _methodChannel = MethodChannel(
    'bike/bluetooth_method',
  );
  static const EventChannel _connectionChannel = EventChannel(
    'bike/bluetooth_connection',
  );
  static const EventChannel _lineChannel = EventChannel('bike/bluetooth_line');
  static const EventChannel _errorChannel = EventChannel(
    'bike/bluetooth_error',
  );

  static Stream<String> get connectionStates => _connectionChannel
      .receiveBroadcastStream()
      .map((event) => event.toString());

  static Stream<String> get receivedLines =>
      _lineChannel.receiveBroadcastStream().map((event) => event.toString());

  static Stream<String> get errors =>
      _errorChannel.receiveBroadcastStream().map((event) => event.toString());

  static Future<bool> ensurePermissions() async =>
      (await _methodChannel.invokeMethod<bool>('ensurePermissions')) ?? false;

  static Future<bool> isBluetoothEnabled() async =>
      (await _methodChannel.invokeMethod<bool>('isBluetoothEnabled')) ?? false;

  static Future<bool> openBluetoothSettings() async =>
      (await _methodChannel.invokeMethod<bool>('openBluetoothSettings')) ??
      false;

  static Future<bool> connect(String macAddress) async =>
      (await _methodChannel.invokeMethod<bool>('connect', <String, dynamic>{
        'macAddress': macAddress,
      })) ??
      false;

  static Future<bool> disconnect() async =>
      (await _methodChannel.invokeMethod<bool>('disconnect')) ?? false;

  static Future<bool> sendLine(String line) async =>
      (await _methodChannel.invokeMethod<bool>('sendLine', <String, dynamic>{
        'line': line,
      })) ??
      false;
}

class BikeRepository {
  BikeRepository._(this.db);

  final Database db;

  static Future<BikeRepository> open() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'bike_lock.db');
    final database = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE circles(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            center_lat REAL NOT NULL,
            center_lng REAL NOT NULL,
            radius_m REAL NOT NULL,
            enabled INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE polygons(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            points_json TEXT NOT NULL,
            enabled INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE rides(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bike_mac TEXT NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            start_lat REAL NOT NULL,
            start_lng REAL NOT NULL,
            end_lat REAL NOT NULL,
            end_lng REAL NOT NULL,
            duration_sec INTEGER NOT NULL,
            distance_m REAL NOT NULL,
            fee_yuan REAL NOT NULL,
            payment_status TEXT NOT NULL,
            payment_method TEXT,
            paid_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE active_session(
            id INTEGER PRIMARY KEY,
            bike_mac TEXT NOT NULL,
            unlock_time TEXT NOT NULL,
            unlock_lat REAL NOT NULL,
            unlock_lng REAL NOT NULL,
            last_lat REAL NOT NULL,
            last_lng REAL NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE rides ADD COLUMN payment_status TEXT NOT NULL DEFAULT 'paid'",
          );
          await db.execute('ALTER TABLE rides ADD COLUMN payment_method TEXT');
          await db.execute('ALTER TABLE rides ADD COLUMN paid_at TEXT');
        }
      },
    );
    return BikeRepository._(database);
  }

  Future<List<GeofenceCircle>> loadCircles() async {
    final rows = await db.query('circles', orderBy: 'id DESC');
    return rows.map(GeofenceCircle.fromMap).toList();
  }

  Future<GeofenceCircle> upsertCircle(GeofenceCircle circle) async {
    final map = circle.toMap();
    if (circle.id == null) {
      final id = await db.insert('circles', map);
      return circle.copyWith(id: id);
    }
    await db.update(
      'circles',
      map,
      where: 'id = ?',
      whereArgs: <Object?>[circle.id],
    );
    return circle;
  }

  Future<void> deleteCircle(int id) async {
    await db.delete('circles', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<List<GeofencePolygon>> loadPolygons() async {
    final rows = await db.query('polygons', orderBy: 'id DESC');
    return rows.map(GeofencePolygon.fromMap).toList();
  }

  Future<GeofencePolygon> upsertPolygon(GeofencePolygon polygon) async {
    final map = polygon.toMap();
    if (polygon.id == null) {
      final id = await db.insert('polygons', map);
      return polygon.copyWith(id: id);
    }
    await db.update(
      'polygons',
      map,
      where: 'id = ?',
      whereArgs: <Object?>[polygon.id],
    );
    return polygon;
  }

  Future<void> deletePolygon(int id) async {
    await db.delete('polygons', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<List<RideRecord>> loadRides() async {
    final rows = await db.query('rides', orderBy: 'id DESC');
    return rows.map(RideRecord.fromMap).toList();
  }

  Future<RideRecord> insertRide(RideRecord ride) async {
    final id = await db.insert('rides', ride.toMap());
    return ride.copyWith(id: id);
  }

  Future<void> updateRide(RideRecord ride) async {
    await db.update(
      'rides',
      ride.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[ride.id],
    );
  }

  Future<RideSession?> loadActiveSession() async {
    final rows = await db.query('active_session', where: 'id = 1');
    if (rows.isEmpty) {
      return null;
    }
    return RideSession.fromMap(rows.first);
  }

  Future<void> saveActiveSession(RideSession session) async {
    await db.insert(
      'active_session',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearActiveSession() async {
    await db.delete('active_session', where: 'id = 1');
  }
}

class AppCoordinate {
  const AppCoordinate(this.lat, this.lng);

  final double lat;
  final double lng;

  String get label => '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';

  Map<String, dynamic> toJson() => <String, dynamic>{'lat': lat, 'lng': lng};

  static AppCoordinate? maybeFromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    return AppCoordinate(
      (json['lat'] as num).toDouble(),
      (json['lng'] as num).toDouble(),
    );
  }
}

class GeofenceCircle {
  const GeofenceCircle({
    required this.id,
    required this.name,
    required this.center,
    required this.radiusM,
    required this.enabled,
  });

  final int? id;
  final String name;
  final AppCoordinate center;
  final double radiusM;
  final bool enabled;

  GeofenceCircle copyWith({
    int? id,
    String? name,
    AppCoordinate? center,
    double? radiusM,
    bool? enabled,
  }) {
    return GeofenceCircle(
      id: id ?? this.id,
      name: name ?? this.name,
      center: center ?? this.center,
      radiusM: radiusM ?? this.radiusM,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'name': name,
    'center_lat': center.lat,
    'center_lng': center.lng,
    'radius_m': radiusM,
    'enabled': enabled ? 1 : 0,
  };

  static GeofenceCircle fromMap(Map<String, Object?> map) {
    return GeofenceCircle(
      id: map['id'] as int?,
      name: map['name'] as String,
      center: AppCoordinate(
        (map['center_lat'] as num).toDouble(),
        (map['center_lng'] as num).toDouble(),
      ),
      radiusM: (map['radius_m'] as num).toDouble(),
      enabled: (map['enabled'] as int) == 1,
    );
  }
}

class GeofencePolygon {
  const GeofencePolygon({
    required this.id,
    required this.name,
    required this.points,
    required this.enabled,
  });

  final int? id;
  final String name;
  final List<AppCoordinate> points;
  final bool enabled;

  GeofencePolygon copyWith({
    int? id,
    String? name,
    List<AppCoordinate>? points,
    bool? enabled,
  }) {
    return GeofencePolygon(
      id: id ?? this.id,
      name: name ?? this.name,
      points: points ?? this.points,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'name': name,
    'points_json': jsonEncode(points.map((item) => item.toJson()).toList()),
    'enabled': enabled ? 1 : 0,
  };

  static GeofencePolygon fromMap(Map<String, Object?> map) {
    final decoded = jsonDecode(map['points_json'] as String) as List<dynamic>;
    return GeofencePolygon(
      id: map['id'] as int?,
      name: map['name'] as String,
      points: decoded
          .map(
            (item) =>
                AppCoordinate.maybeFromJson(item as Map<String, dynamic>)!,
          )
          .toList(),
      enabled: (map['enabled'] as int) == 1,
    );
  }
}

class DebugOverrides {
  const DebugOverrides({
    this.geofenceEnabled = true,
    this.mockCurrentLocation,
    this.mockUnlockLocation,
    this.mockLockLocation,
  });

  final bool geofenceEnabled;
  final AppCoordinate? mockCurrentLocation;
  final AppCoordinate? mockUnlockLocation;
  final AppCoordinate? mockLockLocation;

  DebugOverrides copyWith({
    bool? geofenceEnabled,
    AppCoordinate? mockCurrentLocation,
    AppCoordinate? mockUnlockLocation,
    AppCoordinate? mockLockLocation,
  }) {
    return DebugOverrides(
      geofenceEnabled: geofenceEnabled ?? this.geofenceEnabled,
      mockCurrentLocation: mockCurrentLocation ?? this.mockCurrentLocation,
      mockUnlockLocation: mockUnlockLocation ?? this.mockUnlockLocation,
      mockLockLocation: mockLockLocation ?? this.mockLockLocation,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'geofenceEnabled': geofenceEnabled,
    'mockCurrentLocation': mockCurrentLocation?.toJson(),
    'mockUnlockLocation': mockUnlockLocation?.toJson(),
    'mockLockLocation': mockLockLocation?.toJson(),
  };

  static DebugOverrides fromJson(Map<String, dynamic> json) {
    return DebugOverrides(
      geofenceEnabled: json['geofenceEnabled'] as bool? ?? true,
      mockCurrentLocation: AppCoordinate.maybeFromJson(
        json['mockCurrentLocation'],
      ),
      mockUnlockLocation: AppCoordinate.maybeFromJson(
        json['mockUnlockLocation'],
      ),
      mockLockLocation: AppCoordinate.maybeFromJson(json['mockLockLocation']),
    );
  }
}

class RideSession {
  const RideSession({
    required this.bikeMac,
    required this.unlockTime,
    required this.unlockLocation,
    required this.lastLocation,
  });

  final String bikeMac;
  final DateTime unlockTime;
  final AppCoordinate unlockLocation;
  final AppCoordinate lastLocation;

  Duration durationTo(DateTime endTime) => endTime.difference(unlockTime);

  Map<String, Object?> toMap() => <String, Object?>{
    'id': 1,
    'bike_mac': bikeMac,
    'unlock_time': unlockTime.toIso8601String(),
    'unlock_lat': unlockLocation.lat,
    'unlock_lng': unlockLocation.lng,
    'last_lat': lastLocation.lat,
    'last_lng': lastLocation.lng,
  };

  static RideSession fromMap(Map<String, Object?> map) {
    return RideSession(
      bikeMac: map['bike_mac'] as String,
      unlockTime: DateTime.parse(map['unlock_time'] as String),
      unlockLocation: AppCoordinate(
        (map['unlock_lat'] as num).toDouble(),
        (map['unlock_lng'] as num).toDouble(),
      ),
      lastLocation: AppCoordinate(
        (map['last_lat'] as num).toDouble(),
        (map['last_lng'] as num).toDouble(),
      ),
    );
  }
}

class RideRecord {
  const RideRecord({
    required this.id,
    required this.bikeMac,
    required this.startTime,
    required this.endTime,
    required this.startLocation,
    required this.endLocation,
    required this.durationSec,
    required this.distanceM,
    required this.feeYuan,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.paidAt,
  });

  final int? id;
  final String bikeMac;
  final DateTime startTime;
  final DateTime endTime;
  final AppCoordinate startLocation;
  final AppCoordinate endLocation;
  final int durationSec;
  final double distanceM;
  final double feeYuan;
  final String paymentStatus;
  final String? paymentMethod;
  final DateTime? paidAt;

  bool get isPaid => paymentStatus == 'paid';

  String get paymentStatusLabel => isPaid ? '已支付' : '待支付';

  String get paymentMethodLabel => paymentMethod ?? '未支付';

  String get startTimeText =>
      startTime.toLocal().toString().replaceFirst('T', ' ').split('.').first;
  String get endTimeText =>
      endTime.toLocal().toString().replaceFirst('T', ' ').split('.').first;
  String get paidAtText => paidAt == null
      ? '未支付'
      : paidAt!.toLocal().toString().replaceFirst('T', ' ').split('.').first;

  String get detailText =>
      '''
车辆 MAC：$bikeMac
开始时间：$startTimeText
结束时间：$endTimeText
开始位置：${startLocation.label}
结束位置：${endLocation.label}
骑行时长：${formatDuration(Duration(seconds: durationSec))}
骑行距离：${distanceM.toStringAsFixed(2)} 米
费用：¥${feeYuan.toStringAsFixed(2)}
支付状态：$paymentStatusLabel
支付方式：$paymentMethodLabel
支付时间：$paidAtText
''';

  RideRecord copyWith({
    int? id,
    String? bikeMac,
    DateTime? startTime,
    DateTime? endTime,
    AppCoordinate? startLocation,
    AppCoordinate? endLocation,
    int? durationSec,
    double? distanceM,
    double? feeYuan,
    String? paymentStatus,
    String? paymentMethod,
    DateTime? paidAt,
  }) {
    return RideRecord(
      id: id ?? this.id,
      bikeMac: bikeMac ?? this.bikeMac,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      durationSec: durationSec ?? this.durationSec,
      distanceM: distanceM ?? this.distanceM,
      feeYuan: feeYuan ?? this.feeYuan,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidAt: paidAt ?? this.paidAt,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'bike_mac': bikeMac,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime.toIso8601String(),
    'start_lat': startLocation.lat,
    'start_lng': startLocation.lng,
    'end_lat': endLocation.lat,
    'end_lng': endLocation.lng,
    'duration_sec': durationSec,
    'distance_m': distanceM,
    'fee_yuan': feeYuan,
    'payment_status': paymentStatus,
    'payment_method': paymentMethod,
    'paid_at': paidAt?.toIso8601String(),
  };

  static RideRecord fromMap(Map<String, Object?> map) {
    return RideRecord(
      id: map['id'] as int?,
      bikeMac: map['bike_mac'] as String,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: DateTime.parse(map['end_time'] as String),
      startLocation: AppCoordinate(
        (map['start_lat'] as num).toDouble(),
        (map['start_lng'] as num).toDouble(),
      ),
      endLocation: AppCoordinate(
        (map['end_lat'] as num).toDouble(),
        (map['end_lng'] as num).toDouble(),
      ),
      durationSec: map['duration_sec'] as int,
      distanceM: (map['distance_m'] as num).toDouble(),
      feeYuan: (map['fee_yuan'] as num).toDouble(),
      paymentStatus: map['payment_status'] as String? ?? 'paid',
      paymentMethod: map['payment_method'] as String?,
      paidAt: map['paid_at'] == null
          ? null
          : DateTime.parse(map['paid_at'] as String),
    );
  }
}

class AppErrorLog {
  const AppErrorLog({
    required this.time,
    required this.scene,
    required this.detail,
  });

  final DateTime time;
  final String scene;
  final String detail;

  String get text =>
      '[${time.toIso8601String()}] ${describeErrorScene(scene)}：$detail';
}

String? parseMac(String text) {
  final match = RegExp(
    r'([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}',
  ).firstMatch(text);
  if (match == null) {
    return null;
  }
  return match.group(0)!.replaceAll('-', ':').toUpperCase();
}

double calculateFee(Duration duration) {
  return duration.inSeconds / 60.0 * kFeePerMinute;
}

String? describeMessage(String? message) {
  if (message == null || message.trim().isEmpty) {
    return null;
  }

  switch (message) {
    case 'S,0':
      return '当前车辆状态：已锁定。';
    case 'S,1':
      return '当前车辆状态：骑行中。';
    case 'U,OK':
      return '开锁成功。';
    case 'U,ALREADY':
      return '车辆已经处于开锁状态。';
    case 'U,BUSY':
      return '设备忙，请稍后再试。';
    case 'L,OK':
      return '关锁成功。';
    case 'L,ALREADY':
      return '车辆已经处于锁定状态。';
    case 'L,BUSY':
      return '设备忙，请稍后再试。';
    case 'P,OK':
      return '提示音播放命令已发送。';
    case 'P,BAD':
      return '提示音编号无效。';
    case 'P,BUSY':
      return '设备忙，暂时无法播放提示音。';
    case 'E,BAD':
      return '发送的指令格式不正确。';
    default:
      return message;
  }
}

String describeErrorScene(String scene) {
  switch (scene) {
    case 'bluetooth':
      return '蓝牙';
    case 'location':
      return '定位';
    case 'unlock':
      return '开锁';
    case 'lock':
      return '关锁';
    case 'status':
      return '状态查询';
    case 'mp3':
      return '提示音';
    case 'qr':
      return '二维码';
    case 'payment':
      return '支付';
    default:
      return scene;
  }
}

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

bool isPointInPolygon(AppCoordinate point, List<AppCoordinate> polygon) {
  if (polygon.length < 3) {
    return false;
  }

  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final xi = polygon[i].lng;
    final yi = polygon[i].lat;
    final xj = polygon[j].lng;
    final yj = polygon[j].lat;

    final intersect =
        ((yi > point.lat) != (yj > point.lat)) &&
        (point.lng <
            (xj - xi) *
                    (point.lat - yi) /
                    ((yj - yi) == 0 ? 0.0000001 : (yj - yi)) +
                xi);
    if (intersect) {
      inside = !inside;
    }
  }
  return inside;
}

Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String hintText,
  String initialValue = '',
}) async {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(hintText: hintText),
        maxLines: 4,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

void showAppSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> showCircleEditor(
  BuildContext context,
  BikeController controller, {
  GeofenceCircle? initial,
}) async {
  final pageContext = context;
  final nameController = TextEditingController(text: initial?.name ?? '');
  final latController = TextEditingController(
    text:
        initial?.center.lat.toString() ??
        controller.currentLocation?.lat.toString() ??
        '',
  );
  final lngController = TextEditingController(
    text:
        initial?.center.lng.toString() ??
        controller.currentLocation?.lng.toString() ??
        '',
  );
  final radiusController = TextEditingController(
    text: initial?.radiusM.toString() ?? '200',
  );
  var enabled = initial?.enabled ?? true;

  final saved = await showDialog<bool>(
    context: context,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(initial == null ? '新增圆形围栏' : '编辑圆形围栏'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                TextField(
                  controller: latController,
                  decoration: const InputDecoration(labelText: '中心纬度'),
                ),
                TextField(
                  controller: lngController,
                  decoration: const InputDecoration(labelText: '中心经度'),
                ),
                TextField(
                  controller: radiusController,
                  decoration: const InputDecoration(labelText: '半径（米）'),
                ),
                SwitchListTile(
                  value: enabled,
                  onChanged: (value) => setState(() => enabled = value),
                  title: const Text('启用'),
                  contentPadding: EdgeInsets.zero,
                ),
                TextButton(
                  onPressed: () async {
                    await controller.refreshLocation();
                    final current = controller.currentLocation;
                    if (current != null) {
                      latController.text = current.lat.toString();
                      lngController.text = current.lng.toString();
                    } else if (pageContext.mounted) {
                      showAppSnackBar(pageContext, '当前位置仍不可用。');
                    }
                  },
                  child: const Text('使用当前位置'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      );
    },
  );

  if (saved != true) {
    return;
  }

  final lat = double.tryParse(latController.text.trim());
  final lng = double.tryParse(lngController.text.trim());
  final radius = double.tryParse(radiusController.text.trim());
  if (lat == null ||
      lng == null ||
      radius == null ||
      nameController.text.trim().isEmpty) {
    if (context.mounted) {
      showAppSnackBar(context, '圆形围栏参数填写不完整或格式错误。');
    }
    return;
  }

  await controller.saveCircle(
    GeofenceCircle(
      id: initial?.id,
      name: nameController.text.trim(),
      center: AppCoordinate(lat, lng),
      radiusM: radius,
      enabled: enabled,
    ),
  );
}

Future<void> showPolygonEditor(
  BuildContext context,
  BikeController controller, {
  GeofencePolygon? initial,
}) async {
  final pageContext = context;
  final nameController = TextEditingController(text: initial?.name ?? '');
  final pointsController = TextEditingController(
    text:
        initial?.points.map((item) => '${item.lat},${item.lng}').join('\n') ??
        '',
  );
  var enabled = initial?.enabled ?? true;

  final saved = await showDialog<bool>(
    context: context,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(initial == null ? '新增多边形围栏' : '编辑多边形围栏'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                TextField(
                  controller: pointsController,
                  decoration: const InputDecoration(
                    labelText: '顶点列表',
                    hintText: '每行填写一个“纬度,经度”',
                  ),
                  minLines: 6,
                  maxLines: 10,
                ),
                SwitchListTile(
                  value: enabled,
                  onChanged: (value) => setState(() => enabled = value),
                  title: const Text('启用'),
                  contentPadding: EdgeInsets.zero,
                ),
                TextButton(
                  onPressed: () async {
                    await controller.refreshLocation();
                    final current = controller.currentLocation;
                    if (current != null) {
                      final suffix = pointsController.text.trim().isEmpty
                          ? ''
                          : '\n';
                      pointsController.text =
                          '${pointsController.text}$suffix${current.lat},${current.lng}';
                    } else if (pageContext.mounted) {
                      showAppSnackBar(pageContext, '当前位置仍不可用。');
                    }
                  },
                  child: const Text('追加当前位置'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      );
    },
  );

  if (saved != true) {
    return;
  }

  final lines = pointsController.text
      .split('\n')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
  final points = <AppCoordinate>[];
  for (final line in lines) {
    final parts = line.split(',');
    if (parts.length != 2) {
      if (context.mounted) {
        showAppSnackBar(context, '多边形顶点格式错误。');
      }
      return;
    }
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) {
      if (context.mounted) {
        showAppSnackBar(context, '多边形顶点格式错误。');
      }
      return;
    }
    points.add(AppCoordinate(lat, lng));
  }
  if (points.length < 3 || nameController.text.trim().isEmpty) {
    if (context.mounted) {
      showAppSnackBar(context, '多边形围栏至少需要 3 个顶点，并且必须填写名称。');
    }
    return;
  }

  await controller.savePolygon(
    GeofencePolygon(
      id: initial?.id,
      name: nameController.text.trim(),
      points: points,
      enabled: enabled,
    ),
  );
}

Future<void> showCoordinateEditor(
  BuildContext context, {
  required String title,
  required AppCoordinate? initial,
  required BikeController controller,
  required ValueChanged<AppCoordinate?> onSaved,
}) async {
  final pageContext = context;
  final latController = TextEditingController(
    text: initial?.lat.toString() ?? '',
  );
  final lngController = TextEditingController(
    text: initial?.lng.toString() ?? '',
  );
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: latController,
            decoration: const InputDecoration(labelText: '纬度'),
          ),
          TextField(
            controller: lngController,
            decoration: const InputDecoration(labelText: '经度'),
          ),
          TextButton(
            onPressed: () async {
              await controller.refreshLocation();
              final fillSource = controller.currentLocation;
              if (fillSource != null) {
                latController.text = fillSource.lat.toString();
                lngController.text = fillSource.lng.toString();
              } else if (pageContext.mounted) {
                showAppSnackBar(pageContext, '当前位置仍不可用。');
              }
            },
            child: const Text('使用当前位置'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  if (saved != true) {
    return;
  }
  final lat = double.tryParse(latController.text.trim());
  final lng = double.tryParse(lngController.text.trim());
  if (lat == null || lng == null) {
    if (context.mounted) {
      showAppSnackBar(context, '坐标格式错误。');
    }
    return;
  }
  onSaved(AppCoordinate(lat, lng));
}

Future<void> showRidePaymentDialog(
  BuildContext context,
  BikeController controller,
  RideRecord ride,
) async {
  if (ride.isPaid) {
    if (context.mounted) {
      showAppSnackBar(context, '该订单已完成支付。');
    }
    return;
  }

  var selectedMethod = kPaymentMethods.first;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('支付并结算'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('订单金额：¥${ride.feeYuan.toStringAsFixed(2)}'),
                Text(
                  '骑行时长：${formatDuration(Duration(seconds: ride.durationSec))}',
                ),
                Text('骑行距离：${ride.distanceM.toStringAsFixed(2)} 米'),
                const SizedBox(height: 12),
                const Text('请选择支付方式：'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedMethod,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '支付方式',
                  ),
                  items: kPaymentMethods
                      .map(
                        (method) => DropdownMenuItem<String>(
                          value: method,
                          child: Text(method),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => selectedMethod = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('确认支付'),
            ),
          ],
        ),
      );
    },
  );

  if (confirmed != true) {
    return;
  }

  final success = await controller.settleRidePayment(
    ride,
    paymentMethod: selectedMethod,
  );
  if (context.mounted) {
    showAppSnackBar(context, success ? '支付成功，本次骑行已结算。' : '支付失败，请稍后重试。');
  }
}

void showErrorSheet(BuildContext context, BikeController controller) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final allText = controller.errors.map((item) => item.text).join('\n');
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '错误面板',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: allText.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: allText));
                          if (context.mounted) {
                            showAppSnackBar(context, '错误详情已复制。');
                          }
                        },
                  icon: const Icon(Icons.copy_all),
                  label: const Text('复制'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: controller.errors.isEmpty
                  ? const Center(child: Text('暂无错误信息。'))
                  : ListView.builder(
                      itemCount: controller.errors.length,
                      itemBuilder: (context, index) {
                        final item = controller.errors[index];
                        return ListTile(
                          dense: true,
                          title: Text(describeErrorScene(item.scene)),
                          subtitle: Text(item.text),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );
}

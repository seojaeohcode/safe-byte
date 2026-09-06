import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

final cartService = Uuid.parse('76c10001-249b-4e40-9c5d-a0f6b80c10a1');
final cartCharacteristic = Uuid.parse('76c10002-249b-4e40-9c5d-a0f6b80c10a1');
const _mutedInk = Color(0xff66727f);

class CartBleScreen extends StatefulWidget {
  const CartBleScreen({required this.code, super.key});
  final String code;
  @override
  State<CartBleScreen> createState() => _CartBleScreenState();
}

class _BlePanel extends StatelessWidget {
  const _BlePanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _CartBleScreenState extends State<CartBleScreen> {
  final _ble = FlutterReactiveBle();
  final _devices = <String, DiscoveredDevice>{};
  StreamSubscription<DiscoveredDevice>? _scan;
  StreamSubscription<ConnectionStateUpdate>? _connection;
  Timer? _timer;
  String _status = 'Bluetooth 준비 중';
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (kIsWeb) {
      setState(() {
        _status =
            'Bluetooth 연결은 Android 앱에서 사용할 수 있어요. 웹에서는 페어링 코드를 카트 화면에 입력해주세요.';
      });
      return;
    }
    try {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse
      ].request();
      if (_ble.status != BleStatus.ready) {
        await _ble.statusStream
            .firstWhere((s) => s == BleStatus.ready)
            .timeout(const Duration(seconds: 10));
      }
      if (!mounted) {
        return;
      }
      setState(() => _status = '연결할 카트를 선택하세요 / Select a cart');
      _scan = _ble.scanForDevices(withServices: [cartService]).listen((d) {
        if (mounted) setState(() => _devices[d.id] = d);
      }, onError: (Object e) {
        if (mounted) setState(() => _status = 'Bluetooth 검색 실패: $e');
      });
      _timer = Timer(const Duration(seconds: 15), () {
        _scan?.cancel();
        if (mounted && _devices.isEmpty) {
          setState(() {
            _status = '카트를 찾지 못했습니다. 카트의 BLE를 켜주세요.';
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Bluetooth 권한과 전원을 확인해주세요.');
      }
    }
  }

  Future<void> _send(DiscoveredDevice device) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = '연결 중 / Connecting';
    });
    await _scan?.cancel();
    final connected = Completer<void>();
    try {
      _connection = _ble
          .connectToDevice(
              id: device.id, connectionTimeout: const Duration(seconds: 10))
          .listen((state) {
        if (state.connectionState == DeviceConnectionState.connected &&
            !connected.isCompleted) {
          connected.complete();
        }
        if (state.connectionState == DeviceConnectionState.disconnected &&
            !connected.isCompleted) {
          connected.completeError(StateError('Disconnected'));
        }
      }, onError: (Object e) {
        if (!connected.isCompleted) connected.completeError(e);
      });
      await connected.future.timeout(const Duration(seconds: 12));
      final characteristic = QualifiedCharacteristic(
          serviceId: cartService,
          characteristicId: cartCharacteristic,
          deviceId: device.id);
      final bytes = utf8.encode('${widget.code}\n');
      for (var i = 0; i < bytes.length; i += 20) {
        await _ble.writeCharacteristicWithResponse(characteristic,
            value: bytes.sublist(i, (i + 20).clamp(0, bytes.length)));
      }
      if (mounted) {
        setState(() {
          _status = '코드를 전송했습니다. 카트 LCD에서 연결 완료를 확인하세요.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = '연결 실패: $e');
      }
    } finally {
      await _connection?.cancel();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scan?.cancel();
    _connection?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bluetooth 카트 연결')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            _BlePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _status,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(minHeight: 4),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_devices.isEmpty && !_busy) ...[
              _BlePanel(
                child: Column(
                  children: const [
                    Icon(Icons.bluetooth_searching_rounded, size: 34),
                    SizedBox(height: 10),
                    Text('카트를 찾고 있어요.'),
                    SizedBox(height: 6),
                    Text('카트 전원을 켜고 앱과 가까이 두어 주세요.'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            ..._devices.values.map((device) => _BlePanel(
                  child: ListTile(
                    leading: const Icon(Icons.bluetooth_connected_rounded),
                    title: Text(
                        device.name.isEmpty ? 'SafeByte Cart' : device.name),
                    subtitle: Text(device.id),
                    trailing: Text('${device.rssi} dBm',
                        style: TextStyle(color: _mutedInk)),
                    onTap: _busy ? null : () => _send(device),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

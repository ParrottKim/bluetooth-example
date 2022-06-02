import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bluetooth_example/pages/connection_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class HomePage extends StatefulWidget {
  HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;

  String _address = "...";
  String _name = "...";

  Timer? _discoverableTimeoutTimer;
  int _discoverableTimeoutSecondsLeft = 0;

  final _bluetooth = FlutterBluetoothSerial.instance;

  StreamSubscription<BluetoothDiscoveryResult>? _streamSubscription;
  List<BluetoothDiscoveryResult> results =
      List<BluetoothDiscoveryResult>.empty(growable: true);
  bool _isScanning = false;

  _scanDevices() {
    setState(() {
      results.clear();
      _isScanning = true;
    });

    _streamSubscription = _bluetooth.startDiscovery().listen((r) {
      setState(() {
        final existingIndex = results.indexWhere(
            (element) => element.device.address == r.device.address);
        if (existingIndex >= 0)
          results[existingIndex] = r;
        else
          results.add(r);
      });
    });
    _streamSubscription!.onDone(() {
      setState(() {
        _isScanning = false;
      });
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search Bluetooth Device'),
      ),
      body: SingleChildScrollView(
        child: ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: results.length,
          itemBuilder: (context, index) => ListTile(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ConnectionPage(result: results[index]),
                ),
              );
            },
            title: results[index].device.name != null
                ? Text('${results[index].device.name}')
                : Text('N/A'),
            subtitle: Text(results[index].device.address.toString()),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: !_isScanning ? _scanDevices : null,
        child: !_isScanning
            ? Icon(Icons.search)
            : Container(
                height: 24.0,
                width: 24.0,
                child: CircularProgressIndicator(color: Colors.white),
              ),
      ),
    );
  }
}

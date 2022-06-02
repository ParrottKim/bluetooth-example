import "package:collection/collection.dart";

import 'dart:typed_data';

import 'package:bluetooth_example/models/message_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:hex/hex.dart';

class ConnectionPage extends StatefulWidget {
  final BluetoothDiscoveryResult result;
  ConnectionPage({Key? key, required this.result}) : super(key: key);

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  late TextEditingController _textController;

  BluetoothConnection? _connection;
  bool get _isConnected => (_connection?.isConnected ?? false);
  bool _isConnecting = true;
  bool _isDisconnecting = false;

  List<MessageModel> _messages = List.empty(growable: true);

  calculateChecksum(List<int> data, int length) {
    int checksum = 0x00;
    for (int i = 0; i < length; i++) {
      checksum ^= data[i];
    }
    return checksum;
  }

  void _sendMessage(String text) async {
    text = text.trim();
    _textController.clear();

    if (text.isNotEmpty) {
      try {
        List<int> data = List<int>.empty(growable: true);
        data = HEX.decode(text).toList();
        data.add(calculateChecksum(data, data.length - 1));

        String tx = '';
        for (var value in data) {
          tx += '${HEX.encode([value]).toUpperCase()} ';
        }

        Uint8List bytes = Uint8List.fromList(data);
        _connection!.output.add(bytes);
        await _connection!.output.allSent.then((_) => setState(
              () => _messages.add(MessageModel(
                date: DateTime.now().toLocal(),
                message: tx.toString(),
                isRequest: true,
              )),
            ));
      } catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    String rx = '';

    for (var value in data) {
      rx += '${HEX.encode([value]).toUpperCase()} ';
    }

    setState(
      () => _messages.add(MessageModel(
        date: DateTime.now().toLocal(),
        message: rx.toString(),
        isRequest: false,
      )),
    );
  }

  _connectDevice(BluetoothDiscoveryResult result) async {
    try {
      await BluetoothConnection.toAddress(result.device.address)
          .then((connection) {
        setState(() {
          _connection = connection;
        });
      });

      _connection!.input!.listen(_onDataReceived).onDone(() {});
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Cannot connect to ${result.device.name} (${result.device.address})'),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    if (_isConnected) {
      _connection?.dispose();
      _connection = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var grouped = groupBy(
        _messages,
        (MessageModel element) =>
            '${element.date.year}. ${element.date.month}. ${element.date.day}');
    return Scaffold(
      appBar: AppBar(
          titleSpacing: 0.0,
          title: Row(
            children: [
              Icon(Icons.circle,
                  color: _isConnected ? Colors.green : Colors.red),
              SizedBox(width: 8.0),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  widget.result.device.name != null
                      ? Text('${widget.result.device.name}')
                      : Text('N/A'),
                  Text(
                    '${widget.result.device.address}',
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: !_isConnected
                  ? () {
                      _connectDevice(widget.result);
                    }
                  : null,
              splashRadius: 28.0,
              icon: Icon(Icons.bluetooth),
            )
          ]),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              reverse: true,
              primary: false,
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              itemCount: grouped.keys.length,
              itemBuilder: (context, index) {
                String date = grouped.keys.toList()[index];
                List? messages = grouped[date];

                return MessageCard(messages: messages);
              },
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.only(left: 28.0, right: 28.0, bottom: 28.0),
            child: TextField(
              readOnly: !_isConnected,
              controller: _textController,
              onSubmitted: (value) => _sendMessage(_textController.text),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageCard extends StatelessWidget {
  final List? messages;
  const MessageCard({Key? key, this.messages}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (messages != null) {
      return ListView.separated(
        shrinkWrap: true,
        itemCount: messages!.length,
        itemBuilder: (context, index) => Column(
          crossAxisAlignment: messages![index].isRequest
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
              constraints: BoxConstraints(maxWidth: size.width * 0.6),
              decoration: BoxDecoration(
                color: messages![index].isRequest
                    ? Theme.of(context).primaryColor
                    : Colors.grey[200],
                borderRadius: messages![index].isRequest
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(10.0),
                        topRight: Radius.circular(10.0),
                        bottomLeft: Radius.circular(10.0),
                      )
                    : const BorderRadius.only(
                        topLeft: Radius.circular(10.0),
                        topRight: Radius.circular(10.0),
                        bottomRight: Radius.circular(10.0),
                      ),
              ),
              child: Text(
                messages![index].message,
                style: TextStyle(
                  color: messages![index].isRequest
                      ? Colors.white
                      : Colors.grey[800],
                ),
              ),
            ),
            SizedBox(height: 4.0),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  messages![index].date.toString(),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12.0,
                  ),
                ),
              ],
            ),
          ],
        ),
        separatorBuilder: (context, index) => SizedBox(height: 10.0),
      );
    } else
      return SizedBox.shrink();
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nearpay_flutter_sdk/nearpay.dart';

class ICCardReaderExample extends StatefulWidget {
  @override
  _ICCardReaderExampleState createState() => _ICCardReaderExampleState();
}

class _ICCardReaderExampleState extends State<ICCardReaderExample> {
  String _status = "Not initialized";
  String _lastCardRead = "No card read";
  String _currentHardware = "Unknown";
  bool _isReading = false;

  @override
  void initState() {
    super.initState();
    _initializeHardware();
  }

  // Initialize and detect hardware
  Future<void> _initializeHardware() async {
    try {
      setState(() {
        _status = "Detecting hardware...";
      });

      // Detect available hardware
      var detectionResult = await Nearpay.detectHardware();
      print('Hardware Detection Result: $detectionResult');

      if (detectionResult['status'] == 200) {
        List availableHardware = detectionResult['available_hardware'];

        // Show available hardware
        for (var hardware in availableHardware) {
          print(
              'Found hardware: ${hardware['type']} at ${hardware['devicePath']} - Available: ${hardware['available']}');
        }

        // Auto-initialize with best available hardware
        var initResult = await Nearpay.autoInitializeHardware();
        print('Initialization Result: $initResult');

        if (initResult['status'] == 200) {
          setState(() {
            _status = "Hardware initialized successfully";
            _currentHardware = initResult['hardware_type'] ?? 'Unknown';
          });
        } else {
          setState(() {
            _status =
                "Hardware initialization failed: ${initResult['message']}";
          });
        }
      } else {
        setState(() {
          _status = "Hardware detection failed";
        });
      }
    } catch (e) {
      setState(() {
        _status = "Error: $e";
      });
      print('Hardware initialization error: $e');
    }
  }

  // Read a single card
  Future<void> _readSingleCard() async {
    try {
      var result = await Nearpay.readCard();
      print('Card Read Result: $result');

      if (result['status'] == 200) {
        setState(() {
          _status = "Card reading initiated...";
        });
      } else {
        setState(() {
          _status = "Card read failed: ${result['message']}";
        });
      }
    } catch (e) {
      setState(() {
        _status = "Card read error: $e";
      });
    }
  }

  // Start continuous reading
  Future<void> _startContinuousReading() async {
    try {
      var result = await Nearpay.startCardReading();
      print('Start Reading Result: $result');

      if (result['status'] == 200) {
        setState(() {
          _status = "Continuous reading started";
          _isReading = true;
        });
      } else {
        setState(() {
          _status = "Failed to start reading: ${result['message']}";
        });
      }
    } catch (e) {
      setState(() {
        _status = "Start reading error: $e";
      });
    }
  }

  // Stop reading
  Future<void> _stopReading() async {
    try {
      var result = await Nearpay.stopCardReading();
      print('Stop Reading Result: $result');

      setState(() {
        _status = "Reading stopped";
        _isReading = false;
      });
    } catch (e) {
      setState(() {
        _status = "Stop reading error: $e";
      });
    }
  }

  // Get hardware status
  Future<void> _getHardwareStatus() async {
    try {
      var status = await Nearpay.getHardwareStatus();
      print('Hardware Status: $status');

      setState(() {
        _currentHardware = status['current_hardware'] ?? 'Unknown';
        if (status['ic_reader_status'] != null) {
          var icStatus = status['ic_reader_status'];
          _status =
              "IC Reader: ${icStatus['connected']} at ${icStatus['devicePath']}";
        } else {
          _status = "Hardware status retrieved";
        }
      });
    } catch (e) {
      setState(() {
        _status = "Status error: $e";
      });
    }
  }

  // Initialize specific hardware (IC Card Reader)
  Future<void> _initializeICCardReader() async {
    try {
      var result = await Nearpay.initializeHardware(
        hardwareType: HardwareType.icCardReader.value,
        devicePath: '/dev/ttyUSB0', // Adjust path as needed
      );
      print('IC Reader Init Result: $result');

      if (result['status'] == 200) {
        setState(() {
          _status = "IC Card Reader initialized";
          _currentHardware = "IC Card Reader";
        });
      } else {
        setState(() {
          _status = "IC Reader init failed: ${result['message']}";
        });
      }
    } catch (e) {
      setState(() {
        _status = "IC Reader init error: $e";
      });
    }
  }

  // Switch to NearPay Cloud mode
  Future<void> _switchToNearPay() async {
    try {
      var result = await Nearpay.initializeHardware(
        hardwareType: HardwareType.nearpayCloud.value,
      );
      print('NearPay Init Result: $result');

      if (result['status'] == 200) {
        setState(() {
          _status = "NearPay Cloud mode activated";
          _currentHardware = "NearPay Cloud";
        });

        // Initialize NearPay SDK as before
        var reqData = {
          "authtype": "email", // or your auth type
          "authvalue": "your_token_here",
          "locale": Locale.localeDefault.value,
          "environment": Environments.sandbox.value
        };
        await Nearpay.initialize(reqData);
      }
    } catch (e) {
      setState(() {
        _status = "NearPay init error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('IC Card Reader Integration'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_status),
                    SizedBox(height: 8),
                    Text('Current Hardware:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_currentHardware),
                    SizedBox(height: 8),
                    Text('Last Card Read:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_lastCardRead),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeHardware,
              child: Text('Auto Detect & Initialize Hardware'),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _initializeICCardReader,
                    child: Text('Use IC Reader'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _switchToNearPay,
                    child: Text('Use NearPay'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _readSingleCard,
              child: Text('Read Single Card'),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isReading ? null : _startContinuousReading,
                    child: Text('Start Reading'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isReading ? _stopReading : null,
                    child: Text('Stop Reading'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _getHardwareStatus,
              child: Text('Get Hardware Status'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_isReading) {
      Nearpay.stopCardReading();
    }
    super.dispose();
  }
}

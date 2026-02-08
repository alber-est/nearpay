import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nearpay_flutter_sdk/nearpay.dart';

class RK3588SNFCTest extends StatefulWidget {
  @override
  _RK3588SNFCTestState createState() => _RK3588SNFCTestState();
}

class _RK3588SNFCTestState extends State<RK3588SNFCTest> {
  String _status = "Starting RK3588S NFC Test...";
  String _hardwareInfo = "Not detected";
  String _lastCardType = "No card detected";
  String _lastCardId = "None";
  bool _isTesting = false;
  bool _isReading = false;
  List<Map<String, dynamic>> _detectedCards = [];

  // Method channel for listening to card events
  static const platform = MethodChannel('nearpay');

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
    _initializeRK3588S();
  }

  // Setup event listeners for card detection
  void _setupEventListeners() {
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onCardDetected':
          _handleCardDetected(call.arguments);
          break;
        case 'onCardError':
          _handleCardError(call.arguments);
          break;
        case 'onReaderConnected':
          _handleReaderConnected();
          break;
        case 'onReaderDisconnected':
          _handleReaderDisconnected();
          break;
      }
    });
  }

  // Handle card detected event
  void _handleCardDetected(dynamic arguments) {
    try {
      var cardData = arguments['card_data'];
      var cardId = cardData['cardId'] ?? 'Unknown';
      var cardType = cardData['cardType'] ?? 'Unknown';

      setState(() {
        _lastCardId = cardId;
        _lastCardType = cardType;
        _status = "Card detected: $cardType";
        _isTesting = false;

        // Add to detected cards list
        _detectedCards.insert(0, {
          'cardId': cardId,
          'cardType': cardType,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        // Keep only last 10 detections
        if (_detectedCards.length > 10) {
          _detectedCards.removeLast();
        }
      });

      print('RK3588S Card Detected - ID: $cardId, Type: $cardType');

      // Provide visual/audio feedback
      _showCardDetectedSnackbar(cardType, cardId);
    } catch (e) {
      print('Error handling card detected: $e');
    }
  }

  // Handle card error
  void _handleCardError(dynamic arguments) {
    var error = arguments['error'] ?? 'Unknown error';
    setState(() {
      _status = "Card error: $error";
      _isTesting = false;
    });
    print('RK3588S Card Error: $error');
  }

  // Handle reader connected
  void _handleReaderConnected() {
    setState(() {
      _status = "RK3588S NFC reader connected";
    });
    print('RK3588S Reader Connected');
  }

  // Handle reader disconnected
  void _handleReaderDisconnected() {
    setState(() {
      _status = "RK3588S NFC reader disconnected";
      _isReading = false;
      _isTesting = false;
    });
    print('RK3588S Reader Disconnected');
  }

  // Show snackbar for card detection
  void _showCardDetectedSnackbar(String cardType, String cardId) {
    String analysis = _analyzeCardType(cardType);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$analysis\nCard ID: $cardId'),
        duration: Duration(seconds: 2),
        backgroundColor: cardType.contains('BANK') ? Colors.green : Colors.blue,
      ),
    );
  }

  // Initialize RK3588S specific hardware detection
  Future<void> _initializeRK3588S() async {
    try {
      setState(() {
        _status = "Checking RK3588S NFC hardware...";
      });

      // Step 1: Detect available hardware
      var detection = await Nearpay.detectHardware();
      print('RK3588S Hardware Detection: ${json.encode(detection)}');

      if (detection['status'] == 200) {
        List availableHardware = detection['available_hardware'];

        setState(() {
          _hardwareInfo = "Found ${availableHardware.length} hardware options";
        });

        // Show detailed hardware info
        for (var hw in availableHardware) {
          print('Hardware: ${hw['type']} - ${hw['description']}');
          print('Available: ${hw['available']}, Path: ${hw['devicePath']}');

          if (hw['type'] == 'ic_card_reader' && hw['available'] == true) {
            // Try to initialize with RK3588S specific paths
            await _initializeWithRK3588SPaths(hw['devicePath']);
            return;
          }
        }

        // If no IC reader found, try common RK3588S paths
        await _tryRK3588SPaths();
      } else {
        setState(() {
          _status = "Hardware detection failed";
        });
      }
    } catch (e) {
      setState(() {
        _status = "Error: $e";
      });
    }
  }

  // Try RK3588S specific device paths
  Future<void> _tryRK3588SPaths() async {
    List<String> rk3588sPaths = [
      '/dev/ttyS0', // Most common for NFC on RK3588S
      '/dev/ttyS1',
      '/dev/ttyS2',
      '/dev/ttyRK0', // RK specific UART
      '/dev/ttyRK1',
      '/dev/i2c-0', // I2C interface
      '/dev/i2c-1',
    ];

    for (String path in rk3588sPaths) {
      try {
        setState(() {
          _status = "Trying RK3588S path: $path";
        });

        var result = await Nearpay.initializeHardware(
          hardwareType: HardwareType.icCardReader.value,
          devicePath: path,
        );

        print('RK3588S Path $path result: ${json.encode(result)}');

        if (result['status'] == 200) {
          setState(() {
            _status = "RK3588S NFC initialized at $path";
            _hardwareInfo = "RK3588S NFC at $path";
          });
          return;
        }
      } catch (e) {
        print('Error with path $path: $e');
      }
    }

    setState(() {
      _status = "No RK3588S NFC hardware found";
    });
  }

  // Initialize with specific RK3588S path
  Future<void> _initializeWithRK3588SPaths(String? suggestedPath) async {
    try {
      String devicePath = suggestedPath ?? '/dev/ttyS0';

      var result = await Nearpay.initializeHardware(
        hardwareType: HardwareType.icCardReader.value,
        devicePath: devicePath,
      );

      if (result['status'] == 200) {
        setState(() {
          _status = "RK3588S NFC initialized successfully";
          _hardwareInfo = "IC Reader at $devicePath";
        });
      } else {
        setState(() {
          _status = "Initialization failed: ${result['message']}";
        });
      }
    } catch (e) {
      setState(() {
        _status = "Initialization error: $e";
      });
    }
  }

  // Test door card vs bank card detection
  Future<void> _testCardTypes() async {
    try {
      setState(() {
        _isTesting = true;
        _status = "Testing card type detection...";
      });

      // Single read test
      var result = await Nearpay.readCard();
      print('Card test result: ${json.encode(result)}');

      if (result['status'] == 200) {
        setState(() {
          _status = "Card reading initiated - please present card";
        });
      } else {
        setState(() {
          _status = "Card test failed: ${result['message']}";
          _isTesting = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = "Card test error: $e";
        _isTesting = false;
      });
    }
  }

  // Start continuous reading for both door and bank cards
  Future<void> _startContinuousReading() async {
    try {
      var result = await Nearpay.startCardReading();
      print('Start reading result: ${json.encode(result)}');

      if (result['status'] == 200) {
        setState(() {
          _status = "Continuous reading started - present cards";
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
      await Nearpay.stopCardReading();
      setState(() {
        _status = "Reading stopped";
        _isReading = false;
        _isTesting = false;
      });
    } catch (e) {
      setState(() {
        _status = "Stop error: $e";
      });
    }
  }

  // Clear detected cards list
  void _clearResults() {
    setState(() {
      _detectedCards.clear();
      _lastCardType = "No card detected";
      _lastCardId = "None";
    });
  }

  // Analyze card type for user understanding
  String _analyzeCardType(String cardType) {
    if (cardType.contains('BANK') ||
        cardType.contains('ISO14443') ||
        cardType.contains('EMV')) {
      return '💳 Bank/Payment Card';
    } else if (cardType.contains('DOOR') || cardType.contains('125KHZ')) {
      return '🚪 Door/Access Card';
    } else if (cardType.contains('M1') || cardType.contains('NTAG')) {
      return '🏷️ NFC Tag/Card';
    } else {
      return '❓ Unknown Card Type';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('RK3588S NFC Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RK3588S Board Status:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 8),
                    Text(_status),
                    SizedBox(height: 8),
                    Text('Hardware:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_hardwareInfo),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Last Card Info
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Last Card Detected:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 8),
                    Text('Type: $_lastCardType'),
                    Text('Analysis: ${_analyzeCardType(_lastCardType)}'),
                    Text('ID: $_lastCardId'),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _initializeRK3588S,
                    child: Text('Re-Initialize'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: !_isTesting ? _testCardTypes : null,
                    child: Text('Test Single Read'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                  ),
                ),
              ],
            ),

            SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: !_isReading ? _startContinuousReading : null,
                    child: Text('Start Continuous'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isReading ? _stopReading : null,
                    child: Text('Stop Reading'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ),
              ],
            ),

            SizedBox(height: 8),

            ElevatedButton(
              onPressed: _clearResults,
              child: Text('Clear Results'),
            ),

            SizedBox(height: 16),

            // Results List
            Expanded(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Detected Cards Log:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _detectedCards.length,
                          itemBuilder: (context, index) {
                            var card = _detectedCards[index];
                            return ListTile(
                              leading: Text('${index + 1}'),
                              title: Text('${card['cardType']}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ID: ${card['cardId']}'),
                                  Text(
                                      'Analysis: ${_analyzeCardType(card['cardType'])}'),
                                  Text(
                                      'Time: ${DateTime.fromMillisecondsSinceEpoch(card['timestamp']).toString().substring(11, 19)}'),
                                ],
                              ),
                              dense: true,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Instructions
            Container(
              padding: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.yellow[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Instructions:\n'
                '1. Initialize the RK3588S NFC hardware\n'
                '2. Try "Test Single Read" with door cards first\n'
                '3. Then try with bank cards\n'
                '4. Use "Start Continuous" to test multiple cards\n'
                '5. Check the analysis to see card type detection',
                style: TextStyle(fontSize: 12),
              ),
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

# IC Card Reader Integration Guide

This guide explains how to integrate your new IC card reader hardware with the modified nearpay Flutter SDK.

## Overview

The enhanced nearpay SDK now supports multiple hardware types:
- **IC Card Reader**: Direct serial communication with RFID/NFC card readers (M1/S50, NTAG213, etc.)
- **NearPay Cloud**: Original cloud-based payment processing
- **Android NFC**: Device's built-in NFC capability

## Hardware Detection

The SDK automatically detects available hardware and selects the best option:

```dart
// Auto-detect and initialize best hardware
var result = await Nearpay.autoInitializeHardware();
if (result['status'] == 200) {
  print('Hardware initialized: ${result['hardware_type']}');
}

// Manual hardware detection
var detection = await Nearpay.detectHardware();
List availableHardware = detection['available_hardware'];
for (var hw in availableHardware) {
  print('${hw['type']}: ${hw['available'] ? 'Available' : 'Unavailable'}');
}
```

## IC Card Reader Setup

### 1. Hardware Connection

Connect your IC card reader via USB/Serial:
- Common device paths: `/dev/ttyUSB0`, `/dev/ttyACM0`, `/dev/ttyS0`
- Default baud rate: 115200
- Supported cards: M1/S50, NTAG213, NTAG215, NTAG216

### 2. Initialize IC Card Reader

```dart
// Initialize with specific device path
var result = await Nearpay.initializeHardware(
  hardwareType: HardwareType.icCardReader.value,
  devicePath: '/dev/ttyUSB0', // Adjust as needed
);

// Or use auto-detection
var result = await Nearpay.autoInitializeHardware();
```

### 3. Reading Cards

```dart
// Single card read
await Nearpay.readCard();

// Continuous reading
await Nearpay.startCardReading();
// ... cards will be detected automatically
await Nearpay.stopCardReading();
```

### 4. Listen for Card Events

Set up method channel listeners for card events:

```dart
static const platform = MethodChannel('nearpay');

platform.setMethodCallHandler((call) async {
  switch (call.method) {
    case 'onCardDetected':
      var cardData = call.arguments;
      print('Card detected: ${cardData['card_data']['cardId']}');
      print('Card type: ${cardData['card_data']['cardType']}');
      break;
      
    case 'onCardError':
      print('Card error: ${call.arguments['error']}');
      break;
      
    case 'onReaderConnected':
      print('Card reader connected');
      break;
      
    case 'onReaderDisconnected':
      print('Card reader disconnected');
      break;
  }
});
```

## Hardware Switching

Switch between hardware types dynamically:

```dart
// Switch to IC card reader
await Nearpay.initializeHardware(
  hardwareType: HardwareType.icCardReader.value
);

// Switch to NearPay cloud for payments
await Nearpay.initializeHardware(
  hardwareType: HardwareType.nearpayCloud.value
);

// Then initialize NearPay as usual
var nearPayData = {
  "authtype": "email",
  "authvalue": "your_token",
  "locale": Locale.localeDefault.value,
  "environment": Environments.sandbox.value
};
await Nearpay.initialize(nearPayData);
```

## Error Handling

```dart
try {
  var result = await Nearpay.readCard();
  if (result['status'] != 200) {
    print('Error: ${result['message']}');
  }
} catch (e) {
  print('Exception: $e');
}
```

## Hardware Status Monitoring

```dart
var status = await Nearpay.getHardwareStatus();
print('Current hardware: ${status['current_hardware']}');

if (status['ic_reader_status'] != null) {
  var icStatus = status['ic_reader_status'];
  print('IC Reader connected: ${icStatus['connected']}');
  print('Device path: ${icStatus['devicePath']}');
}
```

## Integration Patterns

### Pattern 1: IC Card Reader + NearPay Payments

```dart
// Use IC card reader for card detection
await Nearpay.initializeHardware(hardwareType: HardwareType.icCardReader.value);
await Nearpay.startCardReading();

// When card detected, switch to NearPay for payment
platform.setMethodCallHandler((call) async {
  if (call.method == 'onCardDetected') {
    var cardId = call.arguments['card_data']['cardId'];
    
    // Switch to NearPay for payment processing
    await Nearpay.initializeHardware(hardwareType: HardwareType.nearpayCloud.value);
    await Nearpay.initialize(nearPayAuthData);
    
    // Process payment with detected card
    var paymentData = {
      "amount": 1000,
      "customer_reference_number": cardId,
      // ... other payment data
    };
    await Nearpay.purchase(paymentData);
  }
});
```

### Pattern 2: Fallback System

```dart
Future<void> initializeBestHardware() async {
  try {
    // Try IC card reader first
    var result = await Nearpay.initializeHardware(
      hardwareType: HardwareType.icCardReader.value
    );
    
    if (result['status'] == 200) {
      print('Using IC Card Reader');
      return;
    }
  } catch (e) {
    print('IC Card Reader failed: $e');
  }
  
  // Fallback to NearPay cloud
  await Nearpay.initializeHardware(
    hardwareType: HardwareType.nearpayCloud.value
  );
  await Nearpay.initialize(nearPayAuthData);
  print('Using NearPay Cloud');
}
```

## Troubleshooting

### Common Issues

1. **"IC Card Reader not found"**
   - Check USB connection
   - Verify device path (`ls /dev/tty*`)
   - Check permissions: `sudo chmod 666 /dev/ttyUSB0`

2. **"Permission denied"**
   - Add user to dialout group: `sudo usermod -a -G dialout $USER`
   - Restart application

3. **"Communication timeout"**
   - Check baud rate (default: 115200)
   - Verify hardware compatibility
   - Check cable quality

### Debug Information

Enable verbose logging:

```dart
var status = await Nearpay.getHardwareStatus();
print('Debug info: ${json.encode(status)}');

var detection = await Nearpay.detectHardware();
print('Available hardware: ${json.encode(detection['available_hardware'])}');
```

## Performance Considerations

- IC card reading adds ~500ms per scan
- Continuous reading uses background threads
- Always stop reading when not needed to save battery
- Hardware detection adds ~1-2s to initialization

## Android Permissions

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

For USB serial devices, add:

```xml
<uses-feature 
    android:name="android.hardware.usb.host"
    android:required="false" />
```

## Migration from Original NearPay

Existing code continues to work unchanged. New hardware detection is optional:

```dart
// Original code still works
await Nearpay.initialize(authData);
await Nearpay.purchase(paymentData);

// New hardware features are additive
await Nearpay.autoInitializeHardware(); // Optional enhancement
```
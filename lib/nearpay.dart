import 'package:flutter/services.dart';

enum Environments {
  sandbox("sandbox"),
  production("production");

  const Environments(this.value);
  final String value;
}

enum AuthenticationType {
  login("userenter"),
  email("email"),
  mobile("mobile"),
  jwt("jwt");

  const AuthenticationType(this.value);
  final String value;
}

enum Locale {
  localeDefault("default");

  const Locale(this.value);
  final String value;
}

enum HardwareType {
  icCardReader("IC_CARD_READER"),
  nearpayCloud("NEARPAY_CLOUD"),
  androidNfc("ANDROID_NFC");

  const HardwareType(this.value);
  final String value;
}

class Nearpay {
  static const MethodChannel methodChannel = MethodChannel('nearpay');

  static Future<dynamic> initialize(Map<dynamic, dynamic> data) async {
    final response =
        await methodChannel.invokeMethod<dynamic>('initialize', data);
    return response;
  }

  static Future<dynamic> purchase(Map<dynamic, dynamic> data) async {
    final response =
        await methodChannel.invokeMethod<dynamic>('purchase', data);
    return response;
  }

  static Future<dynamic> refund(Map<dynamic, dynamic> data) async {
    final response = await methodChannel.invokeMethod<dynamic>('refund', data);
    return response;
  }

  static Future<dynamic> reconcile(Map<dynamic, dynamic> data) async {
    final response =
        await methodChannel.invokeMethod<dynamic>('reconcile', data);
    return response;
  }

  static Future<dynamic> reverse(Map<dynamic, dynamic> data) async {
    final response = await methodChannel.invokeMethod<dynamic>('reverse', data);
    return response;
  }

  static Future<dynamic> logout() async {
    final response = await methodChannel.invokeMethod<dynamic>('logout');
    return response;
  }

  static Future<dynamic> close() async {
    final response = await methodChannel.invokeMethod<dynamic>('close');
    return response;
  }

  static Future<dynamic> setup() async {
    final response = await methodChannel.invokeMethod<dynamic>('setup');
    return response;
  }

  static Future<bool> dismiss() async {
    final response = await methodChannel.invokeMethod<dynamic>('dismiss');
    return response;
  }

  static Future<dynamic> session(Map<dynamic, dynamic> data) async {
    final response = await methodChannel.invokeMethod<dynamic>('session', data);
    return response;
  }

  static Future<dynamic> receiptToImage(Map<dynamic, dynamic> data) async {
    final response =
        await methodChannel.invokeMethod<dynamic>('receiptToImage', data);
    return response;
  }

  static Future<dynamic> updateAuthentication(
      Map<dynamic, dynamic> data) async {
    final response =
        await methodChannel.invokeMethod<dynamic>('updateAuthentication', data);
    return response;
  }

  static Future<dynamic> getTransactionsList({
    int page = 1,
    int limit = 30,
    DateTime? from,
    DateTime? to,
    String? customerReferenceNumber,
    bool? isReconciled,
    bool? isApproved,
  }) async {
    final data = {
      "page": page,
      "limit": limit,
      "startDate": from?.toIso8601String(),
      "endDate": to?.toIso8601String(),
      "customerReferenceNumber": customerReferenceNumber,
      "isReconciled": isReconciled,
      "isApproved": isApproved
    };
    final response =
        await methodChannel.invokeMethod<dynamic>('getTransactionsList', data);
    return response;
  }

  static Future<dynamic> getTransaction({
    required String transactionUuid,
    bool? enableReceiptUi,
    num? finishTimeOut,
  }) async {
    final data = {
      "transactionUuid": transactionUuid,
      "enableReceiptUi": enableReceiptUi,
      "finishTimeOut": finishTimeOut,
    };

    final response =
        await methodChannel.invokeMethod<dynamic>('getTransaction', data);
    return response;
  }

  static Future<dynamic> getReconciliationsList({
    int page = 1,
    int limit = 30,
    DateTime? from,
    DateTime? to,
  }) async {
    final data = {
      "page": page,
      "limit": limit,
      "startDate": from?.toIso8601String(),
      "endDate": to?.toIso8601String()
    };

    final response = await methodChannel.invokeMethod<dynamic>(
        'getReconciliationsList', data);
    return response;
  }

  static Future<dynamic> getReconciliation({
    required String reconciliationUuid,
    bool? enableReceiptUi,
    num? finishTimeOut,
  }) async {
    final data = {
      "reconciliationUuid": reconciliationUuid,
      "enableReceiptUi": enableReceiptUi,
      "finishTimeOut": finishTimeOut,
    };

    final response =
        await methodChannel.invokeMethod<dynamic>('getReconciliation', data);
    return response;
  }

  // ===== NEW HARDWARE METHODS =====

  /// Detect all available NFC/Card reading hardware
  static Future<dynamic> detectHardware() async {
    final response =
        await methodChannel.invokeMethod<dynamic>('detectHardware');
    return response;
  }

  /// Initialize specific hardware type
  /// [hardwareType]: 'IC_CARD_READER', 'NEARPAY_CLOUD', 'ANDROID_NFC'
  /// [devicePath]: Path to device (e.g., '/dev/ttyUSB0') - optional for IC card reader
  static Future<dynamic> initializeHardware({
    required String hardwareType,
    String? devicePath,
  }) async {
    final data = {
      "hardwareType": hardwareType,
      "devicePath": devicePath,
    };
    final response =
        await methodChannel.invokeMethod<dynamic>('initializeHardware', data);
    return response;
  }

  /// Read a single card using current hardware
  static Future<dynamic> readCard() async {
    final response = await methodChannel.invokeMethod<dynamic>('readCard');
    return response;
  }

  /// Start continuous card reading (IC Card Reader only)
  static Future<dynamic> startCardReading() async {
    final response =
        await methodChannel.invokeMethod<dynamic>('startCardReading');
    return response;
  }

  /// Stop card reading
  static Future<dynamic> stopCardReading() async {
    final response =
        await methodChannel.invokeMethod<dynamic>('stopCardReading');
    return response;
  }

  /// Get current hardware status and information
  static Future<dynamic> getHardwareStatus() async {
    final response =
        await methodChannel.invokeMethod<dynamic>('getHardwareStatus');
    return response;
  }

  /// Auto-initialize with best available hardware
  static Future<dynamic> autoInitializeHardware() async {
    final detectionResult = await detectHardware();

    if (detectionResult['status'] == 200) {
      List availableHardware = detectionResult['available_hardware'];

      // Find the best hardware in priority order
      for (var hardware in availableHardware) {
        if (hardware['available'] == true) {
          if (hardware['type'] == 'ic_card_reader') {
            return await initializeHardware(
                hardwareType: 'IC_CARD_READER',
                devicePath: hardware['devicePath']);
          }
        }
      }

      // Fallback to NearPay cloud
      return await initializeHardware(hardwareType: 'NEARPAY_CLOUD');
    }

    throw Exception('Hardware detection failed');
  }
}

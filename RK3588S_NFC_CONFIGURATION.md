# RK3588S Android Board NFC Configuration Guide

## Overview
This guide addresses NFC configuration on RK3588S Android boards where:
- Hardware NFC is connected and partially functional (door cards work)
- Android OS doesn't detect NFC properly (shows "not support NFC")
- Bank cards are not detected
- Need to integrate with nearpay SDK

## Understanding the Issue

### Hardware vs Software Detection
- **Hardware Level**: Your NFC module is connected and working (door cards respond)
- **OS Level**: Android doesn't recognize the NFC hardware properly
- **Application Level**: Bank cards use different protocols than door lock cards

### Card Type Differences
- **Door Lock Cards**: Usually low-frequency (125kHz) or simple RFID
- **Bank Cards**: High-frequency (13.56MHz) with encryption and security protocols
- **Different Protocols**: ISO14443 Type A/B, ISO15693, etc.

## Solution Approaches

### Option 1: Configure Android NFC Support (Recommended)
Configure the Android system to properly recognize your NFC hardware.

### Option 2: Direct Hardware Access (Alternative)
Bypass Android NFC and communicate directly with the hardware via our IC card reader implementation.

---

## Option 1: Android NFC Configuration

### Step 1: Enable NFC in Device Tree

Create or modify the device tree configuration:

```dts
// In your device tree file (e.g., rk3588s-board.dts)
&i2c1 {
    status = "okay";
    
    nfc@28 {
        compatible = "nxp,pn544";  // or your NFC chip
        reg = <0x28>;
        nxp,irq-gpio = <&gpio3 RK_PA6 GPIO_ACTIVE_HIGH>;
        nxp,ven-gpio = <&gpio3 RK_PA5 GPIO_ACTIVE_HIGH>;
        nxp,firm-gpio = <&gpio3 RK_PA4 GPIO_ACTIVE_HIGH>;
        interrupt-parent = <&gpio3>;
        interrupts = <RK_PA6 IRQ_TYPE_EDGE_RISING>;
        status = "okay";
    };
};

// For SPI-connected NFC
&spi2 {
    status = "okay";
    
    nfc@0 {
        compatible = "nxp,pn544-spi";  // or your NFC chip
        reg = <0>;
        spi-max-frequency = <10000000>;
        nxp,irq-gpio = <&gpio3 RK_PA6 GPIO_ACTIVE_HIGH>;
        nxp,ven-gpio = <&gpio3 RK_PA5 GPIO_ACTIVE_HIGH>;
        nxp,firm-gpio = <&gpio3 RK_PA4 GPIO_ACTIVE_HIGH>;
        interrupt-parent = <&gpio3>;
        interrupts = <RK_PA6 IRQ_TYPE_EDGE_RISING>;
        status = "okay";
    };
};
```

### Step 2: Kernel Configuration

Enable NFC in kernel config:
```bash
CONFIG_NFC=y
CONFIG_NFC_NCI=y
CONFIG_NFC_NCI_SPI=y
CONFIG_NFC_NCI_UART=y
CONFIG_NFC_PN544=y
CONFIG_NFC_PN544_I2C=y
CONFIG_NFC_PN544_MEI=y
```

### Step 3: Android Framework Configuration

#### 3.1 Add NFC Permissions
In `frameworks/native/data/etc/handheld_core_hardware.xml`:
```xml
<feature name="android.hardware.nfc" />
<feature name="android.hardware.nfc.hce" />
<feature name="android.hardware.nfc.hcef" />
```

#### 3.2 System Properties
Add to `system.prop` or `build.prop`:
```properties
# Enable NFC
ro.hardware.nfc_nci=nqx.default
ro.nfc.port=I2C
debug.nfc.fw_download=true
debug.nfc.se=true

# NFC chip specific (adjust for your chip)
ro.nfc.chip.vendor=nxp
ro.nfc.chip.model=pn544
```

#### 3.3 SELinux Policies
Add to `sepolicy/nfc.te`:
```
allow nfc device:chr_file { read write open ioctl getattr };
allow nfc nfc_device:chr_file { read write open ioctl getattr };
allow nfc sysfs:dir { search };
allow nfc sysfs:file { read write open getattr };
```

### Step 4: NFC HAL Configuration

Create `/vendor/etc/nfcee_access.xml`:
```xml
<resources>
    <access-rule>
        <filter>
            <package>com.android.nfc</package>
        </filter>
        <allow>true</allow>
    </access-rule>
</resources>
```

Create `/system/etc/nfc_features.xml`:
```xml
<resources xmlns:xliff="urn:oasis:names:tc:xliff:document:1.2">
    <bool-array name="antenna_available">
        <item>true</item>
    </bool-array>
    
    <string-array name="antenna_name">
        <item>Default</item>
    </string-array>
</resources>
```

---

## Option 2: Direct Hardware Access (IC Card Reader)

Since your hardware is working at the physical level, you can bypass Android NFC and use direct communication.

### Step 1: Identify Hardware Interface

Check your NFC module connection:
```bash
# Check I2C devices
sudo i2cdetect -y 1

# Check SPI devices  
ls /dev/spi*

# Check UART devices
ls /dev/tty*

# Check USB devices
lsusb
```

### Step 2: Configure IC Card Reader

Modify the IC card reader configuration for your RK3588S:

```java
// In IcCardSerialCommunication.java
private static final String[] RK3588S_DEVICE_PATHS = {
    "/dev/ttyS0",    // UART0
    "/dev/ttyS1",    // UART1  
    "/dev/ttyS2",    // UART2
    "/dev/ttyS3",    // UART3
    "/dev/ttyS4",    // UART4
    "/dev/ttyUSB0",  // USB-to-serial
    "/dev/ttyACM0",  // USB CDC ACM
    "/dev/i2c-0",    // I2C0 (if using I2C interface)
    "/dev/i2c-1",    // I2C1
    "/dev/spidev0.0", // SPI0
    "/dev/spidev1.0", // SPI1
};
```

### Step 3: Bank Card Protocol Support

Add support for bank card protocols:

```java
// Enhanced card type detection for bank cards
private String detectCardType(byte[] data) {
    if (data.length > 5) {
        int typeFlag = data[5] & 0xFF;
        
        // Check for bank card indicators
        if (isISO14443TypeA(data)) {
            return "ISO14443_TYPE_A"; // Most bank cards
        } else if (isISO14443TypeB(data)) {
            return "ISO14443_TYPE_B"; // Some bank cards
        } else if (isPaymentCard(data)) {
            return "PAYMENT_CARD";
        }
        
        // Original door card types
        switch (typeFlag) {
            case 0x01: return "M1_S50";
            case 0x02: return "NTAG213";
            case 0x08: return "DOOR_CARD_125KHZ";
            default: return "UNKNOWN";
        }
    }
    return "UNKNOWN";
}

private boolean isISO14443TypeA(byte[] response) {
    // Check for ISO14443 Type A indicators
    // This depends on your NFC module's response format
    return response.length >= 4 && 
           (response[0] == (byte)0x44 || response[0] == (byte)0x04);
}

private boolean isPaymentCard(byte[] response) {
    // Check for payment card specific patterns
    // EMV cards typically start with specific ATR sequences
    return response.length >= 6 && 
           response[0] == (byte)0x3B; // T=0 protocol indicator
}
```

---

## Testing and Validation

### Test 1: Hardware Detection
```bash
# Test NFC hardware detection
adb shell dumpsys nfc
adb shell service list | grep nfc
adb shell getprop | grep nfc
```

### Test 2: Direct Hardware Test
```dart
// Test with your existing IC card reader code
await Nearpay.detectHardware();
await Nearpay.initializeHardware(
    hardwareType: HardwareType.icCardReader.value,
    devicePath: '/dev/ttyS0' // Adjust for RK3588S
);
await Nearpay.readCard();
```

### Test 3: Different Card Types
```dart
platform.setMethodCallHandler((call) async {
  if (call.method == 'onCardDetected') {
    var cardData = call.arguments['card_data'];
    var cardType = cardData['cardType'];
    
    print('Card Type: $cardType');
    
    if (cardType.contains('PAYMENT') || cardType.contains('ISO14443')) {
      print('Bank card detected!');
      // Handle bank card processing
    } else if (cardType.contains('DOOR') || cardType.contains('M1')) {
      print('Door card detected!');
      // Handle door card processing  
    }
  }
});
```

---

## Recommendation

### For Your Use Case:

1. **Start with Option 2 (Direct Hardware Access)**:
   - Your hardware is already working
   - Faster implementation
   - No need to rebuild Android system
   - Can handle both door cards and bank cards

2. **Configure Bank Card Detection**:
   - Add ISO14443 protocol support
   - Implement EMV card detection
   - Handle different frequency ranges

3. **Test Incrementally**:
   ```dart
   // Step 1: Test current door card functionality
   await Nearpay.autoInitializeHardware();
   
   // Step 2: Test bank card detection with enhanced protocols
   await Nearpay.readCard(); // Try with bank card
   
   // Step 3: Integrate with payment processing
   // Use detected card data with nearpay payment functions
   ```

### Why This Approach:
- ✅ **No Android System Changes Required**
- ✅ **Works with your current hardware**
- ✅ **Supports both card types**
- ✅ **Faster development**
- ✅ **Better control over hardware**

The key insight is that you don't need Android OS-level NFC support if you can communicate directly with the hardware. Many embedded systems work this way for better control and reliability.

Would you like me to create specific configuration files for your RK3588S board or help you test the bank card detection with the IC card reader approach?
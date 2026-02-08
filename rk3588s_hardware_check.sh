#!/bin/bash

# RK3588S NFC Hardware Detection Script
# Run this on your Android device via ADB shell

echo "=== RK3588S NFC Hardware Detection ==="
echo "Date: $(date)"
echo ""

echo "1. Checking Android Board Info..."
echo "Board: $(getprop ro.board.platform)"
echo "Model: $(getprop ro.product.model)"
echo "Android Version: $(getprop ro.build.version.release)"
echo ""

echo "2. Checking UART Devices..."
echo "Available UART devices:"
ls -la /dev/tty* | grep -E "(ttyS|ttyRK|ttyAMA)" 2>/dev/null || echo "No UART devices found"
echo ""

echo "3. Checking I2C Devices..."
echo "Available I2C devices:"
ls -la /dev/i2c-* 2>/dev/null || echo "No I2C devices found"
echo ""

echo "4. Checking SPI Devices..."
echo "Available SPI devices:"
ls -la /dev/spidev* 2>/dev/null || echo "No SPI devices found"
echo ""

echo "5. Checking USB Serial Devices..." 
echo "Available USB serial devices:"
ls -la /dev/tty* | grep -E "(ttyUSB|ttyACM)" 2>/dev/null || echo "No USB serial devices found"
echo ""

echo "6. Checking Device Tree Info..."
echo "Device tree model:"
cat /proc/device-tree/model 2>/dev/null || echo "Cannot read device tree"
echo ""

echo "7. Checking Serial Driver Status..."
echo "Serial driver info:"
cat /proc/tty/driver/serial 2>/dev/null || echo "Cannot read serial driver info"
echo ""

echo "8. Testing Most Likely NFC Device Paths..."
LIKELY_PATHS="/dev/ttyS0 /dev/ttyS1 /dev/ttyRK0 /dev/i2c-0 /dev/i2c-1"

for path in $LIKELY_PATHS; do
    if [ -e "$path" ]; then
        echo "✓ $path exists"
        ls -la "$path"
        
        # Test read permission
        if [ -r "$path" ]; then
            echo "  - Read permission: OK"
        else
            echo "  - Read permission: DENIED"
        fi
        
        # Test write permission
        if [ -w "$path" ]; then
            echo "  - Write permission: OK"
        else
            echo "  - Write permission: DENIED"
        fi
        
    else
        echo "✗ $path does not exist"
    fi
    echo ""
done

echo "9. Checking Android NFC Status..."
echo "NFC feature in PackageManager:"
pm list features | grep nfc || echo "No NFC features found"
echo ""

echo "NFC system properties:"
getprop | grep nfc || echo "No NFC properties found"
echo ""

echo "10. Checking Permissions..."
echo "Current user: $(whoami)"
echo "Current groups: $(groups)"
echo ""

echo "11. Hardware-specific Commands..."
echo "Checking for RK3588S specific devices:"

# RK3588S specific checks
if [ -d "/sys/class/rockchip_hw" ]; then
    echo "✓ Rockchip hardware class found"
    ls -la /sys/class/rockchip_hw/ 2>/dev/null
else
    echo "✗ No Rockchip hardware class found"
fi
echo ""

# Check GPIO status (NFC often uses GPIO for control)
if [ -d "/sys/class/gpio" ]; then
    echo "GPIO status:"
    ls /sys/class/gpio/ | head -10
else
    echo "No GPIO class found"
fi
echo ""

echo "12. Test Recommendations..."
echo ""

if ls /dev/tty* | grep -E "(ttyS|ttyRK)" >/dev/null 2>&1; then
    echo "✓ UART devices found - try these for NFC communication"
    echo "  Recommended test order:"
    echo "  1. /dev/ttyS0 (most common)"
    echo "  2. /dev/ttyS1"  
    echo "  3. /dev/ttyRK0 (RK specific)"
    echo ""
fi

if ls /dev/i2c-* >/dev/null 2>&1; then
    echo "✓ I2C devices found - NFC module might be on I2C"
    echo "  Try I2C communication if UART fails"
    echo ""
fi

if [ ! -r "/dev/ttyS0" ] && [ -e "/dev/ttyS0" ]; then
    echo "⚠ Permission issue detected!"
    echo "  Run: chmod 666 /dev/ttyS0"
    echo "  Or add your app to dialout group"
    echo ""
fi

echo ""
echo "=== Summary ==="
echo "1. If UART devices exist: Use direct UART communication"
echo "2. If I2C devices exist: Try I2C protocol"
echo "3. If permission denied: Fix device permissions"
echo "4. Door cards working = hardware is functional"
echo "5. Android NFC not detected = normal for RK3588S custom builds"
echo ""
echo "Next step: Use the enhanced nearpay SDK with detected device paths"
echo "=== End of Report ==="
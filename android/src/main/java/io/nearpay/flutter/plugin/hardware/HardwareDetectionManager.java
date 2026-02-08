package io.nearpay.flutter.plugin.hardware;

import android.content.Context;
import android.util.Log;
import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.HashMap;

/**
 * Hardware Detection Manager
 * Detects available NFC/Card reading hardware
 */
public class HardwareDetectionManager {
    private static final String TAG = "HardwareDetection";
    
    public enum HardwareType {
        NEARPAY_CLOUD("nearpay_cloud"),
        IC_CARD_READER("ic_card_reader"),
        ANDROID_NFC("android_nfc"),
        UNKNOWN("unknown");
        
        private final String value;
        
        HardwareType(String value) {
            this.value = value;
        }
        
        public String getValue() {
            return value;
        }
    }
    
    public static class HardwareInfo {
        public HardwareType type;
        public String devicePath;
        public String description;
        public boolean available;
        public Map<String, Object> properties;
        
        public HardwareInfo(HardwareType type, String devicePath, String description) {
            this.type = type;
            this.devicePath = devicePath;
            this.description = description;
            this.available = false;
            this.properties = new HashMap<>();
        }
        
        public Map<String, Object> toMap() {
            Map<String, Object> map = new HashMap<>();
            map.put("type", type.getValue());
            map.put("devicePath", devicePath);
            map.put("description", description);
            map.put("available", available);
            map.put("properties", properties);
            return map;
        }
    }
    
    private Context context;
    
    public HardwareDetectionManager(Context context) {
        this.context = context;
    }
    
    /**
     * Detect all available hardware
     */
    public List<HardwareInfo> detectAllHardware() {
        List<HardwareInfo> hardwareList = new ArrayList<>();
        
        // Check for IC Card Reader (Serial devices)
        hardwareList.addAll(detectIcCardReaders());
        
        // Check for Android NFC
        hardwareList.add(detectAndroidNfc());
        
        // Always include NearPay Cloud option
        hardwareList.add(createNearpayCloudInfo());
        
        Log.i(TAG, "Detected " + hardwareList.size() + " hardware options");
        return hardwareList;
    }
    
    /**
     * Detect IC Card Readers via serial ports - optimized for RK3588S Android board
     */
    private List<HardwareInfo> detectIcCardReaders() {
        List<HardwareInfo> readers = new ArrayList<>();
        
        // RK3588S Android board specific paths
        String[] serialPaths = {
            // RK3588S UART interfaces (most likely for NFC)
            "/dev/ttyS0", "/dev/ttyS1", "/dev/ttyS2", "/dev/ttyS3", "/dev/ttyS4",
            "/dev/ttyRK0", "/dev/ttyRK1", "/dev/ttyRK2", "/dev/ttyRK3",
            
            // USB-to-serial adapters
            "/dev/ttyUSB0", "/dev/ttyUSB1", "/dev/ttyUSB2", "/dev/ttyUSB3",
            "/dev/ttyACM0", "/dev/ttyACM1", "/dev/ttyACM2", "/dev/ttyACM3",
            
            // I2C interfaces for NFC modules
            "/dev/i2c-0", "/dev/i2c-1", "/dev/i2c-2", "/dev/i2c-3", "/dev/i2c-4",
            
            // SPI interfaces
            "/dev/spidev0.0", "/dev/spidev1.0", "/dev/spidev2.0"
        };
        
        for (String path : serialPaths) {
            try {
                File device = new File(path);
                if (device.exists() && isDeviceAccessible(device)) {
                    HardwareInfo info = new HardwareInfo(
                        HardwareType.IC_CARD_READER,
                        path,
                        "IC Card Reader (" + path + ") - RK3588S Compatible"
                    );
                    info.available = true;
                    info.properties.put("supports", "M1/S50,NTAG213,NTAG215,NTAG216,ISO14443A,ISO14443B,EMV");
                    info.properties.put("communication", getInterfaceType(path));
                    info.properties.put("baudRate", getBaudRateForPath(path));
                    info.properties.put("board", "RK3588S");
                    
                    readers.add(info);
                    Log.i(TAG, "Found IC card reader at: " + path);
                }
            } catch (Exception e) {
                Log.w(TAG, "Error checking path " + path + ": " + e.getMessage());
            }
        }
        
        return readers;
    }
    
    /**
     * Check if device is accessible (RK3588S may have different permission requirements)
     */
    private boolean isDeviceAccessible(File device) {
        try {
            // For RK3588S, some devices might need special permission handling
            if (device.canRead() && device.canWrite()) {
                return true;
            }
            
            // Try to check if device exists in /sys for RK3588S
            String deviceName = device.getName();
            String sysPath = "/sys/class/tty/" + deviceName;
            File sysDevice = new File(sysPath);
            if (sysDevice.exists()) {
                Log.i(TAG, "Device " + deviceName + " found in /sys but may need permissions");
                return true;
            }
            
            return false;
        } catch (Exception e) {
            return false;
        }
    }
    
    /**
     * Determine interface type based on device path
     */
    private String getInterfaceType(String path) {
        if (path.contains("ttyS") || path.contains("ttyRK")) {
            return "UART/Serial";
        } else if (path.contains("ttyUSB") || path.contains("ttyACM")) {
            return "USB-Serial";
        } else if (path.contains("i2c")) {
            return "I2C";
        } else if (path.contains("spi")) {
            return "SPI";
        }
        return "Unknown";
    }
    
    /**
     * Get appropriate baud rate for device path
     */
    private int getBaudRateForPath(String path) {
        if (path.contains("i2c")) {
            return 400000; // I2C standard speed
        } else if (path.contains("spi")) {
            return 1000000; // SPI 1MHz
        } else {
            return 115200; // UART default
        }
    }
    
    /**
     * Detect Android NFC capability
     */
    private HardwareInfo detectAndroidNfc() {
        HardwareInfo info = new HardwareInfo(
            HardwareType.ANDROID_NFC,
            "system",
            "Android NFC"
        );
        
        try {
            // Check if device has NFC
            android.nfc.NfcAdapter nfcAdapter = android.nfc.NfcAdapter.getDefaultAdapter(context);
            if (nfcAdapter != null) {
                info.available = nfcAdapter.isEnabled();
                info.properties.put("enabled", nfcAdapter.isEnabled());
                info.properties.put("supported", true);
                Log.i(TAG, "Android NFC: " + (info.available ? "Available" : "Disabled"));
            } else {
                info.available = false;
                info.properties.put("supported", false);
                Log.i(TAG, "Android NFC: Not supported on this device");
            }
        } catch (Exception e) {
            Log.e(TAG, "Error detecting Android NFC: " + e.getMessage());
            info.available = false;
            info.properties.put("error", e.getMessage());
        }
        
        return info;
    }
    
    /**
     * Create NearPay Cloud info (always available if internet is present)
     */
    private HardwareInfo createNearpayCloudInfo() {
        HardwareInfo info = new HardwareInfo(
            HardwareType.NEARPAY_CLOUD,
            "cloud",
            "NearPay Cloud Service"
        );
        info.available = true; // Assume available, actual status checked during initialization
        info.properties.put("type", "cloud_service");
        info.properties.put("supports", "payment_processing");
        info.properties.put("requires", "internet,authentication");
        
        return info;
    }
    
    /**
     * Find the best available hardware option
     */
    public HardwareInfo getPreferredHardware() {
        List<HardwareInfo> allHardware = detectAllHardware();
        
        // Priority order: IC Card Reader -> Android NFC -> NearPay Cloud
        for (HardwareInfo hardware : allHardware) {
            if (hardware.available && hardware.type == HardwareType.IC_CARD_READER) {
                Log.i(TAG, "Preferred hardware: IC Card Reader at " + hardware.devicePath);
                return hardware;
            }
        }
        
        for (HardwareInfo hardware : allHardware) {
            if (hardware.available && hardware.type == HardwareType.ANDROID_NFC) {
                Log.i(TAG, "Preferred hardware: Android NFC");
                return hardware;
            }
        }
        
        // Fallback to NearPay Cloud
        for (HardwareInfo hardware : allHardware) {
            if (hardware.type == HardwareType.NEARPAY_CLOUD) {
                Log.i(TAG, "Fallback hardware: NearPay Cloud");
                return hardware;
            }
        }
        
        return null;
    }
    
    /**
     * Check if a specific hardware type is available
     */
    public boolean isHardwareAvailable(HardwareType type) {
        List<HardwareInfo> allHardware = detectAllHardware();
        
        for (HardwareInfo hardware : allHardware) {
            if (hardware.type == type && hardware.available) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * Get hardware by type
     */
    public List<HardwareInfo> getHardwareByType(HardwareType type) {
        List<HardwareInfo> result = new ArrayList<>();
        List<HardwareInfo> allHardware = detectAllHardware();
        
        for (HardwareInfo hardware : allHardware) {
            if (hardware.type == type) {
                result.add(hardware);
            }
        }
        
        return result;
    }
}
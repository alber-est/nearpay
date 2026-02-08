package io.nearpay.flutter.plugin.iccard;

import android.util.Log;
import java.io.*;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;

/**
 * Serial communication handler for IC Card Reader
 * Supports M1/S50 cards and NTAG213 tags
 */
public class IcCardSerialCommunication {
    private static final String TAG = "IcCardSerial";
    private static final int BAUD_RATE = 115200; // Default baud rate
    
    private FileInputStream serialInput;
    private FileOutputStream serialOutput;
    private String devicePath;
    private boolean isConnected = false;
    private ExecutorService executor = Executors.newSingleThreadExecutor();
    
    // Command constants for the IC card reader
    private static final byte[] CMD_GET_VERSION = {(byte)0xAA, (byte)0xBB, (byte)0x00, (byte)0x03, (byte)0x01, (byte)0x01, (byte)0x04};
    private static final byte[] CMD_READ_CARD = {(byte)0xAA, (byte)0xBB, (byte)0x00, (byte)0x03, (byte)0x01, (byte)0x02, (byte)0x05};
    private static final byte[] CMD_BEEP = {(byte)0xAA, (byte)0xBB, (byte)0x00, (byte)0x04, (byte)0x01, (byte)0x06, (byte)0x01, (byte)0x0B};
    
    public interface IcCardListener {
        void onCardDetected(String cardId, String cardType);
        void onError(String error);
        void onConnected();
        void onDisconnected();
    }
    
    private IcCardListener listener;
    
    public IcCardSerialCommunication(String devicePath) {
        this.devicePath = devicePath;
    }
    
    public void setListener(IcCardListener listener) {
        this.listener = listener;
    }
    
    public boolean connect() {
        try {
            // Try multiple device paths including RK3588S specific paths
            String[] possiblePaths = {
                devicePath,
                // RK3588S Android board specific paths
                "/dev/ttyS0",    // UART0 - most common for NFC
                "/dev/ttyS1",    // UART1
                "/dev/ttyS2",    // UART2 
                "/dev/ttyS3",    // UART3
                "/dev/ttyS4",    // UART4
                "/dev/ttyRK0",   // RK specific UART
                "/dev/ttyRK1",   // RK specific UART
                // Standard USB/serial paths
                "/dev/ttyUSB0",
                "/dev/ttyACM0",
                // I2C paths for RK3588S
                "/dev/i2c-0",
                "/dev/i2c-1",
                "/dev/i2c-2"
            };
            
            for (String path : possiblePaths) {
                try {
                    File device = new File(path);
                    if (device.exists()) {
                        serialInput = new FileInputStream(device);
                        serialOutput = new FileOutputStream(device);
                        this.devicePath = path;
                        isConnected = true;
                        
                        Log.i(TAG, "Connected to IC card reader at: " + path);
                        
                        // Start listening for data
                        startListening();
                        
                        if (listener != null) {
                            listener.onConnected();
                        }
                        
                        // Send initial version request
                        sendCommand(CMD_GET_VERSION);
                        
                        return true;
                    }
                } catch (Exception e) {
                    Log.w(TAG, "Could not connect to " + path + ": " + e.getMessage());
                }
            }
            
            Log.e(TAG, "No IC card reader found at any common path");
            return false;
            
        } catch (Exception e) {
            Log.e(TAG, "Error connecting to IC card reader: " + e.getMessage());
            if (listener != null) {
                listener.onError("Connection failed: " + e.getMessage());
            }
            return false;
        }
    }
    
    public void disconnect() {
        isConnected = false;
        try {
            if (serialInput != null) {
                serialInput.close();
            }
            if (serialOutput != null) {
                serialOutput.close();
            }
            executor.shutdown();
            
            if (listener != null) {
                listener.onDisconnected();
            }
            
        } catch (IOException e) {
            Log.e(TAG, "Error disconnecting: " + e.getMessage());
        }
    }
    
    public void readCard() {
        if (isConnected) {
            sendCommand(CMD_READ_CARD);
        }
    }
    
    public void beep() {
        if (isConnected) {
            sendCommand(CMD_BEEP);
        }
    }
    
    private void sendCommand(byte[] command) {
        if (!isConnected || serialOutput == null) {
            return;
        }
        
        try {
            serialOutput.write(command);
            serialOutput.flush();
            Log.d(TAG, "Sent command: " + bytesToHex(command));
        } catch (IOException e) {
            Log.e(TAG, "Error sending command: " + e.getMessage());
            if (listener != null) {
                listener.onError("Send command failed: " + e.getMessage());
            }
        }
    }
    
    private void startListening() {
        executor.submit(() -> {
            byte[] buffer = new byte[1024];
            while (isConnected && serialInput != null) {
                try {
                    int bytesRead = serialInput.read(buffer);
                    if (bytesRead > 0) {
                        byte[] data = new byte[bytesRead];
                        System.arraycopy(buffer, 0, data, 0, bytesRead);
                        processResponse(data);
                    }
                } catch (IOException e) {
                    if (isConnected) {
                        Log.e(TAG, "Error reading from device: " + e.getMessage());
                        if (listener != null) {
                            listener.onError("Read failed: " + e.getMessage());
                        }
                    }
                    break;
                }
            }
        });
    }
    
    private void processResponse(byte[] data) {
        Log.d(TAG, "Received data: " + bytesToHex(data));
        
        try {
            // Basic protocol parsing - adjust based on your hardware's actual protocol
            if (data.length >= 7 && data[0] == (byte)0xAA && data[1] == (byte)0xBB) {
                int cmdType = data[4];
                
                switch (cmdType) {
                    case 0x01: // Version response
                        String version = "V" + data[6] + "." + data[7];
                        Log.i(TAG, "IC Card Reader Version: " + version);
                        break;
                        
                    case 0x02: // Card read response
                        if (data.length >= 11) {
                            String cardId = extractCardId(data);
                            String cardType = detectCardType(data);
                            
                            if (listener != null && cardId != null) {
                                listener.onCardDetected(cardId, cardType);
                            }
                        }
                        break;
                        
                    case 0x06: // Beep response
                        Log.d(TAG, "Beep command executed");
                        break;
                        
                    default:
                        Log.w(TAG, "Unknown response type: " + cmdType);
                        break;
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Error processing response: " + e.getMessage());
            if (listener != null) {
                listener.onError("Response processing failed: " + e.getMessage());
            }
        }
    }
    
    private String extractCardId(byte[] data) {
        try {
            // Extract card ID from response data (adjust indices based on actual protocol)
            if (data.length >= 11) {
                StringBuilder cardId = new StringBuilder();
                for (int i = 6; i < 10; i++) {
                    cardId.append(String.format("%02X", data[i] & 0xFF));
                }
                return cardId.toString();
            }
        } catch (Exception e) {
            Log.e(TAG, "Error extracting card ID: " + e.getMessage());
        }
        return null;
    }
    
    private String detectCardType(byte[] data) {
        // Enhanced card type detection for RK3588S supporting bank cards
        if (data.length > 5) {
            // Check for ISO14443 Type A (most bank cards)
            if (isISO14443TypeA(data)) {
                return "BANK_CARD_ISO14443A";
            }
            
            // Check for ISO14443 Type B (some bank cards)
            if (isISO14443TypeB(data)) {
                return "BANK_CARD_ISO14443B";
            }
            
            // Check for EMV payment cards
            if (isEMVCard(data)) {
                return "EMV_PAYMENT_CARD";
            }
            
            // Check for door/access cards (125kHz)
            if (isLowFrequencyCard(data)) {
                return "DOOR_CARD_125KHZ";
            }
            
            int typeFlag = data[5] & 0xFF;
            switch (typeFlag) {
                case 0x01:
                    return "M1_S50";
                case 0x02:
                    return "NTAG213";
                case 0x03:
                    return "NTAG215";
                case 0x04:
                    return "NTAG216";
                case 0x08:
                    return "DOOR_CARD_125KHZ";
                case 0x44:
                case 0x04:
                    return "BANK_CARD_ISO14443A";
                case 0x50:
                    return "BANK_CARD_ISO14443B";
                default:
                    return "UNKNOWN";
            }
        }
        return "UNKNOWN";
    }
    
    private boolean isISO14443TypeA(byte[] data) {
        // ISO14443 Type A detection (most bank cards)
        if (data.length >= 4) {
            // Check for ATQA (Answer To Request Type A)
            return (data[0] == (byte)0x44 || data[0] == (byte)0x04) &&
                   (data.length >= 7); // Minimum response length
        }
        return false;
    }
    
    private boolean isISO14443TypeB(byte[] data) {
        // ISO14443 Type B detection
        if (data.length >= 4) {
            // Check for ATQB (Answer To Request Type B)
            return data[0] == (byte)0x50 && data.length >= 12;
        }
        return false;
    }
    
    private boolean isEMVCard(byte[] data) {
        // EMV payment card detection
        if (data.length >= 6) {
            // Look for EMV application identifiers
            return data[0] == (byte)0x6F || // FCI template
                   data[0] == (byte)0x84 || // DF name  
                   (data[0] == (byte)0x3B && data.length >= 10); // ATR for contact cards
        }
        return false;
    }
    
    private boolean isLowFrequencyCard(byte[] data) {
        // 125kHz door card detection
        if (data.length >= 5) {
            // Common 125kHz patterns
            return (data[0] == (byte)0xFD && data[1] == (byte)0x55) || // EM4100
                   (data[0] == (byte)0x1D && data.length == 5) ||       // HID Prox
                   (data[0] == (byte)0x00 && data[1] == (byte)0x00);    // Generic
        }
        return false;
    }
    
    private String bytesToHex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (byte b : bytes) {
            result.append(String.format("%02X ", b));
        }
        return result.toString().trim();
    }
    
    public boolean isConnected() {
        return isConnected;
    }
    
    public String getDevicePath() {
        return devicePath;
    }
}
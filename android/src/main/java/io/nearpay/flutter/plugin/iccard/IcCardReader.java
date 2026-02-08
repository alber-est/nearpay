package io.nearpay.flutter.plugin.iccard;

import android.content.Context;
import android.util.Log;
import java.util.Map;
import java.util.HashMap;

/**
 * IC Card Reader Interface
 * Provides a consistent API for interacting with various IC card readers
 */
public class IcCardReader {
    private static final String TAG = "IcCardReader";
    
    private Context context;
    private IcCardSerialCommunication serialComm;
    private IcCardListener cardListener;
    private boolean isInitialized = false;
    
    public interface IcCardListener {
        void onCardRead(Map<String, Object> cardData);
        void onError(String errorMessage, int errorCode);
        void onReaderConnected();
        void onReaderDisconnected();
    }
    
    public static class CardData {
        public static final String CARD_ID = "cardId";
        public static final String CARD_TYPE = "cardType";
        public static final String READ_TIME = "readTime";
        public static final String READER_TYPE = "readerType";
        public static final String SUCCESS = "success";
    }
    
    public static class ErrorCodes {
        public static final int CONNECTION_FAILED = 1001;
        public static final int READ_FAILED = 1002;
        public static final int NO_CARD_DETECTED = 1003;
        public static final int UNSUPPORTED_CARD = 1004;
        public static final int COMMUNICATION_ERROR = 1005;
    }
    
    public IcCardReader(Context context) {
        this.context = context;
    }
    
    public void setCardListener(IcCardListener listener) {
        this.cardListener = listener;
    }
    
    /**
     * Initialize the IC card reader with device path
     * @param devicePath Path to the serial device (e.g., "/dev/ttyUSB0")
     * @return true if initialization successful
     */
    public boolean initialize(String devicePath) {
        try {
            if (isInitialized) {
                disconnect();
            }
            
            serialComm = new IcCardSerialCommunication(devicePath);
            serialComm.setListener(new IcCardSerialCommunication.IcCardListener() {
                @Override
                public void onCardDetected(String cardId, String cardType) {
                    handleCardDetected(cardId, cardType);
                }
                
                @Override
                public void onError(String error) {
                    if (cardListener != null) {
                        cardListener.onError(error, ErrorCodes.COMMUNICATION_ERROR);
                    }
                }
                
                @Override
                public void onConnected() {
                    Log.i(TAG, "IC Card Reader connected successfully");
                    if (cardListener != null) {
                        cardListener.onReaderConnected();
                    }
                }
                
                @Override
                public void onDisconnected() {
                    Log.i(TAG, "IC Card Reader disconnected");
                    isInitialized = false;
                    if (cardListener != null) {
                        cardListener.onReaderDisconnected();
                    }
                }
            });
            
            boolean connected = serialComm.connect();
            if (connected) {
                isInitialized = true;
                Log.i(TAG, "IC Card Reader initialized successfully");
                return true;
            } else {
                if (cardListener != null) {
                    cardListener.onError("Failed to connect to IC card reader", ErrorCodes.CONNECTION_FAILED);
                }
                return false;
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Initialization failed: " + e.getMessage());
            if (cardListener != null) {
                cardListener.onError("Initialization failed: " + e.getMessage(), ErrorCodes.CONNECTION_FAILED);
            }
            return false;
        }
    }
    
    /**
     * Start reading cards continuously
     */
    public void startReading() {
        if (!isInitialized || serialComm == null) {
            if (cardListener != null) {
                cardListener.onError("Reader not initialized", ErrorCodes.CONNECTION_FAILED);
            }
            return;
        }
        
        // Start continuous reading
        new Thread(() -> {
            while (isInitialized && serialComm.isConnected()) {
                try {
                    serialComm.readCard();
                    Thread.sleep(500); // Read every 500ms
                } catch (InterruptedException e) {
                    Log.w(TAG, "Reading interrupted");
                    break;
                } catch (Exception e) {
                    Log.e(TAG, "Error during reading: " + e.getMessage());
                    if (cardListener != null) {
                        cardListener.onError("Reading failed: " + e.getMessage(), ErrorCodes.READ_FAILED);
                    }
                }
            }
        }).start();
    }
    
    /**
     * Read a single card
     */
    public void readSingleCard() {
        if (!isInitialized || serialComm == null) {
            if (cardListener != null) {
                cardListener.onError("Reader not initialized", ErrorCodes.CONNECTION_FAILED);
            }
            return;
        }
        
        serialComm.readCard();
    }
    
    /**
     * Trigger beep sound on the reader
     */
    public void beep() {
        if (isInitialized && serialComm != null) {
            serialComm.beep();
        }
    }
    
    /**
     * Disconnect from the card reader
     */
    public void disconnect() {
        if (serialComm != null) {
            serialComm.disconnect();
            serialComm = null;
        }
        isInitialized = false;
        Log.i(TAG, "IC Card Reader disconnected");
    }
    
    /**
     * Check if the reader is connected and initialized
     */
    public boolean isConnected() {
        return isInitialized && serialComm != null && serialComm.isConnected();
    }
    
    /**
     * Get device information
     */
    public Map<String, Object> getDeviceInfo() {
        Map<String, Object> info = new HashMap<>();
        info.put("initialized", isInitialized);
        info.put("connected", isConnected());
        info.put("devicePath", serialComm != null ? serialComm.getDevicePath() : null);
        info.put("readerType", "IC_SERIAL");
        return info;
    }
    
    private void handleCardDetected(String cardId, String cardType) {
        if (cardListener == null) {
            return;
        }
        
        try {
            Map<String, Object> cardData = new HashMap<>();
            cardData.put(CardData.CARD_ID, cardId);
            cardData.put(CardData.CARD_TYPE, cardType);
            cardData.put(CardData.READ_TIME, System.currentTimeMillis());
            cardData.put(CardData.READER_TYPE, "IC_SERIAL");
            cardData.put(CardData.SUCCESS, true);
            
            Log.i(TAG, "Card detected - ID: " + cardId + ", Type: " + cardType);
            
            // Trigger beep on successful read
            beep();
            
            cardListener.onCardRead(cardData);
            
        } catch (Exception e) {
            Log.e(TAG, "Error processing card data: " + e.getMessage());
            cardListener.onError("Error processing card: " + e.getMessage(), ErrorCodes.READ_FAILED);
        }
    }
    
    /**
     * Auto-detect and initialize the card reader
     */
    public boolean autoInitialize() {
        String[] commonPaths = {
            "/dev/ttyUSB0",
            "/dev/ttyUSB1", 
            "/dev/ttyACM0",
            "/dev/ttyACM1",
            "/dev/ttyS0",
            "/dev/ttyS1"
        };
        
        for (String path : commonPaths) {
            Log.d(TAG, "Trying to initialize with path: " + path);
            if (initialize(path)) {
                Log.i(TAG, "Successfully initialized with path: " + path);
                return true;
            }
        }
        
        Log.w(TAG, "Auto-initialization failed - no card reader found");
        return false;
    }
}
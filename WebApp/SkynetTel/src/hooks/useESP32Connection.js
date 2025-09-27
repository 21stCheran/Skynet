import { useState, useEffect, useRef } from "react";

/**
 * Custom hook for UDP-like WebSocket communication with ESP32
 * Handles connection management and message sending
 */
export const useESP32Connection = () => {
  const [isConnected, setIsConnected] = useState(false);
  const [connectionStatus, setConnectionStatus] = useState("Disconnected");
  const [receivedMessages, setReceivedMessages] = useState([]);
  const [esp32IP, setESP32IP] = useState("192.168.4.1");
  const [esp32Port, setESP32Port] = useState("14550");

  const socketRef = useRef(null);
  const reconnectTimeoutRef = useRef(null);

  // Connect via WebSocket bridge server (for UDP communication)
  const connect = async () => {
    try {
      setConnectionStatus("Connecting...");

      // Try WebSocket bridge first (if running websocket-udp-bridge.js)
      const wsUrl = `ws://localhost:14551`; // WebSocket bridge port

      socketRef.current = new WebSocket(wsUrl);

      socketRef.current.onopen = () => {
        setIsConnected(true);
        setConnectionStatus("Connected");
        addMessage("Connected to ESP32");
      };

      socketRef.current.onmessage = (event) => {
        const message = event.data;
        addMessage(`Received: ${message}`);
      };

      socketRef.current.onclose = () => {
        setIsConnected(false);
        setConnectionStatus("Disconnected");
        addMessage("Connection closed");

        // Auto-reconnect after 3 seconds
        reconnectTimeoutRef.current = setTimeout(() => {
          if (!isConnected) {
            connect();
          }
        }, 3000);
      };

      socketRef.current.onerror = (error) => {
        console.error("WebSocket error:", error);
        setConnectionStatus("Connection Error");
        addMessage("Connection error occurred");
      };
    } catch (error) {
      setConnectionStatus("Failed to Connect");
      addMessage(`Connection failed: ${error.message}`);
    }
  };

  // For UDP simulation - direct fetch to ESP32
  const sendUDPMessage = async (message) => {
    try {
      const response = await fetch(`http://${esp32IP}:${esp32Port}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ message }),
        timeout: 5000,
      });

      if (response.ok) {
        addMessage(`Sent: ${message}`);
        const responseText = await response.text();
        if (responseText) {
          addMessage(`Response: ${responseText}`);
        }
        return true;
      }
    } catch (error) {
      console.error("UDP send error:", error);
      addMessage(`Send failed: ${error.message}`);
      return false;
    }
  };

  const sendMessage = (message) => {
    if (socketRef.current && socketRef.current.readyState === WebSocket.OPEN) {
      socketRef.current.send(message);
      addMessage(`Sent: ${message}`);
      return true;
    } else {
      // Fallback to UDP simulation
      return sendUDPMessage(message);
    }
  };

  const disconnect = () => {
    if (reconnectTimeoutRef.current) {
      clearTimeout(reconnectTimeoutRef.current);
    }

    if (socketRef.current) {
      socketRef.current.close();
      socketRef.current = null;
    }

    setIsConnected(false);
    setConnectionStatus("Disconnected");
  };

  const addMessage = (message) => {
    const timestamp = new Date().toLocaleTimeString();
    setReceivedMessages((prev) => [
      { id: Date.now(), timestamp, message },
      ...prev.slice(0, 99), // Keep last 100 messages
    ]);
  };

  const clearMessages = () => {
    setReceivedMessages([]);
  };

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      disconnect();
    };
  }, []);

  return {
    isConnected,
    connectionStatus,
    receivedMessages,
    esp32IP,
    setESP32IP,
    esp32Port,
    setESP32Port,
    connect,
    disconnect,
    sendMessage,
    clearMessages,
  };
};

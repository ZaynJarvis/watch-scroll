#!/usr/bin/env python3
import os
import sys

# Add virtual environment to path if it exists
venv_path = os.path.join(os.path.dirname(__file__), 'venv', 'lib', 'python3.13', 'site-packages')
if os.path.exists(venv_path):
    sys.path.insert(0, venv_path)
import socket
import threading
import json
import time
from datetime import datetime

# Try to import pyautogui for Mac scrolling
try:
    import pyautogui
    PYAUTOGUI_AVAILABLE = True
    print("✅ PyAutoGUI available for Mac scrolling")
except ImportError:
    PYAUTOGUI_AVAILABLE = False
    print("⚠️  PyAutoGUI not available. Install with: pip install pyautogui")

# Try alternative using AppleScript
import subprocess

class WatchScrollerServer:
    def __init__(self, host='0.0.0.0', port=8888):
        self.host = host
        self.port = port
        self.server_socket = None
        self.running = False
        self.clients = []
        
    def log(self, message):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
    def start(self):
        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            
            self.log(f"🚀 Starting TCP server on {self.host}:{self.port}")
            self.server_socket.bind((self.host, self.port))
            self.server_socket.listen(5)
            self.running = True
            
            self.log(f"🎉 Server listening on {self.host}:{self.port}")
            self.log(f"📊 Waiting for connections...")
            
            while self.running:
                try:
                    client_socket, client_address = self.server_socket.accept()
                    self.log(f"✅ New connection from {client_address}")
                    
                    # Handle client in separate thread
                    client_thread = threading.Thread(
                        target=self.handle_client,
                        args=(client_socket, client_address)
                    )
                    client_thread.daemon = True
                    client_thread.start()
                    
                except Exception as e:
                    if self.running:
                        self.log(f"❌ Error accepting connection: {e}")
                        
        except Exception as e:
            self.log(f"❌ Failed to start server: {e}")
            
    def handle_client(self, client_socket, client_address):
        self.clients.append(client_socket)
        self.log(f"👋 Client {client_address} connected, total clients: {len(self.clients)}")
        
        try:
            while self.running:
                try:
                    # Receive data
                    data = client_socket.recv(1024)
                    if not data:
                        break
                        
                    # Try to parse as JSON (handle multiple newline-delimited messages)
                    try:
                        message_str = data.decode('utf-8')
                        
                        # Split messages by newline delimiter first, then handle any remaining concatenated messages
                        self.parse_and_handle_messages(message_str, client_socket, client_address)
                        
                    except UnicodeDecodeError as e:
                        self.log(f"⚠️  Unicode decode error from {client_address}: {e}")
                        
                except socket.timeout:
                    continue
                except Exception as e:
                    self.log(f"❌ Error handling client {client_address}: {e}")
                    break
                    
        except Exception as e:
            self.log(f"❌ Client handler error for {client_address}: {e}")
        finally:
            if client_socket in self.clients:
                self.clients.remove(client_socket)
            client_socket.close()
            self.log(f"👋 Client {client_address} disconnected, remaining clients: {len(self.clients)}")
    
    def parse_and_handle_messages(self, message_str, client_socket, client_address):
        """Parse multiple newline-delimited and/or concatenated JSON messages"""
        
        # First try to split by newlines (preferred delimiter)
        lines = message_str.strip().split('\n')
        
        for line in lines:
            line = line.strip()
            if not line:
                continue
                
            # Check if line contains multiple concatenated JSON objects
            if line.count('{') > 1:
                self.log(f"🔍 Found concatenated JSON in line: {line[:100]}...")
                self.parse_concatenated_json(line, client_socket, client_address)
            else:
                # Single JSON message
                try:
                    if line.startswith('{') and line.endswith('}'):
                        message = json.loads(line)
                        self.log(f"📦 Parsed JSON: {message}")
                        self.handle_message(message, client_socket, client_address)
                except json.JSONDecodeError as e:
                    self.log(f"⚠️  Invalid JSON: {e} - {line[:100]}")
    
    def parse_concatenated_json(self, message_str, client_socket, client_address):
        """Parse multiple concatenated JSON messages (fallback method)"""
        current_pos = 0
        while current_pos < len(message_str):
            try:
                # Try to find the end of a JSON object
                open_braces = 0
                json_end = -1
                
                for i in range(current_pos, len(message_str)):
                    if message_str[i] == '{':
                        open_braces += 1
                    elif message_str[i] == '}':
                        open_braces -= 1
                        if open_braces == 0:
                            json_end = i + 1
                            break
                
                if json_end == -1:
                    break
                
                # Extract and parse single JSON message
                single_json = message_str[current_pos:json_end]
                try:
                    message = json.loads(single_json)
                    self.log(f"📦 Parsed concatenated JSON: {message}")
                    self.handle_message(message, client_socket, client_address)
                except json.JSONDecodeError as e:
                    self.log(f"⚠️  Invalid concatenated JSON: {e} - {single_json[:100]}")
                
                current_pos = json_end
                
            except Exception as e:
                self.log(f"❌ Error parsing concatenated messages: {e}")
                break
            
    def handle_message(self, message, client_socket, client_address):
        """Handle parsed JSON messages with ultra-minimal format"""
        if not isinstance(message, dict):
            self.log(f"⚠️  Invalid message format from {client_address}: expected dict")
            return
        
        # Handle ultra-minimal format: "a"=action (int), "p"=pixels (int)
        action = message.get('a', message.get('action', 'unknown'))  # Support both old and new format
        
        # Silent processing for performance
        
        # Handle different actions (support both minimal and legacy formats)
        if action == 1 or action == "scroll":
            self.handle_scroll_minimal(message, client_socket, client_address)
        elif action == 2 or action == "requestStatus":
            self.handle_request_status(message, client_socket, client_address)
        elif action == 3 or action == "ping":
            self.handle_ping(message, client_socket, client_address)
        elif action == "setActive":
            self.handle_set_active(message, client_socket, client_address)
        elif action == "setSensitivity":
            self.handle_set_sensitivity(message, client_socket, client_address)
        else:
            self.log(f"❓ Unknown action '{action}' from {client_address}")
            
    def handle_scroll_minimal(self, message, client_socket, client_address):
        """Handle ultra-minimal scroll messages for maximum performance"""
        # Get pixels from minimal format "p" or legacy "pixels"
        pixels = message.get('p', message.get('pixels', 0))
        direction = "vertical"  # Always vertical for simplicity
        
        # Silent scrolling for performance
        
        # Actually perform the scroll on Mac
        self.perform_mac_scroll(pixels, direction)
            
    def handle_ping(self, message, client_socket, client_address):
        self.log(f"🏓 Ping received from {client_address}")
        response = {
            "action": "pong",
            "timestamp": time.time(),
            "server_time": datetime.now().isoformat()
        }
        self.send_response(response, client_socket, client_address)
        
    def handle_scroll(self, message, client_socket, client_address):
        pixels = message.get('pixels', 0)
        direction = message.get('direction', 'vertical')
        self.log(f"🖱️  Scroll command: {pixels} pixels {direction} from {client_address}")
        
        # Actually perform the scroll on Mac
        self.perform_mac_scroll(pixels, direction)
        
    def handle_set_active(self, message, client_socket, client_address):
        active = message.get('active', False)
        self.log(f"⚡ Set active: {active} from {client_address}")
        
    def handle_set_sensitivity(self, message, client_socket, client_address):
        sensitivity = message.get('sensitivity', 1.0)
        self.log(f"🎚️  Set sensitivity: {sensitivity} from {client_address}")
        
    def handle_request_status(self, message, client_socket, client_address):
        self.log(f"📊 Status request from {client_address}")
        response = {
            "action": "statusResponse",
            "isConnected": True,
            "hasPermission": True,
            "isEnabled": True,
            "sensitivity": 1.0,
            "timestamp": time.time(),
            "server_info": f"Python test server on {self.host}:{self.port}"
        }
        self.send_response(response, client_socket, client_address)
        
    def send_response(self, response, client_socket, client_address):
        try:
            response_json = json.dumps(response)
            response_bytes = response_json.encode('utf-8')
            client_socket.send(response_bytes)
            self.log(f"📤 Sent response to {client_address}: {response_json}")
        except Exception as e:
            self.log(f"❌ Failed to send response to {client_address}: {e}")
    
    def perform_mac_scroll(self, pixels, direction):
        """Ultra-smooth trackpad-like scrolling"""
        try:
            # Trackpad-like conversion: smaller units, more responsive
            # Positive pixels = scroll down, negative = scroll up
            scroll_units = max(1, min(3, abs(int(pixels / 60))))  # Trackpad-like: divide by 60, max 3 units
            
            if pixels > 0:
                # Scroll down (positive)
                scroll_direction = -scroll_units  # PyAutoGUI: negative = down
            else:
                # Scroll up (negative)  
                scroll_direction = scroll_units   # PyAutoGUI: positive = up
            
            if PYAUTOGUI_AVAILABLE:
                # Use PyAutoGUI for scrolling - silent for performance
                if direction == "vertical":
                    pyautogui.scroll(scroll_direction)
                else:
                    pyautogui.hscroll(scroll_direction)
            else:
                # Use AppleScript as fallback
                if direction == "vertical":
                    # AppleScript scroll - negative Y = scroll up
                    script = f'''
                    tell application "System Events"
                        tell process "Safari" to set frontmost to true
                        key code 125 using {{}}
                    end tell
                    ''' if scroll_direction < 0 else f'''
                    tell application "System Events"
                        tell process "Safari" to set frontmost to true  
                        key code 126 using {{}}
                    end tell
                    '''
                else:
                    script = f'''
                    tell application "System Events"
                        tell process "Safari" to set frontmost to true
                        key code 124 using {{}}
                    end tell
                    ''' if scroll_direction > 0 else f'''
                    tell application "System Events"
                        tell process "Safari" to set frontmost to true
                        key code 123 using {{}}
                    end tell
                    '''
                
                subprocess.run(['osascript', '-e', script], capture_output=True)
                
        except Exception as e:
            self.log(f"❌ Failed to perform Mac scroll: {e}")
            
    def stop(self):
        self.log("🛑 Stopping server...")
        self.running = False
        if self.server_socket:
            self.server_socket.close()
        for client in self.clients:
            try:
                client.close()
            except:
                pass
        self.log("✅ Server stopped")

if __name__ == "__main__":
    print("🧪 WatchScroller Python Test Server")
    print("===================================")
    
    server = WatchScrollerServer()
    
    try:
        server.start()
    except KeyboardInterrupt:
        print("\n")
        server.log("🔄 Received interrupt signal")
        server.stop()
    except Exception as e:
        server.log(f"💥 Unexpected error: {e}")
        server.stop()

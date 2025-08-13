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
import math
from datetime import datetime

# Try to import zeroconf for Bonjour service
try:
    from zeroconf import ServiceInfo, Zeroconf
    import socket as sock
    ZEROCONF_AVAILABLE = True
    print("✅ Zeroconf available for Bonjour service")
except ImportError:
    ZEROCONF_AVAILABLE = False
    print("⚠️  Zeroconf not available. Install with: pip install zeroconf")

# Try to import pyautogui for Mac scrolling
try:
    import pyautogui
    # Disable PyAutoGUI's automatic pause for smoother scrolling
    pyautogui.PAUSE = 0
    pyautogui.MINIMUM_DURATION = 0
    pyautogui.MINIMUM_SLEEP = 0
    PYAUTOGUI_AVAILABLE = True
    print("✅ PyAutoGUI available for Mac scrolling")
except ImportError:
    PYAUTOGUI_AVAILABLE = False
    print("⚠️  PyAutoGUI not available. Install with: pip install pyautogui")

# Try alternative using AppleScript
import subprocess

# Try to import requests for Supabase IP registration
try:
    import requests
    REQUESTS_AVAILABLE = True
    print("✅ Requests available for IP registration")
except ImportError:
    REQUESTS_AVAILABLE = False
    print("⚠️  Requests not available. Install with: pip install requests")

class WatchScrollerServer:
    def __init__(self, host='0.0.0.0', port=8888):
        self.host = host
        self.port = port
        self.server_socket = None
        self.running = False
        self.clients = []
        self.scroll_accumulator = 0  # Accumulate small scroll amounts
        self.last_scroll_time = 0
        self.last_direction = 0  # Track last scroll direction
        self.momentum = 0  # Current momentum value
        self.momentum_decay = 0.85  # Faster momentum decay to reduce stickiness
        self.scroll_history = []  # Recent scroll values for smoothing
        self.max_history = 3  # Reduce history for more responsive scrolling
        self.zeroconf = None
        self.service_info = None
        
        # Supabase IP registration
        self.supabase_url = "https://qeioxayacjcrbxbuqzef.functions.supabase.co"
        self.uuid = "zaynjarvis"
        
    def log(self, message):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"{timestamp} {message}")
    
    def register_bonjour_service(self):
        """Register Bonjour/mDNS service for auto-discovery"""
        if not ZEROCONF_AVAILABLE:
            self.log("⚠️  Zeroconf not available, skipping Bonjour registration")
            return
        
        try:
            # Get all available IP addresses
            local_ips = self.get_all_local_ips()
            hostname = socket.gethostname()
            
            self.log(f"📍 Available IPs: {local_ips}")
            
            # Create service info with all available IP addresses
            service_name = "WatchScroller._watchscroller._tcp.local."
            addresses = [socket.inet_aton(ip) for ip in local_ips if ip != "127.0.0.1"]
            
            if not addresses:
                self.log("❌ No valid IP addresses found for Bonjour")
                return
                
            self.service_info = ServiceInfo(
                "_watchscroller._tcp.local.",
                service_name,
                addresses=addresses,
                port=self.port,
                properties={
                    'version': '1.0',
                    'platform': 'mac',
                    'hostname': hostname,
                    'primary_ip': local_ips[0] if local_ips else 'unknown'
                }
            )
            
            # Register service on all interfaces
            self.zeroconf = Zeroconf()
            self.zeroconf.register_service(self.service_info)
            self.log(f"📡 Bonjour service registered: {service_name}")
            self.log(f"📍 Broadcasting on IPs: {local_ips} port {self.port}")
            self.log(f"📍 Interfaces: {[name for idx, name in socket.if_nameindex()]}")
            
        except Exception as e:
            self.log(f"❌ Failed to register Bonjour service: {e}")
            import traceback
            self.log(f"Stack trace: {traceback.format_exc()}")
    
    def register_ip_with_supabase(self):
        """Register IP address with Supabase for fallback service discovery"""
        if not REQUESTS_AVAILABLE:
            self.log("⚠️  Requests not available, skipping Supabase IP registration")
            return
        
        try:
            # Get the primary local IP address
            primary_ip = self.get_local_ip()
            if not primary_ip or primary_ip == "127.0.0.1":
                self.log("❌ No valid IP address found for Supabase registration")
                return
            
            # Prepare registration data
            registration_data = {
                "uuid": self.uuid,
                "ip": primary_ip
            }
            
            # Make POST request to register IP
            url = f"{self.supabase_url}/set-ip"
            headers = {"Content-Type": "application/json"}
            
            self.log(f"🌐 Registering IP with Supabase: {primary_ip}")
            response = requests.post(url, json=registration_data, headers=headers, timeout=10)
            
            if response.status_code == 200:
                self.log(f"✅ Successfully registered IP {primary_ip} with Supabase")
            else:
                self.log(f"❌ Failed to register IP with Supabase: HTTP {response.status_code}")
                self.log(f"Response: {response.text}")
                
        except requests.exceptions.RequestException as e:
            self.log(f"❌ Network error registering IP with Supabase: {e}")
        except Exception as e:
            self.log(f"❌ Failed to register IP with Supabase: {e}")
            import traceback
            self.log(f"Stack trace: {traceback.format_exc()}")
    
    def get_local_ip(self):
        """Get local IP address more reliably"""
        try:
            # Method 1: Connect to external server to get local IP
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            local_ip = s.getsockname()[0]
            s.close()
            return local_ip
        except:
            try:
                # Method 2: Try hostname resolution
                hostname = socket.gethostname()
                return socket.gethostbyname(hostname)
            except:
                # Method 3: Fallback to localhost
                return "127.0.0.1"
                
    def get_all_local_ips(self):
        """Get all local IP addresses for Bonjour registration"""
        import subprocess
        ips = []
        
        try:
            # Use ifconfig to get all IPs
            result = subprocess.run(['ifconfig'], capture_output=True, text=True)
            for line in result.stdout.split('\n'):
                if 'inet ' in line and '127.0.0.1' not in line:
                    # Extract IP address
                    parts = line.strip().split()
                    for i, part in enumerate(parts):
                        if part == 'inet' and i + 1 < len(parts):
                            ip = parts[i + 1]
                            if self.is_valid_ip(ip) and ip not in ips:
                                ips.append(ip)
        except:
            self.log("⚠️ Could not get interface IPs, using primary IP")
        
        # Get primary IP as fallback
        primary_ip = self.get_local_ip()
        if primary_ip and primary_ip != "127.0.0.1" and primary_ip not in ips:
            ips.insert(0, primary_ip)  # Put primary IP first
            
        # Ensure we have at least one IP
        if not ips:
            ips.append("127.0.0.1")
            
        return ips
    
    def is_valid_ip(self, ip):
        """Check if IP address is valid"""
        try:
            parts = ip.split('.')
            return len(parts) == 4 and all(0 <= int(part) <= 255 for part in parts)
        except:
            return False
    
    def unregister_bonjour_service(self):
        """Unregister Bonjour/mDNS service"""
        if self.zeroconf and self.service_info:
            try:
                self.zeroconf.unregister_service(self.service_info)
                self.zeroconf.close()
                self.log("📡 Bonjour service unregistered")
            except Exception as e:
                self.log(f"❌ Failed to unregister Bonjour service: {e}")
        
    def start(self):
        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            
            self.log(f"🚀 Starting TCP server on {self.host}:{self.port}")
            self.server_socket.bind((self.host, self.port))
            self.server_socket.listen(5)
            self.running = True
            
            # Register Bonjour service for auto-discovery
            self.register_bonjour_service()
            
            # Register IP with Supabase for fallback service discovery
            self.register_ip_with_supabase()
            
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
        
        # Send minimal acknowledgment to keep connection alive
        # Ultra-minimal response: just "ok" to confirm receipt
        try:
            ack_response = '{"s":"ok"}\n'.encode('utf-8')  # s=status, minimal format
            client_socket.send(ack_response)
        except Exception as e:
            self.log(f"❌ Failed to send scroll ack to {client_address}: {e}")
            
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
        """Ultra-smooth trackpad-like scrolling with momentum and direction filtering"""
        try:
            # Filter out extreme values (likely errors or noise)
            if abs(pixels) > 10000:
                return
            
            current_time = time.time()
            time_delta = current_time - self.last_scroll_time
            
            # Detect direction
            current_direction = 1 if pixels > 0 else -1
            
            # Filter out sudden direction changes (noise) - less aggressive for user's data
            # If direction suddenly changes and value is small, it's likely noise
            if self.last_direction != 0 and current_direction != self.last_direction:
                if abs(pixels) < 50:  # Reduced threshold - only filter very small noise
                    print(f"Filtered noise: {pixels}")
                    return
                else:
                    # Legitimate direction change - reset momentum
                    self.momentum = 0
                    self.scroll_history.clear()
            
            # Add to scroll history for smoothing
            self.scroll_history.append(pixels)
            if len(self.scroll_history) > self.max_history:
                self.scroll_history.pop(0)
            
            # Calculate smoothed value using weighted average
            if len(self.scroll_history) > 1:
                # Recent values have more weight
                weights = [0.1, 0.15, 0.2, 0.25, 0.3][-len(self.scroll_history):]
                smoothed_pixels = sum(v * w for v, w in zip(self.scroll_history, weights)) / sum(weights)
            else:
                smoothed_pixels = pixels
            
            # Apply acceleration curve based on user behavior analysis
            sign = 1 if smoothed_pixels > 0 else -1
            abs_pixels = abs(smoothed_pixels)
            
            # Optimized for user's scroll patterns with controlled slow scroll acceleration
            if abs_pixels < 900:  # Small movements - controlled response
                processed_pixels = 120
            elif abs_pixels < 2000:  # Medium speed - gentle acceleration
                processed_pixels = (abs_pixels / 100) * 25
            else:
                processed_pixels = math.sqrt(abs_pixels/100*100 + 500) * 10
            
            processed_pixels = sign * processed_pixels
            
            # Update momentum with speed-aware control to prevent rocket effect on slow scrolls
            if time_delta < 0.08:  # Fast scrolling - build momentum (increased threshold)
                # Drastically reduce momentum for slow scrolls to prevent rocket effect
                if abs_pixels < 900:  # Slow scrolls - minimal momentum
                    momentum_factor = 0.05  # Very low momentum for slow scrolls
                elif abs_pixels < 2000:  # Medium-slow - reduced momentum
                    momentum_factor = 0.08
                else:  # Fast speeds - normal momentum
                    momentum_factor = 0.20
                self.momentum = self.momentum * 0.6 + processed_pixels * momentum_factor
            else:
                # Faster momentum decay when scrolling stops, especially for slow scrolls
                decay_rate = 0.75 if abs_pixels < 100 else self.momentum_decay
                self.momentum *= decay_rate
                # Clear momentum if it's very small to prevent drift
                if abs(self.momentum) < 5:
                    self.momentum = 0
            
            # Significantly reduce momentum influence for slow scrolls
            if abs_pixels < 900:  # Slow scrolls - almost no momentum influence
                momentum_influence = 0.02
            elif abs_pixels < 2000:  # Medium-slow - minimal momentum
                momentum_influence = 0.05
            else:  # Fast speeds - normal momentum
                momentum_influence = 0.20
            final_scroll = processed_pixels + self.momentum * momentum_influence
            
            
            # # Perform the scroll immediately (no accumulator for smoother response)
            # # Speed-aware sensitivity to control slow scroll ending speed
            # if abs_pixels < 900:  # Slow scrolls - lower sensitivity to prevent rocket effect
            #     scroll_amount = int(final_scroll / 120)  # Reduced sensitivity for slow scrolls
            # elif abs_pixels < 2000:  # Medium-slow scrolls
            #     scroll_amount = int(final_scroll / 100)  # Moderate sensitivity
            # else:  # Medium to fast scrolls - normal sensitivity
            #     scroll_amount = int(final_scroll / 80)   # Normal sensitivity
            
            # PyAutoGUI uses inverted scrolling
            scroll_direction = -int(final_scroll/120)
            # Log result pixels for movement tracking
            # print(f"result: {scroll_direction:.1f}")
            
            if PYAUTOGUI_AVAILABLE and abs(scroll_direction) > 0.01:  # Minimum threshold
                if direction == "vertical":
                    pyautogui.scroll(scroll_direction)
                else:
                    pyautogui.hscroll(scroll_direction)
            elif not PYAUTOGUI_AVAILABLE and abs(scroll_direction) > 0.01:
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
            
            # Update state for all cases
            self.last_direction = current_direction
            self.last_scroll_time = current_time
                
        except Exception as e:
            self.log(f"❌ Failed to perform Mac scroll: {e}")
            
    def stop(self):
        self.log("🛑 Stopping server...")
        self.running = False
        
        # Unregister Bonjour service
        self.unregister_bonjour_service()
        
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

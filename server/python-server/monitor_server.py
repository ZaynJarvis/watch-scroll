#!/usr/bin/env python3
import socket
import threading
import json
import time
from datetime import datetime

class MessageMonitor:
    def __init__(self, port=8889):  # 使用不同端口避免冲突
        self.port = port
        self.connections = {}
        self.message_count = 0
        
    def log(self, message, client_id=None):
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        if client_id:
            print(f"[{timestamp}] [{client_id}] {message}")
        else:
            print(f"[{timestamp}] [SERVER] {message}")
            
    def start(self):
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(('0.0.0.0', self.port))
        server.listen(5)
        
        self.log(f"🎯 Message Monitor listening on port {self.port}")
        self.log("📊 Waiting for connections...")
        
        try:
            while True:
                client, addr = server.accept()
                client_id = f"{addr[0]}:{addr[1]}"
                self.connections[client_id] = client
                
                self.log(f"✅ NEW CONNECTION from {client_id}")
                
                # Handle in thread
                thread = threading.Thread(target=self.handle_client, args=(client, client_id))
                thread.daemon = True
                thread.start()
                
        except KeyboardInterrupt:
            self.log("🛑 Shutting down...")
            server.close()
            
    def handle_client(self, client, client_id):
        try:
            while True:
                data = client.recv(4096)
                if not data:
                    break
                    
                self.message_count += 1
                self.log(f"📨 Message #{self.message_count} ({len(data)} bytes)", client_id)
                
                try:
                    # Try to decode as text
                    text = data.decode('utf-8', errors='ignore')
                    self.log(f"📄 RAW: {repr(text)}", client_id)
                    
                    # Try to parse as JSON
                    try:
                        msg = json.loads(text)
                        self.log(f"📦 JSON: {json.dumps(msg, indent=2)}", client_id)
                        
                        # Send a test response
                        if msg.get('action') == 'requestStatus':
                            response = {
                                "action": "statusResponse", 
                                "isConnected": True,
                                "hasPermission": True,
                                "isEnabled": True,
                                "sensitivity": 1.0,
                                "timestamp": time.time(),
                                "monitor_info": "Python monitor response"
                            }
                            resp_json = json.dumps(response)
                            client.send(resp_json.encode('utf-8'))
                            self.log(f"📤 SENT: {resp_json}", client_id)
                            
                    except json.JSONDecodeError:
                        self.log(f"⚠️  Not JSON: {text[:100]}...", client_id)
                        
                except Exception as e:
                    self.log(f"❌ Decode error: {e}", client_id)
                    
        except Exception as e:
            self.log(f"❌ Connection error: {e}", client_id)
        finally:
            client.close()
            if client_id in self.connections:
                del self.connections[client_id]
            self.log(f"👋 Connection closed", client_id)

if __name__ == "__main__":
    print("📡 WatchScroller Message Monitor")
    print("================================")
    monitor = MessageMonitor()
    monitor.start()
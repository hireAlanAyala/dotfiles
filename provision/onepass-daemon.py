#!/usr/bin/env python3
"""
1Password CLI Daemon
Secure daemon for managing 1Password CLI sessions with socket-based API
"""

import json
import logging
import os
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Optional, Dict, Any

# Configuration
SOCKET_PATH = "/var/run/onepass/daemon.sock"
LOG_FILE = "/var/log/onepass/daemon.log"
PID_FILE = "/var/run/onepass/daemon.pid"

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class OnePasswordDaemon:
    def __init__(self):
        self.session_token: Optional[str] = None
        self.socket_path = SOCKET_PATH
        self.running = True
        self.last_activity = time.time()
        
    def check_op_cli(self) -> bool:
        """Check if 1Password CLI is available"""
        try:
            result = subprocess.run(['op', '--version'], 
                                  capture_output=True, text=True, timeout=5)
            return result.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return False
    
    def signin(self, account: str, email: str, secret_key: str, password: str) -> Dict[str, Any]:
        """Sign in to 1Password and store session token"""
        try:
            # First sign in 
            cmd = ['op', 'signin', account, email, secret_key, '--raw']
            
            # Use password from stdin for security
            result = subprocess.run(
                cmd,
                input=password,
                text=True,
                capture_output=True,
                timeout=30
            )
            
            if result.returncode != 0:
                logger.error(f"1Password signin failed: {result.stderr}")
                return {"status": "error", "message": f"Signin failed: {result.stderr}"}
            
            self.session_token = result.stdout.strip()
            logger.info("Successfully signed in to 1Password")
            return {"status": "success", "message": "Signed in successfully"}
            
        except subprocess.TimeoutExpired:
            return {"status": "error", "message": "Signin timeout"}
        except Exception as e:
            logger.error(f"Signin error: {e}")
            return {"status": "error", "message": str(e)}
    
    def get_item(self, item_name: str, field: Optional[str] = None) -> Dict[str, Any]:
        """Get item from 1Password"""
        if not self.session_token:
            return {"status": "error", "message": "Not signed in"}
        
        try:
            cmd = ['op', 'item', 'get', item_name]
            if field:
                cmd.extend(['--field', field])
            
            env = os.environ.copy()
            env['OP_SESSION'] = self.session_token
            
            result = subprocess.run(
                cmd,
                env=env,
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode != 0:
                logger.error(f"Get item failed: {result.stderr}")
                return {"status": "error", "message": f"Get item failed: {result.stderr}"}
            
            self.last_activity = time.time()
            return {"status": "success", "data": result.stdout.strip()}
            
        except subprocess.TimeoutExpired:
            return {"status": "error", "message": "Get item timeout"}
        except Exception as e:
            logger.error(f"Get item error: {e}")
            return {"status": "error", "message": str(e)}
    
    def list_items(self) -> Dict[str, Any]:
        """List items from 1Password"""
        if not self.session_token:
            return {"status": "error", "message": "Not signed in"}
        
        try:
            cmd = ['op', 'item', 'list', '--format=json']
            
            env = os.environ.copy()
            env['OP_SESSION'] = self.session_token
            
            result = subprocess.run(
                cmd,
                env=env,
                capture_output=True,
                text=True,
                timeout=15
            )
            
            if result.returncode != 0:
                return {"status": "error", "message": f"List items failed: {result.stderr}"}
            
            self.last_activity = time.time()
            items = json.loads(result.stdout)
            return {"status": "success", "data": items}
            
        except json.JSONDecodeError:
            return {"status": "error", "message": "Invalid JSON response"}
        except subprocess.TimeoutExpired:
            return {"status": "error", "message": "List items timeout"}
        except Exception as e:
            logger.error(f"List items error: {e}")
            return {"status": "error", "message": str(e)}
    
    def signout(self) -> Dict[str, Any]:
        """Sign out and clear session"""
        if self.session_token:
            try:
                env = os.environ.copy()
                env['OP_SESSION'] = self.session_token
                
                subprocess.run(['op', 'signout'], env=env, timeout=5)
            except:
                pass  # Ignore signout errors
            
            self.session_token = None
            logger.info("Signed out of 1Password")
        
        return {"status": "success", "message": "Signed out"}
    
    def handle_request(self, request_data: str) -> Dict[str, Any]:
        """Handle incoming requests"""
        try:
            request = json.loads(request_data)
            command = request.get('command')
            
            if command == 'signin':
                return self.signin(
                    request.get('account', ''),
                    request.get('email', ''),
                    request.get('secret_key', ''),
                    request.get('password', '')
                )
            elif command == 'get_item':
                return self.get_item(
                    request.get('item_name', ''),
                    request.get('field')
                )
            elif command == 'list_items':
                return self.list_items()
            elif command == 'signout':
                return self.signout()
            elif command == 'status':
                return {
                    "status": "success",
                    "signed_in": self.session_token is not None,
                    "last_activity": self.last_activity
                }
            else:
                return {"status": "error", "message": f"Unknown command: {command}"}
                
        except json.JSONDecodeError:
            return {"status": "error", "message": "Invalid JSON request"}
        except Exception as e:
            logger.error(f"Request handling error: {e}")
            return {"status": "error", "message": str(e)}
    
    def setup_socket(self):
        """Setup Unix domain socket"""
        # Create directory if it doesn't exist
        socket_dir = Path(self.socket_path).parent
        socket_dir.mkdir(parents=True, exist_ok=True)
        
        # Remove existing socket
        try:
            os.unlink(self.socket_path)
        except FileNotFoundError:
            pass
        
        # Create socket
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.bind(self.socket_path)
        
        # Set permissions (readable/writable by group)
        os.chmod(self.socket_path, 0o660)
        
        return sock
    
    def session_timeout_monitor(self):
        """Monitor for session timeout (30 minutes of inactivity)"""
        while self.running:
            if (self.session_token and 
                time.time() - self.last_activity > 1800):  # 30 minutes
                logger.info("Session timeout, signing out")
                self.signout()
            time.sleep(60)  # Check every minute
    
    def run(self):
        """Main daemon loop"""
        if not self.check_op_cli():
            logger.error("1Password CLI not found or not working")
            sys.exit(1)
        
        logger.info("Starting 1Password daemon")
        
        # Write PID file
        Path(PID_FILE).parent.mkdir(parents=True, exist_ok=True)
        with open(PID_FILE, 'w') as f:
            f.write(str(os.getpid()))
        
        try:
            sock = self.setup_socket()
            sock.listen(5)
            
            # Start session timeout monitor
            timeout_thread = threading.Thread(target=self.session_timeout_monitor)
            timeout_thread.daemon = True
            timeout_thread.start()
            
            logger.info(f"Daemon listening on {self.socket_path}")
            
            while self.running:
                try:
                    conn, addr = sock.accept()
                    
                    with conn:
                        data = conn.recv(4096).decode('utf-8')
                        if data:
                            response = self.handle_request(data)
                            conn.send(json.dumps(response).encode('utf-8'))
                            
                except KeyboardInterrupt:
                    logger.info("Received interrupt signal")
                    self.running = False
                except Exception as e:
                    logger.error(f"Socket error: {e}")
                    
        except Exception as e:
            logger.error(f"Failed to start daemon: {e}")
            sys.exit(1)
        finally:
            self.cleanup()
    
    def cleanup(self):
        """Cleanup resources"""
        logger.info("Cleaning up daemon")
        
        # Sign out
        self.signout()
        
        # Remove socket
        try:
            os.unlink(self.socket_path)
        except FileNotFoundError:
            pass
        
        # Remove PID file
        try:
            os.unlink(PID_FILE)
        except FileNotFoundError:
            pass


if __name__ == "__main__":
    daemon = OnePasswordDaemon()
    daemon.run()
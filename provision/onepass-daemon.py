#!/usr/bin/env python3
"""
1Password CLI Daemon
Secure daemon for managing 1Password CLI sessions with service account authentication
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
SERVICE_ACCOUNT_TOKEN_FILE = "/opt/onepass/service-account-token"

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
        self.service_account_token: Optional[str] = None
        self.socket_path = SOCKET_PATH
        self.running = True
        self.last_activity = time.time()
        self.authenticated = False
        
    def check_op_cli(self) -> bool:
        """Check if 1Password CLI is available"""
        try:
            result = subprocess.run(['op', '--version'], 
                                  capture_output=True, text=True, timeout=5)
            return result.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return False
    
    def load_service_account_token(self) -> bool:
        """Load service account token from file"""
        try:
            if os.path.exists(SERVICE_ACCOUNT_TOKEN_FILE):
                with open(SERVICE_ACCOUNT_TOKEN_FILE, 'r') as f:
                    self.service_account_token = f.read().strip()
                    if self.service_account_token:
                        logger.info("Service account token loaded successfully")
                        return True
            logger.error(f"Service account token file not found: {SERVICE_ACCOUNT_TOKEN_FILE}")
            return False
        except Exception as e:
            logger.error(f"Failed to load service account token: {e}")
            return False
    
    def validate_service_account(self) -> bool:
        """Validate service account token with 1Password CLI"""
        if not self.service_account_token:
            return False
        
        try:
            env = os.environ.copy()
            env['OP_SERVICE_ACCOUNT_TOKEN'] = self.service_account_token
            
            # Test the service account by listing vaults
            result = subprocess.run(
                ['op', 'vault', 'list', '--format=json'],
                env=env,
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                logger.info("Service account validation successful")
                self.authenticated = True
                return True
            else:
                logger.error(f"Service account validation failed: {result.stderr}")
                return False
                
        except Exception as e:
            logger.error(f"Service account validation error: {e}")
            return False
    
    def signin(self, account: str = None, email: str = None, secret_key: str = None, password: str = None) -> Dict[str, Any]:
        """Service account authentication (no longer supports interactive signin)"""
        # This method is kept for backward compatibility but will always use service account
        if self.authenticated:
            return {"status": "success", "message": "Already authenticated with service account"}
        
        # Attempt to authenticate with service account
        if self.validate_service_account():
            return {"status": "success", "message": "Authenticated with service account"}
        else:
            return {"status": "error", "message": "Service account authentication failed. Please check token configuration."}
    
    def get_item(self, item_name: str, field: Optional[str] = None, vault: Optional[str] = None) -> Dict[str, Any]:
        """Get item from 1Password using service account"""
        if not self.authenticated:
            return {"status": "error", "message": "Not authenticated"}
        
        if not self.service_account_token:
            return {"status": "error", "message": "Service account token not available"}
        
        try:
            cmd = ['op', 'item', 'get', item_name]
            if field:
                cmd.extend(['--field', field])
            if vault:
                cmd.extend(['--vault', vault])
            
            env = os.environ.copy()
            env['OP_SERVICE_ACCOUNT_TOKEN'] = self.service_account_token
            
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
    
    def list_items(self, vault: Optional[str] = None, categories: Optional[str] = None) -> Dict[str, Any]:
        """List items from 1Password using service account"""
        if not self.authenticated:
            return {"status": "error", "message": "Not authenticated"}
        
        if not self.service_account_token:
            return {"status": "error", "message": "Service account token not available"}
        
        try:
            cmd = ['op', 'item', 'list', '--format=json']
            if vault:
                cmd.extend(['--vault', vault])
            if categories:
                cmd.extend(['--categories', categories])
            
            env = os.environ.copy()
            env['OP_SERVICE_ACCOUNT_TOKEN'] = self.service_account_token
            
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
        """Sign out (service accounts don't need explicit signout)"""
        # Service accounts don't require signout, but we'll clear the authenticated flag
        self.authenticated = False
        logger.info("Cleared authentication state")
        return {"status": "success", "message": "Authentication state cleared"}
    
    def list_vaults(self) -> Dict[str, Any]:
        """List available vaults using service account"""
        if not self.authenticated:
            return {"status": "error", "message": "Not authenticated"}
        
        if not self.service_account_token:
            return {"status": "error", "message": "Service account token not available"}
        
        try:
            cmd = ['op', 'vault', 'list', '--format=json']
            
            env = os.environ.copy()
            env['OP_SERVICE_ACCOUNT_TOKEN'] = self.service_account_token
            
            result = subprocess.run(
                cmd,
                env=env,
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode != 0:
                return {"status": "error", "message": f"List vaults failed: {result.stderr}"}
            
            self.last_activity = time.time()
            vaults = json.loads(result.stdout)
            return {"status": "success", "data": vaults}
            
        except json.JSONDecodeError:
            return {"status": "error", "message": "Invalid JSON response"}
        except subprocess.TimeoutExpired:
            return {"status": "error", "message": "List vaults timeout"}
        except Exception as e:
            logger.error(f"List vaults error: {e}")
            return {"status": "error", "message": str(e)}
    
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
                    request.get('field'),
                    request.get('vault')
                )
            elif command == 'list_items':
                return self.list_items(
                    request.get('vault'),
                    request.get('categories')
                )
            elif command == 'signout':
                return self.signout()
            elif command == 'status':
                return {
                    "status": "success",
                    "authenticated": self.authenticated,
                    "auth_type": "service_account",
                    "last_activity": self.last_activity
                }
            elif command == 'list_vaults':
                return self.list_vaults()
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
        """Monitor for service account validity"""
        while self.running:
            # Service accounts don't timeout, but we can periodically validate
            if self.authenticated and time.time() - self.last_activity > 3600:  # 1 hour
                logger.debug("Validating service account token")
                if not self.validate_service_account():
                    logger.error("Service account validation failed")
                    self.authenticated = False
            time.sleep(300)  # Check every 5 minutes
    
    def run(self):
        """Main daemon loop"""
        if not self.check_op_cli():
            logger.error("1Password CLI not found or not working")
            sys.exit(1)
        
        # Load and validate service account token
        if not self.load_service_account_token():
            logger.error("Failed to load service account token")
            sys.exit(1)
        
        if not self.validate_service_account():
            logger.error("Service account validation failed")
            sys.exit(1)
        
        logger.info("Starting 1Password daemon with service account authentication")
        
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
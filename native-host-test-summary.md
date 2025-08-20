# Native Messaging Host Test Summary

## Current Setup

### WSL Side (Linux)
- **Script Location**: `~/.npm-global/lib/node_modules/mcp-chrome-bridge/dist/run_host.sh`
- **Script Status**: ✓ Exists and is executable
- **Node.js Path**: `/nix/store/lz7iav1hd92jbv44zf2rdd7b2mj23536-nodejs-20.19.3/bin/node`
- **Node.js Status**: ✓ Found and working (v20.19.3)

### Windows Side
- **Manifest Location**: `C:\Users\AlanWalker\AppData\Local\Google\Chrome\User Data\NativeMessagingHosts\com.chromemcp.nativehost.json`
- **Manifest Status**: ✓ Created with correct format
- **Command**: `wsl.exe -e bash -c "cd ~/.npm-global/lib/node_modules/mcp-chrome-bridge/dist && ./run_host.sh"`

### Chrome Extension
- **Extension ID**: `hbdgbgagpkpjffpklnamcljpakneikee`
- **Allowed Origins**: `chrome-extension://hbdgbgagpkpjffpklnamcljpakneikee/`

## Test Results

1. **Script Accessibility**: ✓ Script is accessible and executable
2. **Node.js Availability**: ✓ Node.js is found and working
3. **WSL Environment**: ✓ All environment variables are set correctly
4. **Script Execution**: ✓ Script starts successfully and waits for input

## Testing Instructions

### From Windows PowerShell:
```powershell
# Run the PowerShell test script
powershell -ExecutionPolicy Bypass -File "\\wsl.localhost\Ubuntu\home\developer\.config\test-native-host.ps1"
```

### From Windows Command Prompt:
```batch
# Run the batch test script
\\wsl.localhost\Ubuntu\home\developer\.config\test-wsl-native-host.bat
```

### Manual Test:
```batch
# Test the exact command Chrome would use
wsl.exe -e bash -c "cd ~/.npm-global/lib/node_modules/mcp-chrome-bridge/dist && ./run_host.sh"
```

## Troubleshooting

If the native host doesn't work with Chrome:

1. **Check Chrome logs**: 
   - Navigate to `chrome://extensions/`
   - Enable "Developer mode"
   - Click "Inspect views: background page" for the extension
   - Check the console for errors

2. **Check native host logs**:
   - WSL: `~/.npm-global/lib/node_modules/mcp-chrome-bridge/dist/logs/`
   - Look for the most recent `native_host_wrapper_*.log` files

3. **Verify manifest registration**:
   - The manifest must be in the exact location Chrome expects
   - File must be valid JSON with proper escaping

4. **Common Issues**:
   - WSL not installed or not accessible from Windows
   - Path issues (spaces in paths, incorrect escaping)
   - Permission issues (script not executable)
   - Node.js not found in WSL environment

## Next Steps

1. Restart Chrome after creating the manifest
2. Install/reload the Chrome extension
3. Test the connection from the extension
4. Check logs if connection fails
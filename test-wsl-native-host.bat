@echo off
echo === Testing Native Messaging Host via WSL ===
echo.

echo Test 1: Basic WSL execution
wsl.exe -e echo "WSL is working"
echo.

echo Test 2: Test the exact command Chrome would use
echo Command: wsl.exe -e bash -c "cd ~/.npm-global/lib/node_modules/mcp-chrome-bridge/dist && ./run_host.sh"
echo.

echo Test 3: Running a quick test (will timeout after 5 seconds)
echo {"type":"test"} | timeout /t 5 wsl.exe -e bash -c "cd ~/.npm-global/lib/node_modules/mcp-chrome-bridge/dist && ./run_host.sh"
echo.

echo === Test Complete ===
pause
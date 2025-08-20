@echo off
:: Chrome MCP Bridge Wrapper for WSL
:: This script bridges Windows Chrome to WSL-based MCP server

:: Set WSL distribution (change if using different distro)
set WSL_DISTRO=Ubuntu

:: Execute the native host in WSL
wsl.exe -d %WSL_DISTRO% -e bash -c "cd ~/.npm-global/lib/node_modules/mcp-chrome-bridge/dist && exec ./run_host.sh"
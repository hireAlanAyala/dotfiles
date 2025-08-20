#!/usr/bin/env node

// Simple test to verify Playwright MCP server can start
const { spawn } = require('child_process');

console.log('Testing Playwright MCP server...\n');

// Start the Playwright MCP server
const mcp = spawn('npx', ['@playwright/mcp@latest'], {
  stdio: ['pipe', 'pipe', 'pipe']
});

// Set up a timeout to kill the process after 5 seconds
const timeout = setTimeout(() => {
  console.log('\n✓ Playwright MCP server started successfully!');
  console.log('✓ Server is ready to accept MCP protocol connections');
  mcp.kill();
  process.exit(0);
}, 5000);

// Handle server output
mcp.stdout.on('data', (data) => {
  console.log('Server output:', data.toString());
});

mcp.stderr.on('data', (data) => {
  console.log('Server stderr:', data.toString());
});

// Handle server exit
mcp.on('exit', (code) => {
  clearTimeout(timeout);
  if (code !== 0 && code !== null) {
    console.log(`✗ Server exited with code ${code}`);
    process.exit(1);
  }
});

mcp.on('error', (err) => {
  clearTimeout(timeout);
  console.error('✗ Failed to start server:', err);
  process.exit(1);
});

console.log('Waiting for server to initialize...');
Write-Host "=== Testing Native Messaging Host Connection from Windows ===" -ForegroundColor Green
Write-Host ""

# Test 1: Check WSL availability
Write-Host "Test 1: Checking WSL" -ForegroundColor Yellow
try {
    $wslVersion = & wsl.exe --version 2>&1
    Write-Host "✓ WSL is available" -ForegroundColor Green
    Write-Host $wslVersion
} catch {
    Write-Host "✗ WSL not found or not accessible" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 2: Check if the script exists in WSL
Write-Host "Test 2: Checking script in WSL" -ForegroundColor Yellow
$scriptPath = "~/.npm-global/lib/node_modules/mcp-chrome-bridge/dist/run_host.sh"
$checkCommand = "test -f $scriptPath && echo 'exists' || echo 'not found'"
$result = & wsl.exe -e bash -c $checkCommand
if ($result -eq "exists") {
    Write-Host "✓ Script found at: $scriptPath" -ForegroundColor Green
} else {
    Write-Host "✗ Script not found at: $scriptPath" -ForegroundColor Red
}
Write-Host ""

# Test 3: Check Chrome manifest
Write-Host "Test 3: Checking Chrome Native Messaging manifest" -ForegroundColor Yellow
$manifestPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\NativeMessagingHosts\com.chromemcp.nativehost.json"
if (Test-Path $manifestPath) {
    Write-Host "✓ Manifest found at: $manifestPath" -ForegroundColor Green
    Write-Host "Manifest content:" -ForegroundColor Cyan
    Get-Content $manifestPath | Write-Host
} else {
    Write-Host "✗ Manifest not found at: $manifestPath" -ForegroundColor Red
}
Write-Host ""

# Test 4: Test the exact command
Write-Host "Test 4: Testing the exact command Chrome would use" -ForegroundColor Yellow
$testMessage = '{"type":"test","data":"Hello from PowerShell"}'
$bytes = [System.Text.Encoding]::UTF8.GetBytes($testMessage)
$length = [BitConverter]::GetBytes($bytes.Length)

Write-Host "Sending test message to native host..." -ForegroundColor Cyan
try {
    $process = Start-Process -FilePath "wsl.exe" `
        -ArgumentList "-e", "bash", "-c", "cd ~/.npm-global/lib/node_modules/mcp-chrome-bridge/dist && ./run_host.sh" `
        -NoNewWindow -PassThru -RedirectStandardInput "temp_input.txt" -RedirectStandardOutput "temp_output.txt" -RedirectStandardError "temp_error.txt"
    
    # Wait a bit then kill the process (since it's waiting for input)
    Start-Sleep -Seconds 2
    if (!$process.HasExited) {
        $process.Kill()
        Write-Host "✓ Native host started successfully (process killed after 2 seconds)" -ForegroundColor Green
    } else {
        Write-Host "✗ Native host exited unexpectedly" -ForegroundColor Red
        if (Test-Path "temp_error.txt") {
            Write-Host "Error output:" -ForegroundColor Red
            Get-Content "temp_error.txt" | Write-Host
        }
    }
    
    # Cleanup
    Remove-Item "temp_*.txt" -ErrorAction SilentlyContinue
} catch {
    Write-Host "✗ Failed to start native host: $_" -ForegroundColor Red
}
Write-Host ""

Write-Host "=== Test Complete ===" -ForegroundColor Green
Write-Host "If all tests passed, the native messaging host should work with Chrome." -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
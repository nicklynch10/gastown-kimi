# Ralph-Gastown Troubleshooting Guide

This guide addresses common issues encountered when setting up Ralph-Gastown.

## Quick Diagnostics

Run the diagnostic script first:

```powershell
.\scripts\ralph\ralph-prereq-check.ps1 -Verbose
```

---

## Kimi CLI Configuration Issues

### Kimi Authentication Errors

**Error Message:**
```
Authentication failed: Invalid API key
Unauthorized: 401
```

**Root Causes & Fixes:**

1. **Wrong API Key Source:**
   - Get key from: https://platform.moonshot.ai/ (not www.kimi.com)
   - Generate a new API key from the platform dashboard

2. **Missing or Incorrect Config:**

```powershell
# Option 1: Run Kimi's configure command
kimi configure

# Option 2: Set environment variable
$env:MOONSHOT_API_KEY = "your-api-key-here"

# Option 3: Create config file manually (most reliable)
$config = @"
default_model = "kimi-k2.5"

# REQUIRED: Your API key from platform.moonshot.ai
api_key = "YOUR_API_KEY_HERE"

# REQUIRED: API endpoint (use moonshot.ai, not kimi.com)
api_endpoint = "https://api.moonshot.ai/v1"

# Provider configuration
[providers.moonshot]
# ⚠️ CRITICAL: type must be "kimi" (not "moonshot") - this is the provider implementation type
type = "kimi"
base_url = "https://api.moonshot.ai/v1"
api_key = "YOUR_API_KEY_HERE"

# ⚠️ CRITICAL: Quotes REQUIRED for model names with dots
[models."kimi-k2.5"]
provider = "moonshot"
model = "kimi-k2.5"
max_context_size = 262144
"@

$configDir = "$env:USERPROFILE\.kimi"
if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force }
# Write without BOM (PowerShell 5.1 Out-File writes UTF-8-BOM which breaks TOML parsing)
[System.IO.File]::WriteAllText("$configDir\config.toml", $config, [System.Text.UTF8Encoding]::new($false))
Write-Host "Config created. Edit and add your API key from platform.moonshot.ai" -ForegroundColor Yellow
```

**Verification:**
```powershell
# Test the configuration
kimi --yolo --prompt "Hello, verify you are working"
```

---

### TOML Model Names with Dots

**Error Message:**
```
ValidationError: 3 validation errors for Config
models.kimi-k2.provider Field required
models.kimi-k2.model Field required
models.kimi-k2.max_context_size Field required
```

**Root Cause:** The TOML parser interprets `kimi-k2.5` as a nested table structure `kimi-k2` with key `5`.

**How TOML Parsing Works:**
```toml
# This TOML:
[models.kimi-k2.5]
provider = "moonshot"

# Is parsed as equivalent to:
[models.kimi-k2]
5 = null
provider = "moonshot"
```

**Fix:** Always quote model names containing dots:

```toml
# ❌ WRONG - TOML parses as nested table:
[models.kimi-k2.5]
provider = "moonshot"
model = "kimi-k2.5"

# ✅ CORRECT - TOML parses as single table name:
[models."kimi-k2.5"]
provider = "moonshot"
model = "kimi-k2.5"
max_context_size = 262144
```

**Complete Working Example:**
```toml
# %USERPROFILE%\.kimi\config.toml
default_model = "kimi-k2.5"
api_key = "sk-your-api-key-here"
api_endpoint = "https://api.moonshot.ai/v1"

[providers.moonshot]
type = "moonshot"
base_url = "https://api.moonshot.ai/v1"
api_key = "sk-your-api-key-here"

[models."kimi-k2.5"]
provider = "moonshot"
model = "kimi-k2.5"
max_context_size = 262144
```

**Location:** `~/.kimi/config.toml` or `%USERPROFILE%\.kimi\config.toml`

---

## PowerShell Issues

Run the diagnostic script first:

```powershell
.\scripts\ralph\ralph-prereq-check.ps1 -Verbose
```

---

## PowerShell Issues

### Special Character Parsing Errors

**Error Messages:**
```
At ralph-master.ps1:89 char:76 - The '<' operator is reserved for future use
At ralph-executor.ps1:205 char:70 - You must provide a value expression following the '%' operator
```

**Root Causes:**

1. **Redirection Operator Confusion**: PowerShell interprets `<` and `>` as redirection operators
2. **Format Operator Issues**: `%` is the format operator in PowerShell
3. **Encoding Problems**: Files may have incorrect encoding

**Solutions:**

```powershell
# 1. Check file encoding (should be UTF-8)
$file = Get-Content "scripts\ralph\ralph-master.ps1" -Raw
$bytes = [System.Text.Encoding]::UTF8.GetBytes($file)

# 2. Fix line endings
foreach ($file in Get-ChildItem scripts\ralph\*.ps1) {
    $content = Get-Content $file.FullName -Raw
    # Normalize line endings to CRLF
    $content = $content -replace "`r?`n", "`r`n"
    Set-Content $file.FullName $content -NoNewline
}

# 3. Verify scripts parse
try {
    $content = Get-Content "scripts\ralph\ralph-master.ps1" -Raw
    [scriptblock]::Create($content) | Out-Null
    Write-Host "Script parses correctly" -ForegroundColor Green
} catch {
    Write-Host "Parse error: $_" -ForegroundColor Red
}
```

### Here-String Termination Issues

**Error Message:**
```
Missing closing '}' in statement block
```

**Cause:** The closing `"@` must be at the **start of the line** with no whitespace before it.

**Example of Bad Code:**
```powershell
$prompt = @"
  Line 1
  Line 2
  "@  # WRONG - has whitespace before closing
```

**Example of Correct Code:**
```powershell
$prompt = @"
  Line 1
  Line 2
"@  # CORRECT - no whitespace before closing
```

### Execution Policy Restrictions

**Error Message:**
```
File cannot be loaded because running scripts is disabled on this system.
```

**Solutions:**

```powershell
# Option 1: Set for current user (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Option 2: Set for current process only
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Option 3: Bypass for single execution
powershell -ExecutionPolicy Bypass -File script.ps1

# Option 4: Unblock specific file
Unblock-File -Path script.ps1
```

### Line Ending Issues (CRLF vs LF)

**Symptoms:** Scripts fail to parse on Windows even though they look correct.

**Diagnose:**
```powershell
$file = Get-Content "script.ps1" -Raw
if ($file -match "`n" -and $file -notmatch "`r`n") {
    Write-Host "File has Unix line endings (LF)" -ForegroundColor Yellow
}
```

**Fix:**
```powershell
# Convert LF to CRLF
$content = Get-Content "script.ps1" -Raw
$content = $content -replace "(?<!`r)`n", "`r`n"
Set-Content "script.ps1" $content -NoNewline

# Or using Git
git config core.autocrlf true
git rm -rf --cached .
git reset --hard HEAD
```

---

## GT CLI Build Issues

### "BuiltProperly" Check Failure

**Error Message:**
```
ERROR: This binary was built with 'go build' directly
```

**Root Cause:** The gt binary requires specific ldflags to set version info at build time.

**Fix:** Use the provided build script or specify ldflags:

```powershell
# Option 1: Use the build script
.\scripts\build-gt.ps1

# Option 2: Build manually with ldflags
$env:VERSION="dev"
$env:COMMIT=$(git rev-parse --short HEAD)
$env:BUILD_TIME=$(Get-Date -Format "o")
go build -ldflags "-X github.com/steveyegge/gastown/internal/cmd.Version=$env:VERSION -X github.com/steveyegge/gastown/internal/cmd.Commit=$env:COMMIT -X github.com/steveyegge/gastown/internal/cmd.BuildTime=$env:BUILD_TIME -X github.com/steveyegge/gastown/internal/cmd.BuiltProperly=1" -o gt.exe ./cmd/gt
```

---

## Dependency Issues

### SQLite3 Not Found (Windows)

**Error Message:**
```
gt doctor: SQLite3 CLI not found
```

**Note:** SQLite3 is used by `gt doctor` for diagnostics. Ralph-Gastown core functionality works without it.

**Fix:**
```powershell
# Option 1: Using winget (recommended)
winget install SQLite.SQLite

# Option 2: Manual install
# 1. Download from https://sqlite.org/download.html
# 2. Download sqlite-tools-win32-x86-*.zip
# 3. Extract to C:\sqlite
# 4. Add C:\sqlite to PATH

# Verify
sqlite3 --version
```

---

### GT CLI Not Found

**Error Message:**
```
The term 'gt' is not recognized as the name of a cmdlet
```

**Diagnose:**
```powershell
# Check if gt is installed
Get-Command gt -ErrorAction SilentlyContinue

# Check Go bin directory
Test-Path "$env:USERPROFILE\go\bin\gt.exe"

# Check PATH
$env:PATH -split ";" | Select-String "go"
```

**Fix:**
```powershell
# Add Go bin to PATH for current session
$env:PATH += ";$env:USERPROFILE\go\bin"

# Add permanently
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*go\bin*") {
    [Environment]::SetEnvironmentVariable("PATH", "$userPath;$env:USERPROFILE\go\bin", "User")
}

# Restart PowerShell after changing PATH
```

### BD CLI Not Found

**Note:** Ralph works in **standalone mode** without `bd` CLI. If you see this warning but Ralph is functioning (creating beads, running executors), you can ignore it.

**If you need `bd` CLI:** Same solution as GT CLI (they install to the same location via `go install`).

**Standalone Mode (No `bd` required):**
- Beads stored as JSON in `.ralph/beads/*.json`
- All Ralph features work without `bd`
- Automatic fallback when `bd` is not available

### Kimi CLI Not Found

**Error Message:**
```
The term 'kimi' is not recognized as the name of a cmdlet
```

**Diagnose:**
```powershell
# Check Python installation
where python
where python3
where py

# Check if kimi is installed
python -m pip show kimi-cli
pip show kimi-cli
```

**Fix:**
```powershell
# Find where pip installs scripts
$pipLocation = python -m pip show kimi-cli | Select-String "Location"
# Scripts are usually in Python's Scripts directory

# Add Python Scripts to PATH
$pythonScripts = python -c "import site; print(site.USER_BASE + '\\Scripts')"
$env:PATH += ";$pythonScripts"

# Or reinstall with full path
python -m pip install --force-reinstall kimi-cli
```

### Windows Store Python Interference

**Symptoms:** `python` command opens Microsoft Store instead of running Python.

**Fix:**
```powershell
# Option 1: Disable app execution aliases
# Settings > Apps > Advanced app settings > App execution aliases
# Turn OFF "App Installer" for python.exe and python3.exe

# Option 2: Use specific Python path
& "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe" -m pip install kimi-cli

# Option 3: Use py launcher
py -m pip install kimi-cli
py -m kimi --version
```

---

## Path Handling Issues

### Working Directory Confusion

**Symptoms:** Scripts work when run from one directory but fail from another.

**Fix in Scripts:**
```powershell
# Always set explicit paths at start of script
$ScriptDir = $PSScriptRoot  # Directory where script is located
$ProjectRoot = Resolve-Path "$ScriptDir\..\.."  # Adjust as needed

# Or use absolute paths
$BeadsDir = Join-Path $ProjectRoot ".beads"

# Verify paths exist
if (-not (Test-Path $BeadsDir)) {
    throw "Beads directory not found: $BeadsDir"
}
```

### Mixed Path Separators

**Symptoms:** Paths like `C:\project/.beads/active` cause issues with some tools.

**Fix:**
```powershell
# Normalize paths
$path = Join-Path $ProjectRoot ".beads" "active"
$normalized = [System.IO.Path]::GetFullPath($path)
```

---

## Watchdog/Scheduler Issues

### Scheduled Task Access Denied

**Error Message:**
```
ERROR: Access is denied.
```

**Cause:** Creating scheduled tasks requires Administrator privileges.

**Fix:**
```powershell
# Run PowerShell as Administrator
# Right-click PowerShell icon -> Run as Administrator

# Then run setup
.\scripts\ralph\setup-watchdog.ps1
```

### Task Already Exists

**Error Message:**
```
ERROR: The task name "RalphWatchdog" already exists.
```

**Fix:**
```powershell
# Remove existing task
Unregister-ScheduledTask -TaskName "RalphWatchdog" -Confirm:$false

# Then re-run setup
.\scripts\ralph\setup-watchdog.ps1

# Or use the manage script
.\scripts\ralph\manage-watchdog.ps1 -Action restart
```

### Invalid Schedule Type

**Error Message:**
```
ERROR: Invalid schedule type.
```

**Cause:** Different Windows versions have slightly different schtasks syntax.

**Fix:** Use PowerShell cmdlets instead of schtasks.exe:
```powershell
# This is the modern approach (works on Win 10/11)
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File script.ps1"
$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "RalphWatchdog" -Action $Action -Trigger $Trigger -Settings $Settings -Force
```

---

## Bead Schema Issues

### Missing Required Fields

**Error Message:**
```
Bead missing required field: intent
Bead missing required field: dod.verifiers
```

**Fix:** Ensure your bead JSON includes:
```json
{
  "intent": "What needs to be done",
  "dod": {
    "verifiers": [
      {
        "name": "Verifier name",
        "command": "command to run",
        "expect": { "exit_code": 0 }
      }
    ]
  }
}
```

### Formula vs Bead Confusion

| Term | Description | Location | Format |
|------|-------------|----------|--------|
| Formula | Template for creating beads | `.beads/formulas/*.formula.toml` | TOML |
| Bead | Instance of work | `.beads/active/*.json` or via `bd` | JSON |
| Molecule | A formula with special properties | `.beads/formulas/mol-*.formula.toml` | TOML |

---

## Process Management Issues

### Server Processes Left Running (Port Conflicts)

**Symptoms:** 
- "Unable to connect" errors in verifiers
- Port 3000 (or other) already in use
- Multiple Node.js processes running from previous tests

**Diagnose:**
```powershell
# Find processes using port 3000
netstat -ano | findstr :3000

# List Node.js processes
Get-Process node -ErrorAction SilentlyContinue
```

**Fix - Immediate:**
```powershell
# Kill specific process by PID
taskkill /F /PID <PID>

# Kill all Node.js processes (use with caution)
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force
```

**Fix - Proper Process Lifecycle (Recommended):**
When starting servers in verifiers, always ensure cleanup:

```powershell
# CORRECT - Proper process lifecycle with cleanup:
$proc = Start-Process -FilePath "node" -ArgumentList "server.js" `
    -WindowStyle Hidden -PassThru
$procId = $proc.Id  # Save PID for cleanup

try {
    Start-Sleep 3  # Wait for server startup
    $response = Invoke-WebRequest -Uri "http://localhost:3000/api/health" `
        -UseBasicParsing -TimeoutSec 5
    # Verify response...
} finally {
    # MUST kill process even on failure
    Stop-Process -Id $procId -ErrorAction SilentlyContinue
}
```

**Fix - Dynamic Port Allocation (Best Practice):**
For tests, use dynamic ports to avoid conflicts:

```javascript
// In server.js - use PORT environment variable or random port
const PORT = process.env.PORT || 0;  // 0 = random available port
server.listen(PORT, () => {
    console.log(`Server on port ${server.address().port}`);
});
```

Then capture the actual port from output for verifiers.

---

## Kimi CLI Encoding Issues

### UnicodeEncodeError: 'charmap' codec can't encode character

**Error Message:**
```
UnicodeEncodeError: 'charmap' codec can't encode character '\u221a' in position 56
```

**Root Cause:** Kimi CLI uses the Rich console library which attempts to render Unicode characters (like checkmarks √) to a console configured for Windows code page 1252. This commonly happens when Jest or other tools output Unicode checkmarks.

**Impact:** Non-fatal - the underlying test execution succeeds, but output display fails. Ralph's executor timeout (300s) will catch this.

**Fix - Workarounds:**

1. **Set UTF-8 code page before running:**
```powershell
# In your verifier or before running Kimi
chcp 65001  # Set UTF-8 code page
$env:PYTHONIOENCODING = "utf-8"
```

2. **Configure PowerShell for UTF-8:**
```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING = "utf-8"
```

3. **Filter Unicode from test output:**
```json
{
  "name": "Run tests",
  "command": "npm test 2>&1 | ForEach-Object { $_ -replace '[\x00-\x1F\x7F-\x9F]', '' }",
  "timeout_seconds": 120
}
```

---

## Port Conflicts During Testing

**Symptoms:** Server start verifiers fail with "Unable to connect" because port is already in use.

**Root Cause:** Previous test runs or the Ralph watchdog may leave Node.js processes running. Windows doesn't automatically free ports when the parent PowerShell exits.

**Prevention - Best Practices:**

1. **Use Dynamic Ports in Tests:**
```javascript
// server.js
const PORT = process.env.PORT || 0;  // 0 = random available port
const server = app.listen(PORT, () => {
    const actualPort = server.address().port;
    console.log(`Server running on port ${actualPort}`);
    // Write port to file for verifiers to read
    require('fs').writeFileSync('.server-port', actualPort.toString());
});
```

2. **Implement Health Check Verifier:**
```json
{
  "name": "Server health check",
  "command": "$port=Get-Content .server-port; Invoke-WebRequest -Uri \"http://localhost:$port/health\" -UseBasicParsing",
  "timeout_seconds": 10
}
```

3. **Always Include Cleanup in Verifiers:**
See "Process Management Issues" section above for proper cleanup patterns.

---

## Ralph Mode Confusion

### Database vs Standalone Mode

**Symptoms:** 
- `ralph-executor-simple.ps1` fails with `-BeadId` parameter
- "bd CLI not found" errors
- Confusion about when `bd` CLI is required

**Explanation:**
Ralph has two execution modes:

| Mode | Parameter | Requires bd CLI | Use Case |
|------|-----------|-----------------|----------|
| Database | `-BeadId` | Yes | Production with beads database |
| Standalone | `-BeadFile` | No | Development, CI/CD, simple projects |

**Using Standalone Mode (Recommended for most users):**
```powershell
# Create bead JSON file
$bead = @{
    id = "my-feature"
    title = "Implement feature"
    intent = "Add new feature"
    dod = @{ verifiers = @(...) }
} | ConvertTo-Json -Depth 10
$bead | Out-File ".ralph/beads/my-bead.json"

# Run executor with -BeadFile (no bd CLI needed)
.\scripts\ralph\ralph-executor-simple.ps1 -BeadFile ".ralph/beads/my-bead.json"
```

**Note:** Ralph automatically detects and uses standalone mode when:
- `-BeadFile` parameter is provided
- `bd` CLI is not installed
- `-Standalone` switch is used

---

## Coverage Threshold Issues

### Coverage Below Threshold Errors

**Symptoms:** Jest coverage check fails with message like:
```
Jest: "global" coverage threshold for branches (80%) not met: 79.06%
```

**Root Cause:** Initial development often has uncovered error handling paths. Setting thresholds too high causes failures.

**Fix - Realistic Thresholds:**
For initial development, use lower thresholds:

```javascript
// jest.config.js
module.exports = {
  coverageThreshold: {
    global: {
      branches: 75,
      functions: 75,
      lines: 75,
      statements: 75
    }
  }
};
```

**Fix - Incremental Improvement:**
```javascript
// jest.config.js - start low, increase as coverage improves
module.exports = {
  coverageThreshold: {
    global: {
      branches: 75,    // Start here
      functions: 80,
      lines: 80,
      statements: 80
    }
  }
};
```

**Fix - Disable for Initial Development:**
```javascript
// jest.config.js - temporarily disable thresholds
module.exports = {
  // Remove or comment out coverageThreshold during initial development
  // Uncomment and tune after core functionality is complete
};
```

---

## Verification Issues

### Verifier Timeouts

**Symptoms:** Verifiers hang indefinitely.

**Fix:** Always specify a timeout:
```json
{
  "name": "Build project",
  "command": "go build ./...",
  "timeout_seconds": 120,
  "expect": { "exit_code": 0 }
}
```

### Verifier Exit Code Issues

**Symptoms:** Verifier passes but Ralph reports failure.

**Diagnose:**
```powershell
# Check what exit code the command actually returns
$command = "npm test"
Invoke-Expression $command
$LASTEXITCODE  # This is what Ralph checks
```

**Fix:** Check the actual exit code and update your expect:
```json
{
  "expect": { "exit_code": 0 }
}
```

---

## State Management Issues

### Bead State Corruption

**Symptoms:** Bead state is inconsistent or lost.

**Fix:** The standalone executor now includes transaction safety:
```powershell
# Use the standalone executor with transaction support
.\scripts\ralph\ralph-executor-standalone.ps1 -BeadFile my-bead.json -Standalone
```

### Lost Beads During Move

**Symptoms:** Bead disappears when being moved between directories.

**Cause:** Move operation was interrupted (crash, power loss, etc.).

**Fix:** The new standalone executor uses atomic operations:
1. Creates backup before move
2. Performs move
3. Removes backup on success
4. Restores from backup on failure

---

## Getting More Help

If issues persist:

1. **Enable Verbose Logging:**
   ```powershell
   .\scripts\ralph\ralph-executor-standalone.ps1 -Verbose
   ```

2. **Check Logs:**
   ```powershell
   Get-Content .ralph/logs/ralph-$(Get-Date -Format 'yyyy-MM-dd').log -Tail 50
   ```

3. **Run Full Validation:**
   ```powershell
   .\scripts\ralph\ralph-validate.ps1 -Detailed
   ```

4. **Check GitHub Issues:**
   - Gastown CLI: https://github.com/nicklynch10/gastown-cli
   - Beads CLI: Not available - Ralph works in standalone mode without it

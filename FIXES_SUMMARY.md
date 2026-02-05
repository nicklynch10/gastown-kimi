# Ralph-Gastown Fixes Summary

**Date:** 2026-02-04  
**Issues Fixed:** 10 critical/high priority issues from agent reports

---

## CRITICAL Fixes

### 1. Ralph Executor Kimi Invocation Hangs (FIXED)
**File:** `scripts/ralph/ralph-executor.ps1` (Line 44)  
**Issue:** Missing `--print` flag caused Kimi to enter interactive mode and hang indefinitely  
**Fix:** Changed `$KimiArgs = "--yolo"` to `$KimiArgs = "--yolo --print"`

### 2. Log Directory Path Resolution (FIXED)
**File:** `scripts/ralph/ralph-executor.ps1` (Lines 60-61)  
**Issue:** Used relative path `.ralph` which resolved incorrectly when invoked from different directories  
**Fix:** Changed to use `$PSScriptRoot` for script-relative path resolution:
```powershell
$ScriptRoot = Split-Path -Parent $PSScriptRoot
$LogDir = Join-Path (Join-Path $ScriptRoot ".ralph") "logs"
```

---

## HIGH PRIORITY Fixes

### 3. Bead Creation Missing DoD Structure (FIXED)
**File:** `scripts/ralph/ralph-master.ps1` (`Invoke-CreateBeadCommand`)  
**Issue:** Created beads with malformed JSON - DoD stored as markdown string instead of structured JSON object  
**Fix:** Rewrote function to build proper PowerShell object with nested structures:
- Proper `dod.verifiers` array
- Proper `constraints` object
- Proper `ralph_meta` object
- Uses `ConvertTo-Json -Depth 10` to preserve structure

### 4. gt.exe Detection on Windows (FIXED)
**File:** `scripts/ralph/ralph-master.ps1` (Multiple locations)  
**Issue:** Script looked for `gt` in PATH, not `gt.exe` on Windows  
**Fix:** Added Windows detection and `.exe` suffix:
```powershell
$gtCmd = if ($env:OS -eq "Windows_NT") { "gt.exe" } else { "gt" }
```
Applied to: prerequisites check, status command, create-bead, create-gate

---

## DOCUMENTATION Fixes

### 5. Kimi Config TOML Provider Type (FIXED)
**Files:** 
- `docs/guides/SETUP.md` (Line 237)
- `docs/guides/TROUBLESHOOTING.md` (Multiple locations)  
**Issue:** Documentation showed `type = "moonshot"` but Kimi CLI requires `type = "kimi"`  
**Fix:** Changed to `type = "kimi"` with explanatory comment

### 6. BOM in Generated Config (FIXED)
**Files:**
- `docs/guides/SETUP.md` (Line 251)
- `docs/guides/TROUBLESHOOTING.md` (Multiple locations)  
**Issue:** PowerShell 5.1 `Out-File -Encoding utf8` writes UTF-8-BOM which breaks TOML parsing  
**Fix:** Changed to BOM-free UTF-8 write method:
```powershell
[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
```

### 7. Live Test Directory Verifier (FIXED)
**File:** `scripts/ralph/test/ralph-live-test.ps1`  
**Issue:** Single quotes in verifier command prevented variable expansion (`'$TestDir'`)  
**Fix:** Changed to use double quotes for proper variable expansion

---

## DOCUMENTATION Enhancements

### 8. Windows-Specific Setup Section (ADDED)
**File:** `docs/guides/SETUP.md`  
**Added:**
- SQLite3 installation instructions (winget + manual)
- Tmux clarification - Ralph is pure PowerShell, tmux only needed for `gt mayor`
- `gt init` vs `gt install` clarification

### 9. Standalone Mode Clarification (ADDED)
**Files:**
- `docs/guides/SETUP.md`
- `docs/guides/TROUBLESHOOTING.md`
- `AGENTS.md`  
**Added:** Clear documentation that:
- `bd` CLI is OPTIONAL
- Ralph works in standalone mode with JSON files
- Automatic fallback when `bd` is not installed

### 10. Windows-Specific Notes (ADDED)
**File:** `AGENTS.md`  
**Added:**
- Critical configuration notes for Kimi CLI on Windows
- BOM-free UTF-8 encoding requirement
- Provider type must be "kimi" not "moonshot"
- Standalone mode documentation
- Windows-specific dependency notes

---

## Test Results

All tests pass after fixes:

```
System Tests:  60 passed, 0 failed, 1 skipped
Live Tests:    26 passed, 0 failed
Validation:    56 passed, 0 failed
Demo Tests:    5 passed, 0 failed
```

---

## Files Modified

1. `scripts/ralph/ralph-executor.ps1` - Critical fixes for Kimi args and log paths
2. `scripts/ralph/ralph-master.ps1` - Fixed bead creation and gt.exe detection
3. `scripts/ralph/test/ralph-live-test.ps1` - Fixed variable expansion in test
4. `docs/guides/SETUP.md` - Windows setup, BOM-free encoding, provider type
5. `docs/guides/TROUBLESHOOTING.md` - Fixed config examples, added standalone mode
6. `AGENTS.md` - Added critical configuration notes for agents

---

## Key Takeaways for Future Agents

1. **Kimi CLI requires `--print`** for non-interactive mode
2. **Always use `$PSScriptRoot`** for script-relative paths
3. **Use BOM-free UTF-8** when writing TOML files on Windows
4. **Provider type is "kimi"** not "moonshot"
5. **`bd` CLI is optional** - Ralph works in standalone mode
6. **Windows uses `gt.exe`** not just `gt`

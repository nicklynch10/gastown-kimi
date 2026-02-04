@echo off
REM Ralph Executor Batch Fallback
REM For environments where PowerShell execution is restricted
REM
REM REQUIRED DEPENDENCIES:
REM - Git for Windows (in PATH)
REM - Kimi CLI (pip install kimi-cli)
REM - Optional: Gastown CLI (gt) and Beads CLI (bd)

setlocal EnableDelayedExpansion

set RALPH_VERSION=1.0.0
set MAX_ITERATIONS=10
set DEFAULT_BACKOFF=30

REM Parse arguments
set BEAD_FILE=
set PROJECT_ROOT=.
set VERBOSE=0

:parse_args
if "%~1"=="" goto :done_parsing
if /I "%~1"=="-h" goto :show_help
if /I "%~1"=="--help" goto :show_help
if /I "%~1"=="-f" set "BEAD_FILE=%~2" & shift & shift & goto :parse_args
if /I "%~1"=="--file" set "BEAD_FILE=%~2" & shift & shift & goto :parse_args
if /I "%~1"=="-r" set "PROJECT_ROOT=%~2" & shift & shift & goto :parse_args
if /I "%~1"=="--root" set "PROJECT_ROOT=%~2" & shift & shift & goto :parse_args
if /I "%~1"=="-v" set VERBOSE=1 & shift & goto :parse_args
if /I "%~1"=="--verbose" set VERBOSE=1 & shift & goto :parse_args
shift
goto :parse_args
:done_parsing

echo ========================================
echo   RALPH EXECUTOR v%RALPH_VERSION%
echo   Batch Fallback Mode
echo ========================================
echo.

REM Check prerequisites
echo Checking prerequisites...

call :check_command git "Git for Windows"
if errorlevel 1 goto :error

call :check_command kimi "Kimi CLI"
if errorlevel 1 goto :error

if not defined BEAD_FILE (
    echo ERROR: No bead file specified
    echo Usage: %~nx0 -f bead-file.json
    goto :error
)

if not exist "%BEAD_FILE%" (
    echo ERROR: Bead file not found: %BEAD_FILE%
    goto :error
)

echo [OK] All prerequisites met
echo.

REM Setup logging
set LOG_DIR=%PROJECT_ROOT%\.ralph\logs
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

set LOG_FILE=%LOG_DIR%\ralph-%date:~-4,4%%date:~-10,2%%date:~-7,2%.log
call :log INFO "Ralph Executor started"
call :log INFO "Bead file: %BEAD_FILE%"

REM Main execution loop
set ITERATION=0

:main_loop
set /a ITERATION+=1

echo.
echo === Iteration %ITERATION% / %MAX_ITERATIONS% ===
call :log INFO "Starting iteration %ITERATION%"

REM Read intent from bead file (simple JSON parsing)
for /f "tokens=*" %%a in ('powershell -Command "(Get-Content '%BEAD_FILE%' | ConvertFrom-Json).intent"') do (
    set INTENT=%%a
)

for /f "tokens=*" %%a in ('powershell -Command "(Get-Content '%BEAD_FILE%' | ConvertFrom-Json).dod.verifiers.Count"') do (
    set VERIFIER_COUNT=%%a
)

echo Intent: %INTENT%
echo Verifiers: %VERIFIER_COUNT%

REM Build Kimi prompt
set PROMPT_FILE=%TEMP%\ralph-prompt-%RANDOM%.txt
echo # Ralph Implementation Task > "%PROMPT_FILE%"
echo. >> "%PROMPT_FILE%"
echo ## Intent >> "%PROMPT_FILE%"
echo %INTENT% >> "%PROMPT_FILE%"
echo. >> "%PROMPT_FILE%"
echo ## Definition of Done >> "%PROMPT_FILE%"
echo Run all verifiers and ensure they pass. >> "%PROMPT_FILE%"

echo Invoking Kimi...
call :log INFO "Invoking Kimi for iteration %ITERATION%"

kimi --yolo --file "%PROMPT_FILE%"
set KIMI_EXIT=%ERRORLEVEL%

del "%PROMPT_FILE%" 2>nul

if %KIMI_EXIT% neq 0 (
    echo [WARN] Kimi exited with code %KIMI_EXIT%
    call :log WARN "Kimi exited with code %KIMI_EXIT%"
)

REM Run verifiers (simplified - would need PowerShell for full implementation)
echo Running verifiers...
call :log INFO "Running verifiers"

REM For batch, we just signal that verifiers need to be run manually
echo.
echo [IMPORTANT] Please run the verifiers manually:
echo   1. Check the bead file for verifier commands
echo   2. Run each verifier
echo   3. If all pass, press Y to continue
echo   4. If any fail, press N to retry
echo.

choice /C YN /M "Did all verifiers pass"
if errorlevel 2 goto :verifiers_failed
if errorlevel 1 goto :verifiers_passed

:verifiers_passed
echo.
echo ========================================
echo   ALL VERIFIERS PASSED
echo ========================================
call :log INFO "All verifiers passed after %ITERATION% iteration(s)"

REM Update bead status
powershell -Command "$bead=Get-Content '%BEAD_FILE%'|ConvertFrom-Json;$bead.status='completed';$bead|ConvertTo-Json -Depth 10|Out-File '%BEAD_FILE%' -Encoding utf8"

goto :success

:verifiers_failed
echo.
echo [WARN] Some verifiers failed, retrying after %DEFAULT_BACKOFF%s...
call :log WARN "Verifiers failed, retrying"

timeout /t %DEFAULT_BACKOFF% /nobreak >nul

if %ITERATION% lss %MAX_ITERATIONS% goto :main_loop

echo.
echo ========================================
echo   MAX ITERATIONS REACHED
echo ========================================
call :log ERROR "Max iterations reached without success"

REM Update bead status
powershell -Command "$bead=Get-Content '%BEAD_FILE%'|ConvertFrom-Json;$bead.status='failed';$bead|ConvertTo-Json -Depth 10|Out-File '%BEAD_FILE%' -Encoding utf8"

goto :error

:check_command
echo|set /p=Checking %~2... 
where %~1 >nul 2>&1
if errorlevel 1 (
    echo [MISSING]
    echo ERROR: %~2 not found in PATH
    echo Please install %~2 before running Ralph
    exit /b 1
)
echo [OK]
exit /b 0

:log
set TIMESTAMP=%date% %time%
echo [%TIMESTAMP%] [%~1] %~2 >> "%LOG_FILE%"
if %VERBOSE%==1 echo [%TIMESTAMP%] [%~1] %~2
exit /b 0

:show_help
echo Usage: %~nx0 [options]
echo.
echo Options:
echo   -f, --file FILE     Bead JSON file to execute (required)
echo   -r, --root PATH     Project root directory (default: current)
echo   -v, --verbose       Enable verbose output
echo   -h, --help          Show this help message
echo.
echo Example:
echo   %~nx0 -f my-bead.json -r C:\MyProject -v
echo.
exit /b 0

:success
echo.
echo [SUCCESS] Ralph execution completed
echo Log file: %LOG_FILE%
exit /b 0

:error
echo.
echo [FAILED] Ralph execution failed
echo Log file: %LOG_FILE%
exit /b 1

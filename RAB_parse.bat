@echo off
REM RABuffs Logger - Simple Parser (for same directory)
REM Copy this file to the same folder as WoWCombatLog.txt

echo ========================================
echo RABuffs Logger - CombatLog Parser
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python not found!
    echo.
    echo Please install Python from:
    echo https://www.python.org/downloads/
    pause
    exit /b 1
)

REM Check if WoWCombatLog.txt exists in current directory
if not exist "WoWCombatLog.txt" (
    echo ERROR: WoWCombatLog.txt not found in current directory!
    echo.
    echo Current directory: %CD%
    echo.
    dir /b *.txt
    echo.
    pause
    exit /b 1
)

echo Found: WoWCombatLog.txt in current directory
echo.

REM Check if RAB_parse_log.py exists
if not exist "RAB_parse_log.py" (
    echo ERROR: RAB_parse_log.py not found!
    echo.
    echo Please copy both files to this directory:
    echo   - RAB_parse_log.py
    echo   - RAB_parse.bat
    pause
    exit /b 1
)

echo Select export format:
echo   1 = Text (readable)
echo   2 = CSV (for Excel)
echo   3 = JSON (for programming)
echo   4 = All formats
echo   5 = Statistics only
echo.

set /p CHOICE="Enter choice (1-5): "

if "%CHOICE%"=="1" set FORMAT=text
if "%CHOICE%"=="2" set FORMAT=csv
if "%CHOICE%"=="3" set FORMAT=json
if "%CHOICE%"=="4" set FORMAT=all
if "%CHOICE%"=="5" goto STATS

if "%FORMAT%"=="" (
    echo Invalid choice!
    pause
    exit /b 1
)

echo.
echo Parsing with format: %FORMAT%
echo.

python RAB_parse_log.py -i WoWCombatLog.txt -f %FORMAT%

goto END

:STATS
echo.
echo Showing statistics...
echo.
python RAB_parse_log.py -i WoWCombatLog.txt --stats

:END
echo.
echo ========================================
echo Done! Files created in current directory
echo ========================================
pause


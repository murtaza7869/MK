@echo off
REM Kill all running instances of FITeacherConsole.exe
echo Searching for running instances of FITeacherConsole.exe...
for /f "tokens=2 delims=," %%i in ('tasklist /FI "IMAGENAME eq FITeacherConsole.exe" /FO CSV /NH') do (
    echo Terminating process %%~i...
    taskkill /PID %%~i /F >nul 2>&1
)

REM Wait for a moment to ensure all processes are terminated
timeout /t 2 >nul

REM Launch a new instance of FITeacherConsole.exe
echo Launching new instance of FITeacherConsole.exe...
start "" "C:\Program Files\Faronics\Insight Teacher\FITeacherConsole.exe" /showUI

REM Inform the user that the operation is complete
echo Operation completed successfully.


@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION
setlocal
REM go to the folder where this bat script is located
cd /d %~dp0

set /a EXPECTED_CLI_MAJOR=0
set /a EXPECTED_CLI_MINOR=13

set NDP_CMD=ndp10x_flash\ndp10x_flash.exe

FOR %%i in (`DIR /b /s "." ^| find "ei_model*.bin") do SET BIN_FILE=%%i

FOR %%I IN (.) DO SET DIRECTORY_NAME=%%~nI%%~xI

where /q arduino-cli
IF ERRORLEVEL 1 (
    GOTO NOTINPATHERROR
)

REM parse arduino-cli version
FOR /F "tokens=1-3 delims==." %%I IN ('arduino-cli version') DO (
    FOR /F "tokens=1-3 delims== " %%X IN ('echo %%I') DO (
        set /A CLI_MAJOR=%%Z
    )
    SET /A CLI_MINOR=%%J
    FOR /F "tokens=1-3 delims== " %%X IN ('echo %%K') DO (
        set /A CLI_REV=%%X
    )
)

if !CLI_MINOR! LSS !EXPECTED_CLI_MINOR! (
    GOTO UPGRADECLI
)

if !CLI_MAJOR! NEQ !EXPECTED_CLI_MAJOR! (
    echo You're using an untested version of Arduino CLI, this might cause issues (found: %CLI_MAJOR%.%CLI_MINOR%.%CLI_REV%, expected: %EXPECTED_CLI_MAJOR%.%EXPECTED_CLI_MINOR%.x )
) else (
    if !CLI_MINOR! NEQ !EXPECTED_CLI_MINOR! (
        echo You're using an untested version of Arduino CLI, this might cause issues (found: %CLI_MAJOR%.%CLI_MINOR%.%CLI_REV%, expected: %EXPECTED_CLI_MAJOR%.%EXPECTED_CLI_MINOR%.x )
    )
)

echo Finding Arduino SAMD core v1.8.9...

(arduino-cli core list  2> nul) | findstr /r "arduino:samd.*1.8.9"
IF %ERRORLEVEL% NEQ 0 (
    GOTO INSTALLSAMDCORE
)

:AFTERINSTALLSAMDCORE

echo Finding Arduino SAMD core OK

echo Finding Arduino MKRZero...

set COM_PORT=""

for /f "tokens=1" %%i in ('arduino-cli board list ^| findstr "Arduino MKRZERO"') do (
    set COM_PORT=%%i
    GOTO FLASHARDUINO
)

IF %COM_PORT% == "" (
    GOTO NOTCONNECTED
)

:FLASHARDUINO

echo Finding Arduino MKRZero OK at %COM_PORT%

echo Flashing Arduino firmware...
CALL arduino-cli upload -p %COM_PORT% --fqbn arduino:samd:mkrzero  --input-file firmware.ino.bin

IF %ERRORLEVEL% NEQ 0 (
    GOTO FLASHINGFAILEDERROR
)
echo Flashed your Arduino MKRZero development board. Board restarting...
timeout /t 5 /nobreak

REM look for COM port again in case Windows switches COM number
for /f "tokens=1" %%i in ('arduino-cli board list ^| findstr "Arduino MKRZERO"') do (
    set COM_PORT=%%i
    GOTO FLASHNN
)

IF %COM_PORT% == "" (
    GOTO NOTCONNECTED
)

:FLASHNN

echo Writing NN model to flash...
CALL %NDP_CMD% -s %COM_PORT% -Q -a 0x00 -w %BIN_FILE% -v %BIN_FILE%

IF %ERRORLEVEL% NEQ 0 (
    GOTO FLASHINGFAILEDERROR
)

echo Writing NN model OK

echo Press reset button to start the application


@pause
exit /b 0

:NOTINPATHERROR
echo Cannot find 'arduino-cli' in your PATH. Install the Arduino CLI before you continue
echo Installation instructions: https://arduino.github.io/arduino-cli/latest/
@pause
exit /b 1

:INSTALLSAMDCORE
echo Installing Arduino SAMD core...
arduino-cli core update-index
arduino-cli core install arduino:samd@1.8.9
echo Installing Arduino SAMD core OK
GOTO AFTERINSTALLSAMDCORE

:NOTCONNECTED
echo Cannot find a connected Arduino MKRZero development board via 'arduino-cli board list'
echo If your board is connected, double-tap on the RESET button to bring the board in recovery mode
@pause
exit /b 1

:UPGRADECLI
echo You need to upgrade your Arduino CLI version (now: %CLI_MAJOR%.%CLI_MINOR%.%CLI_REV%, but required: %EXPECTED_CLI_MAJOR%.%EXPECTED_CLI_MINOR%.x or higher)
echo See https://arduino.github.io/arduino-cli/installation/ for upgrade instructions
@pause
exit /b 1

:FLASHINGFAILEDERROR
@pause
exit /b %ERRORLEVEL%

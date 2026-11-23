@echo off
REM Downloads packages, checks the code and runs the unit tests.
cd /d "%~dp0"
call flutter pub get || goto :error
call flutter analyze
call flutter test
pause
goto :eof
:error
echo flutter pub get failed. Read the messages above.
pause

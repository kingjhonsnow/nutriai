@echo off
REM Runs NutriAI in Chrome on this PC (for testing).
cd /d "%~dp0"
if not exist config.json (
  echo config.json is missing. Copy config.example.json to config.json and fill in your Supabase URL and key.
  pause
  exit /b 1
)
call flutter pub get || goto :error
call flutter run -d chrome --dart-define-from-file=config.json
goto :eof
:error
echo Something went wrong. Read the messages above.
pause

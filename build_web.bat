@echo off
REM Builds the web app into build\web (this folder is what you upload to Cloudflare Pages).
cd /d "%~dp0"
if not exist config.json (
  echo config.json is missing. Copy config.example.json to config.json and fill in your Supabase URL and key.
  pause
  exit /b 1
)
call flutter pub get || goto :error
call flutter build web --release --dart-define-from-file=config.json || goto :error
echo.
echo Done. Upload the folder build\web to Cloudflare Pages (see SETUP.md, step 6).
pause
goto :eof
:error
echo Build failed. Read the messages above, or send them to Claude.
pause

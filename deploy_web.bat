@echo off
REM Optional: builds and uploads to Cloudflare Pages in one go (needs Node.js installed).
REM The first time, a browser window opens to log in to Cloudflare.
cd /d "%~dp0"
if not exist config.json (
  echo config.json is missing. Copy config.example.json to config.json first.
  pause
  exit /b 1
)
call flutter pub get || goto :error
call flutter build web --release --dart-define-from-file=config.json || goto :error
call npx --yes wrangler pages deploy build\web --project-name nutriai || goto :error
pause
goto :eof
:error
echo Something went wrong. Read the messages above.
pause

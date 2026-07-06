@echo off
setlocal
cd /d "%~dp0\.."
python tooling\micros_review_server.py
if errorlevel 1 (
  echo.
  echo The editor could not start. Make sure Python is installed and port 8766 is free.
  pause
)

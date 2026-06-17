@echo off
setlocal
cd /d "%~dp0\.."
python tooling\food_review_server.py
if errorlevel 1 (
  echo.
  echo The editor could not start. Make sure Python is installed and port 8765 is free.
  pause
)

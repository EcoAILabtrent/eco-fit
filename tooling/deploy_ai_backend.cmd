@echo off
setlocal

cd /d "%~dp0.."

set "NODE_ROOT=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\node"
set "NODE_EXE=%NODE_ROOT%\bin\node.exe"
set "PNPM_CLI=%NODE_ROOT%\node_modules\pnpm\bin\pnpm.cjs"

echo Checking Firebase login...
call tooling\firebase_cli.cmd projects:list --json > nul
if errorlevel 1 (
    echo Firebase CLI is not logged in. Run: tooling\firebase_cli.cmd login
    exit /b 1
)

echo.
echo Installing Cloud Functions dependencies...
pushd functions
"%NODE_EXE%" "%PNPM_CLI%" install --ignore-scripts
if errorlevel 1 exit /b %errorlevel%
popd

echo.
echo Setting DEEPSEEK_API_KEY in Firebase Secret Manager.
echo Paste the DeepSeek API key when Firebase asks for it. The value will not be stored in the app.
call tooling\firebase_cli.cmd functions:secrets:set DEEPSEEK_API_KEY
if errorlevel 1 exit /b %errorlevel%

echo.
echo Deploying Cloud Functions...
call tooling\firebase_cli.cmd deploy --only functions
exit /b %errorlevel%

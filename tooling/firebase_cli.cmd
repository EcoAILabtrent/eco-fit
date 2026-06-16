@echo off
setlocal
set "NODE_ROOT=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\node"
set "NODE_EXE=%NODE_ROOT%\bin\node.exe"
set "PNPM_CLI=%NODE_ROOT%\node_modules\pnpm\bin\pnpm.cjs"
set "PATH=%NODE_ROOT%\bin;%PATH%"
"%NODE_EXE%" "%PNPM_CLI%" dlx firebase-tools %*

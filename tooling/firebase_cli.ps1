param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $FirebaseArgs
)

$ErrorActionPreference = "Stop"

$nodeRoot = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\node"
$nodeExe = Join-Path $nodeRoot "bin\node.exe"
$pnpmCli = Join-Path $nodeRoot "node_modules\pnpm\bin\pnpm.cjs"

if (-not (Test-Path $nodeExe)) {
    throw "Bundled Node.js was not found at $nodeExe"
}

if (-not (Test-Path $pnpmCli)) {
    throw "Bundled pnpm was not found at $pnpmCli"
}

$env:PATH = (Join-Path $nodeRoot "bin") + [IO.Path]::PathSeparator + $env:PATH
& $nodeExe $pnpmCli dlx firebase-tools @FirebaseArgs

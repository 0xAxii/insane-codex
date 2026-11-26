$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($env:OS -ne "Windows_NT") {
    throw "This installer only supports Windows."
}

$architecture = if ($env:PROCESSOR_ARCHITEW6432) {
    $env:PROCESSOR_ARCHITEW6432
} else {
    $env:PROCESSOR_ARCHITECTURE
}

$target = switch ($architecture.ToUpperInvariant()) {
    "AMD64" { "x86_64-pc-windows-msvc" }
    "ARM64" { "aarch64-pc-windows-msvc" }
    default { throw "Unsupported Windows architecture: $architecture" }
}

$repo = "0xAxii/insane-codex"
$releaseBase = if ($env:INSANE_CODEX_RELEASE_BASE) {
    $env:INSANE_CODEX_RELEASE_BASE.TrimEnd("/")
} else {
    "https://github.com/$repo/releases/latest/download"
}
$installDir = if ($env:INSANE_CODEX_INSTALL_DIR) {
    $env:INSANE_CODEX_INSTALL_DIR
} elseif ($env:LOCALAPPDATA) {
    Join-Path $env:LOCALAPPDATA "Programs\insane-codex"
} else {
    Join-Path $HOME ".local\bin"
}

$asset = "insane-codex-$target.zip"
$tempDir = Join-Path ([IO.Path]::GetTempPath()) ("insane-codex-" + [guid]::NewGuid())

try {
    New-Item -ItemType Directory -Force $tempDir | Out-Null
    Invoke-WebRequest "$releaseBase/$asset" -OutFile (Join-Path $tempDir $asset)

    Expand-Archive (Join-Path $tempDir $asset) -DestinationPath $tempDir -Force
    foreach ($required in @("codex-package.json", "bin/insane-codex.exe", "bin/codex-code-mode-host.exe", "bin/codex-exec-server.exe", "codex-path/rg.exe", "codex-resources/codex-command-runner.exe", "codex-resources/codex-windows-sandbox-setup.exe")) {
        if (-not (Test-Path (Join-Path $tempDir $required))) {
            throw "Missing package file: $required"
        }
    }
    New-Item -ItemType Directory -Force $installDir | Out-Null
    Copy-Item (Join-Path $tempDir "bin") (Join-Path $installDir "bin") -Recurse -Force
    Copy-Item (Join-Path $tempDir "codex-path") (Join-Path $installDir "codex-path") -Recurse -Force
    Copy-Item (Join-Path $tempDir "codex-resources") (Join-Path $installDir "codex-resources") -Recurse -Force
    Copy-Item (Join-Path $tempDir "codex-package.json") (Join-Path $installDir "codex-package.json") -Force
    $binDir = Join-Path $installDir "bin"

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $pathEntries = if ($userPath) { $userPath -split ";" } else { @() }
    if ($pathEntries -notcontains $binDir) {
        $newUserPath = if ($userPath) { "$binDir;$userPath" } else { $binDir }
        [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    }
    if (($env:Path -split ";") -notcontains $binDir) {
        $env:Path = "$binDir;$env:Path"
    }

    Write-Host "Installed: $(Join-Path $binDir 'insane-codex.exe')"
    & (Join-Path $binDir "insane-codex.exe") --version
    Write-Host "Open a new terminal, then run: insane-codex"
} finally {
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
}

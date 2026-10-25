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
    Invoke-WebRequest "$releaseBase/$asset.sha256" -OutFile (Join-Path $tempDir "$asset.sha256")

    $expected = ((Get-Content (Join-Path $tempDir "$asset.sha256") -Raw).Trim() -split "\s+")[0]
    $actual = (Get-FileHash (Join-Path $tempDir $asset) -Algorithm SHA256).Hash
    if (-not $expected -or $actual -ne $expected) {
        throw "Checksum verification failed."
    }

    Expand-Archive (Join-Path $tempDir $asset) -DestinationPath $tempDir -Force
    New-Item -ItemType Directory -Force $installDir | Out-Null
    Copy-Item (Join-Path $tempDir "insane-codex.exe") (Join-Path $installDir "insane-codex.exe") -Force

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $pathEntries = if ($userPath) { $userPath -split ";" } else { @() }
    if ($pathEntries -notcontains $installDir) {
        $newUserPath = if ($userPath) { "$installDir;$userPath" } else { $installDir }
        [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    }
    if (($env:Path -split ";") -notcontains $installDir) {
        $env:Path = "$installDir;$env:Path"
    }

    Write-Host "Installed: $(Join-Path $installDir 'insane-codex.exe')"
    & (Join-Path $installDir "insane-codex.exe") --version
    Write-Host "Open a new terminal, then run: insane-codex"
} finally {
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
}

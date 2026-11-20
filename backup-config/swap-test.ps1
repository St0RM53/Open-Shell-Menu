# Swaps the official Open-Shell x64 StartMenu.exe + StartMenuDLL.dll with our freshly built
# ones (with backup), so we can verify the local build works. Run elevated.
# Locked target files (loaded in explorer.exe) are renamed aside instead of overwritten.
param()

$ErrorActionPreference = "Stop"
$log = "C:\Users\TnF\Documents\open-shell-dev\build-logs\swap-test.log"
Start-Transcript -Path $log -Force

$install = "C:\Program Files\Open-Shell"
$built   = "C:\Users\TnF\Documents\open-shell-dev\Open-Shell-Menu\build\bin\Setup64"
$backup  = "C:\Users\TnF\Documents\open-shell-dev\official-backup"

$files = @("StartMenu.exe", "StartMenuDLL.dll")

try {
    # Stop menu process; helper may respawn it, that's fine - handles stay on old files
    Get-Process StartMenu -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500

    # 2. Backup originals once (never overwrite the backup)
    New-Item -ItemType Directory -Force $backup | Out-Null
    foreach ($f in $files) {
        $dst = Join-Path $backup $f
        if (-not (Test-Path $dst)) {
            Copy-Item (Join-Path $install $f) $dst
            Write-Output "Backed up: $f"
        } else {
            Write-Output "Backup already exists: $f (kept)"
        }
    }

    # 3. Copy our build in; if target is locked (loaded in explorer), rename it aside first
    foreach ($f in $files) {
        $target = Join-Path $install $f
        try {
            Copy-Item (Join-Path $built $f) $target -Force
        } catch {
            Write-Output "$f is locked - renaming aside and retrying"
            $aside = Join-Path $install ($f + ".replaced")
            if (Test-Path $aside) { Remove-Item $aside -Force }
            Move-Item $target $aside -Force
            Copy-Item (Join-Path $built $f) $target -Force
        }
        $v = (Get-Item $target).VersionInfo.FileVersion
        Write-Output "Swapped in: $f (version $v)"
    }
    Write-Output "SWAP OK"
}
catch {
    Write-Output "SWAP FAILED: $_"
    exit 1
}
finally {
    Stop-Transcript
}

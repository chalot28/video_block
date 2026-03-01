$ErrorActionPreference = 'Stop'

Set-Location "D:\video_block"

Write-Host "[1/3] Building Flutter Windows release..."
flutter build windows --release

Write-Host "[2/3] Compiling EXE installer with Inno Setup..."
$iscc = $null

try {
	$iscc = (Get-Command iscc -ErrorAction Stop).Source
} catch {
	$registryPaths = @(
		'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
		'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
		'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
	)

	$innoInstall = Get-ItemProperty $registryPaths -ErrorAction SilentlyContinue |
		Where-Object { $_.DisplayName -like '*Inno Setup*' } |
		Select-Object -First 1

	if ($innoInstall -and $innoInstall.InstallLocation) {
		$fromRegistry = Join-Path $innoInstall.InstallLocation 'ISCC.exe'
		if (Test-Path $fromRegistry) {
			$iscc = $fromRegistry
		}
	}

	$candidates = @(
		"C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
		"C:\Program Files\Inno Setup 6\ISCC.exe",
		"C:\Program Files (x86)\Inno Setup 5\ISCC.exe",
		"C:\Program Files\Inno Setup 5\ISCC.exe",
		"$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
	)

	if (-not $iscc) {
		foreach ($candidate in $candidates) {
			if (Test-Path $candidate) {
				$iscc = $candidate
				break
			}
		}
	}
}

if (-not $iscc) {
	throw "Không tìm thấy ISCC.exe (Inno Setup). Hãy cài Inno Setup và thử lại."
}

& $iscc "D:\video_block\installer\video_block.iss"

if ($LASTEXITCODE -ne 0) {
	throw "Biên dịch installer thất bại với mã lỗi $LASTEXITCODE"
}

$setupPath = "D:\video_block\build\installer\video_block_setup.exe"
if (!(Test-Path $setupPath)) {
	throw "Không tìm thấy file installer: $setupPath"
}

Write-Host "[3/3] Done. Installer created at: D:\video_block\build\installer\video_block_setup.exe"

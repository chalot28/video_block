$ErrorActionPreference = 'Stop'

$cerPath = 'D:\video_block\build\windows\x64\runner\Release\video_block_signer.cer'
$msixPath = 'D:\video_block\build\windows\x64\runner\Release\video_block.msix'

if (!(Test-Path $cerPath)) {
	throw "Không tìm thấy file cert: $cerPath"
}

if (!(Test-Path $msixPath)) {
	throw "Không tìm thấy file msix: $msixPath"
}

Write-Host 'Adding certificate to LocalMachine Root...'
certutil -addstore Root $cerPath | Out-Host

Write-Host 'Adding certificate to LocalMachine TrustedPeople...'
certutil -addstore TrustedPeople $cerPath | Out-Host

Write-Host 'Installing MSIX...'
Add-AppxPackage -Path $msixPath

Write-Host 'Cài đặt hoàn tất.'

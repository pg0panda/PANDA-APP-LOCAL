$path = 'e:'
$path = Join-Path $path 'مشاريع'
$path = Join-Path $path 'PANDA-APP-LOCAL'
$path = Join-Path $path 'tools'
$path = Join-Path $path 'clean.ps1'
$tokens = $null
$errors = $null
$content = Get-Content -Raw $path
[System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { $_.Message }
    exit 1
}
Write-Output 'Script syntax OK'

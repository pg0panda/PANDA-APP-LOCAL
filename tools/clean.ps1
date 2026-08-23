# Safe Deep Clean Tool - PowerShell Version
# Created by Panda
# This version focuses on safe, review-first cleanup.
# It does not forcibly remove unknown services or startup entries without confirmation.

$ErrorActionPreference = "Continue"
Set-StrictMode -Version Latest

function Test-IsAdministrator {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Status {
    param(
        [string]$Message,
        [string]$Color = "Green"
    )
    Write-Host "[+] $Message" -ForegroundColor $Color
}

function Confirm-Action {
    param([string]$Question)
    $answer = Read-Host $Question
    return ($answer -match "^(Y|YES)$")
}

function Clear-IfExists {
    param(
        [string]$Path,
        [string]$Description = "item"
    )

    if (-not $Path) { return }
    if (Test-Path -LiteralPath $Path) {
        try {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
            Write-Status "$Description removed successfully."
        }
        catch {
            Write-Status "Could not remove ${Description}: ${Path}" "Yellow"
        }
    }
}

function Clear-DirectoryContents {
    param(
        [string]$Directory,
        [string]$Description
    )

    if (-not $Directory) { return }
    if (Test-Path -LiteralPath $Directory) {
        $items = Get-ChildItem -LiteralPath $Directory -Force -ErrorAction SilentlyContinue
        if ($items) {
            foreach ($item in $items) {
                try {
                    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                }
                catch {
                    Write-Status "Skipped locked item: $($item.FullName)" "Yellow"
                }
            }
            Write-Status "$Description cleaned."
        }
        else {
            Write-Status "$Description is already clean."
        }
    }
    else {
        Write-Status "$Description not found."
    }
}

function Get-SuspiciousStartupEntries {
    $patterns = @("adb","android","emulator","aow","qm","game","syzs","ninja","tupdate","loader","tencent","tp3helper")
    $keys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce"
    )

    $candidates = @()
    foreach ($key in $keys) {
        if (Test-Path $key) {
            $properties = Get-ItemProperty $key -ErrorAction SilentlyContinue
            if (-not $properties) { continue }

            foreach ($property in $properties.PSObject.Properties) {
                $name = $property.Name
                $value = [string]$property.Value
                $matched = $false
                foreach ($pattern in $patterns) {
                    if ($name -match $pattern -or $value -match $pattern) {
                        $matched = $true
                        break
                    }
                }

                if ($matched) {
                    $candidates += [PSCustomObject]@{
                        Key = $key
                        Name = $name
                        Value = $value
                    }
                }
            }
        }
    }

    return $candidates
}

function Remove-SuspiciousStartupEntries {
    $items = Get-SuspiciousStartupEntries
    if (-not $items -or $items.Count -eq 0) {
        Write-Status "No suspicious startup entries found."
        return
    }

    Write-Host "" 
    Write-Host "Suspicious Startup Entries:" -ForegroundColor Yellow
    foreach ($item in $items) {
        Write-Host " - $($item.Key)\$($item.Name) = $($item.Value)" -ForegroundColor Yellow
    }

    if (-not (Confirm-Action "Remove these startup entries? (Y/N): ")) {
        Write-Status "Startup entries left unchanged."
        return
    }

    foreach ($item in $items) {
        try {
            Remove-ItemProperty -Path $item.Key -Name $item.Name -ErrorAction Stop
            Write-Status "Removed startup entry: $($item.Key)\$($item.Name)"
        }
        catch {
            Write-Status "Could not remove startup entry: $($item.Key)\$($item.Name)" "Yellow"
        }
    }
}

function Get-SuspiciousScheduledTasks {
    $patterns = @("adb","android","emulator","aow","qm","game","syzs","ninja","tupdate","loader","tencent","tp3helper")
    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue
    $candidates = @()

    foreach ($task in $tasks) {
        foreach ($pattern in $patterns) {
            if ($task.TaskName -match $pattern) {
                $candidates += $task.TaskName
                break
            }
        }
    }

    return $candidates
}

function Remove-SuspiciousScheduledTasks {
    $tasks = Get-SuspiciousScheduledTasks
    if (-not $tasks -or $tasks.Count -eq 0) {
        Write-Status "No suspicious scheduled tasks found."
        return
    }

    Write-Host "" 
    Write-Host "Suspicious Scheduled Tasks:" -ForegroundColor Yellow
    foreach ($task in $tasks) {
        Write-Host " - $task" -ForegroundColor Yellow
    }

    if (-not (Confirm-Action "Remove these scheduled tasks? (Y/N): ")) {
        Write-Status "Scheduled tasks left unchanged."
        return
    }

    foreach ($task in $tasks) {
        try {
            Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction Stop
            Write-Status "Removed scheduled task: $task"
        }
        catch {
            Write-Status "Could not remove scheduled task: $task" "Yellow"
        }
    }
}

function Get-SuspiciousServices {
    $patterns = @("adb","android","emulator","aow","qm","game","syzs","ninja","tupdate","loader","tencent","tp3helper")
    $services = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue
    $candidates = @()

    foreach ($service in $services) {
        foreach ($pattern in $patterns) {
            if ($service.Name -match $pattern) {
                $candidates += $service.Name
                break
            }
        }
    }

    return $candidates
}

function Remove-SuspiciousServices {
    $services = Get-SuspiciousServices
    if (-not $services -or $services.Count -eq 0) {
        Write-Status "No suspicious services found."
        return
    }

    Write-Host "" 
    Write-Host "Suspicious Services:" -ForegroundColor Yellow
    foreach ($service in $services) {
        Write-Host " - $service" -ForegroundColor Yellow
    }

    if (-not (Confirm-Action "Disable and remove these services? (Y/N): ")) {
        Write-Status "Services left unchanged."
        return
    }

    foreach ($service in $services) {
        try {
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
            sc.exe delete $service | Out-Null
            Write-Status "Removed service: $service"
        }
        catch {
            Write-Status "Could not remove service: $service" "Yellow"
        }
    }
}

function Get-SuspiciousProcesses {
    $patterns = @("adb","android","emulator","aow","qm","game","syzs","ninja","tupdate","loader","tencent","tp3helper")
    $processes = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue
    $candidates = @()

    foreach ($process in $processes) {
        foreach ($pattern in $patterns) {
            if ($process.Name -match $pattern) {
                $candidates += $process.Name
                break
            }
        }
    }

    return $candidates
}

function Stop-SuspiciousProcesses {
    $processes = Get-SuspiciousProcesses
    if (-not $processes -or $processes.Count -eq 0) {
        Write-Status "No suspicious processes found."
        return
    }

    Write-Host "" 
    Write-Host "Suspicious Processes:" -ForegroundColor Yellow
    foreach ($process in $processes) {
        Write-Host " - $process" -ForegroundColor Yellow
    }

    if (-not (Confirm-Action "Stop these suspicious processes? (Y/N): ")) {
        Write-Status "Processes left running."
        return
    }

    foreach ($process in $processes) {
        $runningProc = Get-CimInstance Win32_Process -Filter "Name = '$process'" -ErrorAction SilentlyContinue
        foreach ($item in $runningProc) {
            try {
                Stop-Process -Id $item.ProcessId -Force -ErrorAction Stop
                Write-Status "Stopped process: $process"
            }
            catch {
                Write-Status "Could not stop process: $process" "Yellow"
            }
        }
    }
}

function Clear-BrowserCaches {
    $targets = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cookies",
        "$env:APPDATA\Mozilla\Firefox\Profiles"
    )

    foreach ($target in $targets) {
        if (Test-Path -LiteralPath $target) {
            if ($target -match "Firefox") {
                Get-ChildItem -LiteralPath $target -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    Clear-DirectoryContents -Directory $_.FullName -Description "Firefox profile cache"
                }
            }
            else {
                Clear-DirectoryContents -Directory $target -Description "Browser cache"
            }
        }
    }
}

function Clear-SystemArtifacts {
    $paths = @(
        "$env:LOCALAPPDATA\Temp",
        "$env:TEMP",
        "$env:WINDIR\Temp",
        "$env:WINDIR\Prefetch",
        "$env:LOCALAPPDATA\Microsoft\Windows\Temporary Internet Files",
        "$env:LOCALAPPDATA\Microsoft\Windows\History",
        "$env:LOCALAPPDATA\Microsoft\Windows\Caches",
        "$env:LOCALAPPDATA\Microsoft\Windows\WER",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\ThumbCacheToDelete",
        "$env:APPDATA\Microsoft\Windows\Cookies",
        "$env:USERPROFILE\Cookies",
        "$env:USERPROFILE\Recent",
        "$env:ProgramData\Microsoft\Windows\Caches",
        "$env:ProgramData\Microsoft\Windows\WER",
        "$env:WINDIR\Minidump",
        "$env:WINDIR\MEMORY.DMP",
        "$env:WINDIR\Minidump.dmp"
    )

    foreach ($path in $paths) {
        if (Test-Path -LiteralPath $path) {
            if ($path -like "*\Prefetch") {
                Get-ChildItem -LiteralPath $path -Filter "*.pf" -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    Clear-IfExists -Path $_.FullName -Description "Prefetch file"
                }
            }
            else {
                Clear-DirectoryContents -Directory $path -Description "System artifact"
            }
        }
    }
}

function Clear-OldLogsAndDumps {
    $folders = @(
        "$env:WINDIR\Logs",
        "$env:WINDIR\Panther",
        "$env:ProgramData\Microsoft\Windows\Logs",
        "$env:ProgramData\Microsoft\Windows\WER"
    )

    foreach ($folder in $folders) {
        if (Test-Path -LiteralPath $folder) {
            Get-ChildItem -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {
                $_.LastWriteTime -lt (Get-Date).AddDays(-30)
            } | ForEach-Object {
                Clear-IfExists -Path $_.FullName -Description "Old log/dump file"
            }
        }
    }
}

function Remove-AutorunInfFiles {
    $letters = 67..90 | ForEach-Object { [char]$_ }
    foreach ($letter in $letters) {
        $path = "$letter`:\autorun.inf"
        if (Test-Path -LiteralPath $path) {
            if (Confirm-Action "Remove autorun.inf from drive ${letter}:? (Y/N): ") {
                Clear-IfExists -Path $path -Description "autorun.inf on drive ${letter}:"
            }
        }
    }
}

function Remove-SuspiciousStartupFiles {
    $targets = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:USERPROFILE\Desktop",
        "$env:USERPROFILE\Downloads",
        "$env:LOCALAPPDATA\Temp"
    )

    $patterns = @("adb","android","emulator","aow","qm","syzs","ninja","tupdate","loader","tencent","tp3helper","autorun","runonce","suspicious")
    $startupMatches = [System.Collections.Generic.List[object]]::new()

    foreach ($target in $targets) {
        if (-not (Test-Path -LiteralPath $target)) { continue }

        Get-ChildItem -LiteralPath $target -File -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $item = $_
            if ($null -eq $item) { return }

            $name = [string]$item.Name
            $full = [string]$item.FullName
            foreach ($pattern in $patterns) {
                if ($name -match $pattern -or $full -match $pattern) {
                    $startupMatches.Add($item) | Out-Null
                    break
                }
            }
        }
    }

    if ($startupMatches.Count -eq 0) {
        Write-Status "No suspicious startup files found."
        return
    }

    Write-Host "" 
    Write-Host "Suspicious Startup Files:" -ForegroundColor Yellow
    foreach ($item in $startupMatches) {
        $itemPath = [string]$item.FullName
        Write-Host " - $itemPath" -ForegroundColor Yellow
    }

    if (-not (Confirm-Action "Delete these suspicious startup files? (Y/N): ")) {
        Write-Status "Suspicious startup files left unchanged."
        return
    }

    foreach ($item in $startupMatches) {
        try {
            $itemPath = [string]$item.FullName
            Remove-Item -LiteralPath $itemPath -Recurse -Force -ErrorAction Stop
            Write-Status "Deleted suspicious file: $itemPath"
        }
        catch {
            $itemPath = [string]$item.FullName
            Write-Status "Could not delete suspicious file: $itemPath" "Yellow"
        }
    }
}

function Get-FileHashSha256 {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $null }

    try {
        $hash = Get-FileHash -Path $Path -Algorithm SHA256 -ErrorAction Stop
        return $hash.Hash
    }
    catch {
        return $null
    }
}

function Test-PEFileIndicators {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return @() }

    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
    }
    catch {
        return @()
    }

    if ($bytes.Length -lt 64) { return @() }

    $header = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 2)
    $reasons = @()

    if ($header -ne "MZ") { return @() }

    $suspiciousImports = @(
        "CreateProcess","CreateRemoteThread","VirtualAlloc","WriteProcessMemory",
        "OpenProcess","InternetOpenA","InternetOpenUrl","WinExec","ShellExecute",
        "WSAStartup","SetWindowsHookEx","GetAsyncKeyState","RegisterHotKey",
        "IsDebuggerPresent","ReadProcessMemory","GetTickCount","NtCreateUserProcess"
    )

    $ascii = [System.Text.Encoding]::ASCII.GetString($bytes)
    foreach ($token in $suspiciousImports) {
        if ($ascii -match [Regex]::Escape($token)) {
            $reasons += "PE import pattern: $token"
        }
    }

    if ($ascii -match "powershell.*-nop.*-w.*hidden|rundll32|regsvr32|mshta|bitsadmin|certutil|frombase64string") {
        $reasons += "Embedded execution payload pattern"
    }

    return @($reasons)
}

function Test-ScriptFileIndicators {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return @() }

    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $reasons = @()

    try {
        $content = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    }
    catch {
        return @()
    }

    $patterns = @(
        "powershell.*-nop.*-w.*hidden",
        "frombase64string",
        "Invoke-Expression",
        "WScript\.Shell",
        "cmd\.exe.*\/c",
        "Start-Process",
        "CreateObject.*WScript\.Shell",
        "RunOnce|autorun|HKCU\\\\Software\\\\Microsoft\\\\Windows\\\\CurrentVersion\\\\Run",
        "http.*(exe|dll|ps1|vbs|js)",
        "taskkill|sc\.exe.*delete|netsh.*winsock|bitsadmin.*http",
        "obfuscation|base64|Invoke-WebRequest|DownloadString"
    )

    foreach ($pattern in $patterns) {
        if ($content -match $pattern) {
            $reasons += "Script indicator: $pattern"
        }
    }

    if ($ext -in @(".bat", ".cmd", ".vbs", ".js", ".jse", ".ps1", ".psm1", ".hta", ".scr")) {
        $reasons += "Script extension is commonly abused for persistence"
    }

    return @($reasons)
}

function Get-MalwareIndicators {
    $targets = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:USERPROFILE\Desktop",
        "$env:USERPROFILE\Downloads",
        "$env:LOCALAPPDATA\Temp",
        "$env:TEMP"
    )

    $items = [System.Collections.Generic.List[object]]::new()

    foreach ($target in $targets) {
        if (-not (Test-Path -LiteralPath $target)) { continue }

        Get-ChildItem -LiteralPath $target -File -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $file = $_
            if ($null -eq $file -or $null -eq $file.FullName) { return }

            $filePath = [string]$file.FullName
            $sourceName = [string]$file.Name
            $reasons = @()

            if ($sourceName -match "loader|dropper|inject|payload|rat|keylogger|adb|android|emulator|autorun|runonce|backdoor|fakeupdate|cash|shadows|vip") {
                $reasons += "Suspicious filename pattern"
            }

            if ($filePath -match "\\(Desktop|Downloads|Temp|Startup)\\.*(loader|dropper|payload|adb|android|emulator|autorun|runonce)") {
                $reasons += "Suspicious execution path"
            }

            $peReasons = Test-PEFileIndicators -Path $filePath
            if ((@($peReasons)).Count -gt 0) {
                $reasons += $peReasons
            }

            $scriptReasons = Test-ScriptFileIndicators -Path $filePath
            if ((@($scriptReasons)).Count -gt 0) {
                $reasons += $scriptReasons
            }

            if ((@($reasons)).Count -gt 0) {
                $items.Add([PSCustomObject]@{
                    Type = "File"
                    Path = $filePath
                    Hash = Get-FileHashSha256 -Path $filePath
                    Reasons = @($reasons)
                    Severity = if ((@($peReasons)).Count -gt 0) { "High" } else { "Medium" }
                }) | Out-Null
            }
        }
    }

    foreach ($key in @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce"
    )) {
        if (-not (Test-Path $key)) { continue }

        $props = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
        if (-not $props) { continue }

        foreach ($property in $props.PSObject.Properties) {
            $name = [string]$property.Name
            $value = [string]$property.Value
            $reasons = @()

            if ($name -match "loader|dropper|payload|adb|android|emulator|autorun|runonce|mshta|rundll32|regsvr32") {
                $reasons += "Registry key name is suspicious"
            }

            if ($value -match "powershell.*-nop.*-w.*hidden|frombase64string|rundll32|regsvr32|mshta|cmd\.exe.*\/c|http.*exe|start-process") {
                $reasons += "Registry command line is suspicious"
            }

            if ((@($reasons)).Count -gt 0) {
                $items.Add([PSCustomObject]@{
                    Type = "Registry"
                    Path = $key
                    Name = $name
                    Value = $value
                    Reasons = @($reasons)
                    Severity = "High"
                }) | Out-Null
            }
        }
    }

    return $items
}

function Remove-MalwareIndicators {
    $items = Get-MalwareIndicators
    if ($items.Count -eq 0) {
        Write-Status "No malware indicators found."
        return
    }

    Write-Host "" 
    Write-Host "Malware Indicators Found:" -ForegroundColor Red
    foreach ($item in $items) {
        if ($item.Type -eq "File") {
            $reasonText = ($item.Reasons -join "; ")
            Write-Host " - FILE [$($item.Severity)]: $($item.Path) [$reasonText]" -ForegroundColor Yellow
        }
        else {
            $reasonText = ($item.Reasons -join "; ")
            Write-Host " - REG [$($item.Severity)]: $($item.Path)\$($item.Name) = $($item.Value) [$reasonText]" -ForegroundColor Yellow
        }
    }

    if (-not (Confirm-Action "Delete these malicious items? (Y/N): ")) {
        Write-Status "Malware indicators left unchanged."
        return
    }

    foreach ($item in $items) {
        try {
            if ($item.Type -eq "File") {
                Remove-Item -LiteralPath $item.Path -Force -Recurse -ErrorAction Stop
                Write-Status "Removed malicious file: $($item.Path)"
            }
            else {
                Remove-ItemProperty -Path $item.Path -Name $item.Name -ErrorAction Stop
                Write-Status "Removed malicious startup entry: $($item.Path)\$($item.Name)"
            }
        }
        catch {
            Write-Status "Could not remove: $($item.Path)" "Yellow"
        }
    }
}

function Reset-NetworkStack {
    Write-Status "Resetting network stack..."
    netsh interface ip reset | Out-Null
    netsh winsock reset | Out-Null
    netsh interface ipv4 reset | Out-Null
    netsh interface ipv6 reset | Out-Null
    ipconfig /flushdns | Out-Null
    ipconfig /registerdns | Out-Null
    nbtstat -R | Out-Null
}

function Invoke-IntegrityChecks {
    Write-Status "Running Windows system file check..."
    sfc /scannow

    Write-Status "Running DISM restore health..."
    DISM.exe /Online /Cleanup-image /Restorehealth

    $defender = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"
    if (Test-Path $defender) {
        Write-Status "Running Microsoft Defender full scan..."
        & $defender -Scan -ScanType 2
    }
    else {
        Write-Status "Windows Defender not found." "Yellow"
    }
}

function Clear-RecycleBins {
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Za-z]:\\$' } | ForEach-Object {
        $driveLetter = $_.Name
        $recyclePath = "$driveLetter`:\$([char]36)Recycle.Bin"
        if (Test-Path -LiteralPath $recyclePath) {
            try {
                Clear-RecycleBin -DriveLetter $driveLetter -Force -ErrorAction Stop
                Write-Status "Cleared recycle bin for $driveLetter\\"
            }
            catch {
                Write-Status "Recycle bin for $driveLetter is already clean or inaccessible." "Yellow"
            }
        }
    }
}

function Show-Menu {
    Write-Host "" 
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host " Safe Deep Clean Tool" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "1. Quick Clean"
    Write-Host "2. Deep Clean"
    Write-Host "3. Full Security Check"
    Write-Host "4. Exit"
    Write-Host "==================================================" -ForegroundColor Cyan
}

function Invoke-QuickClean {
    Write-Status "Running Quick Clean..."
    Clear-DirectoryContents -Directory $env:TEMP -Description "User temp directory"
    Clear-DirectoryContents -Directory $env:LOCALAPPDATA\Temp -Description "Local temp directory"
    Clear-DirectoryContents -Directory $env:WINDIR\Temp -Description "Windows temp directory"
    Clear-SystemArtifacts
    Clear-BrowserCaches
    Clear-OldLogsAndDumps
    Clear-RecycleBins
    Write-Status "Quick clean finished."
}

function Invoke-DeepClean {
    Write-Status "Running Deep Clean..."
    Invoke-QuickClean
    Reset-NetworkStack
    Stop-SuspiciousProcesses
    Remove-SuspiciousServices
    Remove-SuspiciousScheduledTasks
    Remove-SuspiciousStartupEntries
    Remove-SuspiciousStartupFiles
    Remove-AutorunInfFiles
    Invoke-IntegrityChecks
    Write-Status "Deep clean finished."
}

function Invoke-FullSecurityCheck {
    Write-Status "Running Full Security Check..."
    Invoke-DeepClean
    Remove-MalwareIndicators
    Invoke-IntegrityChecks
    Write-Status "Full security check finished."
}

if (-not (Test-IsAdministrator)) {
    Write-Host ""
    Write-Host "[!] This script must be run as Administrator." -ForegroundColor Red
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -Verb RunAs
    exit
}

if ($MyInvocation.InvocationName -ne '.') {
    $Host.UI.RawUI.WindowTitle = "Safe Deep Clean Tool - created by PANDA"
    Write-Host ""
    Write-Status "Safe Deep Clean Tool is ready." "Cyan"

    while ($true) {
        Show-Menu
        $choice = Read-Host "Select an option"

        switch ($choice) {
            "1" {
                Invoke-QuickClean
                break
            }
            "2" {
                Invoke-DeepClean
                break
            }
            "3" {
                Invoke-FullSecurityCheck
                break
            }
            "4" {
                Write-Status "Exiting..."
                exit
            }
            default {
                Write-Status "Invalid option. Please select 1, 2, 3 or 4." "Yellow"
            }
        }

        Write-Host ""
        $continue = Read-Host "Do you want to return to the menu? (Y/N, Enter = Y)"
        if ([string]::IsNullOrWhiteSpace($continue) -or $continue -match "^(Y|YES)$") {
            continue
        }
        else {
            Write-Status "Exiting..."
            break
        }
    }
}

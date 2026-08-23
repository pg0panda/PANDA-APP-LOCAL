# Modern System Information Tool v3.0 - PowerShell Version
# Updated for Windows 10/11
# Version: 3.0 PowerShell Enhanced

# Check for Administrator privileges
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "[!] This script must be run as Administrator" -ForegroundColor Red
    Write-Host "[!] Restarting with admin rights..." -ForegroundColor Yellow
    
    # Relaunch the script with administrator privileges
    $psiArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process -FilePath "powershell.exe" -ArgumentList $psiArgs -Verb RunAs
    exit
}
# Set window title and color
$Host.UI.RawUI.WindowTitle = "Modern System Info Tool"
$Host.UI.RawUI.ForegroundColor = "Cyan"

# Variables
$script:cpuUsage = 0
$script:memPercent = 0

# Main Menu
function Show-MainMenu {
    Clear-Host
    Write-Host ""
    Write-Host "====================================================================================="
    Write-Host "                                    MAIN MENU"
    Write-Host "====================================================================================="
    Write-Host ""
    Write-Host "   AVAILABLE OPTIONS:"
    Write-Host ""
    Write-Host "   [1]  Complete System Overview"
    Write-Host "   [2]  Hardware Details"
    Write-Host "   [3]  Performance Analysis"
    Write-Host "   [4]  Network Diagnostics"
    Write-Host "   [5]  System Health Check"
    Write-Host "   [6]  Display Full Report"
    Write-Host "   [7]  Gaming Performance Info"
    Write-Host "   [0]  Exit"
    Write-Host ""
    $choice = Read-Host "Select option (0-7)"
    
    switch ($choice) {
        "1" { Show-SystemOverview }
        "2" { Show-HardwareDetails }
        "3" { Show-PerformanceAnalysis }
        "4" { Show-NetworkDiagnostics }
        "5" { Show-SystemHealthCheck }
        "6" { Show-FullReport }
        "7" { Show-GamingPerformance }
        "0" { Exit-Script }
        default { Show-MainMenu }
    }
}

# Function to display system overview
function Show-SystemOverview {
    Clear-Host
    Write-Host ""
    Write-Host "====================================================================================="
    Write-Host "                                  SYSTEM OVERVIEW"
    Write-Host "====================================================================================="
    Write-Host ""
    
    Write-Host "        BASIC SYSTEM INFO:"
    Write-Host ""
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Host "          OS: $($os.Caption)"
    Write-Host "          Version: $($os.Version)"
    
    $computer = Get-CimInstance Win32_ComputerSystem
    Write-Host "          Manufacturer: $($computer.Manufacturer)"
    Write-Host "          Model: $($computer.Model)"
    Write-Host "          User: $env:USERNAME"
    Write-Host "          Computer: $env:COMPUTERNAME"
    
    Write-Host ""
    Write-Host "        QUICK HARDWARE SUMMARY:"
    Write-Host ""
    
    $processor = Get-CimInstance Win32_Processor
    Write-Host "          CPU: $($processor.Name)"
    Write-Host "          RAM: $([math]::Round($computer.TotalPhysicalMemory/1GB)) GB"
    
    $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notlike "*Basic*" }
    foreach ($g in $gpu) {
        Write-Host "          GPU: $($g.Name)"
    }
    
    Write-Host ""
    Write-Host "          Last Boot: $($os.LastBootUpTime.ToString('dd/MM/yyyy HH:mm'))"
    Write-Host ""
    Write-Host "====================================================================================="
    Read-Host "Press Enter to continue"
    Show-MainMenu
}

# Function to display hardware details
function Show-HardwareDetails {
    Clear-Host
    Write-Host ""
    Write-Host "====================================================================================="
    Write-Host "                                    HARDWARE DETAILS"
    Write-Host "====================================================================================="
    Write-Host ""
    
    Write-Host "        PROCESSOR INFORMATION:"
    Write-Host ""
    $processor = Get-CimInstance Win32_Processor
    Write-Host "          Name: $($processor.Name)"
    Write-Host "          Cores: $($processor.NumberOfCores)"
    Write-Host "          Threads: $($processor.NumberOfLogicalProcessors)"
    Write-Host "          Max Speed: $([math]::Round($processor.MaxClockSpeed/1000, 1)) GHz"
    
    if ($processor.Architecture -eq 9) {
        Write-Host "          Architecture: x64"
    } elseif ($processor.Architecture -eq 0) {
        Write-Host "          Architecture: x86"
    }
    
    Write-Host ""
    Write-Host "        MEMORY INFORMATION:"
    Write-Host ""
    $sticks = Get-CimInstance Win32_PhysicalMemory
    $total = 0
    foreach ($stick in $sticks) {
        $gb = [math]::Round($stick.Capacity/1GB)
        Write-Host "          RAM Stick: $gb GB"
        $total += $gb
    }
    Write-Host "          Total RAM: $total GB"
    
    Write-Host ""
    Write-Host "        STORAGE INFORMATION:"
    Write-Host ""
    $disks = Get-CimInstance Win32_DiskDrive
    foreach ($disk in $disks) {
        Write-Host "          Drive: $($disk.Model)"
        Write-Host "          Size: $([math]::Round($disk.Size/1GB)) GB"
        Write-Host "          ────────────────────"
    }
    
    Write-Host ""
    Write-Host "        GRAPHICS INFORMATION:"
    Write-Host ""
    $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notlike "*Basic*" }
    foreach ($g in $gpu) {
        Write-Host "          GPU: $($g.Name)"
    }
    
    Write-Host ""
    Write-Host "====================================================================================="
    Read-Host "Press Enter to continue"
    Show-MainMenu
}

# Function to display performance analysis
function Show-PerformanceAnalysis {
    Clear-Host
    Write-Host ""
    Write-Host "====================================================================================="
    Write-Host "                                 PERFORMANCE ANALYSIS"
    Write-Host "====================================================================================="
    Write-Host ""
    
    Write-Host "        CURRENT SYSTEM PERFORMANCE:"
    Write-Host ""
    Write-Host "         Collecting performance data..."
    Write-Host ""
    
# CPU Usage - الطريقة الصحيحة
$cpu = Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 2 | 
       Select-Object -ExpandProperty CounterSamples | 
       Select-Object -Last 1
$cpuUsage = [math]::Round($cpu.CookedValue)
$script:cpuUsage = $cpuUsage

if ($cpuUsage -lt 30) {
    Write-Host "          CPU Usage: $cpuUsage% (Good)" -ForegroundColor Green
} elseif ($cpuUsage -lt 70) {
    Write-Host "          CPU Usage: $cpuUsage% (Moderate)" -ForegroundColor Yellow
} else {
    Write-Host "          CPU Usage: $cpuUsage% (High)" -ForegroundColor Red
}

    
    # Memory Usage
    $os = Get-CimInstance Win32_OperatingSystem
    $used = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1024
    $total = $os.TotalVisibleMemorySize * 1024
    $memPercent = [math]::Round(($used / $total) * 100)
    $script:memPercent = $memPercent
    
    if ($memPercent -lt 60) {
        Write-Host "          RAM Usage: $memPercent% (Good)"
    } elseif ($memPercent -lt 85) {
        Write-Host "          RAM Usage: $memPercent% (Moderate)"
    } else {
        Write-Host "          RAM Usage: $memPercent% (High)"
    }

    
    Write-Host ""
    Write-Host "        POWER INFORMATION:"
    Write-Host ""
    try {
        $battery = Get-CimInstance Win32_Battery -ErrorAction Stop
        if ($battery.BatteryStatus -eq 1) {
            Write-Host "          Battery: Discharging"
        } elseif ($battery.BatteryStatus -eq 2) {
            Write-Host "          Battery: Charging"
        } elseif ($battery.BatteryStatus -eq 3) {
            Write-Host "          Battery: Critical"
        } else {
            Write-Host "          Battery: Unknown status"
        }
        Write-Host "          Battery Level: $($battery.EstimatedChargeRemaining)%"
    } catch {
        Write-Host "          No battery detected (Desktop)"
    }
    
    Write-Host ""
    Write-Host "        PROCESS COUNT:"
    Write-Host "          Running Processes: $((Get-Process).Count)"
    
    Write-Host ""
    Write-Host "====================================================================================="
    Read-Host "Press Enter to continue"
    Show-MainMenu
}

# Function to display network diagnostics
function Show-NetworkDiagnostics {
    Clear-Host
    Write-Host ""
    Write-Host "====================================================================================="
    Write-Host "                                   NETWORK DIAGNOSTICS"
    Write-Host "====================================================================================="
    Write-Host ""
    
    Write-Host "        NETWORK ADAPTERS:"
    Write-Host ""
    $adapters = Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.NetEnabled -eq $true }
    foreach ($adapter in $adapters) {
        Write-Host "          $($adapter.Name)"
    }
    
    Write-Host ""
    Write-Host "        IP CONFIGURATION:"
    Write-Host ""
    $ipConfig = @(Get-CimInstance Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -and $_.IPAddress[0] -notmatch '^127\.' })
    if ($ipConfig.Count -gt 0) {
        foreach ($ip in $ipConfig) {
            if ($ip.IPAddress) {
                foreach ($addr in $ip.IPAddress) {
                    if ($addr -notmatch '^127\.') {
                        Write-Host "          IPv4: $addr"
                    }
                }
            }
            if ($ip.DefaultIPGateway) {
                foreach ($gw in $ip.DefaultIPGateway) {
                    Write-Host "          Gateway: $gw"
                }
            }
        }
    }
    else {
        Write-Host "          No IPv4 address detected via WMI fallback."
        $rawIp = ipconfig 2>$null | Out-String
        if ($rawIp) {
            $rawIp = [regex]::Matches($rawIp, 'IPv4 Address.*?: ([0-9.]+)')
            if ($rawIp.Count -gt 0) {
                foreach ($match in $rawIp) {
                    Write-Host "          IPv4: $($match.Groups[1].Value)"
                }
            }
        }
    }

    Write-Host ""
    Write-Host "        CONNECTIVITY TEST:"
    Write-Host "         Testing internet connection..."

    $internetTest = Test-Connection -ComputerName google.com -Count 2 -ErrorAction SilentlyContinue
    if ($internetTest) {
        Write-Host "          Internet: Connected"
    }
    else {
        Write-Host "          Internet: Disconnected"
    }

    $dnsTest = Test-Connection -ComputerName 8.8.8.8 -Count 2 -ErrorAction SilentlyContinue
    if ($dnsTest) {
        Write-Host "          DNS: Working"
    }
    else {
        Write-Host "          DNS: Issues detected"
    }

    Write-Host ""
    Write-Host "        NETWORK STATISTICS:"

    $stats = Get-NetAdapterStatistics -ErrorAction SilentlyContinue
    if ($stats) {
        foreach ($stat in $stats) {
            Write-Host "          Adapter: $($stat.Name)"
            Write-Host "          Bytes Sent: $($stat.SentBytes)"
            Write-Host "          Bytes Received: $($stat.ReceivedBytes)"
            Write-Host ""
        }
    }
    else {
        Write-Host "          Statistics unavailable on this system."
    }
    
    Write-Host ""
    Write-Host "====================================================================================="
    Read-Host "Press Enter to continue"
    Show-MainMenu
}


function Show-SystemHealthCheck {
    Clear-Host
    Write-Host ""
    Write-Host "====================================================================================="
    Write-Host "                                    SYSTEM HEALTH CHECK"
    Write-Host "====================================================================================="
    Write-Host ""
    
    Write-Host "        HEALTH DIAGNOSTICS:"
    Write-Host "         Running system health checks..."
    Write-Host ""
    
    $healthScore = 100
    
    # Check disk space
    $disk = Get-CimInstance Win32_LogicalDisk | Where-Object DeviceID -eq "C:"
    $freeGB = [math]::Round($disk.FreeSpace/1GB)
    if ($freeGB -lt 10) {
        Write-Host "          Low disk space on C: drive ($freeGB GB free)"
        $healthScore -= 15
    } else {
        Write-Host "          Disk space: OK ($freeGB GB free)"
    }
    
    # Check system file integrity
    Write-Host "          Checking system files..."
    $sfcResult = Start-Process -FilePath "sfc.exe" -ArgumentList "/verifyonly" -Wait -PassThru -WindowStyle Hidden
    if ($sfcResult.ExitCode -eq 0) {
        Write-Host "          System files: Intact"
    } else {
        Write-Host "          System files: May need repair"
        $healthScore -= 20
    }
    
    # Check for Windows updates
    Write-Host "          Checking update status..."
    $rebootRequired = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    if ($rebootRequired) {
        Write-Host "          Pending restart required"
        $healthScore -= 10
    } else {
        Write-Host "          No pending restarts"
    }
    
    # Check running services
    $wuauserv = Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue
    if ($wuauserv -and $wuauserv.Status -eq "Running") {
        Write-Host "          Windows Update service: Running"
    } else {
        Write-Host "          Windows Update service: Not running"
        $healthScore -= 5
    }
    
    # Check Windows Defender
    $defender = Get-Service -Name "WinDefend" -ErrorAction SilentlyContinue
    if ($defender -and $defender.Status -eq "Running") {
        Write-Host "          Windows Defender: Running"
    } else {
        Write-Host "          Windows Defender: Not running"
        $healthScore -= 10
    }
    
    Write-Host ""
    Write-Host "        SYSTEM HEALTH SCORE:"
    if ($healthScore -ge 90) {
        Write-Host "          Health Score: $healthScore/100 (Excellent)" -ForegroundColor Green
    } elseif ($healthScore -ge 70) {
        Write-Host "          Health Score: $healthScore/100 (Good)" -ForegroundColor Yellow
    } else {
        Write-Host "          Health Score: $healthScore/100 (Needs Attention)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "        RECOMMENDATIONS:"
    if ($healthScore -lt 90) {
        Write-Host "          • Run disk cleanup"
        Write-Host "          • Check for Windows updates"
        Write-Host "          • Consider system maintenance"
        Write-Host "          • Ensure antivirus is running"
    } else {
        Write-Host "          • System is running optimally"
        Write-Host "          • Continue regular maintenance"
    }
    
    Write-Host ""
    Write-Host "====================================================================================="
    Read-Host "Press Enter to continue"
    Show-MainMenu
}



function Show-GamingPerformance {
    Clear-Host
    Write-Host ""
    Write-Host "====================================================================================="
    Write-Host "                                     GAMING PERFORMANCE INFO"
    Write-Host "====================================================================================="
    Write-Host ""
    
    Write-Host "        GAMING READINESS CHECK:"
    Write-Host ""
    
    # DirectX Version
    $directX = Test-Path "HKLM:\SOFTWARE\Microsoft\DirectX"
    if ($directX) {
        Write-Host "          DirectX: Installed"
    } else {
        Write-Host "          DirectX: Not found"
    }
    
    # Check for gaming-related software
    $steam = Get-Process -Name "Steam" -ErrorAction SilentlyContinue
    if ($steam) {
        Write-Host "          Steam: Running"
    } else {
        Write-Host "          Steam: Not running"
    }
    
    $discord = Get-Process -Name "Discord" -ErrorAction SilentlyContinue
    if ($discord) {
        Write-Host "          Discord: Running"
    } else {
        Write-Host "          Discord: Not running"
    }
    
    Write-Host ""
    Write-Host "        GRAPHICS PERFORMANCE:"
    Write-Host ""
    $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notlike "*Basic*" } | Select-Object -First 1
    if ($gpu) {
        Write-Host "          GPU: $($gpu.Name)"
        if ($gpu.Name -like "*RTX*") {
            Write-Host "          Ray Tracing: Supported"
        }
        if ($gpu.Name -like "*GTX*") {
            Write-Host "          Gaming: Optimized"
        }
        if ($gpu.Name -like "*Intel*") {
            Write-Host "          Integrated: Basic gaming"
        }
        if ($gpu.Name -like "*AMD*") {
            Write-Host "          Gaming: Optimized"
        }
    }
    
    Write-Host ""
    Write-Host "        GAMING RECOMMENDATIONS:"
    Write-Host ""
    $computer = Get-CimInstance Win32_ComputerSystem
    $totalRAM = [math]::Round($computer.TotalPhysicalMemory/1GB)
    if ($totalRAM -ge 32) {
        Write-Host "          RAM: Excellent for gaming ($totalRAM GB)"
    } elseif ($totalRAM -ge 16) {
        Write-Host "          RAM: Great for gaming ($totalRAM GB)"
    } elseif ($totalRAM -ge 8) {
        Write-Host "          RAM: Good for gaming ($totalRAM GB)"
    } else {
        Write-Host "          RAM: Consider upgrade ($totalRAM GB)"
    }
    
    if ($script:cpuUsage -lt 50) {
        Write-Host "          CPU: Ready for gaming"
    } else {
        Write-Host "          CPU: High usage, close background apps"
    }
    
    if ($script:memPercent -lt 70) {
        Write-Host "          RAM: Available for gaming"
    } else {
        Write-Host "          RAM: High usage, close background apps"
    }
    
    Write-Host ""
    Write-Host "        GAMING OPTIMIZATION TIPS:"
    Write-Host "          • Close unnecessary background applications"
    Write-Host "          • Update graphics drivers regularly"
    Write-Host "          • Enable Game Mode in Windows settings"
    Write-Host "          • Consider SSD for faster loading times"
    Write-Host "          • Adjust graphics settings for optimal performance"
    Write-Host "          • Keep system updated"
    
    Write-Host ""
    Write-Host "====================================================================================="
    Read-Host "Press Enter to continue"
    Show-MainMenu
}



function Show-FullReport {
    Clear-Host
    Write-Host ""
    Write-Host "====================================================================================="
    Write-Host "                         COMPLETE DETAILED SYSTEM INFORMATION REPORT"
    Write-Host "====================================================================================="
    Write-Host ""
    Write-Host "Generated: $(Get-Date)"
    Write-Host "User: $env:USERNAME"
    Write-Host "Computer: $env:COMPUTERNAME"
    Write-Host ""

    $computer = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $baseboard = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
    $os = Get-CimInstance Win32_OperatingSystem
    $processor = Get-CimInstance Win32_Processor
    $memoryModules = Get-CimInstance Win32_PhysicalMemory
    $video = Get-CimInstance Win32_VideoController
    $disks = Get-CimInstance Win32_DiskDrive
    $logicalDisks = Get-CimInstance Win32_LogicalDisk
    $networkAdapters = Get-NetAdapter -ErrorAction SilentlyContinue
    $ipConfig = @(Get-CimInstance Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -and $_.IPAddress[0] -notmatch '^127\.' })
    $routes = @(Get-CimInstance Win32_IP4RouteTable -ErrorAction SilentlyContinue)
    $dns = @(Get-DnsClientServerAddress -ErrorAction SilentlyContinue)
    $updates = Get-HotFix -ErrorAction SilentlyContinue
    $services = Get-Service | Sort-Object Name
    $startupCommands = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue
    $users = Get-LocalUser -ErrorAction SilentlyContinue
    $processes = Get-Process | Sort-Object CPU -Descending | Select-Object -First 15

    Write-Host "====================================================================================="
    Write-Host "                               1. SYSTEM IDENTIFICATION"
    Write-Host "====================================================================================="
    Write-Host "Manufacturer: $($computer.Manufacturer)"
    Write-Host "Model: $($computer.Model)"
    Write-Host "Domain: $($computer.Domain)"
    Write-Host "Workgroup: $($computer.Workgroup)"
    Write-Host "System Type: $($computer.SystemType)"
    Write-Host "Total Physical Memory: $([math]::Round($computer.TotalPhysicalMemory / 1GB, 2)) GB"
    Write-Host "Name: $($computer.Name)"
    Write-Host "User: $env:USERNAME"
    Write-Host "Computer Name: $env:COMPUTERNAME"
    Write-Host ""

    Write-Host "====================================================================================="
    Write-Host "                               2. OPERATING SYSTEM"
    Write-Host "====================================================================================="
    Write-Host "OS Name: $($os.Caption)"
    Write-Host "Version: $($os.Version)"
    Write-Host "Build: $($os.BuildNumber)"
    Write-Host "Architecture: $([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)"
    Write-Host "Install Date: $($os.InstallDate.ToString('dd/MM/yyyy HH:mm'))"
    Write-Host "Last Boot: $($os.LastBootUpTime.ToString('dd/MM/yyyy HH:mm'))"
    Write-Host "System Directory: $($os.SystemDirectory)"
    Write-Host "Windows Directory: $($os.WindowsDirectory)"
    Write-Host ""

    Write-Host "====================================================================================="
    Write-Host "                               3. BIOS / MOTHERBOARD"
    Write-Host "====================================================================================="
    Write-Host "BIOS Manufacturer: $($bios.Manufacturer)"
    Write-Host "BIOS Name: $($bios.Name)"
    Write-Host "BIOS Version: $($bios.Version)"
    Write-Host "BIOS Serial: $($bios.SerialNumber)"
    if ($baseboard) {
        Write-Host "Motherboard Manufacturer: $($baseboard.Manufacturer)"
        Write-Host "Motherboard Product: $($baseboard.Product)"
        Write-Host "Motherboard Version: $($baseboard.Version)"
        Write-Host "Motherboard Serial: $($baseboard.SerialNumber)"
    }
    Write-Host ""

    Write-Host "====================================================================================="
    Write-Host "                               4. PROCESSOR DETAILS"
    Write-Host "====================================================================================="
    Write-Host "CPU Name: $($processor.Name)"
    Write-Host "Cores: $($processor.NumberOfCores)"
    Write-Host "Logical Processors: $($processor.NumberOfLogicalProcessors)"
    Write-Host "Socket Designation: $($processor.SocketDesignation)"
    Write-Host "Max Clock Speed: $([math]::Round($processor.MaxClockSpeed / 1000, 2)) GHz"
    Write-Host "Manufacturer: $($processor.Manufacturer)"
    Write-Host "Architecture: $($processor.Architecture)"
    Write-Host "Processor ID: $($processor.ProcessorId)"
    Write-Host "L2 Cache: $($processor.L2Cache) KB"
    Write-Host "L3 Cache: $($processor.L3Cache) KB"
    Write-Host ""

    Write-Host "====================================================================================="
    Write-Host "                               5. MEMORY / RAM"
    Write-Host "====================================================================================="
    $totalRamGB = 0
    foreach ($module in $memoryModules) {
        $capacityGB = [math]::Round($module.Capacity / 1GB, 2)
        $totalRamGB += $capacityGB
        Write-Host "RAM Module: $($module.Manufacturer) $capacityGB GB @ $($module.ConfiguredClockSpeed) MHz"
    }
    Write-Host "Total Installed RAM: $totalRamGB GB"
    Write-Host "Available Memory: $([math]::Round(($os.FreePhysicalMemory / 1024 / 1024), 2)) GB"
    Write-Host ""

    Write-Host "====================================================================================="
    Write-Host "                               6. STORAGE / DISKS"
    Write-Host "====================================================================================="
    foreach ($disk in $disks) {
        $sizeGB = [math]::Round($disk.Size / 1GB, 2)
        Write-Host "Disk Model: $($disk.Model)"
        Write-Host "Disk Size: $sizeGB GB"
        Write-Host "Interface Type: $($disk.InterfaceType)"
        Write-Host "Media Type: $($disk.MediaType)"
        Write-Host "Serial Number: $($disk.SerialNumber)"
        Write-Host ""
    }

    foreach ($drive in $logicalDisks) {
        $sizeGB = [math]::Round($drive.Size / 1GB, 2)
        $freeGB = [math]::Round($drive.FreeSpace / 1GB, 2)
        Write-Host "Drive: $($drive.DeviceID) | FS: $($drive.FileSystem) | Size: $sizeGB GB | Free: $freeGB GB | Used: $([math]::Round(($drive.Size - $drive.FreeSpace) / 1GB, 2)) GB"
    }
    Write-Host ""

    Write-Host "====================================================================================="
    Write-Host "                               7. GRAPHICS / GPU"
    Write-Host "====================================================================================="
    foreach ($g in $video) {
        Write-Host "GPU: $($g.Name)"
        Write-Host "GPU Manufacturer: $($g.AdapterCompatibility)"
        Write-Host "Driver Version: $($g.DriverVersion)"
        Write-Host "Video Memory: $([math]::Round($g.AdapterRAM / 1MB, 2)) MB"
        Write-Host "Current Resolution: $($g.CurrentHorizontalResolution) x $($g.CurrentVerticalResolution)"
        Write-Host ""
    }

    Write-Host "====================================================================================="
    Write-Host "                               8. NETWORK ADAPTERS"
    Write-Host "====================================================================================="
    if ($networkAdapters) {
        foreach ($adapter in $networkAdapters) {
            Write-Host "Adapter: $($adapter.Name)"
            Write-Host "Interface Description: $($adapter.InterfaceDescription)"
            Write-Host "Status: $($adapter.Status)"
            Write-Host "MAC: $($adapter.MacAddress)"
            Write-Host "Link Speed: $($adapter.LinkSpeed)"
            Write-Host ""
        }
    }

    foreach ($ip in $ipConfig) {
        if ($ip.IPAddress) {
            foreach ($addr in $ip.IPAddress) {
                if ($addr -notmatch '^127\.') {
                    Write-Host "IPv4: $addr | Prefix: $($ip.IPSubnet) | InterfaceAlias: $($ip.Description)"
                }
            }
        }
    }

    foreach ($route in $routes) {
        if ($route.Destination -eq '0.0.0.0' -and $route.Type -eq 3) {
            Write-Host "Default Gateway: $($route.NextHop)"
        }
    }

    if ($dns) {
        foreach ($entry in $dns) {
            Write-Host "DNS: Interface $($entry.InterfaceAlias) -> $($entry.ServerAddresses -join ', ')"
        }
    }
    else {
        Write-Host "DNS: No DNS records available via Get-DnsClientServerAddress"
    }
    Write-Host ""

    Write-Host "====================================================================================="
    Write-Host "                               9. CONNECTION TEST"
    Write-Host "====================================================================================="
    $internet = Test-Connection -ComputerName google.com -Count 2 -ErrorAction SilentlyContinue
    if ($internet) {
        Write-Host "Internet Connectivity: Connected"
        foreach ($item in $internet) {
            Write-Host "Ping: $($item.Address) | Status: $($item.ResponseTime) ms"
        }
    }
    else {
        Write-Host "Internet Connectivity: Not connected"
    }
    Write-Host ""

    Write-Host "====================================================================================="
    Write-Host "                               10. WINDOWS UPDATES"
    Write-Host "====================================================================================="
    if ($updates) {
        foreach ($update in $updates | Select-Object -First 20) {
            Write-Host "HotFix: $($update.HotFixID) | Installed: $($update.InstalledOn)"
        }
    }
    else {
        Write-Host "No HotFix information found."
    }
    Write-Host ""

    Write-Host "====================================================================================="
    Write-Host "                               11. SERVICES"
    Write-Host "====================================================================================="
    foreach ($svc in $services | Select-Object -First 40) {
        Write-Host "Service: $($svc.Name) | Status: $($svc.Status) | StartType: $($svc.StartType)"
    }
    Write-Host ""

    Write-Host "====================================================================================="
    Write-Host "                               12. STARTUP PROGRAMS"
    Write-Host "====================================================================================="
    if ($startupCommands) {
        foreach ($item in $startupCommands | Select-Object -First 30) {
            Write-Host "Startup: $($item.Name) | Command: $($item.Command)"
        }
    }
    else {
        Write-Host "No startup entries found."
    }
    Write-Host ""

    Write-Host "====================================================================================="
    Write-Host "                               13. LOCAL USERS"
    Write-Host "====================================================================================="
    if ($users) {
        foreach ($user in $users) {
            Write-Host "User: $($user.Name) | Enabled: $($user.Enabled) | Description: $($user.Description)"
        }
    }
    else {
        Write-Host "No local users found."
    }
    Write-Host ""

    Write-Host "====================================================================================="
    Write-Host "                               14. TOP PROCESSES"
    Write-Host "====================================================================================="
    foreach ($proc in $processes) {
        Write-Host "Process: $($proc.ProcessName) | PID: $($proc.Id) | CPU: $($proc.CPU) ms | Memory: $([math]::Round($proc.WorkingSet64 / 1MB, 2)) MB"
    }
    Write-Host ""

    Write-Host "====================================================================================="
    Write-Host "                               15. REPORT COMPLETION"
    Write-Host "====================================================================================="
    Write-Host "Detailed report completed successfully."
    Write-Host "Press Enter to continue..."
    [void][System.Console]::ReadLine()
    Show-MainMenu
}



function Exit-Script {
    Clear-Host
    Write-Host ""
    Write-Host "================================================================================"
    Write-Host "                                   GOODBYE!"
    Write-Host "================================================================================"
    Write-Host ""
    Write-Host "     Thank you for using System Info Tool v3.0"
    Write-Host ""
    Stop-Process -Id $PID
}

# Start the script
Show-MainMenu
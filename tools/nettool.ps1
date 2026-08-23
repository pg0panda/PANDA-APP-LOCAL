# Advanced Network Repair Tool v3.0 - PowerShell Version
# Created by PANDA
# Purpose: Powerful, practical, and deep network repair and troubleshooting

# Check for Administrator privileges
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "[!] This script must be run as Administrator" -ForegroundColor Red
    Write-Host "[!] Restarting with admin rights..." -ForegroundColor Yellow
    $psiArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process -FilePath "powershell.exe" -ArgumentList $psiArgs -Verb RunAs | Out-Null
    exit
}

# Set window title and color
$Host.UI.RawUI.WindowTitle = "Advanced Network Repair Tool v3.0 - Created by PANDA"
$Host.UI.RawUI.ForegroundColor = "Cyan"

# Variables
$script:logfile = "$env:TEMP\network_repair_log.txt"
$script:statefile = "$env:TEMP\network_tool_state.ini"
$script:lastdns = "Unknown"
$script:netif = ""

if (Test-Path $script:statefile) {
    $script:lastdns = Get-Content $script:statefile -ErrorAction SilentlyContinue | Select-Object -Last 1
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
    Add-Content -Path $script:logfile -Value "[$timestamp] $Message" -ErrorAction SilentlyContinue
}

function Test-OperationSuccess {
    param(
        [string]$TaskName,
        [int]$ErrorCode
    )

    if ($ErrorCode -eq 0) {
        Write-Host "SUCCESS: $TaskName" -ForegroundColor Green
    }
    else {
        Write-Host "FAILED: $TaskName (ErrorLevel=$ErrorCode)" -ForegroundColor Red
    }

    Write-Log -Message "$TaskName - ErrorLevel: $ErrorCode"
}

function Get-ActiveAdapters {
    $adapters = Get-InterfaceCandidates
    if (-not $adapters) { return @() }
    return @($adapters | Where-Object { $_.Status -notin @("Not Present", "Disconnected", "Down", "Unknown") })
}

function Get-WmiNetworkAdaptersFallback {
    $results = @()

    $rawAdapters = Get-WmiObject -Class Win32_NetworkAdapter -ErrorAction SilentlyContinue
    if (-not $rawAdapters) { return @() }

    foreach ($adapter in $rawAdapters) {
        $name = $adapter.NetConnectionID
        if (-not $name) { $name = $adapter.Name }
        if (-not $name) { continue }

        $status = switch ($adapter.NetConnectionStatus) {
            0 { 'Disconnected' }
            1 { 'Disconnected' }
            2 { 'Connecting' }
            3 { 'Connected' }
            4 { 'Connected' }
            5 { 'Disconnected' }
            6 { 'Disconnected' }
            7 { 'Disconnected' }
            default { 'Unknown' }
        }

        $results += [pscustomobject]@{
            Name = $name
            Status = $status
            InterfaceDescription = $adapter.Name
            MacAddress = $adapter.MACAddress
            LinkSpeed = 'Unknown'
        }
    }

    return @($results)
}

function Get-InterfaceCandidates {
    $adapters = @(Get-NetAdapter -ErrorAction SilentlyContinue)
    if ($adapters.Count -gt 0) {
        $usable = $adapters | Where-Object { $_.Status -notin @("Not Present", "Disconnected", "Down", "Unknown") }
        if ($usable) { return @($usable) }
        return @($adapters)
    }

    $fallback = Get-WmiNetworkAdaptersFallback
    if ($fallback.Count -gt 0) {
        $usable = $fallback | Where-Object { $_.Status -notin @("Not Present", "Disconnected", "Down", "Unknown") }
        if ($usable) { return @($usable) }
        return @($fallback)
    }

    return @()
}

function Ensure-NetworkServicesRunning {
    $servicesToCheck = @("Dhcp", "Dnscache", "Netman", "NlaSvc")

    foreach ($serviceName in $servicesToCheck) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if (-not $service) {
            Write-Host "INFO: Service '$serviceName' not found on this system; skipping." -ForegroundColor Yellow
            continue
        }

        if ($service.Status -ne "Running") {
            Write-Host "Starting service: $serviceName" -ForegroundColor Yellow
            try {
                Start-Service -Name $serviceName -ErrorAction Stop | Out-Null
                Write-Host "SUCCESS: Service '$serviceName' started." -ForegroundColor Green
                Write-Log -Message "Started service: $serviceName"
            }
            catch {
                Write-Host "WARNING: Could not start service '$serviceName'." -ForegroundColor Yellow
                Write-Log -Message "Failed to start service: $serviceName"
            }
        }
        else {
            Write-Host "SERVICE OK: $serviceName is already running." -ForegroundColor Green
        }
    }
}

function Restart-NetworkAdapters {
    $adapters = Get-InterfaceCandidates
    $adapterCount = 0
    $successCount = 0

    Write-Host "[+] Discovering network adapters..."

    foreach ($adapter in $adapters) {
        $adapterCount++
        Write-Host "[$adapterCount] Restarting: $($adapter.Name)"
        $restartSucceeded = $false

        try {
            if (Get-Command Disable-NetAdapter -ErrorAction SilentlyContinue) {
                Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop | Out-Null
                Start-Sleep -Seconds 2
                Enable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop | Out-Null
                $restartSucceeded = $true
            }
            else {
                netsh interface set interface name="$($adapter.Name)" admin=disabled | Out-Null
                Start-Sleep -Seconds 2
                netsh interface set interface name="$($adapter.Name)" admin=enabled | Out-Null
                $restartSucceeded = $true
            }
        }
        catch {
            Write-Host "WARNING: Could not restart adapter `"$($adapter.Name)`" due to OS/driver restrictions. Trying DHCP refresh only..." -ForegroundColor Yellow
            Write-Log -Message "Failed to restart adapter: $($adapter.Name)"
        }

        if (-not $restartSucceeded) {
            try {
                Renew-InterfaceIp -AdapterName $adapter.Name
                $restartSucceeded = $true
            }
            catch {
                Write-Host "INFO: Adapter restart not supported for this interface; DHCP refresh was attempted instead." -ForegroundColor Yellow
            }
        }

        if ($restartSucceeded) {
            $successCount++
            Write-Host "SUCCESS: Adapter `"$($adapter.Name)`" processed" -ForegroundColor Green
            Write-Log -Message "Processed adapter: $($adapter.Name)"
        }

        Start-Sleep -Seconds 1
    }

    if ($adapterCount -eq 0) {
        Write-Host "INFO: No connected adapters found." -ForegroundColor Yellow
    }
    else {
        Write-Host "SUMMARY: $successCount out of $adapterCount adapters processed successfully." -ForegroundColor Cyan
    }
}

function Choose-Adapter {
    $adapters = Get-InterfaceCandidates
    $fallbackNames = @("Ethernet", "Wi-Fi", "Local Area Connection", "Ethernet 2", "Wireless Network Connection", "LAN", "Network")

    if (-not $adapters) {
        $adapters = @()
        foreach ($name in $fallbackNames) {
            $adapter = Get-NetAdapter -Name $name -ErrorAction SilentlyContinue
            if ($adapter) { $adapters += $adapter }
        }
    }

    if (-not $adapters) {
        Write-Host "ERROR: No network interfaces detected on this system." -ForegroundColor Red
        return $null
    }

    Write-Host "Available network interfaces:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $adapters.Count; $i++) {
        Write-Host "[$($i + 1)] $($adapters[$i].Name)"
    }

    $choice = Read-Host "Select interface number"
    if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $adapters.Count) {
        return $adapters[[int]$choice - 1].Name
    }

    foreach ($name in $fallbackNames) {
        $adapter = Get-NetAdapter -Name $name -ErrorAction SilentlyContinue
        if ($adapter) { return $adapter.Name }
    }

    return $adapters[0].Name
}

function Renew-InterfaceIp {
    param([string]$AdapterName)

    if (-not $AdapterName) { return }

    Write-Host "Refreshing IP for: $AdapterName" -ForegroundColor Yellow

    $before = (Get-NetIPAddress -InterfaceAlias $AdapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IPAddress -First 1)
    if (-not $before) { $before = 'Unknown' }
    Write-Host "Before: $before" -ForegroundColor Yellow

    try {
        ipconfig /release "$AdapterName" | Out-Null
        Start-Sleep -Seconds 2
        ipconfig /renew "$AdapterName" | Out-Null
    }
    catch {
        Write-Host "IP release/renew fallback failed for $AdapterName" -ForegroundColor Yellow
    }

    try {
        netsh interface ipv4 set address name="$AdapterName" source=dhcp | Out-Null
        netsh interface ipv4 set dns name="$AdapterName" source=dhcp | Out-Null
        Write-Host "DHCP force-refresh applied to $AdapterName" -ForegroundColor Yellow
    }
    catch {
        Write-Host "Could not force DHCP refresh for $AdapterName" -ForegroundColor Red
    }

    $after = (Get-NetIPAddress -InterfaceAlias $AdapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IPAddress -First 1)
    if (-not $after) { $after = 'Unknown' }
    Write-Host "After: $after" -ForegroundColor Green

    Write-Host "Current IP result for ${AdapterName}:" -ForegroundColor Cyan
    ipconfig | Select-String -Pattern "IPv4 Address|DNS Servers|Ethernet|Wi-Fi|Wireless LAN adapter" -Context 0,2 | Select-Object -First 16 | ForEach-Object { Write-Host $_ }
}

function Full-Network-Repair {
    Clear-Host
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║               Advanced Network Repair / Full Reset               ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Running a deep network reset..." -ForegroundColor Yellow
    Write-Host ""

    Ensure-NetworkServicesRunning
    Write-Host ""

    Write-Host "[1/10] Flushing DNS cache..."
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Test-OperationSuccess -TaskName "DNS Cache Flush" -ErrorCode $LASTEXITCODE

    Write-Host "[2/10] Resetting Winsock..."
    netsh winsock reset | Out-Null
    Test-OperationSuccess -TaskName "Winsock Reset" -ErrorCode $LASTEXITCODE

    Write-Host "[3/10] Resetting IPv4 TCP/IP stack..."
    netsh int ip reset "$env:TEMP\netreset_ipv4.txt" | Out-Null
    Test-OperationSuccess -TaskName "IPv4 Reset" -ErrorCode $LASTEXITCODE

    Write-Host "[4/10] Resetting IPv6 stack..."
    netsh int ipv6 reset "$env:TEMP\netreset_ipv6.txt" | Out-Null
    Test-OperationSuccess -TaskName "IPv6 Reset" -ErrorCode $LASTEXITCODE

    Write-Host "[5/10] Resetting WinHTTP proxy..."
    netsh winhttp reset proxy | Out-Null
    Test-OperationSuccess -TaskName "WinHTTP Proxy Reset" -ErrorCode $LASTEXITCODE

    Write-Host "[6/10] Resetting firewall..."
    netsh advfirewall reset | Out-Null
    Test-OperationSuccess -TaskName "Firewall Reset" -ErrorCode $LASTEXITCODE

    Write-Host "[7/10] Clearing ARP table..."
    arp -d * | Out-Null
    Test-OperationSuccess -TaskName "ARP Cache Clear" -ErrorCode $LASTEXITCODE

    Write-Host "[8/10] Releasing and renewing IP addresses..."
    $interfaces = Get-InterfaceCandidates
    foreach ($adapter in $interfaces) {
        Write-Host "Refreshing adapter: $($adapter.Name)"
        try {
            ipconfig /release "$($adapter.Name)" | Out-Null
            Start-Sleep -Seconds 2
            ipconfig /renew "$($adapter.Name)" | Out-Null
            Write-Log -Message "Renewed IP for adapter: $($adapter.Name)"
        }
        catch {
            Write-Host "Could not renew IP on: $($adapter.Name)" -ForegroundColor Yellow
            Write-Log -Message "Failed IP renew on adapter: $($adapter.Name)"
        }
    }
    Test-OperationSuccess -TaskName "IP Renew" -ErrorCode 0

    Write-Host "[9/10] Registering DNS..."
    ipconfig /registerdns | Out-Null
    Test-OperationSuccess -TaskName "DNS Registration" -ErrorCode $LASTEXITCODE

    Write-Host "[10/10] Restarting network adapters..."
    Restart-NetworkAdapters

    Write-Host ""
    Write-Host "SUCCESS: Deep network repair has been completed." -ForegroundColor Green
    Write-Host "NOTE: A reboot may still be required for all settings to fully apply." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to continue"
    Show-MainMenu
}

function DNS-Flush {
    Clear-Host
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                      DNS Cache Flush                             ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Flushing DNS cache..."
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Test-OperationSuccess -TaskName "DNS Cache Flush" -ErrorCode $LASTEXITCODE
    Write-Host ""
    Read-Host "Press Enter to continue"
    Show-MainMenu
}

function Winsock-Reset {
    Clear-Host
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                Reset Winsock / TCP-IP Stack                      ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Resetting Winsock..."
    netsh winsock reset | Out-Null
    Test-OperationSuccess -TaskName "Winsock Reset" -ErrorCode $LASTEXITCODE
    Write-Host ""
    Write-Host "Resetting TCP/IP..."
    netsh int ip reset "$env:TEMP\netreset_tcpip.txt" | Out-Null
    Test-OperationSuccess -TaskName "TCP/IP Reset" -ErrorCode $LASTEXITCODE
    Write-Host ""
    Write-Host "WARNING: A system restart is recommended after the reset." -ForegroundColor Yellow
    Read-Host "Press Enter to continue"
    Show-MainMenu
}

function Adapter-Restart {
    Clear-Host
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    Restart Network Adapters                      ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Restart-NetworkAdapters
    Write-Host ""
    Read-Host "Press Enter to continue"
    Show-MainMenu
}

function IP-Renew {
    Clear-Host

    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    IP / MAC MANAGER                            ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    try {

        # ============================================================
        # Detect active physical adapter
        # ============================================================

        $adapter = Get-WmiObject Win32_NetworkAdapter |
            Where-Object {
                $_.NetConnectionStatus -eq 2 -and
                $_.PhysicalAdapter -eq $true -and
                $_.NetConnectionID -and
                $_.Name -notmatch "Virtual|VPN|Bluetooth|Teredo|Loopback"
            } |
            Select-Object -First 1

        if (-not $adapter) {
            Write-Host "ERROR: No active physical network adapter found." -ForegroundColor Red
            Read-Host "Press Enter to continue"
            Show-MainMenu
            return
        }

        $adapterName = $adapter.NetConnectionID
        $index       = $adapter.Index
        $oldMac      = $adapter.MACAddress

        # ============================================================
        # Read current configuration
        # ============================================================

        $config = Get-WmiObject Win32_NetworkAdapterConfiguration `
            -Filter "Index=$index" `
            -ErrorAction Stop

        $oldIPv4 = $config.IPAddress |
            Where-Object {
                $_ -match '^\d{1,3}(\.\d{1,3}){3}$' -and
                $_ -notlike "169.254.*"
            } |
            Select-Object -First 1

        $oldIPv6 = $config.IPAddress |
            Where-Object {
                $_ -match ':' -and
                $_ -notlike "fe80::*"
            } |
            Select-Object -First 1

        $oldGateway = $config.DefaultIPGateway |
            Where-Object {
                $_ -match '^\d{1,3}(\.\d{1,3}){3}$'
            } |
            Select-Object -First 1

        $oldSubnet = $config.IPSubnet |
            Where-Object {
                $_ -match '^\d{1,3}(\.\d{1,3}){3}$'
            } |
            Select-Object -First 1

        if (-not $oldSubnet) {
            $oldSubnet = "255.255.255.0"
        }

        # Save DNS
        $oldDNS = @(
            $config.DNSServerSearchOrder |
                Where-Object {
                    $_ -and
                    (
                        $_ -match '^\d{1,3}(\.\d{1,3}){3}$' -or
                        $_ -match ':'
                    )
                }
        )

        # Save DHCP state
        $wasDHCP = $config.DHCPEnabled

        Write-Host "Adapter : $adapterName" -ForegroundColor Cyan
        Write-Host "Device  : $($adapter.Name)" -ForegroundColor DarkGray
        Write-Host "MAC     : $oldMac" -ForegroundColor Yellow
        Write-Host "IPv4    : $oldIPv4" -ForegroundColor Yellow
        Write-Host "IPv6    : $oldIPv6" -ForegroundColor Yellow
        Write-Host "Gateway : $oldGateway" -ForegroundColor DarkGray

        if ($oldDNS.Count -gt 0) {
            Write-Host "DNS     : $($oldDNS -join ', ')" -ForegroundColor DarkGray
        }
        else {
            Write-Host "DNS     : Automatic / Router" -ForegroundColor DarkGray
        }

        Write-Host ""

        # ============================================================
        # Helper: Generate random MAC
        # ============================================================

        function New-RandomMac {
            $bytes = New-Object byte[] 6

            $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
            $rng.GetBytes($bytes)
            $rng.Dispose()

            # Locally administered + unicast
            $bytes[0] = ($bytes[0] -bor 2) -band 254

            return (($bytes | ForEach-Object {
                $_.ToString("X2")
            }) -join "")
        }

        # ============================================================
        # Helper: Find adapter registry key
        # ============================================================

        function Find-AdapterRegistryKey {

            $classPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"

            foreach ($key in Get-ChildItem $classPath -ErrorAction SilentlyContinue) {

                if ($key.PSChildName -notmatch "^\d{4}$") {
                    continue
                }

                $props = Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue

                if ($props.NetCfgInstanceId -eq $adapter.GUID) {
                    return $key
                }

                if ($props.PNPDeviceID -eq $adapter.PNPDeviceID) {
                    return $key
                }
            }

            return $null
        }

        # ============================================================
        # Helper: Change MAC
        # ============================================================

        function Set-AdapterMAC {
            param(
                [Parameter(Mandatory=$true)]
                [string]$RequestedMac
            )

            $key = Find-AdapterRegistryKey

            if (-not $key) {
                throw "Could not find adapter registry entry."
            }

            Set-ItemProperty `
                -Path $key.PSPath `
                -Name "NetworkAddress" `
                -Value $RequestedMac `
                -ErrorAction Stop

            Write-Host "MAC override written successfully." -ForegroundColor Green

            # Restart adapter
            $currentAdapter = Get-WmiObject Win32_NetworkAdapter `
                -Filter "Index=$index"

            $currentAdapter.Disable() | Out-Null

            Start-Sleep -Seconds 3

            $currentAdapter = Get-WmiObject Win32_NetworkAdapter `
                -Filter "Index=$index"

            $currentAdapter.Enable() | Out-Null

            Write-Host "Waiting for network..." -ForegroundColor Yellow

            Start-Sleep -Seconds 8

            $verifyAdapter = Get-WmiObject Win32_NetworkAdapter `
                -Filter "Index=$index"

            return $verifyAdapter.MACAddress
        }

        # ============================================================
        # Helper: Get current IPv4
        # ============================================================

        function Get-CurrentIPv4 {

            $c = Get-WmiObject Win32_NetworkAdapterConfiguration `
                -Filter "Index=$index" `
                -ErrorAction SilentlyContinue

            return $c.IPAddress |
                Where-Object {
                    $_ -match '^\d{1,3}(\.\d{1,3}){3}$' -and
                    $_ -notlike "169.254.*"
                } |
                Select-Object -First 1
        }

        # ============================================================
        # Helper: Get current IPv6
        # ============================================================

        function Get-CurrentIPv6 {

            $c = Get-WmiObject Win32_NetworkAdapterConfiguration `
                -Filter "Index=$index" `
                -ErrorAction SilentlyContinue

            return $c.IPAddress |
                Where-Object {
                    $_ -match ':' -and
                    $_ -notlike "fe80::*"
                } |
                Select-Object -First 1
        }

        # ============================================================
        # Helper: Test Internet
        # ============================================================

        function Test-InternetConnection {

            # Test gateway first
            if ($oldGateway) {

                $gatewayOK = Test-Connection `
                    -ComputerName $oldGateway `
                    -Count 1 `
                    -Quiet `
                    -ErrorAction SilentlyContinue

                if (-not $gatewayOK) {
                    return $false
                }
            }

            # Test IP connectivity first
            $ipOK = Test-Connection `
                -ComputerName "1.1.1.1" `
                -Count 1 `
                -Quiet `
                -ErrorAction SilentlyContinue

            if ($ipOK) {
                return $true
            }

            # Test DNS/HTTPS as fallback
            try {
                $dnsTest = Resolve-DnsName `
                    -Name "www.microsoft.com" `
                    -ErrorAction Stop

                if ($dnsTest) {
                    return $true
                }
            }
            catch {}

            return $false
        }

        # ============================================================
        # Helper: Restore DHCP safely
        # ============================================================

        function Restore-DHCP {

            Write-Host ""
            Write-Host "Rolling back to DHCP..." -ForegroundColor Yellow

            $rollbackConfig = Get-WmiObject Win32_NetworkAdapterConfiguration `
                -Filter "Index=$index" `
                -ErrorAction SilentlyContinue

            if ($rollbackConfig) {

                $dhcpResult = $rollbackConfig.EnableDHCP()

                if ($dhcpResult.ReturnValue -eq 0 -or
                    $dhcpResult.ReturnValue -eq 1) {

                    Start-Sleep -Seconds 2

                    ipconfig /release "$adapterName" 2>$null | Out-Null
                    ipconfig /renew "$adapterName" 2>$null | Out-Null

                    Start-Sleep -Seconds 6

                    Write-Host "DHCP restored." -ForegroundColor Green
                }
                else {
                    Write-Host "WARNING: DHCP rollback returned code $($dhcpResult.ReturnValue)." -ForegroundColor Red
                }
            }
        }

        # ============================================================
        # MAIN MENU
        # ============================================================

        Write-Host "Select what you want to change:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "[1] Change MAC Address" -ForegroundColor White
        Write-Host "[2] Change IPv4 Address" -ForegroundColor White
        Write-Host "[3] Change IPv6 Address" -ForegroundColor White
        Write-Host "[4] Change Everything Automatically" -ForegroundColor Green
        Write-Host "[5] Cancel" -ForegroundColor White
        Write-Host ""

        do {
            $mainChoice = Read-Host "Select"

            if ($mainChoice -notin @("1","2","3","4","5")) {
                Write-Host "Invalid selection." -ForegroundColor Red
            }

        } while ($mainChoice -notin @("1","2","3","4","5"))

        if ($mainChoice -eq "5") {
            Show-MainMenu
            return
        }

        # ============================================================
        # 1 - MAC
        # ============================================================

        if ($mainChoice -eq "1") {

            Write-Host ""
            Write-Host "MAC Address Mode:" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "[1] Automatic" -ForegroundColor White
            Write-Host "[2] Manual" -ForegroundColor White
            Write-Host "[3] Cancel" -ForegroundColor White
            Write-Host ""

            $macChoice = Read-Host "Select"

            if ($macChoice -eq "3") {
                Show-MainMenu
                return
            }

            if ($macChoice -eq "1") {

                $newMac = New-RandomMac
            }
            elseif ($macChoice -eq "2") {

                $newMac = Read-Host "Enter MAC address"

                $newMac = $newMac `
                    -replace ":", "" `
                    -replace "-", "" `
                    -replace "\.", ""

                if ($newMac -notmatch '^[0-9A-Fa-f]{12}$') {
                    throw "Invalid MAC address."
                }

                $firstByte = [Convert]::ToInt32(
                    $newMac.Substring(0,2),
                    16
                )

                # Force unicast
                if (($firstByte -band 1) -eq 1) {
                    throw "Multicast MAC addresses are not allowed."
                }
            }
            else {
                throw "Invalid MAC selection."
            }

            Write-Host ""
            Write-Host "Changing MAC..." -ForegroundColor Cyan

            $actualMac = Set-AdapterMAC -RequestedMac $newMac

            Write-Host ""
            Write-Host "OLD : $oldMac" -ForegroundColor Yellow
            Write-Host "NEW : $actualMac" -ForegroundColor Green

            if ($actualMac -ne $oldMac) {
                Write-Host "SUCCESS: MAC changed." -ForegroundColor Green
            }
            else {
                Write-Host "WARNING: MAC did not change." -ForegroundColor Yellow
            }
        }

        # ============================================================
        # 2 - IPv4
        # ============================================================

        elseif ($mainChoice -eq "2") {

            Write-Host ""
            Write-Host "IPv4 Address Mode:" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "[1] Automatic DHCP" -ForegroundColor White
            Write-Host "[2] Manual" -ForegroundColor White
            Write-Host "[3] Cancel" -ForegroundColor White
            Write-Host ""

            $ipv4Choice = Read-Host "Select"

            if ($ipv4Choice -eq "3") {
                Show-MainMenu
                return
            }

            # --------------------------------------------------------
            # Automatic IPv4
            # --------------------------------------------------------

            if ($ipv4Choice -eq "1") {

                Write-Host ""
                Write-Host "Generating new MAC for DHCP..." -ForegroundColor Cyan

                $newMac = New-RandomMac

                $actualMac = Set-AdapterMAC -RequestedMac $newMac

                Write-Host "Actual MAC: $actualMac" -ForegroundColor Green

                Write-Host "Renewing DHCP..." -ForegroundColor Cyan

                ipconfig /release "$adapterName" 2>$null | Out-Null
                Start-Sleep -Seconds 2

                ipconfig /renew "$adapterName" 2>$null | Out-Null
                Start-Sleep -Seconds 5

                $newIPv4 = Get-CurrentIPv4

                Write-Host ""
                Write-Host "IPv4" -ForegroundColor White
                Write-Host "OLD : $oldIPv4" -ForegroundColor Yellow
                Write-Host "NEW : $newIPv4" -ForegroundColor Green

                if ($newIPv4 -and $newIPv4 -ne $oldIPv4) {
                    Write-Host "SUCCESS: IPv4 changed." -ForegroundColor Green
                }
                else {
                    Write-Host "WARNING: DHCP returned the same IPv4." -ForegroundColor Yellow
                }
            }

            # --------------------------------------------------------
            # Manual IPv4 - SAFE VERSION
            # --------------------------------------------------------

            elseif ($ipv4Choice -eq "2") {

                Write-Host ""
                Write-Host "Manual IPv4 Configuration" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Current Gateway : $oldGateway" -ForegroundColor DarkGray
                Write-Host "Current Subnet  : $oldSubnet" -ForegroundColor DarkGray

                if ($oldDNS.Count -gt 0) {
                    Write-Host "Current DNS     : $($oldDNS -join ', ')" -ForegroundColor DarkGray
                }

                Write-Host ""

                $manualIPv4 = Read-Host "Enter IPv4 address"

                # ----------------------------------------------------
                # Validate IP
                # ----------------------------------------------------

                $parsedIPv4 = $null

                if (
                    -not [System.Net.IPAddress]::TryParse(
                        $manualIPv4,
                        [ref]$parsedIPv4
                    ) -or
                    $parsedIPv4.AddressFamily -ne `
                    [System.Net.Sockets.AddressFamily]::InterNetwork
                ) {
                    throw "Invalid IPv4 address."
                }

                if (
                    $manualIPv4 -eq "0.0.0.0" -or
                    $manualIPv4 -eq "255.255.255.255" -or
                    $manualIPv4 -like "127.*" -or
                    $manualIPv4 -like "169.254.*"
                ) {
                    throw "This IPv4 address cannot be used."
                }

                # ----------------------------------------------------
                # Don't allow Gateway
                # ----------------------------------------------------

                if ($oldGateway -and $manualIPv4 -eq $oldGateway) {
                    throw "You cannot use the Gateway address."
                }

                # ----------------------------------------------------
                # Check network
                # ----------------------------------------------------

                function Convert-IPv4ToUInt32 {
                    param([string]$IP)

                    $bytes = [System.Net.IPAddress]::Parse($IP).GetAddressBytes()

                    [Array]::Reverse($bytes)

                    return [BitConverter]::ToUInt32($bytes,0)
                }

                $ipValue = Convert-IPv4ToUInt32 $manualIPv4
                $maskValue = Convert-IPv4ToUInt32 $oldSubnet
                $gatewayValue = Convert-IPv4ToUInt32 $oldGateway

                $networkValue = $ipValue -band $maskValue
                $gatewayNetwork = $gatewayValue -band $maskValue

                if ($networkValue -ne $gatewayNetwork) {

                    Write-Host ""
                    Write-Host "ERROR: The IP is not in the same network as the Gateway." -ForegroundColor Red
                    Write-Host "IP      : $manualIPv4" -ForegroundColor Yellow
                    Write-Host "Gateway : $oldGateway" -ForegroundColor Yellow

                    Read-Host "Press Enter to continue"
                    Show-MainMenu
                    return
                }

                # ----------------------------------------------------
                # Check if IP is responding
                # ----------------------------------------------------

                Write-Host ""
                Write-Host "Checking whether IP is already in use..." -ForegroundColor Cyan

                $ipInUse = Test-Connection `
                    -ComputerName $manualIPv4 `
                    -Count 2 `
                    -Quiet `
                    -ErrorAction SilentlyContinue

                if ($ipInUse) {

                    Write-Host ""
                    Write-Host "WARNING: $manualIPv4 appears to be in use." -ForegroundColor Red
                    Write-Host ""

                    $auto = Read-Host "Use automatic IPv4 instead? [Y/N]"

                    if ($auto -match "^[Yy]$") {

                        Write-Host ""
                        Write-Host "Switching to automatic DHCP..." -ForegroundColor Cyan

                        $newMac = New-RandomMac

                        $actualMac = Set-AdapterMAC `
                            -RequestedMac $newMac

                        ipconfig /release "$adapterName" 2>$null | Out-Null
                        Start-Sleep -Seconds 2

                        ipconfig /renew "$adapterName" 2>$null | Out-Null
                        Start-Sleep -Seconds 5

                        $newIPv4 = Get-CurrentIPv4

                        Write-Host ""
                        Write-Host "NEW IPv4 : $newIPv4" -ForegroundColor Green
                    }
                    else {

                        Write-Host "Operation cancelled." -ForegroundColor Yellow
                    }
                }
                else {

                    # ------------------------------------------------
                    # Save current DNS before changing anything
                    # ------------------------------------------------

                    Write-Host ""
                    Write-Host "Applying Static IPv4..." -ForegroundColor Cyan

                    $wmiConfig = Get-WmiObject Win32_NetworkAdapterConfiguration `
                        -Filter "Index=$index" `
                        -ErrorAction Stop

                    # Set IP + subnet
                    $staticResult = $wmiConfig.EnableStatic(
                        @($manualIPv4),
                        @($oldSubnet)
                    )

                    if (
                        $staticResult.ReturnValue -ne 0 -and
                        $staticResult.ReturnValue -ne 1
                    ) {
                        throw "EnableStatic failed. WMI code: $($staticResult.ReturnValue)"
                    }

                    Start-Sleep -Seconds 2

                    # Re-read object
                    $wmiConfig = Get-WmiObject Win32_NetworkAdapterConfiguration `
                        -Filter "Index=$index" `
                        -ErrorAction Stop

                    # ------------------------------------------------
                    # Gateway
                    # ------------------------------------------------

                    $gatewayResult = $wmiConfig.SetGateways(
                        @($oldGateway),
                        @(1)
                    )

                    if ($gatewayResult.ReturnValue -ne 0) {
                        Write-Host "WARNING: Gateway returned code $($gatewayResult.ReturnValue)." -ForegroundColor Yellow
                    }

                    # ------------------------------------------------
                    # RESTORE DNS
                    # ------------------------------------------------

                    Start-Sleep -Seconds 1

                    $wmiConfig = Get-WmiObject Win32_NetworkAdapterConfiguration `
                        -Filter "Index=$index" `
                        -ErrorAction Stop

                    if ($oldDNS.Count -gt 0) {

                        Write-Host "Restoring DNS servers..." -ForegroundColor Cyan

                        $dnsResult = $wmiConfig.SetDNSServerSearchOrder(
                            $oldDNS
                        )

                        if ($dnsResult.ReturnValue -ne 0) {
                            Write-Host "WARNING: DNS configuration returned code $($dnsResult.ReturnValue)." -ForegroundColor Yellow
                        }
                    }

                    Start-Sleep -Seconds 4

                    # ------------------------------------------------
                    # Verify local configuration
                    # ------------------------------------------------

                    $testConfig = Get-WmiObject Win32_NetworkAdapterConfiguration `
                        -Filter "Index=$index" `
                        -ErrorAction SilentlyContinue

                    $testIPv4 = $testConfig.IPAddress |
                        Where-Object {
                            $_ -match '^\d{1,3}(\.\d{1,3}){3}$'
                        } |
                        Select-Object -First 1

                    Write-Host ""
                    Write-Host "IPv4 applied: $testIPv4" -ForegroundColor Green

                    # ------------------------------------------------
                    # Test Gateway
                    # ------------------------------------------------

                    Write-Host "Testing Gateway..." -ForegroundColor Cyan

                    $gatewayOK = Test-Connection `
                        -ComputerName $oldGateway `
                        -Count 2 `
                        -Quiet `
                        -ErrorAction SilentlyContinue

                    # ------------------------------------------------
                    # Test Internet by IP
                    # ------------------------------------------------

                    Write-Host "Testing Internet connectivity..." -ForegroundColor Cyan

                    $internetOK = Test-Connection `
                        -ComputerName "1.1.1.1" `
                        -Count 2 `
                        -Quiet `
                        -ErrorAction SilentlyContinue

                    # ------------------------------------------------
                    # Test DNS
                    # ------------------------------------------------

                    $dnsOK = $false

                    try {
                        $dnsResult = Resolve-DnsName `
                            -Name "www.microsoft.com" `
                            -ErrorAction Stop

                        if ($dnsResult) {
                            $dnsOK = $true
                        }
                    }
                    catch {}

                    Write-Host ""

                    if ($gatewayOK) {
                        Write-Host "Gateway : OK" -ForegroundColor Green
                    }
                    else {
                        Write-Host "Gateway : FAILED" -ForegroundColor Red
                    }

                    if ($internetOK) {
                        Write-Host "Internet: OK" -ForegroundColor Green
                    }
                    else {
                        Write-Host "Internet: FAILED" -ForegroundColor Red
                    }

                    if ($dnsOK) {
                        Write-Host "DNS     : OK" -ForegroundColor Green
                    }
                    else {
                        Write-Host "DNS     : FAILED" -ForegroundColor Red
                    }

                    # ------------------------------------------------
                    # SAFE ROLLBACK
                    # ------------------------------------------------

                    if (-not $gatewayOK -or -not $internetOK -or -not $dnsOK) {

                        Write-Host ""
                        Write-Host "Manual IPv4 configuration failed connectivity test." -ForegroundColor Red
                        Write-Host "Internet will be restored automatically." -ForegroundColor Yellow

                        Restore-DHCP

                        Start-Sleep -Seconds 5

                        $restoredIPv4 = Get-CurrentIPv4

                        Write-Host ""
                        Write-Host "Restored IPv4: $restoredIPv4" -ForegroundColor Green
                        Write-Host "DHCP rollback completed." -ForegroundColor Green
                    }
                    else {

                        Write-Host ""
                        Write-Host "SUCCESS: Manual IPv4 applied and Internet is working." -ForegroundColor Green
                        Write-Host "IPv4   : $manualIPv4" -ForegroundColor Green
                        Write-Host "Gateway: $oldGateway" -ForegroundColor Green
                    }
                }
            }
            else {
                throw "Invalid IPv4 selection."
            }
        }

        # ============================================================
        # 3 - IPv6
        # ============================================================

        elseif ($mainChoice -eq "3") {

            Write-Host ""
            Write-Host "IPv6 Address Mode:" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "[1] Automatic" -ForegroundColor White
            Write-Host "[2] Manual" -ForegroundColor White
            Write-Host "[3] Cancel" -ForegroundColor White
            Write-Host ""

            $ipv6Choice = Read-Host "Select"

            if ($ipv6Choice -eq "3") {
                Show-MainMenu
                return
            }

            if ($ipv6Choice -eq "1") {

                Write-Host ""
                Write-Host "Refreshing IPv6 automatically..." -ForegroundColor Cyan

                netsh interface ipv6 set interface `
                    "$adapterName" `
                    routerdiscovery=enabled `
                    managedaddress=enabled `
                    otherstateful=enabled `
                    store=active 2>$null | Out-Null

                Start-Sleep -Seconds 3

                ipconfig /renew6 "$adapterName" 2>$null | Out-Null

                Start-Sleep -Seconds 5

                $newIPv6 = Get-CurrentIPv6

                Write-Host ""
                Write-Host "IPv6 : $newIPv6" -ForegroundColor Green
                Write-Host "IPv6 automatic refresh completed." -ForegroundColor Green
            }

            elseif ($ipv6Choice -eq "2") {

                Write-Host ""
                Write-Host "WARNING: Manual IPv6 requires a valid IPv6 prefix from your ISP/router." -ForegroundColor Yellow
                Write-Host ""

                $manualIPv6 = Read-Host "Enter IPv6 address"
                $prefix = Read-Host "Prefix Length (example: 64)"

                $parsedIPv6 = $null

                if (
                    -not [System.Net.IPAddress]::TryParse(
                        $manualIPv6,
                        [ref]$parsedIPv6
                    ) -or
                    $parsedIPv6.AddressFamily -ne `
                    [System.Net.Sockets.AddressFamily]::InterNetworkV6
                ) {
                    throw "Invalid IPv6 address."
                }

                $prefixNumber = 0

                if (
                    -not [int]::TryParse(
                        $prefix,
                        [ref]$prefixNumber
                    ) -or
                    $prefixNumber -lt 1 -or
                    $prefixNumber -gt 128
                ) {
                    throw "Invalid IPv6 prefix length."
                }

                Write-Host ""
                Write-Host "Adding IPv6 address..." -ForegroundColor Cyan

                netsh interface ipv6 add address `
                    interface="$adapterName" `
                    address="$manualIPv6/$prefixNumber" `
                    store=active 2>$null | Out-Null

                Start-Sleep -Seconds 3

                Write-Host ""
                Write-Host "IPv6 address added." -ForegroundColor Green
                Write-Host "$manualIPv6/$prefixNumber" -ForegroundColor Green
            }
            else {
                throw "Invalid IPv6 selection."
            }
        }

        # ============================================================
        # 4 - EVERYTHING AUTOMATIC
        # ============================================================

        elseif ($mainChoice -eq "4") {

            Write-Host ""
            Write-Host "══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "                 AUTOMATIC FULL RENEW" -ForegroundColor Cyan
            Write-Host "══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host ""

            # --------------------------------------------------------
            # MAC
            # --------------------------------------------------------

            Write-Host "[1/4] Changing MAC..." -ForegroundColor Cyan

            $newMac = New-RandomMac

            $actualMac = Set-AdapterMAC `
                -RequestedMac $newMac

            Write-Host "OLD : $oldMac" -ForegroundColor Yellow
            Write-Host "NEW : $actualMac" -ForegroundColor Green

            # --------------------------------------------------------
            # IPv4
            # --------------------------------------------------------

            Write-Host ""
            Write-Host "[2/4] Renewing IPv4..." -ForegroundColor Cyan

            ipconfig /release "$adapterName" 2>$null | Out-Null

            Start-Sleep -Seconds 2

            ipconfig /renew "$adapterName" 2>$null | Out-Null

            Start-Sleep -Seconds 5

            $newIPv4 = Get-CurrentIPv4

            # --------------------------------------------------------
            # IPv6
            # --------------------------------------------------------

            Write-Host "[3/4] Refreshing IPv6..." -ForegroundColor Cyan

            netsh interface ipv6 set interface `
                "$adapterName" `
                routerdiscovery=enabled `
                managedaddress=enabled `
                otherstateful=enabled `
                store=active 2>$null | Out-Null

            Start-Sleep -Seconds 3

            ipconfig /renew6 "$adapterName" 2>$null | Out-Null

            Start-Sleep -Seconds 5

            $newIPv6 = Get-CurrentIPv6

            # --------------------------------------------------------
            # Verify
            # --------------------------------------------------------

            Write-Host "[4/4] Verifying Internet..." -ForegroundColor Cyan

            $internetOK = Test-Connection `
                -ComputerName "1.1.1.1" `
                -Count 2 `
                -Quiet `
                -ErrorAction SilentlyContinue

            Write-Host ""
            Write-Host "══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "                           RESULT" -ForegroundColor Cyan
            Write-Host "══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

            Write-Host ""
            Write-Host "MAC" -ForegroundColor White
            Write-Host "OLD : $oldMac" -ForegroundColor Yellow
            Write-Host "NEW : $actualMac" -ForegroundColor Green

            Write-Host ""
            Write-Host "IPv4" -ForegroundColor White
            Write-Host "OLD : $oldIPv4" -ForegroundColor Yellow
            Write-Host "NEW : $newIPv4" -ForegroundColor Green

            Write-Host ""
            Write-Host "IPv6" -ForegroundColor White
            Write-Host "OLD : $oldIPv6" -ForegroundColor Yellow
            Write-Host "NEW : $newIPv6" -ForegroundColor Green

            Write-Host ""

            if ($actualMac -ne $oldMac) {
                Write-Host "SUCCESS: MAC changed." -ForegroundColor Green
            }

            if ($newIPv4 -and $newIPv4 -ne $oldIPv4) {
                Write-Host "SUCCESS: IPv4 changed." -ForegroundColor Green
            }
            else {
                Write-Host "WARNING: DHCP returned the same IPv4." -ForegroundColor Yellow
            }

            if ($newIPv6) {
                Write-Host "IPv6: Global IPv6 available." -ForegroundColor Green
            }
            else {
                Write-Host "IPv6: No Global IPv6 assigned by network." -ForegroundColor Yellow
            }

            if ($internetOK) {
                Write-Host ""
                Write-Host "SUCCESS: Internet connection is working." -ForegroundColor Green
            }
            else {
                Write-Host ""
                Write-Host "WARNING: Internet connectivity test failed." -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Host ""
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "Operation finished." -ForegroundColor Green
    Read-Host "Press Enter to continue"
    Show-MainMenu
}

function Network-Diagnosis {
    Clear-Host
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                        Network Diagnosis                         ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    $adapters = Get-InterfaceCandidates
    if ($adapters) {
        Write-Host "Network Adapters:" -ForegroundColor Green
        $adapters | Select-Object Name, InterfaceDescription, Status, MacAddress, LinkSpeed | Format-Table -AutoSize
    }
    else {
        Write-Host "No network adapters found or none are usable in this environment."
    }

    Write-Host ""
    Write-Host "IPv4 addresses:" -ForegroundColor Green
    Get-NetIPAddress -AddressFamily IPv4 | Format-Table -AutoSize

    Write-Host ""
    Write-Host "DNS servers:" -ForegroundColor Green
    Get-DnsClientServerAddress | Format-Table -AutoSize

    Write-Host ""
    Write-Host "Current route table:" -ForegroundColor Green
    Get-NetRoute | Where-Object { $_.DestinationPrefix -ne "255.255.255.255/32" } | Format-Table -AutoSize

    Write-Host ""
    Read-Host "Press Enter to continue"
    Show-MainMenu
}

function Connection-Test {
    Clear-Host
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                       Internet Connectivity                      ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    $targets = @("8.8.8.8", "1.1.1.1", "google.com", "microsoft.com")
    foreach ($target in $targets) {
        Write-Host "Testing: $target"
        Test-Connection -ComputerName $target -Count 2 -ErrorAction SilentlyContinue | Format-Table -AutoSize
        Write-Host ""
    }

    Read-Host "Press Enter to continue"
    Show-MainMenu
}

function Restart-NetworkServices {
    Write-Host ""
    Write-Host "Restarting DHCP and DNS related services..."

    $services = @("Dhcp", "Dnscache", "Netman", "NlaSvc")
    foreach ($svcName in $services) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if (-not $svc) {
            Write-Host "INFO: Service '$svcName' not found; skipping." -ForegroundColor Yellow
            continue
        }

        try {
            if ($svc.Status -eq "Running") {
                Stop-Service -Name $svcName -Force -ErrorAction Stop | Out-Null
                Write-Host "Stopped: $svcName" -ForegroundColor Yellow
            }
            Start-Sleep -Seconds 2
            Start-Service -Name $svcName -ErrorAction Stop | Out-Null
            Write-Host "Started: $svcName" -ForegroundColor Green
            Write-Log -Message "Restarted service: $svcName"
        }
        catch {
            Write-Host "WARNING: Service '$svcName' could not be restarted." -ForegroundColor Yellow
            Write-Log -Message "Failed to restart service: $svcName"
        }
    }

    Write-Host ""
    Write-Host "Network services refresh completed." -ForegroundColor Green
    Read-Host "Press Enter to continue"
    Advanced-Settings
}

function Set-DnsOnInterface {
    param(
        [string]$InterfaceAlias,
        [string[]]$ServerAddresses,
        [switch]$ResetToDhcp
    )

    $target = $InterfaceAlias
    if (-not $target) { $target = "Ethernet" }
    $adapter = Get-NetAdapter -Name $target -ErrorAction SilentlyContinue
    if (-not $adapter) {
        foreach ($name in @("Ethernet", "Wi-Fi", "Local Area Connection", "Ethernet 2", "Wireless Network Connection")) {
            $a = Get-NetAdapter -Name $name -ErrorAction SilentlyContinue
            if ($a) { $target = $a.Name; break }
        }
    }

    if ($ResetToDhcp) {
        if (Get-Command Set-DnsClientServerAddress -ErrorAction SilentlyContinue) {
            Set-DnsClientServerAddress -InterfaceAlias $target -ResetServerAddresses -ErrorAction Stop | Out-Null
        }
        else {
            netsh interface ipv4 set dns name="$target" source=dhcp | Out-Null
        }
        Write-Host "DNS reset to DHCP on $target" -ForegroundColor Yellow
        return
    }

    if (Get-Command Set-DnsClientServerAddress -ErrorAction SilentlyContinue) {
        Set-DnsClientServerAddress -InterfaceAlias $target -ServerAddresses $ServerAddresses -ErrorAction Stop | Out-Null
    }
    else {
        $primary = $ServerAddresses[0]
        $secondary = if ($ServerAddresses.Count -gt 1) { $ServerAddresses[1] } else { $null }
        netsh interface ipv4 set dns name="$target" static $primary primary | Out-Null
        if ($secondary) {
            netsh interface ipv4 add dns name="$target" $secondary index=2 | Out-Null
        }
    }

    Write-Host "DNS updated on $target to: $($ServerAddresses -join ', ')" -ForegroundColor Green
    Write-Host "Current DNS values:" -ForegroundColor Cyan
    try {
        Get-DnsClientServerAddress -InterfaceAlias $target | Format-Table -AutoSize
    }
    catch {
        netsh interface ipv4 show dns name="$target" | Out-Host
    }
}

function Change-DNS {
    Clear-Host
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                         Change DNS Server                        ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    $iface = Choose-Adapter
    if (-not $iface) {
        $iface = "Ethernet"
    }

    $script:netif = $iface
    Write-Host ""
    Write-Host "  [0] Manual DNS (enter your own values)"
    Write-Host "  [1] Google DNS (8.8.8.8 / 8.8.4.4)     - Very popular, stable, good for general use"
    Write-Host "  [2] Cloudflare DNS (1.1.1.1 / 1.0.0.1) - Fast, privacy-friendly, modern"
    Write-Host "  [3] OpenDNS (208.67.222.123 / 208.67.220.123) - Security-focused, content filtering"
    Write-Host "  [4] Automatic (DHCP)                   - Restore default ISP/router DNS"
    Write-Host "  [5] Custom (press Enter for one DNS only) - Enter your own DNS values"
    Write-Host ""
    $dnsChoice = Read-Host "Choose DNS profile (0-5)."

    switch ($dnsChoice) {
        "0" {
            $custom1 = Read-Host "Enter primary DNS (example: 8.8.8.8)"
            $custom2 = Read-Host "Enter secondary DNS (optional, press Enter to skip)"
            if ([string]::IsNullOrWhiteSpace($custom1)) {
                Write-Host "Primary DNS is required." -ForegroundColor Red
                Read-Host "Press Enter to continue"
                Advanced-Settings
                return
            }
            if ([string]::IsNullOrWhiteSpace($custom2)) {
                Set-DnsOnInterface -InterfaceAlias $script:netif -ServerAddresses @($custom1)
                $script:lastdns = "Manual ($custom1)"
            }
            else {
                Set-DnsOnInterface -InterfaceAlias $script:netif -ServerAddresses @($custom1, $custom2)
                $script:lastdns = "Manual ($custom1 / $custom2)"
            }
        }
        "1" {
            Set-DnsOnInterface -InterfaceAlias $script:netif -ServerAddresses @("8.8.8.8", "8.8.4.4")
            $script:lastdns = "Google (8.8.8.8 / 8.8.4.4)"
        }
        "2" {
            Set-DnsOnInterface -InterfaceAlias $script:netif -ServerAddresses @("1.1.1.1", "1.0.0.1")
            $script:lastdns = "Cloudflare (1.1.1.1 / 1.0.0.1)"
        }
        "3" {
            Set-DnsOnInterface -InterfaceAlias $script:netif -ServerAddresses @("208.67.222.123", "208.67.220.123")
            $script:lastdns = "OpenDNS (208.67.222.123 / 208.67.220.123)"
        }
        "4" {
            Set-DnsOnInterface -InterfaceAlias $script:netif -ResetToDhcp
            $script:lastdns = "Automatic (DHCP)"
        }
        "5" {
            $custom1 = Read-Host "Primary DNS"
            $custom2 = Read-Host "Secondary DNS (optional)"
            if ([string]::IsNullOrWhiteSpace($custom2)) {
                Set-DnsOnInterface -InterfaceAlias $script:netif -ServerAddresses @($custom1)
                $script:lastdns = "Custom ($custom1)"
            }
            else {
                Set-DnsOnInterface -InterfaceAlias $script:netif -ServerAddresses @($custom1, $custom2)
                $script:lastdns = "Custom ($custom1 / $custom2)"
            }
        }
        default {
            Write-Host "Invalid DNS selection." -ForegroundColor Red
            Read-Host "Press Enter to continue"
            Advanced-Settings
            return
        }
    }

    $script:lastdns | Out-File -FilePath $script:statefile -Encoding utf8
    Write-Host "SUCCESS: DNS settings updated for $script:netif" -ForegroundColor Green
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    try {
        Get-DnsClientServerAddress -InterfaceAlias $script:netif | Format-Table -AutoSize
    }
    catch {
        netsh interface ip show dns name="$script:netif" | Out-Host
    }
    Read-Host "Press Enter to continue"
    Advanced-Settings
}

function Firewall-Reset {
    Write-Host ""
    Write-Host "Resetting firewall configuration..."
    netsh advfirewall reset | Out-Null
    Test-OperationSuccess -TaskName "Firewall Reset" -ErrorCode $LASTEXITCODE
    Read-Host "Press Enter to continue"
    Advanced-Settings
}

function Clear-Log {
    Write-Host ""
    Write-Host "Clearing operation log..."
    if (Test-Path $script:logfile) {
        Remove-Item -Path $script:logfile -Force
    }
    Write-Host "SUCCESS: Operation log cleared." -ForegroundColor Green
    Read-Host "Press Enter to continue"
    Advanced-Settings
}

function Show-Log {
    Clear-Host
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                         Operation Log                            ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    if (Test-Path $script:logfile) {
        Get-Content $script:logfile | ForEach-Object { Write-Host $_ }
    }
    else {
        Write-Host "No operations logged yet."
    }
    Write-Host ""
    Read-Host "Press Enter to continue"
    Advanced-Settings
}

function Advanced-Settings {
    Clear-Host
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                        Advanced Settings                         ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] Reset Firewall"
    Write-Host "  [2] Clear Log"
    Write-Host "  [3] Restart DHCP / DNS Services"
    Write-Host "  [4] Change DNS"
    Write-Host "  [5] View Log"
    Write-Host "  [6] Back to Main Menu"
    Write-Host ""
    Write-Host "  Current DNS Profile: $script:lastdns"
    Write-Host ""
    $advChoice = Read-Host "Select option number"

    switch ($advChoice) {
        "1" { Firewall-Reset }
        "2" { Clear-Log }
        "3" { Restart-NetworkServices }
        "4" { Change-DNS }
        "5" { Show-Log }
        "6" { Show-MainMenu }
        default { Advanced-Settings }
    }
}

function Show-MainMenu {
    Clear-Host
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                  Advanced Network Repair Tool                    ║" -ForegroundColor Cyan
    Write-Host "║                        Created by PANDA                          ║" -ForegroundColor Cyan
    Write-Host "╠══════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║                                                                  ║" -ForegroundColor Cyan
    Write-Host "║  [1] Full Network Repair (Deep)                                  ║" -ForegroundColor Cyan
    Write-Host "║  [2] Flush DNS Cache                                             ║" -ForegroundColor Cyan
    Write-Host "║  [3] Reset Winsock / TCP-IP                                      ║" -ForegroundColor Cyan
    Write-Host "║  [4] Restart Network Adapters                                    ║" -ForegroundColor Cyan
    Write-Host "║  [5] Renew IP Address                                            ║" -ForegroundColor Cyan
    Write-Host "║  [6] Diagnose Network                                            ║" -ForegroundColor Cyan
    Write-Host "║  [7] Internet Connectivity Test                                  ║" -ForegroundColor Cyan
    Write-Host "║  [8] Advanced Settings                                           ║" -ForegroundColor Cyan
    Write-Host "║  [0] Exit                                                        ║" -ForegroundColor Cyan
    Write-Host "║                                                                  ║" -ForegroundColor Cyan
    Write-Host "╠══════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "   Current DNS: $script:lastdns                                     " -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    $choice = Read-Host "Select option number"

    switch ($choice) {
        "1" { Full-Network-Repair }
        "2" { DNS-Flush }
        "3" { Winsock-Reset }
        "4" { Adapter-Restart }
        "5" { IP-Renew }
        "6" { Network-Diagnosis }
        "7" { Connection-Test }
        "8" { Advanced-Settings }
        "0" { exit }
        default { Show-MainMenu }
    }
}

# Start the script
Show-MainMenu
<# 
.SYNOPSIS
  Tests connectivity to Intune network endpoints (FQDNs and IP subnets)
  from the "Network endpoints for Microsoft Intune" documentation (North America).

.NOTES
  - Run from a Windows client/server with PowerShell 5.1+.
  - Requires outbound access to DNS and the tested ports.
  - Outputs ONLY failed checks.
#>

$DefaultTcpPorts = @(80,443)

# ---------------------------
# FQDN endpoints (from Intune endpoints doc - NA)
# ---------------------------
$Fqdns = @(
    # Intune core / management / DO / WUFB / Store / Remote Help / Org messages, etc.
    "*.manage.microsoft.com",
    "manage.microsoft.com",
    "*.dm.microsoft.com",
    "EnterpriseEnrollment.manage.microsoft.com",

    "*.dl.delivery.mp.microsoft.com",
    "*.do.dsp.mp.microsoft.com",
    "*.prod.do.dsp.mp.microsoft.com",
    "*.delivery.mp.microsoft.com",
    "*.windowsupdate.com",
    "*.update.microsoft.com",
    "tsfe.trafficshaping.dsp.mp.microsoft.com",
    "adl.windows.com",

    # Autopilot / WNS
    "time.windows.com",
    "clientconfig.passport.net",
    "windowsphone.com",
    "*.s-microsoft.com",
    "c.s-microsoft.com",

    # Win32 / PowerShell content CDN
    "approdimedatapri.azureedge.net",
    "approdimedatasec.azureedge.net",
    "approdimedatahotfix.azureedge.net",
    "euprodimedatapri.azureedge.net",
    "euprodimedatasec.azureedge.net",
    "euprodimedatahotfix.azureedge.net",
    "naprodimedatapri.azureedge.net",
    "naprodimedatasec.azureedge.net",
    "naprodimedatahotfix.azureedge.net",

    "swda01-mscdn.manage.microsoft.com",
    "swda02-mscdn.manage.microsoft.com",
    "swdb01-mscdn.manage.microsoft.com",
    "swdb02-mscdn.manage.microsoft.com",
    "swdc01-mscdn.manage.microsoft.com",
    "swdc02-mscdn.manage.microsoft.com",
    "swdd01-mscdn.manage.microsoft.com",
    "swdd02-mscdn.manage.microsoft.com",
    "swdin01-mscdn.manage.microsoft.com",
    "swdin02-mscdn.manage.microsoft.com",

    # WNS
    "*.notify.windows.com",
    "*.wns.windows.com",

    # Third-party deployment requirements
    "ekcert.spserv.microsoft.com",
    "ekop.intel.com",
    "ftpm.amd.com",

    # Android AOSP / macOS / PS/Win32 NA
    "intunecdnpeasd.azureedge.net",
    "intunecdnpeasd.manage.microsoft.com",
    "macsidecar.manage.microsoft.com",
    "macsidecarprod.azureedge.net",
    "naprodimedatapri.azureedge.net",
    "naprodimedatasec.azureedge.net",
    "naprodimedatahotfix.azureedge.net",
    "imeswda-afd-primary.manage.microsoft.com",
    "imeswda-afd-secondary.manage.microsoft.com",
    "imeswda-afd-hotfix.manage.microsoft.com",

    # Microsoft Store for Business / AppInstallManager
    "displaycatalog.mp.microsoft.com",
    "purchase.md.mp.microsoft.com",
    "licensing.mp.microsoft.com",
    "storeedgefd.dsx.mp.microsoft.com",
    "cdn.storeedgefd.dsx.mp.microsoft.com",

    # Diagnostic data
    "*.events.data.microsoft.com",

    # Device Health Attestation (NA examples)
    "intunemaape1.eus.attest.azure.net",
    "intunemaape2.eus2.attest.azure.net",
    "intunemaape3.cus.attest.azure.net",
    "intunemaape4.wus.attest.azure.net",
    "intunemaape5.scus.attest.azure.net",
    "intunemaape6.ncus.attest.azure.net",

    # Remote Help
    "*.support.services.microsoft.com",
    "remoteassistance.support.services.microsoft.com",
    "remoteassistanceprodacs.communication.azure.com",
    "remoteassistanceprodacseu.communication.azure.com",
    "remotehelp.microsoft.com",
    "teams.microsoft.com",
    "edge.skype.com",
    "edge.microsoft.com",
    "aadcdn.msftauth.net",
    "aadcdn.msauth.net",
    "alcdn.msauth.net",
    "wcpstatic.microsoft.com",
    "*.aria.microsoft.com",
    "browser.pipe.aria.microsoft.com",
    "*.events.data.microsoft.com",
    "*.monitor.azure.com",
    "js.monitor.azure.com",
    "*.trouter.communication.microsoft.com",
    "*.trouter.teams.microsoft.com",
    "api.flightproxy.skype.com",
    "ecs.communication.microsoft.com",

    # Remote Help – WebPubSub
    "*.webpubsub.azure.com",

    # Remote Help – GCC
    "remoteassistanceweb-gcc.usgov.communication.azure.us",
    "gcc.remotehelp.microsoft.com",
    "gcc.relay.remotehelp.microsoft.com",
    "*.gov.teams.microsoft.us",

    # Org messages dependencies
    "config.edge.skype.com",
    "ecs.office.com",
    "fd.api.orgmsg.microsoft.com",
    "ris.prod.api.personalization.ideas.microsoft.com",

    # Identity / auth deps
    "login.microsoftonline.com",
    "graph.windows.net",
    "enterpriseregistration.windows.net",
    "certauth.enterpriseregistration.windows.net",

    # Endpoint discovery
    "go.microsoft.com"
)

# ---------------------------
# IP subnets (from Intune endpoints doc - NA)
# ---------------------------
$IpSubnets = @(
    "4.145.74.224/27", "4.150.254.64/27", "4.154.145.224/27", "4.200.254.32/27",
    "4.207.244.0/27", "4.213.25.64/27", "4.213.86.128/25", "4.216.205.32/27",
    "4.237.143.128/25",
    "13.67.13.176/28", "13.67.15.128/27", "13.69.67.224/28", "13.69.231.128/28",
    "13.70.78.128/28", "13.70.79.128/27", "13.74.111.192/27", "13.77.53.176/28",
    "13.86.221.176/28", "13.89.174.240/28", "13.89.175.192/28",
    "20.37.153.0/24", "20.37.192.128/25", "20.38.81.0/24", "20.41.1.0/24",
    "20.42.1.0/24", "20.42.130.0/24", "20.42.224.128/25", "20.43.129.0/24",
    "20.44.19.224/27", "20.91.147.72/29", "20.168.189.128/27",
    "20.189.172.160/27", "20.189.229.0/25", "20.191.167.0/25",
    "20.192.159.40/29", "20.192.174.216/29", "20.199.207.192/28",
    "20.204.193.10/31", "20.204.193.12/30", "20.204.194.128/31",
    "20.208.149.192/27", "20.208.157.128/27", "20.214.131.176/29",
    "40.67.121.224/27", "40.70.151.32/28", "40.71.14.96/28", "40.74.25.0/24",
    "40.78.245.240/28", "40.78.247.128/27", "40.79.197.64/27", "40.79.197.96/28",
    "40.80.180.208/28", "40.80.180.224/27", "40.80.184.128/25",
    "40.82.248.224/28", "40.82.249.128/25", "40.84.70.128/25",
    "40.119.8.128/25",
    "48.218.252.128/25",
    "52.150.137.0/25", "52.162.111.96/28", "52.168.116.128/27",
    "52.182.141.192/27", "52.236.189.96/27", "52.240.244.160/27",
    "57.151.0.192/27", "57.153.235.0/25", "57.154.140.128/25",
    "57.154.195.0/25", "57.155.45.128/25",
    "68.218.134.96/27",
    "74.224.214.64/27", "74.242.35.0/25",
    "104.46.162.96/27", "104.208.197.64/27",
    "172.160.217.160/27", "172.201.237.160/27", "172.202.86.192/27",
    "172.205.63.0/25", "172.212.214.0/25", "172.215.131.0/27",
    "13.107.219.0/24", "13.107.227.0/24", "13.107.228.0/23",
    "150.171.97.0/24",
    "2620:1ec:40::/48", "2620:1ec:49::/48", "2620:1ec:4a::/47"
)

# ---------------------------
# Helper: get first usable IPv4 from CIDR
# ---------------------------
function Get-FirstHostFromCidr {
    param(
        [Parameter(Mandatory)]
        [string]$Cidr
    )
    if ($Cidr -notmatch "/") { return $Cidr }

    $parts = $Cidr.Split("/")
    $ipStr = $parts[0]
    $prefix = [int]$parts[1]

    # Skip IPv6 for this simple ICMP check
    if ($ipStr -like "*:*") {
        return $null
    }

    $ip = [System.Net.IPAddress]::Parse($ipStr)
    $bytes = $ip.GetAddressBytes()

    $maskBytes = [byte[]](0,0,0,0)
    for ($i=0; $i -lt 4; $i++) {
        $bitsThisByte = [Math]::Max([Math]::Min($prefix - ($i*8), 8), 0)
        if ($bitsThisByte -le 0) { $maskBytes[$i] = 0; continue }
        $maskBytes[$i] = [byte](0xFF -shl (8 - $bitsThisByte) -band 0xFF)
    }

    $netBytes = [byte[]]::new(4)
    for ($i=0; $i -lt 4; $i++) {
        $netBytes[$i] = $bytes[$i] -band $maskBytes[$i]
    }

    # first usable host = network + 1 (simple heuristic)
    $netBytes[3] = [byte]([int]$netBytes[3] + 1)
    return ([System.Net.IPAddress]::new($netBytes)).ToString()
}

$failedFqdns = New-Object System.Collections.Generic.List[object]
$failedIps   = New-Object System.Collections.Generic.List[object]

Write-Host "Testing FQDN connectivity (TCP $($DefaultTcpPorts -join ','))..." -ForegroundColor Cyan

foreach ($fqdn in $Fqdns | Sort-Object -Unique) {
    # DNS resolution
    try {
        $null = Resolve-DnsName -Name $fqdn -ErrorAction Stop
    }
    catch {
        $failedFqdns.Add([pscustomobject]@{
            Endpoint = $fqdn
            Type     = 'FQDN'
            Port     = '-'
            Reason   = 'DNS resolution failed'
        })
        continue
    }

    foreach ($port in $DefaultTcpPorts) {
        $res = Test-NetConnection -ComputerName $fqdn -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
        if (-not $res) {
            $failedFqdns.Add([pscustomobject]@{
                Endpoint = $fqdn
                Type     = 'FQDN'
                Port     = $port
                Reason   = 'TCP connection failed'
            })
        }
    }
}

Write-Host "Testing IP subnet reachability (ICMP ping to first host)..." -ForegroundColor Cyan

foreach ($cidr in $IpSubnets | Sort-Object -Unique) {
    $hostIp = Get-FirstHostFromCidr -Cidr $cidr
    if (-not $hostIp) {
        $failedIps.Add([pscustomobject]@{
            Endpoint = $cidr
            Type     = 'IPSubnet'
            Port     = 'ICMP'
            Reason   = 'Skipped (IPv6 or parse error)'
        })
        continue
    }

    $ping = Test-Connection -ComputerName $hostIp -Count 1 -Quiet -ErrorAction SilentlyContinue
    if (-not $ping) {
        $failedIps.Add([pscustomobject]@{
            Endpoint = $cidr
            Type     = 'IPSubnet'
            Port     = 'ICMP'
            Reason   = "Ping to $hostIp failed"
        })
    }
}

Write-Host ""
Write-Host "========= FAILED FQDN CHECKS =========" -ForegroundColor Yellow
if ($failedFqdns.Count -eq 0) {
    Write-Host "No FQDN failures detected."
} else {
    $failedFqdns | Sort-Object Endpoint,Port | Format-Table -AutoSize
}

Write-Host ""
Write-Host "========= FAILED IP SUBNET CHECKS =========" -ForegroundColor Yellow
if ($failedIps.Count -eq 0) {
    Write-Host "No IP subnet failures detected."
} else {
    $failedIps | Sort-Object Endpoint | Format-Table -AutoSize
}

<# 
One-shot 22H2 -> 23H2 + LCU with reboot hop (Intune Device Script ready)
- Phase1: EKB (KB5027397) -> schedule Phase2 -> reboot
- Phase2: LCU (e.g., KB5062552) -> write flag -> reboot if 3010
Exit code: 0 on success paths. Throws on hard errors.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ==== CONFIG (edit if needed) ====
$TargetBuild = 22631             # 23H2 build
$TargetUBR   = 5624              # e.g. KB5062552 UBR
$hosts = @("google.com", "microsoft.com", "github.com")
foreach ($host in $hosts) {
    Test-NetConnection -ComputerName $host -Port 443
} # עדכן אם יש URL אחר
$UseWUFBIfMissing = $false       # אם MSU לא זמין, נסה WU/WSUS להתקין LCU (נדרש חיבור/אישור)
$FlagPath    = 'C:\ProgramData\PR\Fixed.flag'

# פאתים קבועים
$RootDir     = 'C:\ProgramData\PR'
$ScriptDir   = Join-Path $RootDir 'Scripts'
$PkgDir      = Join-Path $RootDir 'AVD-Updates'
$LogDir      = Join-Path $RootDir 'Logs'
$LogPath     = Join-Path $LogDir  'W11-OneShot.log'
$SelfStable  = Join-Path $ScriptDir 'W11-OneShot.ps1'

# שמות קבועים ל-RunOnce
$RunOnceKey  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
$RunOnceName = 'PR_W11_OneShot_Phase2'
$RunOnceFinalize = 'PR_W11_OneShot_Finalize'

# ==== Helpers ====
function Write-Log([string]$msg) {
  $line = ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg)
  Write-Output $line
  Add-Content -Path $LogPath -Value $line
}

function Ensure-Dirs {
  foreach ($d in @($RootDir,$ScriptDir,$PkgDir,$LogDir)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}
function Get-OsInfo {
  $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
  [pscustomobject]@{
    ProductName    = $cv.ProductName
    DisplayVersion = $cv.DisplayVersion
    CurrentBuild   = [int]$cv.CurrentBuild
    UBR            = [int]$cv.UBR
    Version        = [version]("10.0.{0}.{1}" -f $cv.CurrentBuild,$cv.UBR)
  }
}
function Set-Tls12 { try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {} }

function Download-IfMissing($url, $dst) {
  if (Test-Path $dst) { return $true }
  Set-Tls12
  Write-Log "Downloading: $url -> $dst"
  try {
    # נסה BITS אם זמין (Silent)
    if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
      Start-BitsTransfer -Source $url -Destination $dst -RetryInterval 3 -Description 'PR-EKB/LCU' -ErrorAction Stop
    } else {
      Invoke-WebRequest -Uri $url -OutFile $dst -UseBasicParsing -TimeoutSec 900
    }
    return $true
  } catch {
    Write-Log "Download failed: $($_.Exception.Message)"
    return $false
  }
}

function Install-MSU($path) {
  if (!(Test-Path $path)) { throw "MSU not found: $path" }
  Write-Log "Installing MSU: $path"
  $p = Start-Process wusa.exe -ArgumentList "`"$path`" /quiet /norestart" -Wait -PassThru
  Write-Log "WUSA exit code: $($p.ExitCode)"
  return $p.ExitCode  # 0=OK, 3010=Reboot required
}

function Schedule-RunOnce($name,$command) {
  New-ItemProperty -Path $RunOnceKey -Name $name -Value $command -Force | Out-Null
  Write-Log "RunOnce scheduled: $name -> $command"
}

function Reboot-Now([string]$reason) {
  Write-Log "Rebooting: $reason"
  shutdown.exe /r /t 60 /c $reason
  exit 0
}

# ==== Bootstrap ====
Ensure-Dirs
"--- Script start ---" | Add-Content $LogPath

# אם לא רץ מהנתיב היציב – העתק את עצמנו לשם והרצה משם
try {
  if ($PSCommandPath -ne $SelfStable) {
    Write-Log "Self path: $PSCommandPath ; Stable path: $SelfStable"
    Copy-Item -LiteralPath $PSCommandPath -Destination $SelfStable -Force
    Write-Log "Re-invoking from stable path..."
    & powershell.exe -ExecutionPolicy Bypass -File $SelfStable
    exit $LASTEXITCODE
  }
} catch {
  Write-Log "Self-copy failed: $($_.Exception.Message)"
  throw
}

# זיהוי אם זו ריצה של Phase2 (אחרי ריבוט EKB)
$phase2 = (Get-ItemProperty -Path $RunOnceKey -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $RunOnceName -ErrorAction SilentlyContinue) -ne $null
if ($phase2) { Write-Log "Detected RunOnce Phase2 marker (by existence)"; }

# ==== MAIN ====
$targetVersion = [version]("10.0.{0}.{1}" -f $TargetBuild,$TargetUBR)

$os = Get-OsInfo
Write-Log "OS: $($os.ProductName) $($os.DisplayVersion)  Version=$($os.Version)"

# --- If already fully compliant ---
if ($os.Version -ge $targetVersion) {
  Write-Log "Already at/above target $targetVersion -> writing flag and exiting."
  New-Item -ItemType Directory -Path (Split-Path $FlagPath) -Force | Out-Null
  New-Item -ItemType File -Path $FlagPath -Force | Out-Null
  exit 0
}

# --- Phase selector ---
# אם אנחנו עדיין לא ב-23H2 (22631.x) => צריך EKB (Phase1)
$needEkb = $os.Version -lt [version]("10.0.{0}.0" -f $TargetBuild)

if ($needEkb) {
  Write-Log "Phase1: Installing EKB (22H2 -> 23H2)."
  $EkbPath = Join-Path $PkgDir 'windows11.0-kb5027397-x64.msu'
  if (-not (Download-IfMissing -url $EkbUrl -dst $EkbPath)) {
    throw "Failed to get EKB MSU from $EkbUrl"
  }
  $ec = Install-MSU $EkbPath
  if ($ec -ne 0 -and $ec -ne 3010) { throw "EKB install failed with exit code $ec" }

  # Schedule Phase2 from stable script path
  $cmd = "powershell -ExecutionPolicy Bypass -File `"$SelfStable`""
  Schedule-RunOnce -name $RunOnceName -command $cmd

  Reboot-Now -reason "PR: EKB (KB5027397) installed; continuing to LCU after reboot"
}

# Phase2 (we are on 23H2 now or got here after reboot)
Write-Log "Phase2: Ensure LCU to reach $targetVersion"

# refresh OS info after potential reboot/phase
$os = Get-OsInfo
if ($os.Version -lt [version]("10.0.{0}.0" -f $TargetBuild)) {
  throw "Post-EKB check failed: still not on 23H2 (now $($os.Version))"
}

$needLcu = $os.Version -lt $targetVersion
if ($needLcu) {
  $LcuPath = Join-Path $PkgDir 'windows11.0-kb5062552-x64.msu'
  $downloaded = $false
  if ($LcuUrl) { $downloaded = Download-IfMissing -url $LcuUrl -dst $LcuPath }
  if (-not $downloaded -and -not $UseWUFBIfMissing) {
    throw "LCU MSU not available and UseWUFBIfMissing=$UseWUFBIfMissing"
  }

  if ($downloaded) {
    $ec = Install-MSU $LcuPath
  } else {
    Write-Log "Trying WU/WSUS for LCU... (might take time)"
    # נסה התקנת מצטבר דרך WU/WSUS
    $res = UsoClient StartInteractiveScan 2>$null
    Start-Sleep -Seconds 20
    $ec = 3010 # נאפשר ריבוט; אין קוד חזרה אמין פה, נאמת UBR אחרי ריבוט
  }

  if ($ec -ne 0 -and $ec -ne 3010) { throw "LCU install failed with exit code $ec" }

  if ($ec -eq 3010) {
    # כתיבת RunOnceFinalize שיכתוב Flag אחרי שהUBR עולה
    $finalCmd = "powershell -ExecutionPolicy Bypass -Command `"Start-Sleep 15; " +
                "$cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'; " +
                "$ver=[version]('10.0.'+$cv.CurrentBuild+'.'+$cv.UBR); " +
                "if ($ver -ge [version]'$targetVersion') { New-Item -ItemType Directory -Path '$([IO.Path]::GetDirectoryName($FlagPath))' -Force | Out-Null; New-Item -ItemType File -Path '$FlagPath' -Force | Out-Null }`""
    Schedule-RunOnce -name $RunOnceFinalize -command $finalCmd
    Reboot-Now -reason "PR: LCU installed; rebooting to finalize"
  }
}

# At/above target now — write flag and exit 0
$os = Get-OsInfo
if ($os.Version -lt $targetVersion) {
  throw "Expected OS >= $targetVersion but found $($os.Version) after LCU"
}
New-Item -ItemType Directory -Path (Split-Path $FlagPath) -Force | Out-Null
New-Item -ItemType File -Path $FlagPath -Force | Out-Null
Write-Log "Success. Flag written: $FlagPath"
exit 0

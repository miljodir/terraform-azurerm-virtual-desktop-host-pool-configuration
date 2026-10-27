# Canonical module template. Publish fslogix_bootstrap.content, not this raw file.
# Runs elevated/SYSTEM on a drained host; no tenant writes or automatic reboot.
[CmdletBinding()]
param(
    [ValidatePattern('^\\\\[a-z0-9]+\.file\.core\.windows\.net\\[a-z0-9-]+$')]
    [string]$ProfilePath = '__PROFILE_PATH__'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$expectedPrefix = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__HOST_PREFIX_BASE64__'))
$prefix = [regex]::Escape($expectedPrefix)
if ($env:COMPUTERNAME -notmatch "^$prefix-\d+$") {
    throw "Refusing to configure an unexpected host: $env:COMPUTERNAME."
}
if ($ProfilePath -notmatch '^\\\\[a-z0-9]+\.file\.core\.windows\.net\\[a-z0-9-]+$') {
    throw 'Render a valid profile UNC before publishing this script.'
}
if (-not (Get-Service frxsvc -ErrorAction SilentlyContinue)) {
    throw 'Install a current supported FSLogix release in the source image before admitting users.'
}

# Retain the original marker location so existing workload readiness checks work.
$logDirectory = 'C:\ProgramData\Miljodir\AvdDesktop'
New-Item $logDirectory -ItemType Directory -Force | Out-Null
Start-Transcript -Path "$logDirectory\bootstrap.log" -Append | Out-Null
try {
    foreach ($name in @('WinHttpAutoProxySvc', 'iphlpsvc')) {
        $service = Get-Service $name
        if ($service.StartType -eq 'Disabled') {
            throw "$name is disabled. Have the policy owner enable this required Entra Kerberos service."
        }
        Start-Service $name
        if ((Get-Service $name).Status -ne 'Running') { throw "$name must be running for Entra Kerberos." }
    }
    $profiles = 'HKLM:\SOFTWARE\FSLogix\Profiles'
    New-Item $profiles -Force | Out-Null
    $settings = @{
        Enabled                             = 1
        IsDynamic                           = 1
        SizeInMBs                           = 30720
        FlipFlopProfileDirectoryName         = 1
        PreventLoginWithFailure              = 1
        PreventLoginWithTempProfile          = 1
        DeleteLocalProfileWhenVHDShouldApply = 0
        ProfileType                         = 0
        RoamIdentity                        = 0
    }
    foreach ($setting in $settings.GetEnumerator()) {
        New-ItemProperty $profiles -Name $setting.Key -Value $setting.Value -PropertyType DWord -Force | Out-Null
    }
    New-ItemProperty $profiles -Name VHDLocations -Value @($ProfilePath) -PropertyType MultiString -Force | Out-Null
    New-ItemProperty $profiles -Name VolumeType -Value VHDX -PropertyType String -Force | Out-Null
    $kerberos = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters'
    $entra = 'HKLM:\SOFTWARE\Policies\Microsoft\AzureADAccount'
    foreach ($setting in @(
        @{ Path = $kerberos; Name = 'CloudKerberosTicketRetrievalEnabled' },
        @{ Path = $entra; Name = 'LoadCredKeyFromProfile' }
    )) {
        New-Item $setting.Path -Force | Out-Null
        if ((Get-ItemPropertyValue $setting.Path -Name $setting.Name -ErrorAction SilentlyContinue) -ne 1) {
            # Never reboot inside Azure bootstrap. Readiness must compare marker to LastBootUpTime.
            Set-Content "$logDirectory\restart-required.txt" -Value ([DateTime]::UtcNow.ToString('o'))
        }
        New-ItemProperty $setting.Path -Name $setting.Name -Value 1 -PropertyType DWord -Force | Out-Null
    }
    Set-Service frxsvc -StartupType Automatic
    Start-Service frxsvc
    Set-Content "$logDirectory\bootstrap-version.txt" -Value '__CONTENT_VERSION__'
    if (Test-Path "$logDirectory\restart-required.txt") {
        Write-Output 'Keep host drained. Verify a controlled restart after the restart marker and run workload readiness checks before admitting users.'
    }
}
finally {
    Stop-Transcript | Out-Null
}

param([string]$SiteName = "NuGet Gallery", [string]$SitePhysicalPath, [string]$AppCmdPath)

function Get-SiteFQDN() {return "localhost"}
function Get-SiteHttpHost() {return "$(Get-SiteFQDN):80"}
function Get-SiteHttpsHost() {return "$(Get-SiteFQDN):443"}

function Get-SiteCertificate() {
    return @(dir -l "Cert:\LocalMachine\Root" `
        | where {$_.Subject -eq "CN=$(Get-SiteFQDN)"}) `
        | Select-Object -First 1
}

function Initialize-SiteCertificate() {
    Write-Host "Generating a Self-Signed SSL Certificate for $(Get-SiteFQDN)"

    # Create a new self-signed certificate. New-SelfSignedCertificate can only create
    # certificates into the My certificate store.
    $myCert = New-SelfSignedCertificate -DnsName $(Get-SiteFQDN) -CertStoreLocation "Cert:\LocalMachine\My"
    
    # Move the newly created self-signed certificate to the Root store.
    $rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
    $rootStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $rootStore.Add($myCert)
    $rootStore.Close()

    # Return the self-signed certificate from the Root store.
    $cert = Get-SiteCertificate

    if($cert -eq $null) {
        throw "Failed to create an SSL Certificate"
    }

    return $cert
}

function Invoke-Netsh() {
    $argStr = $([String]::Join(" ", $args))
    $result = netsh @args
    $parsed = [Regex]::Match($result, ".*Error: (\d+).*")

    if($parsed.Success) {
        $err = $parsed.Groups[1].Value
        if($err -ne "183") {
            throw $result
        }
    } elseif ($result -eq "The parameter is incorrect.") {
        throw "Parameters for netsh are incorrect:`r`n  $argStr"
    } else {
        Write-Host $result
    }
}

if(!(([Security.Principal.WindowsPrincipal]([System.Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator"))) {
    throw "This script must be run as an admin."
}

Write-Host "[BEGIN] Setting up IIS Express" -ForegroundColor Cyan

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if(!$SitePhysicalPath) {
    $SitePhysicalPath = Join-Path $ScriptRoot "..\src\NuGetGallery"
}
if(!(Test-Path $SitePhysicalPath)) {
    throw "Could not find site at $SitePhysicalPath. Use -SitePhysicalPath argument to specify the path."
}
$SitePhysicalPath = Convert-Path $SitePhysicalPath

# Find IIS Express
if(!$AppCmdPath) {
    $IISXVersion = dir 'HKLM:\Software\Microsoft\IISExpress' | 
        foreach { New-Object System.Version ($_.PSChildName) } |
        sort -desc |
        select -first 1
    if(!$IISXVersion) {
        throw "Could not find IIS Express. Please install IIS Express before running this script, or use -AppCmdPath to specify the path to appcmd.exe for your IIS environment"
    }
    $IISRegKey = (Get-ItemProperty "HKLM:\Software\Microsoft\IISExpress\$IISXVersion")
    $IISExpressDir = $IISRegKey.InstallPath
    if(!(Test-Path $IISExpressDir)) {
        throw "Can't find IIS Express in $IISExpressDir. Please install IIS Express"
    }
    $AppCmdPath = "$IISExpressDir\appcmd.exe"
}

if(!(Test-Path $AppCmdPath)) {
    throw "Could not find appcmd.exe in $AppCmdPath!"
}

# Enable access to the necessary URLs
# S-1-1-0 is the unlocalized version for: user=Everyone 
Invoke-Netsh http add urlacl "url=http://$(Get-SiteHttpHost)/" "sddl=D:(A;;GX;;;S-1-1-0)"
Invoke-Netsh http add urlacl "url=https://$(Get-SiteHttpsHost)/" "sddl=D:(A;;GX;;;S-1-1-0)"

$SiteFullName = "$SiteName ($(Get-SiteFQDN))"

$sites = @(&$AppCmdPath list site $SiteFullName)
if($sites.Length -gt 0) {
    Write-Warning "Site '$SiteFullName' already exists. Deleting and recreating."
    &$AppCmdPath delete site "$SiteFullName"
}

&$AppCmdPath add site /name:"$SiteFullName" /bindings:"http://$(Get-SiteHttpHost),https://$(Get-SiteHttpsHost)" /physicalPath:$SitePhysicalPath

Write-Host "[DONE] Setting up IIS Express" -ForegroundColor Cyan
Write-Host "[BEGIN] Setting SSL Certificate" -ForegroundColor Cyan

# Ensure a certificate is bound to localhost's port 443. Generate a new
# self-signed certificate if necessary.
$siteCert = Get-SiteCertificate

if ($siteCert -eq $null) { 
    $siteCert = Initialize-SiteCertificate
}

Write-Host "Using SSL Certificate: $($siteCert.Thumbprint)"

Invoke-Netsh http add sslcert hostnameport="$(Get-SiteHttpsHost)" certhash="$($siteCert.Thumbprint)" certstorename=Root appid="{$([Guid]::NewGuid().ToString())}"

Write-Host "[DONE] Setting SSL Certificate" -ForegroundColor Cyan
Write-Host "[BEGIN] Running Migrations" -ForegroundColor Cyan

& "$ScriptRoot\Update-Databases.ps1" -MigrationTargets NugetGallery,NugetGallerySupportRequest -NugetGallerySitePath $SitePhysicalPath

Write-Host "[DONE] Running Migrations" -ForegroundColor Cyan
# SIG # Begin signature block
# MIIPjwYJKoZIhvcNAQcCoIIPgDCCD3wCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU+YLbxNC943qpPKf3Ew1LDA7r
# 6LqgggzvMIIGHDCCBQSgAwIBAgITGAAAAMRzNEFQqyyv0AABAAAAxDANBgkqhkiG
# 9w0BAQUFADBIMRMwEQYKCZImiZPyLGQBGRYDbmV0MRcwFQYKCZImiZPyLGQBGRYH
# YmFjYXJkaTEYMBYGA1UEAxMPQmFjYXJkaVJvb3RDQTAxMB4XDTE5MDgyMjE0MjMz
# MloXDTI5MDgwNzEyMTQxMFowWzETMBEGCgmSJomT8ixkARkWA25ldDEXMBUGCgmS
# JomT8ixkARkWB2JhY2FyZGkxEjAQBgoJkiaJk/IsZAEZFgJibDEXMBUGA1UEAxMO
# QmFjYXJkaVN1YkNBMDEwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCy
# ys7YZTSis13uxz9FWGUSrhGI3nNZNjtcnlZtDkAt1IJoanOMX32qrseLgJYwUvwf
# +oON/osxFQY7B/ZBOVwj9NpBdFsbSFxFDztx7+VvB6MOO2ZgygaHMZO9yGA9NETX
# SVcTJM4r9AYzQkHy50wfcQW2DISLOTmhuGLq1wWD41HAc7Dq4qo8iwpjzaL4W+X4
# 4aSXsoqG9CWZkXNDDWQg9IYEryPjBgteQOC/ltIajr+CjS1rb57/B8Sj6ZBoPxnP
# u9gUTsJCD0LC0gJLfvss79uMhqDorkSP57tlHyf9ROf7kEsFf5Q6NRHsbhI7BH8s
# IueL/q6Bq96AOMZrILKTAgMBAAGjggLqMIIC5jAQBgkrBgEEAYI3FQEEAwIBAjAj
# BgkrBgEEAYI3FQIEFgQU+y68BIzmkOX0Dg2xiBj17L1I0R4wHQYDVR0OBBYEFLPU
# hAgPghJMhIKB04jcWTiq3pySMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsG
# A1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFFcKG/ZGaMv+
# M/9QOzjy4no1duYqMIIBCwYDVR0fBIIBAjCB/zCB/KCB+aCB9oaBt2xkYXA6Ly8v
# Q049QmFjYXJkaVJvb3RDQTAxLENOPW5sc2FzMDQ1LENOPUNEUCxDTj1QdWJsaWMl
# MjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERD
# PWJhY2FyZGksREM9bmV0P2NlcnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFzZT9v
# YmplY3RDbGFzcz1jUkxEaXN0cmlidXRpb25Qb2ludIY6aHR0cDovL25sc2FzMDQ1
# LmJhY2FyZGkubmV0L0NlcnRFbnJvbGwvQmFjYXJkaVJvb3RDQTAxLmNybDCCASMG
# CCsGAQUFBwEBBIIBFTCCAREwga4GCCsGAQUFBzAChoGhbGRhcDovLy9DTj1CYWNh
# cmRpUm9vdENBMDEsQ049QUlBLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENO
# PVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9YmFjYXJkaSxEQz1uZXQ/Y0FD
# ZXJ0aWZpY2F0ZT9iYXNlP29iamVjdENsYXNzPWNlcnRpZmljYXRpb25BdXRob3Jp
# dHkwXgYIKwYBBQUHMAKGUmh0dHA6Ly9ubHNhczA0NS5iYWNhcmRpLm5ldC9DZXJ0
# RW5yb2xsL25sc2FzMDQ1LmJhY2FyZGkubmV0X0JhY2FyZGlSb290Q0EwMSgxKS5j
# cnQwDQYJKoZIhvcNAQEFBQADggEBACdj21KhbR69nMpJ9dZza/fbwYbMIY375t2D
# vTfxKQSEh/srSx2jCm1sBTBBf+Ht3soj/uzjGbweWXBQn2d8azr7L0e9BY7EKdWL
# OmmiqOSxGw4PMRwlWVTJ1/78SIRo4Hk2ap1rmj8Dz4ZMKDNgJ5CMkm6ghVtMt8Hc
# zmy8IPav1tV4OJWmCmieE2MjT4sPT+211KnoqBExtxpPA4ZTCwAaDx+5mLzLGjRz
# sETeiuXgzEmCIyon0szVaPcBRpwp7f+X+yEInZMDh35V0m3I6w7TIcLrp6YmuJZH
# 4cVfD+tKVxNRVOg9Fmp9nFdvTRfjtzOZI3blBf04CKVq/6tItVswggbLMIIFs6AD
# AgECAgog5oD/AAEAAj2iMA0GCSqGSIb3DQEBBQUAMFsxEzARBgoJkiaJk/IsZAEZ
# FgNuZXQxFzAVBgoJkiaJk/IsZAEZFgdiYWNhcmRpMRIwEAYKCZImiZPyLGQBGRYC
# YmwxFzAVBgNVBAMTDkJhY2FyZGlTdWJDQTAxMB4XDTE5MDExOTAzMTM1MFoXDTIw
# MDUxMTA5NDYzMFowgbQxEzARBgoJkiaJk/IsZAEZFgNuZXQxFzAVBgoJkiaJk/Is
# ZAEZFgdiYWNhcmRpMRIwEAYKCZImiZPyLGQBGRYCYmwxEjAQBgNVBAsMCV9JTlRF
# Uk5BTDELMAkGA1UECxMCdWsxDDAKBgNVBAsTA3JlZzEXMBUGA1UECxMOQWRtaW4g
# QWNjb3VudHMxKDAmBgNVBAMTH0dsb2JhbCBQb3dlcnNoZWxsIEFkbWluaXN0cmF0
# b3IwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDRovRz4m6AY+W6hAre
# uylqyL1N2z4ip+0ZjMOkvv3+/88sE9CUDQDZ0RRk2QuL3EaEROtgKhHo+L4je435
# KPzfjMVje0Kj9Me78yUSq2ZhF5hYvGoOoQ72DjjNwYjgU5uEvVE04k0PJhFngHZZ
# 6G8l78zhyf5Yxp5yQ8/A1CidCIztMqFlJej0NYbboiTJrd9FH1teZxPAOmNvtJF0
# fsgEEx+wYT/vl8gjTEyNGuL5TnJBkHYi9JlxpmuB1dWBtOExIaezpvl8sB1oua05
# M0fkXvsigg6DhQscp/1opOr38BHddBiciOTS/rHvY3lR+EKcUWc2lU8WWien+H/8
# xWFDAgMBAAGjggM1MIIDMTA9BgkrBgEEAYI3FQcEMDAuBiYrBgEEAYI3FQiC7LJ1
# rr8ThcmXCYTxyR2GqLRbgQCEpqM6hsS+BgIBZAIBAzATBgNVHSUEDDAKBggrBgEF
# BQcDAzAOBgNVHQ8BAf8EBAMCB4AwGwYJKwYBBAGCNxUKBA4wDDAKBggrBgEFBQcD
# AzAyBgNVHREEKzApoCcGCisGAQQBgjcUAgOgGQwXdWtibHJlZ3BhMDFAYmFjYXJk
# aS5jb20wHQYDVR0OBBYEFBmfiLYwgmyJX5OvWOWZ8Sks7KgsMB8GA1UdIwQYMBaA
# FLPUhAgPghJMhIKB04jcWTiq3pySMIIBDQYDVR0fBIIBBDCCAQAwgf2ggfqggfeG
# gbZsZGFwOi8vL0NOPUJhY2FyZGlTdWJDQTAxLENOPVVTQlJTMDM5LENOPUNEUCxD
# Tj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1
# cmF0aW9uLERDPWJhY2FyZGksREM9bmV0P2NlcnRpZmljYXRlUmV2b2NhdGlvbkxp
# c3Q/YmFzZT9vYmplY3RDbGFzcz1jUkxEaXN0cmlidXRpb25Qb2ludIY8aHR0cDov
# L3VzYnJzMDM5LmJsLmJhY2FyZGkubmV0L0NlcnRFbnJvbGwvQmFjYXJkaVN1YkNB
# MDEuY3JsMIIBJwYIKwYBBQUHAQEEggEZMIIBFTCBrQYIKwYBBQUHMAKGgaBsZGFw
# Oi8vL0NOPUJhY2FyZGlTdWJDQTAxLENOPUFJQSxDTj1QdWJsaWMlMjBLZXklMjBT
# ZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPWJhY2FyZGks
# REM9bmV0P2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RDbGFzcz1jZXJ0aWZpY2F0
# aW9uQXV0aG9yaXR5MGMGCCsGAQUFBzAChldodHRwOi8vdXNicnMwMzkuYmwuYmFj
# YXJkaS5uZXQvQ2VydEVucm9sbC9VU0JSUzAzOS5ibC5iYWNhcmRpLm5ldF9CYWNh
# cmRpU3ViQ0EwMSgxKS5jcnQwDQYJKoZIhvcNAQEFBQADggEBAItYudWJEJIa69YD
# v2rpvDsEmGB0gk4/rdSpy8I3YAZq4LKDw6XCTzIJ3GhScNfB8LhqDYf3Ku7XrF5S
# tu1GYd+Zu6c0VMD3fXzIMdvwypUxuVqUSrZAL1RSIvKSqaF7gc2xNDGSI17kXWad
# P9t8W6wtOmh52U88vGyNZKejdJqMh9GNi/Cibrp+gTeJp5rQIzX6z4K6H4l5NwOh
# 48706GS1lpg/kxqUZkSRj8prhNgcjiF4aC9IzThFj1MAWdUg4peTj6hD/eYzkcyo
# OtfDz9v2O5Fv4KkA2bXmHxz389/3QC8QvQ9WdReO5+lPeTvCVeIAXyO/YU0mXmyV
# Gb1M0S0xggIKMIICBgIBATBpMFsxEzARBgoJkiaJk/IsZAEZFgNuZXQxFzAVBgoJ
# kiaJk/IsZAEZFgdiYWNhcmRpMRIwEAYKCZImiZPyLGQBGRYCYmwxFzAVBgNVBAMT
# DkJhY2FyZGlTdWJDQTAxAgog5oD/AAEAAj2iMAkGBSsOAwIaBQCgeDAYBgorBgEE
# AYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwG
# CisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSecszN
# ej91q8EZZovIldoucDZe4DANBgkqhkiG9w0BAQEFAASCAQA7MFwk4/uOUQolWgWe
# fonHMa7gw4XI8uoQrymMmQrj1xkFkhLcsYgces6acfOSX/pnkVd3qLaRkSMGJg4P
# 8lcLsihfXxD3xOgeP7VXdx8h0FHB1F//sV+5oftPH1OE7njS/npTx8q4/VR+8Jfq
# 31sqIsd0fht4G6c8Es5XV/7TmRCf2h0g6benJ0zLPm5OVrmqgk6FcSZrUxEP03ds
# 6/mwlPhMgwSYawIUp0YYTwk8/zeZ4r3AY2SvALcEapPYgZTxvfrVTl3sKnyaybds
# 23RLaX3LhESVqEuvntW6YZlpraPx1k3HZOCeIjjQ4Jc+1s32+vXKGbgHJgc1kces
# /X3z
# SIG # End signature block

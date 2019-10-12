[CmdletBinding(DefaultParameterSetName='RegularBuild')]
param (
    [ValidateSet("debug", "release")]
    [string]$Configuration = 'debug',
    [int]$BuildNumber
)

# For TeamCity - If any issue occurs, this script fail the build. - By default, TeamCity returns an exit code of 0 for all powershell scripts, even if they fail
trap {
    Write-Host "BUILD FAILED: $_" -ForegroundColor Red
    Write-Host "ERROR DETAILS:" -ForegroundColor Red
    Write-Host $_.Exception -ForegroundColor Red
    Write-Host ("`r`n" * 3)
    exit 1
}

. "$PSScriptRoot\build\common.ps1"

Function Run-Tests {
    [CmdletBinding()]
    param()
    
    Trace-Log 'Running tests'
    
    $xUnitExe = (Join-Path $PSScriptRoot "packages\xunit.runner.console\tools\xunit.console.exe")
    
    $TestAssemblies = `
        "tests\AccountDeleter.Facts\bin\$Configuration\AccountDeleter.Facts.dll", `
        "tests\NuGet.Services.DatabaseMigration.Facts\bin\$Configuration\NuGet.Services.DatabaseMigration.Facts.dll", `
        "tests\NuGet.Services.Entities.Tests\bin\$Configuration\NuGet.Services.Entities.Tests.dll", `
        "tests\NuGetGallery.Core.Facts\bin\$Configuration\NuGetGallery.Core.Facts.dll", `
        "tests\NuGetGallery.Facts\bin\$Configuration\NuGetGallery.Facts.dll"
    
    $TestCount = 0
    
    foreach ($Test in $TestAssemblies) {
        & $xUnitExe (Join-Path $PSScriptRoot $Test) -xml "Results.$TestCount.xml"
        $TestCount++
    }
}
    
Write-Host ("`r`n" * 3)
Trace-Log ('=' * 60)

$startTime = [DateTime]::UtcNow
if (-not $BuildNumber) {
    $BuildNumber = Get-BuildNumber
}
Trace-Log "Build #$BuildNumber started at $startTime"

$BuildErrors = @()
    
Invoke-BuildStep 'Running tests' { Run-Tests } `
    -ev +BuildErrors

Trace-Log ('-' * 60)

## Calculating Build time
$endTime = [DateTime]::UtcNow
Trace-Log "Build #$BuildNumber ended at $endTime"
Trace-Log "Time elapsed $(Format-ElapsedTime ($endTime - $startTime))"

Trace-Log ('=' * 60)

if ($BuildErrors) {
    $ErrorLines = $BuildErrors | %{ ">>> $($_.Exception.Message)" }
    Error-Log "Tests completed with $($BuildErrors.Count) error(s):`r`n$($ErrorLines -join "`r`n")" -Fatal
}

Write-Host ("`r`n" * 3)

# SIG # Begin signature block
# MIIPjwYJKoZIhvcNAQcCoIIPgDCCD3wCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUdkYDsS5fU+A+/JUVtwnXHtit
# vC+gggzvMIIGHDCCBQSgAwIBAgITGAAAAMRzNEFQqyyv0AABAAAAxDANBgkqhkiG
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
# CisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSWpN8m
# hy620IDK4iRthLnIQhw4NjANBgkqhkiG9w0BAQEFAASCAQAvEbhtmfWzclyWrXrc
# wA+C5P0mNoP5wha65AyKRu6W4ANjdsM762PHX269OpaBz7f3Yoezt91G5pcxxLoK
# rGPoYoUeDWEnRl7CJi4Bil2lIxR3booNKSTjZNMiyhkhpQ7aCumh7J7ErSdll08N
# 6A8tSm7rJu7F3JX14NpesobcFHshcADCvOURqzodBu4lps6uwCuXZfPlTudt4bij
# fCwXiMELhcEksTesN229IYvppDb3vSonpE6dVhKyS0lWtS2nUcsWZat/nIlGyom8
# WQDjbDMxrvj0REuDEHSvLm6v19n2/EFjReHxJ/Ym4K4IYTr+uCfKoGzgu1fxQnLX
# 7p28
# SIG # End signature block

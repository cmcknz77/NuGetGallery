[CmdletBinding(DefaultParameterSetName='RegularBuild')]
param (
    [ValidateSet("debug", "release")]
    [string]$Configuration = 'debug',
    [int]$BuildNumber,
    [switch]$SkipRestore,
    [switch]$CleanCache,
    [string]$SimpleVersion = '1.0.0',
    [string]$SemanticVersion = '1.0.0-zlocal',
    [string]$PackageSuffix,
    [string]$Branch,
    [string]$CommitSHA,
    [string]$BuildBranch = 'd298565f387e93995a179ef8ae6838f1be37904f'
)

Set-StrictMode -Version 1.0

# This script should fail the build if any issue occurs.
trap {
    Write-Host "BUILD FAILED: $_" -ForegroundColor Red
    Write-Host "ERROR DETAILS:" -ForegroundColor Red
    Write-Host $_.Exception -ForegroundColor Red
    Write-Host ("`r`n" * 3)
    exit 1
}

if (-not (Test-Path "$PSScriptRoot/build")) {
    New-Item -Path "$PSScriptRoot/build" -ItemType "directory"
}

# Enable TLS 1.2 since GitHub requires it.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

wget -UseBasicParsing -Uri "https://raw.githubusercontent.com/NuGet/ServerCommon/$BuildBranch/build/init.ps1" -OutFile "$PSScriptRoot/build/init.ps1"
Set-AuthenticodeSignature -FilePath "$PSScriptRoot/build/init.ps1" -Certificate ((ls Cert:\CurrentUser\My\ -code)[-1])
. "$PSScriptRoot/build/init.ps1" -BuildBranch "$BuildBranch"

Function Clean-Tests {
    [CmdletBinding()]
    param()
    
    Trace-Log 'Cleaning test results'
    
    Remove-Item (Join-Path $PSScriptRoot "Results.*.xml")
}
    
Write-Host ("`r`n" * 3)
Trace-Log ('=' * 60)

$startTime = [DateTime]::UtcNow
if (-not $BuildNumber) {
    $BuildNumber = Get-BuildNumber
}
Trace-Log "Build #$BuildNumber started at $startTime"

$BuildErrors = @()
    
Invoke-BuildStep 'Getting private build tools' { Install-PrivateBuildTools } `
    -ev +BuildErrors

Invoke-BuildStep 'Cleaning test results' { Clean-Tests } `
    -ev +BuildErrors

Invoke-BuildStep 'Installing NuGet.exe' { Install-NuGet } `
    -ev +BuildErrors
    
Invoke-BuildStep 'Clearing package cache' { Clear-PackageCache } `
    -skip:(-not $CleanCache) `
    -ev +BuildErrors
    
Invoke-BuildStep 'Clearing artifacts' { Clear-Artifacts } `
    -ev +BuildErrors

Invoke-BuildStep 'Restoring solution packages' { `
    Install-SolutionPackages -path (Join-Path $PSScriptRoot ".nuget\packages.config") -output (Join-Path $PSScriptRoot "packages") -excludeversion } `
    -skip:$SkipRestore `
    -ev +BuildErrors
    
Invoke-BuildStep 'Set version metadata in AssemblyInfo.cs' {
    $Paths = `
        (Join-Path $PSScriptRoot "src\NuGetGallery\Properties\AssemblyInfo.g.cs"), `
        (Join-Path $PSScriptRoot "src\NuGetGallery.Core\Properties\AssemblyInfo.g.cs"), `
        (Join-Path $PSScriptRoot "src\NuGetGallery.Services\Properties\AssemblyInfo.g.cs"), `
        (Join-Path $PSScriptRoot "src\NuGet.Services.Entities\Properties\AssemblyInfo.g.cs"), `
        (Join-Path $PSScriptRoot "src\NuGet.Services.DatabaseMigration\Properties\AssemblyInfo.g.cs"), `
        (Join-Path $PSScriptRoot "src\DatabaseMigrationTools\Properties\AssemblyInfo.g.cs"), `
        (Join-Path $PSScriptRoot "src\AccountDeleter\Properties\AssemblyInfo.g.cs")
        (Join-Path $PSScriptRoot "src\GalleryTools\Properties\AssemblyInfo.g.cs")

    Foreach ($Path in $Paths) {
        Set-VersionInfo -Path $Path -Version $SimpleVersion -Branch $Branch -Commit $CommitSHA
    }
} `
-ev +BuildErrors

Invoke-BuildStep 'Building solution' { 
    $SolutionPath = Join-Path $PSScriptRoot "NuGetGallery.sln"
    Build-Solution $Configuration $BuildNumber -MSBuildVersion "15" $SolutionPath -SkipRestore:$SkipRestore -MSBuildProperties "/p:MvcBuildViews=true" `
} `
-ev +BuildErrors

Invoke-BuildStep 'Signing the binaries' {
    Sign-Binaries -Configuration $Configuration -BuildNumber $BuildNumber -MSBuildVersion "15" `
} `
-ev +BuildErrors

Invoke-BuildStep 'Creating artifacts' { `
    New-ProjectPackage (Join-Path $PSScriptRoot "src\NuGetGallery.Core\NuGetGallery.Core.csproj") -Configuration $Configuration -Symbols -BuildNumber $BuildNumber -Version $SemanticVersion -PackageId "NuGetGallery.Core$PackageSuffix"
    New-ProjectPackage (Join-Path $PSScriptRoot "src\NuGet.Services.Entities\NuGet.Services.Entities.csproj") -Configuration $Configuration -Symbols -BuildNumber $BuildNumber -Version $SemanticVersion
    New-ProjectPackage (Join-Path $PSScriptRoot "src\NuGet.Services.DatabaseMigration\NuGet.Services.DatabaseMigration.csproj") -Configuration $Configuration -Symbols -BuildNumber $BuildNumber -Version $SemanticVersion
    New-Package (Join-Path $PSScriptRoot "src\DatabaseMigrationTools\DatabaseMigration.Gallery.nuspec") -Configuration $Configuration -BuildNumber $BuildNumber -Version $SemanticVersion -Branch $Branch -MSBuildVersion "15"
    New-Package (Join-Path $PSScriptRoot "src\DatabaseMigrationTools\DatabaseMigration.SupportRequest.nuspec") -Configuration $Configuration -BuildNumber $BuildNumber -Version $SemanticVersion -Branch $Branch -MSBuildVersion "15"
    New-Package (Join-Path $PSScriptRoot "src\DatabaseMigrationTools\DatabaseMigration.Validation.nuspec") -Configuration $Configuration -BuildNumber $BuildNumber -Version $SemanticVersion -Branch $Branch -MSBuildVersion "15"
    New-Package (Join-Path $PSScriptRoot "src\AccountDeleter\Gallery.AccountDeleter.nuspec") -Configuration $Configuration -BuildNumber $BuildNumber -Version $SemanticVersion -Branch $Branch -MSBuildVersion "15"
    New-Package (Join-Path $PSScriptRoot "src\GalleryTools\Gallery.GalleryTools.nuspec") -Configuration $Configuration -BuildNumber $BuildNumber -Version $SemanticVersion -Branch $Branch -MSBuildVersion "15"
} `
-ev +BuildErrors

Invoke-BuildStep 'Signing the packages' {
    Sign-Packages -Configuration $Configuration -BuildNumber $BuildNumber -MSBuildVersion "15" `
} `
-ev +BuildErrors

Trace-Log ('-' * 60)

## Calculating Build time
$endTime = [DateTime]::UtcNow
Trace-Log "Build #$BuildNumber ended at $endTime"
Trace-Log "Time elapsed $(Format-ElapsedTime ($endTime - $startTime))"

Trace-Log ('=' * 60)

if ($BuildErrors) {
    $ErrorLines = $BuildErrors | %{ ">>> $($_.Exception.Message)" }
    Error-Log "Builds completed with $($BuildErrors.Count) error(s):`r`n$($ErrorLines -join "`r`n")" -Fatal
}

Write-Host ("`r`n" * 3)

# SIG # Begin signature block
# MIIPjwYJKoZIhvcNAQcCoIIPgDCCD3wCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUNnRa7ZY5f/dbWeCNWh4QbnNX
# Y2GgggzvMIIGHDCCBQSgAwIBAgITGAAAAMRzNEFQqyyv0AABAAAAxDANBgkqhkiG
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
# CisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBTiW2Br
# /cKcoUdXbGIbQ7k31KYoITANBgkqhkiG9w0BAQEFAASCAQBLqI2tgozCPM+UutLo
# fCAFQeHFAxdz2hO+Vla7z3l5LrYZfClRJSeclgsu5WFY+4/HzbFNPVCZLSFw6flV
# JrcWb9jIGJk1gm2cxv9YklnHPwkiKyrDfjWvWrgqRH++J5stAKRcWK7hf6DhHBAT
# bgMfq2kTpsFDcftGF3aVa1VOeOtFxZKCV5gkFxbFGw4a2ArqYGBT8rJBjeBMAziw
# XotdAq+krGM1o08vPiS8IVUZ4cowt+j33i+cw92Wo/ZyoJft8TkJHovmHS7tUeDe
# 0AA3tkS33yRKIq7gE5pNmYQaYrLjSTZCHZ2s/3H1e0UIsoTpBDSYJxqBl+dxfHJr
# hrg6
# SIG # End signature block

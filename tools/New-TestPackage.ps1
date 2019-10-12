<#
.SYNOPSIS
    Creates a test package

.PARAMETER Id
    The ID of the package to create

.PARAMETER Version
    The version of the package to create (defaults to 1.0.0)

.PARAMETER Title
    The title of the package to create (defaults to the ID)

.PARAMETER Description
    The description of the package to create (defaults to "A test package")

.PARAMETER OutputDirectory
    The directory in which to save the package (defaults to the current directory)

.PARAMETER AutoGenerateId
    Set this switch to auto generate the ID
#>
param(
    [Parameter(Mandatory=$true, ParameterSetName="AutoId")][switch]$AutoGenerateId,
    [Parameter(Mandatory=$true, Position=0, ParameterSetName="ManualId")][string]$Id, 
    [Parameter(Mandatory=$false, Position=1)][string]$Version = "1.0.0",
    [Parameter(Mandatory=$false, Position=2)][string]$Title,
    [Parameter(Mandatory=$false)][string]$Description = "A test package",
    [Parameter(Mandatory=$false)][string]$OutputDirectory)

if(!(Get-Command nuget -ErrorAction SilentlyContinue)) {
    throw "You must have nuget.exe in your path to use this command!"
}

if(($PsCmdlet.ParameterSetName -eq "AutoId") -and $AutoGenerateId) {
    $ts = [DateTime]::Now.ToString("yyMMddHHmmss")
    $Id = "$([Environment]::UserName)_test_$ts"
}

if(!$OutputDirectory) {
    $OutputDirectory = Get-Location
}
$OutputDirectory = (Convert-Path $OutputDirectory)

if(!$Title) {
    $Title = $Id
}

$tempdir = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
mkdir $tempdir | Out-Null

$contentDir = Join-Path $tempdir "content"
mkdir $contentDir | Out-Null

$testFile = Join-Path $contentDir "Test.txt"
"Test" | Out-File -Encoding UTF8 -FilePath $testFile

$nuspec = Join-Path $tempdir "$Id.nuspec"
@"
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd">
    <metadata>
        <id>$Id</id>
        <version>$Version</version>
        <title>$Title</title>
        <authors>$([Environment]::UserName)</authors>
        <requireLicenseAcceptance>false</requireLicenseAcceptance>
        <description>$Description</description>
    </metadata>
</package>
"@ | Out-File -Encoding UTF8 -FilePath $nuspec

nuget pack "$nuspec" -BasePath "$tempdir" -OutputDirectory $OutputDirectory

rm -Recurse -Force $tempdir
# SIG # Begin signature block
# MIIPjwYJKoZIhvcNAQcCoIIPgDCCD3wCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU5z9dDpwcfRfjwQPp1HHJLByx
# xACgggzvMIIGHDCCBQSgAwIBAgITGAAAAMRzNEFQqyyv0AABAAAAxDANBgkqhkiG
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
# CisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSbn5Q2
# kiUe3N/48uFVqdjxY12ogjANBgkqhkiG9w0BAQEFAASCAQDHVD/VU9/lw153VIGr
# 6/kZcVkxG/0Q9QeuahEfoN2KfelIwZNrb0exCgfsgK8SkjjgwBYWOF5Wku+6qNpx
# gWjg+xYlIBR84j42TSJMIfS/CTWCk1Py+g3/ywIv0B2pU8FsOYLXnvEVLgrQJPm6
# zXIuRlHhZWDZ8N1q8/kJhOJVa53cM9FXnZ+LYifKmg2s/wKXWy8BKen0GoC6MUAT
# DWxrC8sy2Kv/PD8ShC9x+tZpW9IYM+u3pOMfGHspCOAj6MCp9GTw+eHQOWjyIwu2
# hO3L8DVZYPTFEudJuKs4OuQXIOriwKfJPt2ehpbWNSiLsXGFSiFbofD7hHlCUEcz
# uaHP
# SIG # End signature block

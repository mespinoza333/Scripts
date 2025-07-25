#Requires -Version 5
<#
.SYNOPSIS
  <This script will start a CSAT Endpoint scan, when the CSAT server is found localy.>

.DESCRIPTION
  Microsoft Intune Management Extension - The IME PowerShell template script used contains logging, error codes and standard error output handling. Default directories are created and log files are removed.
  <This script will try to reach the CSAT server. Then the Endpoint scan .exe will be downloaded and started. The data will be collected and send back to the CSAT server for analysis.>
  
.PARAMETER
  None

.INPUTS
  None

.OUTPUTS
  None

.NOTES
  Script:				IME_Device_CSATRunOnce.ps1
  Version:				1.7
  Template:				IME_PSTemplateScript.ps1
  Template Version:		1.4
  Company:				QS solutions
  Author:				Tom van Beest
  Creation Date:		02-04-2019
  Source(s):			
  Release notes:		Version 1.0 - Initial published version.
						Version 1.1	- 18-04-2019 - Tom van Beest - Added all variables for CSAT.exe
                        Version 1.2 - 13-05-2019 - Wilfred Horden - Finetuned the script
                        Version 1.3 - 14-05-2019 - Wilfred Horden - Added a option to do a file hash check
                        Version 1.4 - 27-01-2020 - Wilfred Horden - Restructured variables and made a switch for logging
                        Version 1.5 - 31-07-2023 - Wilfred Horden - Updated to align with CSAT 2.04
                        Version 1.6 - 01-05-2024 - Wilfred Horden - Updated the description, Updated Create Surveyexeconfig to ensure correct creation
                        Version 1.7 - 17-08-2024 - Wilfred Horden - Added if statements if transscript is running

.LINK
  https://qssolutions.cloud/

.EXAMPLE
  .\IME_Device_CSATRunOnce.ps1

REQUIRED
  csat.zip		<Purpose>

USAGE
  Make the relevant changes to the variables in the [Declarations] section to reflect the execution evironment of the script.
  
  Information to be provided is:
	Script Version	for 	$qScriptVersion 	Should correspond with Version in the .NOTES section
	Script Name 	for 	$qScriptName		Should correspond with the actual file name (WITHOUT FILE EXTENSION) and Script (WITHOUT FILE EXTENSION) in the .NOTES section
	Customer Name	for		$qCustomerName		The full name of the customer
	Customer Abbr.	for		$qCustomerShortName	A three or four character alpanumeric (common) abbreviation of the customer
  
IMPORTANT: Please test the script using PsExec first and check for errors before deploying it through IME!

DISCLAIMER
  THIS CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" 
  WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, 
  INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF
  MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE. 

  This script is provided "AS IS" with no warranties, and confers no rights. 
  Use of the script is subject to the terms specified
  at https://qssolutions.cloud/terms-conditions/

COPYRIGHT
  © 2019 QS solutions. Modemweg 38 | 3821 BS Amersfoort | +31 (0)33 71 22 111

#>

#---------------------------------------------------------[Initializations]--------------------------------------------------------

$exitCode = 0
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Update these Variables
$qLoggingEnabled = "No" #Use "Yes" to enable logging and "No" to Disable logging
$qCSATServer = "192.168.10.98" #Type here the CSAT server name that the machines can reach
$qCSATBrowerScan = "Full" #Options are: “Off”, “Anonymous” and “Full", the default is "Off"
$qCSATScanLevel = "9" #Set the scan level for the scan the options are between 1 and 9, the default is "5"
$qCSATFilehashenabled = "No" #Use Yes to enable CSAT.exe file hash check, also then fill in the variable $qCSAToriginalFilehash. Use No for no file hash check
$qCSAToriginalFilehash = "" #See the CSAT manual how to find the CSAT file hash check

#Script Version
$qScriptVersion = "1.7"
$qScriptName = "IME_Device_CSATRunOnce"

#Customer Specific Information
$qCustomerName = "QS solutions"
$qCustomerShortName = "QSS"

#Directories
$qCustomerDir = "$Env:ProgramData\$qCustomerShortName"
$qCustomerSavedDir = "$qCustomerDir\Saved"
$qCustomerScriptsDir = "$qCustomerDir\Scripts"
$qCustomerTempDir = "$qCustomerDir\Temp"
$qCustomerWorkingDir = "$qCustomerDir\Working"

#Log File Information
$qLogPath = "$qCustomerDir\Logging"
$qLogTime = Get-Date -Format "yyyy-MM-dd-HHmmss"
$qLogName = "$qScriptName`_$qLogTime.log"
$qLogFile = Join-Path -Path $qLogPath -ChildPath $qLogName
$qLogMaxAge = 30

# Script Specific
$qCSATExe = "csat.exe"
$qCSATServerPort = "8080"
$qCSATSurveyconfigfile = "csat.exe.config"
$qCSATTempPath = "$Env:WINDIR\Temp\CSAT"
$qCSATExePath = "$Env:WINDIR\Temp\CSAT\$qCSATExe"
$qCSATconfigPath = "$Env:WINDIR\Temp\CSAT\$qCSATSurveyconfigfile"
$qCSATDownloadUrl = "https://" + $qCSATServer + ":8080/DeploymentService/rest/GetSurvey"

#Surveyconfigcontent
$qCSATSurveyconfigcontent = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  
<system.data>
    <DbProviderFactories>
      <remove invariant="System.Data.SQLite"/>
      <add name="SQLite Data Provider" invariant="System.Data.SQLite" description=".NET Framework Data Provider for SQLite" type="System.Data.SQLite.SQLiteFactory, System.Data.SQLite"/>
    </DbProviderFactories>
</system.data>
  <startup>
    <supportedRuntime version="v4.0" />
    <supportedRuntime version="v2.0.50727"/>
  </startup>
</configuration>
"@

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Invoke-Executable 
    {
    Param(
        [parameter(mandatory=$True,position=0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Executable,

        [parameter(mandatory=$False,position=1)]
        [string]
        $Arguments
    )

    If ($Arguments -eq "") 
        {
        Write-Verbose "Running Start-Process -FilePath $Executable -Wait -Passthru -Verb RunAs"
        $ReturnFromEXE = Start-Process -FilePath $Executable -NoNewWindow -Wait -Passthru
        }
	Else 
        {
        Write-Verbose "Running Start-Process -FilePath $Executable -ArgumentList $Arguments -Wait -Passthru -Verb RunAs"
        $ReturnFromEXE = Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru
        }
    Write-Verbose "Returncode is $($ReturnFromEXE.ExitCode)"
    Return $ReturnFromEXE.ExitCode
    }

#--------------------------------------------------------[PrepareDirectories]----------------------------------------------------------

If ($qLoggingEnabled -eq "Yes")
    {
    $qCustomerDirs = $qCustomerDir,$qCustomerSavedDir,$qCustomerScriptsDir,$qCustomerTempDir,$qCustomerWorkingDir

    Foreach ($qDir in $qCustomerDirs) 
        {
	    If (!(Test-Path -Path $qDir)) 
            {
		    Try 
                {
			    New-Item -Path $qDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
			    Write-Host "Info: Succesfully created the directory $qDir."
		        }
		    Catch 
                {
			    Write-Error "Error: Failed to create directory $qDir. Exit code ($LastExitCode). Exception: $($_.Exception.Message)" -Category OperationStopped
		        }
            Finally {}
	        }
	    Else 
            {
		    Write-Host "Warn: Directory $qDir already existed."
	        }
       }

    If (!(Test-Path -Path $qCSATTempPath)) 
        {
		Try 
            {
			New-Item -Path $qCSATTempPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
			Write-Host "Info: Succesfully created the directory $($qCSATTempPath)."
		    }
		Catch 
            {
			Write-Error "Error: Failed to create directory $qCSATTempPath. Exit code ($LastExitCode). Exception: $($_.Exception.Message)" -Category OperationStopped
		    }
        Finally {}
	    }
	    Else 
            {
		    Write-Host "Warn: Directory $qCSATTempPath already existed."
            }
    }

#--------------------------------------------------------[PrepareCertificate]----------------------------------------------------------

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

#--------------------------------------------------------[RemoveOldLogging]----------------------------------------------------------

If ($qLoggingEnabled -eq "Yes")
    {
    $qLogsToRemove = Get-ChildItem $qLogPath -Filter *.log | Where LastWriteTime -lt (Get-Date).AddDays(-1 * $qLogMaxAge)
  
    If ($qLogsToRemove.Count -gt 0) 
        { 
        ForEach ($qLog in $qLogsToRemove) 
            {
		    Get-Item $qLogPath\$qLog | Remove-Item
            Write-Host "Info: Succesfully deleted $qLogPath\$qLog"
            }
        }
    }
#-----------------------------------------------------------[Execution]------------------------------------------------------------

If ($qLoggingEnabled -eq "Yes")
    {
    #Start Logging
    Start-Transcript -Path $qLogFile | Out-Null
    }

#Script Execution Elements
$qCSATServerConnection = (Test-NetConnection "$qCSATServer" -Port $qCSATServerPort)
$qCSATServerTCPStatus = $qCSATServerConnection.TcpTestSucceeded

#Create Surveyexeconfig
If (!(Test-Path -Path $qCSATconfigPath)) 
    {
		Try 
            {
			New-Item -Path $qCSATconfigPath -ItemType "file" -Value $qCSATSurveyconfigcontent -Force -ErrorAction Stop | Out-Null
			Write-Host "Info: Succesfully created config file in the folder $qCSATTempPath."
	    	}
		Catch 
            {
			Write-Error "Error: Failed to create config file $($qCSATTempPath). Exit code ($LastExitCode). Exception: $($_.Exception.Message)" -Category OperationStopped
		    }
        Finally {}
    }
Else 
    {
	New-Item -Path $qCSATconfigPath -ItemType "file" -Value $qCSATSurveyconfigcontent -Force -ErrorAction Stop | Out-Null
	Write-Host "Info: Survey file $qCSATconfigPath already existed, Config file created."
    }

#Download CSAT.exe
If ($qCSATServerConnection) 
    { 
	Invoke-WebRequest -Uri $qCSATDownloadUrl -OutFile $qCSATExePath
    $qCSATDownloadHash = Get-FileHash -Path $qCSATExePath | Select-Object -ExpandProperty Hash -first 1
    }
Else 
    {
	Write-Error "Error: Failed to connect to the CSAT server or Download of CSAT.exe. The TCP status variable is $qCSATServerTCPStatus." -Category OperationStopped
	If ($qLoggingEnabled -eq "Yes") {Stop-Transcript | Out-Null}
	Exit $exitCode = -1
    }

#Test if CSAT.exe is placed correctly
$qCSATPathtest = Test-Path $qCSATExePath
If ($qCSATPathtest -eq "True")
    {
    Write-Host "Info: CSAT.exe file correctly placed in "$qCSATExePath"."
    }
Else
    {
    Write-Error "Error: Failed to connect to the CSAT server or Download of CSAT.exe. The TCP status variable is $qCSATServerTCPStatus." -Category OperationStopped
	If ($qLoggingEnabled -eq "Yes") {Stop-Transcript | Out-Null}
	Exit $exitCode = -1
    }

$qCSATItemTest = Get-Item $qCSATExePath
If ($qCSATItemTest.Length -gt "3000000")
    {
    Write-Host "Info: CSAT.exe file larger than 3000000 KB."
    }
Else
    {
    Write-Error "Error: The CSAT.exe is smaller than 3000000 KB, This CSAT.exe is to small." -Category OperationStopped
	If ($qLoggingEnabled -eq "Yes") {Stop-Transcript | Out-Null}
	Exit $exitCode = -1
    }

#File hash check if enabled
If ($qCSATFilehashenabled -eq "Yes")
    {
    If ($qCSATDownloadHash -eq $qCSAToriginalFilehash) 
        { 
	    Write-Output "Info: CSAT.exe file hash match, continue with script."
        }
    Else 
        {
	    Write-Error "Error: File hash does not match." -Category OperationStopped
	If ($qLoggingEnabled -eq "Yes") {Stop-Transcript | Out-Null}
	    Exit $exitCode = -1
        }
    }

#Create parameter value
Try 
    {
    $qExecutable = $qCSATExePath
    $qLocalFQDN = (Get-WmiObject Win32_ComputerSystem).DNSHostName+"."+(Get-WmiObject Win32_Computersystem).Domain
    If ($qCSATBrowerScan -eq "Off")
        {
        $qParameters = "`"Fqdn=$qLocalFQDN`" `"Host=$qCSATServer`" `"Port=$qCSATServerPort`" `"Scanlevel=$qCSATScanLevel`" `"exportzipfile=true`""
        }
    Else
        {
        $qParameters = "`"Fqdn=$qLocalFQDN`" `"Host=$qCSATServer`" `"Port=$qCSATServerPort`" `"Browser=$qCSATBrowerScan`" `"Scanlevel=$qCSATScanLevel`" `"exportzipfile=true`""
        }
    Write-Output "Info: Created the parameter variable"
    }
Catch 
    {
    Write-Error "Error: Not able set the parameter variable" -Category OperationStopped
	If ($qLoggingEnabled -eq "Yes") {Stop-Transcript | Out-Null}
	Exit $exitCode = -1
    }
Finally {}

#Start CSAT scan
If ($qCSATServerConnection) 
    {
    Try {
		$qCSATVersions = (Get-Item -Path $qCSATExePath).VersionInfo
		$qCSATVersion = $qCSATVersions.ProductVersion
		Write-Output "Info: Starting CSAT Executable $qCSATVersion"
		Invoke-Executable -Executable $qExecutable -Arguments $qParameters | Out-Null
		Write-Output "Info: CSAT scan completed successfully."
        }
    Catch 
        {
		Get-Process -ProcessName csat -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Error "Error: Not able to run CSAT.exe!" -Category OperationStopped
	    If ($qLoggingEnabled -eq "Yes") {Stop-Transcript | Out-Null}
	    Exit $exitCode = -1
        }
    Finally {}
    }
Else 
    {
	Write-Error "Error: CSAT scan failed" -Category OperationStopped
	Stop-Transcript | Out-Null
	Exit $exitCode = -1
    }

If ($qLoggingEnabled -eq "Yes")
    {
    #Stop Logging
    Stop-Transcript | Out-Null
    }

Exit $exitCode
# SIG # Begin signature block
# MIIm7QYJKoZIhvcNAQcCoIIm3jCCJtoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU0Kh1+HVXHsUmV4tWYwoVt27M
# jKGggh/+MIIFbzCCBFegAwIBAgIQSPyTtGBVlI02p8mKidaUFjANBgkqhkiG9w0B
# AQwFADB7MQswCQYDVQQGEwJHQjEbMBkGA1UECAwSR3JlYXRlciBNYW5jaGVzdGVy
# MRAwDgYDVQQHDAdTYWxmb3JkMRowGAYDVQQKDBFDb21vZG8gQ0EgTGltaXRlZDEh
# MB8GA1UEAwwYQUFBIENlcnRpZmljYXRlIFNlcnZpY2VzMB4XDTIxMDUyNTAwMDAw
# MFoXDTI4MTIzMTIzNTk1OVowVjELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3Rp
# Z28gTGltaXRlZDEtMCsGA1UEAxMkU2VjdGlnbyBQdWJsaWMgQ29kZSBTaWduaW5n
# IFJvb3QgUjQ2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAjeeUEiIE
# JHQu/xYjApKKtq42haxH1CORKz7cfeIxoFFvrISR41KKteKW3tCHYySJiv/vEpM7
# fbu2ir29BX8nm2tl06UMabG8STma8W1uquSggyfamg0rUOlLW7O4ZDakfko9qXGr
# YbNzszwLDO/bM1flvjQ345cbXf0fEj2CA3bm+z9m0pQxafptszSswXp43JJQ8mTH
# qi0Eq8Nq6uAvp6fcbtfo/9ohq0C/ue4NnsbZnpnvxt4fqQx2sycgoda6/YDnAdLv
# 64IplXCN/7sVz/7RDzaiLk8ykHRGa0c1E3cFM09jLrgt4b9lpwRrGNhx+swI8m2J
# mRCxrds+LOSqGLDGBwF1Z95t6WNjHjZ/aYm+qkU+blpfj6Fby50whjDoA7NAxg0P
# OM1nqFOI+rgwZfpvx+cdsYN0aT6sxGg7seZnM5q2COCABUhA7vaCZEao9XOwBpXy
# bGWfv1VbHJxXGsd4RnxwqpQbghesh+m2yQ6BHEDWFhcp/FycGCvqRfXvvdVnTyhe
# Be6QTHrnxvTQ/PrNPjJGEyA2igTqt6oHRpwNkzoJZplYXCmjuQymMDg80EY2NXyc
# uu7D1fkKdvp+BRtAypI16dV60bV/AK6pkKrFfwGcELEW/MxuGNxvYv6mUKe4e7id
# FT/+IAx1yCJaE5UZkADpGtXChvHjjuxf9OUCAwEAAaOCARIwggEOMB8GA1UdIwQY
# MBaAFKARCiM+lvEH7OKvKe+CpX/QMKS0MB0GA1UdDgQWBBQy65Ka/zWWSC8oQEJw
# IDaRXBeF5jAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zATBgNVHSUE
# DDAKBggrBgEFBQcDAzAbBgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQBMEMGA1Ud
# HwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwuY29tb2RvY2EuY29tL0FBQUNlcnRpZmlj
# YXRlU2VydmljZXMuY3JsMDQGCCsGAQUFBwEBBCgwJjAkBggrBgEFBQcwAYYYaHR0
# cDovL29jc3AuY29tb2RvY2EuY29tMA0GCSqGSIb3DQEBDAUAA4IBAQASv6Hvi3Sa
# mES4aUa1qyQKDKSKZ7g6gb9Fin1SB6iNH04hhTmja14tIIa/ELiueTtTzbT72ES+
# BtlcY2fUQBaHRIZyKtYyFfUSg8L54V0RQGf2QidyxSPiAjgaTCDi2wH3zUZPJqJ8
# ZsBRNraJAlTH/Fj7bADu/pimLpWhDFMpH2/YGaZPnvesCepdgsaLr4CnvYFIUoQx
# 2jLsFeSmTD1sOXPUC4U5IOCFGmjhp0g4qdE2JXfBjRkWxYhMZn0vY86Y6GnfrDyo
# XZ3JHFuu2PMvdM+4fvbXg50RlmKarkUT2n/cR/vfw1Kf5gZV6Z2M8jpiUbzsJA8p
# 1FiAhORFe1rYMIIGGjCCBAKgAwIBAgIQYh1tDFIBnjuQeRUgiSEcCjANBgkqhkiG
# 9w0BAQwFADBWMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
# MS0wKwYDVQQDEyRTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgUm9vdCBSNDYw
# HhcNMjEwMzIyMDAwMDAwWhcNMzYwMzIxMjM1OTU5WjBUMQswCQYDVQQGEwJHQjEY
# MBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJTZWN0aWdvIFB1Ymxp
# YyBDb2RlIFNpZ25pbmcgQ0EgUjM2MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIB
# igKCAYEAmyudU/o1P45gBkNqwM/1f/bIU1MYyM7TbH78WAeVF3llMwsRHgBGRmxD
# eEDIArCS2VCoVk4Y/8j6stIkmYV5Gej4NgNjVQ4BYoDjGMwdjioXan1hlaGFt4Wk
# 9vT0k2oWJMJjL9G//N523hAm4jF4UjrW2pvv9+hdPX8tbbAfI3v0VdJiJPFy/7Xw
# iunD7mBxNtecM6ytIdUlh08T2z7mJEXZD9OWcJkZk5wDuf2q52PN43jc4T9OkoXZ
# 0arWZVeffvMr/iiIROSCzKoDmWABDRzV/UiQ5vqsaeFaqQdzFf4ed8peNWh1OaZX
# nYvZQgWx/SXiJDRSAolRzZEZquE6cbcH747FHncs/Kzcn0Ccv2jrOW+LPmnOyB+t
# AfiWu01TPhCr9VrkxsHC5qFNxaThTG5j4/Kc+ODD2dX/fmBECELcvzUHf9shoFvr
# n35XGf2RPaNTO2uSZ6n9otv7jElspkfK9qEATHZcodp+R4q2OIypxR//YEb3fkDn
# 3UayWW9bAgMBAAGjggFkMIIBYDAfBgNVHSMEGDAWgBQy65Ka/zWWSC8oQEJwIDaR
# XBeF5jAdBgNVHQ4EFgQUDyrLIIcouOxvSK4rVKYpqhekzQwwDgYDVR0PAQH/BAQD
# AgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwGwYD
# VR0gBBQwEjAGBgRVHSAAMAgGBmeBDAEEATBLBgNVHR8ERDBCMECgPqA8hjpodHRw
# Oi8vY3JsLnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ1Jvb3RS
# NDYuY3JsMHsGCCsGAQUFBwEBBG8wbTBGBggrBgEFBQcwAoY6aHR0cDovL2NydC5z
# ZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljQ29kZVNpZ25pbmdSb290UjQ2LnA3YzAj
# BggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZIhvcNAQEM
# BQADggIBAAb/guF3YzZue6EVIJsT/wT+mHVEYcNWlXHRkT+FoetAQLHI1uBy/YXK
# ZDk8+Y1LoNqHrp22AKMGxQtgCivnDHFyAQ9GXTmlk7MjcgQbDCx6mn7yIawsppWk
# vfPkKaAQsiqaT9DnMWBHVNIabGqgQSGTrQWo43MOfsPynhbz2Hyxf5XWKZpRvr3d
# MapandPfYgoZ8iDL2OR3sYztgJrbG6VZ9DoTXFm1g0Rf97Aaen1l4c+w3DC+IkwF
# kvjFV3jS49ZSc4lShKK6BrPTJYs4NG1DGzmpToTnwoqZ8fAmi2XlZnuchC4NPSZa
# PATHvNIzt+z1PHo35D/f7j2pO1S8BCysQDHCbM5Mnomnq5aYcKCsdbh0czchOm8b
# kinLrYrKpii+Tk7pwL7TjRKLXkomm5D1Umds++pip8wH2cQpf93at3VDcOK4N7Ew
# oIJB0kak6pSzEu4I64U6gZs7tS/dGNSljf2OSSnRr7KWzq03zl8l75jy+hOds9TW
# SenLbjBQUGR96cFr6lEUfAIEHVC1L68Y1GGxx4/eRI82ut83axHMViw1+sVpbPxg
# 51Tbnio1lB93079WPFnYaOvfGAA0e0zcfF/M9gXr+korwQTh2Prqooq2bYNMvUoU
# KD85gnJ+t0smrWrb8dee2CvYZXD5laGtaAxOfy/VKNmwuWuAh9kcMIIGgDCCBOig
# AwIBAgIRAMww+b44w577X4SNuqLxS4QwDQYJKoZIhvcNAQEMBQAwVDELMAkGA1UE
# BhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGln
# byBQdWJsaWMgQ29kZSBTaWduaW5nIENBIFIzNjAeFw0yMjAxMDMwMDAwMDBaFw0y
# NTAxMDIyMzU5NTlaMGAxCzAJBgNVBAYTAk5MMRAwDgYDVQQIDAdVdHJlY2h0MRgw
# FgYDVQQKDA9RUyBzb2x1dGlvbnMgQlYxCzAJBgNVBAsMAklUMRgwFgYDVQQDDA9R
# UyBzb2x1dGlvbnMgQlYwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDj
# FRjxBbxPJ6/PwIh7QYSzhec/EDo+uY7Vw6fKg2vZUxJkqI0FJ/wxd7cJiXZYvLAC
# 6pbZS6AiCRA/lQPr8ldoHfcpF0PNjW+7XkKccdg6CH1qT4Gir4aBenLYOZbtE9bk
# X3dfPzpQelZ2fFwiN5GBMhqlOOGPFuiOC3dKFlTlcGdDCmVOOWYvfvq1ilO/EK2y
# ZDsxAxiUHxVdMVP/HK6H6OqzpknDS7/Lgt/LIVjSUHMSZsxCrooxGW4B/TxzMUJu
# LWU68mtSHIYsfMdt6jx80ygNDQwJT+Pceogf8V/qA3f01t1yskhiVgKOS75jMfK8
# F2lo4JbNC8YiwagPgkD6Qn4BrCpyd2EoaIPfDuCKP2YpG7iRGz/MULhpuEGpOg6N
# QmBbZhfKFQ8WSZsh9snbCSC1/0Auy3d+23COrxF53162/n/3mL7xoAaA06j8iJKE
# nERG+2OuUMwDEUnCJOhzzEXhqVz24qGGhW0E+nHmiEAbPbejfEOdecOnE0tPB5Uh
# I1vCZ09AGeWasaIKy6jDga6XvzrmowUKJJG4MBtYu8VSQSYJgOw1143A0J3r7LnR
# DJBBnhOID3hsqmgABZ6QODPhJqFCOPPTkedvQvHiTWBICGDvdkUT1hBDFyjcHIEE
# u1I3uof7lqDE6AGNBcg1Mgs7tAT0GqdQtNB92yuztQIDAQABo4IBvzCCAbswHwYD
# VR0jBBgwFoAUDyrLIIcouOxvSK4rVKYpqhekzQwwHQYDVR0OBBYEFHW0jsw1t/iX
# Hr+Aw9bxaykXAMNvMA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMBEGCWCGSAGG+EIBAQQEAwIEEDBKBgNVHSAEQzBBMDUG
# DCsGAQQBsjEBAgEDAjAlMCMGCCsGAQUFBwIBFhdodHRwczovL3NlY3RpZ28uY29t
# L0NQUzAIBgZngQwBBAEwSQYDVR0fBEIwQDA+oDygOoY4aHR0cDovL2NybC5zZWN0
# aWdvLmNvbS9TZWN0aWdvUHVibGljQ29kZVNpZ25pbmdDQVIzNi5jcmwweQYIKwYB
# BQUHAQEEbTBrMEQGCCsGAQUFBzAChjhodHRwOi8vY3J0LnNlY3RpZ28uY29tL1Nl
# Y3RpZ29QdWJsaWNDb2RlU2lnbmluZ0NBUjM2LmNydDAjBggrBgEFBQcwAYYXaHR0
# cDovL29jc3Auc2VjdGlnby5jb20wIQYDVR0RBBowGIEWZG9tYWluc0Bxc3NvbHV0
# aW9ucy5ubDANBgkqhkiG9w0BAQwFAAOCAYEAN9egIloABcaSxyilddT0kRKmFZQd
# SCPIZy+fnJfqAHpzYbMjZmb+HtJs+ckHkSuZZ490Ovh1cWhin4SOYWRG7QaBLL96
# TT//GWjOLmaPJQPcjRd0VHKTLmp4zKYqN7D40+dskGhsHoldOa3Z8T17/J6nObZN
# 75RWMWPD9+WnDbUAPPDvWewnBkcXOpDAfoD5JMcw7v3fI19dmVnWd1pHRcA3Z6M8
# PcKaF3uwcjOzcmdu8evGsYncLjDC24speeO/ZtTWq40EraOlz2TCpv/o+K5boNBY
# CTy2OHldi/S9LXhOLR6WwW8BxK8CslF8uSW6Viwh5rW3QhClAi1/GOcxUJ8aGa8/
# tROnsEYWj2vbOKcAHjGweyyz7CtibkdmIt1hv0hU5EvIcinkTK8ik++cXqSifcTs
# tpGqevrqojhuQrHcv0jAlH44nEoHmf054eCWWjQUmzOg03aTcvVlql8ZJZaNR7A0
# yImLCm22Z+bcSax7vyHXAoJc4VVtXQgERs72MIIG7DCCBNSgAwIBAgIQMA9vrN1m
# mHR8qUY2p3gtuTANBgkqhkiG9w0BAQwFADCBiDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVU
# aGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2Vy
# dGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTkwNTAyMDAwMDAwWhcNMzgwMTE4MjM1
# OTU5WjB9MQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVy
# MRAwDgYDVQQHEwdTYWxmb3JkMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxJTAj
# BgNVBAMTHFNlY3RpZ28gUlNBIFRpbWUgU3RhbXBpbmcgQ0EwggIiMA0GCSqGSIb3
# DQEBAQUAA4ICDwAwggIKAoICAQDIGwGv2Sx+iJl9AZg/IJC9nIAhVJO5z6A+U++z
# WsB21hoEpc5Hg7XrxMxJNMvzRWW5+adkFiYJ+9UyUnkuyWPCE5u2hj8BBZJmbyGr
# 1XEQeYf0RirNxFrJ29ddSU1yVg/cyeNTmDoqHvzOWEnTv/M5u7mkI0Ks0BXDf56i
# XNc48RaycNOjxN+zxXKsLgp3/A2UUrf8H5VzJD0BKLwPDU+zkQGObp0ndVXRFzs0
# IXuXAZSvf4DP0REKV4TJf1bgvUacgr6Unb+0ILBgfrhN9Q0/29DqhYyKVnHRLZRM
# yIw80xSinL0m/9NTIMdgaZtYClT0Bef9Maz5yIUXx7gpGaQpL0bj3duRX58/Nj4O
# MGcrRrc1r5a+2kxgzKi7nw0U1BjEMJh0giHPYla1IXMSHv2qyghYh3ekFesZVf/Q
# OVQtJu5FGjpvzdeE8NfwKMVPZIMC1Pvi3vG8Aij0bdonigbSlofe6GsO8Ft96XZp
# kyAcSpcsdxkrk5WYnJee647BeFbGRCXfBhKaBi2fA179g6JTZ8qx+o2hZMmIklnL
# qEbAyfKm/31X2xJ2+opBJNQb/HKlFKLUrUMcpEmLQTkUAx4p+hulIq6lw02C0I3a
# a7fb9xhAV3PwcaP7Sn1FNsH3jYL6uckNU4B9+rY5WDLvbxhQiddPnTO9GrWdod6V
# QXqngwIDAQABo4IBWjCCAVYwHwYDVR0jBBgwFoAUU3m/WqorSs9UgOHYm8Cd8rID
# ZsswHQYDVR0OBBYEFBqh+GEZIA/DQXdFKI7RNV8GEgRVMA4GA1UdDwEB/wQEAwIB
# hjASBgNVHRMBAf8ECDAGAQH/AgEAMBMGA1UdJQQMMAoGCCsGAQUFBwMIMBEGA1Ud
# IAQKMAgwBgYEVR0gADBQBgNVHR8ESTBHMEWgQ6BBhj9odHRwOi8vY3JsLnVzZXJ0
# cnVzdC5jb20vVVNFUlRydXN0UlNBQ2VydGlmaWNhdGlvbkF1dGhvcml0eS5jcmww
# dgYIKwYBBQUHAQEEajBoMD8GCCsGAQUFBzAChjNodHRwOi8vY3J0LnVzZXJ0cnVz
# dC5jb20vVVNFUlRydXN0UlNBQWRkVHJ1c3RDQS5jcnQwJQYIKwYBBQUHMAGGGWh0
# dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZIhvcNAQEMBQADggIBAG1UgaUz
# XRbhtVOBkXXfA3oyCy0lhBGysNsqfSoF9bw7J/RaoLlJWZApbGHLtVDb4n35nwDv
# QMOt0+LkVvlYQc/xQuUQff+wdB+PxlwJ+TNe6qAcJlhc87QRD9XVw+K81Vh4v0h2
# 4URnbY+wQxAPjeT5OGK/EwHFhaNMxcyyUzCVpNb0llYIuM1cfwGWvnJSajtCN3wW
# eDmTk5SbsdyybUFtZ83Jb5A9f0VywRsj1sJVhGbks8VmBvbz1kteraMrQoohkv6o
# b1olcGKBc2NeoLvY3NdK0z2vgwY4Eh0khy3k/ALWPncEvAQ2ted3y5wujSMYuaPC
# Rx3wXdahc1cFaJqnyTdlHb7qvNhCg0MFpYumCf/RoZSmTqo9CfUFbLfSZFrYKiLC
# S53xOV5M3kg9mzSWmglfjv33sVKRzj+J9hyhtal1H3G/W0NdZT1QgW6r8NDT/LKz
# H7aZlib0PHmLXGTMze4nmuWgwAxyh8FuTVrTHurwROYybxzrF06Uw3hlIDsPQaof
# 6aFBnf6xuKBlKjTg3qj5PObBMLvAoGMs/FwWAKjQxH/qEZ0eBsambTJdtDgJK0kH
# qv3sMNrxpy/Pt/360KOE2See+wFmd7lWEOEgbsausfm2usg1XTN2jvF8IAwqd661
# ogKGuinutFoAsYyr4/kKyVRd1LlqdJ69SK6YMIIG9TCCBN2gAwIBAgIQOUwl4Xyg
# bSeoZeI72R0i1DANBgkqhkiG9w0BAQwFADB9MQswCQYDVQQGEwJHQjEbMBkGA1UE
# CBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRgwFgYDVQQK
# Ew9TZWN0aWdvIExpbWl0ZWQxJTAjBgNVBAMTHFNlY3RpZ28gUlNBIFRpbWUgU3Rh
# bXBpbmcgQ0EwHhcNMjMwNTAzMDAwMDAwWhcNMzQwODAyMjM1OTU5WjBqMQswCQYD
# VQQGEwJHQjETMBEGA1UECBMKTWFuY2hlc3RlcjEYMBYGA1UEChMPU2VjdGlnbyBM
# aW1pdGVkMSwwKgYDVQQDDCNTZWN0aWdvIFJTQSBUaW1lIFN0YW1waW5nIFNpZ25l
# ciAjNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAKSTKFJLzyeHdqQp
# HJk4wOcO1NEc7GjLAWTkis13sHFlgryf/Iu7u5WY+yURjlqICWYRFFiyuiJb5vYy
# 8V0twHqiDuDgVmTtoeWBIHIgZEFsx8MI+vN9Xe8hmsJ+1yzDuhGYHvzTIAhCs1+/
# f4hYMqsws9iMepZKGRNcrPznq+kcFi6wsDiVSs+FUKtnAyWhuzjpD2+pWpqRKBM1
# uR/zPeEkyGuxmegN77tN5T2MVAOR0Pwtz1UzOHoJHAfRIuBjhqe+/dKDcxIUm5pM
# CUa9NLzhS1B7cuBb/Rm7HzxqGXtuuy1EKr48TMysigSTxleGoHM2K4GX+hubfoiH
# 2FJ5if5udzfXu1Cf+hglTxPyXnypsSBaKaujQod34PRMAkjdWKVTpqOg7RmWZRUp
# xe0zMCXmloOBmvZgZpBYB4DNQnWs+7SR0MXdAUBqtqgQ7vaNereeda/TpUsYoQyf
# V7BeJUeRdM11EtGcb+ReDZvsdSbu/tP1ki9ShejaRFEqoswAyodmQ6MbAO+itZad
# Yq0nC/IbSsnDlEI3iCCEqIeuw7ojcnv4VO/4ayewhfWnQ4XYKzl021p3AtGk+vXN
# nD3MH65R0Hts2B0tEUJTcXTC5TWqLVIS2SXP8NPQkUMS1zJ9mGzjd0HI/x8kVO9u
# rcY+VXvxXIc6ZPFgSwVP77kv7AkTAgMBAAGjggGCMIIBfjAfBgNVHSMEGDAWgBQa
# ofhhGSAPw0F3RSiO0TVfBhIEVTAdBgNVHQ4EFgQUAw8xyJEqk71j89FdTaQ0D9KV
# ARgwDgYDVR0PAQH/BAQDAgbAMAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYI
# KwYBBQUHAwgwSgYDVR0gBEMwQTA1BgwrBgEEAbIxAQIBAwgwJTAjBggrBgEFBQcC
# ARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9DUFMwCAYGZ4EMAQQCMEQGA1UdHwQ9MDsw
# OaA3oDWGM2h0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1JTQVRpbWVTdGFt
# cGluZ0NBLmNybDB0BggrBgEFBQcBAQRoMGYwPwYIKwYBBQUHMAKGM2h0dHA6Ly9j
# cnQuc2VjdGlnby5jb20vU2VjdGlnb1JTQVRpbWVTdGFtcGluZ0NBLmNydDAjBggr
# BgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZIhvcNAQEMBQAD
# ggIBAEybZVj64HnP7xXDMm3eM5Hrd1ji673LSjx13n6UbcMixwSV32VpYRMM9gye
# 9YkgXsGHxwMkysel8Cbf+PgxZQ3g621RV6aMhFIIRhwqwt7y2opF87739i7Efu34
# 7Wi/elZI6WHlmjl3vL66kWSIdf9dhRY0J9Ipy//tLdr/vpMM7G2iDczD8W69IZEa
# IwBSrZfUYngqhHmo1z2sIY9wwyR5OpfxDaOjW1PYqwC6WPs1gE9fKHFsGV7Cg3KQ
# ruDG2PKZ++q0kmV8B3w1RB2tWBhrYvvebMQKqWzTIUZw3C+NdUwjwkHQepY7w0vd
# zZImdHZcN6CaJJ5OX07Tjw/lE09ZRGVLQ2TPSPhnZ7lNv8wNsTow0KE9SK16ZeTs
# 3+AB8LMqSjmswaT5qX010DJAoLEZKhghssh9BXEaSyc2quCYHIN158d+S4RDzUP7
# kJd2KhKsQMFwW5kKQPqAbZRhe8huuchnZyRcUI0BIN4H9wHU+C4RzZ2D5fjKJRxE
# PSflsIZHKgsbhHZ9e2hPjbf3E7TtoC3ucw/ZELqdmSx813UfjxDElOZ+JOWVSoiM
# J9aFZh35rmR2kehI/shVCu0pwx/eOKbAFPsyPfipg2I2yMO+AIccq/pKQhyJA9z1
# XHxw2V14Tu6fXiDmCWp8KwijSPUV/ARP380hHHrl9Y4a1LlAMYIGWTCCBlUCAQEw
# aTBUMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYD
# VQQDEyJTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2AhEAzDD5vjjD
# nvtfhI26ovFLhDAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKA
# ADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYK
# KwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUT9mdxqCp8rroIO5ETrIcEIA3s40w
# DQYJKoZIhvcNAQEBBQAEggIA3CPkwHiXeb/xLyq2iz5rVaijfNxi2bEHMBJRw/Qw
# kNddOvbzu2nJOh24N5Ooxe7/I4NE0zQjVLGKuf1b9wrrug+gXChJL0kO25zHEWEo
# mQqyeC9urjkMi3FZ8wB5F493/9yMmbfJQJMe7cIxwmU8b7igBljG+TPrAAgq96yT
# lMKBk7lLDeygvw7xxp4tVWG6uOzj4uAN/uDC5ziMcFi525LReQKUnHD5Oa9oHzmY
# 5/ThH/kL3Df3wl93IWBe3uD3cHnHETlwGVFMehemL1w83Di67pU22+c3fMV66BK5
# XQkUDKt8h1LzfpXTXyPHCwyhtDgV1BLTHSLKGMC8lNOcvfwjF+tZoJZSjUOYW9st
# Qj/vfUMRR97dD0C48yWZZUZ413WdS7+NIUoANMhUwcBiHo8NE1ICT0X74N62NCDT
# C8JatpI1zFKY/1PU0SF9k5gmiSB8S8DJl+8Of0mC+RKJdn4Utvt6k5zskyayHcHl
# awhjdtIwLaKS6tMvQs87nb2sDB8Yvz2cqZOMeSB7+nJdZnHC6TRvOgD7FZapw5co
# k4lbsY9Maql7ydnO0t4UqbZmv7T8yQi87OzKMPSi+mu5ocp4s8j0NC8DWOa+MvAN
# 2+OmENCX2NaUPEQ9uUBwci+zuGob1pFe5ry0edTiM/s1F408Hjgc0qXTt1FfuimE
# qhChggNLMIIDRwYJKoZIhvcNAQkGMYIDODCCAzQCAQEwgZEwfTELMAkGA1UEBhMC
# R0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9y
# ZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSUwIwYDVQQDExxTZWN0aWdvIFJT
# QSBUaW1lIFN0YW1waW5nIENBAhA5TCXhfKBtJ6hl4jvZHSLUMA0GCWCGSAFlAwQC
# AgUAoHkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcN
# MjQwMTI1MDcyODU4WjA/BgkqhkiG9w0BCQQxMgQw1+TMi3jIWtEP34Lb5B5R7yCJ
# b8QJuK1KQyxSQTbJgizsP/dd92877aUSt8pb2qdsMA0GCSqGSIb3DQEBAQUABIIC
# ADPY06fO+NyifheCRVJOfxZMolHLb2lLRKWhotvhEhC6n6UVwSKKpW4aSRr5r5Dd
# isMNvUtv6mZAIhqYad3iuZqbme5Lo/VTMm988hdbEV1cGBQwDKq0jVs8Wi6i96kj
# KOTor81pKuQFFGFthO9HfdM4TCtG5soThBKbUTIx7M5ceo71feB4jzqmKY5wI9e3
# 2q4D6H7eaHf/E26mmClyVtJBtHsL4riRDP5EYaIE+S6M49sO35H6TTU8U5ZUNiJb
# jxSM8pjNCavj6CuW2C7t36SyQZwWfv1A1Pz6Morb36c86SWVuheM5qwaKhRHX/TV
# 694W3jF3Uu4Ple6y13HFZFabIcZGjjMwF0tyXcJNkbYxGsC8ceM3bcwMv+/0/0wO
# ITl7ggSyuwdJ3ql1WACnpButjbLce/dMRKQrJ698ITLW+EkWqw4Hc2UEj0otlY0c
# FatyTf1fI0nmO/naEb06QRtkU69w5BI1fpNw/3R7dBeG4wG59vNv1/dwxNwkaXgt
# Azm5SGcRqDX8kA+GFwaXtLLCmgOPsi6E06erBG25PLTyyQcO6b3b2q1kt0eB1vAJ
# 24n+H5XJARUXe6hDRoQF1eOw8cwQ2kU/65RYP7ADpm3IWuOl00/ay2JPu2+p7BZQ
# AqXPUoEX+JU4+8pLJ6g1CRycb6Bsvn8j8QIwfKp6qgSn
# SIG # End signature block

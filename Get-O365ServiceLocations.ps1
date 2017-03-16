# From: https://www.petri.com/tonys-office-365-snippets-september-15-2016

$invocation = (Get-Variable MyInvocation).Value
$cmdName = $invocation.MyCommand.Name
$cmdPath = Split-Path $MyInvocation.MyCommand.Path
$strt = get-date

Write-Output "Starting $cmdName at $strt"

Write-Output " This script shows each of the Office 365 services"
Write-Output " along with the data centres they are delivered"
Write-Output " from for our tenancy."

#region == Prerequisites ==========================================================
#
# Set a permanent environment variable to your user name so this script does
# not need to store it (we can then publish to github
# Use these commands (skip the second if you can restart powershell):
#   [Environment]::SetEnvironmentVariable("o365Account", "xxxx.yyyy@domain.com", "User")
#   [Environment]::SetEnvironmentVariable("o365Account", "xxxx.yyyy@domain.com", "Process")
#
# The following modules are needed for this script:
#    MS Online Services Sign-in Assistant (https://www.microsoft.com/en-us/download/details.aspx?id=28177)
#    BetterCredentials (PSGallery)
#    MSOnline (PSGallery)
#
#endregion Prerequisites ==========================================================

#region == CHANGE THESE ===========================================================
$mylogin = [Environment]::GetEnvironmentVariable("o365Account", "User")
$days = 40
#endregion CHANGE THESE ===========================================================

#region == LOGIN ==================================================================
Write-Output ("Starting login: {0} min" -f (New-TimeSpan -Start $strt).TotalMinutes )
try {
    Import-Module -Name 'BetterCredentials'
    $credential = BetterCredentials\Get-Credential $mylogin
} catch {
    Write-Warning 'BetterCredentials module not available or user name missing, check $mylogin and/or install-module -Name BetterCredentials'
    $credential = Get-Credential
}
if ($Credential -eq $null) {
    throw "Could not retrieve credential for '$mylogin'. Check that you created this asset in the Automation service."
}     

# Connect to Azure AD
try {
    Import-Module -Name MSOnline
    MSOnline\Connect-MsolService -Credential $credential
} catch {
    throw "MSOL Login Failed - has password changed? Or is MSOnline module not installed?"
}

<# Try to connect to Exchange Online
if ( (-not $Session) -or $Session.State -ne "Opened") {
    try {
        $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $credential -Authentication Basic -AllowRedirection
        Import-PSSession $Session | Out-Null
    } catch {
        throw "Exchange Online login failed"
    }
}
#>
#endregion LOGIN =================================================================

(Get-MsolCompanyInformation).AuthorizedServiceInstances

#(Get-MsolCompanyInformation).ServiceInformation
#(Get-MsolCompanyInformation).ServiceInstanceInformation

#region == TIDY UP ================================================================
#Write-Output ("Tidying up (Disconnect, delete temp files): {0} min" -f (New-TimeSpan -Start $strt).TotalMinutes )

#Remove-PSSession $Session
#Remove-Variable $Session

$strt = get-date
Write-Output "Ending $cmdName at $strt"
#endregion TIDY UP ================================================================

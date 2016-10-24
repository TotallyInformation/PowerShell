<#
 # Script to check which Office 365 users have NOT logged in in the previous n days
 # 
 # Also produces output for all users who's logins are enabled and output for all users who HAVE logged in.
 #
 # Notes:
 #   All user list excludes users blocked from logging in (but includes users with no license, including *#EXT#*)
 #   Inactive user list excludes SP mailboxes (SMO-*) but includes External users (*#EXT#*)
 #   Active user list excludes SP mailboxes (SMO-*) but includes External users (*#EXT#*)
 #
 #   The following variables are available after running:
 #   $allUsers     : All users in AAD who could potentially log on excluding SP mailboxes (UPN, isLicensed, Last PW Chg, Display Name)
 #   $userData     : As above, enriched with logon data for last n days (+ Last logon date, # logons)
 #   $inactiveUsers: Users not logged in in the last n days (data as above)
 #   $loggedOnUsers: Users that did log in in the last n days (data as above)
 #
 # Author: Julian Knight, Totally Information, 2016-10-20
 # Master Location: https://github.com/TotallyInformation/PowerShell/blob/master/Get-O365UserLoginStats.ps1
 # Inspiration from: https://github.com/OfficeDev/O365-InvestigationTooling/blob/master/InactiveUsersLast90Days.ps1
 #>

$invocation = (Get-Variable MyInvocation).Value
$cmdName = $invocation.MyCommand.Name
$cmdPath = Split-Path $MyInvocation.MyCommand.Path
$strt = get-date

# If you want a transcript:
#Start-Transcript ....

Write-Output "Starting $cmdName at $strt"

#region ============= CHANGE THESE ============= #
$mylogin = 'global.admin@tenantname.onmicrosoft.com'
$days = 90 # days to check
#endregion ===================================== #

#region INITIALISE # ----------------------------------------------------------------
#$allUsers = @()
#$inactiveUsers = @()
#$loggedOnUsers = @()
#$out = @()  
#$userData = @()
#endregion INITIALISE # -------------------------------------------------------------

#region LOGIN # ----------------------------------------------------------------
Write-Output ("Starting login: {0} min" -f [math]::Round((New-TimeSpan -Start $strt).TotalMinutes,4) )
try {
    #Install-Module -Name BetterCredentials # Allows PS credentials to be stored/accessed in Windows Credential Store
    Import-Module -Name 'BetterCredentials'
    $credential = BetterCredentials\Get-Credential $mylogin
} catch {
    Write-Warning 'BetterCredential module not available - install for easier logins: "Install-Module -Name BetterCredentials"'
    $credential = Get-Credential
}
if ($Credential -eq $null) {
    throw "Could not retrieve credential for '$mylogin'."
}     

# Connect to Azure AD
try {
    Import-Module -Name MSOnline
    MSOnline\Connect-MsolService -Credential $credential
} catch {
    throw "MSOL Login Failed - has password changed? Or is MSOnline module not installed?"
}

# Try to connect to Exchange Online
if ( (-not $Session) -or $Session.State -ne "Opened") {
    try {
        $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $credential -Authentication Basic -AllowRedirection
        Import-PSSession $Session | Out-Null
    } catch {
        throw "Exchange Online login failed"
    }
}
#endregion LOGIN # -------------------------------------------------------------

#region ALLUSERS # -------------------------------------------------------------------

Write-Output ("Getting AAD Users: {0} min" -f [math]::Round((New-TimeSpan -Start $strt).TotalMinutes,4) )

# Get all the users in AAD who have enabled logins (including those with no licenses) - but excludes SharePoint site mailboxes
$allUsers = Get-MsolUser -All -EnabledFilter EnabledOnly | `
                where { ($_.UserPrincipalName -notmatch '^SMO-') } | `
                Select UserPrincipalName, isLicensed, LastPasswordChangeTimestamp, DisplayName, CreationDate

Write-Output ("Got {1} enabled AAD Users (excluding SMO): {0} min" -f [math]::Round((New-TimeSpan -Start $strt).TotalMinutes,4), $allUsers.Count )

#endregion ALLUSERS # ----------------------------------------------------------------

# Prep the search dates
$enddate = get-date
$startdate = $enddate.AddDays( 0 - $days )

$userData = @()

# Loop through all users and add latest login from the previous $days
$i = 0 # Loop Counter
forEach ($user in $allUsers) {

    Write-Host ("{2} of {3}: Processing {1}: {0} min" -f [math]::Round((New-TimeSpan -Start $strt).TotalMinutes,4), $user.UserPrincipalName, $i, $allUsers.Count )

    $sessionName = $cmdName + ( get-date -Format 'u' ) + $user.UserPrincipalName

    # Reset user audit accumulator
    $out = @()

    $j = 0 # Loop counter
    Do { # --- Loop through log search for day session (up to 50k records) --- #


        # Do the actual search (NB: Excluding UserLoginFailed) - we are using ReturnLargeSet to get back up to 50k records, 5k at a time
        # Search for logins, appear to be 2 operation types: PasswordLogonInitialAuthUsingPassword and UserLoggedIn 
        $o = Search-UnifiedAuditLog -StartDate $startdate -EndDate $enddate `
                                    -UserIds $user.UserPrincipalName `
                                    -SessionId $sessionName -SessionCommand ReturnLargeSet `
                                    -Operations UserLoggedIn, PasswordLogonInitialAuthUsingPassword `
                                    -ResultSize 5000
        
        # If the count is 0, no records to process
        if ($o.Count -gt 0) {
            Write-Host ("  Finished {3} search #{1}, {2} records: {0} min" -f [math]::Round((New-TimeSpan -Start $strt).TotalMinutes,4), $j, $o.Count, $user.UserPrincipalName )

            # Accumulate the data
            $out += $o | select CreationDate

            # No need to do another query if the # recs returned <5k - should save around 5-10 sec per user
            if ($o.Count -lt 5000) {
                $o = @()
            } else {
                $j++
            }
        }

    } Until ($o.Count -eq 0) # --- End of Session Search Loop --- #

    # Make sure we got everything
    if ($out.Count -ge 50000) {
        throw ("Too many records for user {0}, some have been lost, {1} processed" -f $user.UserPrincipalName, $out.Count)
    }

    # Gets one record per user along with the latest login date - excludes SharePoint site mailboxes
    if ( $out.Count -gt 0 ) {
        $logon = ($out | `
                    sort CreationDate | `
                    select -last 1 -Property CreationDate).CreationDate
    } else {
        $logon = $null
    }

    # Check for invalid password expiry (e.g. account in use more than 90d after password changed)
    if ( $logon -gt ($user.LastPasswordChangeTimestamp).AddDays(91) ) { 
        $PwExpiryError = $true
        $PwExpiryAge = $logon - $user.LastPasswordChangeTimestamp
        Write-Host ("  WARNING: User logged in >90d after previous password reset. Last Login: {0}, Last Reset: {1}, Difference: {2}" -f $logon, $user.LastPasswordChangeTimestamp, ($logon - $user.LastPasswordChangeTimestamp) )
    } else { 
        $PwExpiryError = $false
        $PwExpiryAge = $null
    }

    $userData += [pscustomobject]@{
        UserPrincipalName = $user.UserPrincipalName
        LastLogonTimestamp = $logon
        LastPasswordChangeTimestamp = $user.LastPasswordChangeTimestamp
        CreationDate = $user.CreationDate
        LogonCount = $out.Count
        isLicensed = $user.isLicensed
        DisplayName = $user.DisplayName
        PwExpiryError = $PwExpiryError
        PwExpiryAge = [Math]::Round($PwExpiryAge.totaldays,2)
    }

    $i++

} # ---- End of User Loop ---- #

# Check output
if ($allUsers.Count -ne $userData.Count) {
    Write-Output ' '
    Write-Output ("WARNING: Input All User count ({0}) <> output count ({1})" -f $allUsers.Count, $userData.Count )
    Write-Output ' '
}

$loggedOnUsers = $userData | where { $_.LogonCount -gt 0 }
$inactiveUsers = $userData | where { $_.LogonCount -eq 0 }

#region SUMMARY # ----------------------------------------------------------------

Write-Output ' '
Write-Output ("{1} users have NOT logged in for the last {0} days:" -f $days, $inactiveUsers.Count )
Write-Output ("{1} users HAVE logged over the last {0} days:" -f $days, $loggedOnUsers.Count )
Write-Output ("{0} users are currently able to log in to AAD:" -f $allUsers.Count )
Write-Output ' '
Write-Output 'All user list excludes users blocked from logging in (but includes users with no license, including *#EXT#*) '
Write-Output 'Inactive user list excludes SP mailboxes (SMO-*) but includes External users (*#EXT#*) '
Write-Output 'Active user list excludes SP mailboxes (SMO-*) but includes External users (*#EXT#*) '
Write-Output ' '
Write-Output 'The following variables are now available:'
Write-Output '    $allUsers     : All users in AAD who could potentially log on excluding SP mailboxes (UPN, isLicensed, Last PW Chg, Display Name)'
Write-Output '    $userData     : As above, enriched with logon data for last n days (+ Last logon date, # logons)'
Write-Output '    $inactiveUsers: Users not logged in in the last n days (data as above)'
Write-Output '    $loggedOnUsers: Users that did log in in the last n days (data as above)'
Write-Output ' '

#Write-Output $inactiveInLastThreeMonthsUsers

#endregion SUMMARY # ----------------------------------------------------------------

#region OUTPUT # ---------------------------------------------------------------
# Uncomment if wanting files saved

# Get current date for adding to file names
$DateStr = Get-Date -format "yyyyMMdd"

#$outFileDated  = "$mypath\_output\$cmdName-AllUsers-$DateStr.csv"
#$outFileLatest = "$mypath\_output\$cmdName-AllUsers-Latest.csv"
#$allUsers | Export-Csv -Path $outFileDated -NoTypeInformation
#Copy-Item -Path $outFileDated -Destination $outFileLatest -Force

#$outFileDated  = "$mypath\_output\$cmdName-InactiveUsers-$DateStr.csv"
#$outFileLatest = "$mypath\_output\$cmdName-InactiveUsers-Latest.csv"
#$inactiveUsers | Export-Csv -Path $outFileDated -NoTypeInformation
#Copy-Item -Path $outFileDated -Destination $outFileLatest -Force

#$outFileDated  = "$mypath\_output\$cmdName-LoggedOnUsers-$DateStr.csv"
#$outFileLatest = "$mypath\_output\$cmdName-LoggedOnUsers-Latest.csv"
#$loggedOnUsers | Export-Csv -Path $outFileDated -NoTypeInformation
#Copy-Item -Path $outFileDated -Destination $outFileLatest -Force

#$outFileDated  = "$mypath\_output\$cmdName-AllLogonAuditRecords-$DateStr.csv"
#$outFileLatest = "$mypath\_output\$cmdName-AllLogonAuditRecords-Latest.csv"
#$out | Export-Csv -Path $outFileDated -NoTypeInformation
#Copy-Item -Path $outFileDated -Destination $outFileLatest -Force

#endregion OUTPUT # ------------------------------------------------------------


#region "TIDY UP" # ------------------------------------------------------------
Write-Output "Tidying up (Disconnect, delete temp files)"

Remove-PSSession $Session
Remove-Variable $Session

$end = get-date
$duration = New-TimeSpan -Start $strt -End $end
Write-Output ("{0} {1} => {2}. Duration: {3}:{4}:{5}" -f $cmdName, $strt, $end, $duration.Hours, $duration.Minutes, $duration.Seconds)
#endregion "TIDY UP" # ---------------------------------------------------------

<#
# AAD Reporting API
# https://azure.microsoft.com/en-gb/documentation/articles/active-directory-reporting-api-getting-started/
#
# Search the Unified Audit Log
# https://technet.microsoft.com/library/mt238501(v=exchg.160).aspx
# The data is returned in pages as the command is rerun sequentially while using the same SessionId value.
# Data can be 12 hours out of date
# AuditData details is returned in JSON format
# *** WARNING: ONLY 5000 entries can ever be returned from a single session ***
# Search-UnifiedAuditLog -StartDate 5/1/2015 -EndDate 5/8/2015 -RecordType SharePointFileOperation -Operations FileAccessed -SessionId "WordDocs_SharepointViews"-SessionCommand ReturnNextPreviewPage
#>

# ctrl-j for snippets menu

Function Save-IseSession{
    [CmdletBinding()]
    Param(
        [Parameter(Position=0)]
        [String]$Path = "$env:tempIse.txt"
    )
 
    Begin{ }
    Process{
        $psISE.CurrentPowerShellTab.Files | % {$_.SaveAs($_.FullPath)}
        "ise ""$($psISE.PowerShellTabs.Files.FullPath -join',')""" | Out-File -Encoding utf8 -FilePath $Path
    }
    End{ }
}
Function Restore-IseSession{
    [CmdletBinding()]
    Param(
        [Parameter(Position=0)]
        [String]$Path = "$env:tempIse.txt"
    )
 
    Begin{ }
    Process{
        Invoke-Expression (Get-Content $Path)
    }
    End{ }
}

# List all modules that were manually installed (or came with the OS) that have updates
# http://mikefrobbins.com/2016/06/09/update-manually-installed-powershell-modules-from-the-powershell-gallery/
function List-ManualModulesWithUpdates{
    Write-Output "This will be slow ..."
    Write-Output "Update with: 'Install-Module -Name xxxxx -Force'"
    $i = 0
    $avail = Get-Module -ListAvailable

    $avail |
    #Where-Object ModuleBase -like $env:ProgramFiles\WindowsPowerShell\Modules\* |
    Sort-Object -Property Name, Version -Descending |
    Get-Unique -PipelineVariable Module |
    ForEach-Object {
        $i++
        Write-Progress -Activity "Checking Modules" -Status $_.Name -PercentComplete (100*$i/$avail.count)
        if (-not(Test-Path -Path "$($_.ModuleBase)\PSGetModuleInfo.xml")) {
            Find-Module -Name $_.Name -OutVariable Repo -ErrorAction SilentlyContinue |
            Compare-Object -ReferenceObject $_ -Property Name, Version |
            Where-Object SideIndicator -eq '=>' |
            Select-Object -Property Name,
                                    Version,
                                    @{label='Repository';expression={$Repo.Repository}},
                                    @{label='InstalledVersion';expression={$Module.Version}}
        }
    }
}

<#
 # TODO
 #   Edit file from selected text
 # Snippets
 #   Remove-Variable
#>
<#
    Azure runbook gallery https://www.powershellgallery.com/packages/
    Office 365 samples
    PowerShell for Office 365

    Exchange & CSOnline (SfB) have a small shell and download the full commandlets from online

    CIM replaces WMI and is platform agnostic. There is a CIM server for Linux



    O365 Reports?
    - last used - send annual email to site owners
#>


try {
    Set-ExecutionPolicy Bypass | Out-Null
} catch {}

# To extend the ISE menu with your own entries, @See:
#   https://www.petri.com/using-addonsmenu-property-powershell-ise-object-model
$psise.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("Save ISE Session",{Save-IseSession},"Ctrl+Alt+S") | Out-Null
$psise.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("Restore ISE Session",{Restore-IseSession},"Ctrl+Alt+R") | Out-Null
$MyFilesMenu = $psise.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("Scripts",$null,$null)
$MyFilesMenu.Submenus.Add("Open Weekly Reporting", {PowerShell_ISE –file ( (Get-Item env:USERPROFILE).Value + '\OneDrive\node1\o365\ps\WeeklyReportingAndUpdates.ps1' ) }, $null) | Out-Null
$MyFilesMenu.Submenus.Add("Open Profile Script", {PowerShell_ISE –file $profile}, $null) | Out-Null
$MyFilesMenu.Submenus.Add("Explore Scripts", {explorer 'C:\OD\Src\PowerShell'}, $null) | Out-Null
$MyFilesMenu.Submenus.Add("Explore Current Scripts Folder", {explorer (Get-ChildItem $psise.CurrentFile.FullPath).DirectoryName}, $null) | Out-Null

$MyFilesMenu1 = $psise.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("PS Modules",$null,$null)
$MyFilesMenu1.Submenus.Add("Update PS Modules", {Update-Module}, $null) | Out-Null
$MyFilesMenu1.Submenus.Add("List Manually/OS Installed Modules with updates", {List-ManualModulesWithUpdates}, $null) | Out-Null
$MyFilesMenu1.Submenus.Add("Show PS Module Paths", {($env:psmodulepath).split(';')}, $null) | Out-Null
$MyFilesMenu1.Submenus.Add("Show Installed PS Modules", {get-module -ListAvailable}, $null) | Out-Null
$MyFilesMenu1.Submenus.Add("Show Loaded PS Modules", {get-module}, $null) | Out-Null
$MyFilesMenu1.Submenus.Add("Show MSOnline Module Version", {(Get-Item C:\Windows\System32\WindowsPowerShell\v1.0\Modules\MSOnline\Microsoft.Online.Administration.Automation.PSModule.dll).VersionInfo.FileVersion}, $null) | Out-Null

$MyFilesMenu2 = $psise.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("OS",$null,$null)
$MyFilesMenu2.Submenus.Add("Show Windows Paths", {($env:path).split(';')}, $null) | Out-Null
# ---------------------------- #

# Start AzureAutomationISEAddOn snippet
Import-Module AzureAutomationAuthoringToolkit
# End AzureAutomationISEAddOn snippet

Import-Module -Name PsISEProjectExplorer

# Where do I want my own scripts?
$Global:myScripts = "C:\OD\Src\PowerShell"
Set-Location $Global:myScripts
cd $Global:myScripts

# +=========================+ #
# | SETUP for new PC...     | #
# +=========================+ #

# Trust the PSGallery Repository (to get rid of prompts on install)
#Set-PSRepository -InstallationPolicy Trusted -Name PSGallery

# ==== MODULES INSTALLED ==== #
#Install-Module -Name AzureAutomationAuthoringToolkit
#Install-AzureAutomationIseAddOn
#Install-Module -Name AzureADPreview -RequiredVersion 1.1.143.0
#Install-Module -Name MSOnline
#Install-Module -Name OfficeDevPnP.PowerShell.V16.Commands -Force
#Install-Module -Name BetterCredentials # Allows PS credentials to be stored/accessed in Windows Credential Store
    # Get-Command -Module BetterCredentials
    # BetterCredentials\Get-Credential -UserName xxx -Store
#Install-Module -Name CsvSqlimport # Easier, streaming CSV->SQL https://gallery.technet.microsoft.com/scriptcenter/Import-Large-CSVs-into-SQL-fa339046
#Install-Module -Name PowerShellISEModule
#Install-Module -Name PsISEProjectExplorer

# Skype for Business
#Import-Module LyncOnlineConnector # install sfb ps module
#$cssess = Import-PSSession (New-CsOnlineSession)
#Get-Command -Module $cssess.Name
## use disconnect-pssession $cssess to end the session

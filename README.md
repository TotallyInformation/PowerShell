# PowerShell
A collection of snippets, functions and modules useful to me

- [Microsoft.PowerShellISE_profile.ps1](https://github.com/TotallyInformation/PowerShell/blob/master/Microsoft.PowerShellISE_profile.ps1)
  A profile script for PowerShell ISE. Contains functions for updating PS modules, saving/loading project sessions, has a menu for opening common scripts and script locations, sets a useful starting folder and loads some userful modules.
  
- [Get-O365UserLoginStats.ps1](https://github.com/TotallyInformation/PowerShell/blob/master/Get-O365UserLoginStats.ps1)
  A script that analyses Azure AD and the Office 365 combined audit log checking for active users who have and haven't logged in over the past n days. Until recently (2016H2), this data was not possible to get except for Exchange Online users. Warning: This script takes HOURS to run for a reasonable sized tenant of a few thousand active users.

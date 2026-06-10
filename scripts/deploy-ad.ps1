<#
.SYNOPSIS
    Automated Active Directory Domain Services & Group Policy Lab Deployment Script.
.DESCRIPTION
    This script automates the installation of AD DS, promotes the server to a root DC,
    provisions the OU hierarchy, seeds initial security groups and user accounts, 
    and injects a Group Policy Object for workstation security.
.NOTES
    Run this script inside PowerShell as an Administrator.
#>

# ==========================================
# PHASE 1: FEATURE & ROLE INSTALLATION
# ==========================================
Write-Host "[*] Phase 1: Installing AD DS and Management Tools..." -ForegroundColor Cyan

# Install the Active Directory Domain Services role along with RSAT management tools
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Install the Group Policy Management Console feature explicitly
Install-WindowsFeature -Name GPMC

# ==========================================
# PHASE 2: FOREST & DOMAIN PROMOTION
# ==========================================
Write-Host "[*] Phase 2: Deploying Active Directory Forest..." -ForegroundColor Cyan

# Import the deployment module required for forest operations
Import-Module ADDSDeployment

# Define a secure string password for the Directory Services Restore Mode (DSRM)
$DSRMPassword = ConvertTo-SecureString 'YourStrongDSRMPassword!' -AsPlainText -Force

# Deploy the root forest container. 
# NOTE: This command will automatically force a system restart upon completion.
Install-ADDSForest `
    -DomainName 'lab.local' `
    -DomainNetBiosName 'LAB' `
    -InstallDns:$true `
    -SafeModeAdministratorPassword $DSRMPassword `
    -Force:$true

<# 
  STOP: The server will reboot here. 
  After logging back in as LAB\Administrator, execute the remainder of the script below.
#>

# ==========================================
# PHASE 3: DIRECTORY ARCHITECTURE & ACCOUNTS
# ==========================================
Write-Host "[*] Phase 3: Building Organizational Units and Security Groups..." -ForegroundColor Cyan

# 1. Provision Organizational Unit (OU) structures at the root domain path
New-ADOrganizationalUnit -Name "IT" -Path "DC=lab,DC=local"
New-ADOrganizationalUnit -Name "Finance" -Path "DC=lab,DC=local"
New-ADOrganizationalUnit -Name "HR" -Path "DC=lab,DC=local"
New-ADOrganizationalUnit -Name "Sales" -Path "DC=lab,DC=local"
New-ADOrganizationalUnit -Name "Computers" -Path "DC=lab,DC=local"

# 2. Provision Global Security Groups inside their respective departmental OUs
New-ADGroup -Name "IT_Admins" -GroupScope Global -GroupCategory Security -Path "OU=IT,DC=lab,DC=local"
New-ADGroup -Name "Finance_Users" -GroupScope Global -GroupCategory Security -Path "OU=Finance,DC=lab,DC=local"
New-ADGroup -Name "HR_Users" -GroupScope Global -GroupCategory Security -Path "OU=HR,DC=lab,DC=local"
New-ADGroup -Name "Sales_Users" -GroupScope Global -GroupCategory Security -Path "OU=Sales,DC=lab,DC=local"

# 3. Batch User Provisioning & Password Seeding
Write-Host "[*] Provisioning directory user accounts..." -ForegroundColor Cyan
$DefaultPassword = ConvertTo-SecureString "Welcome@2026!" -AsPlainText -Force

# Alice Chen - IT
New-ADUser -Name "alice.chen" -GivenName "Alice" -Surname "Chen" `
    -SamAccountName "alice.chen" -UserPrincipalName "alice.chen@lab.local" `
    -Path "OU=IT,DC=lab,DC=local" -AccountPassword $DefaultPassword -Enabled $true

# Bob Patel - Finance
New-ADUser -Name "bob.patel" -GivenName "Bob" -Surname "Patel" `
    -SamAccountName "bob.patel" -UserPrincipalName "bob.patel@lab.local" `
    -Path "OU=Finance,DC=lab,DC=local" -AccountPassword $DefaultPassword -Enabled $true

# Carol Jones - HR
New-ADUser -Name "carol.jones" -GivenName "Carol" -Surname "Jones" `
    -SamAccountName "carol.jones" -UserPrincipalName "carol.jones@lab.local" `
    -Path "OU=HR,DC=lab,DC=local" -AccountPassword $DefaultPassword -Enabled $true

# David Smith - Sales
New-ADUser -Name "david.smith" -GivenName "David" -Surname "Smith" `
    -SamAccountName "david.smith" -UserPrincipalName "david.smith@lab.local" `
    -Path "OU=Sales,DC=lab,DC=local" -AccountPassword $DefaultPassword -Enabled $true

# 4. Map user accounts to their designated corporate role-based security groups
Add-ADGroupMember -Identity "IT_Admins" -Members "alice.chen"
Add-ADGroupMember -Identity "Finance_Users" -Members "bob.patel"
Add-ADGroupMember -Identity "HR_Users" -Members "carol.jones"
Add-ADGroupMember -Identity "Sales_Users" -Members "david.smith"

# ==========================================
# PHASE 4: GROUP POLICY AUTOMATION (STEP 5)
# ==========================================
Write-Host "[*] Phase 4: Deploying Baseline Security Group Policies..." -ForegroundColor Cyan

# Import the core Group Policy management engine module
Import-Module GroupPolicy

# Create a new Group Policy Object (GPO) container
$GPO = New-GPO -Name "IT Security Policy" -Comment "Automated Corporate IT OU Baseline Security Configuration"

# Link the new GPO container straight to the IT department's organizational unit target path
New-GPLink -Guid $GPO.Id -Target "OU=IT,DC=lab,DC=local"

# Inject administrative registry keys into the GPO to force a 15-minute (900 seconds) locked screensaver timeout
Set-GPRegistryValue -Guid $GPO.Id `
    -Key "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" `
    -ValueName "ScreenSaveActive" -Type String -Value "1"

Set-GPRegistryValue -Guid $GPO.Id `
    -Key "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" `
    -ValueName "ScreenSaverIsSecure" -Type String -Value "1"

Set-GPRegistryValue -Guid $GPO.Id `
    -Key "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" `
    -ValueName "ScreenSaveTimeOut" -Type String -Value "900"

# ==========================================
# PHASE 5: POST-DEPLOYMENT ENVIRONMENT AUDIT
# ==========================================
Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "         SYSTEM AUTOMATION AUDIT REPORT           " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green

Write-Host "`n[+] Domain Controller Status:" -ForegroundColor Cyan
Get-ADDomainController | Select-Object ComputerName, OperatingSystem, Forest

Write-Host "`n[+] Created Organizational Units:" -ForegroundColor Cyan
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName

Write-Host "`n[+] Active User Identities:" -ForegroundColor Cyan
Get-ADUser -Filter {Enabled -eq $true} | Select-Object Name, SamAccountName

Write-Host "`n[+] Security Group Memberships (IT_Admins):" -ForegroundColor Cyan
Get-ADGroupMember -Identity "IT_Admins" | Select-Object Name, SamAccountName

Write-Host "`n[+] Enforced GPO Links on IT OU:" -ForegroundColor Cyan
Get-GPInheritance -Target 'OU=IT,DC=lab,DC=local' | Select-Object -ExpandProperty GpoLinks
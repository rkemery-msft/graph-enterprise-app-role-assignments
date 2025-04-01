[CmdletBinding(DefaultParameterSetName = 'ByAppName')]
param (
    [Parameter(Mandatory = $true, ParameterSetName = 'ByAppName')]
    [string]$AppName,
    
    [Parameter(Mandatory = $true, ParameterSetName = 'ExportAll')]
    [switch]$ExportAllApps
)

# Import required module
Import-Module Microsoft.Graph.Authentication

# Connect to Graph
Connect-MgGraph -Scopes "Application.Read.All","Directory.Read.All","User.Read" -NoWelcome

if ($ExportAllApps) {
    Write-Host "Retrieving all enterprise applications..." -ForegroundColor Cyan
    
    try {
        # Get all applications - use SDK method instead of direct REST for better reliability
        $allApps = Get-MgServicePrincipal -All
        
        # Filter to application type service principals
        $enterpriseApps = $allApps | Where-Object { 
            $_.ServicePrincipalType -eq "Application" -and
            -not [string]::IsNullOrEmpty($_.DisplayName)
        }
        
        Write-Host "Found $($enterpriseApps.Count) enterprise applications." -ForegroundColor Green
        
        # Prepare CSV data
        $appData = @()
        foreach ($app in $enterpriseApps) {
            $appData += [PSCustomObject]@{
                DisplayName = $app.DisplayName
                AppId = $app.AppId
                ObjectId = $app.Id
                ServicePrincipalType = $app.ServicePrincipalType
                Tags = if ($app.Tags) { $app.Tags -join "; " } else { "" }
                AccountEnabled = $app.AccountEnabled
                HomePage = $app.Homepage
                LoginUrl = $app.LoginUrl
                ReplyUrls = if ($app.ReplyUrls) { $app.ReplyUrls -join "; " } else { "" }
            }
        }
        
        # Export to CSV
        $timestamp = Get-Date -Format "yyyyMMddHHmmss"
        $exportPath = "AllEnterpriseApplications_$timestamp.csv"
        $appData | Export-Csv -Path $exportPath -NoTypeInformation
        
        Write-Host "Exported $($appData.Count) enterprise applications to $exportPath" -ForegroundColor Green
        Write-Host "To export role assignments for a specific application, run:" -ForegroundColor Yellow
        Write-Host ".\Export-AppRoles.ps1 -AppName ""Application Name""" -ForegroundColor Yellow
        
        exit 0
    }
    catch {
        Write-Error "Error retrieving enterprise applications: $_"
        exit 1
    }
}
else {
    try {
        # Get all applications
        Write-Host "Getting all enterprise applications..." -ForegroundColor Cyan
        $allApps = Get-MgServicePrincipal -All
        
        # Find applications matching the name
        Write-Host "Searching for applications matching '$AppName'..." -ForegroundColor Cyan
        $matchingApps = $allApps | Where-Object { $_.DisplayName -like "*$AppName*" }
        
        if ($matchingApps.Count -eq 0) {
            Write-Host "No applications found matching '$AppName'. Please check the name and try again." -ForegroundColor Red
            exit 1
        }
        
        Write-Host "Found $($matchingApps.Count) matching applications:" -ForegroundColor Green
        for ($i = 0; $i -lt $matchingApps.Count; $i++) {
            $app = $matchingApps[$i]
            Write-Host "[$i] $($app.DisplayName) (AppId: $($app.AppId), Id: $($app.Id))" -ForegroundColor White
        }
        
        # Select application
        $selectedIdx = 0
        if ($matchingApps.Count -gt 1) {
            $input = Read-Host "Enter the number of the application to export (default: 0)"
            if ($input -match '^\d+$' -and [int]$input -ge 0 -and [int]$input -lt $matchingApps.Count) {
                $selectedIdx = [int]$input
            }
            else {
                Write-Host "Invalid selection. Using default (0)." -ForegroundColor Yellow
            }
        }
        
        $selectedApp = $matchingApps[$selectedIdx]
        
        # Make sure we have a valid service principal
        if (-not $selectedApp -or -not $selectedApp.Id) {
            Write-Error "Selected application is invalid or missing an ID."
            exit 1
        }
        
        Write-Host "Selected: $($selectedApp.DisplayName) (Id: $($selectedApp.Id))" -ForegroundColor Green
        
        # Get role assignments
        Write-Host "Getting role assignments..." -ForegroundColor Cyan
        $roleAssignments = Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $selectedApp.Id -All
        
        Write-Host "Found $($roleAssignments.Count) role assignments." -ForegroundColor Green
        
        # Process assignments
        $results = @()
        foreach ($assignment in $roleAssignments) {
            $principalType = "Unknown"
            $principalName = "Unknown"
            $principalEmail = ""
            
            try {
                # Try to get user details
                $user = Get-MgUser -UserId $assignment.PrincipalId -ErrorAction SilentlyContinue
                if ($user) {
                    $principalType = "User"
                    $principalName = $user.DisplayName
                    $principalEmail = $user.Mail
                }
                else {
                    # Try to get group details
                    $group = Get-MgGroup -GroupId $assignment.PrincipalId -ErrorAction SilentlyContinue
                    if ($group) {
                        $principalType = "Group"
                        $principalName = $group.DisplayName
                        $principalEmail = $group.Mail
                    }
                }
            }
            catch {
                # Continue with unknown
                Write-Host "Could not identify principal $($assignment.PrincipalId)" -ForegroundColor Yellow
            }
            
            # Add to results
            $results += [PSCustomObject]@{
                ApplicationName = $selectedApp.DisplayName
                ApplicationId = $selectedApp.AppId
                PrincipalId = $assignment.PrincipalId
                PrincipalName = $principalName
                PrincipalType = $principalType
                PrincipalEmail = $principalEmail
                AppRoleId = $assignment.AppRoleId
                CreatedDateTime = $assignment.CreatedDateTime
            }
        }
        
        # Export results
        if ($results.Count -gt 0) {
            $timestamp = Get-Date -Format "yyyyMMddHHmmss"
            $safeAppName = $selectedApp.DisplayName -replace '[\\/:*?"<>|]', '_'
            $exportPath = "$safeAppName-Assignments_$timestamp.csv"
            
            $results | Export-Csv -Path $exportPath -NoTypeInformation
            Write-Host "Exported $($results.Count) role assignments to $exportPath" -ForegroundColor Green
        }
        else {
            Write-Host "No role assignments found for $($selectedApp.DisplayName)" -ForegroundColor Yellow
            
            # Create empty file with header as indication
            $timestamp = Get-Date -Format "yyyyMMddHHmmss"
            $safeAppName = $selectedApp.DisplayName -replace '[\\/:*?"<>|]', '_'
            $exportPath = "$safeAppName-NoAssignments_$timestamp.csv"
            
            [PSCustomObject]@{
                ApplicationName = $selectedApp.DisplayName
                ApplicationId = $selectedApp.AppId
                Note = "No role assignments found"
            } | Export-Csv -Path $exportPath -NoTypeInformation
            
            Write-Host "Created empty file at $exportPath" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Error "Error processing application: $_"
        exit 1
    }
}
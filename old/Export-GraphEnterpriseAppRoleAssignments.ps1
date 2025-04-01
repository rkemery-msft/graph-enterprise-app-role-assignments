<#
.SYNOPSIS
    Retrieves user and group role assignments for a selected enterprise application,
    or, if the -AllApps switch is specified, exports all app registrations.

.DESCRIPTION
    This script demonstrates how to work with the Microsoft Graph PowerShell SDK in an
    enterprise environment using PowerShell Core 7.5. It:
      • Imports only the required Graph submodules.
      • Connects to Microsoft Graph (with an interactive flow by default).
      • Dynamically retrieves all app registrations with support for interactive paging.
      • Allows you to either export all app registrations (via -AllApps) or select one application.
      • Retrieves the corresponding service principal.
      • Downloads all app role assignments and determines whether each assignment is for a user or a group.
      • Exports the results to a CSV file with a unique filename.

    GRAPH PREREQUISITES:
      - Microsoft Graph PowerShell SDK installed (Install-Module Microsoft.Graph).
      - Appropriate permissions (e.g., Application.Read.All, Directory.Read.All, User.Read).
      - In an enterprise scenario, permissions may require admin consent via the Azure portal.

    AUTHENTICATION MECHANISMS:
      Interactive (User) Flow:
        - Uses Connect-MgGraph to open a browser-based sign-in prompt.
        - Best for ad hoc operations where a user is present.
      
      Non-interactive (Client Credentials) Flow:
        - Best for automation and scheduled tasks.
        - Authenticate using an application’s ClientId and ClientSecret or certificate.
        - Example for Non-interactive Flow (uncomment and configure if needed):
          # $ClientId = "your-application-client-id"
          # $TenantId = "your-tenant-id"
          # $ClientSecret = "your-client-secret"
          # Connect-MgGraph -ClientId $ClientId -TenantId $TenantId -ClientSecret $ClientSecret -Scopes "Application.Read.All","Directory.Read.All","User.Read"

.NOTES
    This script has error handling, verbose logging toggles,
    and interactive paging for scenarios with many app registrations.
#>

[CmdletBinding()]
param (
    [switch]$AllApps
)

# Uncomment to Enable verbose logging for detailed runtime information.
# $VerbosePreference = 'Continue'

# -------------------------------
# Function: Interactive Paging Selection
# -------------------------------
function Select-AppRegistration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array]$Apps,

        [int]$PageSize = 10
    )
    $total = $Apps.Count
    $currentPage = 0

    while ($true) {
        $start = $currentPage * $PageSize
        $end = [Math]::Min($start + $PageSize, $total) - 1
        Write-Host "Displaying results $start to $end of ${total}:" -ForegroundColor Cyan

        for ($i = $start; $i -le $end; $i++) {
            Write-Host "[$i] $($Apps[$i].DisplayName) (AppId: $($Apps[$i].AppId))"
        }

        Write-Host ""
        Write-Host "Enter a number to select an app, 'n' for next page, 'p' for previous page, or 'q' to quit:" -ForegroundColor Yellow
        $input = Read-Host

        switch ($input) {
            'q' { return $null }
            'n' {
                if ($end -eq $total - 1) {
                    Write-Host "Already on the last page." -ForegroundColor Red
                } else {
                    $currentPage++
                }
            }
            'p' {
                if ($currentPage -eq 0) {
                    Write-Host "Already on the first page." -ForegroundColor Red
                } else {
                    $currentPage--
                }
            }
            default {
                if ($input -match '^\d+$') {
                    $selectedIndex = [int]$input
                    if ($selectedIndex -ge 0 -and $selectedIndex -lt $total) {
                        return $Apps[$selectedIndex]
                    } else {
                        Write-Host "Invalid selection: index out of range." -ForegroundColor Red
                    }
                }
                else {
                    Write-Host "Invalid input." -ForegroundColor Red
                }
            }
        }
    }
}

# -------------------------------
# 1. Import Required Graph Modules
# -------------------------------
try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.Applications -ErrorAction Stop
    Import-Module Microsoft.Graph.Users -ErrorAction Stop
    Import-Module Microsoft.Graph.Groups -ErrorAction Stop
    Write-Verbose "Successfully imported required Microsoft Graph modules."
} catch {
    Write-Error "Failed to import required modules: $_"
    exit 1
}

# -------------------------------
# 2. Connect to Microsoft Graph
# -------------------------------
# For interactive (user) authentication, use:
try {
    Connect-MgGraph -Scopes "Application.Read.All","Directory.Read.All","User.Read" -ErrorAction Stop
    Write-Verbose "Connected to Microsoft Graph successfully using interactive authentication."
} catch {
    Write-Error "Failed to connect to Microsoft Graph: $_"
    exit 1
}

# -------------------------------
# 3. Dynamically Retrieve App Registrations (with Paging Support)
# -------------------------------
try {
    Write-Verbose "Retrieving app registrations (this may take a while in large enterprises)..."
    $apps = Get-MgApplication -All -ErrorAction Stop
    if (-not $apps) {
        Write-Error "No app registrations found."
        exit 1
    }
    Write-Verbose "Retrieved $($apps.Count) app registrations."
} catch {
    Write-Error "Error retrieving app registrations: $_"
    exit 1
}

# -------------------------------
# 4. Handle -AllApps Switch
# -------------------------------
if ($AllApps) {
    # Generate a unique filename using a timestamp to avoid file lock conflicts.
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $exportPathApps = "AppRegistrations-Graph_$timestamp.csv"
    try {
        $apps | Export-Csv -Path $exportPathApps -NoTypeInformation -Force
        Write-Host "Exported all app registrations to '$exportPathApps'." -ForegroundColor Green
    } catch {
        Write-Error "Failed to export app registrations: $_"
    }
    exit 0
}

# -------------------------------
# 5. Let User Select an Application with Paging
# -------------------------------
$selectedApp = Select-AppRegistration -Apps $apps -PageSize 10
if (-not $selectedApp) {
    Write-Error "No application selected. Exiting."
    exit 1
}
Write-Host "Selected application: $($selectedApp.DisplayName)" -ForegroundColor Green

# -------------------------------
# 6. Retrieve the Service Principal for the Selected Application
# -------------------------------
try {
    Write-Verbose "Retrieving service principal for AppId: $($selectedApp.AppId)..."
    $sp = Get-MgServicePrincipal -Filter "appId eq '$($selectedApp.AppId)'" -ErrorAction Stop | Select-Object -First 1
    if (-not $sp) {
        Write-Error "Service principal for application '$($selectedApp.DisplayName)' not found."
        exit 1
    }
    Write-Verbose "Service principal found: $($sp.DisplayName)"
} catch {
    Write-Error "Error retrieving service principal: $_"
    exit 1
}

# -------------------------------
# 7. Retrieve All App Role Assignments
# -------------------------------
try {
    Write-Verbose "Retrieving app role assignments for service principal ID: $($sp.Id)..."
    $appRoleAssignments = Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $sp.Id -ErrorAction Stop
    Write-Verbose "Found $($appRoleAssignments.Count) role assignments."
} catch {
    Write-Error "Error retrieving app role assignments: $_"
    exit 1
}

# -------------------------------
# 8. Process Each Role Assignment
# -------------------------------
$results = foreach ($assignment in $appRoleAssignments) {
    $principalId = $assignment.PrincipalId
    try {
        # Attempt to retrieve the user details
        $user = Get-MgUser -UserId $principalId -ErrorAction Stop
        [PSCustomObject]@{
            PrincipalId         = $principalId
            PrincipalName       = $user.DisplayName
            PrincipalType       = "User"
            AppRoleId           = $assignment.AppRoleId
            ResourceDisplayName = $sp.DisplayName
        }
    } catch {
        try {
            # If not a user, attempt to retrieve group details
            $group = Get-MgGroup -GroupId $principalId -ErrorAction Stop
            [PSCustomObject]@{
                PrincipalId         = $principalId
                PrincipalName       = $group.DisplayName
                PrincipalType       = "Group"
                AppRoleId           = $assignment.AppRoleId
                ResourceDisplayName = $sp.DisplayName
            }
        } catch {
            # Mark as unknown if neither user nor group is found.
            [PSCustomObject]@{
                PrincipalId         = $principalId
                PrincipalName       = "Unknown"
                PrincipalType       = "Unknown"
                AppRoleId           = $assignment.AppRoleId
                ResourceDisplayName = $sp.DisplayName
            }
        }
    }
}

# -------------------------------
# 9. Export the Role Assignment Results to CSV
# -------------------------------
# Generate a unique filename using a timestamp for role assignments export.
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$exportPath = "EnterpriseAppRoleAssignments-Graph_$timestamp.csv"
try {
    $results | Export-Csv -Path $exportPath -NoTypeInformation -Force
    Write-Host "Export completed successfully to '$exportPath'." -ForegroundColor Green
} catch {
    Write-Error "Failed to export results: $_"
}
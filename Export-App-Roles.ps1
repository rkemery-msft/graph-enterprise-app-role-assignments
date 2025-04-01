[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$AppName
)

# Import only what we need
try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Write-Host "Successfully imported Microsoft Graph Authentication module." -ForegroundColor Green
} catch {
    Write-Error "Failed to import Microsoft Graph Authentication module. Please make sure it's installed: $_"
    Write-Host "You can install it with: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser" -ForegroundColor Yellow
    exit 1
}

# Connect to Graph
try {
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes "Application.Read.All","Directory.Read.All","User.Read" -ErrorAction Stop
    Write-Host "Successfully connected to Microsoft Graph." -ForegroundColor Green
} catch {
    Write-Error "Failed to connect to Microsoft Graph: $_"
    Write-Host "Please make sure you have the necessary permissions and can connect to Microsoft Graph." -ForegroundColor Yellow
    exit 1
}

# Get all service principals in one call
try {
    Write-Host "Getting all service principals..." -ForegroundColor Cyan
    $allSPs = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$top=999" -Method GET -ErrorAction Stop
    $servicePrincipals = $allSPs.value
    
    # Handle pagination if there are more results
    $nextLink = $allSPs.'@odata.nextLink'
    while ($nextLink) {
        Write-Host "Getting additional service principals..." -ForegroundColor Gray
        $moreResults = Invoke-MgGraphRequest -Uri $nextLink -Method GET -ErrorAction Stop
        $servicePrincipals += $moreResults.value
        $nextLink = $moreResults.'@odata.nextLink'
    }
    
    Write-Host "Retrieved $($servicePrincipals.Count) service principals." -ForegroundColor Green
    
    if ($servicePrincipals.Count -eq 0) {
        Write-Warning "No service principals were found in the tenant. This is unusual and may indicate a permissions issue."
        exit 1
    }
} catch {
    Write-Error "Failed to retrieve service principals: $_"
    Write-Host "Please check your network connection and permissions." -ForegroundColor Yellow
    exit 1
}

# Find matches
Write-Host "Searching for '$AppName'..." -ForegroundColor Cyan
$matches = @()
foreach ($sp in $servicePrincipals) {
    if ($sp.displayName -like "*$AppName*") {
        $matches += $sp
    }
}

# Show matches
if ($matches.Count -eq 0) {
    Write-Error "No applications found matching '$AppName'. Please check the name and try again."
    exit 1
} else {
    Write-Host "Found $($matches.Count) matches:" -ForegroundColor Green
    for ($i = 0; $i -lt $matches.Count; $i++) {
        Write-Host "[$i] $($matches[$i].displayName) (Id: $($matches[$i].id))" -ForegroundColor White
    }
}

# Select app
$selectedIdx = 0
if ($matches.Count -gt 1) {
    $selectedIdx = Read-Host "Enter number (default: 0)"
    if (-not [int]::TryParse($selectedIdx, [ref]$selectedIdx)) { 
        Write-Host "Invalid input. Using default (0)." -ForegroundColor Yellow
        $selectedIdx = 0 
    }
    
    if ([int]$selectedIdx -lt 0 -or [int]$selectedIdx -ge $matches.Count) {
        Write-Host "Index out of range. Using default (0)." -ForegroundColor Yellow
        $selectedIdx = 0
    }
}

# Get the service principal ID
$spId = $matches[$selectedIdx].id
$spName = $matches[$selectedIdx].displayName

if (-not $spId) {
    Write-Error "Selected application doesn't have a valid ID. This is unexpected and may indicate an issue with the application."
    exit 1
}

Write-Host "Selected: $spName (Id: $spId)" -ForegroundColor Green

# Get role assignments
try {
    Write-Host "Getting role assignments..." -ForegroundColor Cyan
    $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$spId/appRoleAssignedTo" -Method GET -ErrorAction Stop
    $assignments = $response.value
    
    # Handle pagination if there are more results
    $nextLink = $response.'@odata.nextLink'
    while ($nextLink) {
        Write-Host "Getting additional role assignments..." -ForegroundColor Gray
        $moreResults = Invoke-MgGraphRequest -Uri $nextLink -Method GET -ErrorAction Stop
        $assignments += $moreResults.value
        $nextLink = $moreResults.'@odata.nextLink'
    }
    
    Write-Host "Found $($assignments.Count) assignments." -ForegroundColor Green
} catch {
    Write-Error "Failed to retrieve role assignments: $_"
    Write-Host "This may be due to permissions issues or the application not having any role assignments." -ForegroundColor Yellow
    $assignments = @()
}

# Process assignments
$results = @()
$successCount = 0
$errorCount = 0

foreach ($assignment in $assignments) {
    # Get principal details
    $principalType = "Unknown"
    $principalName = "Unknown"
    $principalEmail = ""
    
    try {
        $userResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($assignment.principalId)" -Method GET -ErrorAction SilentlyContinue
        if ($userResponse) {
            $principalType = "User"
            $principalName = $userResponse.displayName
            $principalEmail = $userResponse.mail
        } else {
            $groupResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$($assignment.principalId)" -Method GET -ErrorAction SilentlyContinue
            if ($groupResponse) {
                $principalType = "Group"
                $principalName = $groupResponse.displayName
                $principalEmail = $groupResponse.mail
            }
        }
        $successCount++
    } catch {
        Write-Verbose "Could not resolve details for principal ID $($assignment.principalId): $_"
        $errorCount++
        # Continue with unknown values
    }
    
    # Try to get role name instead of just ID
    $roleName = "Default Access"
    try {
        if ($assignment.appRoleId -ne "00000000-0000-0000-0000-000000000000") {
            $appDetails = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$spId" -Method GET -ErrorAction SilentlyContinue
            if ($appDetails -and $appDetails.appRoles) {
                $role = $appDetails.appRoles | Where-Object { $_.id -eq $assignment.appRoleId }
                if ($role) {
                    $roleName = $role.displayName
                }
            }
        }
    } catch {
        # Continue with default role name
    }
    
    # Add to results
    $results += [PSCustomObject]@{
        Application = $spName
        PrincipalId = $assignment.principalId
        PrincipalName = $principalName
        PrincipalType = $principalType
        PrincipalEmail = $principalEmail
        AppRoleId = $assignment.appRoleId
        RoleName = $roleName
        CreatedDateTime = $assignment.createdDateTime
    }
}

# Export
try {
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $safeAppName = $spName -replace '[\\/:*?"<>|]', '_'
    $exportPath = "$safeAppName-Assignments_$timestamp.csv"
    $results | Export-Csv -Path $exportPath -NoTypeInformation -ErrorAction Stop
    Write-Host "Exported $($results.Count) assignments to $exportPath" -ForegroundColor Green
    
    if ($errorCount -gt 0) {
        Write-Warning "Encountered issues resolving $errorCount out of $($assignments.Count) principals. Some entries may have incomplete information."
    }
    
    # Open in Excel if available
    $openInExcel = Read-Host "Would you like to open the CSV file now? (Y/N)"
    if ($openInExcel -eq "Y" -or $openInExcel -eq "y") {
        try {
            Start-Process $exportPath
        } catch {
            Write-Warning "Could not open the file automatically. Please open it manually from: $exportPath"
        }
    }
} catch {
    Write-Error "Failed to export results to CSV: $_"
    Write-Host "Results could not be saved. Here are the first few entries:" -ForegroundColor Yellow
    $results | Select-Object -First 5 | Format-Table -AutoSize
}
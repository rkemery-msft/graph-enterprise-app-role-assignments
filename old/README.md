# Export-GraphEnterpriseAppRoleAssignments

PowerShell scripts leveraging Microsoft Graph to retrieve and export user and group role assignments for Azure AD enterprise applications.

## Overview

**Export-GraphEnterpriseAppRoleAssignments.ps1** is a PowerShell Core 7.5+ script that demonstrates how to use the Microsoft Graph PowerShell SDK to:
- Dynamically retrieve all app registrations (with interactive paging support).
- Allow a user to select an application from a list.
- Retrieve the corresponding service principal.
- Download and process all app role assignments—identifying whether each assignment belongs to a user or a group.
- Export the results to a uniquely named CSV file.

This repository provides a sample for environments and is ideal for demos, testing, and adapting to your organization's needs.

## Prerequisites

Before using this script, ensure you have the following:
- **PowerShell Core 7.5+** installed.
- The **Microsoft Graph PowerShell SDK** installed. You can install it by running:
  ```powershell
  Install-Module -Name Microsoft.Graph -Scope CurrentUser
  ```
- Appropriate Microsoft Graph API permissions, such as:
  - `Application.Read.All`
  - `Directory.Read.All`
  - `User.Read`
- Admin consent for the above scopes may be required in your tenant.

## Authentication

### Interactive Flow (Default)

By default, the script uses an interactive (browser-based) authentication flow. When you run the script, you'll be prompted to sign in with your credentials. This approach is best suited for ad hoc operations or manual testing.

### Non-Interactive Flow (For Automation)

For automated environments or scheduled tasks, it is best practice to use a non-interactive authentication mechanism (Client Credentials flow). In your Azure AD app registration, configure your application with the appropriate client secret or certificate and update the script accordingly. For example:

```powershell
# Example for non-interactive authentication (uncomment and configure if needed):
# $ClientId = "your-application-client-id"
# $TenantId = "your-tenant-id"
# $ClientSecret = "your-client-secret"  # Or use certificate-based authentication
# Connect-MgGraph -ClientId $ClientId -TenantId $TenantId -ClientSecret $ClientSecret -Scopes "Application.Read.All","Directory.Read.All","User.Read"
```

## Installation & Setup

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/yourusername/graph-enterprise-app-role-assignments.git
   cd graph-enterprise-app-role-assignments
   ```

2. **Review the Script:**
   Open `Export-GraphEnterpriseAppRoleAssignments.ps1` in your favorite code editor (e.g., VS Code) and review the inline comments for detailed instructions on configuring and running the script.

3. **Install Required Modules:**
   Ensure the required Microsoft Graph modules are installed as noted in the prerequisites.

## Usage

You can run the script in an interactive PowerShell Core session:

```powershell
pwsh -NoProfile -File .\Export-GraphEnterpriseAppRoleAssignments.ps1
```

### Command Line Options

- **Interactive App Selection:**
  The script will retrieve all app registrations and allow you to page through the list interactively to select a specific application.

- **Export All App Registrations:**
  If you wish to export all app registrations instead of selecting one, run the script with the `-AllApps` switch:
  ```powershell
  pwsh -NoProfile -File .\Export-GraphEnterpriseAppRoleAssignments.ps1 -AllApps
  ```

Each CSV export is generated with a unique filename (using a timestamp) to prevent conflicts with files that may be in use.

## Cautionary Note

> **WARNING:** This script is provided as a demo and for educational purposes only. It is designed to be adapted and tested within your environment.  
> **Do not use this script in production without thoroughly reviewing, testing, and adapting it to meet your organization’s security and operational requirements.**

## License

This project is licensed under the [MIT License](LICENSE).


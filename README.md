# Enterprise App Role Assignments Export Tool

A PowerShell script to export user and group role assignments from Azure Enterprise Applications.

## Overview

This tool allows you to:
- Search for Enterprise Applications by name
- Export all user and group assignments for a specific application to CSV

The script uses the Microsoft Graph API to retrieve information about Enterprise Applications and their role assignments, providing a convenient way to audit and document who has access to specific applications in your Azure tenant.

## ⚠️ Important Warning

**This script is provided as-is for demonstration and example purposes only.**

- No official support is provided for this script.
- Always test thoroughly in a non-production environment before using in production.
- The script makes multiple API calls that could potentially impact API throttling limits in your tenant.
- Results may vary depending on your tenant configuration and permissions.
- Microsoft Graph API endpoints and behaviors may change over time, potentially affecting script functionality.

## Prerequisites

- PowerShell 7.0 or later
- Microsoft Graph PowerShell SDK module
- Appropriate permissions in your Azure tenant:
  - Application.Read.All
  - Directory.Read.All
  - User.Read

## Installation

1. Install the required Microsoft Graph module:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
```

2. Save the script as `Export-AppRoles.ps1`

## Usage

### Export role assignments for a specific application

```powershell
.\Export-AppRoles.ps1 -AppName "ApplicationName"
```

The script will:
1. Search for Enterprise Applications matching the provided name
2. If multiple matches are found, prompt you to select one
3. Retrieve all user and group assignments for the selected application
4. Export the results to a CSV file

### Example Output

The CSV output includes:
- Application name
- Principal ID (user or group)
- Principal name
- Principal type (User or Group)
- Principal email
- App role ID
- Role name
- Creation date

## Permissions

The script requires the following Microsoft Graph permissions:
- Application.Read.All - To read Enterprise Application information
- Directory.Read.All - To read user and group information
- User.Read - For basic authentication

## Troubleshooting

If you encounter issues:
1. Ensure you have the proper permissions in your Azure tenant
2. Verify network connectivity to Microsoft Graph endpoints
3. Check for any error messages in the console output
4. Try connecting to Microsoft Graph manually to validate credentials

## Alternative Methods

### Azure Portal (GUI)

You can also view and manage Enterprise Application assignments through the Azure Portal:

1. Sign in to the [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** > **Enterprise applications**
3. Select the specific application you want to examine
4. Go to **Users and groups** in the left navigation pane
5. Review the list of assigned users and groups
6. To export this data:
   - You can use the browser's "Save as" feature on the page
   - Take screenshots for documentation
   - Or manually copy the data to Excel

### Azure CLI

You can retrieve Enterprise Application assignments using Azure CLI:

```bash
# Install the Azure CLI if needed
# https://docs.microsoft.com/en-us/cli/azure/install-azure-cli

# Sign in to Azure
az login

# List all Enterprise Applications in Azure AD
az ad sp list --all --query "[?servicePrincipalType=='Application'].{DisplayName:displayName, AppId:appId, ObjectId:id}" --output table

# Find a specific Enterprise Application by name
az ad sp list --all --query "[?servicePrincipalType=='Application' && contains(displayName,'APPLICATION_NAME')].{DisplayName:displayName, AppId:appId, ObjectId:id}" --output table

# Get role assignments for a specific Enterprise Application (replace with the actual ObjectId)
az rest --method GET --uri "https://graph.microsoft.com/v1.0/servicePrincipals/OBJECT_ID/appRoleAssignedTo" --headers "Content-Type=application/json"
```

Example output from the role assignments command:
```json
{
  "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#appRoleAssignments",
  "value": [
    {
      "appRoleId": "00000000-0000-0000-0000-000000000000",
      "createdDateTime": "2023-01-26T03:00:55.9501724Z",
      "id": "00000000-0000-0000-0000-000000000000",
      "principalDisplayName": "System Administrator",
      "principalId": "00000000-0000-0000-0000-000000000000",
      "principalType": "User",
      "resourceDisplayName": "example-name",
      "resourceId": "00000000-0000-0000-0000-000000000000"
    }
  ]
}
```

Notes:
- These commands are specifically for Enterprise Applications in Azure AD
- The queries filter for Service Principals of type 'Application', which represents Enterprise Applications
- Azure CLI commands may change over time as the CLI is updated
- The `az rest` command provides direct access to Microsoft Graph API and returns the most detailed information
- Use the ObjectId (not AppId) from the first command as the identifier in the appRoleAssignedTo request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This script is not an official Microsoft product. It's provided as-is without warranty of any kind, express or implied. Use at your own risk.
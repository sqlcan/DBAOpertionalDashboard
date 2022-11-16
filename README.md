# DBAOpertionalDashboard
SQL Server DBA Opertional Dashboard collects information from all versions of Windows and SQL Server.

# Requirements
- SQL Server 2016+
- Reporting Services 2016+ or PowerBI Report Server
- PowerShell 5+
- .NET 4.5 +
- Service Account with Local Administrative and SYSADMIN Permissions
- Central Management Server (CMS)

# Deployment Requirements
- Solution requires access to following databases:
  -- SQLOpsDB - Stores all the data collected with PowerShell Solution for both SQLOpsDB and EPM framework.
  -- MSDB - Stores CMS Servers and Groups.
- Must deploy SQLOpsDB / EPM Framework to CMS Server.
- Must deploy all the policies to the same CMS Server.

# Out of Support
- SQL Server 6.5, 7.0, and 2000
- Windows Server 2000, 2003, and 2003 R2

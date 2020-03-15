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
  -- SQLOpsDB - Stores all the data collected with PowerShell Solution.
  -- PolicyBasedManagement - Stores all the Policy Evaluation Data -- Alternatively this can be stored in SQLOpsDB.
  -- MSDB - Stores CMS Servers and Groups.
- Ideally all three databases should be accessible from same SQL Server instance.  If not some of the code will have be modified for getting and managing CMS Server List and Groups.

# Out of Support
- SQL Server 2000
- Windows Server 2000

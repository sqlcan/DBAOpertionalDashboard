# SQL Opertional Dashboard
SQL Server Opertional Dashboard collects information from Windows and SQL Server.  Although the script should work with Windows 2003+ and SQL Server 2005+.  The latest version has been developed and tested against SQL Server 2019 on Windows 2019.

## Deplopyment Requirements
- SQL Server 2016+
- Reporting Services 2016+
- PowerShell 5+
- .NET 4.5 +
- Group Managed Service Account (gMSA) with Local Administrative and SYSADMIN Permissions to Target Servers
- Central Management Server (CMS)
- Visual Studio 2019 with SQL Server Data Tools
- Policies, Database, and Reports must be deployed to the CMS SQL Server.

## Deployment Process
1. Copy all the solution to <DestinationDrive:>\SQLOpDB folder
2. Configure CMS with standard configuration.  Structure the folders so it makes it easy for you to enable and disable monitoring on selective folders.
3. Register all SQL instances to monitor
4. Deploy SQL Server Policies on the CMS Server.
5. Deploy SQL Scripts to Create the Database, Tables, Views, and Stored Procedures.
6. Same set of scripts will also have some data population tables.
7. Update ".\PowerShell\EPM\EPM_EnterpriseEvaluation_5.ps1", update the connection string to the CMS Server.
8. Update the JSON file, ".\PowerShell\SQLOpsDB\Config\SQLOpsDB.json",  with connection string for SQLOpDB server.
9. Enable monitor for CMS groups by using Set-SQLOpCMSGroup command-let.
10. Deploy Windows Scheduler task against ".\PowerShell\EPM\EPMExecution.ps1" supply required parameters.  Run with -ExecutionPolicy BYPASS.  Run -IsDailyCheck every day at 2 AM (or after your backups finish).
11. Deploy same job again without "-IsDailyCheck" to run every Sunday at 4 AM.
12. Deploy another Windows Scheduler task against ".\PowerShell\CollectionScript\SQLOpsDB_DataCollection.ps1" to run at 6 AM.
13. Using Visual Studio with SSDT installed, open and deploy reports.  Before deploying update the connection settings and deployment parameters.

** I do have Deployment Ssript under ".\PowerShell\" folder that can deploy some the components.  However it is not complete to deploy the full solution.
** You might have to update the schedules above depending on the number of instances to monitor for policy evaluation.

## Out of Support
- SQL Server 6.5, 7.0, and 2000
- Windows Server 2000, 2003, and 2003 R2

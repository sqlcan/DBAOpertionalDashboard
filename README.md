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
1. Download the SQLOpDB_Solution_V3.00.00.0000_RTM.zip file.
2. Extract file to C:\Temp\
3. Open PowerShell with Run As Admin to C:\Temp\
4. Execute DeploySQLOpsSolution.ps1 with required parameters.
5. Follow steps in deployment script.

## Out of Support
- SQL Server 6.5, 7.0, and 2000
- Windows Server 2000, 2003, and 2003 R2

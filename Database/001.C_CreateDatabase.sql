--     Purpose: Create new database SQLOpsDB with single data file and log file.
--              Both files grow by 256MB.  Depending on the volume of data this
--              database should not grow too large due to self trimming functionality.
--
--              I do not recommend changing the database name.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Oct. 3, 2020

DECLARE @DataFileName NVARCHAR(MAX)
DECLARE @LogFileName NVARCHAR(MAX)
DECLARE @SQLStmt NVARCHAR(MAX)

SET @DataFileName = CONVERT(sysname,SERVERPROPERTY('InstanceDefaultDataPath')) + 'SQLOpsDB.mdf'
SET @LogFileName = CONVERT(sysname,SERVERPROPERTY('InstanceDefaultLogPath')) + 'SQLOpsDB_log.ldf'

SET @SQLStmt = '
CREATE DATABASE [SQLOpsDB]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N''SQLOpsDB'', FILENAME = ''' + @DataFileName + ''' , SIZE = 262144KB , FILEGROWTH = 262144KB )
 LOG ON 
( NAME = N''SQLOpsDB_log'', FILENAME = ''' + @LogFileName + ''' , SIZE = 262144KB , FILEGROWTH = 262144KB )'

EXEC (@SQLStmt)
GO

ALTER DATABASE [SQLOpsDB] SET COMPATIBILITY_LEVEL = 140
GO
ALTER DATABASE [SQLOpsDB] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [SQLOpsDB] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [SQLOpsDB] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [SQLOpsDB] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [SQLOpsDB] SET ARITHABORT OFF 
GO
ALTER DATABASE [SQLOpsDB] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [SQLOpsDB] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [SQLOpsDB] SET AUTO_CREATE_STATISTICS ON(INCREMENTAL = OFF)
GO
ALTER DATABASE [SQLOpsDB] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [SQLOpsDB] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [SQLOpsDB] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [SQLOpsDB] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [SQLOpsDB] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [SQLOpsDB] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [SQLOpsDB] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [SQLOpsDB] SET  DISABLE_BROKER 
GO
ALTER DATABASE [SQLOpsDB] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [SQLOpsDB] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [SQLOpsDB] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [SQLOpsDB] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [SQLOpsDB] SET  READ_WRITE 
GO
ALTER DATABASE [SQLOpsDB] SET RECOVERY SIMPLE 
GO
ALTER DATABASE [SQLOpsDB] SET  MULTI_USER 
GO
ALTER DATABASE [SQLOpsDB] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [SQLOpsDB] SET TARGET_RECOVERY_TIME = 60 SECONDS 
GO
ALTER DATABASE [SQLOpsDB] SET DELAYED_DURABILITY = DISABLED 
GO
USE [SQLOpsDB]
GO
ALTER DATABASE SCOPED CONFIGURATION SET LEGACY_CARDINALITY_ESTIMATION = Off;
GO
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET LEGACY_CARDINALITY_ESTIMATION = Primary;
GO
ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = 0;
GO
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET MAXDOP = PRIMARY;
GO
ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SNIFFING = On;
GO
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET PARAMETER_SNIFFING = Primary;
GO
ALTER DATABASE SCOPED CONFIGURATION SET QUERY_OPTIMIZER_HOTFIXES = Off;
GO
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET QUERY_OPTIMIZER_HOTFIXES = Primary;
GO
USE [SQLOpsDB]
GO
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') ALTER DATABASE [SQLOpsDB] MODIFY FILEGROUP [PRIMARY] DEFAULT
GO
--     Purpose: Nodes belonging to a SQL FCI.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No changes since released.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Oct. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SQLClusterNodes')
BEGIN

	CREATE TABLE [dbo].[SQLClusterNodes](
		[SQLClusterNodeID] [int] IDENTITY(1,1) NOT NULL,
		[SQLClusterID] [int] NOT NULL,
		[SQLNodeID] [int] NOT NULL,
		[IsActiveNode] [bit] NOT NULL,
		[DiscoveryOn] [date] NOT NULL,
		[LastUpdated] [date] NOT NULL,
	 CONSTRAINT [PK_SQLClusterNodes] PRIMARY KEY CLUSTERED 
	(
		[SQLClusterNodeID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
	) ON [PRIMARY]

	ALTER TABLE [dbo].[SQLClusterNodes] ADD  CONSTRAINT [DF_SQLClusterNodes_IsActiveNode]  DEFAULT ((0)) FOR [IsActiveNode]

	ALTER TABLE [dbo].[SQLClusterNodes] ADD  CONSTRAINT [DF_SQLClusterNodes_DiscoveryOn]  DEFAULT (getdate()) FOR [DiscoveryOn]

	ALTER TABLE [dbo].[SQLClusterNodes] ADD  CONSTRAINT [DF_SQLClusterNodes_LastUpdated]  DEFAULT (getdate()) FOR [LastUpdated]

END
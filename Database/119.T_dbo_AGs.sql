--     Purpose: Stores list of discovered AG by their name and guid.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No change since release.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[AGs](
	[AGID] [int] IDENTITY(1,1) NOT NULL,
	[AGName] [varchar](255) NOT NULL,
	[AGGuid] [uniqueidentifier] NOT NULL,
	[DiscoveryOn] [date] NOT NULL,
	[LastUpdated] [date] NOT NULL,
 CONSTRAINT [PK_AG] PRIMARY KEY CLUSTERED 
(
	[AGID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

ALTER TABLE [dbo].[AGs] ADD  CONSTRAINT [DF_AGs_AGGuid]  DEFAULT ('00000000-0000-0000-0000-000000000000') FOR [AGGuid]

ALTER TABLE [dbo].[AGs] ADD  CONSTRAINT [DF_AGs_DiscoveryOn]  DEFAULT (getdate()) FOR [DiscoveryOn]

ALTER TABLE [dbo].[AGs] ADD  CONSTRAINT [DF_AGs_LastUpdated]  DEFAULT (getdate()) FOR [LastUpdated]
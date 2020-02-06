USE [SQLOpsDB]
GO

/****** Object:  Table [dbo].[SQLClusters]    Script Date: 2020-02-06 1:14:13 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[SQLClusters](
	[SQLClusterID] [int] IDENTITY(1,1) NOT NULL,
	[SQLClusterName] [varchar](255) NOT NULL,
	[IsMonitored] [bit] NOT NULL,
	[DiscoveryOn] [date] NOT NULL,
	[LastUpdated] [date] NOT NULL,
 CONSTRAINT [PK_SQLClusters] PRIMARY KEY CLUSTERED 
(
	[SQLClusterID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[SQLClusters] ADD  CONSTRAINT [DF_SQLClusters_IsMonitored]  DEFAULT ((1)) FOR [IsMonitored]
GO

ALTER TABLE [dbo].[SQLClusters] ADD  CONSTRAINT [DF_SQLClusters_DiscoveryOn]  DEFAULT (getdate()) FOR [DiscoveryOn]
GO

ALTER TABLE [dbo].[SQLClusters] ADD  CONSTRAINT [DF_SQLClusters_LastUpdated]  DEFAULT (getdate()) FOR [LastUpdated]
GO



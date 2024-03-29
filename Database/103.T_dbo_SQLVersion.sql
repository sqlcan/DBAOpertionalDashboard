USE [SQLOpsDB]
GO

/****** Object:  Table [dbo].[SQLVersions]    Script Date: 11/25/2022 4:55:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[SQLVersions](
	[SQLVersionID] [int] IDENTITY(1,1) NOT NULL,
	[SQLVersion] [varchar](50) NOT NULL,
	[SQLVersionShortName] [varchar](50) NOT NULL,
	[SQLMajorVersion] [int] NOT NULL,
	[SQLMinorVersion] [int] NOT NULL,
	[SQLBuild] [int] NOT NULL,
	[SQLVersionSupportEndDate] [date] NULL,
 CONSTRAINT [PK_SQLVersions] PRIMARY KEY CLUSTERED 
(
	[SQLVersionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[SQLVersions] ADD  CONSTRAINT [DF_SQLVersions_SQLVersionShortName]  DEFAULT ('Unknown') FOR [SQLVersionShortName]
GO

ALTER TABLE [dbo].[SQLVersions] ADD  CONSTRAINT [DF_SQLVersions_SQLMajorVersion]  DEFAULT ((0)) FOR [SQLMajorVersion]
GO

ALTER TABLE [dbo].[SQLVersions] ADD  CONSTRAINT [DF_SQLVersions_SQLMinorVersion]  DEFAULT ((0)) FOR [SQLMinorVersion]
GO

ALTER TABLE [dbo].[SQLVersions] ADD  CONSTRAINT [DF_SQLVersions_SQLBuild]  DEFAULT ((0)) FOR [SQLBuild]
GO

ALTER TABLE [dbo].[SQLVersions] ADD  CONSTRAINT [DF_SQLVersions_SQLVersionSupportEndDate]  DEFAULT ('1999/01/01') FOR [SQLVersionSupportEndDate]
GO



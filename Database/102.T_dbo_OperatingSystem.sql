USE [SQLOpsDB]
GO

/****** Object:  Table [dbo].[OperatingSystems]    Script Date: 11/25/2022 4:56:07 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[OperatingSystems](
	[OperatingSystemID] [int] IDENTITY(1,1) NOT NULL,
	[OperatingSystemName] [varchar](255) NOT NULL,
	[OperatingSystemShortName] [varchar](128) NOT NULL,
 CONSTRAINT [PK_OperatingSystems] PRIMARY KEY CLUSTERED 
(
	[OperatingSystemID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[OperatingSystems] ADD  CONSTRAINT [DF_OperatingSystems_OperatingSystemShortName]  DEFAULT ('Unknown') FOR [OperatingSystemShortName]
GO



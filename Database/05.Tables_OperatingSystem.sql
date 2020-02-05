USE [SQLOpsDB]
GO

/****** Object:  Table [dbo].[OperatingSystems]    Script Date: 2020-02-05 10:07:18 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[OperatingSystems](
	[OperatingSystemID] [int] IDENTITY(1,1) NOT NULL,
	[OperatingSystemName] [varchar](255) NOT NULL,
 CONSTRAINT [PK_OperatingSystems] PRIMARY KEY CLUSTERED 
(
	[OperatingSystemID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO



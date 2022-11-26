USE [SQLOpsDB]
GO

/****** Object:  Table [dbo].[ExtendedPropertyValues]    Script Date: 10/31/2022 7:59:40 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[ExtendedPropertyValues](
	[ExtendedPropertyID] [int] NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[ExtendedPropertyValue] [varchar](255) NOT NULL,
	[DiscoveryOn] [date] NOT NULL,
	[LastUpdated] [date] NOT NULL,
 CONSTRAINT [PK_ExtendedPropertyValues] PRIMARY KEY CLUSTERED 
(
	[ExtendedPropertyID] ASC,
	[SQLInstanceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[ExtendedPropertyValues] ADD  CONSTRAINT [DF_ExtendedPropertyValues_DiscoveryOn]  DEFAULT (getdate()) FOR [DiscoveryOn]
GO

ALTER TABLE [dbo].[ExtendedPropertyValues] ADD  CONSTRAINT [DF_ExtendedPropertyValues_LastUpdated]  DEFAULT (getdate()) FOR [LastUpdated]
GO



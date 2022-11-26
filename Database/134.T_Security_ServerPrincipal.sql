USE [SQLOpsDB]
GO

/****** Object:  Table [Security].[ServerPrincipal]    Script Date: 11/2/2022 6:03:04 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Security].[ServerPrincipal](
	[PrincipalID] [int] IDENTITY(1,1) NOT NULL,
	[PrincipalName] [varchar](255) NOT NULL,
	[PrincipalType] [varchar](50) NOT NULL,
 CONSTRAINT [PK_ServerLogin] PRIMARY KEY CLUSTERED 
(
	[PrincipalID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO



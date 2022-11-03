USE [SQLOpsDB]
GO

/****** Object:  Table [Security].[DatabasePermission]    Script Date: 11/2/2022 6:03:27 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Security].[DatabasePermission](
	[DatabaseID] [int] NOT NULL,
	[GranteeID] [int] NOT NULL,
	[GrantorID] [int] NOT NULL,
	[ObjectType] [varchar](50) NOT NULL,
	[ObjectName] [varchar](255) NOT NULL,
	[Access] [varchar](25) NOT NULL,
	[PermissionName] [varchar](255) NOT NULL,
	[IsArchived] [bit] NOT NULL,
	[DiscoveryOn] [date] NOT NULL,
	[LastUpdated] [date] NOT NULL
) ON [PRIMARY]
GO

ALTER TABLE [Security].[DatabasePermission] ADD  CONSTRAINT [DF_DatabasePermission_IsArchived]  DEFAULT ((0)) FOR [IsArchived]
GO

ALTER TABLE [Security].[DatabasePermission] ADD  CONSTRAINT [DF_DatabasePermission_DiscoveryOn]  DEFAULT (getdate()) FOR [DiscoveryOn]
GO

ALTER TABLE [Security].[DatabasePermission] ADD  CONSTRAINT [DF_DatabasePermission_LastUpdated]  DEFAULT (getdate()) FOR [LastUpdated]
GO

ALTER TABLE [Security].[DatabasePermission]  WITH CHECK ADD  CONSTRAINT [FK_DatabasePermission_DatabasePrincipal_Grantee] FOREIGN KEY([GranteeID])
REFERENCES [Security].[DatabasePrincipal] ([PrincipalID])
GO

ALTER TABLE [Security].[DatabasePermission] CHECK CONSTRAINT [FK_DatabasePermission_DatabasePrincipal_Grantee]
GO

ALTER TABLE [Security].[DatabasePermission]  WITH CHECK ADD  CONSTRAINT [FK_DatabasePermission_DatabasePrincipal_Grantor] FOREIGN KEY([GrantorID])
REFERENCES [Security].[DatabasePrincipal] ([PrincipalID])
GO

ALTER TABLE [Security].[DatabasePermission] CHECK CONSTRAINT [FK_DatabasePermission_DatabasePrincipal_Grantor]
GO

ALTER TABLE [Security].[DatabasePermission]  WITH CHECK ADD  CONSTRAINT [FK_DatabasePermission_Databases] FOREIGN KEY([DatabaseID])
REFERENCES [dbo].[Databases] ([DatabaseID])
GO

ALTER TABLE [Security].[DatabasePermission] CHECK CONSTRAINT [FK_DatabasePermission_Databases]
GO



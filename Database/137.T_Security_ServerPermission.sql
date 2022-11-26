USE [SQLOpsDB]
GO

/****** Object:  Table [Security].[ServerPermission]    Script Date: 11/2/2022 6:04:12 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Security].[ServerPermission](
	[SQLInstanceID] [int] NOT NULL,
	[GranteeID] [int] NOT NULL,
	[GrantorID] [int] NOT NULL,
	[ObjectType] [varchar](50) NOT NULL,
	[ObjectID] [bigint] NOT NULL,
	[Access] [varchar](25) NOT NULL,
	[PermissionName] [varchar](255) NOT NULL,
	[IsArchived] [bit] NOT NULL,
	[DiscoveryOn] [date] NOT NULL,
	[LastUpdated] [date] NOT NULL
) ON [PRIMARY]
GO

ALTER TABLE [Security].[ServerPermission] ADD  CONSTRAINT [DF_ServerPermission_IsArchived]  DEFAULT ((0)) FOR [IsArchived]
GO

ALTER TABLE [Security].[ServerPermission] ADD  CONSTRAINT [DF_ServerPermission_DiscoveryOn]  DEFAULT (getdate()) FOR [DiscoveryOn]
GO

ALTER TABLE [Security].[ServerPermission] ADD  CONSTRAINT [DF_ServerPermission_LastUpdated]  DEFAULT (getdate()) FOR [LastUpdated]
GO

ALTER TABLE [Security].[ServerPermission]  WITH CHECK ADD  CONSTRAINT [FK_ServerPermission_ServerPrincipal_Grantee] FOREIGN KEY([GranteeID])
REFERENCES [Security].[ServerPrincipal] ([PrincipalID])
GO

ALTER TABLE [Security].[ServerPermission] CHECK CONSTRAINT [FK_ServerPermission_ServerPrincipal_Grantee]
GO

ALTER TABLE [Security].[ServerPermission]  WITH CHECK ADD  CONSTRAINT [FK_ServerPermission_ServerPrincipal_Grantor] FOREIGN KEY([GrantorID])
REFERENCES [Security].[ServerPrincipal] ([PrincipalID])
GO

ALTER TABLE [Security].[ServerPermission] CHECK CONSTRAINT [FK_ServerPermission_ServerPrincipal_Grantor]
GO

ALTER TABLE [Security].[ServerPermission]  WITH CHECK ADD  CONSTRAINT [FK_ServerPermission_SQLInstances] FOREIGN KEY([SQLInstanceID])
REFERENCES [dbo].[SQLInstances] ([SQLInstanceID])
GO

ALTER TABLE [Security].[ServerPermission] CHECK CONSTRAINT [FK_ServerPermission_SQLInstances]
GO



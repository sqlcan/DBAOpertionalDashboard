USE [SQLOpsDB]
GO

/****** Object:  Table [Security].[ServerPrincipalMembership]    Script Date: 11/3/2022 4:05:28 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Security].[ServerPrincipalMembership](
	[ServerLoginID] [int] NOT NULL,
	[ServerRoleID] [int] NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[IsArchived] [bit] NOT NULL,
	[DiscoveryOn] [date] NOT NULL,
	[LastUpdated] [date] NOT NULL
) ON [PRIMARY]
GO

ALTER TABLE [Security].[ServerPrincipalMembership] ADD  CONSTRAINT [DF_ServerPrincipalMembership_IsArchived]  DEFAULT ((0)) FOR [IsArchived]
GO

ALTER TABLE [Security].[ServerPrincipalMembership] ADD  CONSTRAINT [DF_ServerPrincipalMembership_DiscoveryOn]  DEFAULT (getdate()) FOR [DiscoveryOn]
GO

ALTER TABLE [Security].[ServerPrincipalMembership] ADD  CONSTRAINT [DF_ServerPrincipalMembership_LastUpdatedOn]  DEFAULT (getdate()) FOR [LastUpdated]
GO

ALTER TABLE [Security].[ServerPrincipalMembership]  WITH CHECK ADD  CONSTRAINT [FK_ServerPrincipalMembership_ServerPrincipal_Login] FOREIGN KEY([ServerLoginID])
REFERENCES [Security].[ServerPrincipal] ([PrincipalID])
GO

ALTER TABLE [Security].[ServerPrincipalMembership] CHECK CONSTRAINT [FK_ServerPrincipalMembership_ServerPrincipal_Login]
GO

ALTER TABLE [Security].[ServerPrincipalMembership]  WITH CHECK ADD  CONSTRAINT [FK_ServerPrincipalMembership_ServerPrincipal_Role] FOREIGN KEY([ServerRoleID])
REFERENCES [Security].[ServerPrincipal] ([PrincipalID])
GO

ALTER TABLE [Security].[ServerPrincipalMembership] CHECK CONSTRAINT [FK_ServerPrincipalMembership_ServerPrincipal_Role]
GO

ALTER TABLE [Security].[ServerPrincipalMembership]  WITH CHECK ADD  CONSTRAINT [FK_ServerPrincipalMembership_SQLInstance] FOREIGN KEY([SQLInstanceID])
REFERENCES [dbo].[SQLInstances] ([SQLInstanceID])
GO

ALTER TABLE [Security].[ServerPrincipalMembership] CHECK CONSTRAINT [FK_ServerPrincipalMembership_SQLInstance]
GO



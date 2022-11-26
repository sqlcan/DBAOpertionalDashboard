USE [SQLOpsDB]
GO

/****** Object:  Table [Security].[DatabasePrincipalMembership]    Script Date: 11/3/2022 4:05:44 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Security].[DatabasePrincipalMembership](
	[DatabaseUserID] [int] NOT NULL,
	[DatabaseRoleID] [int] NOT NULL,
	[DatabaseID] [int] NOT NULL,
	[IsOrphaned] [bit] NOT NULL,
	[IsArchived] [bit] NOT NULL,
	[DiscoveryOn] [date] NOT NULL,
	[LastUpdated] [date] NOT NULL
) ON [PRIMARY]
GO

ALTER TABLE [Security].[DatabasePrincipalMembership] ADD  CONSTRAINT [DF_DatabasePrincipalMembership_IsOrphaned]  DEFAULT ((0)) FOR [IsOrphaned]
GO

ALTER TABLE [Security].[DatabasePrincipalMembership] ADD  CONSTRAINT [DF_DatabasePrincipalMembership_IsArchived]  DEFAULT ((0)) FOR [IsArchived]
GO

ALTER TABLE [Security].[DatabasePrincipalMembership] ADD  CONSTRAINT [DF_DatabasePrincipalMembership_DiscoveryOn]  DEFAULT (getdate()) FOR [DiscoveryOn]
GO

ALTER TABLE [Security].[DatabasePrincipalMembership] ADD  CONSTRAINT [DF_DatabasePrincipalMembership_LastUpdatedOn]  DEFAULT (getdate()) FOR [LastUpdated]
GO

ALTER TABLE [Security].[DatabasePrincipalMembership]  WITH CHECK ADD  CONSTRAINT [FK_DatabasePrincipalMembership_DatabasePrincipal_Role] FOREIGN KEY([DatabaseRoleID])
REFERENCES [Security].[DatabasePrincipal] ([PrincipalID])
GO

ALTER TABLE [Security].[DatabasePrincipalMembership] CHECK CONSTRAINT [FK_DatabasePrincipalMembership_DatabasePrincipal_Role]
GO

ALTER TABLE [Security].[DatabasePrincipalMembership]  WITH CHECK ADD  CONSTRAINT [FK_DatabasePrincipalMembership_DatabasePrincipal_User] FOREIGN KEY([DatabaseUserID])
REFERENCES [Security].[DatabasePrincipal] ([PrincipalID])
GO

ALTER TABLE [Security].[DatabasePrincipalMembership] CHECK CONSTRAINT [FK_DatabasePrincipalMembership_DatabasePrincipal_User]
GO

ALTER TABLE [Security].[DatabasePrincipalMembership]  WITH CHECK ADD  CONSTRAINT [FK_DatabasePrincipalMembership_Databases] FOREIGN KEY([DatabaseID])
REFERENCES [dbo].[Databases] ([DatabaseID])
GO

ALTER TABLE [Security].[DatabasePrincipalMembership] CHECK CONSTRAINT [FK_DatabasePrincipalMembership_Databases]
GO



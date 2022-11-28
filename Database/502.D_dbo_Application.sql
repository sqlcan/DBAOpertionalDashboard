Use [SQLOpsDB]
GO

SET IDENTITY_INSERT dbo.Application ON

SET NOCOUNT ON

INSERT INTO dbo.Application  (ApplicationID, ApplicationName, ApplicationOwner) 
VALUES (1,'Unknown','Unknown')

SET IDENTITY_INSERT dbo.Application OFF
GO

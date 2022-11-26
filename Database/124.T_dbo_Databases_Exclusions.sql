USE [SQLOpsDB]
GO

CREATE TABLE [dbo].[Databases_Exclusions] (
    [DatabaseID]         INT           NOT NULL,
    [SQLInstanceID]      INT           NOT NULL,
    [DatabaseName]       VARCHAR (255) NOT NULL,
    [ReasonForExclusion] VARCHAR (255) NOT NULL
);
GO
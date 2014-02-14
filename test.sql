USE [master]
GO

/****** Object:  Database [ServiceBrokerTest]    Script Date: 08/09/2013 20:58:54 ******/
IF  EXISTS (SELECT name FROM sys.databases WHERE name = N'ServiceBrokerTest')
  DROP DATABASE [ServiceBrokerTest]
GO

CREATE DATABASE ServiceBrokerTest
GO

USE ServiceBrokerTest
GO

ALTER DATABASE [ServiceBrokerTest] SET  ENABLE_BROKER 
GO

IF  EXISTS (SELECT * FROM sys.services WHERE name = N'SBSendService')
  DROP SERVICE [SBSendService]
GO

IF  EXISTS (SELECT * FROM sys.services WHERE name = N'SBReceiveService')
  DROP SERVICE [SBReceiveService]
GO

IF  EXISTS (SELECT * FROM sys.service_contracts WHERE name = N'SBContract')
  DROP CONTRACT [SBContract]
GO

IF  EXISTS (SELECT * FROM sys.service_queues WHERE name = N'SBSendQueue')
  DROP QUEUE [dbo].[SBSendQueue]
GO

IF  EXISTS (SELECT * FROM sys.service_queues WHERE name = N'SBReceiveQueue')
  DROP QUEUE [dbo].[SBReceiveQueue]
GO

IF  EXISTS (SELECT * FROM sys.service_message_types WHERE name = N'SBMessage')
  DROP MESSAGE TYPE [SBMessage]
GO

CREATE MESSAGE TYPE [SBMessage] AUTHORIZATION [dbo] VALIDATION = WELL_FORMED_XML
CREATE CONTRACT [SBContract] AUTHORIZATION [dbo] ([SBMessage] SENT BY INITIATOR)

CREATE QUEUE [dbo].[SBSendQueue] WITH STATUS = ON , RETENTION = OFF , POISON_MESSAGE_HANDLING (STATUS = ON)  ON [PRIMARY]
CREATE QUEUE [dbo].[SBReceiveQueue] WITH STATUS = ON , RETENTION = OFF , POISON_MESSAGE_HANDLING (STATUS = ON)  ON [PRIMARY]

CREATE SERVICE [SBSendService]  AUTHORIZATION [dbo]  ON QUEUE [dbo].[SBSendQueue] ([SBContract])
CREATE SERVICE [SBReceiveService]  AUTHORIZATION [dbo]  ON QUEUE [dbo].[SBReceiveQueue] ([SBContract])
GO 


IF OBJECT_ID('dbo.TestTable', 'U') IS NOT NULL
  DROP TABLE TestTable
GO

CREATE TABLE TestTable (
  Col1 INT, 
  Col2 INT, 
  Col3 VARCHAR(100),
  PRIMARY KEY(Col1, Col2)
)
GO

IF OBJECT_ID('dbo.Audit', 'U') IS NOT NULL
  DROP TABLE Audit
GO

CREATE TABLE Audit (
  [AuditID] INT IDENTITY(1,1) PRIMARY KEY,
  [DateAudited] [datetime] NOT NULL DEFAULT (getdate()),
  [DMLStatement] VARCHAR(6) NOT NULL,
  [AuditedData] [xml] NOT NULL
) 
GO


IF (SELECT COUNT(*) FROM sysobjects WHERE Name = 'trgAudit_tableName') > 0 
  DROP TRIGGER [dbo].[trgAudit_tableName]

GO

CREATE TRIGGER [dbo].[trgAudit_tableName] 
ON  TestTable 
FOR INSERT, UPDATE, DELETE
AS  
BEGIN
  SET NOCOUNT ON;
  DECLARE 
	@Xml XML,
	@Type varchar(6) 

  if exists (select * from inserted)
  BEGIN
	if exists (select * from deleted)
	  select @Type = 'UPDATE'
	else
	  select @Type = 'INSERT'
  END
  else
  BEGIN
	select @Type = 'DELETE'
  END

  SET @Xml = 
  '
  <EVENT_MESSAGE>
	<TABLE>trgAudit_tableName</TABLE>
	<TYPE>' + @Type + '</TYPE>
	<INSERT>' + ISNULL((select Col1, Col2, Col3 from inserted for xml raw), '') + '</INSERT>
	<DELETE>' + ISNULL((select Col1, Col2, Col3 from deleted for xml raw), '') + '</DELETE>
  </EVENT_MESSAGE>
  ';
  
  DECLARE @SBDialog uniqueidentifier
  
  BEGIN DIALOG CONVERSATION @SBDialog
    FROM SERVICE SBSendService
    TO SERVICE 'SBReceiveService'
    ON CONTRACT SBContract
    WITH ENCRYPTION = OFF;

  -- Send messages on Dialog
  SEND ON CONVERSATION @SBDialog
    MESSAGE TYPE SBMessage (@Xml);
  
  END CONVERSATION @SBDialog WITH CLEANUP;
  
  --INSERT INTO Audit (DMLStatement, AuditedData) VALUES(@Type, @Xml)
END
GO

INSERT INTO TestTable (Col1, Col2, Col3)
  SELECT 1, 11, 'First'
    UNION ALL
  SELECT 11, 12, 'Second'
    UNION ALL
  SELECT 21, 13, 'Third'
    UNION ALL
  SELECT 31, 14, 'Fourth'
GO

update TestTable set Col2 = Col2 + 5 where Col1 = 1
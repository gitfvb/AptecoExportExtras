SELECT [Id]
    ,[DateAdded]
    ,[Command].value('(/DeliveryCommand/BroadcastActionDetails/ExternalId/IdType)[1]', 'nvarchar(50)') AS ExternalIdType
    ,[Command].value('(/DeliveryCommand/BroadcastActionDetails/ExternalId/Id)[1]', 'nvarchar(50)') AS ExternalId
    ,[Command].value('(/DeliveryCommand/BroadcastActionDetails/DeliveryKey)[1]', 'uniqueidentifier') AS DeliveryKey
    ,[Command].value('(/DeliveryCommand/BroadcastActionDetails/Run)[1]', 'bigint') AS Run
	,[Command].value('(/DeliveryCommand/BroadcastActionDetails/Parameters)[1]', 'nvarchar(max)') AS Parameters
    ,[Status]
   FROM [dbo].[vDeliveryCommands]
   WHERE [Command].value('(/DeliveryCommand/BroadcastActionDetails/FilePath)[1]', 'varchar(max)') LIKE '%#FILE#'

DECLARE @sql NVARCHAR(MAX) = '';

-- Generate DROP TABLE statements for all tables in dbo schema
SELECT @sql = @sql + 'DROP TABLE IF EXISTS dbo.' + QUOTENAME(TABLE_NAME) + ';' + CHAR(13)
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_TYPE = 'BASE TABLE';

-- Execute the generated DROP TABLE statements
EXEC sp_executesql @sql;

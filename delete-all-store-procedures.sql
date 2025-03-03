DECLARE @procName NVARCHAR(MAX)
DECLARE cur CURSOR FOR 
SELECT '[' + SCHEMA_NAME(schema_id) + '].[' + name + ']' 
FROM sys.procedures

OPEN cur
FETCH NEXT FROM cur INTO @procName

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC('DROP PROCEDURE ' + @procName)
    FETCH NEXT FROM cur INTO @procName
END

CLOSE cur
DEALLOCATE cur

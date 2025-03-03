-- Source: https://techcommunity.microsoft.com/blog/azuredbsupport/troubleshooting-high-lock-wait-time-and-lock-time-out/2368875

--Blocking tree

SET NOCOUNT ON
GO
SELECT SPID, BLOCKED, REPLACE (REPLACE (T.TEXT, CHAR(10), ' '), CHAR (13), ' ' ) AS BATCH
INTO #T
FROM sys.sysprocesses R CROSS APPLY sys.dm_exec_sql_text(R.SQL_HANDLE) T
GO
WITH BLOCKERS (SPID, BLOCKED, LEVEL, BATCH)
AS
(
SELECT SPID,
BLOCKED,
CAST (REPLICATE ('0', 4-LEN (CAST (SPID AS VARCHAR))) + CAST (SPID AS VARCHAR) AS VARCHAR (1000)) AS LEVEL,
BATCH FROM #T R
WHERE (BLOCKED = 0 OR BLOCKED = SPID)
AND EXISTS (SELECT * FROM #T R2 WHERE R2.BLOCKED = R.SPID AND R2.BLOCKED <> R2.SPID)
UNION ALL
SELECT R.SPID,
R.BLOCKED,
CAST (BLOCKERS.LEVEL + RIGHT (CAST ((1000 + R.SPID) AS VARCHAR (100)), 4) AS VARCHAR (1000)) AS LEVEL,
R.BATCH FROM #T AS R
INNER JOIN BLOCKERS ON R.BLOCKED = BLOCKERS.SPID WHERE R.BLOCKED > 0 AND R.BLOCKED <> R.SPID
)
SELECT N'    ' + REPLICATE (N'|         ', LEN (LEVEL)/4 - 1) +
CASE WHEN (LEN(LEVEL)/4 - 1) = 0
THEN 'HEAD -  '
ELSE '|------  ' END
+ CAST (SPID AS NVARCHAR (10)) + N' ' + BATCH AS BLOCKING_TREE
FROM BLOCKERS ORDER BY LEVEL ASC
GO
DROP TABLE #T
GO

--Details about the sessions that are blocking and being blocked:

 

SELECT current_timestamp as [CURRENT_TIMESTAMP]

       , DB_NAME(dtl.resource_database_id) AS database_name

       , req.session_id AS blocked_sessionID

       , ses.program_name blocked_programName

       , ses.host_name blocked_hostname

       , ses.login_name blocked_login

       , CASE ses.transaction_isolation_level

              WHEN 1 THEN 'ReadUncomitted'

              WHEN 2 THEN 'ReadCommitted'

              WHEN 3 THEN 'Repeatable'

              WHEN 4 THEN 'Serializable'

              WHEN 5 THEN 'Snapshot'

       END blocked_isolation_level

       , REPLACE(REPLACE(sqltext.TEXT, CHAR(13), ' '), CHAR(10), ' ') AS blocked_last_query

       , req.status AS [blocked_status]

       , req.command AS blocked_command

       , req.cpu_time AS blocked_cpuTime

       , req.total_elapsed_time AS blocked_totalElapsedTime

       , blocked_tran.transaction_id blocked_transaction_id

       , osw.blocking_session_id AS blocker_SessionID

       , blocker_ses.program_name blocker_programName

       , blocker_ses.host_name blocker_hostName

       , blocker_ses.login_name blocker_login

       , CASE blocker_ses.transaction_isolation_level

              WHEN 1 THEN 'ReadUncomitted'

              WHEN 2 THEN 'ReadCommitted'

              WHEN 3 THEN 'Repeatable'

              WHEN 4 THEN 'Serializable'

              WHEN 5 THEN 'Snapshot'

       END blocker_isolation_level

       , REPLACE(REPLACE(iif(blocker_sqltext.TEXT is NULL,blocker_sqltext2.event_info,blocker_sqltext.TEXT), CHAR(13), ' '), CHAR(10), ' ') AS blocker_last_query

       , blocker_req.status AS [blocker_status]

       , blocker_req.command AS blocker_command

       , blocker_req.cpu_time AS blocker_cpuTime

       , blocker_req.total_elapsed_time AS blocker_totalElapsedTime

       , blocker_proc.lastwaittype blocker_last_waittype

       , blocker_proc.last_batch blocker_last_batch

       , blocker_proc.open_tran blocker_open_tran

       , blocker_tran.transaction_id blocker_transaction_id

       , blocker_proc.cmd blocker_command

       , dtl.request_mode AS lockRequestMode

       , dtl.resource_type AS lockResourceType

       , dtl.resource_subtype AS lockResourceSubType

       , osw.wait_type AS taskWaitType

       , osw.resource_description AS taskResourceDescription

       , osw.wait_duration_ms

FROM sys.dm_exec_requests req

INNER JOIN sys.dm_exec_sessions ses on ses.session_id = req.session_id

CROSS APPLY sys.dm_exec_sql_text(req.sql_handle) AS sqltext

INNER JOIN sys.dm_tran_locks dtl on dtl.request_session_id = req.session_id

INNER JOIN sys.dm_os_waiting_tasks osw on osw.session_id = req.session_id

LEFT JOIN sys.dm_tran_session_transactions blocked_tran on blocked_tran.session_id =req.session_id

INNER JOIN dbo.sysprocesses blocker_proc on osw.blocking_session_id = blocker_proc.spid

LEFT JOIN sys.dm_exec_requests blocker_req on blocker_req.session_id = osw.blocking_session_id

LEFT JOIN sys.dm_exec_sessions blocker_ses on blocker_ses.session_id = osw.blocking_session_id

LEFT JOIN sys.dm_tran_session_transactions blocker_tran on blocker_tran.session_id =osw.blocking_session_id

OUTER APPLY sys.dm_exec_sql_text(blocker_req.sql_handle) AS blocker_sqltext

OUTER APPLY sys.dm_exec_input_buffer(osw.blocking_session_id,0) as blocker_sqltext2;



--Details about the locks that are being held by the sessions that are blocking and being blocked:

select DB_NAME(locks.resource_database_id) AS database_name

 , locks.request_session_id

 , locks.resource_type, locks.resource_subtype

 , locks.resource_description

 , locks.resource_associated_entity_id

 , locks.resource_lock_partition

 , locks.request_mode

 , locks.request_type

 , locks.request_status

 , locks.request_reference_count

 , locks.request_lifetime

 , locks.request_exec_context_id

 , locks.request_request_id

 , locks.request_owner_type

FROM sys.dm_exec_requests req

INNER JOIN sys.dm_os_waiting_tasks osw on osw.session_id = req.session_id

INNER JOIN sys.dm_tran_locks locks on osw.blocking_session_id = locks.request_session_id or (osw.session_id = locks.request_session_id and osw.blocking_session_id is not null)

order by locks.request_session_id;


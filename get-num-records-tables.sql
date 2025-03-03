SELECT 
    t.name AS TableName,
    p.rows AS RowCounts
FROM 
    sys.tables AS t
INNER JOIN     
    sys.partitions AS p ON t.object_id = p.object_id
WHERE 
    p.index_id IN (0, 1) -- 0 = Heap, 1 = Clustered index
GROUP BY 
    t.name, p.rows
ORDER BY 
    p.rows DESC;

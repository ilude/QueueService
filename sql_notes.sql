select *
from INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk 
join INFORMATION_SCHEMA.KEY_COLUMN_USAGE c on c.TABLE_NAME = pk.TABLE_NAME AND c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME
where CONSTRAINT_TYPE = 'PRIMARY KEY'

select *
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE c


SELECT 
  STUFF(SELECT ',' + COLUMN_NAME
    INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
    FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 1, '')
    
DECLARE @listStr VARCHAR(MAX)
SELECT @listStr = COALESCE(@listStr+',' , '') + COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE C

SELECT @listStr


select 
  C.TABLE_NAME, 
    stuff((
        select ',' + U.COLUMN_NAME
        from INFORMATION_SCHEMA.KEY_COLUMN_USAGE U
        where U.TABLE_NAME = C.TABLE_NAME
        order by U.ORDINAL_POSITION
        for xml path('')
    ),1,1,'') as PRIMARY_KEYS
from INFORMATION_SCHEMA.KEY_COLUMN_USAGE C
group by C.TABLE_NAME 
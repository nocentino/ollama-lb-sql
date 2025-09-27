CREATE DATABASE StackOverflow_Embeddings_Small
ON 
    (FILENAME = N'/var/opt/mssql/data/StackOverflow2013_1.mdf'),
    (FILENAME = N'/var/opt/mssql/data/StackOverflow2013_2.ndf'),
    (FILENAME = N'/var/opt/mssql/data/StackOverflow2013_3.ndf'),
    (FILENAME = N'/var/opt/mssql/data/StackOverflow2013_4.ndf')
LOG ON
    (FILENAME = N'/var/opt/mssql/data/StackOverflow2013_log.ldf')
FOR ATTACH ;


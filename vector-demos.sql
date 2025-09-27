ALTER DATABASE [StackOverflow_Embeddings_Small]
ADD FILEGROUP EmbeddingsFileGroup;
GO

ALTER DATABASE [StackOverflow_Embeddings_Small]
ADD FILE (
    NAME = N'StackOverflowEmbeddings',
    FILENAME = N'/var/opt/mssql/data/StackOverflow_Embeddings.ndf',
    SIZE = 20GB,
    FILEGROWTH = 64MB
) TO FILEGROUP EmbeddingsFileGroup;
GO

CREATE TABLE dbo.PostEmbeddings (
    PostID INT NOT NULL PRIMARY KEY CLUSTERED,
    Embedding VECTOR(768) NOT NULL,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
    UpdatedAt DATETIME NULL
) ON EmbeddingsFileGroup;
GO

USE [StackOverflow_Embeddings_Small];
GO

PRINT 'Step 2: Creating external model connection to load-balanced Ollama...';
GO

-- Drop existing external model if it exists
IF EXISTS (SELECT * FROM sys.external_models WHERE name = 'ollama_lb')
BEGIN
    DROP EXTERNAL MODEL ollama_lb;
    PRINT 'Existing external model dropped.';
END
GO

-- Create external model pointing to our load-balanced nginx endpoint
CREATE EXTERNAL MODEL ollama_lb
WITH (
    LOCATION = 'https://host.docker.internal:443/api/embed',
    API_FORMAT = 'Ollama',
    MODEL_TYPE = EMBEDDINGS,
    MODEL = 'nomic-embed-text'
);
GO

CREATE EXTERNAL MODEL ollama_single
WITH (
    LOCATION = 'https://host.docker.internal:444/api/embed',
    API_FORMAT = 'Ollama',
    MODEL_TYPE = EMBEDDINGS,
    MODEL = 'nomic-embed-text'
);
GO


PRINT 'External model created successfully!';
GO

PRINT 'Testing load-balanced Ollama connection...';
GO

-- Test the external model connection
BEGIN TRY
    DECLARE @test_result NVARCHAR(MAX);
    DECLARE @test_vector VECTOR(768);
    
    SET @test_vector = AI_GENERATE_EMBEDDINGS(N'test message for load balancer' USE MODEL ollama_lb);
    SET @test_result = CONVERT(NVARCHAR(MAX), @test_vector);
    
    IF @test_result IS NOT NULL AND LEN(@test_result) > 10
    BEGIN
        PRINT 'SUCCESS: Load-balanced Ollama connection working!';
        PRINT 'Vector length: ' + CAST(LEN(@test_result) AS VARCHAR(10)) + ' characters';
        PRINT 'Vector: ' + CAST(@test_result AS VARCHAR(MAX)) + ' characters';
    END
    ELSE
    BEGIN
        PRINT 'WARNING: Connection established but no valid response received.';
    END
END TRY
BEGIN CATCH
    PRINT 'ERROR: Failed to connect to load-balanced Ollama:';
    PRINT ERROR_MESSAGE();
END CATCH
GO


-- Test the external model connection
BEGIN TRY
    DECLARE @test_result NVARCHAR(MAX);
    DECLARE @test_vector VECTOR(768);
    
    SET @test_vector = AI_GENERATE_EMBEDDINGS(N'test message for load balancer' USE MODEL ollama_single);
    SET @test_result = CONVERT(NVARCHAR(MAX), @test_vector);
    
    IF @test_result IS NOT NULL AND LEN(@test_result) > 10
    BEGIN
        PRINT 'SUCCESS: Load-balanced Ollama connection working!';
        PRINT 'Vector length: ' + CAST(LEN(@test_result) AS VARCHAR(10)) + ' characters';
        PRINT 'Vector: ' + CAST(@test_result AS VARCHAR(MAX)) + ' characters';
    END
    ELSE
    BEGIN
        PRINT 'WARNING: Connection established but no valid response received.';
    END
END TRY
BEGIN CATCH
    PRINT 'ERROR: Failed to connect to load-balanced Ollama:';
    PRINT ERROR_MESSAGE();
END CATCH
GO

-- Get the database compatibility level
SELECT compatibility_level
FROM sys.databases
WHERE name = 'StackOverflow_Embeddings_Small';

-- Set compatibility level is at least 170
PRINT 'Setting database compatibility level to 170...';
ALTER DATABASE [StackOverflow_Embeddings_Small] SET COMPATIBILITY_LEVEL = 170;

DECLARE @BatchSize INT = 1000;
DECLARE @StartRow INT = 0;
DECLARE @MaxPostID INT;

SELECT @MaxPostID = MAX(Id) FROM dbo.Posts;

WHILE @StartRow <= @MaxPostID
BEGIN
    INSERT INTO dbo.PostEmbeddings (PostID, Embedding, CreatedAt)
    SELECT
        p.Id AS PostID,
        AI_GENERATE_EMBEDDINGS(p.Title USE MODEL ollama) AS Embedding,
        GETDATE() AS CreatedAt
    FROM dbo.Posts p
    WHERE p.Id BETWEEN @StartRow AND @StartRow + @BatchSize - 1
        AND NOT EXISTS (
            SELECT 1 FROM dbo.PostEmbeddings pe WHERE pe.PostID = p.Id
        )
        AND p.Title IS NOT NULL
    OPTION(USE HINT('ENABLE_PARALLEL_PLAN_PREFERENCE'))

    SET @StartRow = @StartRow + @BatchSize;
    PRINT 'Processed rows from ' + CAST(@StartRow - @BatchSize AS NVARCHAR(10)) + ' to ' + CAST(@StartRow - 1 AS NVARCHAR(10));
END;
GO

SELECT TOP 10 p.Id, p.Title, pe.Embedding, pe.CreatedAt
FROM dbo.Posts p
JOIN dbo.PostEmbeddings pe ON p.Id = pe.PostID
WHERE Embedding IS NOT NULL;
GO

DECLARE @QueryText NVARCHAR(MAX) = N'Find me posts about issues with SQL Server performance';
DECLARE @QueryEmbedding VECTOR(768);

SET @QueryEmbedding = AI_GENERATE_EMBEDDINGS(@QueryText USE MODEL ollama);

SELECT TOP 10
    p.Id,
    p.Title,
    pe.Embedding,
    vector_distance('cosine', @QueryEmbedding, pe.Embedding) AS SimilarityScore
FROM dbo.Posts p
JOIN dbo.PostEmbeddings pe ON p.Id = pe.PostID
WHERE pe.Embedding IS NOT NULL
ORDER BY SimilarityScore ASC;
GO

EXEC sp_spaceused N'dbo.PostEmbeddings';
SELECT TOP 1 * FROM dbo.PostEmbeddings;
GO

-- Compare embedding generation performance: load-balanced vs single endpoint

USE [StackOverflow_Embeddings_Small];

-- Enable timing statistics
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- Test 1: Load-balanced endpoint
PRINT 'Generating embeddings using LOAD-BALANCED endpoint...';

INSERT INTO dbo.PostEmbeddings  WITH(TABLOCK) (PostID, Embedding, CreatedAt)     
SELECT top 1000
    p.Id AS PostID,
    AI_GENERATE_EMBEDDINGS(p.Title USE MODEL ollama_lb) AS Embedding,
    GETDATE() AS CreatedAt
FROM dbo.Posts p
WHERE p.Title IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM dbo.PostEmbeddings pe WHERE pe.PostID = p.Id) OPTION(USE HINT('ENABLE_PARALLEL_PLAN_PREFERENCE'))
GO
/*
 SQL Server Execution Times:
   CPU time = 2047 ms,  elapsed time = 5359 ms.
Total execution time: 00:00:05.413
*/

-- Test 2: Single endpoint
PRINT 'Generating embeddings using SINGLE endpoint...';

INSERT INTO dbo.PostEmbeddings (PostID, Embedding, CreatedAt)
SELECT top 1000
    p.Id AS PostID,
    AI_GENERATE_EMBEDDINGS(p.Title USE MODEL ollama_single) AS Embedding,
    GETDATE() AS CreatedAt
FROM dbo.Posts p
WHERE p.Title IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM dbo.PostEmbeddings pe WHERE pe.PostID = p.Id);

GO
/*

 SQL Server Execution Times:
   CPU time = 3909 ms,  elapsed time = 30370 ms.
Total execution time: 00:00:30.419
*/
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO


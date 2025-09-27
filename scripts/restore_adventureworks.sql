-- AdventureWorks Database Restore Script
-- Restores AdventureWorks2025 database from backup file
-- Based on the ollama-sql-faststart project restoration process

USE [master];
GO

PRINT 'Starting AdventureWorks database restoration...';
GO

-- Check if backup file exists and get info
IF EXISTS (SELECT 1 FROM sys.dm_os_file_exists('/backups/AdventureWorks2025_FULL.bak'))
BEGIN
    PRINT 'AdventureWorks backup file found, proceeding with restoration...';
    
    -- Get backup file information
    RESTORE FILELISTONLY FROM DISK = '/backups/AdventureWorks2025_FULL.bak';
    
    -- Disconnect all users from the database before restore (if it exists)
    IF EXISTS (SELECT name FROM sys.databases WHERE name = 'AdventureWorksLT')
    BEGIN
        PRINT 'Disconnecting users from existing AdventureWorksLT database...';
        ALTER DATABASE [AdventureWorksLT] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    END
    
    -- Restore the database
    PRINT 'Restoring AdventureWorksLT database...';
    RESTORE DATABASE [AdventureWorksLT]
    FROM DISK = '/backups/AdventureWorks2025_FULL.bak'
    WITH
        MOVE 'AdventureWorksLT2022_Data' TO '/var/opt/mssql/data/AdventureWorksLT_Data.mdf',
        MOVE 'AdventureWorksLT2022_Log' TO '/var/opt/mssql/data/AdventureWorksLT_log.ldf',
        FILE = 1,
        NOUNLOAD,
        STATS = 10,
        REPLACE;
    
    -- Set database to multi-user mode
    ALTER DATABASE [AdventureWorksLT] SET MULTI_USER;
    
    PRINT 'AdventureWorksLT database restored successfully!';
END
ELSE
BEGIN
    PRINT 'AdventureWorks backup file not found. Creating sample AdventureWorksLT database...';
    
    -- Create a basic AdventureWorksLT database structure if backup is not available
    IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'AdventureWorksLT')
    BEGIN
        CREATE DATABASE [AdventureWorksLT];
        PRINT 'AdventureWorksLT database created.';
    END
    
    USE [AdventureWorksLT];
    GO
    
    -- Create basic schema structure
    IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'SalesLT')
    BEGIN
        EXEC('CREATE SCHEMA SalesLT');
        PRINT 'SalesLT schema created.';
    END
    
    -- Create a simple Product table for demonstration
    IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[SalesLT].[Product]') AND type in (N'U'))
    BEGIN
        CREATE TABLE [SalesLT].[Product](
            [ProductID] [int] IDENTITY(1,1) NOT NULL,
            [Name] [nvarchar](50) NOT NULL,
            [ProductNumber] [nvarchar](25) NOT NULL,
            [Color] [nvarchar](15) NULL,
            [StandardCost] [money] NOT NULL,
            [ListPrice] [money] NOT NULL,
            [Size] [nvarchar](5) NULL,
            [Weight] [decimal](8, 2) NULL,
            [ProductCategoryID] [int] NULL,
            [ProductModelID] [int] NULL,
            [SellStartDate] [datetime] NOT NULL,
            [SellEndDate] [datetime] NULL,
            [DiscontinuedDate] [datetime] NULL,
            CONSTRAINT [PK_Product_ProductID] PRIMARY KEY CLUSTERED ([ProductID] ASC)
        );
        PRINT 'Product table created.';
    END
    
    -- Create ProductCategory table
    IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[SalesLT].[ProductCategory]') AND type in (N'U'))
    BEGIN
        CREATE TABLE [SalesLT].[ProductCategory](
            [ProductCategoryID] [int] IDENTITY(1,1) NOT NULL,
            [ParentProductCategoryID] [int] NULL,
            [Name] [nvarchar](50) NOT NULL,
            CONSTRAINT [PK_ProductCategory_ProductCategoryID] PRIMARY KEY CLUSTERED ([ProductCategoryID] ASC)
        );
        PRINT 'ProductCategory table created.';
    END
    
    -- Create ProductModel table
    IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[SalesLT].[ProductModel]') AND type in (N'U'))
    BEGIN
        CREATE TABLE [SalesLT].[ProductModel](
            [ProductModelID] [int] IDENTITY(1,1) NOT NULL,
            [Name] [nvarchar](50) NOT NULL,
            CONSTRAINT [PK_ProductModel_ProductModelID] PRIMARY KEY CLUSTERED ([ProductModelID] ASC)
        );
        PRINT 'ProductModel table created.';
    END
    
    -- Insert sample data for demonstration
    PRINT 'Inserting sample data...';
    
    -- Sample categories
    IF NOT EXISTS (SELECT 1 FROM [SalesLT].[ProductCategory])
    BEGIN
        INSERT INTO [SalesLT].[ProductCategory] ([Name]) VALUES 
        ('Bikes'), 
        ('Components'), 
        ('Clothing'), 
        ('Accessories');
    END
    
    -- Sample models
    IF NOT EXISTS (SELECT 1 FROM [SalesLT].[ProductModel])
    BEGIN
        INSERT INTO [SalesLT].[ProductModel] ([Name]) VALUES 
        ('Mountain Bike'), 
        ('Road Bike'), 
        ('Touring Bike'),
        ('Hybrid Bike');
    END
    
    -- Sample products
    IF NOT EXISTS (SELECT 1 FROM [SalesLT].[Product])
    BEGIN
        INSERT INTO [SalesLT].[Product] 
        ([Name], [ProductNumber], [Color], [StandardCost], [ListPrice], [ProductCategoryID], [ProductModelID], [SellStartDate])
        VALUES 
        ('Mountain-100 Silver, 38', 'BK-M82S-38', 'Silver', 1912.1544, 3399.99, 1, 1, GETDATE()),
        ('Mountain-100 Silver, 42', 'BK-M82S-42', 'Silver', 1912.1544, 3399.99, 1, 1, GETDATE()),
        ('Mountain-100 Black, 38', 'BK-M82B-38', 'Black', 1912.1544, 3399.99, 1, 1, GETDATE()),
        ('Road-150 Red, 62', 'BK-R93R-62', 'Red', 2171.2942, 3578.27, 1, 2, GETDATE()),
        ('Road-150 Red, 44', 'BK-R93R-44', 'Red', 2171.2942, 3578.27, 1, 2, GETDATE()),
        ('Touring-1000 Blue, 60', 'BK-T79U-60', 'Blue', 1481.9379, 2384.07, 1, 3, GETDATE());
    END
    
    PRINT 'Sample AdventureWorksLT database with demo data created successfully!';
END
GO

-- Verify the database setup
USE [AdventureWorksLT];
GO

PRINT 'Verifying database setup...';
SELECT 
    'Products' AS TableName,
    COUNT(*) AS RecordCount
FROM [SalesLT].[Product]
UNION ALL
SELECT 
    'ProductCategories' AS TableName,
    COUNT(*) AS RecordCount
FROM [SalesLT].[ProductCategory]
UNION ALL
SELECT 
    'ProductModels' AS TableName,
    COUNT(*) AS RecordCount
FROM [SalesLT].[ProductModel];
GO

PRINT 'AdventureWorksLT database setup completed successfully!';
GO

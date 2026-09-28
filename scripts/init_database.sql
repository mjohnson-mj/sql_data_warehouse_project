/* 
======================================================
Create Database and Schemas
======================================================
Script Purpose:
    This script creates a new database named 'datawarehouse' and also sets up
    three schemas within the database: 'bronze', 'silver', and 'gold'.

Note:
    This script was written in Visual Studio Code connected to PostgreSQL 18 pgAdmin4.

    First create the new database under general postgres connection in VS Code, then
    create new connection to database using SQLTools PostgreSQL.

*/

CREATE DATABASE datawarehouse;

-- Create bronze, silver, and gold schemas
CREATE SCHEMA bronze;
CREATE SCHEMA silver;
CREATE SCHEMA gold;


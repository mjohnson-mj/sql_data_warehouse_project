/*
=====================================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
=====================================================================================

Script Purpose:
    This stored procedure loads data into the 'bronze'schema from external CSV files.
    It performs the following actions:
    - Truncates the bronze tables before loading data.
    - Uses the 'COPY' command to load data from CSV files to bronze tables.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    CALL bronze.load_bronze();

=====================================================================================
*/

CREATE OR REPLACE PROCEDURE bronze.load_bronze()
LANGUAGE plpgsql
AS $$
DECLARE
    -- Timing variables
    v_batch_start_time  TIMESTAMP;
    v_batch_end_time    TIMESTAMP;
    v_start_time        TIMESTAMP;
    v_end_time          TIMESTAMP;

    -- Error variables
    v_error_message     TEXT;
    v_error_state       TEXT;
BEGIN
    v_batch_start_time := clock_timestamp();

    RAISE INFO '===================================================================';
    RAISE INFO 'Loading Bronze Layer';
    RAISE INFO '===================================================================';

    RAISE INFO '-------------------------------------------------------------------';
    RAISE INFO ' Loading CRM Tables';
    RAISE INFO '-------------------------------------------------------------------';

    -- Table 1: crm_cust_info
    v_start_time := clock_timestamp();
    RAISE INFO '>> Truncating Table: bronze.crm_cust_info';
    TRUNCATE TABLE bronze.crm_cust_info;

    RAISE INFO '>> Inserting Data Into: bronze.crm_cust_info';
    COPY bronze.crm_cust_info
    FROM 'C:\MEGAN\Data_Analyst\sql-data-warehouse-project-main\datasets\source_crm\cust_info.csv'
    WITH (
        FORMAT csv,
        HEADER true,
        DELIMITER ','
    );
    v_end_time := clock_timestamp();
    RAISE INFO '>> Load Duration: %', (v_end_time - v_start_time);
    RAISE INFO '>> -------------';


    -- Table 2: crm_prd_info
    v_start_time := clock_timestamp();
    RAISE INFO '>> Truncating Table: bronze.crm_prd_info';
    TRUNCATE TABLE bronze.crm_prd_info;

    RAISE INFO '>> Inserting Data Into: bronze.crm_prd_info';
    COPY bronze.crm_prd_info
    FROM 'C:\MEGAN\Data_Analyst\sql-data-warehouse-project-main\datasets\source_crm\prd_info.csv'
    WITH (
        FORMAT csv,
        HEADER true,
        DELIMITER ','
    );
    v_end_time := clock_timestamp();
    RAISE INFO '>> Load Duration: %', (v_end_time - v_start_time);
    RAISE INFO '>> -------------';


    -- Table 3: crm_sales_details
    v_start_time := clock_timestamp();
    RAISE INFO '>> Truncating Table: bronze.crm_sales_details';
    TRUNCATE TABLE bronze.crm_sales_details;

    RAISE INFO '>> Inserting Data Into: bronze.crm_sales_details';
    COPY bronze.crm_sales_details
    FROM 'C:\MEGAN\Data_Analyst\sql-data-warehouse-project-main\datasets\source_crm\sales_details.csv'
    WITH (
        FORMAT csv,
        HEADER true,
        DELIMITER ','
    );
    v_end_time := clock_timestamp();
    RAISE INFO '>> Load Duration: %', (v_end_time - v_start_time);
    RAISE INFO '>> -------------';


    RAISE INFO '-------------------------------------------------------------------';
    RAISE INFO ' Loading ERP Tables';
    RAISE INFO '-------------------------------------------------------------------';


    -- Table 4: erp_cust_az12
    v_start_time := clock_timestamp();
    RAISE INFO '>> Truncating Table: bronze.erp_cust_az12';
    TRUNCATE TABLE bronze.erp_cust_az12;

    RAISE INFO '>> Inserting Data Into: bronze.erp_cust_az12';
    COPY bronze.erp_cust_az12
    FROM 'C:\MEGAN\Data_Analyst\sql-data-warehouse-project-main\datasets\source_erp\cust_az12.csv'
    WITH (
        FORMAT csv,
        HEADER true,
        DELIMITER ','
    );
    v_end_time := clock_timestamp();
    RAISE INFO '>> Load Duration: %', (v_end_time - v_start_time);
    RAISE INFO '>> -------------';


    -- Table 5: erp_loc_a101
    v_start_time := clock_timestamp();
    RAISE INFO '>> Truncating Table: bronze.erp_loc_a101';
    TRUNCATE TABLE bronze.erp_loc_a101;

    RAISE INFO '>> Inserting Data Into: bronze.erp_loc_a101';
    COPY bronze.erp_loc_a101
    FROM 'C:\MEGAN\Data_Analyst\sql-data-warehouse-project-main\datasets\source_erp\loc_a101.csv'
    WITH (
        FORMAT csv,
        HEADER true,
        DELIMITER ','
    );
    v_end_time := clock_timestamp();
    RAISE INFO '>> Load Duration: %', (v_end_time - v_start_time);
    RAISE INFO '>> -------------';


    -- Table 6: erp_px_cat_g1v2
    v_start_time := clock_timestamp();
    RAISE INFO '>> Truncating Table: bronze.erp_px_cat_g1v2';
    TRUNCATE TABLE bronze.erp_px_cat_g1v2;

    RAISE INFO '>> Inserting Data Into: bronze.erp_px_cat_g1v2';
    COPY bronze.erp_px_cat_g1v2
    FROM 'C:\MEGAN\Data_Analyst\sql-data-warehouse-project-main\datasets\source_erp\px_cat_g1v2.csv'
    WITH (
        FORMAT csv,
        HEADER true,
        DELIMITER ','
    );
    v_end_time := clock_timestamp();
    RAISE INFO '>> Load Duration: %', (v_end_time - v_start_time);
    RAISE INFO '>> -------------';

    -- Total Load Duration
    v_batch_end_time := clock_timestamp();
    RAISE INFO '-------------------------------------------------------------------';
    RAISE INFO 'Bronze Layer Loading Completed Successfully';
    RAISE INFO 'Total Load Duration: %', (v_batch_end_time - v_batch_start_time);
    RAISE INFO '-------------------------------------------------------------------';

    
-- Catch any exception thrown inside the procedure
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            v_error_message = MESSAGE_TEXT,
            v_error_state = RETURNED_SQLSTATE;
        RAISE INFO '===================================================================';
        RAISE INFO 'ERROR OCCURRED DURING LOADING BRONZE LAYER';
        RAISE INFO 'Error Message: %', v_error_message;
        RAISE INFO 'Error State/Code: %', v_error_state;
END;
$$;


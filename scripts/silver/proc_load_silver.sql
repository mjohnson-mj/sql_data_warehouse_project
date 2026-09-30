/*
=====================================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
=====================================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver' schema tables from the 'bronze' schema.
        Actions Performed:
            - Truncates Silver tables.
            - Inserts transformed and cleansed data from Bronze into Silver tables.

Parameters:
    None.
        This stored procedure does not accept any parameters or return any values.

Usage Example:
    CALL silver.load_silver();
=====================================================================================
*/

CREATE OR REPLACE PROCEDURE silver.load_silver()
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
    RAISE INFO 'Loading Silver Layer';
    RAISE INFO '===================================================================';

    RAISE INFO '-------------------------------------------------------------------';
    RAISE INFO ' Loading CRM Tables';
    RAISE INFO '-------------------------------------------------------------------';

    -- Table 1: crm_cust_info
    v_start_time := clock_timestamp();
    RAISE INFO '>> Truncating Table: silver.crm_cust_info';
    TRUNCATE TABLE silver.crm_cust_info;
    RAISE INFO '>> Inserting Data Into: silver.crm_cust_info';
    INSERT INTO silver.crm_cust_info (
        cst_id,
        cst_key,
        cst_firstname,
        cst_lastname,
        cst_marital_status,
        cst_gndr,
        cst_create_date
    )
    SELECT
        cst_id,
        cst_key,
        TRIM(cst_firstname) AS cst_firstname,
        TRIM(cst_lastname) AS cst_lastname,
        CASE
            WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
            WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
            ELSE 'n/a'
        END cst_marital_status, -- Normalize marital status values to readable format
        CASE
            WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
            WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
            ELSE 'n/a'
        END cst_gndr,   -- Normalize gender values to readable format
        cst_create_date
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
        FROM bronze.crm_cust_info
        WHERE cst_id IS NOT NULL
    )t WHERE flag_last = 1;  -- Select the most recent record per customer
    v_end_time := clock_timestamp();
    RAISE INFO '>> Load Duration: %', (v_end_time - v_start_time);
    RAISE INFO '>> -------------';


    -- Table 2: crm_prd_info
    v_start_time := clock_timestamp();
    RAISE INFO '>> Truncating Table: silver.crm_prd_info';
    TRUNCATE TABLE silver.crm_prd_info;
    RAISE INFO '>> Inserting Data Into: silver.crm_prd_info';
    INSERT INTO silver.crm_prd_info (
        prd_id,
        cat_id,
        prd_key,
        prd_nm,
        prd_cost,
        prd_line,
        prd_start_dt,
        prd_end_dt
    )
    SELECT
        prd_id,
        REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,  -- Extract category ID
        SUBSTRING(prd_key, 7, LENGTH(prd_key)) AS prd_key,      -- Extract product key
        prd_nm,
        COALESCE(prd_cost, 0) AS prd_cost,
        CASE UPPER(TRIM(prd_line))
            WHEN 'M' THEN 'Mountain'
            WHEN 'R' THEN 'Road'
            WHEN 'S' THEN 'Other Sales'
            WHEN 'T' THEN 'Touring'
            ELSE 'n/a'
        END prd_line,   -- Map product line codes to descriptive values
        prd_start_dt::DATE AS prd_start_dt,
        -- Calculate the end date as one day before the next start date
        LEAD(prd_start_dt::DATE) OVER(PARTITION BY prd_key ORDER BY prd_start_dt ASC) - 1 AS prd_end_dt
    FROM bronze.crm_prd_info;
    v_end_time := clock_timestamp();
    RAISE INFO '>> Load Duration: %', (v_end_time - v_start_time);
    RAISE INFO '>> -------------';


    -- Table 3: crm_sales_details
    v_start_time := clock_timestamp();
    RAISE INFO '>> Truncating Table: silver.crm_sales_details';
    TRUNCATE TABLE silver.crm_sales_details;
    RAISE INFO '>> Inserting Data Into: silver.crm_sales_details';
    INSERT INTO silver.crm_sales_details (
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        sls_order_dt,
        sls_ship_dt,
        sls_due_dt,
        sls_sales,
        sls_quantity,
        sls_price
    )
    SELECT
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        CASE
            WHEN sls_order_dt = 0 OR LENGTH(sls_order_dt::TEXT) <> 8 THEN NULL
            ELSE CAST(CAST(sls_order_dt AS TEXT) AS DATE)
        END AS sls_order_dt,
        CASE
            WHEN sls_ship_dt = 0 OR LENGTH(sls_ship_dt::TEXT) <> 8 THEN NULL
            ELSE CAST(CAST(sls_ship_dt AS TEXT) AS DATE)
        END AS sls_ship_dt,
        CASE
            WHEN sls_due_dt = 0 OR LENGTH(sls_due_dt::TEXT) <> 8 THEN NULL
            ELSE CAST(CAST(sls_due_dt AS TEXT) AS DATE)
        END AS sls_due_dt,
        CASE
            WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales <> sls_quantity * ABS(sls_price)
                THEN sls_quantity * ABS(sls_price)
            ELSE sls_sales
        END AS sls_sales,   -- Recalculate sales if original value is missing or incorrect
        sls_quantity,
        CASE
            WHEN sls_price IS NULL OR sls_price <= 0
                THEN ROUND(sls_sales / NULLIF(sls_quantity, 0), 2)
            ELSE sls_price
        END AS sls_price    -- Derive price if original value is invalid
    FROM bronze.crm_sales_details;
    v_end_time := clock_timestamp();
    RAISE INFO '>> Load Duration: %', (v_end_time - v_start_time);
    RAISE INFO '>> -------------';


    RAISE INFO '-------------------------------------------------------------------';
    RAISE INFO ' Loading ERP Tables';
    RAISE INFO '-------------------------------------------------------------------';   


    -- Table 4: erp_cust_az12
    v_start_time := clock_timestamp();
    RAISE INFO '>> Truncating Table: silver.erp_cust_az12';
    TRUNCATE TABLE silver.erp_cust_az12;
    RAISE INFO '>> Inserting Data Into: silver.erp_cust_az12';
    INSERT INTO silver.erp_cust_az12 (
        cid,
        bdate,
        gen
    )
    SELECT
        CASE
            WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LENGTH(cid))  -- Remove 'NAS' prefix if present
            ELSE cid
        END cid,
        CASE
            WHEN bdate > CURRENT_DATE THEN NULL
            ELSE bdate
        END AS bdate,   -- Set future birthdates to NULL
        CASE
            WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
            WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
            ELSE 'n/a'
        END AS gen  -- Normalize gender values and handle unknown cases
    FROM bronze.erp_cust_az12;
    v_end_time := clock_timestamp();
    RAISE INFO '>> Load Duration: %', (v_end_time - v_start_time);
    RAISE INFO '>> -------------';


    -- Table 5: erp_loc_a101
    v_start_time := clock_timestamp();
    RAISE INFO '>> Truncating Table: silver.erp_loc_a101';
    TRUNCATE TABLE silver.erp_loc_a101;
    RAISE INFO '>> Inserting Data Into: silver.erp_loc_a101';
    INSERT INTO silver.erp_loc_a101 (
        cid,
        cntry
    )
    SELECT
        REPLACE(cid, '-', '') cid,
        CASE
            WHEN TRIM(cntry) = 'DE' THEN 'Germany'
            WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
            WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
            ELSE TRIM(cntry)
        END AS cntry    -- Normalize and Handle missing or blank country codes
    FROM bronze.erp_loc_a101;
    v_end_time := clock_timestamp();
    RAISE INFO '>> Load Duration: %', (v_end_time - v_start_time);
    RAISE INFO '>> -------------';


    -- Table 6: erp_px_cat_g1v2
    v_start_time := clock_timestamp();
    RAISE INFO '>> Truncating Table: silver.erp_px_cat_g1v2';
    TRUNCATE TABLE silver.erp_px_cat_g1v2;
    RAISE INFO '>> Inserting Data Into: silver.erp_px_cat_g1v2';
    INSERT INTO silver.erp_px_cat_g1v2 (
        id,
        cat,
        subcat,
        maintenance
    )
    SELECT
        id,
        cat,
        subcat,
        maintenance
    FROM bronze.erp_px_cat_g1v2;
    v_end_time := clock_timestamp();
    RAISE INFO '>> Load Duration: %', (v_end_time - v_start_time);
    RAISE INFO '>> -------------';

    -- Total Load Duration
    v_batch_end_time := clock_timestamp();
    RAISE INFO '-------------------------------------------------------------------';
    RAISE INFO 'Silver Layer Loading Completed Successfully';
    RAISE INFO 'Total Load Duration: %', (v_batch_end_time - v_batch_start_time);
    RAISE INFO '-------------------------------------------------------------------';

-- Catch any exception thrown inside the procedure
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            v_error_message = MESSAGE_TEXT,
            v_error_state = RETURNED_SQLSTATE;
        RAISE INFO '===================================================================';
        RAISE INFO 'ERROR OCCURRED DURING LOADING SILVER LAYER';
        RAISE INFO 'Error Message: %', v_error_message;
        RAISE INFO 'Error State/Code: %', v_error_state;
END;
$$;

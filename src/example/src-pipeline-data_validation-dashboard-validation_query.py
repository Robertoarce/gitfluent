import validation_utils as utils 

def get_query(brand, data_table):
    if brand == "FLU":
        if data_table == "Touchpoint_Facts":
            sql = f"""(SELECT 'FR' AS COUNTRY_CODE,
                            A.CODE_ONEKEY AS INTERNAL_GEO_CODE,
                            'FLU' AS BRAND_NAME,
                            CAST(PERIOD_START AS DATETIME) AS PERIOD_START,
                            A.INTERNAL_CHANNEL_CODE AS INTERNAL_CHANNEL_CODE,
                            'vaxigrip_efluelda' AS BRAND_CODE,
                            CODE_ONEKEY AS SUB_NATIONAL_CODE,
                            'PHARMACY' AS SPECIALTY_CODE,
                            'BUYING_GROUP' AS SEGMENT_CODE,
                            BUYING_GROUP AS SEGMENT_VALUE,
                            A.CHANNEL_CODE,
                            'MONTH' AS FREQUENCY,
                            COALESCE(PDES,0) as VALUE
                            from (SELECT CODE_SAP, CODE_ONEKEY, HCO_ID, BUYING_GROUP,INTERNAL_CHANNEL_CODE,CHANNEL_CODE,
                            CASE
                            WHEN CONCAT(SUBSTRING(PERIOD_START, 1, 4),'-',SUBSTRING(PERIOD_START, 5, 2),'-01') IN ('2021-04-01','2021-05-01','2021-06-01','2021-07-01','2021-08-01','2021-09-01') THEN '2023-01-01'
                            WHEN CONCAT(SUBSTRING(PERIOD_START, 1, 4),'-',SUBSTRING(PERIOD_START, 5, 2),'-01') IN ('2021-10-01','2021-11-01','2021-12-01','2022-01-01','2022-02-01','2022-03-01') THEN '2023-02-01'
                            WHEN CONCAT(SUBSTRING(PERIOD_START, 1, 4),'-',SUBSTRING(PERIOD_START, 5, 2),'-01') IN ('2022-04-01','2022-05-01','2022-06-01','2022-07-01','2022-08-01','2022-09-01') THEN '2023-03-01'
                            ELSE '2023-04-01'
                            END AS PERIOD_START FROM
                            (select * from
                            (SELECT CODE_SAP, CODE_ONEKEY, HCO_ID, COALESCE(BUYING_GROUP,'No_Buying_Group') AS BUYING_GROUP
                            FROM (SELECT CODE_SAP, CODE_ONEKEY,
                            CONCAT('ID',HCO_ID) AS HCO_ID,
                            CASE
                            WHEN BUYING_GROUP_TYPE = '' THEN 'No_Buying_Group'
                            WHEN BUYING_GROUP_TYPE = 'Local/régional' THEN 'Local_Regional'
                            WHEN BUYING_GROUP_TYPE = 'Régional' THEN 'Regional'
                            ELSE BUYING_GROUP_TYPE
                            END AS BUYING_GROUP
                            FROM MMX_DEV.DWH_MMX.DWH_FLU_POTENTIAL
                            )
                            where (CODE_ONEKEY IS NOT NULL
                            AND CODE_ONEKEY<>'-')
                            ) A
                            CROSS JOIN
                            (select INTERNAL_CHANNEL_CODE,CHANNEL_CODE from
                            MMX_DEV.DWH_MMX.DWH_CHANNEL_MASTER
                            WHERE UPPER(channel_code) in ('F2F','PHO','REM')) B
                            CROSS JOIN
                            (SELECT DISTINCT cast(CONCAT(SUBSTRING(ORDER_CREATION_DATE, 1, 4),SUBSTRING(ORDER_CREATION_DATE, 6, 2)) as int) AS PERIOD_START
                            FROM MMX_DEV.DWH_MMX.DWH_FR_FLU_PREORDERS) C
                            WHERE PERIOD_START>=202104
                            AND PERIOD_START<=202303
                            ORDER BY 2,5)
                            GROUP BY 1,2,3,4,5,6,7
                            ORDER BY 1,2,3,4,5,6,7
                            ) A
                            left join
                            (SELECT COUNTRY_CODE, CHANNEL_CODE, HCO_ID,
                            CASE
                            WHEN CONCAT(SUBSTRING(TIME_PERIOD, 1, 4),'-',SUBSTRING(TIME_PERIOD, 5, 2),'-01') IN ('2021-04-01','2021-05-01','2021-06-01','2021-07-01','2021-08-01','2021-09-01') THEN '2023-01-01'
                            WHEN CONCAT(SUBSTRING(TIME_PERIOD, 1, 4),'-',SUBSTRING(TIME_PERIOD, 5, 2),'-01') IN ('2021-10-01','2021-11-01','2021-12-01','2022-01-01','2022-02-01','2022-03-01') THEN '2023-02-01'
                            WHEN CONCAT(SUBSTRING(TIME_PERIOD, 1, 4),'-',SUBSTRING(TIME_PERIOD, 5, 2),'-01') IN ('2022-04-01','2022-05-01','2022-06-01','2022-07-01','2022-08-01','2022-09-01') THEN '2023-03-01'
                            ELSE '2023-04-01'
                            END AS TIME_PERIOD,
                            SUM(PDES) AS PDES FROM
                            (
                            (SELECT COUNTRY_CODE, CHANNEL_CODE, HCO_ID, TIME_PERIOD, SUM(PDES) AS PDES
                            FROM
                            (SELECT COUNTRY_CODE, CHANNEL_CODE,
                            CONCAT('ID',PRESCRIBER_CODE) AS PRESCRIBER_CODE,
                            cast(CONCAT(SUBSTRING(PERIOD_START, 1, 4),SUBSTRING(PERIOD_START, 6, 2)) as int) AS TIME_PERIOD,
                            SUM(PDE_WEIGHTAGE) as PDES
                            FROM MMX_DEV.DWH_MMX.DWH_CHANNEL_FACTS
                            WHERE UPPER(COUNTRY_CODE) = 'FR'
                            AND (PRESCRIBER_CODE is not NULL or PRESCRIBER_CODE <> '')
                            AND UPPER(BRAND_NAME) in ('VAXIGRIP TETRA', 'EFLUELDA')
                            AND UPPER(CHANNEL_CODE) in ('F2F', 'PHO', 'REM')
                            AND UPPER(PRESCRIBER_TYPE) = 'HCP'
                            GROUP BY 1,2,3,4) A
                            LEFT JOIN
                            (SELECT distinct CONCAT('ID',HCP_CODE) AS PRESCRIBER_CODE,
                            CONCAT('ID',PRIMARY_HCO_CODE) AS HCO_ID
                            FROM MMX_DEV.DWH_MMX.DWH_HCP_MASTER
                            WHERE UPPER(COUNTRY_CODE) = 'FR'
                            and (HCP_CODE<>'-1' or PRIMARY_HCO_CODE<>'-1')
                            AND PRIMARY_HCO_CODE IS NOT NULL
                            AND HCP_CODE IS NOT NULL
                            GROUP BY 1,2) B
                            ON A.PRESCRIBER_CODE = B.PRESCRIBER_CODE
                            where (HCO_ID is not NULL or HCO_ID <> '')
                            group by 1,2,3,4
                            )
                            UNION ALL
                            (SELECT COUNTRY_CODE, CHANNEL_CODE,
                            CONCAT('ID',PRESCRIBER_CODE) AS HCO_ID,
                            cast(CONCAT(SUBSTRING(PERIOD_START, 1, 4),SUBSTRING(PERIOD_START, 6, 2)) as int) AS TIME_PERIOD,
                            SUM(PDE_WEIGHTAGE) as PDES
                            FROM MMX_DEV.DWH_MMX.DWH_CHANNEL_FACTS
                            WHERE UPPER(COUNTRY_CODE) = 'FR'
                            AND (PRESCRIBER_CODE is not NULL or PRESCRIBER_CODE <> '')
                            AND UPPER(BRAND_NAME) in ('VAXIGRIP TETRA', 'EFLUELDA')
                            AND UPPER(CHANNEL_CODE) in ('F2F', 'PHO', 'REM')
                            AND UPPER(PRESCRIBER_TYPE) = 'HCO'
                            GROUP BY 1,2,3,4)
                            )
                            GROUP BY 1,2,3,4
                            ORDER BY 1,2,3,4) B
                            ON A.HCO_ID = B.HCO_ID
                            AND A.PERIOD_START = B.TIME_PERIOD
                            AND A.CHANNEL_CODE = B.CHANNEL_CODE)
                            UNION
                            (SELECT 'FR' AS COUNTRY_CODE, A.CODE_ONEKEY AS INTERNAL_GEO_CODE,'FLU' AS BRAND_NAME,
                            CAST(PERIOD_START AS DATETIME) AS PERIOD_START, A.INTERNAL_CHANNEL_CODE AS INTERNAL_CHANNEL_CODE,
                            'vaxigrip_efluelda' AS BRAND_CODE, CODE_ONEKEY AS SUB_NATIONAL_CODE,
                            'PHARMACY' AS SPECIALTY_CODE, 'BUYING_GROUP' AS SEGMENT_CODE,
                            BUYING_GROUP AS SEGMENT_VALUE, A.CHANNEL_CODE,
                            'MONTH' AS FREQUENCY,
                            COALESCE(METRIC_VALUES,0) as VALUE
                            FROM 
                            (
                            SELECT CODE_SAP, CODE_ONEKEY, HCO_ID, BUYING_GROUP,INTERNAL_CHANNEL_CODE,CHANNEL_CODE,
                            CASE
                            WHEN CONCAT(SUBSTRING(PERIOD_START, 1, 4),'-',SUBSTRING(PERIOD_START, 5, 2),'-01') IN ('2021-04-01','2021-05-01','2021-06-01','2021-07-01','2021-08-01','2021-09-01') THEN '2023-01-01'
                            WHEN CONCAT(SUBSTRING(PERIOD_START, 1, 4),'-',SUBSTRING(PERIOD_START, 5, 2),'-01') IN ('2021-10-01','2021-11-01','2021-12-01','2022-01-01','2022-02-01','2022-03-01') THEN '2023-02-01'
                            WHEN CONCAT(SUBSTRING(PERIOD_START, 1, 4),'-',SUBSTRING(PERIOD_START, 5, 2),'-01') IN ('2022-04-01','2022-05-01','2022-06-01','2022-07-01','2022-08-01','2022-09-01') THEN '2023-03-01'
                            ELSE '2023-04-01'
                            END AS PERIOD_START FROM
                            (
                            select * from
                            (SELECT CODE_SAP, CODE_ONEKEY, HCO_ID, COALESCE(BUYING_GROUP,'No_Buying_Group') AS BUYING_GROUP
                            FROM (SELECT CODE_SAP, CODE_ONEKEY,
                            CONCAT('ID',HCO_ID) AS HCO_ID,
                            CASE
                            WHEN BUYING_GROUP_TYPE = '' THEN 'No_Buying_Group'
                            WHEN BUYING_GROUP_TYPE = 'Local/régional' THEN 'Local_Regional'
                            WHEN BUYING_GROUP_TYPE = 'Régional' THEN 'Regional'
                            ELSE BUYING_GROUP_TYPE
                            END AS BUYING_GROUP
                            FROM MMX_DEV.DWH_MMX.DWH_FLU_POTENTIAL
                            )
                            where (CODE_ONEKEY IS NOT NULL
                            AND CODE_ONEKEY<>'-')
                            ) A
                            CROSS JOIN
                            (select INTERNAL_CHANNEL_CODE,CHANNEL_CODE from
                            MMX_DEV.DWH_MMX.DWH_CHANNEL_MASTER
                            WHERE UPPER(channel_code) in ('RTE','HQE')) B
                            CROSS JOIN
                            (SELECT DISTINCT cast(CONCAT(SUBSTRING(ORDER_CREATION_DATE, 1, 4),SUBSTRING(ORDER_CREATION_DATE, 6, 2)) as int) AS PERIOD_START
                            FROM MMX_DEV.DWH_MMX.DWH_FR_FLU_PREORDERS) C
                            WHERE PERIOD_START>=202104
                            AND PERIOD_START<=202303
                            ORDER BY 2,5
                            )
                            GROUP BY 1,2,3,4,5,6,7
                            ORDER BY 1,2,3,4,5,6,7
                            ) A
                            left join
                            (
                            SELECT COUNTRY_CODE, CHANNEL_CODE, HCO_ID,
                            CASE
                            WHEN CONCAT(SUBSTRING(TIME_PERIOD, 1, 4),'-',SUBSTRING(TIME_PERIOD, 5, 2),'-01') IN ('2021-04-01','2021-05-01','2021-06-01','2021-07-01','2021-08-01','2021-09-01') THEN '2023-01-01'
                            WHEN CONCAT(SUBSTRING(TIME_PERIOD, 1, 4),'-',SUBSTRING(TIME_PERIOD, 5, 2),'-01') IN ('2021-10-01','2021-11-01','2021-12-01','2022-01-01','2022-02-01','2022-03-01') THEN '2023-02-01'
                            WHEN CONCAT(SUBSTRING(TIME_PERIOD, 1, 4),'-',SUBSTRING(TIME_PERIOD, 5, 2),'-01') IN ('2022-04-01','2022-05-01','2022-06-01','2022-07-01','2022-08-01','2022-09-01') THEN '2023-03-01'
                            ELSE '2023-04-01'
                            END AS TIME_PERIOD,
                            SUM(METRIC_VALUES) AS METRIC_VALUES FROM
                            (
                            (SELECT COUNTRY_CODE, CHANNEL_CODE, HCO_ID, TIME_PERIOD, SUM(METRIC_VALUES) AS
                            METRIC_VALUES
                            FROM
                            (SELECT COUNTRY_CODE, CHANNEL_CODE,
                            CONCAT('ID',PRESCRIBER_CODE) AS PRESCRIBER_CODE,
                            cast(CONCAT(SUBSTRING(PERIOD_START, 1, 4),SUBSTRING(PERIOD_START, 6, 2)) as int) AS TIME_PERIOD,
                            SUM(METRIC_VALUE) AS METRIC_VALUES
                            FROM MMX_DEV.DWH_MMX.DWH_CHANNEL_EMAIL_FACTS
                            WHERE UPPER(COUNTRY_CODE) = 'FR'
                            AND UPPER(METRIC_NAME) in ('OPENED')
                            AND (PRESCRIBER_CODE is not NULL or PRESCRIBER_CODE <> '')
                            AND UPPER(BRAND_NAME) in ('VAXIGRIP TETRA', 'EFLUELDA')
                            AND UPPER(CHANNEL_CODE) in ('RTE', 'HQE')
                            AND UPPER(PRESCRIBER_TYPE) = 'HCP'
                            GROUP BY 1,2,3,4) A
                            LEFT JOIN
                            (SELECT distinct CONCAT('ID',HCP_CODE) AS PRESCRIBER_CODE,
                            CONCAT('ID',PRIMARY_HCO_CODE) AS HCO_ID
                            FROM MMX_DEV.DWH_MMX.DWH_HCP_MASTER
                            WHERE UPPER(COUNTRY_CODE) = 'FR'
                            and (HCP_CODE<>'-1' or PRIMARY_HCO_CODE<>'-1')
                            AND PRIMARY_HCO_CODE IS NOT NULL
                            AND HCP_CODE IS NOT NULL
                            GROUP BY 1,2) B
                            ON A.PRESCRIBER_CODE = B.PRESCRIBER_CODE
                            where (HCO_ID is not NULL or HCO_ID <> '')
                            group by 1,2,3,4
                            )
                            UNION ALL
                            (SELECT COUNTRY_CODE, CHANNEL_CODE,
                            CONCAT('ID',PRESCRIBER_CODE) AS HCO_ID,
                            cast(CONCAT(SUBSTRING(PERIOD_START, 1, 4),SUBSTRING(PERIOD_START, 6, 2)) as int) AS TIME_PERIOD,
                            SUM(METRIC_VALUE) AS METRIC_VALUES
                            FROM MMX_DEV.DWH_MMX.DWH_CHANNEL_EMAIL_FACTS
                            WHERE UPPER(COUNTRY_CODE) = 'FR'
                            AND (PRESCRIBER_CODE is not NULL or PRESCRIBER_CODE <> '')
                            AND UPPER(BRAND_NAME) in ('VAXIGRIP TETRA', 'EFLUELDA')
                            AND UPPER(CHANNEL_CODE) in ('RTE', 'HQE')
                            AND UPPER(PRESCRIBER_TYPE) = 'HCO'
                            GROUP BY 1,2,3,4)
                            )
                            GROUP BY 1,2,3,4
                            ORDER BY 1,2,3,4
                            ) B
                            ON A.HCO_ID = B.HCO_ID
                            AND A.PERIOD_START = B.TIME_PERIOD
                            AND A.CHANNEL_CODE = B.CHANNEL_CODE);"""

        elif data_table == 'Sell_Out_Own':
            sql = """(SELECT CODE_ONEKEY as INTERNAL_GEO_CODE,
                            A.PERIOD_START as PERIOD_START,
                            'MONTH' AS FREQUENCY,
                            COALESCE(VALUE,0) AS VALUE,
                            'EUR' AS CURRENCY,
                            'vaxigrip_efluelda' AS BRAND_CODE,
                            'FLU' AS BRAND_NAME,
                            'PHARMACY' AS SPECIALTY_CODE,
                            'BUYING_GROUP' AS SEGMENT_CODE,
                            BUYING_GROUP AS SEGMENT_VALUE,
                            'vaxigrip_efluelda_sales' AS SALES_CHANNEL_CODE,
                            COALESCE(VOLUME,0) AS VOLUME
                            FROM
                            (SELECT CODE_SAP, CODE_ONEKEY, HCO_ID, BUYING_GROUP,
                            CASE
                            WHEN CONCAT(SUBSTRING(PERIOD_START, 1, 4),'-',SUBSTRING(PERIOD_START, 5, 2),'-01') IN ('2021-04-01','2021-05-01','2021-06-01','2021-07-01','2021-08-01','2021-09-01') THEN '2023-01-01'
                            WHEN CONCAT(SUBSTRING(PERIOD_START, 1, 4),'-',SUBSTRING(PERIOD_START, 5, 2),'-01') IN ('2021-10-01','2021-11-01','2021-12-01','2022-01-01','2022-02-01','2022-03-01') THEN '2023-02-01'
                            WHEN CONCAT(SUBSTRING(PERIOD_START, 1, 4),'-',SUBSTRING(PERIOD_START, 5, 2),'-01') IN ('2022-04-01','2022-05-01','2022-06-01','2022-07-01','2022-08-01','2022-09-01') THEN '2023-03-01'
                            ELSE '2023-04-01'
                            END AS PERIOD_START FROM
                            (select * from
                            (
                            (SELECT CODE_SAP, CODE_ONEKEY, HCO_ID, COALESCE(BUYING_GROUP,'No_Buying_Group') AS BUYING_GROUP
                            FROM (SELECT CODE_SAP, CODE_ONEKEY,
                            CONCAT('ID',HCO_ID) AS HCO_ID,
                            CASE
                            WHEN BUYING_GROUP_TYPE = '' THEN 'No_Buying_Group'
                            WHEN BUYING_GROUP_TYPE = 'Local/régional' THEN 'Local_Regional'
                            WHEN BUYING_GROUP_TYPE = 'Régional' THEN 'Regional'
                            ELSE BUYING_GROUP_TYPE
                            END AS BUYING_GROUP
                            FROM MMX_DEV.DWH_MMX.DWH_FLU_POTENTIAL
                            )
                            where (CODE_ONEKEY IS NOT NULL
                            AND CODE_ONEKEY<>'-')
                            ) A
                            CROSS JOIN
                            (SELECT DISTINCT cast(CONCAT(SUBSTRING(ORDER_CREATION_DATE, 1, 4),SUBSTRING(ORDER_CREATION_DATE, 6, 2)) as int) AS PERIOD_START
                            FROM MMX_DEV.DWH_MMX.DWH_FR_FLU_PREORDERS) B)
                            WHERE PERIOD_START>=202104
                            AND PERIOD_START<=202303
                            ORDER BY 2,5)
                            GROUP BY 1,2,3,4,5
                            ORDER BY 1,2,3,4,5
                            ) A
                            left join
                            (SELECT
                            SOLD_TO_CUSTOMER,
                            CASE
                            WHEN CONCAT(SUBSTRING(PERIOD_START, 1, 4),'-',SUBSTRING(PERIOD_START, 5, 2),'-01') IN ('2021-04-01','2021-05-01','2021-06-01','2021-07-01','2021-08-01','2021-09-01') THEN '2023-01-01'
                            WHEN CONCAT(SUBSTRING(PERIOD_START, 1, 4),'-',SUBSTRING(PERIOD_START, 5, 2),'-01') IN ('2021-10-01','2021-11-01','2021-12-01','2022-01-01','2022-02-01','2022-03-01') THEN '2023-02-01'
                            WHEN CONCAT(SUBSTRING(PERIOD_START, 1, 4),'-',SUBSTRING(PERIOD_START, 5, 2),'-01') IN ('2022-04-01','2022-05-01','2022-06-01','2022-07-01','2022-08-01','2022-09-01') THEN '2023-03-01'
                            ELSE '2023-04-01'
                            END AS PERIOD_START,
                            SUM(COALESCE(VALUE,0)) AS VALUE,
                            SUM(COALESCE(VOLUME,0)) AS VOLUME FROM
                            (SELECT cast(REPLACE(LTRIM(REPLACE(SOLD_TO_CUSTOMER, '0', ' ')), ' ', '0') as int) as SOLD_TO_CUSTOMER,
                            cast(CONCAT(SUBSTRING(ORDER_CREATION_DATE, 1, 4),SUBSTRING(ORDER_CREATION_DATE, 6, 2)) as int) AS PERIOD_START,
                            SUM(COALESCE(NET_PRICE,0)) AS VALUE,
                            SUM(COALESCE(ORDERED_QUANTITY,0)) AS VOLUME
                            FROM MMX_DEV.DWH_MMX.DWH_FR_FLU_PREORDERS
                            where UPPER(COUNTRY_ISO_CD) = 'FR'
                            and cast(CONCAT(SUBSTRING(ORDER_CREATION_DATE, 1, 4),SUBSTRING(ORDER_CREATION_DATE, 6, 2)) as int)>=202104
                            and cast(CONCAT(SUBSTRING(ORDER_CREATION_DATE, 1, 4),SUBSTRING(ORDER_CREATION_DATE, 6, 2)) as int)<=202303
                            GROUP BY 1,2)
                            GROUP BY 1,2
                            ORDER BY 1,2
                            ) B
                            ON A.CODE_SAP = B.SOLD_TO_CUSTOMER
                            AND A.PERIOD_START = B.PERIOD_START);"""
    return sql


def get_query_tables(tab_source, market, brand_list, start_period, end_period):

    if tab_source == 'tab1':
        sql = f"""
        SELECT SEGMENT_CODE,SEGMENT_VALUE,BRAND_NAME,COALESCE(SENT_HQE,0) as SENT_HQE,COALESCE(SENT_RTE,0) as SENT_RTE,COALESCE(OPENED_HQE,0) as OPENED_HQE,COALESCE(OPENED_RTE,0) as OPENED_RTE,COALESCE(ATTENDED_EVV,0) AS ATTENDED_EVV,
        COALESCE(ATTENDED_HQV,0) AS ATTENDED_HQV,COALESCE(ATTENDED_HQF,0) AS ATTENDED_HQF,COALESCE(ATTENDED_EVF,0) AS ATTENDED_EVF,COALESCE(PDE_PHO,0) AS PDE_PHO,COALESCE(PDE_F2F,0) AS PDE_F2F,COALESCE(PDE_REM, 0) AS PDE_REM 
        FROM
        (WITH PROMOTIONS AS 
        ((SELECT  B.SEGMENT_CODE,B.SEGMENT_VALUE,A.CHANNEL_CODE,A.BRAND_NAME,SUM(METRIC_VALUE) AS METRIC_VALUE FROM "MMX_DEV"."DWH_MMX"."DWH_SEGMENT_MASTER" B  
        LEFT JOIN (SELECT PRESCRIBER_CODE,BRAND_NAME,CONCAT(METRIC_NAME,'_',CHANNEL_CODE) AS CHANNEL_CODE,SUM(METRIC_VALUE) AS METRIC_VALUE FROM "MMX_DEV"."DWH_MMX"."DWH_CHANNEL_EMAIL_FACTS" WHERE COUNTRY_CODE='{market}' AND PRESCRIBER_TYPE='HCP' AND PERIOD_START BETWEEN '{start_period}' AND '{end_period}' 
                GROUP BY 1,2,3)A
        ON A.PRESCRIBER_CODE=B.HCP_CODE AND A.BRAND_NAME=B.BRAND_NAME
        WHERE CHANNEL_CODE IS NOT NULL 
        GROUP BY 1,2,3,4)
        UNION ALL
        (SELECT  B.SEGMENT_CODE,B.SEGMENT_VALUE,A.CHANNEL_CODE,A.BRAND_NAME,SUM(METRIC_VALUE) AS METRIC_VALUE FROM "MMX_DEV"."DWH_MMX"."DWH_SEGMENT_MASTER" B  
        LEFT JOIN (SELECT PRESCRIBER_CODE,BRAND_NAME,CONCAT(METRIC_NAME,'_',CHANNEL_CODE) AS CHANNEL_CODE,SUM(METRIC_VALUE) AS METRIC_VALUE FROM "MMX_DEV"."DWH_MMX"."DWH_CHANNEL_EVENTS_FACTS" WHERE COUNTRY_CODE='{market}' AND PRESCRIBER_TYPE='HCP' AND PERIOD_START BETWEEN '{start_period}' AND '{end_period}'
                GROUP BY 1,2,3)A
        ON A.PRESCRIBER_CODE=B.HCP_CODE AND A.BRAND_NAME=B.BRAND_NAME
        WHERE  CHANNEL_CODE IS NOT NULL
        GROUP BY 1,2,3,4)
        UNION ALL
        (SELECT  B.SEGMENT_CODE,B.SEGMENT_VALUE,A.CHANNEL_CODE,A.BRAND_NAME,SUM(METRIC_VALUE) AS METRIC_VALUE FROM "MMX_DEV"."DWH_MMX"."DWH_SEGMENT_MASTER" B  
        LEFT JOIN (SELECT PRESCRIBER_CODE,BRAND_NAME,CONCAT('PDE','_',CHANNEL_CODE) AS CHANNEL_CODE,SUM(PDE_WEIGHTAGE) AS METRIC_VALUE FROM "MMX_DEV"."DWH_MMX"."DWH_CHANNEL_FACTS" WHERE COUNTRY_CODE='{market}' AND PERIOD_START BETWEEN '{start_period}' AND '{end_period}' GROUP BY 1,2,3)A
        ON A.PRESCRIBER_CODE=B.HCP_CODE AND A.BRAND_NAME=B.BRAND_NAME
        WHERE  CHANNEL_CODE IS NOT NULL
        GROUP BY 1,2,3,4))

        SELECT SEGMENT_CODE,SEGMENT_VALUE,BRAND_NAME,"'SENT_HQE'" AS SENT_HQE,"'SENT_RTE'" AS SENT_RTE,"'OPENED_HQE'" AS OPENED_HQE,"'OPENED_RTE'" AS OPENED_RTE
        ,"'ATTENDED_EVV'" AS ATTENDED_EVV,"'ATTENDED_HQV'" AS ATTENDED_HQV,"'ATTENDED_HQF'" AS ATTENDED_HQF,"'ATTENDED_EVF'" AS ATTENDED_EVF,"'PDE_PHO'" AS PDE_PHO,"'PDE_F2F'" AS PDE_F2F,"'PDE_REM'" AS PDE_REM
        FROM PROMOTIONS
        PIVOT
        (
        SUM(METRIC_VALUE) FOR CHANNEL_CODE IN ('SENT_HQE','SENT_RTE','OPENED_HQE','OPENED_RTE','ATTENDED_EVV','ATTENDED_HQV','ATTENDED_HQF','ATTENDED_EVF','PDE_PHO','PDE_F2F','PDE_REM')
        
        )AS PIVOT_TABLE
        WHERE BRAND_NAME IN ({brand_list})
        ORDER BY 3 DESC,1,2);
        """

    elif tab_source == "tab2":

        sql = f"""
        SELECT A.SEGMENT_CODE,A.SEGMENT_VALUE,A.BRAND_NAME,B.SEG_MASTER_HCP_CODE,COALESCE(SENT_HQE,0) as SENT_HQE,COALESCE(SENT_RTE,0) as SENT_RTE,COALESCE(OPENED_HQE,0) as OPENED_HQE,COALESCE(OPENED_RTE,0) as OPENED_RTE,COALESCE(ATTENDED_EVV,0) AS ATTENDED_EVV,
        COALESCE(ATTENDED_HQV,0) AS ATTENDED_HQV,COALESCE(ATTENDED_HQF,0) AS ATTENDED_HQF,COALESCE(ATTENDED_EVF,0) AS ATTENDED_EVF,COALESCE(PDE_PHO,0) AS PDE_PHO,COALESCE(PDE_F2F,0) AS PDE_F2F,COALESCE(PDE_REM, 0) AS PDE_REM 
        FROM
        (WITH HCPS AS 
        ((SELECT  B.SEGMENT_CODE,B.SEGMENT_VALUE,A.CHANNEL_CODE,A.BRAND_NAME,COUNT(DISTINCT PRESCRIBER_CODE) AS PRESCRIBER_CODE FROM "MMX_DEV"."DWH_MMX"."DWH_SEGMENT_MASTER" B  
        LEFT JOIN (SELECT PRESCRIBER_CODE,BRAND_NAME,CONCAT(METRIC_NAME,'_',CHANNEL_CODE) AS CHANNEL_CODE,SUM(METRIC_VALUE) AS METRIC_VALUE FROM "MMX_DEV"."DWH_MMX"."DWH_CHANNEL_EMAIL_FACTS" 
                WHERE COUNTRY_CODE='{market}' AND PRESCRIBER_TYPE='HCP' 
                AND METRIC_VALUE>0 AND PERIOD_START BETWEEN '{start_period}' AND '{end_period}'
                GROUP BY 1,2,3)A
        ON A.PRESCRIBER_CODE=B.HCP_CODE AND A.BRAND_NAME=B.BRAND_NAME
        WHERE CHANNEL_CODE IS NOT NULL 
        GROUP BY 1,2,3,4)
        UNION ALL
        (SELECT  B.SEGMENT_CODE,B.SEGMENT_VALUE,A.CHANNEL_CODE,A.BRAND_NAME,COUNT(DISTINCT PRESCRIBER_CODE) AS PRESCRIBER_CODE FROM "MMX_DEV"."DWH_MMX"."DWH_SEGMENT_MASTER" B  
        LEFT JOIN (SELECT PRESCRIBER_CODE,BRAND_NAME,CONCAT(METRIC_NAME,'_',CHANNEL_CODE) AS CHANNEL_CODE,SUM(METRIC_VALUE) AS METRIC_VALUE FROM "MMX_DEV"."DWH_MMX"."DWH_CHANNEL_EVENTS_FACTS" 
                WHERE COUNTRY_CODE='{market}' AND PRESCRIBER_TYPE='HCP' 
                AND METRIC_VALUE>0 AND PERIOD_START BETWEEN '{start_period}' AND '{end_period}'
                GROUP BY 1,2,3)A
        ON A.PRESCRIBER_CODE=B.HCP_CODE AND A.BRAND_NAME=B.BRAND_NAME
        WHERE  CHANNEL_CODE IS NOT NULL
        GROUP BY 1,2,3,4)
        UNION ALL
        (SELECT  B.SEGMENT_CODE,B.SEGMENT_VALUE,A.CHANNEL_CODE,A.BRAND_NAME,COUNT(DISTINCT PRESCRIBER_CODE) AS PRESCRIBER_CODE FROM "MMX_DEV"."DWH_MMX"."DWH_SEGMENT_MASTER" B  
        LEFT JOIN (SELECT PRESCRIBER_CODE,BRAND_NAME,CONCAT('PDE','_',CHANNEL_CODE) AS CHANNEL_CODE,SUM(PDE_WEIGHTAGE) AS METRIC_VALUE FROM "MMX_DEV"."DWH_MMX"."DWH_CHANNEL_FACTS" 
                WHERE COUNTRY_CODE='{market}'
                AND PDE_WEIGHTAGE>0 AND PERIOD_START BETWEEN '{start_period}' AND '{end_period}'
                GROUP BY 1,2,3)A
        ON A.PRESCRIBER_CODE=B.HCP_CODE AND A.BRAND_NAME=B.BRAND_NAME
        WHERE  CHANNEL_CODE IS NOT NULL
        GROUP BY 1,2,3,4))

        SELECT SEGMENT_CODE,SEGMENT_VALUE,BRAND_NAME,"'SENT_HQE'" AS SENT_HQE,"'SENT_RTE'" AS SENT_RTE,"'OPENED_HQE'" AS OPENED_HQE,"'OPENED_RTE'" AS OPENED_RTE
        ,"'ATTENDED_EVV'" AS ATTENDED_EVV,"'ATTENDED_HQV'" AS ATTENDED_HQV,"'ATTENDED_HQF'" AS ATTENDED_HQF,"'ATTENDED_EVF'" AS ATTENDED_EVF,"'PDE_PHO'" AS PDE_PHO,"'PDE_F2F'" AS PDE_F2F,"'PDE_REM'" AS PDE_REM
        FROM HCPS
        PIVOT
        (
        SUM(PRESCRIBER_CODE) FOR CHANNEL_CODE IN ('SENT_HQE','SENT_RTE','OPENED_HQE','OPENED_RTE','ATTENDED_EVV','ATTENDED_HQV','ATTENDED_HQF','ATTENDED_EVF','PDE_PHO','PDE_F2F','PDE_REM')
        
        )AS PIVOT_TABLE
        WHERE BRAND_NAME IN ({brand_list})
        ORDER BY 3 DESC,1,2) A
        LEFT JOIN 
        (SELECT SEGMENT_CODE,SEGMENT_VALUE,BRAND_NAME,COUNT(DISTINCT HCP_CODE) AS SEG_MASTER_HCP_CODE 
        FROM "MMX_DEV"."DWH_MMX"."DWH_SEGMENT_MASTER" 
        WHERE BRAND_NAME IN ({brand_list})
        GROUP BY 1,2,3) B ON A.SEGMENT_CODE=B.SEGMENT_CODE AND A.SEGMENT_VALUE=B.SEGMENT_VALUE AND A.BRAND_NAME=B.BRAND_NAME;
        """
    return sql


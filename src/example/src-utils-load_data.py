"""
Created By  : MMX DS Team (Jeeyoung, Dipkumar, Youssef)
Created Date: 16/01/2023
Description : Functions for Loading data from MMX SnowFlake
"""
from src.utils.config import load_config
from src.utils.snowflake_utils import mmx_snowflake_connection, read_table_pandas

dict_params = load_config(common=True)


def get_snowflake_business_priority_table():
    """
    Get the Business Priority Data .
    :return: Pandas dataframe
    :rtype: Pandas dataframe
    """
    try:
        conn = mmx_snowflake_connection()
        query = (
            f"SELECT * FROM {dict_params['INPUT_SCHEMA']}.{dict_params['DWH_BUSINESS_PRIORITY']}"
        )
        busin_prio_df = read_table_pandas(conn, query)
    finally:
        conn.close()
    return busin_prio_df


def get_snowflake_campaign_master_table():
    """
    Get the Campaign Master  Data .
    :return: Pandas dataframe
    :rtype: Pandas dataframe
    """
    try:
        conn = mmx_snowflake_connection()
        query = f"SELECT * FROM {dict_params['INPUT_SCHEMA']}.{dict_params['DWH_CAMPAIGN_MASTER']}"
        camp_master_df = read_table_pandas(conn, query)
    finally:
        conn.close()
    return camp_master_df


def get_snowflake_channel_master_table():
    """
    Get the Channel Master  Data .
    :return: Pandas dataframe
    :rtype: Pandas dataframe
    """
    try:
        conn = mmx_snowflake_connection()
        query = f"SELECT * FROM {dict_params['INPUT_SCHEMA']}.{dict_params['DWH_CHANNEL_MASTER']}"
        camp_channel_df = read_table_pandas(conn, query)
    finally:
        conn.close()
    return camp_channel_df


def get_snowflake_currency_exchange_table():
    """
    Get the ChaCurrency Exchange  Data .
    :return: Pandas dataframe
    :rtype: Pandas dataframe
    """
    try:
        conn = mmx_snowflake_connection()
        query = (
            f"SELECT * FROM {dict_params['INPUT_SCHEMA']}."
            f"{dict_params['DWH_CURRENCY_EXCHANGE_RATE']}"
        )
        curr_exch_df = read_table_pandas(conn, query)
    finally:
        conn.close()
    return curr_exch_df


def get_snowflake_sell_out_competitors_table():
    """
    Get the Sell out Competitors Data .
    :return: Pandas dataframe
    :rtype: Pandas dataframe
    """
    try:
        conn = mmx_snowflake_connection()
        query = (
            f"SELECT * FROM {dict_params['INPUT_SCHEMA']}."
            f"{dict_params['DWH_SELL_OUT_COMPETITORS']}"
        )
        sell_out_compe_df = read_table_pandas(conn, query)
    finally:
        conn.close()
    return sell_out_compe_df


def get_snowflake_sell_out_table():
    """
    Get the Sell out Data .
    :return: Pandas dataframe
    :rtype: Pandas dataframe
    """
    try:
        conn = mmx_snowflake_connection()
        query = (f"SELECT * FROM {dict_params['INPUT_SCHEMA']}."
                f"{dict_params['DWH_SELL_OUT_OWN']}")
        sell_out_df = read_table_pandas(conn, query)
    finally:
        conn.close()
    return sell_out_df


def get_snowflake_touchpoint_master_table():
    """
    Get the Touchpoint Master Data .
    :return: Pandas dataframe
    :rtype: Pandas dataframe
    """
    try:
        conn = mmx_snowflake_connection()
        query = (
            f"SELECT * FROM {dict_params['INPUT_SCHEMA']}."
            f"{dict_params['DWH_TOUCHPOINT_MASTER']}"
        )
        touchpoint_master_df = read_table_pandas(conn, query)
    finally:
        conn.close()
    return touchpoint_master_df


def get_snowflake_distribution_own_table():
    """
    Get the Distribution  Data .
    :return: Pandas dataframe
    :rtype: Pandas dataframe
    """
    try:
        conn = mmx_snowflake_connection()
        query = (f"SELECT * FROM {dict_params['INPUT_SCHEMA']}."
                f"{dict_params['DWH_DISTRIBUTION_OWN']}")
        dist_own_df = read_table_pandas(conn, query)
    finally:
        conn.close()
    return dist_own_df


def get_snowflake_external_fatcs_table():
    """
    Get the External Facts Data .
    :return: Pandas dataframe
    :rtype: Pandas dataframe
    """
    try:
        conn = mmx_snowflake_connection()
        query = (f"SELECT * FROM {dict_params['INPUT_SCHEMA']}."
                f"{dict_params['DWH_EXTERNAL_FACTS']}")
        external_facts_df = read_table_pandas(conn, query)
    finally:
        conn.close()
    return external_facts_df


def get_snowflake_product_master_table():
    """
    Get the Product Master Data .
    :return: Pandas dataframe
    :rtype: Pandas dataframe
    """
    try:
        conn = mmx_snowflake_connection()
        query = (f"SELECT * FROM {dict_params['INPUT_SCHEMA']}."
                f"{dict_params['DWH_PRODUCT_MASTER']}")
        product_master_df = read_table_pandas(conn, query)
    finally:
        conn.close()
    return product_master_df


def get_snowflake_distribution_competitors_table():
    """
    Get the Distribution Competitors Data .
    :return: Pandas dataframe
    :rtype: Pandas dataframe
    """
    try:
        conn = mmx_snowflake_connection()
        query = (f"SELECT * FROM {dict_params['INPUT_SCHEMA']}."
                f"{dict_params['DWH_DISTRIBUTION_COMPETITORS']}")
        distribution_competitors_df = read_table_pandas(conn, query)
    finally:
        conn.close()
    return distribution_competitors_df


def get_snowflake_finance_fatcs_table():
    """
    Get the Finance Data .
    :return: Pandas dataframe
    :rtype: Pandas dataframe
    """
    try:
        conn = mmx_snowflake_connection()
        query = (f"SELECT * FROM {dict_params['INPUT_SCHEMA']}."
                f"{dict_params['DWH_FINANCE_FACTS']}")
        fin_facts_df = read_table_pandas(conn, query)
    finally:
        conn.close()
    return fin_facts_df


def get_snowflake_geo_master_table():
    """
    Get the Geo Master Data .
    :return: Pandas dataframe
    :rtype: Pandas dataframe
    """
    try:
        conn = mmx_snowflake_connection()
        query = (f"SELECT * FROM {dict_params['INPUT_SCHEMA']}."
                f"{dict_params['DWH_GEO_MASTER']}")
        geo_master_df = read_table_pandas(conn, query)
    finally:
        conn.close()
    return geo_master_df


def get_snowflake_sales_forecast_table():
    """
    Get the Sales Forecast  Data .
    :return: Pandas dataframe
    :rtype: Pandas dataframe
    """
    try:
        conn = mmx_snowflake_connection()
        query = (f"SELECT * FROM {dict_params['INPUT_SCHEMA']}."
                f"{dict_params['DWH_SALES_FORECAST']} ")
        sales_forecast_df = read_table_pandas(conn, query)
    finally:
        conn.close()
    return sales_forecast_df


def get_snowflake_touchpoint_facts_table():
    """
    Get the Touchpoint Facts Data .
    :return: Pandas dataframe
    :rtype: Pandas dataframe
    """
    try:
        conn = mmx_snowflake_connection()
        query = (f"SELECT * FROM {dict_params['INPUT_SCHEMA']}."
                f"{dict_params['DWH_TOUCHPOINT_FACTS']} ")
        touchpoint_facts_df = read_table_pandas(conn, query)
    finally:
        conn.close()
    return touchpoint_facts_df


def get_snowflake_prescription_own_table():
    """
    Get the Prescription Own Data .
    :return: Pandas dataframe
    :rtype: Pandas dataframe
    """
    try:
        conn = mmx_snowflake_connection()
        query = (
            f"SELECT * FROM {dict_params['INPUT_SCHEMA']}."
            f"{dict_params['DWH_PRESCRIPTION_OWN']}"
        )
        prescription_own_df = read_table_pandas(conn, query)
    finally:
        conn.close()
    return prescription_own_df

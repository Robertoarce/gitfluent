import os
import streamlit as st 
from streamlit_elements import elements, mui, html, sync,editor, lazy,nivo
import numpy as np
import pandas as pd
from pandas.api.types import (
    is_categorical_dtype,
    is_datetime64_any_dtype,
    is_numeric_dtype,
    is_object_dtype)

import plotly.express as px 
import snowflake.connector
from sqlalchemy import create_engine
from datetime import datetime
import warnings
warnings.simplefilter(action='ignore', category=FutureWarning)

import sys
sys.path.insert(0, '..')
import validation_utils as utils
import validation_query as query

# Change box color
utils.set_box()

# check password
st.image("logo.png", width = 160)
if not utils.check_password():
    st.stop()

##############################################################################
## TITLE
##############################################################################
st.markdown(f'**<p style="color:#5500a1;font-size:30px;"> :bar_chart: RC | Data Source Validations </p>**', unsafe_allow_html=True)
st.markdown(f"""
The Response Curve input anlaysis is displayed on this page, with two sections below:
- **I. Raw & Filtered Data Overview**: An overview of raw (or filtered) data that includes basic analysis, statistics, and distribution of data source.
- **II. Specialty & Segment Distributions**: The DWH_HCP_MASTER, DWH_SEGMENT_MASTER, DWH_CHANNEL_MASTER are merged.  
  - DWH_SELL_OUT_OWN: The *MMX_DEV.DMT_MMX.SALES_ALLOCATION* is the source of the analysis if the version code is available. 
""")
st.markdown("""
- Remark 1. Ensure that all options are selected.
- Remark 2. During data updates in Snowflake, the dashboard may not contain the data. 
""")


st.divider()


##############################################################################
## OPTIONS 
##############################################################################
st.markdown(f'**<p style="color:#7A00E6;font-size:20px;"> 1. Please Select the Environment. </p>**', unsafe_allow_html=True)
source = st.radio("[Step 1.] Snowflake Environment:", ('DEV', 'UAT',), )

st.markdown(f'**<p style="color:#7A00E6;font-size:20px;"> 2. Please Select the Market and Brand. </p>**', unsafe_allow_html=True)

col_1, col_2 = st.columns(2)
with col_1:
    sql_market = f"SELECT distinct(country_code) FROM MMX_DEV.DWH_MMX.DWH_PRODUCT_MASTER;"
    df_markets = utils.get_data_sql("DEV", sql_market)
    market = st.selectbox( "[Step 1.] Market:",df_markets['country_code'].unique().tolist(), index=4)
with col_2:
    sql_brand = f"SELECT distinct(brand_name) FROM MMX_DEV.DWH_MMX.DWH_PRODUCT_MASTER where country_code = '{market}';"
    df_brands = utils.get_data_sql("DEV", sql_brand)
    brand = st.selectbox( "[Step 2.] Brand:", df_brands['brand_name'].unique().tolist())

    sql_brand_code = f"SELECT distinct(BRAND_CODE) FROM MMX_DEV.DWH_MMX.DWH_PRODUCT_MASTER where BRAND_NAME = '{brand}';"
    df_brands = utils.get_data_sql("DEV", sql_brand_code)
    brand_code = df_brands['brand_code'].unique().tolist()[0]
st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ Market & Brand Data Source: MMX_DEV.DWH_MMX.DWH_PRODUCT_MASTER (DEV Environment) </p>', unsafe_allow_html=True)

st.markdown(f'**<p style="color:#7A00E6;font-size:20px;"> 3. Please Select the Data Table.</p>**', unsafe_allow_html=True)

col_1, col_2 = st.columns(2)
with col_1:
    data_table = st.selectbox( "[Step 3.] Data Table:",("DWH_SELL_OUT_OWN",
                                                                "DWH_CHANNEL_FACTS",
                                                                "DWH_CHANNEL_EMAIL_FACTS",
                                                                "DWH_CHANNEL_EVENTS_FACTS",
                                                                "DWH_CHANNEL_SMS_FACTS",
                                                                "DWH_CHANNEL_WEBINAR_FACTS",
                                                                "DWH_CHANNEL_WHATSAPP_FACTS",
                                                                ))
# Load the data 
data_raw, sql_table = utils.get_data(data_table, brand, market, source, brand_code)

# IF THERE IS NO DATA AVAILABLE, STOP PROCESSING. 
if len(data_raw) == 0: 
    st.markdown(f'**<p style="color:#990000;font-size:20px;"> No Data Available: {market} & {brand} & {data_table}. </p>**', unsafe_allow_html=True)
else: 
    with col_2:
        start_period, end_period = st.select_slider(
        '[Step 4.] Range in <PERIOD_START>',
        options=sorted(data_raw["period_start"].unique().tolist()),
        value=(data_raw["period_start"].min(), data_raw["period_start"].max()))

    # Filter the raw data 
    data_raw = data_raw[(data_raw["period_start"] >= start_period) & 
                        (data_raw["period_start"] <= end_period)]
    
    created_ts = data_raw["created_ts"].unique().tolist()
    st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ [SQL]: {sql_table}</p>', unsafe_allow_html=True)
    st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ [PERIOD_TIME Range]: {data_raw["period_start"].min()} - {data_raw["period_start"].max()}</p>', unsafe_allow_html=True)
    st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ [CREATED_TS]: {created_ts[0]}</p>', unsafe_allow_html=True)
    st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ [MAIN SOURCES]: DWH_SELL_OUT_OWN & DWH_CHANNEL_FACTS. Other tables are for Data Engineering team.</p>', unsafe_allow_html=True)

    st.divider()

##############################################################################
## I. FILTERED DATA OVERVIEW
##############################################################################
    st.markdown(f'**<p style="color:#5500a1;font-size:30px;"> I. [{brand} in {market}] Raw & Filtered Data Overview</p>**', unsafe_allow_html=True)

    # Convert datetime 
    for col in data_raw.select_dtypes(include=['datetime64']).columns.tolist():
        utils.datetime_to_string_ymd(data_raw, col)

    data_filtered = utils.filter_dataframe(data_raw)

    utils.get_basic_info_metric(data_filtered, sql_table)
    st.divider()

##############################################################################
## II. Specialty/Segment Distributions
##############################################################################
    st.markdown(f'**<p style="color:#5500a1;font-size:30px;"> II. [{brand} in {market}] Specialty & Segment Distributions </p>**', unsafe_allow_html=True)
    msg = "DWH_HCP_MASTER, DWH_SEGMENT_MASTER, DWH_CHANNEL_MASTER are left or inner merged to create a specialty, segment distribution. To plot a distribution, the data are aggregated on a monthly level."
    st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ {msg}</p>', unsafe_allow_html=True)
    st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ There can be two UAT/DEV environments within the query, when selecting the UAT environment. </p>', unsafe_allow_html=True)
    
    st.markdown(f'**<p style="color:#7A00E6;font-size:20px;"> 1. Please Select Column to Aggregate.</p>**', unsafe_allow_html=True)
    
    # set the aggregated columns
    if data_table == 'DWH_CHANNEL_FACTS':
        agg_col = ['call_count', 'pde_weightage']
    elif data_table == "DWH_CHANNEL_EMAIL_FACTS":
        agg_col = ['metric_value']
    elif data_table == "DWH_CHANNEL_EVENTS_FACTS":
        agg_col = ['metric_value']
    elif data_table == "DWH_SELL_OUT_OWN":
        agg_col = ["value"]

    # Set the aggreagation column 
    agg_col = st.selectbox('[Step 1.] Choose a column to aggregate on a monthly level:', options=agg_col, key=11)

    # get the version code for SOO 
    if data_table == 'DWH_SELL_OUT_OWN':
        # get the version code
        st.markdown(f'**<p style="color:#9432eb;font-size:17px;"> 1-1. Please Select Version Code.</p>**', unsafe_allow_html=True)
        top_vc_list, sql_vc = utils.get_version_code(source, brand_code)

        # IF THERE IS NO VERSION CODE - NOT POSSIBLE TO GENERATE SPECIALTY AND SEGMENT DISTRIBUTIONS
        if len(top_vc_list) == 0:
            st.markdown(f'**<p style="color:#990000;font-size:20px;"> No Version Code Available, Please Run Brick Breaking Pipeline First.</p>**', unsafe_allow_html=True)
        else:
            selected_version_code = st.selectbox('[Step 2.] Choose a version code:', options=top_vc_list, key=100)
            st.markdown(f'**<p style="color:#7A00E6;font-size:20px;"> 2. Please Select Specialty & Segment Options. (Maximum 2) </p>**', unsafe_allow_html=True)
            
            # Get the data and sql
            data_merged, sql_table = utils.get_data_merged(source, data_table, brand, market, selected_version_code, brand_code) 

            if len(data_merged) ==0:
                st.markdown(f'**<p style="color:#990000;font-size:20px;"> No Data Available. Please Try Different Version Code.</p>**', unsafe_allow_html=True)
            else:
                # Create buttons for each data table
                data, specialty_list, segment_list = utils.set_buttons_on_tables(data_merged, sql_table)
                with st.expander(">>> Data Frame (partial) & SQL & Statistics"):
                    st.dataframe(data_merged.head(20))
                    st.markdown(sql_table)
                    utils.get_statistics(data)

                # Create distributions
                utils.get_all_distributions(data, agg_col, specialty_list, segment_list)
    else:    
        selected_version_code = False # no need a version code
        st.markdown(f'**<p style="color:#7A00E6;font-size:20px;"> 2. Please Select Specialty & Segment Options. (Maximum 2)</p>**', unsafe_allow_html=True)
        # get the data and sql
        data_merged, sql_table = utils.get_data_merged(source, data_table, brand, market, selected_version_code, brand_code) 

        # Create buttons for each data table
        data, specialty_list, segment_list = utils.set_buttons_on_tables(data_merged, sql_table)

        with st.expander(">>> Data Frame (partial) & SQL & See Statistics"):
            st.dataframe(data_merged.head(20))
            st.markdown(sql_table)
            utils.get_statistics(data)

        # Create distributions
        utils.get_all_distributions(data, agg_col, specialty_list, segment_list)

    st.divider()

##############################################################################
## III. Additional Tables
##############################################################################
    st.markdown(f'**<p style="color:#5500a1;font-size:30px;"> III. Additional Tables </p>**', unsafe_allow_html=True)

    st.markdown(f'**<p style="color:#7A00E6;font-size:20px;"> (1) Segment Code & Segment Value & Brand wise Metric Values and HCP Covered by Various Channels </p>**', unsafe_allow_html=True)
    # First two tables
    utils.additional_tables_channels(df_markets)
    st.divider()

    # Last two tables 
    st.markdown(f'**<p style="color:#7A00E6;font-size:20px;"> (2) Sales per HCP and Sales Coefficients </p>**', unsafe_allow_html=True)
    utils.get_sales_hcp_coeff(selected_version_code, brand, market)
    st.divider()
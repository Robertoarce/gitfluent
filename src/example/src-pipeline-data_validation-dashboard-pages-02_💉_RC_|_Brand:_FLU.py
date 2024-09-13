import os
import streamlit as st # pip install streamlit 
from streamlit_elements import elements, mui, html, sync,editor, lazy,nivo # pip install streamlit_elements
import pandas as pd
import numpy as np
import plotly.express as px  # pip install plotly-express
import snowflake.connector
from sqlalchemy import create_engine
import warnings
warnings.simplefilter(action='ignore', category=FutureWarning)
st.set_page_config(
    page_title="[MMX] Data Validation",
    page_icon="🌐",
    layout="wide",
    initial_sidebar_state="auto")

import sys
sys.path.insert(0, '..')
import validation_utils as utils
import validation_query as query

st.image("logo.png", width = 160)
if not utils.check_password():
    st.stop()

st.markdown(
            """
        <style>
        span[data-baseweb="tag"] {
          background-color: #23004C !important;
        }
        </style>
        """,
            unsafe_allow_html=True,
        )

source = "DEV"
brand = "FLU"
market = "FR"
env = "DEV"
##############################################################################
## TITLE / OPTIONS
##############################################################################
st.markdown(f'**<p style="color:#5500a1;font-size:30px;"> :syringe: RC | FLU Input Validations </p>**', unsafe_allow_html=True)
st.markdown(f"""
- This page shows RC input analysis of FLU brand in France market (DEV Environment). Please select the **DS | RC Input Validation** page for other brands.
""")
st.divider()

st.markdown(f'**<p style="color:#7A00E6;font-size:20px;"> 1. Please Select Input Source. </p>**', unsafe_allow_html=True)
data_table = st.selectbox( "Select Data Table:",('Touchpoint_Facts', 
                                                         'Sell_Out_Own'))

st.markdown(f'**<p style="color:#7A00E6;font-size:20px;"> 2. Please Select Following Options for Filtered Data. </p>**', unsafe_allow_html=True)

##############################################################################
## 1. Data Source Overview
##############################################################################
data_raw, sql = utils.get_flu_data(source, env, brand, data_table)
data_raw['value'] = data_raw['value'].apply(pd.to_numeric, errors='coerce')

data_raw_copy = data_raw.copy()
col_1, col_2, col_3 = st.columns(3)
for col in ["segment_code", "segment_value", "specialty_code"]:
    data_raw[col] = data_raw[col].str.lower()
with col_1:
    specialty = st.multiselect( "Select 1. Specialty:", 
                                   options = data_raw["specialty_code"].unique().tolist(), 
                                   default = data_raw["specialty_code"].unique().tolist(), key = 41)
data = data_raw[data_raw["specialty_code"].isin(specialty)]  # Filtered data

with col_2:
    segments = st.multiselect( "Select 2. Segment:", 
                                   options = data["segment_code"].unique().tolist(), 
                                   default = data["segment_code"].unique().tolist(), key = 42)
data = data[data["segment_code"].isin(segments)]  # Filtered data

with col_3:
    segments_vals = st.multiselect( "Select 3. Segment Values:", 
                                   options = data["segment_value"].unique().tolist(), 
                                   default = data["segment_value"].unique().tolist(), key = 43)
data = data[data["segment_value"].isin(segments_vals)]  # Filtered data

st.divider()
st.markdown(f'**<p style="color:#434343;font-size:20px;"> (1) A brief description</p>**', unsafe_allow_html=True)
"""
 * Data size & the number of unique values with respec to the column
   * 1st Row: Raw Data with removed nulls in segment_code
   * 2nd Row: Data with selected specialty_code & segment_code
"""
utils.get_compare_data(data_raw, data, data_table)

st.markdown(f'**<p style="color:#434343;font-size:20px;">(2) Filtered (Market, Brand, Segment_Code) DataFrame </p>**', unsafe_allow_html=True)
with st.expander(">>> See SQL "):
    st.markdown(f"**sql**: {sql}")

with st.expander(">>> See Filtered Data Statistics"):
    utils.get_statistics(data)

with st.expander(">>> See DataFrame (Partial})"):
    st.dataframe(data_raw.head(20))
st.divider()

##############################################################################
## 2. Basic Distribution
##############################################################################
st.markdown(f'**<p style="color:#0D0D0D;font-size:30px;"> II. [{brand} & {market}] Specialty & Segment Distributions</p>**', unsafe_allow_html=True)

agg_col = ['value']
segment_val = data_raw_copy['segment_value'].unique().tolist()

f"""
* Selected Data: 
* SPECIALTY: {data_raw_copy['specialty_code'].unique().tolist()}
* SEGMENT: {data_raw_copy['segment_code'].unique().tolist()}
* SEGMENT_VALUE : {segment_val}
"""

data_agg = utils.period_start_monthly_agg_df(data_raw_copy)

row1_col1, row1_col2 = st.columns(2)
with row1_col1: 
    st.markdown(f"**1. Channel Bar Graph**")
    try:
        data_ped = pd.DataFrame(data_raw_copy['channel_code'].value_counts()).reset_index().rename(columns={'index': 'channel'})
        data_ped.rename(columns={"channel_code": "channel_code_count"}, inplace=True)
        fig_channel = px.pie(data_ped, names=data_ped.columns.tolist()[0], values=data_ped.columns.tolist()[1]) #, orientation='h', opacity=0.7)
        row1_col1.plotly_chart(fig_channel, use_container_width=True)
    except:
        st.markdown("")
        st.markdown(f"Note: <channel_code> is not available.")

with row1_col2: 
    st.markdown(f"**2 Segment Value Bar Graph.**")
    data_ped = pd.DataFrame(data_raw_copy['segment_value'].value_counts()).reset_index().rename(columns={'index': 'segment_val'})
    data_ped.rename(columns={"segment_value": "segment_value_count"}, inplace=True)
    fig_channel = px.pie(data_ped, names=data_ped.columns.tolist()[0], values=data_ped.columns.tolist()[1]) #, orientation='h', opacity=0.7)
    row1_col2.plotly_chart(fig_channel, use_container_width=True)

row2_col1, row2_col2 = st.columns(2)
with row2_col1:
    st.markdown(f"**3. Aggregated on Monthly <VALUE>**")
    row2_col1.plotly_chart(utils.get_plot_all(data_agg, agg_col), use_container_width=True)

with row2_col2:
    st.markdown(f"**4. Aggregated on Monthly <VALUE> - per Segment Value**")
    df_seg_list = []
    for seg_val in segment_val:
        df_temp = data_raw_copy[data_raw_copy["segment_value"] == seg_val]
        df_agg = utils.period_start_monthly_agg_df(df_temp)
        df_agg['segment_value'] = seg_val
        df_seg_list.append(df_agg)
    final_df_seg_agg = pd.concat(df_seg_list)
    row2_col2.plotly_chart(utils.get_seg_plot(final_df_seg_agg, agg_col), use_container_width=True)


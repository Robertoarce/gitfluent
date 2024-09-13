import os
import streamlit as st
import snowflake.connector
from sqlalchemy import create_engine
import numpy as np
import pandas as pd
from pandas.api.types import (
    is_categorical_dtype,
    is_datetime64_any_dtype,
    is_numeric_dtype,
    is_object_dtype,
)
import plotly.express as px 
import plotly.graph_objects as go
import mlflow
from io import StringIO
# Reload ENV file 
try:
  from dotenv import load_dotenv
  load_dotenv(override=False)
except ModuleNotFoundError:
  pass

def set_page():
    """
    Page set up - wide format. 
    """
    st.set_page_config(
    page_title="[MMX] Data Validation",
    page_icon="🌐",
    layout="wide",
    initial_sidebar_state="auto")

def set_box():
    """
    Set up the <select box> color
    """
    st.markdown(
            """
        <style>
        span[data-baseweb="tag"] {
          background-color: #7A00E6 !important;
        }
        </style>
        """, unsafe_allow_html=True)
    
def check_password():
    """Returns `True` if the user had the correct password."""
    def password_entered():
        """Checks whether a password entered by the user is correct."""
        if st.session_state["password"] == os.environ["STREAMLIT_DASHBOARD_PASSWORD"]:
            st.session_state["password_correct"] = True
            del st.session_state["password"]  
        else:
            st.session_state["password_correct"] = False

    if "password_correct" not in st.session_state:
        # First run, show input for password.
        st.text_input(
            "Password", type="password", on_change=password_entered, key="password"
        )
        return False
    elif not st.session_state["password_correct"]:
        # Password not correct, show input + error.
        st.text_input(
            "Password", type="password", on_change=password_entered, key="password"
        )
        st.error("😕 Password incorrect")
        return False
    else:
        # Password correct.
        return True

@st.cache_resource
def set_snowflake_connection(env):
    """[Set the snowflake connection object]
    Arguments:
        snowflake_con_params {dict} -- [snowflake parameters to be passed] given source (environment)
    Returns:
        snowflake connection
    """
    con = snowflake.connector.connect(
                user = os.environ[f"SNOW_USER_{env}"], 
                account = os.environ[f"SNOW_ACCOUNT_{env}"], 
                password = os.environ[f"SNOW_PASSWORD_{env}"],
                warehouse = os.environ[f"SNOW_WAREHOUSE_{env}"],
                database = os.environ[f"SNOW_DATABASE_{env}"],
                role = os.environ[f"SNOW_ROLE_{env}"],
                client_session_keep_alive=True)
    print("Connection successful!")
    return con

# FLU
import validation_query as query
def get_flu_data(source, env, brand, data_table):
    snowflake_con = set_snowflake_connection(env)
    cursor = snowflake_con.cursor()

    sql = query.get_query(brand, data_table)
    cursor.execute(sql)
    data = cursor.fetch_pandas_all()
    data.columns = data.columns.str.lower()
    return data, sql
    

def get_data_merged(source, data_table, brand, market, version_code, brand_code):
    """[Set the snowflake connection object]
    Arguments:
        snowflake_con_params {dict} -- [snowflake parameters to be passed]
    """
    snowflake_con = set_snowflake_connection(source)
    cursor = snowflake_con.cursor()
    
    if source == "DEV":
        DATABASE = os.environ["SNOW_DATABASE_DEV"]
    elif source =="UAT":
        DATABASE = os.environ["SNOW_DATABASE_UAT"]

    if data_table == "DWH_CHANNEL_FACTS":
        select_cols = """A.country_code, A.PRESCRIBER_CODE, A.brand_name, A.period_start, A.call_count,
                    A.pde_weightage, A.internal_channel_code, A.INTERNAL_GEO_CODE, A.BRAND_CODE, A.FREQUENCY"""
        sql = f"""SELECT {select_cols}, 
                    C.sub_national_code,
                    LOWER(C.SPECIALTY_CODE) AS SPECIALTY_CODE, D.SEGMENT_CODE, D.SEGMENT_VALUE, E.channel_CODE
                    FROM {DATABASE}.DWH_MMX.{data_table} A
                    INNER JOIN {DATABASE}.DWH_MMX.DWH_HCP_MASTER C
                    ON A.PRESCRIBER_CODE = C.HCP_CODE
                    LEFT JOIN (SELECT * FROM {DATABASE}.DWH_MMX.DWH_SEGMENT_MASTER where BRAND_NAME = '{brand}' and COUNTRY_CODE = '{market}') D
                    ON A.PRESCRIBER_CODE = D.HCP_CODE
                    INNER JOIN {DATABASE}.DWH_MMX.DWH_CHANNEL_MASTER E
                    ON A.INTERNAL_CHANNEL_CODE=E.internal_channel_code
                    WHERE A.COUNTRY_CODE = '{market}'
                    AND A.BRAND_CODE = '{brand_code}'
                    AND A.INTERNAL_GEO_CODE is not null
                    AND (A.BRAND_NAME like '{brand}');"""

    elif data_table == "DWH_CHANNEL_EMAIL_FACTS":
        select_cols = """A.country_code, A.PRESCRIBER_CODE, A.brand_name, A.period_start, 
                    A.PRESCRIBER_TYPE,  A.METRIC_NAME, A.METRIC_VALUE, A.BRAND_CODE, A.CREATED_TS"""              
        sql = f"""SELECT {select_cols}, 
                        C.sub_national_code,
                        LOWER(C.SPECIALTY_CODE) AS SPECIALTY_CODE, D.SEGMENT_CODE, D.SEGMENT_VALUE
                        FROM {DATABASE}.DWH_MMX.{data_table} A 
                        INNER JOIN {DATABASE}.DWH_MMX.DWH_HCP_MASTER C
                        ON A.PRESCRIBER_CODE = C.HCP_CODE
                        LEFT JOIN (SELECT * FROM {DATABASE}.DWH_MMX.DWH_SEGMENT_MASTER where BRAND_NAME = '{brand}' and COUNTRY_CODE = '{market}') D
                        ON A.PRESCRIBER_CODE = D.HCP_CODE
                        WHERE A.BRAND_CODE = '{brand_code}'
                        AND A.COUNTRY_CODE = '{market}'
                        AND A.INTERNAL_GEO_CODE is not null
                        AND A.BRAND_CODE = '{brand_code}'
                        AND (A.BRAND_NAME like '{brand}');"""

    elif data_table == "DWH_CHANNEL_EVENTS_FACTS":
        select_cols = """A.INTERNAL_GEO_CODE, A.EVENT_CODE, A.PRESCRIBER_CODE, A.PRESCRIBER_TYPE, A.COUNTRY_CODE, 
                    A.GBU_CODE,  A.BRAND_CODE, A.BRAND_NAME, A.CHANNEL_CODE, A.METRIC_NAME, A.METRIC_VALUE, A.PERIOD_START, A.CREATED_TS"""              
        sql = f"""SELECT {select_cols}, 
                        C.sub_national_code,
                        LOWER(C.SPECIALTY_CODE) AS SPECIALTY_CODE, D.SEGMENT_CODE, D.SEGMENT_VALUE
                        FROM {DATABASE}.DWH_MMX.{data_table} A 
                        INNER JOIN {DATABASE}.DWH_MMX.DWH_HCP_MASTER C
                        ON A.PRESCRIBER_CODE = C.HCP_CODE
                        LEFT JOIN (SELECT * FROM {DATABASE}.DWH_MMX.DWH_SEGMENT_MASTER where BRAND_NAME = '{brand}' and COUNTRY_CODE = '{market}') D
                        ON A.PRESCRIBER_CODE = D.HCP_CODE
                        WHERE A.BRAND_CODE = '{brand_code}'
                        AND A.COUNTRY_CODE = '{market}'
                        AND A.INTERNAL_GEO_CODE is not null
                        AND A.BRAND_CODE = '{brand_code}'
                        AND (A.BRAND_NAME like '{brand}');"""

    elif data_table == "DWH_SELL_OUT_OWN":
        sql = f"""SELECT sa.internal_geo_code, sa.period_start, 'MONTH' as frequency, sa.sales_value as value,
                        sa.currency, sa.brand_code, gb.brand_name, LOWER(sa.specialty_code) as specialty_code, LOWER(sa.segment_code) as segment_code, sa.segment_value_lower as segment_value,sa.sales_channel_code, sa.sales_volume as volume, sa.num_hcp
                        FROM {DATABASE}.DMT_MMX.SALES_ALLOCATION sa inner join
                        MMX_DEV.DWH_MMX.dwh_gbu_brand gb on sa.brand_code=gb.brand_code
                        WHERE
                        sa.VERSION_CODE = '{version_code}' and 
                        sa.internal_geo_code in (select gm.internal_geo_code from MMX_DEV.DWH_MMX.DWH_GEO_MASTER gm where gm.market_code='{market}')
                        and sa.brand_code='{brand_code}'""" 

    elif data_table == "Touchpoint_Facts":
        sql = f"""SELECT A.COUNTRY_CODE, A.PRESCRIBER_CODE, A.brand_name, A.period_start, A.call_count,
                        A.pde_weightage, A.internal_channel_code, A.INTERNAL_GEO_CODE, A.BRAND_CODE, A.FREQUENCY, 
                        A.PDE_WEIGHTAGE as value, c.sub_national_code,
                        LOWER(C.SPECIALTY_CODE) AS SPECIALTY_CODE, D.SEGMENT_CODE, D.SEGMENT_VALUE, E.channel_CODE
                        FROM MMX_DEV.DWH_MMX.DWH_CHANNEL_FACTS A
                        INNER JOIN MMX_DEV.DWH_MMX.DWH_HCP_MASTER C
                        ON A.PRESCRIBER_CODE = C.HCP_CODE
                        LEFT JOIN (SELECT * FROM MMX_DEV.DWH_MMX.DWH_SEGMENT_MASTER where BRAND_NAME = '{brand}' and COUNTRY_CODE = '{market}') D
                        ON A.PRESCRIBER_CODE = D.HCP_CODE
                        INNER JOIN MMX_DEV.DWH_MMX.DWH_CHANNEL_MASTER E
                        ON A.INTERNAL_CHANNEL_CODE=E.internal_channel_code
                        WHERE A.COUNTRY_CODE = '{market}'
                        AND A.INTERNAL_GEO_CODE is not null
                        AND (A.BRAND_NAME like '{brand}');"""
                        # AND A.period_start between '2021-01-01' and '2022-11-01';"""
   
    elif data_table == "Sell_Out_Own":
        sql = f"""SELECT sa.internal_geo_code, sa.period_start, 'MONTH' as frequency, sa.sales_value as value,
                        sa.currency, sa.brand_code, gb.brand_name, LOWER(sa.specialty_code) as specialty_code, LOWER(sa.segment_code) as segment_code, sa.segment_value_lower as segment_value,sa.sales_channel_code, sa.sales_volume as volume, sa.num_hcp
                        FROM {DATABASE}.DMT_MMX.SALES_ALLOCATION sa inner join
                        MMX_DEV.DWH_MMX.DWH_GBU_BRAND gb on sa.brand_code=gb.brand_code
                        WHERE
                        sa.VERSION_CODE = '{version_code}' and 
                        sa.internal_geo_code in (select gm.internal_geo_code from MMX_DEV.DWH_MMX.DWH_GEO_MASTER gm where gm.market_code='{market}')
                        and sa.brand_code='{brand_code}'""" 

    cursor.execute(sql)
    data = cursor.fetch_pandas_all()
    data.columns = data.columns.str.lower()
    return data, sql

def get_version_code(env, brand_code):
    """[Set the snowflake connection object]
    Arguments:
        snowflake_con_params {dict} -- [snowflake parameters to be passed]
    """
    snowflake_con = set_snowflake_connection(env)
    cursor = snowflake_con.cursor()
    
    if env == "DEV":
        DATABASE = os.environ["SNOW_DATABASE_DEV"]
    elif env =="UAT":
        DATABASE = os.environ["SNOW_DATABASE_UAT"]

    sql = f"SELECT distinct(version_code) FROM MMX_{env}.DMT_MMX.SALES_ALLOCATION where brand_code = '{brand_code}';"
    
    cursor.execute(sql)
    data = cursor.fetch_pandas_all()
    top_vc_list = sorted(data["VERSION_CODE"].unique().tolist(), reverse=True)
    
    return top_vc_list, sql

def get_data_sql(env, sql):
    """
    Return:
        return any values based on a given query
    """
    snowflake_con = set_snowflake_connection(env)
    cursor = snowflake_con.cursor()
    cursor.execute(sql)
    data = cursor.fetch_pandas_all()
    data.columns = data.columns.str.lower()
    return data

def get_data(data_table, brand, market, env, brand_code):
    """
    Return:
        Load the data from Snowflake for given brand and market
    """
    snowflake_con = set_snowflake_connection(env)
    cursor = snowflake_con.cursor()

    if env == "DEV":
        DATABASE = os.environ["SNOW_DATABASE_DEV"]
        print('DEV Envorinment')
    elif env =="UAT":
        print('UAT Envorinment')
        DATABASE = os.environ["SNOW_DATABASE_UAT"]

    if data_table == "DWH_CHANNEL_EMAIL_FACTS":
        sql = f"""SELECT * FROM {DATABASE}.DWH_MMX.{data_table} 
                WHERE BRAND_NAME = '{brand}' 
                AND COUNTRY_CODE = '{market}'"""

    elif data_table == "DWH_CHANNEL_EVENTS_FACTS":
        sql = f"""SELECT * FROM {DATABASE}.DWH_MMX.{data_table} 
                WHERE BRAND_NAME = '{brand}' 
                AND COUNTRY_CODE = '{market}'"""

    elif data_table == "DWH_CHANNEL_FACTS":
        sql = f"""SELECT * FROM {DATABASE}.DWH_MMX.{data_table} 
                WHERE BRAND_NAME = '{brand}' 
                AND COUNTRY_CODE = '{market}'"""

    elif data_table == "DWH_CHANNEL_SMS_FACTS":
        sql = f"""SELECT * FROM {DATABASE}.DWH_MMX.{data_table} 
                WHERE BRAND_NAME = '{brand}' 
                AND COUNTRY_CODE = '{market}'"""

    elif data_table == "DWH_CHANNEL_WEBINAR_FACTS":
        sql = f"""SELECT * FROM {DATABASE}.DWH_MMX.{data_table} 
                WHERE BRAND_NAME = '{brand}' 
                AND COUNTRY_CODE = '{market}'"""   

    elif data_table == "DWH_CHANNEL_WHATSAPP_FACTS":
        sql = f"""SELECT * FROM {DATABASE}.DWH_MMX.{data_table} 
                WHERE BRAND_NAME = '{brand}' 
                AND COUNTRY_CODE = '{market}'"""  

    elif data_table == "DWH_SELL_OUT_OWN":
        sql = f"""SELECT * FROM {DATABASE}.DWH_MMX.{data_table} 
                WHERE BRAND_CODE = '{brand_code}'"""   
 
    cursor.execute(sql)
    data = cursor.fetch_pandas_all()
    data.columns = data.columns.str.lower()
    return data, sql 

def get_compare_data(data_raw, data, data_table):
    """
    Return:
        The RC Input Validation Overview Page
    """
    col_1, col_2, col_3, col_4, col_5, col_6 = st.columns(6)
    with col_1: 
        st.markdown(f'**<p style="color:#757575  ;font-size:19px;">Size</p>**', unsafe_allow_html=True)
        st.markdown(f'{len(data_raw):,}')
        st.markdown(f'{len(data):,}')
    with col_2:
        st.markdown(f'**<p style="color:#757575  ;font-size:19px;"> Internal_geo_code</p>**', unsafe_allow_html=True)
        st.markdown(f"""{data_raw['internal_geo_code'].nunique()}""")
        st.markdown(f"""{data['internal_geo_code'].nunique()}""")
    with col_3:
        st.markdown(f'**<p style="color:#757575  ;font-size:19px;"> Specialty</p>**', unsafe_allow_html=True)
        st.markdown(f"""{data_raw['specialty_code'].nunique()}""")
        st.markdown(f"""{data['specialty_code'].nunique()}""")
    with col_4:
        st.markdown(f'**<p style="color:#757575  ;font-size:19px;"> Segment_code</p>**', unsafe_allow_html=True)
        st.markdown(f"""{data_raw['segment_code'].nunique()}""")
        st.markdown(f"""{data['segment_code'].nunique()}""")
    with col_5:
        st.markdown(f'**<p style="color:#757575  ;font-size:19px;"> Segment_value</p>**', unsafe_allow_html=True)
        st.markdown(f"""{data_raw['segment_value'].nunique()}""")
        st.markdown(f"""{data['segment_value'].nunique()}""")
    with col_6:
        st.markdown(f'**<p style="color:#757575  ;font-size:19px;"> Channel_code</p>**', unsafe_allow_html=True)
        if data_table == "Touchpoint_Facts":
            st.markdown(f"""{data_raw['channel_code'].nunique()}""")
            st.markdown(f"""{data['channel_code'].nunique()}""")
        else:
            st.markdown(f"""{"N/A"}""")
            st.markdown(f"""{"N/A"}""")

    with st.expander(">>> See Unique Values in <segment_code>, <segment_value>, <specialty_code>"):
        st.markdown("**[Raw Data] Unique Values**")
        st.markdown(f"""**specialty_code:** {data_raw["specialty_code"].unique().tolist()}""")
        st.markdown(f"""**segment_code:** { data_raw["segment_code"].unique().tolist()}""")
        st.markdown(f"""**segment_value:** { data_raw["segment_value"].unique().tolist()}""")
        if data_table == "Touchpoint_Facts":
            st.markdown(f"""**channel_code:** { data_raw["channel_code"].unique().tolist()}""")

        st.divider()
        st.markdown("**[Filtered Data] Unique Values**")
        st.markdown(f"""**specialty_code:** {data["specialty_code"].unique().tolist()}""")
        st.markdown(f"""**segment_code:** { data["segment_code"].unique().tolist()}""")
        st.markdown(f"""**segment_value:** { data["segment_value"].unique().tolist()}""")
        if data_table == "Touchpoint_Facts":
            st.markdown(f"""**channel_code:** { data["channel_code"].unique().tolist()}""")

def get_statistics(df):
    """
    Return:
        Basic statistics for numerical / categorical columns for a given data set.
    """
    num_col_list = df.select_dtypes(include=[np.number]).columns.tolist()
    ojb_col_list = df.select_dtypes(exclude=[np.number]).columns.tolist()
    num_col_list = [x for x in num_col_list if x != 'prescriber_code']

    st.markdown(f'**<p style="color:#7A00E6;font-size:18px;"> 1. Basic Infomation </p>**', unsafe_allow_html=True)
    st.markdown(f'<p style="color:#808B96;font-size:16px;"> ‣ [Data Size]: {len(df):,} </p>', unsafe_allow_html=True)
    st.markdown(f'<p style="color:#808B96;font-size:16px;"> ‣ [Missing Values] - columns and its missing value percentage </p>', unsafe_allow_html=True)
    st.dataframe(pd.DataFrame(df.isnull().mean()*100).reset_index().rename(columns={0 : "Missing Value Percent", "index" : "column name"}))
    
    st.markdown(f'**<p style="color:#7A00E6;font-size:18px;"> 2. Numerical Columns </p>**', unsafe_allow_html=True)
    for col in num_col_list:
        if (col == "prescriber_code") or (col == "period_start"):
            st.write(f"""
            * **{col}**
                * Those values are numeric, but the number of unique values is: {df[col].nunique():,}
            """)
            pass
        else:
            st.write(f"""
            * **{col}**
                * Mean: {round(df[col].mean(), 3)}
                * Median: {round(df[col].median(), 3)}
                * Variance: {round(df[col].var(),3)}
            """)

    st.write("")
    st.markdown(f'**<p style="color:#7A00E6;font-size:18px;"> 3. Object Columns </p>**', unsafe_allow_html=True)
    for col in ojb_col_list:
        unique_num = df[col].nunique()

        if (col == "channel_code") or (col == "prescriber_type"):
            st.write(f"""
            * **{col}**
                * The Number of Unique Values: {unique_num}
                * value_counts(normlized=True)"""
                )
            st.dataframe(pd.DataFrame(df[col].value_counts(normalize=True)))
            

        if unique_num == 1:
            st.write(f"""
            * **{col}**: Only one unique Value → {df[col].unique().tolist()[0]}
            """)
        elif unique_num > 10: 
            st.write(f"""
            * **{col}**
                * The Number of Unique Values: {unique_num}
                * Top 10: value_counts(normalize=True)
            """)
            st.dataframe(pd.DataFrame(df[col].value_counts(normalize=True).nlargest(10)))
        else:
            st.write(f"""
            * **{col}**
                * The Number of Unique Values: {unique_num}
                * Unique Values: {df[col].unique().tolist()}
            """)

def get_basic_info_metric(df, sql):
    c1_r1, c2_r1, c3_r1, c4_r1= st.columns(4)
    with c1_r1: 
        st.metric(label="Data Size", value=f'{len(df):,}')
    with c2_r1:
        if "internal_geo_code" in df.columns.tolist():
            st.metric(label="Internal Geo Code", value=f'{df["internal_geo_code"].nunique():,}')
    with c3_r1:
        if "prescriber_code" in df.columns.tolist():
            st.metric(label="Prescriber Code", value=f'{df["prescriber_code"].nunique():,}')
        else:
            st.markdown("")
    with c4_r1:
        if "channel_code" in df.columns.tolist():
            st.metric(label="Channel Code", value=f'{df["channel_code"].nunique():,}')
            channel_list = df["channel_code"].unique().tolist()
            st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ {", ".join(channel_list)}</p>', unsafe_allow_html=True)
        else:
            st.markdown("")
    
    with st.expander(">>> See Descriptions"):
        st.markdown(
        f"""
        * **Data size**: The number of records selected <CREATED_TS>.
        * **INTERNAL_GEO_CODE**: The number of unique <INTERNAL_GEO_CODE>
        * **PRESCRIBER_CODE**: The number of unique <PRESCRIBER_CODE>, *if available.*
        * **CHANNEL_CODE**: Unique values in <CHANNEL_CODE>, *if available.*
        """)  
    with st.expander(">>> Basic Distributions"):
        for col in df.select_dtypes(include=np.number).columns.tolist():
            if (col == "prescriber_code") or (col == "period_start"):
                pass
            else:
                st.markdown(f'**<p style="color:#7A00E6;font-size:18px;"> >>> {col.upper()}</p>**', unsafe_allow_html=True)
                get_basic_dist(df, col)
                st.divider()

    with st.expander(">>> See DataFrame (partial) & SQL"):
        st.dataframe(df.head(30))
        st.divider()
        st.markdown(sql)

    with st.expander(">>> See Statistics"):
        get_statistics(df)


def get_features_df(df, col_list):
    c1_r1, c2_r1, c3_r1= st.columns(3)
    with c1_r1: 
        st.metric(label="Data Size", value=f'{len(df):,}')
    with c2_r1:
        if "internal_geo_code" in df.columns.tolist():
            st.metric(label="Internal Geo Code", value=f'{df["internal_geo_code"].nunique():,}')
    with c3_r1:
        if "channel_code" in df.columns.tolist():
            st.metric(label="Channel Code", value=f'{df["channel_code"].nunique():,}')
            channel_list = df["channel_code"].unique().tolist()
            st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ {", ".join(channel_list)}</p>', unsafe_allow_html=True)
        else:
            st.markdown("")
     
    with st.expander(">>> Basic Distributions"):
        for col in col_list:
            st.markdown(f'**<p style="color:#7A00E6;font-size:18px;"> >>> {col.upper()}</p>**', unsafe_allow_html=True)
            get_basic_dist(df, col)
            st.divider()


def filter_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """
    [Adds a UI on top of a dataframe to let viewers filter columns]
    Args:
        df (pd.DataFrame): Original dataframe
    Returns:
        pd.DataFrame: Filtered dataframe
    """
    modify = st.checkbox("Add filters")

    if not modify:
        return df

    df = df.copy()

    # Try to convert datetimes into a standard format (datetime, no timezone)
    for col in df.columns:
        if is_object_dtype(df[col]):
            try:
                df[col] = pd.to_datetime(df[col])
            except Exception:
                pass

        if is_datetime64_any_dtype(df[col]):
            df[col] = df[col].dt.tz_localize(None)

    modification_container = st.container()

    with modification_container:
        to_filter_columns = st.multiselect("Filter dataframe on", df.columns)
        for column in to_filter_columns:
            left, right = st.columns((1, 20))
            # Treat columns with < 10 unique values as categorical
            if is_categorical_dtype(df[column]) or df[column].nunique() < 10:
                user_cat_input = right.multiselect(
                    f"Values for {column}",
                    df[column].unique(),
                    default=list(df[column].unique()),
                )
                df = df[df[column].isin(user_cat_input)]
            elif is_numeric_dtype(df[column]):
                _min = float(df[column].min())
                _max = float(df[column].max())
                step = (_max - _min) / 100
                user_num_input = right.slider(
                    f"Values for {column}",
                    min_value=_min,
                    max_value=_max,
                    value=(_min, _max),
                    step=step,
                )
                df = df[df[column].between(*user_num_input)]
            elif is_datetime64_any_dtype(df[column]):
                user_date_input = right.date_input(
                    f"Values for {column}",
                    value=(
                        df[column].min(),
                        df[column].max(),
                    ),
                )
                if len(user_date_input) == 2:
                    user_date_input = tuple(map(pd.to_datetime, user_date_input))
                    start_date, end_date = user_date_input
                    df = df.loc[df[column].between(start_date, end_date)]
            else:
                user_text_input = right.text_input(
                    f"Substring or regex in {column}",
                )
                if user_text_input:
                    df = df[df[column].astype(str).str.contains(user_text_input)]

    return df

def get_basic_dist(df, col):
    '''
    Returns basic plots for numerical columns
    '''
    st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ [PERIOD_TIME Range]: {df["period_start"].min()} - {df["period_start"].max()}</p>', unsafe_allow_html=True)
    if 'channel_code' in df.columns.tolist():
        channel_list = df["channel_code"].unique().tolist()
        st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ [Selected Channel_Code]: {", ".join(channel_list)} </p>', unsafe_allow_html=True)
           
    if (col in ['call_count', 'pde_weightage', 'value', 'volume', 'spend_f2f', 'spend_rem', 'spend_pho', 'spend_oth']) & ('period_start' in df.columns.tolist()):

        if col in ['spend_f2f', 'spend_rem', 'spend_pho', 'spend_oth']:
            # Not plotting Histogram in those columns
            pass 
        else:
            col_1, col_2 = st.columns([4, 1])
            with col_1:
                if 'channel_code' in df.columns.tolist():
                    df_channel_list = []
                    for ch in channel_list:
                        df_temp = df[df["channel_code"] == ch]
                        df_agg_temp = period_start_monthly_agg_df(df_temp)
                        df_agg_temp['channel_code'] = ch
                        df_channel_list.append(df_agg_temp)
                    final_df_ch_agg = pd.concat(df_channel_list)
                    fig = px.histogram(df, x=col, marginal="violin", color = "channel_code",
                            hover_data=df.columns, title = f'Histogram: {col.upper()}')
                    st.plotly_chart(fig, use_container_width=True) 
                else:
                    fig = px.histogram(df, x=col, marginal="violin",
                                hover_data=df.columns, title = f'Histogram: {col.upper()}')
                    st.plotly_chart(fig, use_container_width=True) 

        
        col_1_line, col_2_line = st.columns([4, 1])
        with col_1_line:
            # Line plot 
            datetime_to_string_ymd(df, 'period_start')
            if 'channel_code' in df.columns.tolist():
                df_channel_list = []
                for ch in channel_list:
                    df_temp = df[df["channel_code"] == ch]
                    df_agg_temp = period_start_monthly_agg_df(df_temp)
                    df_agg_temp['channel_code'] = ch
                    df_channel_list.append(df_agg_temp)
                final_df_ch_agg = pd.concat(df_channel_list)
                fig_ch = px.line(final_df_ch_agg, x='period_start', y=col, color = "channel_code", markers=True,
                                title = f"Line Plot: {col.upper()}"
                                )
                st.plotly_chart(fig_ch, use_container_width=True)
            else: 
                df_agg = period_start_monthly_agg_df(df)
                fig = px.line(df_agg, x='period_start', y=col, markers=True,
                    title = f"Line Plot: {col.upper()}")
                st.plotly_chart(fig, use_container_width=True)


    elif col in ['call_count', 'pde_weightage', 'value', 'volumn']:
        fig = px.histogram(df, x=col, marginal="violin",
                    hover_data=df.columns, title = f'Histogram: {col.upper()}')
        st.plotly_chart(fig, use_container_width=True)


def set_buttons_on_tables(data_merged, sql_table):
    """
    Returns:
        Create select buttons of Specialty and Segment
    """
    for col in ["segment_code", "segment_value", "specialty_code"]:
        data_merged[col] = data_merged[col].str.lower()
    
    col_1, col_2 = st.columns(2)
    with col_1:
        specialty = st.multiselect( "[Step 1]. Please Select Specialty:", 
                                    options = data_merged["specialty_code"].unique().tolist(), 
                                    default = data_merged['specialty_code'].value_counts().nlargest(10)[:2].index.tolist(), key = 12)
    with col_2:
        segments = st.multiselect( "[Step 2.] Please select Segment:", 
                                    options = data_merged["segment_code"].unique().tolist(), 
                                    default = data_merged['segment_code'].value_counts().nlargest(10)[:2].index.tolist(), key = 13)

    data_merged = data_merged[data_merged["specialty_code"].isin(specialty)]  # Filtered data
    data = data_merged[data_merged["segment_code"].isin(segments)]  # Filtered data
    return data, specialty, segments
    

def datetime_to_string_ymd(df, col):
    """
    Returns:
        year-month-day string format
    """
    try:
        df[col] = pd.to_datetime(df[col].astype(str), format='%Y-%m-%d').dt.date
        df[col] = df[col].astype(str)
    except:
        try:
            df[col] = pd.to_datetime(df[col].astype(str), format='%Y%m').dt.date
            df[col] = df[col].astype(str)
        except:
            try:
                df[col] = pd.to_datetime(df[col].astype(str), format='%Y-%m-%d %H:%M:%S').dt.date
                df[col] = df[col].astype(str)
            except:
                try:
                    df[col] = pd.to_datetime(df[col].astype(str), format='ISO8601').dt.date
                    df[col] = df[col].astype(str)
                except Exception as inst:
                    print(inst)
                    st.markdown(inst)
    return df[col]

def period_start_monthly_agg_df(data):
    """
    Returns:
        Monthly aggregated dataframe (period_start)
    """
    cols = data.select_dtypes(include=np.number).columns.tolist()
    cols = [x for x in cols if x != "prescriber_code"]
    df_agg = data.groupby('period_start', as_index=False)[cols].sum()
    return df_agg
    
def get_plot_all(df, agg_col):
    """
    Returns:
       Ploty fig information of given agg_col distribution.
    """
    fig_all = px.line(df, 
                    x="period_start", 
                    y=agg_col, 
                    markers=True)
    fig_all.update_traces(line_color='#7A00E6')
    return fig_all

def get_specialty_plot(data, agg_col):
    """
    Returns:
       Ploty fig information for specialty groups.
    """
    fig_specialty = px.line(data, 
            x="period_start", 
            y=agg_col, 
            color="specialty_value",
            markers=True)
    fig_specialty.update_layout(legend=dict(
                            orientation="h",
                            yanchor="bottom",
                            y=1.02,
                            xanchor="right",
                            x=1
                        ))
    return fig_specialty

def get_seg_plot(data, agg_col):
    """
    Returns:
       Ploty fig information for segments.
    """
    fig_seg = px.line(data, 
                        x="period_start", 
                        y=agg_col, 
                        color="segment_value",
                        markers=True)
    fig_seg.update_layout(legend=dict(
                            orientation="h",
                            yanchor="bottom",
                            y=1.02,
                            xanchor="right",
                            x=1
                        ))
    return fig_seg

def get_specialty_channel_hist(data, segment_val, specialty):
    """
    Args:
        segment_val: segment value list
        specialty: str
    Returns:
       Horizontal histogram givin segment value and specialty
    """
    data_ped = data[(data["specialty_code"] == specialty) & 
                    (data["segment_value"].isin(segment_val))]
    data_ped = pd.DataFrame(data_ped['channel_code'].value_counts()).reset_index().rename(columns={'index': 'channel'})
    data_ped.rename(columns={"channel_code": "channel_code_count"}, inplace=True)
    fig_channel = px.pie(data_ped, names=data_ped.columns.tolist()[0], values=data_ped.columns.tolist()[1]) #orientation='h', opacity=0.7
    return fig_channel

def get_all_distributions(data, agg_col, specialty_list, segment_list):
    """
    Returns:
        First Row, First Column: All Specialties Distribution 
        First Row, Second Column: 'Pédiatrie' vs 'Méd générale' Distributions

        Second Row, First Column: Pédiatrie - Segment Distributions
        Second Row, Second Column: Méd générale - Segment Distributions

        Thrid Row, First Column: Pédiatrie Channel Bar Graph
        Third Row, Second Column Méd générale Channel Bar Graph
    """
    row1_col1, row1_col2 = st.columns(2)
    # First Row, First Column
    with row1_col1:
        st.markdown(f'**(1) All Specialties Distribution:**')
        df_agg = period_start_monthly_agg_df(data)
        row1_col1.plotly_chart(get_plot_all(df_agg, agg_col), use_container_width=True)

    # First Row, Second Column
    with row1_col2:
        st.markdown(f"**(2) {specialty_list} Distributions**")
        df_seg_list = []
        for spe_val in specialty_list:
            df_temp = data[data["specialty_code"] == spe_val]
            df_agg = period_start_monthly_agg_df(df_temp)
            df_agg['specialty_value'] = spe_val
            df_seg_list.append(df_agg)
        final_df_seg_agg = pd.concat(df_seg_list)
        row1_col2.plotly_chart(get_specialty_plot(final_df_seg_agg, agg_col), use_container_width=True)

    row2_col1, row2_col2 = st.columns(2)
    # Second Row, First Column
    with row2_col1:
        try:
            st.markdown(f"**(3) {specialty_list[0]}- Segment Distributions**")
            segment_val = data['segment_value'].unique().tolist()
            data_ped = data[(data["specialty_code"] == specialty_list[0]) & 
                            (data["segment_value"].isin(segment_val))]
            df_seg_list = []
            for seg_val in segment_val: 
                df_temp = data_ped[data_ped["segment_value"] == seg_val]
                df_agg = period_start_monthly_agg_df(df_temp)
                df_agg['segment_value'] = seg_val
                df_seg_list.append(df_agg)
            final_df_seg_agg = pd.concat(df_seg_list)
            if len(final_df_seg_agg) == 0:
                st.markdown(f'<p style="color:#FF5733 ;font-size:14px;"> NOTE. There is no data available. Please check the segment values. </p>', unsafe_allow_html=True)
                st.markdown("")
            else:
                row2_col1.plotly_chart(get_seg_plot(final_df_seg_agg, agg_col), use_container_width=True)
        except:
            st.markdown(f"**(3) There is no selected specialty.**")

    # Second Row, Second Column
    with row2_col2:
        try:
            st.markdown(f"**(4) {specialty_list[1]} - Segment Distributions**")
            data_gen = data[(data["specialty_code"] == specialty_list[1]) &  
                                (data["segment_value"].isin(segment_val))]
            df_seg_list = []
            for seg_val in segment_val: 
                df_temp = data_gen[data_gen["segment_value"] == seg_val]
                df_agg = period_start_monthly_agg_df(df_temp)
                df_agg['segment_value'] = seg_val
                df_seg_list.append(df_agg)
            final_df_seg_agg = pd.concat(df_seg_list)
            if len(final_df_seg_agg) == 0:
                st.markdown(f'<p style="color:#FF5733 ;font-size:14px;"> NOTE. There is no data available. Please check the segment values.</p>', unsafe_allow_html=True)
                st.markdown("")
            else:
                row2_col2.plotly_chart(get_seg_plot(final_df_seg_agg, agg_col), use_container_width=True)
        except:
            st.markdown(f"**(4) There is no selected specialty.**")
   
    # Third Row, First Column
    if 'internal_channel_code' in data.columns.tolist():
        row3_col1, row3_col2 = st.columns(2)
        with row3_col1:
            data_ped = data[(data["specialty_code"] == specialty_list[0]) & 
                    (data["segment_value"].isin(segment_val))]
            if len(data_ped) == 0:
                st.markdown(f"**(5) {specialty_list[0]} - Pie Chart in Channels**")
                st.markdown(f'<p style="color:#FF5733 ;font-size:14px;"> NOTE. There is no data available. </p>', unsafe_allow_html=True)
            else: 
                st.markdown(f"**(5) {specialty_list[0]} - Pie Chart in Channels**")
                row3_col1.plotly_chart(get_specialty_channel_hist(data, segment_val, specialty_list[0]), use_container_width=True)

        # Third Row, Second Column
        with row3_col2:
            data_ped = data[(data["specialty_code"] == specialty_list[1]) & 
                    (data["segment_value"].isin(segment_val))]
            if len(data_ped) == 0:
                st.markdown(f"**(6) {specialty_list[1]} - Pie Chart in Channels**")
                st.markdown(f'<p style="color:#FF5733 ;font-size:14px;"> NOTE. There is no data available. </p>', unsafe_allow_html=True)
            else: 
                st.markdown(f"**(6) {specialty_list[1]} - Pie Chart in Channels**")
                row3_col2.plotly_chart(get_specialty_channel_hist(data, segment_val, specialty_list[1]), use_container_width=True)
        
    else:
        st.markdown("[Note] The <Internal Channel Code> is not avilable to plot a channel Pie chart.")


def get_databricks_csv(base, exp_id, run_id, model_seg, file_name):
    """
    Returns:
        A csv file from Databrick given url
    """
    url = f"{base}/{exp_id}/{run_id}/artifacts/{model_seg}/{file_name}.csv"
    df = mlflow.artifacts.load_text(url)
    df = pd.read_csv(StringIO(df)) 
    del df['Unnamed: 0']
    return df

def get_pred_actual(df, col_actual, col_pred):
    """
    The actual and predicted plot
    Args:
        df (pd.DataFrame): Original dataframe
        col_actual: actual column string
        col_pred: predicted column string
    Returns:
        Line plot and difference dataframe in streamlit format
    """
    from datetime import datetime,date
    df['year_month'] = pd.to_datetime(df['year_month'], format = "%Y%m").dt.strftime('%Y-%m')
    df["diff"] = round(df[col_actual] - df[col_pred],1)

    col1, col2 = st.columns([3, 1])
    with col1:
        fig = go.Figure()
        fig.add_trace(go.Scatter(x=df["year_month"], y=df[col_actual], name = "value",
                        marker=dict(color="#578AFF"), showlegend=True))
        fig.add_trace(go.Scatter(x=df["year_month"], y=df[col_pred], name = "value_f_denorm",
                        marker=dict(color="red"),showlegend=True))
        fig.update_layout( title="The Predicted Vs Actual Plot",
            legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1))
        st.plotly_chart(fig, use_container_width=True)
    with col2:
        st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ diff = value - value_f_denorm </p>', unsafe_allow_html=True)
        st.dataframe(df[["year_month", "diff"]])


def get_overview_output_snowflake(data, irc, vc):
    """
    Basic information of the Response Curve output
    """
    spc = data['speciality_code'].unique().tolist()
    cc = data['channel_code'].unique().tolist()
    sgv = data['segment_value'].unique().tolist()
    sgc = data['segment_code'].unique().tolist()
    ts = data['created_ts'].unique().tolist()[0]

    c1_r1, c2_r1= st.columns(2)
    with c1_r1: 
        st.write(f'**‣ Data Created:** {ts}')
    with c2_r1: 
        st.write(f'**‣ Data Size**: {len(data):,}')
    c1_r2, c2_r2= st.columns(2)
    with c1_r2: 
        st.write(f'**‣ Speciality Code:** {", ".join(spc)}')
    with c2_r2: 
        st.write(f'**‣ Channel Code**: {", ".join(cc)}')
    c1_r3, c2_r3= st.columns(2)
    with c1_r3: 
        st.write(f'**‣ Segment Code:** {", ".join(sgc)}')
    with c2_r3: 
        st.write(f'**‣ Segment value**: {", ".join(sgv)}')
    c1_r4, c2_r4= st.columns(2)
    with c1_r4: 
        st.write(f'**‣ Version Code:** {vc}')
    with c2_r4: 
        st.write(f'**‣ Internal Response Code**: {irc}')
    st.dataframe(data)
    st.divider()

    return spc, cc, sgv, sgc, ts


def get_sales_spend_graph(data, col_x, col_y, metric_select_option, currency):
    """
    Generate gm_adjusted_incremental_value_sales vs spend plot
    """
    data_filtered = data[data["metric"] == metric_select_option]
    
    if len(data_filtered) > 0:
        value_1 = round(data_filtered[data_filtered["uplift"]==1].iloc[0][col_y])
        spend_1 = round(data_filtered[data_filtered["uplift"]==1].iloc[0][col_x])

        fig = px.line(data_filtered, x=col_x, 
                    y=col_y, 
                    # color = "segment_value",
                    # text="uplift",
                    title=f'{col_x.upper()} & {col_y.upper()} Plot ({currency})')
        fig.add_annotation(x=spend_1, y=value_1,
                    text=" Uplift 1 ",
                    showarrow=True,
                    font=dict(
                    size=16,
                    color="#7A00E6"
                    ),
                    arrowhead=2)
        fig.update_traces(textposition="bottom right")
        st.plotly_chart(fig, use_container_width=True)
        c1_r1, c2_r1= st.columns(2)
        with c1_r1: 
            st.metric(label=f"UPLIFT 1: {col_x.upper()}", value=f'{spend_1:,}')
        with c2_r1:
            st.metric(label=f"UPLIFT 1: {col_y.upper()}", value=f'{value_1:,}')
    else: 
        st.markdown(f'**<p style="color:#990000;font-size:20px;"> Not able to generate the Value & Spend Plot</p>**', unsafe_allow_html=True)



def additional_tables_channels(df_markets):
    """
    It returns two tables: 1) segment_code|segment_value|brand wise Metric values and 2) HCP covered by various 
    Selected options are: Market, Brand list, and Start/End date.
    """
    col_1, col_2, col_3 = st.columns([1,2,2])
    with col_1:
        market = st.selectbox("[Step 1.] Market:",df_markets['country_code'].unique().tolist(), index=4, key=2024)
    with col_2:
        sql_brand = f"SELECT distinct(brand_name) FROM MMX_DEV.DWH_MMX.DWH_PRODUCT_MASTER where country_code = '{market}';"
        df_brands = get_data_sql("DEV", sql_brand)
        brand_list = st.multiselect( "[Step 2.] Brand:", df_brands['brand_name'].unique().tolist(),df_brands['brand_name'].unique().tolist()[0])
        brand_list = ", ".join(f"'{s}'" for s in brand_list)
    with col_3:
        sql_channel = "SELECT distinct(to_varchar(period_start, 'YYYY-MM-DD')) as period_start FROM MMX_DEV.DWH_MMX.DWH_CHANNEL_FACTS;"
        df_temp = get_data_sql("DEV", sql_channel)
        start_period, end_period = st.select_slider(
        '[Step 3.] Range in <PERIOD_START>:',
        options=sorted(df_temp["period_start"].unique().tolist()),
        value=(df_temp["period_start"].min(), df_temp["period_start"].max()))

    st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ Market & Brand: MMX_DEV.DWH_MMX.DWH_PRODUCT_MASTER </p>', unsafe_allow_html=True)
    st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ Period Start: MMX_DEV.DWH_MMX.DWH_CHANNEL_FACTS </p>', unsafe_allow_html=True)
    
    tab1, tab2 = st.tabs(["(1-1) Brand Metric Value Distributions    ", 
                            "(1-2) HCP Reached by the Promotions"]) 
    with tab1:
        #st.markdown(f'**<p style="color:#af66f0;font-size:17px;"> (1-1) Brand Metric Value Distributions </p>**', unsafe_allow_html=True)
        sql_temp= query.get_query_tables("tab1", market, brand_list, start_period, end_period) 
        df_temp = get_data_sql("DEV", sql_temp)    
        st.dataframe(df_temp)
        with st.expander(">>> SQL"):
            st.markdown(sql_temp)

    with tab2:
        #st.markdown(f'**<p style="color:#af66f0;font-size:17px;"> (1-2) HCP Reached by the Promotions </p>**', unsafe_allow_html=True)
        st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ HCP reached (rating) by segments, count of hcp reached by various channels </p>', unsafe_allow_html=True)
    
        sql_temp= query.get_query_tables("tab2", market, brand_list, start_period, end_period) 
        df_temp = get_data_sql("DEV", sql_temp)    
        st.dataframe(df_temp)
        with st.expander(">>> SQL"):
            st.markdown(sql_temp)


def get_sales_hcp_coeff(selected_version_code, brand, market):
    """
    Given the selected version code along with a brand and market, it returns the sales per HCP and sales coefficients dataframes. 
    """
    col_1, col_2 = st.columns(2)
    with col_1: 
        sql_specialty = f"""SELECT * FROM MMX_DEV.DMT_MMX.SALES_ALLOCATION_COEFFICIENTS
                WHERE VERSION_CODE='{selected_version_code}'
                ORDER BY 4 DESC;
                """
        df = get_data_sql("DEV", sql_specialty)    
        specialty = st.radio("[Step 1.] Specialty Code:", df['specialty_code'].unique().tolist())

    with col_2:
        segment = st.radio("[Step 2.] Segment Code:", df['segment_code'].unique().tolist())

    tab1, tab2 = st.tabs(["(2-1) Sales per HCP",
                        "(2-2) Sales Allocation Coefficients"])
    with tab1:  
        #st.markdown(f'**<p style="color:#7A00E6;font-size:17px;"> (2-1) Sales per HCP </p>**', unsafe_allow_html=True)
        st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ The selected Version Code above: {selected_version_code} ({brand}, {market}) </p>', unsafe_allow_html=True)
        sql_concat = f"""SELECT CONCAT(SPECIALTY_CODE,'||',SEGMENT_VALUE_LOWER) AS SEGMENT,SUM(SALES_VALUE) AS SALES_VALUE_,SUM(NUM_HCP) AS NUM_HCP_,(SALES_VALUE_)/NULLIF(NUM_HCP_, 0) AS SALES_PER_HCP
                        FROM MMX_DEV.DMT_MMX.SALES_ALLOCATION
                        WHERE VERSION_CODE='{selected_version_code}' AND SPECIALTY_CODE = '{specialty}'
                            GROUP BY 1
                            ORDER BY 1,2,3;"""
        df_temp = get_data_sql("DEV", sql_concat) 
        st.dataframe(df_temp)
        with st.expander(">>> SQL"):
            st.markdown(sql_concat)

    with tab2:  
        #st.markdown(f'**<p style="color:#7A00E6;font-size:17px;"> (2-2) Sales Allocation Coefficients </p>**', unsafe_allow_html=True)
        st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ The selected Version Code: {selected_version_code} </p>', unsafe_allow_html=True)
        df_specialty = df[(df["specialty_code"] == specialty) & (df["segment_code"] == segment)]
        st.dataframe(df_specialty.sort_values(by=['year'], ascending=False))
        
        with st.expander(">>> SQL"):
            st.markdown(sql_specialty)

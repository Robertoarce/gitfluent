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

import yaml
from yaml import SafeLoader
import mlflow
from io import StringIO

import plotly.express as px 
import plotly.graph_objects as go
import snowflake.connector
from sqlalchemy import create_engine
from datetime import datetime
import warnings
warnings.simplefilter(action='ignore', category=FutureWarning)
import sys
sys.path.insert(0, '..')
import validation_utils as utils

# Change box color
utils.set_box()

# check password
st.image("logo.png", width = 160)
if not utils.check_password():
    st.stop()


##############################################################################
## TITLE
##############################################################################
st.markdown(f'**<p style="color:#5500a1;font-size:30px;"> :bow_and_arrow: RC | Output Validations </p>**', unsafe_allow_html=True)
st.markdown(f"""
* Snowflake:  Output validation features will be updated once output files are added in Snowflake.
* Databricks: The Run ID for analysis can be found in Databricks.  
""")
st.divider()

from mlflow.entities import ViewType
runs = mlflow.search_runs(
    experiment_ids=["2320504346335382"],
    run_view_type=ViewType.ALL,
)
print(runs)

##############################################################################
## OPTIONS 
##############################################################################
st.markdown(f'**<p style="color:#7A00E6;font-size:20px;"> 1. Please Select the Output Source. </p>**', unsafe_allow_html=True)
source = st.radio("[Step 1.] Snowflake Environment:", ('Snowflake', 'Databricks',), )

##############################################################################
## Source: Snowflake 
##############################################################################
if source == "Snowflake": 
    st.markdown(f'**<p style="color:#7A00E6;font-size:20px;"> ‣ Please Select the Following Options. </p>**', unsafe_allow_html=True)
    col_1, col_2 = st.columns(2)
    with col_1:
        sql = f"SELECT distinct(market_code) FROM MMX_DEV.DMT_MMX.RESPONSE_CURVE;"
        data = utils.get_data_sql("DEV", sql)
        market = st.selectbox( "[Step 1.] Market:",data['market_code'].unique().tolist(), index=4)
    with col_2:
        sql = f"SELECT distinct(brand_name) FROM MMX_DEV.DMT_MMX.RESPONSE_CURVE where market_code ='{market}';"
        data = utils.get_data_sql("DEV", sql)
        data = data[~data["brand_name"].isin(["MEDICINE1", "MEDICINE2", "MedicineA", "Vaccine 1", "Product B"])]
        brand = st.selectbox( "[Step 2.] Brand:", data['brand_name'].unique().tolist())
    col_1, col_2 = st.columns(2)
    with col_1:
        sql = f"SELECT distinct(version_code) FROM MMX_DEV.DMT_MMX.RESPONSE_CURVE where market_code ='{market}' AND brand_name = '{brand}';"
        data = utils.get_data_sql("DEV", sql)
        vc = st.selectbox( "[Step 3.] Version Code:", sorted(data['version_code'].unique().tolist(), reverse=True))
    with col_2:
        sql = f"SELECT distinct(internal_response_code) FROM MMX_DEV.DMT_MMX.RESPONSE_CURVE where market_code ='{market}' AND brand_name = '{brand}' AND version_code='{vc}';"
        data = utils.get_data_sql("DEV", sql)
        irc = st.selectbox( "[Step 4.] Internal Response Code:", data['internal_response_code'].unique().tolist())
    st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ [MAIN SOURCES]: MMX_DEV.DMT_MMX.RESPONSE_CURVE</p>', unsafe_allow_html=True)
    st.divider()
    ##############################################################################
    ## I. Overview 
    ##############################################################################
    st.markdown(f'**<p style="color:#5500a1;font-size:30px;"> I. An Overview of the Selected Options</p>**', unsafe_allow_html=True)
    sql = f"SELECT * FROM MMX_DEV.DMT_MMX.RESPONSE_CURVE where market_code ='{market}' AND brand_name = '{brand}' AND version_code = '{vc}' AND internal_response_code = '{irc}';"
    data = utils.get_data_sql("DEV", sql)
    spc, cc, sgv, sgc, ts = utils.get_overview_output_snowflake(data, irc, vc)

    ##############################################################################
    ## II. Analysis
    ##############################################################################
    st.markdown(f'**<p style="color:#5500a1;font-size:30px;"> II. An Analysis of Output</p>**', unsafe_allow_html=True)
    st.markdown(f'**<p style="color:#7A00E6;font-size:20px;"> ‣ Please Select the Following Options. </p>**', unsafe_allow_html=True)


    col_1, col_2, col_3 = st.columns(3)
    with col_1:
        spc_select = st.selectbox( "[Step 1.] Speciality Code:", spc)
    with col_2:
        sgv_select = st.selectbox( "[Step 2.] Segment Value:", sgv)
    with col_3:
        cc_select = st.selectbox( "[Step 3.] Channel Code:", cc)

    data = data[(data["speciality_code"] == spc_select) &
                (data["segment_value"] == sgv_select) &
                (data["channel_code"] == cc_select)]
    with st.expander(">>> DataFrame"):
        st.dataframe(data)

    # generate the value & spend plot
    currency = data[data["metric"] == "currency"]['value'].unique().tolist()[0]
    metric_list = data["metric"].unique().tolist()
    metric_list.remove('currency')
    numeric_cols = data.select_dtypes(include=np.number).columns.tolist()
    numeric_cols = [col for col in numeric_cols if col != 'uplift']
    col_1, col_2, col_3 = st.columns(3)
    with col_1:
        metric_select_option = st.radio( "[Step 1.] Please select the metric to filter the data first.", metric_list)
    with col_2: 
        x = st.radio( "[Step 2.] Select the SPEND Column",numeric_cols)  # gm_adjusted_incremental_value_sales
    with col_3: 
        numeric_cols = [col for col in numeric_cols if col != x]
        y = st.radio( "[Step 3.] Select the VALUE Column", sorted(numeric_cols, reverse=True)) 
    try:
        utils.get_sales_spend_graph(data, x, y, metric_select_option, currency)
    except:
        st.markdown(f'**<p style="color:#990000;font-size:20px;"> Not able to generate the Value & Spend Plot. Please try a different metric.</p>**', unsafe_allow_html=True)
        st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ Ex) spend & gm_adjusted_incremental_value_sales </p>', unsafe_allow_html=True)


##############################################################################
## Source: Snowflake 
##############################################################################
elif source == "Databricks":
    st.markdown(f'**<p style="color:#7A00E6;font-size:20px;"> 2. Please Select the Following IDs. </p>**', unsafe_allow_html=True)
    try:
        col_1, col_2 = st.columns(2)
        with col_1:
            exp_id = st.text_input(
            "The Experiment ID",
            "2320504346335382",
            key="2320504346335382")
        with col_2:
            run_id = st.text_input(
                "The Run ID",
                "061483035add4b87974014c544d890ad",
                key="061483035add4b87974014c544d890ad")
        url_yml = f"dbfs:/databricks/mlflow-tracking/{exp_id}/{run_id}/artifacts/model_config.yaml"
        config = mlflow.artifacts.load_text(url_yml)
        config_dict=yaml.load(config, Loader=SafeLoader)
    except:
        st.error("Please enter a valid input")

    with st.expander("Information of Experiment IDs & Run IDs"):
            st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ [MMX]: Experiment ID - 2320504346335382 & Run ID - 061483035add4b87974014c544d890ad</p>', unsafe_allow_html=True)
            st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ [GenMed]: Experiment ID - 2768497519166406 & Run ID - 9e3f5008e7c54873b663b9cd500050e6</p>', unsafe_allow_html=True)
            st.markdown(f'<p style="color:#808B96;font-size:14px;"> ‣ [Vaccine]: Experiment ID - 4139385166913258 & Run ID - cf8e7dbc77dd456eb7feee2f21d9b411, 509b452259f5458eb3ab73b42dc9d4e7 (for multiple segments) </p>', unsafe_allow_html=True)
            """
            [MMX Databricks Experiments](https://sanofi-oneai-emea-prod.cloud.databricks.com/?o=3601573116687247#)
            """
        
    ##############################################################################
    ## I. Overview 
    ##############################################################################
    st.markdown(f'**<p style="color:#5500a1;font-size:30px;"> I. An Overview of the Config File</p>**', unsafe_allow_html=True)
    BRAND_NAME = config_dict["BRAND_NAME"]
    COUNTRY_CODE = config_dict["COUNTRY_CODE"]
    VERSION_CODE = config_dict["VERSION_CODE"]
    RESPONSE_CURVE_YEARS = config_dict["RESPONSE_CURVE_YEARS"][0]    
    base = "dbfs:/databricks/mlflow-tracking"
    model_seg_list = list(config_dict["STAN_PARAMETERS"]["channels"].keys())
    col_list = ["value"] + list(config_dict["STAN_PARAMETERS"]["predictor_parameters"].keys())

    st.markdown(f"""
    - **{BRAND_NAME}** in **{COUNTRY_CODE}** with the Version Code, *{VERSION_CODE}*. 
    - **Model Segment:** {model_seg_list}
    - **RESPONSE_LEVEL:** {', '.join(config_dict["RESPONSE_LEVEL"])}
    - **Model Type**: {config_dict["model_type"]}
    - **RESPONSE_CURVE_YEARS**: {RESPONSE_CURVE_YEARS}
    """) 

    with st.expander(">>> See the Config File"):
        tab1, tab2, tab3 = st.tabs(["STAN_MODEL_PARAMETERS", "STAN_PARAMETERS", "The Full Config"])
        with tab1: 
            st.write(config_dict["STAN_MODEL_PARAMETERS"])
        with tab2:
                st.write(config_dict["STAN_PARAMETERS"])
        with tab3:
            for key, item in config_dict.items():
                st.write(key, item)
                st.write("")

    ##############################################################################
    ## II. RC  
    ##############################################################################
    st.markdown(f'**<p style="color:#5500a1;font-size:30px;"> II. An Overview of the Response Curves</p>**', unsafe_allow_html=True)
    try:
        url_img = f"dbfs:/databricks/mlflow-tracking/{exp_id}/{run_id}/artifacts/joint_response_revenues_ros_{BRAND_NAME}_{RESPONSE_CURVE_YEARS}.png"
        url_img_png = mlflow.artifacts.load_image(url_img)
        st.image(url_img_png)
    except:
        st.markdown(f'**<p style="color:#990000;font-size:20px;"> There is no Response Curve Plot in the Databricks artifacts folder. </p>**', unsafe_allow_html=True)

    ##############################################################################
    ## III. Features 
    ##############################################################################
    st.markdown(f'**<p style="color:#5500a1;font-size:30px;"> III. An Overview of the FEATURES_DF</p>**', unsafe_allow_html=True)
    for model_seg in model_seg_list:
        st.markdown(f'**<p style="color:#7A00E6;font-size:17px;"> ‣ {model_seg} </p>**', unsafe_allow_html=True)
        df_features = utils.get_databricks_csv(base, exp_id, run_id, model_seg, 'features_df')   

        df_features.rename(columns = {"year_month" : "period_start"}, inplace=True)
        utils.get_features_df(df_features, col_list)
        with st.expander(">>> DataFrame: df_features"):
            st.dataframe(df_features)
        st.divider()

    ##############################################################################
    ## IIII. Metrics
    ##############################################################################
    st.markdown(f'**<p style="color:#5500a1;font-size:30px;"> IV. An Overview of All Metrics</p>**', unsafe_allow_html=True)

    for model_seg in model_seg_list:
        st.markdown(f'**<p style="color:#7A00E6;font-size:17px;"> ‣ {model_seg} </p>**', unsafe_allow_html=True)
        with st.expander(">>> Post-processing Metrics"):
            tab1, tab2, tab3, tab4, tab5 = st.tabs(["Durbin Watson", 
                                                    "Regression Metrics", 
                                                    "Response Curve Metric",
                                                    "VIF Summary",
                                                    "P-values"])
            with tab1: 
                st.dataframe(utils.get_databricks_csv(base, exp_id, run_id, model_seg, 'durbin_watson'))
            with tab2:
                st.dataframe(utils.get_databricks_csv(base, exp_id, run_id, model_seg, 'regression_metrics'))
            with tab3:
                st.dataframe(utils.get_databricks_csv(base, exp_id, run_id, model_seg, 'response_curve_metric'))
            with tab4:
                st.dataframe(utils.get_databricks_csv(base, exp_id, run_id, model_seg, "vif_summary_"+model_seg))
            with tab5:
                st.dataframe(utils.get_databricks_csv(base, exp_id, run_id, model_seg, "params_p_value_summary_"+model_seg))
            
        st.divider()
        
    ##############################################################################
    ## IV. Performance
    ##############################################################################
    st.markdown(f'**<p style="color:#5500a1;font-size:30px;"> V. An Overview of Performance</p>**', unsafe_allow_html=True)

    for model_seg in model_seg_list:
        st.markdown(f'**<p style="color:#7A00E6;font-size:17px;"> ‣ {model_seg} </p>**', unsafe_allow_html=True)
        df = utils.get_databricks_csv(base, exp_id, run_id, model_seg, 'pred_vs_actual_df')
        utils.get_pred_actual(df, "value", "value_f_denorm")
        with st.expander(">>> Predicted vs Actual DataFrame"):
            st.dataframe(df)
   

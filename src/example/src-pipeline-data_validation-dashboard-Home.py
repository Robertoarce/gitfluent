import streamlit as st # sqlalchemy
from streamlit_elements import elements, mui, html, sync,editor, lazy,nivo # pip install streamlit_elements
import pandas as pd 
import numpy as np
import plotly.express as px  # pip install plotly-express
import snowflake.connector
from sqlalchemy import create_engine
from validation_utils import check_password
import os
import validation_utils as utils

# Reload ENV file 
try:
  from dotenv import load_dotenv
  load_dotenv(override=False)
except ModuleNotFoundError:
  pass
# st.markdown(os.environ)

##############################################################################
# SETTINGS
##############################################################################
utils.set_page()
utils.set_box()
st.image("logo.png", width = 160)

if check_password():    
    st.title(":chart_with_upwards_trend: [MMX] Data Validation Dashboard")
    st.divider()

    """
    ### What are included:

    - RC | Input Validation 
    - RC | Output Validation - To be updated!
    - Model Comparisons - To be updated!

    ### Links:

    - [MMX Confluence Page](https://sanofi.atlassian.net/wiki/spaces/MMX001/pages/63900975421/Data+Science)
    - [MMX Scrum Board](https://sanofi.atlassian.net/jira/software/c/projects/MMX001/boards/3563)
    - [MMX Github oneai-com-turing-prj0060690_mmx](https://github.com/Sanofi-OneAI/oneai-com-turing-prj0060690_mmx)
    - [MMX Databricks Experiments](https://sanofi-oneai-emea-prod.cloud.databricks.com/?o=3601573116687247#mlflow/experiments)

    """

    """
    ✉️ Please contact for any inquiries, jeeyoung.lee@sanofi.com
    """
"""Main Base class for entire library
"""
import warnings

import pandas as pd
from turing_generic_lib.utils.logging import get_logger

from turing_sales_allocation.constants.constants_base import DT_FORMAT, PROJECT_NAME

warnings.filterwarnings("ignore")


class SalesAllocationMainBase:
    """
    Sales Allocation main base class
    """

    def __init__(self, country, usecase):
        self.country = country
        self.use_case = usecase
        self.snowflake_con = None
        self.sales_allocation_df = None
        self.logger_obj = get_logger(PROJECT_NAME)
        self.all_params = {}
        self.date_params = {}

    def set_date_params(self, params: dict) -> None:
        """[Set the date params dictionary]
        Arguments:
            params {dict} -- [date parameters to be passed]
        """
        self.date_params = params

    def set_all_params(self, config_params: dict) -> None:
        """[Set the code config params dictionary]
        Arguments:
            config_params {dict} -- [code config parameters to be passed]
        """
        self.all_params = config_params

    def set_snowflake_connection(self, snowflake_connection: object) -> None:
        """[Set the snowflake connection object]
        Arguments:
            snowflake_connection {object} -- [snowflake connection object to be passed]
        """
        self.snowflake_con = snowflake_connection

    def add_datetime_column_in_df(
            self, df_input: pd.DataFrame) -> pd.DataFrame:
        """Add Datetime column in a DataFrame
        Arguments:
            df_input {pd.DataFrame} -- Input DataFrame
        Returns:
            pd.DataFrame -- Output DataFrame
        """
        df_input["MRDS_CREATED_DATE_TIME"] = pd.to_datetime("now")
        df_input["MRDS_CREATED_DATE_TIME"] = df_input["MRDS_CREATED_DATE_TIME"].dt.tz_localize(
            "UTC")
        self.logger_obj.info("DateTime Column Added")
        return df_input

    def replace_sql_identifiers(
        self,
        query: str,
    ):
        """Global SQL Constants Replacer
        Arguments:
            query {str} -- SQL Query string
        Returns:
            [str] -- SQL Query string
        """
        query = query.replace("COUNTRY_NAME", f"'{self.country}'")
        brand_list = ",".join(
            f"{dt_s}" for dt_s in self.all_params["BRAND_LIST"])
        query = query.replace("BRAND_LIST", f"'{brand_list}'")
        query = query.replace("DT_FORMAT", f"'{DT_FORMAT}'")
        return query

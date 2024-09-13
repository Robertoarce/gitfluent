"""Contains the flow of Execution for JAPAN(JP).
Has Classes and functions associated for the same.
"""
import warnings

import pandas as pd
# from turing_sales_allocation.constants.constants_base import HCP_UNIVERSE_DATA_PATH
from turing_sales_allocation.constants.constants_jp import (
    SALES_ALLOCATION_DATA_PATH
)
from turing_sales_allocation.mrds.sales_allocation_country_base import SalesAllocationCountryBase
from turing_sales_allocation.utils.data_utils import (
    get_first_row_on_group,
    impute_column,
    pivot_column_group,
    replace_space_col_name,
    select_and_dropna_on_cols,
    null_outlier_treatment,
)

warnings.filterwarnings("ignore")


class SalesAllocationJP(SalesAllocationCountryBase):
    """
    Sales Allocation for JAPAN(JP) class
    """

    def __init__(self, usecase, all_params: dict):
        super().__init__("JAPAN", usecase)
        self.all_params = all_params

    def get_sales_allocation_mrds(self) -> pd.DataFrame:
        """Get the Sales Allocation MRDS DataFrame for JAPAN(JP)

        Returns:
            pd.DataFrame -- DataFrame
        """
        if self.snowflake_con is None:
            self.logger_obj.error(
                "Snowflake connection is not set. Kindly set "
                "the snowflake connection by calling "
                "set_snowflake_connection(params) method"
            )
            raise ValueError("Snowflake connection is not set")
        if len(self.date_params) == 0:
            self.logger_obj.error(
                "Date params is not set. Kindly set "
                "the date params by calling "
                "set_date_params(params) method"
            )
            raise ValueError("Date params is not set")

        self.logger_obj.info(f"Country : {self.country}")
        self.logger_obj.info(f"Use case : {self.use_case}")
        self.logger_obj.info("Sales Allocation MRDS creation in progress")

        # Get Sales allocation Data
        df_master = self.get_data_from_sql(SALES_ALLOCATION_DATA_PATH)
        self.logger_obj.info(
            f"Function get_data_from_sql to get the SALES ALLOCATION DATFARAME output with shape : {df_master.shape}"
        )

        # Select and Drop NA on Columns
        df_master = select_and_dropna_on_cols(
            df_master,
            self.all_params["OUTPUT_COLUMNS"],
            self.all_params["DROP_NULL_COL"])
        self.logger_obj.info(
            f"Function select_and_dropna_on_cols to select the required columns and filter the data before getting top row with shape : {df_master.shape}"
        )

        # Getting rid of outliers & null values in target column.
        df_master = null_outlier_treatment(
            df_master.copy(), self.all_params["IMPUTE_TARGET_COL"])
        self.logger_obj.info(
            f"Function null_outlier_treatment to treat the null values & outliers in AGG_SALES column with shape : {df_master.shape}"
        )

        # Add extra columns to identify the data
        df_master = self.add_datetime_column_in_df(df_master.copy())
        print(len(df_master.columns))
        df_master["COUNTRY"] = self.country
        self.logger_obj.info(
            f"Sales Allocation for {self.country} with shape of {df_master.shape} is created."
        )
        df_master = replace_space_col_name(df_master.copy())
        self.sales_allocation_df = df_master.copy()
        return df_master.copy()

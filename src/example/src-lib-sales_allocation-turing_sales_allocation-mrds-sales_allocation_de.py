"""Contains the flow of Execution for GERMANY(DE).
Has Classes and functions associated for the same.
"""
import warnings

import pandas as pd
from turing_sales_allocation.constants.constants_base import HCP_UNIVERSE_DATA_PATH
from turing_sales_allocation.constants.constants_de import (
    HCP_ADOPTION_DATA_PATH,
    HCP_AGE_DATA_PATH,
    HCP_AREA_DATA_PATH,
    HCP_SPECIALITY_DATA_PATH,
    SALES_DATA_PATH,
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


class SalesAllocationDE(SalesAllocationCountryBase):
    """
    Sales Allocation for GERMANY(DE) class
    """

    def __init__(self, usecase, all_params: dict):
        super().__init__("GERMANY", usecase)
        self.all_params = all_params

    def get_sales_allocation_mrds(self) -> pd.DataFrame:
        """Get the Sales Allocation MRDS DataFrame for GERMANY(DE)

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

        # Get HCP Universe data
        df_germany = self.get_data_from_sql(HCP_UNIVERSE_DATA_PATH)
        self.logger_obj.info(
            f"Function get_data_from_sql to get the HCP UNIVERSE DataFrame output with shape : {df_germany.shape}"
        )

        # Get HCP Adoption Ladder data
        df_germany = self.get_data_from_sql(
            HCP_ADOPTION_DATA_PATH,
            df_germany,
            "left",
            self.all_params["HCP_KEY"])
        self.logger_obj.info(
            f"Function get_data_from_sql to get the HCP ADOPTION DataFrame output with shape : {df_germany.shape}"
        )
        # Get HCP Speciality data
        df_germany = self.get_data_from_sql(
            HCP_SPECIALITY_DATA_PATH,
            df_germany.copy(),
            "left",
            self.all_params["HCP_KEY"])
        self.logger_obj.info(
            f"Function get_data_from_sql to get the HCP SPECIALITY DataFrame output with shape : {df_germany.shape}"
        )

        # Get HCP Age data
        df_germany = self.get_data_from_sql(
            HCP_AGE_DATA_PATH,
            df_germany.copy(),
            "left",
            self.all_params["HCP_KEY"])
        self.logger_obj.info(
            f"Function get_data_from_sql to get the HCP AGE DataFrame output with shape : {df_germany.shape}"
        )

        # Get Sales Area data
        df_germany = self.get_data_from_sql(
            HCP_AREA_DATA_PATH,
            df_germany.copy(),
            "left",
            self.all_params["HCP_KEY"])
        self.logger_obj.info(
            f"Function get_data_from_sql to get the HCP AREA DataFrame output with shape : {df_germany.shape}"
        )

        # Impute the columns with required values
        df_germany = impute_column(
            df_germany.copy(),
            self.all_params["IMPUTE_COLUMNS"])
        self.logger_obj.info(
            f"Function impute_column to impute the columns with required values DataFrame output with shape : {df_germany.shape}"
        )

        # Select and Drop NA on Columns
        df_germany = select_and_dropna_on_cols(
            df_germany.copy(),
            self.all_params["OUTPUT_COLUMNS"],
            self.all_params["DROP_NULL_COL"])
        self.logger_obj.info(
            f"Function select_and_dropna_on_cols to select the required columns and filter the data before getting top row with shape : {df_germany.shape}"
        )

        # Get the first row per group to remove duplicate
        df_germany = get_first_row_on_group(
            df_germany.copy(),
            self.all_params["TOP_ROW_REMOVE_DUPLICATE"]["PARTITION_BY"],
            self.all_params["TOP_ROW_REMOVE_DUPLICATE"]["ORDER_BY"],
        )
        self.logger_obj.info(
            f"Function get_first_row_on_group to get the first row per group on DataFrame to remove duplicate with shape : {df_germany.shape}"
        )

        # Pivot
        df_germany = pivot_column_group(
            df_germany.copy(),
            self.all_params["SALES_JOIN_KEY"],
            self.all_params["COMBINATION_FEATURE_LIST"],
            self.all_params["HCP_KEY"][0],
        )
        self.logger_obj.info(
            f"Function impute_column to pivot DataFrame output with shape : {df_germany.shape}"
        )

        # Get Sales at Area level data
        df_germany = self.get_data_from_sql(
            SALES_DATA_PATH,
            df_germany.copy(),
            "left",
            self.all_params["SALES_JOIN_KEY"])
        self.logger_obj.info(
            f"Function get_data_from_sql to get the HCP AREA SALES DataFrame output with shape : {df_germany.shape}"
        )

        # Getting rid of outliers & null values in target column.
        df_germany = null_outlier_treatment(
            df_germany.copy(), self.all_params["IMPUTE_TARGET_COL"])
        self.logger_obj.info(
            f"Function null_outlier_treatment to treat the null values & outliers in AGG_SALES column with shape : {df_germany.shape}"
        )

        # Add extra columns to identify the data
        df_germany = self.add_datetime_column_in_df(df_germany.copy())

        df_germany["COUNTRY"] = self.country
        self.logger_obj.info(
            f"Sales Allocation for {self.country} with shape of {df_germany.shape} is created."
        )
        df_germany = replace_space_col_name(df_germany.copy())
        self.sales_allocation_df = df_germany.copy()
        return df_germany.copy()

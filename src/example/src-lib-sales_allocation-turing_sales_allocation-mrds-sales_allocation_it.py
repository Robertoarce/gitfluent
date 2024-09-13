"""Contains the flow of Execution for ITALY(IT).
Has Classes and functions associated for the same.
"""
import warnings

import pandas as pd
from turing_sales_allocation.constants.constants_base import HCP_UNIVERSE_DATA_PATH
from turing_sales_allocation.constants.constants_it import (
    HCP_ADOPTION_DATA_PATH,
    HCP_AGE_DATA_PATH,
    HCP_AREA_DATA_PATH,
    HCP_POTENTIAL_DATA_PATH,
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


class SalesAllocationIT(SalesAllocationCountryBase):
    """
    Sales Allocation for ITALY(IT) class
    """

    def __init__(self, usecase, all_params: dict):
        super().__init__("ITALY", usecase)
        self.all_params = all_params

    def get_sales_allocation_mrds(self) -> pd.DataFrame:
        """Get the Sales Allocation MRDS DataFrame for ITALY(IT)

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
        df_italy = self.get_data_from_sql(HCP_UNIVERSE_DATA_PATH)
        self.logger_obj.info(
            f"Function get_data_from_sql to get the HCP UNIVERSE DataFrame output with shape : {df_italy.shape}"
        )

        # Get HCP Adoption Ladder data
        df_italy = self.get_data_from_sql(
            HCP_ADOPTION_DATA_PATH,
            df_italy,
            "left",
            self.all_params["HCP_KEY"])
        self.logger_obj.info(
            f"Function get_data_from_sql to get the HCP ADOPTION DataFrame output with shape : {df_italy.shape}"
        )

        # Get HCP Speciality data
        df_italy = self.get_data_from_sql(
            HCP_SPECIALITY_DATA_PATH,
            df_italy.copy(),
            "left",
            self.all_params["HCP_KEY"])
        self.logger_obj.info(
            f"Function get_data_from_sql to get the HCP SPECIALITY DataFrame output with shape : {df_italy.shape}"
        )

        # Get HCP Potential data
        df_italy = self.get_data_from_sql(
            HCP_POTENTIAL_DATA_PATH,
            df_italy.copy(),
            "left",
            self.all_params["HCP_KEY"])
        self.logger_obj.info(
            f"Function get_data_from_sql to get the HCP POTENTIAL DataFrame output with shape : {df_italy.shape}"
        )

        # Get HCP Age data
        df_italy = self.get_data_from_sql(
            HCP_AGE_DATA_PATH,
            df_italy.copy(),
            "left",
            self.all_params["HCP_KEY"])
        self.logger_obj.info(
            f"Function get_data_from_sql to get the HCP AGE DataFrame output with shape : {df_italy.shape}"
        )

        # Get Sales Area data
        df_italy = self.get_data_from_sql(
            HCP_AREA_DATA_PATH,
            df_italy.copy(),
            "left",
            self.all_params["HCP_KEY"])
        self.logger_obj.info(
            f"Function get_data_from_sql to get the HCP AREA DataFrame output with shape : {df_italy.shape}"
        )

        # Impute the columns with required values
        df_italy = impute_column(
            df_italy.copy(),
            self.all_params["IMPUTE_COLUMNS"])
        self.logger_obj.info(
            f"Function impute_column to impute the columns with required values DataFrame output with shape : {df_italy.shape}"
        )

        # Select and Drop NA on Columns
        df_italy = select_and_dropna_on_cols(
            df_italy.copy(),
            self.all_params["OUTPUT_COLUMNS"],
            self.all_params["DROP_NULL_COL"])
        self.logger_obj.info(
            f"Function select_and_dropna_on_cols to select the required columns and filter the data before getting top row with shape : {df_italy.shape}"
        )

        # Get the first row per group to remove duplicate
        df_italy = get_first_row_on_group(
            df_italy.copy(),
            self.all_params["TOP_ROW_REMOVE_DUPLICATE"]["PARTITION_BY"],
            self.all_params["TOP_ROW_REMOVE_DUPLICATE"]["ORDER_BY"],
        )
        self.logger_obj.info(
            f"Function get_first_row_on_group to get the first row per group on DataFrame to remove duplicate with shape : {df_italy.shape}"
        )

        # Pivot
        df_italy = pivot_column_group(
            df_italy.copy(),
            self.all_params["SALES_JOIN_KEY"],
            self.all_params["COMBINATION_FEATURE_LIST"],
            self.all_params["HCP_KEY"][0],
        )
        self.logger_obj.info(
            f"Function pivot_column_group to pivot DataFrame output with shape : {df_italy.shape}"
        )

        # Get Sales at Area level data
        df_italy = self.get_data_from_sql(
            SALES_DATA_PATH,
            df_italy.copy(),
            "left",
            self.all_params["SALES_JOIN_KEY"])
        self.logger_obj.info(
            f"Function get_data_from_sql to get the HCP AREA SALES DataFrame output with shape : {df_italy.shape}"
        )

        # Getting rid of outliers & null values in target column.
        df_italy = null_outlier_treatment(
            df_italy.copy(), self.all_params["IMPUTE_TARGET_COL"])
        self.logger_obj.info(
            f"Function null_outlier_treatment to treat the null values & outliers in AGG_SALES column with shape : {df_italy.shape}"
        )

        # Add extra columns to identify the data
        df_italy = self.add_datetime_column_in_df(df_italy.copy())
        print(len(df_italy.columns))
        df_italy["COUNTRY"] = self.country
        self.logger_obj.info(
            f"Sales Allocation for {self.country} with shape of {df_italy.shape} is created."
        )
        df_italy = replace_space_col_name(df_italy.copy())
        self.sales_allocation_df = df_italy.copy()
        return df_italy.copy()

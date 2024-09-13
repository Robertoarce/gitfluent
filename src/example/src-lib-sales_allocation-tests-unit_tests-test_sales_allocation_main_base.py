"""
Tests functionality of crrc_main_base.py
"""
from unittest import TestCase

import pandas as pd
import pandas.testing as pd_testing
from turing_sales_allocation.sales_allocation_main_base import SalesAllocationMainBase


code_params = {
    "BRAND_LIST": "TOUJEO",
    "HCP_KEY": "HCP_ID",
    "SALES_JOIN_KEY": [
        "BRICK_CD",
        "BRAND_NM"],
    "IMPUTE_COLUMNS": {
        "ADOPTION_LEVEL": "NO",
        "POTENTIAL_LEVEL": "NOT",
        "SPECIALITY_NM": "OTHERS",
        "SPECIALITY_NM_2": "OTHERS",
    },
    "IMPUTE_TARGET_COL": {
        "TARGET_COL": "AGG_SALES",
        "QUANTILE": 0.98,
        "VALUE": 10},
    "TOP_ROW_REMOVE_DUPLICATE": {
        "PARTITION_BY": "HCP_ID",
        "ORDER_BY": {
                        "ADOPTION_LEVEL": True,
                        "POTENTIAL_LEVEL": True},
    },
    "OUTPUT_COLUMNS": [
        "HCP_ID",
        "BRICK_CD",
        "BRAND_NM",
        "ADOPTION_LEVEL",
        "SPECIALITY_NM",
        "SPECIALITY_NM_2",
        "AGE_BIN",
        "POTENTIAL_LEVEL",
    ],
    "DROP_NULL_COL": "BRICK_CD",
    "COMBINATION_FEATURE_LIST": [
        "ADOPTION_LEVEL",
        "AGE_BIN",
        "POTENTIAL_LEVEL",
        "SPECIALITY_NM",
        "SPECIALITY_NM_2",
        "ADOPTION_LEVEL",
        "AGE_BIN",
        "ADOPTION_LEVEL",
        "POTENTIAL_LEVEL",
        "ADOPTION_LEVEL",
        "SPECIALITY_NM",
    ],
}


class TestSalesAllocationMainBase(TestCase):
    """
    Class to test sales_allocation_main_base.py functions
    """

    def assert_dataframe_equal(self, input_df, expected_df, msg):
        """
        Checks if two dataframes are equal
        """
        try:
            pd_testing.assert_frame_equal(input_df, expected_df)
        except AssertionError as err:
            raise self.failureException(msg) from err

    def test_add_datetime_column_in_df(self):
        """
        Tests the get_add_months function
        """
        df_sample = pd.DataFrame(
            {"DATE_TIME_CREATION": ["2022-11-02 06:02:28.820035+00:00"]})
        sales_allocation_obj = SalesAllocationMainBase(
            "IT", "sales_allocation")
        df_final = sales_allocation_obj.add_datetime_column_in_df(df_sample)
        df_col = len(df_final.columns)
        column_count = 2
        self.assertEqual(df_col, column_count)

    def test_replace_sql_identifiers(self):
        """
        Tests the get_add_months function
        """
        query_sample = "Test for COUNTRY_NAME and BRAND_LIST with DT_FORMAT"
        query_sample_output = "Test for 'IT' and 'T,O,U,J,E,O' with 'YYYY-MM-DD'"
        sales_allocation_obj = SalesAllocationMainBase(
            "IT", "sales_allocation")
        sales_allocation_obj.all_params = code_params
        df_final = sales_allocation_obj.replace_sql_identifiers(query_sample)
        print(str(df_final))
        print(query_sample_output)
        self.assertIn(str(df_final), query_sample_output)

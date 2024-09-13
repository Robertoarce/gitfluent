from unittest import TestCase
from unittest.mock import patch

import pandas as pd
from turing_sales_allocation.mrds.sales_allocation_it import SalesAllocationIT


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
                                [
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
                                ]],
}


class TestSalesAllocationIT(TestCase):
    """Test Case Class for testing Sales Allocation IT Class"""

    @patch("turing_sales_allocation.mrds.sales_allocation_it.SalesAllocationIT."
           "get_data_from_sql")
    @patch("turing_sales_allocation.mrds.sales_allocation_it.get_first_row_on_group")
    @patch("turing_sales_allocation.mrds.sales_allocation_it.impute_column")
    @patch("turing_sales_allocation.mrds.sales_allocation_it.pivot_column_group")
    @patch("turing_sales_allocation.mrds.sales_allocation_it.replace_space_col_name")
    @patch("turing_sales_allocation.mrds.sales_allocation_it.select_and_dropna_on_cols")
    @patch("turing_sales_allocation.mrds.sales_allocation_it.null_outlier_treatment")
    def test_get_sales_allocation_mrds(
        self,
        mock_null_outlier_treatment,
        mock_select_and_dropna_on_cols,
        mock_replace_space_col_name,
        mock_pivot_column_group,
        mock_impute_column,
        mock_get_first_row_on_group,
        mock_get_data_from_sql,
    ):
        """
        Tests the function get_sales_allocation_mrds that generated mrds for Italy.
        """
        input_df = pd.DataFrame(
            [
                ("TOUJEO", "ITALY", 186),
                ("SOLIQUA", "GERMANY", 202),
                ("SULIQUA", "US", 304),
                ("SULIQUA", "KOREA", 210),
                ("TOUJEO", "JAPAN", 218),
                ("TOUJEO", "ITALY-WEST", 270),
                ("SULIQUA", "US-EAST", 188),
            ],
            columns=("Brand", "Country", "Sales"),
        )
        mock_get_data_from_sql.return_value = input_df
        sales_allocation_mrds = SalesAllocationIT(
            "sales_allocation", code_params)
        sales_allocation_mrds.snowflake_con = ""
        sales_allocation_mrds.date_params = ["", ""]
        sales_allocation_mrds.get_sales_allocation_mrds()

        mock_null_outlier_treatment.assert_called()
        mock_pivot_column_group.assert_called()
        mock_select_and_dropna_on_cols.assert_called()
        mock_get_first_row_on_group.assert_called()
        mock_impute_column.assert_called()
        mock_replace_space_col_name.assert_called()

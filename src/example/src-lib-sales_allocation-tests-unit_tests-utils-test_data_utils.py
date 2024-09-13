from unittest import TestCase

import pandas as pd
from turing_sales_allocation.utils import data_utils


class TestDataUtils(TestCase):
    def test_impute_column(self):
        input_df = pd.DataFrame(
            {
                "BRAND": ["TOUJEO", "SOLIQUA", "SULIQUA"],
                "INDEX": [10, None, 25],
                "SALES": [None, 1243, 978],
            }
        )
        impute_dict = {"INDEX": "OTHER", "SALES": 555}
        result = data_utils.impute_column(input_df, impute_dict)
        expected_output = pd.DataFrame(
            {
                "BRAND": ["TOUJEO", "SOLIQUA", "SULIQUA"],
                "INDEX": [10, "OTHER", 25],
                "SALES": [555, 1243, 978],
            }
        )
        check_null_values = result[impute_dict.keys()].isnull().values.any()
        self.assertEqual(check_null_values, False)
        self.assertListEqual(list(result), list(expected_output))

    def test_get_first_row_on_group(self):
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

        rows_partition = ["Brand"]
        rows_order = {"Country": False, "Sales": True}
        result = data_utils.get_first_row_on_group(
            input_df, rows_partition, rows_order)
        expected_output = pd.DataFrame(
            [
                ("SOLIQUA", "GERMANY", 202),
                ("TOUJEO", "JAPAN", 218),
                ("SULIQUA", "US-EAST", 188),
            ],
            columns=("Brand", "Country", "Sales"),
        )
        self.assertEqual(len(input_df.columns) - 1, len(result.columns))
        self.assertListEqual(list(result), list(expected_output))

    def test_select_and_dropna_on_cols(self):
        input_df = pd.DataFrame(
            {
                "BRAND": ["TOUJEO", "SOLIQUA", "SULIQUA"],
                "INDEX": [None, 26, 25],
                "SALES": [155, 1243, None],
            }
        )
        col_list = ["BRAND", "SALES"]
        drop_col = ["INDEX"]
        result = data_utils.select_and_dropna_on_cols(
            input_df, col_list, drop_col)
        expected_output = pd.DataFrame(
            {
                "BRAND": ["SOLIQUA", "SULIQUA"],
                "SALES": [1243, None],
            }
        )
        self.assertEqual(len(input_df.columns) -
                         len(drop_col), len(result.columns))
        self.assertListEqual(list(result), list(expected_output))

    def test_null_outlier_treatment(self):
        input_df = pd.DataFrame(
            {
                "BRAND": ["TOUJEO", "SOLIQUA", "SULIQUA"],
                "INDEX": [None, 26, 25],
                "SALES": [15563, 12433, None],
            }
        )
        target_dict = {
            "TARGET_COL": "SALES",
            "QUANTILE": 0.99,
            "VALUE": "MEAN"}
        result = data_utils.null_outlier_treatment(input_df, target_dict)
        expected_output = pd.DataFrame(
            {
                "BRAND": ["TOUJEO", "SOLIQUA", "SULIQUA"],
                "INDEX": [None, 26, 25],
                "SALES": [15531.70, 12433.00, 13982.35],
            }
        )
        check_null_values = result[target_dict["TARGET_COL"]].isnull(
        ).values.any()
        self.assertEqual(check_null_values, False)
        self.assertListEqual(list(result), list(expected_output))

    def test_pivot_column_group(self):
        input_df = pd.DataFrame(
            [
                ("TOUJEO", "ITALY", 186, 24),
                ("SOLIQUA", "GERMANY", 202, 24),
                ("SULIQUA", "US", 304, 36),
                ("SULIQUA", "KOREA", 210, 28),
                ("TOUJEO", "JAPAN", 218, 18),
                ("TOUJEO", "ITALY-WEST", 270, 33),
                ("SULIQUA", "US-EAST", 188, 31),
            ],
            columns=("Brand", "Country", "Sales", "Brick_ID"),
        )
        col_list = ["Brand"]
        feature_list = [["Country"], ["Sales"]]
        agg_val = "Brick_ID"
        output = input_df[col_list].iloc[:, 0].unique()
        result = data_utils.pivot_column_group(
            input_df, col_list, feature_list, agg_val)
        expected_output = pd.DataFrame(
            [
                ("TOUJEO", 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0),
                ("SOLIQUA", 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0),
            ],
            columns=(
                "Brand",
                "HCP_Country_GERMANY",
                "HCP_Country_ITALY",
                "HCP_Country_ITALY-WEST",
                "HCP_Country_JAPAN",
                "HCP_Country_KOREA",
                "HCP_Country_US",
                "HCP_Country_US-EAST",
                "HCP_Sales_186",
                "HCP_Sales_188",
                "HCP_Sales_202",
                "HCP_Sales_210",
                "HCP_Sales_218",
                "HCP_Sales_270",
                "HCP_Sales_304",
            ),
        )
        self.assertEqual(len(output), result.shape[0])
        self.assertListEqual(list(result), list(expected_output))

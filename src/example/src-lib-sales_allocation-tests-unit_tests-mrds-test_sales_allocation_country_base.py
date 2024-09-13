from unittest import TestCase
from unittest.mock import patch

import pandas as pd
from turing_sales_allocation.mrds.sales_allocation_country_base import SalesAllocationCountryBase
from turing_sales_allocation.constants.constants_base import HCP_UNIVERSE_DATA_PATH


class TestSalesAllocationCountryBase(TestCase):
    """Test Case Class for testing Sales Allocation Country Base Class"""

    @patch("turing_sales_allocation.mrds.sales_allocation_country_base.read_table_query")
    @patch(
        "turing_sales_allocation.sales_allocation_main_base.SalesAllocationMainBase.replace_sql_identifiers"
    )
    @patch("turing_generic_lib.utils.snowflake_connection.snowflake.connector.connect")
    def test_get_data_from_sql_no_input_dataframe(
            self,
            mock_snowflake_connector,
            mock_replace_sql_identifiers,
            mock_read_table_query):
        """
        Tests the function get_data_from_sql that read and stores tables in a dataframe when no input dataframe is given.
        """
        country_base_obj = SalesAllocationCountryBase("IT", "sales_allocation")
        sample_table = pd.DataFrame({"Test": [1]})
        mock_replace_sql_identifiers.return_value = ""
        mock_snowflake_connector.return_value = ""
        mock_read_table_query.return_value = sample_table
        data_frame = country_base_obj.get_data_from_sql(HCP_UNIVERSE_DATA_PATH)
        self.assertListEqual(list(data_frame), list(sample_table))

    @patch("turing_sales_allocation.mrds.sales_allocation_country_base.read_table_query")
    @patch(
        "turing_sales_allocation.sales_allocation_main_base.SalesAllocationMainBase.replace_sql_identifiers"
    )
    @patch("turing_generic_lib.utils.snowflake_connection.snowflake.connector.connect")
    def test_get_data_from_sql_with_input_dataframe(
            self,
            mock_snowflake_connector,
            mock_replace_sql_identifiers,
            mock_read_table_query):
        """
        Tests the function get_data_from_sql that read and stores tables in a dataframe when an input dataframe is given.

        """
        country_base_obj = SalesAllocationCountryBase("IT", "sales_allocation")
        sample_table = pd.DataFrame({"Test": [1]})
        mock_replace_sql_identifiers.return_value = ""
        mock_snowflake_connector.return_value = ""
        mock_read_table_query.return_value = sample_table
        input_df = pd.DataFrame({"Index": [2, 7], "Test": [23, 10]})
        expected_output = pd.DataFrame(
            {"Index": [2, 7, None], "Test": [23, 10, 1]})
        data_frame = country_base_obj.get_data_from_sql(
            HCP_UNIVERSE_DATA_PATH, input_df, "outer", ["Test"]
        )
        self.assertListEqual(list(data_frame), list(expected_output))

"""This file constains the classes and finctions to pull, merge and prepare data.
"""
import abc
import warnings
from typing import List

import pandas as pd
from turing_generic_lib.utils.snowflake_connection import open_sql_file, read_table_query
from turing_sales_allocation.sales_allocation_main_base import SalesAllocationMainBase

warnings.filterwarnings("ignore")


class SalesAllocationCountryBase(SalesAllocationMainBase):
    """
    CRRC base class
    """

    def __init__(self, country, usecase):
        abc.ABCMeta
        super().__init__(country, usecase)

    def get_data_from_sql(
        self,
        sql_data_path: str,
        df_input: pd.DataFrame = None,
        join_type: str = None,
        join_col_list: List[str] = None,
    ) -> pd.DataFrame:
        """This function allows us to get the data for all countries

        Arguments:
            sql_data_path {str} -- File path to get the data
            country {str} -- Country name string

        Returns:
            pd.DataFrame -- Sales master data
        """

        query = open_sql_file(sql_data_path)
        query = self.replace_sql_identifiers(query)
        if df_input is None:
            df_master = read_table_query(query, self.snowflake_con)
        else:
            df_read_table = read_table_query(query, self.snowflake_con)
            df_master = df_input.merge(
                df_read_table, how=join_type, on=join_col_list)
        return df_master

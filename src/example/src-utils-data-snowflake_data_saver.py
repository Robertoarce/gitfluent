"""
Module for saving data to Snowflake
"""
from typing import Dict

import pandas as pd
from snowflake.connector.errors import DatabaseError
from snowflake.connector.pandas_tools import write_pandas

from src.utils.data.data_saver import DataSaver
from src.utils.snowflake_utils import MMXSnowflakeConnection


# pylint: disable=too-few-public-methods
class SnowflakeDataSaver(DataSaver):
    """
    Collection of functions and utilities to load data from Snowflake.
    init params:
        `config` is a dictionary with the following nested structure:

        tables:
            {table_name (str)}: # this is an identifier string, doesn't need to match SF table name
                schema: {name of schema in Snowflake (str)}
                table: {name of table in Snowflake (str)}
    """

    # pylint:disable=arguments-differ, broad-exception-raised
    def _save_table(self, df: pd.DataFrame, table_config: Dict, chunk_size=20000):
        """
        Copies data into a Snowflake table

        chunk_size parameter prevents memory issue when working on low-resource machines
        """
        nrows_expected = df.shape[0]
        df.columns = [c.upper() for c in df.columns]

        connection = MMXSnowflakeConnection(
            schema=table_config["schema"],
            env=self.env,
            **self.config.get("snowflake_connection", {}),
        )

        try:
            success, _, nrows, _ = write_pandas(
                conn=connection,
                df=df,
                table_name=table_config["table"],
                schema=table_config["schema"],
                chunk_size=chunk_size,
            )

            if success and (nrows == nrows_expected):
                pass  # TODO: success statement
            else:
                raise Exception(
                    f"Failed to save dataframe to {table_config['schema']}.{table_config['table']}"
                )
        except DatabaseError as de:
            connection.close()  # pylint: disable=no-member
            raise de

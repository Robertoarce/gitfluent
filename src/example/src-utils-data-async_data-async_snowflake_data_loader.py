"""
Async Snowflake Data Loader
"""
from src.utils.data.async_data.async_data_loader import AsyncDataLoader
from src.utils.data.snowflake_data_loader import SnowflakeDataLoader
from src.utils.snowflake_utils import snowflake_to_pandas_async


# pylint: disable=too-few-public-methods, no-self-use
# pylint:disable=invalid-overridden-method
class AsyncSnowflakeDataLoader(SnowflakeDataLoader, AsyncDataLoader):
    """
    SnowflakeDataLoader with async load method.
    """

    async def _load_table_from_source(self, table_config: dict):
        """
        Loads the table from Snowflake as a pandas df
        """
        query = self._build_query(table_config)
        df = await snowflake_to_pandas_async(query, env=self.env)

        return df

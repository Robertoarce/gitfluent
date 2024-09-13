"""
Data Manager, with async methods (only for loading methods for now).
"""

from src.utils.data.async_data.async_snowflake_data_loader import (
    AsyncSnowflakeDataLoader,
)
from src.utils.data.data_manager import DataManager
from src.utils.data.s3_data_saver import S3DataSaver
from src.utils.data.snowflake_data_saver import SnowflakeDataSaver


# pylint:disable=invalid-overridden-method
class AsyncDataManager(DataManager):
    """
    DataManager with async loaders methods.
    """

    supported_loaders = {"Snowflake": AsyncSnowflakeDataLoader}
    supported_savers = {"S3": S3DataSaver, "Snowflake": SnowflakeDataSaver}

    async def load_validate_clean(self):
        """
        Load, validate, and clean all tables.
        """
        for t in self._table_sources.keys():
            await self._load_table(t)
            self._validate_table(t)
            self._clean_table(t)

    async def _load_table(self, table_name: str):
        """
        Wrapper to load table from the respective data loader.
        """
        source = self._table_sources.get(table_name)
        self._table_data[table_name] = await self._data_loaders[source].load_table(
            table_name
        )

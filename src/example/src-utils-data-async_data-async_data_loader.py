"""
Data Loader, with async methods.
"""
from abc import abstractmethod
from typing import Dict

from src.utils.data.data_loader import DataLoader
from src.utils.data.filter_functions import FILTER_FUNCTIONS


# pylint:disable=too-few-public-methods
# pylint:disable=invalid-overridden-method
class AsyncDataLoader(DataLoader):
    """
    Overwrite DataLoader methods with awaitable couroutines.
    """

    filter_functions = dict(FILTER_FUNCTIONS)

    async def load_table(self, table_name: str):
        """
        Where the data has already been loaded, retrieve it as a property-like attribute.
        Where the data has not yet been loaded, load it and save it.
        """
        if hasattr(self, table_name):
            return getattr(self, table_name).copy()

        table_config = self._tables[table_name]
        df = await self._load_table_from_source(table_config)
        if self._standardize_column_names:
            df = self._columns_to_lower_case(df)

        setattr(self, table_name, df)

        return df

    @abstractmethod
    async def _load_table_from_source(self, table_config: Dict):
        """
        Reads the table from the data source.
        """

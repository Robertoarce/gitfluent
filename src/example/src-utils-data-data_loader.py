"""
Abstract Base Class for Data Loader
"""
from abc import ABC, abstractmethod
from typing import Dict

import pandas as pd

from src.utils.data.filter_functions import FILTER_FUNCTIONS


# pylint:disable=too-few-public-methods
class DataLoader(ABC):
    """
    DataLoader class for loading data from data sources.
    """

    filter_functions = dict(FILTER_FUNCTIONS)

    def __init__(self, config: Dict, env: str = None):
        """
        `config` is a dict with keys:
            `tables` which is a dict, with format determined by the subclass
            `standardize_column_names`: bool
        """
        self.config = config
        self._tables = config.get("tables", {})
        self._standardize_column_names = config.get("standardize_column_names", False)
        self.env = env

    def load_table(self, table_name: str, config=None):
        """
        Where the data has already been loaded, retrieve it as a property-like attribute.
        Where the data has not yet been loaded, load it and save it.
        """
        if hasattr(self, table_name):
            return getattr(self, table_name).copy()

        table_config = self._tables[table_name]
        df = self._load_table_from_source(table_config, config)
        if self._standardize_column_names:
            df = self._columns_to_lower_case(df)

        setattr(self, table_name, df)

        return df

    def _columns_to_lower_case(self, df: pd.DataFrame):
        """
        Standardizes column names in the dataframes to lower case.
        """
        df.columns = [c.lower() for c in df.columns]
        return df

    @abstractmethod
    def _load_table_from_source(self, table_config: Dict, config=None):
        """
        Reads the table from the data source.
        """

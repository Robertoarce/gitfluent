"""
Abstract Base Class for Data Saver
"""
from abc import ABC, abstractmethod
from typing import Dict

import pandas as pd


# pylint:disable=too-few-public-methods
class DataSaver(ABC):
    """
    DataSaver class for writing to tables.
    """

    def __init__(self, config: Dict, env: str = None):
        """
        `config is a dict with keys:
            `tables` which is a dict, with format determined by the subclass
        """
        self.config = config
        self._tables = config.get("tables", {})
        self.env = env

    def save_table(self, df: pd.DataFrame, table_name: str):
        """
        `df` is the dataframe to save
        `table_name` identifies the table (in the config) save location.
        """
        self._save_table(df, self._tables[table_name])

    @abstractmethod
    def _save_table(self, df: pd.DataFrame, table_config: Dict):
        """
        To be implemented by subclasses depending on save location.
        """

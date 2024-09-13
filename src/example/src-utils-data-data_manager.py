"""
DataManager module
"""
import logging
from copy import deepcopy
from typing import Dict, Iterable

import pandas as pd

from src.utils.data.data_cleaner import DataCleaner
from src.utils.data.data_preparation import DataValidator
from src.utils.data.s3_data_loader import S3DataLoader
from src.utils.data.s3_data_saver import S3DataSaver
from src.utils.data.snowflake_data_loader import SnowflakeDataLoader
from src.utils.data.snowflake_data_saver import SnowflakeDataSaver


logger = logging.getLogger(__name__)

class DataManager:
    """
    Manages all data I/O for a pipeline
        Input: Loads, Validates, and Cleans input data.
        Output: Saves data to respective locations.
    """

    supported_loaders = {"S3": S3DataLoader, "Snowflake": SnowflakeDataLoader}
    supported_savers = {"S3": S3DataSaver, "Snowflake": SnowflakeDataSaver}

    def __init__(
        self,
        data_sources_config: Dict,
        data_validation_config: Dict,
        data_cleaning_config: Dict,
        data_outputs_config: Dict,
        env: str = None,
    ):
        """
        Config structure:

        `data_sources_config` is a dictionary:
            S3:
                {S3DataLoader config dict}
            Snowflake:
                {SnowflakeDataLoader config dict}

            Note that the table names must be unique across data sources; otherwise,
            the last defined source will be used.

        `data_validation_config` is a dictionary, where table names align with those in data loader.
            {table_name}:
                {DataValidator config dict}

        `data_cleaning_config` is a dictionary, where table names align with those in data loader.
            {table_name}:
                {DataCleaner config dict}

        `data_outputs_config` is a dictionary:
            {table_name}:
                {DataSaver config dict}
        """
        # Loading
        self._data_loaders = {}
        self._table_sources = {}
        for data_source, loader_config in data_sources_config.items():
            if data_source in self.supported_loaders.keys():
                self._data_loaders[data_source] = self.supported_loaders[data_source](
                    loader_config, env=env
                )
                self._table_sources.update({t: data_source for t in loader_config["tables"].keys()})
            else:
                raise NotImplementedError(f"Data Loader for {data_source} not yet implemented")

        # Validating
        self._data_validators = {t: DataValidator(cfg) for t, cfg in data_validation_config.items()}

        # Cleaning
        self._data_cleaners = {t: DataCleaner(cfg) for t, cfg in data_cleaning_config.items()}

        # Outputs
        self._data_savers = {}
        self._table_destinations = {}
        for data_destination, saver_config in data_outputs_config.items():
            if data_destination in self.supported_savers.keys():
                self._data_savers[data_destination] = self.supported_savers[data_destination](
                    saver_config, env=env
                )
                self._table_destinations.update(
                    {t: data_destination for t in saver_config["tables"].keys()}
                )
            else:
                raise NotImplementedError(f"Data Saver for {data_destination} not yet implemented")

        # internal dict to hold data
        self._table_data = {}

    def load_validate_clean(self, subset=None, config=None):
        """
        Load, validate, and clean all tables.
        """
        if subset is not None:
            subset = [t for t in self._table_sources.keys() if t in subset]
        else:
            subset = self._table_sources.keys()

        for t in subset:
            self._load_table(t, config)
            self._validate_table(t)
            self._clean_table(t)

    def _load_table(self, table_name: str, config=None):
        """
        Wrapper to load table from the respective data loader.
        """
        source = self._table_sources.get(table_name)
        self._table_data[table_name] = self._data_loaders[source].load_table(table_name, config)
        if self._table_data[table_name] is None or len(self._table_data[table_name]) == 0:
            logger.warning(f'Query result for {table_name} is empty')


    def _validate_table(self, table_name: str):
        """
        Validates the table.
        """
        validator = self._data_validators.get(table_name)

        if validator is not None:
            validator.validate(self._table_data[table_name])

    def _clean_table(self, table_name: str):
        """
        Cleans the table
        """
        cleaner = self._data_cleaners.get(table_name)

        if cleaner is not None:
            self._table_data[table_name] = cleaner.apply_cleaning_steps(
                self._table_data[table_name]
            )

    def get_data_dict(self, keys: Iterable = None):
        """
        Returns the data in dictionary format
        """
        if not keys:
            data_dict = self._table_data
        else:
            data_dict = {k: self._table_data[k] for k in keys}

        return deepcopy(data_dict)

    def save_table(self, df: pd.DataFrame, table_name: str):
        """
        Uses the underlying data saver to save the table.
        """
        destination = self._table_destinations.get(table_name)
        self._data_savers[destination].save_table(df, table_name)

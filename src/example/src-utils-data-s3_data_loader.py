"""
Module for loading data from S3
"""
import os
from typing import Dict

import pandas as pd

from src.utils.data.data_loader import DataLoader


# pylint: disable=too-few-public-methods
class S3DataLoader(DataLoader):
    """
    Collection of functions and utilities to load data from S3.
    init params:
        `config` is a dictionary with the following nested structure:

        tables:
            {table_name (str)}: # this is an identifier string
                bucket: {bucket_name (str)}
                dir: {directory/under/bucket (str)}
                pre_filters:
                    {column name (str)}:
                        type: {equal/not_equal/less/less_equal/greater/greater_equal}
                        value: int/float/string
                delim: {delimiter string for csv files, defaults to comma}
    """

    def _load_table_from_source(self, table_config: dict):
        """
        Loads the table as a pandas df, and stores it for cheap retrieval.
        """
        # pandas can read directly from s3, assuming:
        #   s3fs is installed
        # credentials are configured
        # https://s3fs.readthedocs.io/en/latest/#credentials
        path = f"s3://{table_config['bucket']}/{table_config['dir']}"
        ext = os.path.splitext(path)[1]

        if ext == ".csv":
            df = pd.read_csv(path, sep=table_config.get("delim", ","))
        elif ext == ".parquet":
            df = pd.read_parquet(path)
        else:
            raise ValueError(f"Could not read file {path} with file extension {ext}")

        df = self._apply_filters(df, table_config)

        return df

    def _apply_filters(self, df: pd.DataFrame, table_config: Dict):
        """
        Apply filters to dataframe `df` based on dictionary `table_config
        """
        for col_name, fltr in table_config.get("pre_filters", {}).items():
            filter_fn = self.filter_functions.get(fltr["type"])
            if filter_fn is None:
                raise ValueError(f"Filter type {fltr['type']} not implemented!")

            df = df.query(f"`{col_name}` {filter_fn} {fltr['value']}")

        return df

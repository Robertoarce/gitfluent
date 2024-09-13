"""
Module for saving data to S3
"""
import os
from typing import Dict

import pandas as pd

from src.utils.data.data_saver import DataSaver


# pylint: disable=too-few-public-methods
class S3DataSaver(DataSaver):
    """
    Collection of functions and utilities to save data to S3.
    Init params:
        `config` is a dictionary with the following nested structure:

        tables:
            {table_name (str)}: # this is an identifier string
                bucket: {bucket_name (str)}
                dir: {directory/under/bucket (str)}
    """

    def _save_table(self, df: pd.DataFrame, table_config: Dict):
        """
        Saves the table to S3 location.
        """
        # pandas can save directly to s3, assuming:
        #   s3fs is installed
        # credentials are configured
        # https://s3fs.readthedocs.io/en/latest/#credentials
        path = f"s3://{table_config['bucket']}/{table_config['dir']}"
        ext = os.path.splitext(path)[1]

        if ext == ".csv":
            df = pd.to_csv(path)
        elif ext == ".parquet":
            df = pd.to_parquet(path)
        else:
            raise ValueError(f"Cannot save to {path} with file extension {ext}")

        return df

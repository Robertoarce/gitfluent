"""
Created By  : MMX DS Team (Jeeyoung, Dipkumar, Alex, Nikhil, Youssef)
Created Date: 16/01/2023
Description : Functions for Loading data from MMX SnowFlake
"""
from typing import Dict

import pandas as pd
from pandas.api.types import (
    is_bool_dtype,
    is_datetime64_any_dtype,
    is_float_dtype,
    is_integer_dtype,
    is_string_dtype,
)


# pylint: disable=too-few-public-methods
class DataValidator:
    """
    Class to perform sanity checks on the data.
    """

    dtype_validation_fns = {
        "str": is_string_dtype,
        "float": is_float_dtype,
        "int": is_integer_dtype,
        "bool": is_bool_dtype,
        "datetime": is_datetime64_any_dtype,
    }

    def __init__(self, config_dico: Dict):
        """
        `config_dico` holds the configuration that will be used to validate the data,
        and has the following dictionary structure:
        columns:
            {column_name}:
                type: type of the column; valid types are the keys in `dtype_validation_fns`
                null_allowed: bool
        """
        self.columns = config_dico.get("columns", {})

    def validate(self, df: pd.DataFrame):
        """
        Check integrity of a Pandas dataframe regarding expected columns, missing values and types.

        Args:
        df (dataframe): pandas dataframe to check
        """
        # Check that all the columns are there
        expected_columns = set(self.columns.keys())
        present_columns = set(df.columns)
        missing_columns = expected_columns - present_columns
        additional_columns = present_columns - expected_columns
        if missing_columns or additional_columns:
            raise ValueError(
                "The columns present in the dataframe are not those expected:"
                f" Missing columns: {missing_columns}."
                f" Additional columns: {additional_columns}."
            )

        # Columns for missing values
        na_count = df.isna().sum()
        columns_with_na = set(na_count[na_count > 0].index.values)
        columns_na_allowed = set(
            c for c, v in self.columns.items() if v.get("null_allowed")
        )
        columns_na_unexpected = columns_with_na - columns_na_allowed

        if columns_na_unexpected:
            raise ValueError(
                f"There are columns with unexpected missing values: {columns_na_unexpected}."
            )

        # Validate that column types are correct
        wrong_dtype_cols = []
        for col, col_config in self.columns.items():
            validation_fn = self.dtype_validation_fns.get(col_config["type"], None)
            if validation_fn is None:
                raise NotImplementedError(
                    f"Cannot validate column {col} with expected datatype {col_config['type']}."
                )

            if not validation_fn(df[col]):
                wrong_dtype_cols.append((col, col_config["type"], df[col].dtype))

        if wrong_dtype_cols:
            error_string = "; ".join(
                [
                    f"Column {c} has expected dtype {expected_type}, but has type {actual_type}"
                    for c, expected_type, actual_type in wrong_dtype_cols
                ]
            )
            raise ValueError(f"There are columns with unexpected types: {error_string}")

"""
Base schema class used in schema classes
"""
from typing import Any, Dict, List, Tuple

import numpy as np
import pandas as pd


class BaseSchema:
    """
    Base schema class

    Attributes:
        _label (str): A label for the schema class.
        _columns (Dict[str, Tuple[str, int]]): A dictionary mapping column names to their types.
    """

    _label: str = "base"

    _columns: Dict[str, Tuple[str, int]] = {}

    def __init__(self):
        """constructor method"""
        self._primary_key: List[str] = []

        self._enum: Dict[str, List[Any]] = {}

    def __getattr__(self, item: str) -> str:
        """Method to get attribute

        Arguments:
            item {str} -- [description]

        Raises:
            ValueError: [description]

        Returns:
            str -- [description]
        """
        if item in self._columns:
            return self._columns.get(item)[0]
        raise ValueError(f"Column: {item} doesn't exist")

    def __getitem__(self, item: str) -> str:
        """
        Get item
        """
        return self.__getattr__(item)

    # Override __dir__ method to add _columns attributes to object attribute
    # autocompletion
    def __dir__(self):
        """
        Returns directory
        """
        return super().__dir__() + list(self._columns.keys())

    @classmethod
    def get_label(cls):
        """
        Returns class label
        """
        return cls._label

    def get_primary_key(self):
        """
        Returns primary key
        """
        return self._primary_key

    @classmethod
    def get_columns(cls) -> Dict[str, Tuple[str, int]]:
        """
        Returns column names
        """
        return cls._columns

    @classmethod
    def get_column_names(cls) -> List[str]:
        """
        Return column names
        """
        return [v[0] for _, v in cls._columns.items()]

    @classmethod
    def get_column_types(cls) -> List[str]:
        """
        Get the column data types.

        Returns:
            List[str]: A list of column data types.
        """
        return [v[1] for _, v in cls._columns.items()]

    @classmethod
    def cast(cls, data: pd.DataFrame) -> pd.DataFrame:
        """
        Cast the data types of columns in a DataFrame according to schema.

        Args:
            data (pd.DataFrame): The input DataFrame.

        Returns:
            pd.DataFrame: The DataFrame with casted column types.
        """
        data = data.copy()
        for _, (col, col_type) in cls._columns.items():
            if col in data.columns:
                if col_type == "datetime":
                    data[col] = pd.to_datetime(data[col])
                elif col_type == str:
                    data[col] = (
                        data[col]
                        .replace({np.nan: "None"})
                        .astype(col_type)
                        .replace({"None": np.nan})
                    )
                else:
                    data[col] = data[col].astype(col_type)
        return data

    def validate(self, data: pd.DataFrame) -> None:
        """
        Validate the input DataFrame against the schema.

        Args:
            data (pd.DataFrame): The input DataFrame to be validated.
        """
        self.check_enum_values(data)

    @classmethod
    def check_missing_columns(cls, data: pd.DataFrame) -> None:
        """
        Check for missing columns in the input DataFrame.

        Args:
            data (pd.DataFrame): The input DataFrame.

        Raises:
            AssertionError: If missing columns are found.
        """
        missing_columns = list(set(cls.get_column_names()).difference(set(data.columns)))

        assert (
            not missing_columns
        ), f"{cls._label} - The following columns are missing: {missing_columns}"

    def check_primary_key(self, data: pd.DataFrame) -> None:
        """
        Check the uniqueness of the primary key in the input DataFrame.

        Args:
            data (pd.DataFrame): The input DataFrame.

        Raises:
            AssertionError: If the primary key is not unique.
        """
        if self._primary_key:
            is_unique = not data.duplicated(self._primary_key).sum()
            assert is_unique, f"{self._label} - Primary key: {self._primary_key} is not unique"

    def check_enum_values(self, data: pd.DataFrame) -> None:
        """
        Check enum values in the input DataFrame against allowed values.

        Args:
            data (pd.DataFrame): The input DataFrame.

        Raises:
            AssertionError: If invalid enum values are found.
        """
        for k, v in self._enum.items():
            col_values = set(data[k].unique())
            col_values = col_values.difference([None, "None", np.nan])

            assert col_values.issubset(
                set(v)
            ), f"{self._label} - Invalid values for column {k}: {col_values.difference(set(v))}"

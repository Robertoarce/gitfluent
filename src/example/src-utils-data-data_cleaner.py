# pylint:disable=unused-argument
"""
Module to perform data cleaning
"""
from logging import getLogger
from typing import Dict, List, Union

import numpy as np
import pandas as pd

from src.utils.data.filter_functions import FILTER_FUNCTIONS

logger = getLogger(__name__)


# pylint: disable=too-few-public-methods
class DataCleaner:
    """
    Class to perform data cleaning operations on a dataframe according to dictionary config.

    For performance reasons, this class is only intended for light data cleaning
    on a minimal dataframe. It is much more performant for the majority of data
    cleaning/transformations to be performed directly in Snowflake where possible,
    especially where a large number of rows can be pre-filtered.
    """

    filter_functions = dict(FILTER_FUNCTIONS)

    def __init__(self, config_dico: Dict):
        """
        Keys of `config_dico`:
            `name`: str; Name to be associated with the DataCleaner instance (for logging only)
            `copy`: bool; Returns a copy of the dataframe if True (default).
            `steps`: List[
                Dict:
                    name: str; name of the step
                    type: str; type of the step
                    kwargs: Dict (str -> value) for all kwargs to pass to the step
            ]
        """
        self.name = config_dico.get("name")
        if self.name:
            self.logger_tag = f"[{self.name}] "
        else:
            self.logger_tag = ""

        self.return_copy = config_dico.get("copy", True)
        self.steps = config_dico.get("steps", [])

    def apply_cleaning_steps(self, df: pd.DataFrame):
        """
        Apply the data cleaning steps to a dataframe `df`
        """
        if self.return_copy:
            new_df = df.copy()
        else:
            new_df = df

        for step_config in self.steps:
            new_df = self._apply_cleaning_step(
                df=new_df,
                step_type=step_config["type"],  # cannot be missing
                step_name=step_config.get("name"),
                **step_config.get("kwargs"),
            )

        return new_df

    def _apply_cleaning_step(
        self, df: pd.DataFrame, step_type: str, step_name: str = None, **kwargs
    ):
        """
        Apply a single cleaning step.
        """
        step_fn = getattr(
            self, "_" + step_type, None
        )  # step functions are private class methods with `_`

        if (step_fn is None) or (not callable(step_fn)):
            # checks that each step_type is actually a valid method that has
            # been implemented
            raise NotImplementedError(
                f"{self.__class__.__name__}: Cleaning step type {step_type} not implemented"
            )

        if step_name:
            logger.info(self.logger_tag + f"APPLYING STEP {step_name}")

        return step_fn(df, **kwargs)

    def _drop_na(self, df: pd.DataFrame, **kwargs):
        """
        Wrapper function for pd.DataFrame.dropna()
        """
        return df.dropna(**kwargs)

    def _drop_columns(self, df: pd.DataFrame, columns: List[str], **kwargs):
        """
        Drop columns `columns` from the dataframe.
        """
        return df.drop(columns, axis=1)

    def _keep_columns(self, df: pd.DataFrame, columns: List[str], **kwargs):
        """
        Keep columns `columns` from the dataframe, and drop the rest.
        """
        return df[columns]

    def _clip_values(self, df: pd.DataFrame, clip_range: Dict[str, Dict[str, float]], **kwargs):
        """
        Clips the values of the specified columns to a specified range.
        The function might be useful to remove outlying values.

        `clip_range` is a dict with:
            keys as strings representing the column names
            values as a dict with two keys:
                min: the minimum float value
                max: the minimum float value
        Values below/above the min/max will be set to the min/max respectively.
        """
        for col, v in clip_range.items():
            if v.get("min") is not None:
                df[col] = df[col].where(df[col] >= v["min"], v["min"])
            if v.get("max") is not None:
                df[col] = df[col].where(df[col] <= v["max"], v["max"])

        return df

    def _clip_quantile(self, df: pd.DataFrame, clip_range: Dict[str, Dict[str, float]], **kwargs):
        """
        Clips the values of the specified columns to a specified range, based on quantile.
        The function might be useful to remove outlying values.

        `clip_range` is a dict with:
            keys as strings representing the column names
            values as a dict with two keys:
                min: the lowest quantile value. All values below will be set to the quantile value.
                max: the highest quantile value. All values above will be set to the quantile value.
        """
        for col, v in clip_range.items():
            min_q = df[col].quantile(v.get("min", 0))
            max_q = df[col].quantile(v.get("max", 1))

            df[col] = df[col].where(df[col] >= min_q, min_q)
            df[col] = df[col].where(df[col] <= max_q, max_q)

        return df

    def _drop_quantile(self, df: pd.DataFrame, keep_range: Dict[str, Dict[str, float]], **kwargs):
        """
        Drops certain rows of the dataframe, based on specified quantiles of given columns.
        The function might be useful to remove outlying values.

        `keep_range` is a dict with:
            keys as strings representing the column names
            values as a dict with two keys:
                min: The lower bound quantile value.
                max: The upper bound quantile value.
        Rows with this column value outside this range will be dropped.
        """
        for col, v in keep_range.items():
            min_q = df[col].quantile(v.get("min", 0))
            max_q = df[col].quantile(v.get("max", 1))

            df = df[(df[col] >= min_q) & (df[col] <= max_q)]

        return df

    def _standardize(self, df: pd.DataFrame, scale_loc: Dict[str, Dict[str, float]], **kwargs):
        """
        Standardizes the values of the specified columns to a specified range by applying:
            standardize(x) = (x - min) / (max - min) * scale + loc

        `scale_loc` is a dict with:
            keys as strings representing the column names
            values as a dict with two keys:
                scale: defaults to 1
                loc: defaults to 0
        """
        for col, v in scale_loc.items():
            scale = v.get("scale", 1)
            loc = v.get("loc", 0)

            df[col] = (df[col] - df[col].min()) / (df[col].max() - df[col].min()) * scale + loc

        return df

    def _filter(self, df: pd.DataFrame, filters: Dict[str, Union[List[str], str]], **kwargs):
        """
        Applies filters to the dataframe based on specified columns and conditions.

        `filters` is a dict mapping:
            {column_name}:
                    type: {equal/not_equal/less/less_equal/greater/greater_equal}
                    value: int/float/string
        """
        for col_name, fltr in filters.items():
            filter_fn = self.filter_functions.get(fltr["type"])
            if filter_fn is None:
                raise ValueError(f"Filter type {fltr['type']} not implemented!")

            df = df.query(f"`{col_name}` {filter_fn} {fltr['value']}")

        return df

    def _rename_columns(self, df: pd.DataFrame, names: Dict[str, str], **kwargs):
        """
        Renames columns based on dictionary.

        `names` is a dict mapping:
            {old_name}: {new_name}
            for each column to rename
        """
        df = df.rename(columns=names)

        return df

    def _cast_type(self, df: pd.DataFrame, types: Dict[str, str], **kwargs):
        """
        Casts columns to specified type based on dictionary

        `types` is a dict mapping:
            {column_name}: {type}
        """
        for col, new_type in types.items():
            df[col] = df[col].astype(new_type)

        return df

    def _datetime_to_str(self, df: pd.DataFrame, formats: Dict[str, str], **kwargs):
        """
        Applies strftime on a datetime column.

        `formats` is a dict mapping:
            {column_name}: {strftime format}
        """
        for col, fmt in formats.items():
            df[col] = df[col].dt.strftime(fmt)

        return df

    def _bucketize(self, df: pd.DataFrame, col_settings: Dict[str, Dict], **kwargs):
        """
        Bucketizes specified columns - wrapper for pd.cut.

        `col_settings` is a dict mapping:
            {column_name}:
                bins: list[int or float]
                right: bool
                add_inf: ["left"/"right"/"both"/"neither]
                labels: list[int or float or str]
                drop_outside: bool

            `bins` is a list of length n which indicates the borders of the buckets
            `right`: intervals are rightbounded (] if True, else leftbounded [)
            `add_inf`: whether to prepend -np.inf, postpend +np.inf to the bins, or both.
                Where "left", `labels` must be of length n,
                    with labels[0] corresponding to (-np.inf, bins[0])
                Where "right", `labels` must be of length n,
                    with labels[-1] corresponding to (bins[-1], np.inf)
                Where "both", `labels` must be of length n+1
                Where "neither", `labels` must be of length n-1
            `labels`: labels for each of the buckets
            `drop_outside`: If true, drop any rows which had values outside the bins.
        """
        for col, settings in col_settings.items():
            bins = settings["bins"].copy()
            if settings["add_inf"] in ("left", "both"):
                bins = [-np.inf] + bins
            if settings["add_inf"] in ("right", "both"):
                bins = bins + [np.inf]

            df[col] = pd.cut(df[col], bins=bins, right=settings["right"], labels=settings["labels"])

            if settings["drop_outside"]:
                df = df.dropna(subset=col)

        return df

    def _upper(self, df: pd.DataFrame, columns: List[str], **kwargs):
        """
        Convert a string column to all uppercase
        """
        for col in columns:
            df[col] = df[col].str.upper()

        return df

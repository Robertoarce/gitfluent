"""
Module to apply operations at data frame levels such as reducing or aggregating data frames
"""
import logging
from dataclasses import dataclass
from typing import Dict, List, Optional, Set, Tuple

import numpy as np
import pandas as pd

from src.utils.names import F_CHANNEL_CODE, F_LAMBDA_ADSTOCK, F_TOUCHPOINT


class BaseResultsBayesianUplift:
    """
    Class to store bayesian uplift result
    """

    # Results tables
    denormalized_output_df: pd.DataFrame
    value_contribution_df: pd.DataFrame
    value_uplift_df: pd.DataFrame


@dataclass(frozen=True)
class ResultsBayesianUpliftChannel(BaseResultsBayesianUplift):
    """
    Results for the response curve uplift (and contribution) module for a specific sales channel
    """

    # Information
    channel_code: str

    # Results tables
    denormalized_output_df: pd.DataFrame
    value_contribution_df: pd.DataFrame
    value_uplift_df: pd.DataFrame


@dataclass(frozen=True)
class ResultsBayesianUplift(BaseResultsBayesianUplift):
    """
    Main output of the bayesian response uplift module combined the results of the response module
    uplift for each channel
    """

    denormalized_output_df: pd.DataFrame
    value_contribution_df: pd.DataFrame
    value_uplift_df: pd.DataFrame


def add_missing_columns(data_df: pd.DataFrame, set_missing_colums: Set) -> pd.DataFrame:
    """
    docstring
    """
    for col in set_missing_colums:
        data_df[col] = np.nan
    return data_df


def reduce_data_frames(
    frames: List[pd.DataFrame], on: Optional[List[str]] = None, how: str = "left"
) -> pd.DataFrame:
    """
    Utils functions to consolidate a list of data frames into one large data frame (using successive
    merges)

    Args:
        - frames: list of data frames to merges
        - on: columns used to merge data frames (same as pandas)
        - how: method used to merge data frames (same as pandas)

    Returns:
        - consolidated data frame
    """

    frames = [frame for frame in frames if not frame.empty]

    if len(frames) == 0:
        return pd.DataFrame()

    new_frame = frames.pop(0)
    while frames:
        right_frame = frames.pop(0)
        new_frame = new_frame.merge(right_frame, on=on, how=how)

    return new_frame


def round_numeric_columns(
    dataframe: pd.DataFrame, columns: List[str] = None, rounding: int = 2
) -> pd.DataFrame:
    """
    This dataframe rounds the values of the numeric columns to the rounding provided in argument
    """
    dataframe = dataframe.copy()
    if columns is None:
        columns = [col for col, dt in dataframe.dtypes.items() if dt == float]

    logging.info(f"Rounding columns {columns} to {rounding} decimals")

    for numeric_col in columns:
        dataframe.loc[:, numeric_col] = dataframe[numeric_col].apply(lambda x: round(x, rounding))
        # dataframe[numeric_col] = (dataframe[numeric_col] * 100).astype(int) / 100
    return dataframe


def cast_numeric_columns(dataframe: pd.DataFrame, columns: List = None) -> pd.DataFrame:
    """
    This dataframe casts the values of the numeric columns to float32
    if columns re not specified, the algorithm will cast all numerical columns
    """
    dataframe = dataframe.copy()
    if columns is None:
        columns = [col for col, dt in dataframe.dtypes.items() if dt == float]

    logging.info(f"Casting columns {columns} to float32")
    for numeric_col in columns:
        dataframe.loc[:, numeric_col] = dataframe.loc[:, numeric_col].astype(np.float32)

    return dataframe


def aggregate_results(
    results_channels: List[ResultsBayesianUpliftChannel],
    lambda_adstocks: Dict,
) -> Tuple[pd.DataFrame, ResultsBayesianUplift]:
    """
    Aggregate results from the different channels

    Args:
        - denormalized_outputs: list of denormalized_output_df (1 per channel)
        - volume_uplifts list of volume_uplift_df (1 per channel)
        - volume_contributions: list of volume_contribution_df (1 per channel)
        - transformed_features_df: table of features used to add the relevant target variables
        - column_year: fiscal_year or calendar_year
    """
    results_dict = {}
    results_dict["value_uplift_df"] = pd.concat(
        [results_channel.value_uplift_df for results_channel in results_channels],
        axis=0,
        sort=False,
    )

    results_dict["value_contribution_df"] = pd.concat(
        [results_channel.value_contribution_df for results_channel in results_channels],
        axis=0,
        sort=False,
    )

    results_dict["denormalized_output_df"] = pd.concat(
        [results_channel.denormalized_output_df for results_channel in results_channels],
        axis=0,
        sort=False,
    )

    lambda_adstocks = [
        pd.DataFrame(
            data=[(channel_code, key[0], key[1]) for key in lambda_adstocks[channel_code]],
            columns=[F_CHANNEL_CODE, F_TOUCHPOINT, F_LAMBDA_ADSTOCK],
        )
        for channel_code in lambda_adstocks.keys()
    ]

    lambda_adstock_df = pd.concat(lambda_adstocks).reset_index(drop=True)

    return (
        lambda_adstock_df,
        ResultsBayesianUplift(**results_dict),
    )

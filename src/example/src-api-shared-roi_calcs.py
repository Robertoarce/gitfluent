"""
Reusable calculations for ROI, MROI and GMROI.
"""

from typing import List

import numpy as np
import pandas as pd


def shift_roll(df: pd.DataFrame, col: str):
    """
    Function that rolls each array in a column by 1, and replaces the last entry with NaN.
    Useful for calculating MROI, which requires comparisons to previous rows.

    e.g. for one entry [1,2,3,4], would be transformed to [2,3,4,nan]
    """
    shifted_series = (
        df[col]
        .apply(lambda x: np.roll(x, -1))
        .apply(lambda x: np.concatenate([x[:-1], [np.nan]]))
    )
    return shifted_series


def argsort_by_uplift(
    df: pd.DataFrame,
    uplift_col: str,
    cols_to_sort: List[str],
    sort_order_col: str = "argsort_order",
):
    """
    Expects a dataframe with columns containing arrays.

    Performs parallel sort on each array in accordance with uplift order.

    `uplift_col`: the name of the column containing array of uplifts
    `cols_to_sort`: list of columns of arrays to sort
    `sort_order_col`: temporary column used to store sort order.
    """
    df[sort_order_col] = df[uplift_col].apply(np.argsort)
    for c in [uplift_col, *cols_to_sort]:
        df[c] = df.apply(lambda row: row[c][row[sort_order_col]], axis=1)

    df = df.drop(sort_order_col, axis=1)

    return df


def calc_roi_mroi_gmroi(
    df: pd.DataFrame,
    sell_out_input_col: str,
    spend_input_col: str,
    roi_output_col: str = "ROI",
    mroi_output_col: str = "MROI",
    gmroi_output_col: str = "GMROI",
    shift_suffix: str = "_shifted",
):
    """
    Function to calculate ROI MROI and GMROI

    Expects that the required columns as indicated by input kwargs contain arrays
    that are already sorted in order of uplift.

    `sell_out_input_col`: column containing array of sell out
    `spend_input_col`: column containing array of spend
    `gm_input_col`: column containing gross margin %
    `roi_output_col`: name of column to be added to contain ROI array
    `mroi_output_col`: name of column to be added to contain MROI array
    `gmroi_output_col`: name of column to be added to contain GMROI array
    `shift_suffix`: suffix to be added to create temporary columns of sellout and spend (shifted)
    """

    # ROI - simple calculation
    with np.errstate(divide="ignore", invalid="ignore"):
        df[roi_output_col] = df.apply(
            lambda row: row[sell_out_input_col] / row[spend_input_col],
            axis=1,
        )

    # GMROI: This is a deprecated metric in MMX.
    # Instead, the `sell_out_input_col` (used to calculate ROI)
    #   is expected to be already adjusted for GM.
    # The UI still requires GMROI to be returned to match database schemas for scenario creation,
    #   so we must still continue to send this key (but it is not used)
    # However, we return empty array to reduce payload size.
    df[gmroi_output_col] = df.apply(lambda _: [], axis=1)

    # MROI - shift then apply marginal calculations
    temp_cols = []
    for c in [spend_input_col, sell_out_input_col]:
        temp_col_name = f"{c}{shift_suffix}"
        df[temp_col_name] = shift_roll(df, c)
        temp_cols.append(temp_col_name)

    with np.errstate(divide="ignore", invalid="ignore"):
        df[mroi_output_col] = df.apply(
            lambda row: (
                row[f"{sell_out_input_col}{shift_suffix}"] - row[sell_out_input_col]
            )
            / (row[f"{spend_input_col}{shift_suffix}"] - row[spend_input_col]),
            axis=1,
        )

    df = df.drop(temp_cols, axis=1)

    return df

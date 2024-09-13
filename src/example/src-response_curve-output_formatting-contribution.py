"""
Module for contributions
"""

import pandas as pd

from src.response_curve.output_formatting.utils import add_total_metrics
from src.utils.data_frames import reduce_data_frames
from src.utils.names import (
    F_CHANNEL_CODE,
    F_DELTA_TO_NULL_VALUE,
    F_FEATURE_BRAND_CONTRIBUTION,
    F_TOUCHPOINT,
    F_UPLIFT,
    F_VALUE_PRED,
)


def compute_feature_brand_contribution_df(
    delta_to_null_value_contribution_df,
    spend_value_yr_df,
    response_curves_manager,
    config,
):
    """
    Function to compute the contribution of each feature, for each brand, and each year
    """
    scenarios_summary_contribution_df = reduce_data_frames(
        frames=[delta_to_null_value_contribution_df, spend_value_yr_df], how="left"
    )

    scenarios_summary_contribution_df = add_total_metrics(
        scenarios_summary_contribution_df,
        response_level_time=config.get("RESPONSE_LEVEL_TIME"),
    )

    feature_brand_contribution_df = compute_contribution(
        scenarios_summary_contribution_df=scenarios_summary_contribution_df,
        column_year=response_curves_manager.column_year,
    )

    return feature_brand_contribution_df


def compute_contribution(scenarios_summary_contribution_df, column_year) -> pd.DataFrame:
    """
    Function to compute the contribution of each touchpoint over the total predicted yearly sell-out
    value (at uplift = 1), i.e. the share of current sell-out value that is due to the spend
    on the touchpoint (according to the model)
    """
    idx_columns = [
        "brand_name",
        F_TOUCHPOINT,
        column_year,
        F_CHANNEL_CODE,
        F_VALUE_PRED,
        F_DELTA_TO_NULL_VALUE,
    ]

    contribution_df = scenarios_summary_contribution_df.loc[
        scenarios_summary_contribution_df[F_UPLIFT] == 1,
        idx_columns,
    ].copy()

    contribution_df[F_FEATURE_BRAND_CONTRIBUTION] = (
        contribution_df[F_DELTA_TO_NULL_VALUE] / contribution_df[F_VALUE_PRED] * 100
    ).round(2)
    contribution_df = contribution_df.drop(columns={F_VALUE_PRED, F_DELTA_TO_NULL_VALUE})

    return contribution_df

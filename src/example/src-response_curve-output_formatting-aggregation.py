"""
Post processing module for data aggregation to yearly frequency
"""
import pandas as pd

from src.utils.data_frames import reduce_data_frames
from src.utils.names import (
    F_CHANNEL_CODE,
    F_FEATURE,
    F_SPEND,
    F_UPLIFT,
    F_VALUE_PRED,
)


def get_spend_value_yr_df(
    denormalized_output_df,
    response_curves_manager,
    config,
):
    """
    Function to create the aggregated predicted volume, at yearly level, and spend, at yearly level

    Args:
        - denormalized_output_df: Volume distribution from bayesian response model at weekly level
        - response_curves_manager: allow to identify the year for each year_week

    Return:
        - spend_value_yr_df: Dataframe including the value and the spends at yearly level
    """
    # Total spend associated to each scenario
    spend_yr_df = _get_yearly_aggregated_spend(
        denormalized_output_df=denormalized_output_df,
        response_curves_manager=response_curves_manager,
        config=config,
    )

    # Total yearly sell-out volume predicted for each scenario
    value_pred_yr_df = _get_yearly_aggregated_value_predictions(
        denormalized_output_df=denormalized_output_df,
        response_curves_manager=response_curves_manager,
        config=config,
    )

    # Add estimated yearly sell-out contribution
    spend_value_yr_df = reduce_data_frames(
        frames=[value_pred_yr_df, spend_yr_df],
        on=config.get("granularity_output")
        + [response_curves_manager.column_year, F_UPLIFT, F_CHANNEL_CODE],
        how="inner",
    )
    return spend_value_yr_df


def _get_yearly_aggregated_value_predictions(
    denormalized_output_df,
    response_curves_manager,
    config,
) -> pd.DataFrame:
    """
    Computes yearly value predictions for each uplift
    """
    column_year = response_curves_manager.column_year
    value_pred_yr_df = response_curves_manager.add_year(data_df=denormalized_output_df)
    # cols_volume = [F_VOLUME_PRED]
    cols_value = [F_VALUE_PRED]

    # Aggregate predicted values - careful special handling of values because
    # of categorical values
    value_pred_yr_df = value_pred_yr_df.groupby(
        config.get("granularity_output") + [column_year, F_UPLIFT, F_CHANNEL_CODE]
    )[cols_value].sum()

    value_pred_yr_df = value_pred_yr_df[value_pred_yr_df.notnull().any(axis=1)].reset_index()

    return value_pred_yr_df


def _get_yearly_aggregated_spend(
    denormalized_output_df,
    response_curves_manager,
    config,
) -> pd.DataFrame:
    """
    Computes yearly spend values for each uplift,
    and handles the conversion from execution, back to spend
    """
    # Add relevant year info. and convert execution variables to spend
    column_year = response_curves_manager.column_year
    scenarios_summary_df = response_curves_manager.add_year(data_df=denormalized_output_df.copy())
    scenarios_summary_df[F_SPEND] = scenarios_summary_df[F_FEATURE]

    # Get total feature value and spend per year (FY or CY)
    # min_count = 1 to keep NaN spend values (missing conversion execution metric to spend)
    # observed = True to keep only observed combinations (needed with pandas
    # category)
    idx_columns = config.get("granularity_output") + [column_year]
    scenarios_summary_df = scenarios_summary_df.groupby(
        idx_columns + [F_UPLIFT, F_CHANNEL_CODE],
        as_index=False,
        observed=True,
    )[[F_SPEND]].sum(min_count=1)

    scenarios_summary_df = response_curves_manager.conversion.correct_yearly_spend_level(
        scenarios_summary_df
    )

    return scenarios_summary_df

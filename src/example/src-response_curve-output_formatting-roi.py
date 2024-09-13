"""
Module to calculate ROIs
"""

import numpy as np
import pandas as pd

from src.response_curve.output_formatting.utils import add_total_metrics
from src.utils.data_frames import reduce_data_frames
from src.utils.names import (
    F_CONTRIBUTION_MARGIN_PER_UNIT,
    F_DELTA_TO_NULL_REVENUES,
    F_DELTA_TO_NULL_VALUE,
    F_PRICE_ASP_UNIT,
    F_ROI,
    F_ROS,
    F_SPEND,
)


def compute_roi_table(
    delta_to_null_value_uplift_df, spend_value_yr_df, response_curves_manager, config
):
    """Main function to compute ROI and ROS for each uplift. The function works in 4 steps:
    - Add the spend dataframe
    - Add the profitability metrics for each channel
    - Compute additive financial metrics
    - Compute the additive metrics for all channels
    - Compute ROIs for all channels and aggregation of channels
    """

    uplift_scenarios_df = reduce_data_frames(
        frames=[delta_to_null_value_uplift_df, spend_value_yr_df], how="left"
    )

    uplift_scenarios_df = add_profitability_metrics(
        feature_df=uplift_scenarios_df,
        response_curves_manager=response_curves_manager,
        relevant_metrics=["sell_out_asp", "sell_in_cm", "sell_in_asp_net"],
    )
    uplift_scenarios_df = compute_revenues_and_caap(uplift_scenarios_df)

    uplift_scenarios_df = add_total_metrics(uplift_scenarios_df, config.get("RESPONSE_LEVEL_TIME"))

    gm_multiplier = config.get("gm_of_sell_out")

    (
        roi_table_df,
        roi_table_new,
    ) = compute_marketing_and_trade_financial_effectiveness_metrics(
        feature_df=uplift_scenarios_df, gm_multiplier=gm_multiplier
    )
    return roi_table_df, roi_table_new


def add_profitability_metrics(
    feature_df,
    response_curves_manager,
    relevant_metrics,
):
    """
    docstring
    """
    feature_new_df = feature_df

    for asp in relevant_metrics:
        metric_df = response_curves_manager.get_conversion_table(asp)

        if metric_df is None or metric_df.empty:
            continue

        for col in feature_df.columns.intersection(metric_df.columns).to_list():
            metric_df[col] = metric_df[col].astype(feature_df[col].dtype)
            if col == response_curves_manager.column_year:
                metric_df[col] = metric_df[col].astype(int).astype(feature_df[col].dtype)

        feature_new_df = feature_new_df.merge(
            metric_df,
            on=feature_df.columns.intersection(metric_df.columns).to_list(),
            how="left",
        )
    return feature_new_df


def compute_revenues_and_caap(feature_df):
    """
    docstring
    """
    roi_df = feature_df.copy()

    # Keep ref volume and null volume for metric feature contribution
    for percentile in ["mean", "p10", "p90"]:
        suffix = ("_" + percentile) if percentile != "mean" else ""

        roi_df[F_DELTA_TO_NULL_REVENUES + suffix] = (
            roi_df[F_DELTA_TO_NULL_VALUE + suffix] 
        )
        # TODO: Dip - Removed * roi_df[F_PRICE_ASP_UNIT] as we don't have price per unit

        # roi_df["contribution_margin" + suffix] = (
        #     roi_df[F_DELTA_TO_NULL_VALUE + suffix] * roi_df[F_CONTRIBUTION_MARGIN_PER_UNIT]
        # )

    return roi_df


def compute_marketing_and_trade_financial_effectiveness_metrics(feature_df, gm_multiplier):
    """
    Function centralizing the logic used to compute all relevant financial return metrics

    Args:
        - feature_df: Table containing all volume uplifts, spends & financial profitability metrics
        (e.g. ASP, CM) which are needed to compute the financial return KPIs. This table is created
        from the scenarios_summary_df table outside of this function.
    """

    roi_df = feature_df.copy()

    # Keep ref volume and null volume for metric feature contribution
    for percentile in ["mean", "p10", "p90"]:
        suffix = ("_" + percentile) if percentile != "mean" else ""

        # Divide incremental revenue by total spend to get the ROI
        roi_df[F_ROS + suffix] = compute_return_on_sell_out(
            sell_out=roi_df[F_DELTA_TO_NULL_REVENUES + suffix],
            marketing_and_trade_spend=roi_df[F_SPEND],
        )
        # roi_df[F_ROI + suffix] = compute_return_on_investment(
        #     contribution=roi_df["contribution_margin" + suffix],
        #     marketing_and_trade_spend=roi_df[F_SPEND],
        # )

    # JEEYOUNG ADDED NEW ROIs
    roi_df_new = feature_df.copy()
    roi_df_new_output = compute_return_on_investment_new(roi_df_new, 1.01, gm_multiplier)
    return roi_df, roi_df_new_output


def compute_return_on_investment(
    contribution: pd.Series, marketing_and_trade_spend: pd.Series
) -> pd.Series:
    """
    Return ROI
    """
    return (
        (contribution / marketing_and_trade_spend).rename(F_ROI).replace(np.inf, np.nan)
    )  # ROI calculated as Incremental / spend


def compute_return_on_sell_out(
    sell_out: pd.Series,
    marketing_and_trade_spend: pd.Series,
) -> pd.Series:
    """
    Return ROS
    """
    return (sell_out / marketing_and_trade_spend).rename(F_ROS).replace(np.inf, np.nan)


def compute_return_on_investment_new(roi_input, uplift_marginal, gm_multiplier):
    """
    Returns mROI, GM ROI, NET ROI for each touchpoint
    """

    touchpoint_list = []
    mROI_list = []
    GMROI_list = []
    NETROI_list = []
    ROI_list = []
    value_uplift1 = []
    value_uplift1m = []
    spend_uplift1 = []
    spend_upliftm = []

    for ch in roi_input["touchpoint"].unique().tolist():
        # val_1, val_2_marginal = incremental sales when uplift = 1 and uplift
        # = marginal (0.01)
        val_1 = roi_input[(roi_input["touchpoint"] == ch) & (roi_input["uplift"] == 1.0)][
            "delta_to_null_value"
        ].tolist()[0]
        val_1_marginal = roi_input[
            (roi_input["touchpoint"] == ch) & (roi_input["uplift"] == uplift_marginal)
        ]["delta_to_null_value"].tolist()[0]
        # spend_1, spend_1_marginal = spend when uplift = 1 and uplift =
        # marginal (0.01)
        spend_1 = roi_input[(roi_input["touchpoint"] == ch) & (roi_input["uplift"] == 1.0)][
            "spend"
        ].tolist()[0]
        spend_1_marginal = roi_input[
            (roi_input["touchpoint"] == ch) & (roi_input["uplift"] == uplift_marginal)
        ]["spend"].tolist()[0]

        touchpoint_list.append(ch)
        value_uplift1.append(val_1)
        value_uplift1m.append(val_1_marginal)
        spend_uplift1.append(spend_1)
        spend_upliftm.append(spend_1_marginal)

        spend_1_marginal = -1 * spend_1_marginal
        spend_1 = -1 * spend_1

        # mROI = row-wise difference is calculated using uplift = 1 and uplift
        # = 1.01
        mROI = np.divide(
            (val_1_marginal - val_1), (spend_1_marginal - spend_1)
        )  # MROI = (derivative of ROI d(contrib)/d(spend)
        mROI_list.append(mROI)

        # GM ROI = incremental sales at uplift 1 * 0.75 / spend
        gm_roi = np.divide(val_1 * 0.75, spend_1)
        GMROI_list.append(gm_roi)

        # Net ROI = incremental sales at uplift 1 / spend - 1 (Net ROI is obtained by substracting spend from the numerator)
        net_roi = np.divide(val_1, spend_1) - 1
        NETROI_list.append(net_roi)

        # ROI = incremental sales at uplift 1 / spend
        roi = np.divide(val_1, spend_1)
        ROI_list.append(roi)

    df_roi_output = pd.DataFrame(
        {
            "touchpoint": touchpoint_list,
            "value_uplift1": value_uplift1,
            "value_uplift1_marginal": value_uplift1m,
            "spend_uplift1": spend_uplift1,
            "spend_uplift1_marginal": spend_upliftm,
            "mROI": mROI_list,
            "GMROI": GMROI_list,
            "NETROI": NETROI_list,
            "ROI": ROI_list,
            "gm_multiplier": gm_multiplier,
        }
    )
    return df_roi_output

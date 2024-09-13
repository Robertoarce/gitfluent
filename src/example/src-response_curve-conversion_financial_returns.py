"""Conversion financial returns module

Returns:
    [type] -- [description]
"""
import logging
from typing import List

import numpy as np
import pandas as pd

from src.utils.names import (
    F_COGS,
    F_CONTRIBUTION_MARGIN_PER_UNIT,
    F_PRICE_ASP_UNIT,
    F_PRICE_ASP_UNIT_NET,
    F_ROI,
    F_ROS,
    F_SALES_NET,
    F_VALUE,
    F_VOLUME,
)
from src.utils.schemas.response_model.input import (
    FinanceFactsSchema,
    ProductMasterSchema,
)
from src.utils.schemas.response_model.output.response_curve import ResponseCurveSchema

logger = logging.getLogger(__name__)


pms = ProductMasterSchema()
rcs = ResponseCurveSchema()
fcs = FinanceFactsSchema()


def build_finance_facts(
    finance_facts: pd.DataFrame,
    sellout_df: pd.DataFrame,
    granularity: List[str],
    column_year: str,
    config,
):
    """
    Builds finance facts DataFrame by merging finance and sellout data.

    Args:
        finance_facts (pd.DataFrame): The finance facts DataFrame.
        sellout_df (pd.DataFrame): The sellout data DataFrame.
        granularity (List[str]): A list of granularity columns for merging.
        column_year (str): The year column name.
        config: Configuration information.

    Returns:
        pd.DataFrame: The merged finance facts DataFrame.
    """
    if finance_facts.empty:
        finance_facts_wide = finance_facts.drop(columns=[F_VALUE])
    else:
        finance_facts_wide = finance_facts.pivot_table(
            index=granularity + [column_year],
            columns="account",
            values="value",
            aggfunc="sum",
        )

    sellout_df_agg = (
        sellout_df.groupby(granularity + [column_year])[[F_VALUE, F_VOLUME]].sum().reset_index()
    )

    finance_facts_wide = sellout_df_agg.merge(
        finance_facts_wide, on=granularity + [column_year], how="left", validate="1:1"
    )

    required_columns = [
        F_SALES_NET,
        F_COGS,
    ]

    for col in required_columns:
        if col not in finance_facts_wide.columns:
            finance_facts_wide[col] = np.nan

    finance_facts_wide[F_CONTRIBUTION_MARGIN_PER_UNIT] = (
        finance_facts_wide[F_SALES_NET] - finance_facts_wide[F_COGS]
    ) / finance_facts_wide[F_VOLUME]
    finance_facts_wide[F_PRICE_ASP_UNIT_NET] = (
        finance_facts_wide[F_SALES_NET] / finance_facts_wide[F_VOLUME]
    )
    finance_facts_wide[F_PRICE_ASP_UNIT] = (
        finance_facts_wide[F_VALUE] / finance_facts_wide[F_VOLUME]
    )

    return finance_facts_wide


def compute_return_on_investment(
    contribution: pd.Series, marketing_and_trade_spend: pd.Series
) -> pd.Series:
    """
    Computes Return on Investment (ROI).

    Args:
        contribution (pd.Series): The contribution series.
        marketing_and_trade_spend (pd.Series): The marketing and trade spend series.

    Returns:
        pd.Series: The computed ROI series.
    """
    return ((contribution / marketing_and_trade_spend) - 1).rename(F_ROI).replace(np.inf, np.nan)


def compute_contribution_after_advertising_and_promo_spend(
    volume_uplift: pd.Series,
    sell_in_cm: pd.Series,
    marketing_and_trade_spend: pd.Series,
) -> pd.Series:
    """
    Computes Contribution After Advertising and Promo Spend (CAAP).

    Args:
        volume_uplift (pd.Series): The volume uplift series.
        sell_in_cm (pd.Series): The sell-in CM series.
        marketing_and_trade_spend (pd.Series): The marketing and trade spend series.

    Returns:
        pd.Series: The computed CAAP series.
    """
    return sell_in_cm * volume_uplift - marketing_and_trade_spend


def compute_sell_out(
    volume_uplift: pd.Series,
    sell_out_asp: pd.Series,
) -> pd.Series:
    """
    Computes Sell Out.

    Args:
        volume_uplift (pd.Series): The volume uplift series.
        sell_out_asp (pd.Series): The sell-out ASP series.

    Returns:
        pd.Series: The computed Sell Out series.
    """
    return sell_out_asp * volume_uplift


def compute_return_on_sell_out(
    sell_out: pd.Series,
    marketing_and_trade_spend: pd.Series,
) -> pd.Series:
    """
    Computes Return on Sell Out (ROS).

    Args:
        sell_out (pd.Series): The sell-out series.
        marketing_and_trade_spend (pd.Series): The marketing and trade spend series.

    Returns:
        pd.Series: The computed ROS series.
    """
    return (sell_out / marketing_and_trade_spend).rename(F_ROS).replace(np.inf, np.nan)

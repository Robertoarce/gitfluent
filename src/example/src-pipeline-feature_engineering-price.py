'''
Pricing module
'''
from typing import List, Tuple

import numpy as np
import pandas as pd

from src.utils.names import F_PERIOD_START, F_PRICE_ASP, F_VALUE, F_VOLUME
from src.utils.settings_utils import all_settings_dict


def single_touchpoint_level(config, touchpoint, channel_code) -> List[str]:
    """
    This function returns a list of levels for a single touchpoint based on configuration.

    Args:
        config: The configuration object.
        touchpoint: The touchpoint.
        channel_code: The channel code.

    Returns:
        List[str]: A list of levels.
    """
    if touchpoint in all_settings_dict(config)[channel_code]:
        if "granularity" in all_settings_dict(config)[channel_code][touchpoint]:
            return [
                "brand_name",
                all_settings_dict(config)[channel_code][touchpoint]["granularity"],
                config.get("RESPONSE_LEVEL_TIME"),
            ]
    return list(config.get("RESPONSE_LEVEL"))


def response_level_for_touchpoint(config, touchpoint, channel_code) -> List[str]:
    """
    This function returns a list of levels for a given touchpoint and channel based on configuration.

    Args:
        config: The configuration object.
        touchpoint: The touchpoint.
        channel_code: The channel code.

    Returns:
        List[str]: A list of levels.
    """
    granularity_list = config.get("STAN_PARAMETERS")["channels"][channel_code]
    if "granularity" not in granularity_list:
        return list(config.get("RESPONSE_LEVEL"))

    if isinstance(touchpoint, str):
        return single_touchpoint_level(config, touchpoint, channel_code)

    elif isinstance(touchpoint, list):
        return list(
            {f for tp in touchpoint for f in single_touchpoint_level(
                config, tp, channel_code
                )}
            )

def create_feature_as_gap_to_brand_reference_level(
    config,
    feature_df: pd.DataFrame,
    col_feature: str,
    channel_code: str,
    col_feature_ref: str = None,
    is_ratio_to_ref: bool = False,
    quantile_reference: float = 0.1,
    force_positive_feature: bool = False,
) -> Tuple[pd.DataFrame, pd.DataFrame, List]:
    """
    Function to transform a feature in absolute value to a gap with
    a reference level for that feature.

    Args:
        config: The configuration object.
        feature_df: The input feature DataFrame.
        col_feature: Name of the feature to transform.
        channel_code: The channel code.
        col_feature_ref: Name of reference column in the output.
        is_ratio_to_ref: Whether to compute the feature as a ratio to the reference.
        quantile_reference: Quantile used to compute the reference price.
        force_positive_feature: Whether to force the gap to be positive.

    Returns:
        Tuple[pd.DataFrame, pd.DataFrame, List]:
        - feature_df: Table with the residual feature.
        - feature_bulk_df: Table with bulk of feature that was filtered out.
        - ref_level: List of reference levels.
    """
    assert (quantile_reference >= 0) & (quantile_reference <= 1)

    if len(response_level_for_touchpoint(config, col_feature, channel_code)) > len(
        config.get("RESPONSE_LEVEL")
    ):
        ref_level = [
            config.get("RESPONSE_LEVEL_PRODUCT"),
            config.get("STAN_PARAMETERS")["predictor_parameters"][col_feature]["granularity"],
        ]
    else:
        ref_level = [config.get("RESPONSE_LEVEL_PRODUCT")]

    ref_level = [x.lower() for x in ref_level]

    # 1. Compute the feature reference level
    is_ref_column_returned = bool(col_feature_ref)
    col_feature_ref = "_".join([col_feature, "ref"]) if not col_feature_ref else col_feature_ref
    ref_df = (
        feature_df.groupby(ref_level)[col_feature]
        .quantile(q=quantile_reference)
        .rename(col_feature_ref)
    )

    # 2. Compute gap to reference level (forced to be positive)
    feature_df = feature_df.merge(ref_df, on=ref_level, how="inner")
    feature_df[col_feature + "_raw"] = feature_df[col_feature].copy()
    feature_df[col_feature] = feature_df[col_feature] - feature_df[col_feature_ref]
    feature_raw = feature_df[col_feature + "_raw"].sum()

    # 3. Clip to force gap to be positive
    if force_positive_feature:
        print(f"[FEATURES] Negative values of `{col_feature}` are capped to 0")
        feature_df[col_feature] = feature_df[col_feature].clip(0)

    # 4. Compute bulk of feature that was filtered out (must be kept for spends)
    feature_bulk_df = feature_df[
        response_level_for_touchpoint(config, col_feature, channel_code) + [col_feature]
    ].copy()
    feature_bulk_df[col_feature] = feature_df[col_feature + "_raw"] - feature_bulk_df[col_feature]
    feature_check = feature_bulk_df[col_feature].sum() + feature_df[col_feature].sum()
    assert np.abs(feature_raw - feature_check) <= 10 ** (-3)

    # 5. Compute feature as a discount / gap ratio vs the reference
    if is_ratio_to_ref:
        print(f"[FEATURES] `{col_feature}` feature computed as ratio to reference level")
        feature_df[col_feature] = feature_df[col_feature] / feature_df[col_feature_ref].replace(
            0, 1
        )
    else:
        print(f"[FEATURES] Building `{col_feature}` feature as a gap to reference level")

    if not is_ref_column_returned:
        feature_df = feature_df.drop(columns=[col_feature_ref])

    feature_df = feature_df.drop(columns=[col_feature + "_raw"])

    return feature_df, feature_bulk_df, ref_level


def compute_price_discount_feature(
    config,
    sell_out_agg_df: pd.DataFrame,
    channel_code: str,
    quantile_reference: float,
    suffix: str = "",
) -> pd.DataFrame:
    """
    Relative apparent discount compared to the baseline price defined as xth
    percentile of observed average prices (where x = quantile_reference * 100)

    Price influenced by product & distribution channel mixes
    """
    sell_out_agg_df[F_PRICE_ASP + suffix] = (
        sell_out_agg_df[F_VALUE + suffix] / sell_out_agg_df[F_VOLUME + suffix]
    )

    col_feature = "relative_gap_to_90th_price" + suffix
    sell_out_agg_df[col_feature] = sell_out_agg_df[F_PRICE_ASP + suffix].copy()
    sell_out_agg_df, _, _ = create_feature_as_gap_to_brand_reference_level(
        config,
        feature_df=sell_out_agg_df,
        col_feature=col_feature,
        channel_code=channel_code,
        col_feature_ref = None,
        quantile_reference=quantile_reference,
        is_ratio_to_ref=True,
        force_positive_feature=False,
    )

    sell_out_agg_df[col_feature] = sell_out_agg_df[col_feature] * (-1)
    
    return sell_out_agg_df


def construct_basic_price_discount_feature(
    config,
    sell_out_df: pd.DataFrame,
    channel_code: str,
    quantile_reference: float = 0.9,
) -> pd.DataFrame:
    """
        Calculate price discount features based on: mix of promo & non-promo sales
    """

    sell_out_df[config.get("RESPONSE_LEVEL_TIME")] = (
        pd.to_datetime(sell_out_df[F_PERIOD_START])
        .dt.strftime("%Y%m")
        .astype(int)
    )

    # Aggregate sell-out at the right granularity
    sell_out_agg_df = (
        sell_out_df.reset_index(drop=True)
        .groupby(
            response_level_for_touchpoint(config, "relative_gap_to_90th_price", channel_code),
            as_index=False,
        )[
            [F_VALUE]
        ]
        .sum()
    )

    ref_level = response_level_for_touchpoint(config, "relative_gap_to_90th_price", channel_code)

    price_df = sell_out_agg_df[
        ref_level
        + [
            F_VALUE,
        ]
    ]
    price_df.drop("compute_price_discount_feature", inplace=True, errors="ignore")
    return price_df, ref_level
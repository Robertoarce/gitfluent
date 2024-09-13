"""
Piecewise parameters define the discretized response curve for use in the optimizer.
"""
from collections import defaultdict
from dataclasses import dataclass
from typing import Dict, Set

import pandas as pd


@dataclass
class PiecewiseParameters:
    """
    Dictionaries that allow us to reference spend vs. sell out via uplift,
    as calculated in `compute_piecewise_parameters`
    """

    upliftidx_at_region_market_brand_channel_speciality_segment: Dict
    uplift_at_region_market_brand_channel_speciality_segment_upliftidx: Dict
    spend_at_uplift_1: Dict
    incr_sell_out_value_by_upliftidx: Dict
    incr_sell_out_volume_by_upliftidx: Dict


def compute_piecewise_parameters(
    response_curves_projected_df: pd.DataFrame,
    set_region_market_brand_channel_speciality_segment_upliftidx_domain: Set,
):
    """
    Returns an instance of PiecewiseParameters:

    `upliftidx_at_market_brand_channel_speciality_segment` is a dictionary:
        (market, brand, channel, speciality, segment) -> List[int]
        representing uplift indices on the curve identified by the 5-tuple key.

    `uplift_at_market_brand_channel_speciality_segment_upliftidx` is a dictionary:
        (market, brand, channel, speciality, segment, upliftidx) -> List[float]
        representing the actual uplift value at a given upliftidx on a given curve.

    `spend_at_uplift_1` is a dictionary:
        (market, brand, channel, speciality, segment) -> float
        representing the spend on the curve identified by the 5-tuple key at uplift 1.

    `incr_sell_out_value_by_upliftidx` is a dictionary:
        (market, brand, channel, speciality, segment, upliftidx) -> List[float]
        representing the sell out value at a given point on the curve.

    `incr_sell_out_volume_by_upliftidx` is a dictionary:
        (market, brand, channel, speciality, segment, upliftidx) -> List[float]
        representing the sell out volume at a given point on the curve.
    """

    idx = [
        "region_name",
        "market_code",
        "brand_name",
        "channel_code",
        "speciality_code",
        "segment_value",
    ]

    upliftidx_at_region_market_brand_channel_speciality_segment = _domain_to_curve_uplifts_dict(
        set_region_market_brand_channel_speciality_segment_upliftidx_domain
    )

    uplift_at_region_market_brand_channel_speciality_segment_upliftidx = (
        response_curves_projected_df.set_index(idx + ["curve_uplift_idx"])["uplift"].to_dict()
    )

    spend_at_uplift_1 = (
        response_curves_projected_df[response_curves_projected_df["uplift"] == 1]
        .set_index(idx)["spend"]
        .to_dict()
    )

    incr_sell_out_value_by_upliftidx = response_curves_projected_df.set_index(
        idx + ["curve_uplift_idx"]
    )["incremental_sell_out_value"].to_dict()

    if "incremental_sell_out_units" in response_curves_projected_df.columns:
        incr_sell_out_volume_by_upliftidx = response_curves_projected_df.set_index(
            idx + ["curve_uplift_idx"]
        )["incremental_sell_out_units"].to_dict()
    else:
        # Special case for when price per unit is not provided in the data.
        incr_sell_out_volume_by_upliftidx = defaultdict(lambda: 0)

    return PiecewiseParameters(
        # fmt: off
        # flake8: noqa
        upliftidx_at_region_market_brand_channel_speciality_segment=\
            upliftidx_at_region_market_brand_channel_speciality_segment,
        uplift_at_region_market_brand_channel_speciality_segment_upliftidx=\
            uplift_at_region_market_brand_channel_speciality_segment_upliftidx,
        # fmt: on
        spend_at_uplift_1=spend_at_uplift_1,
        incr_sell_out_value_by_upliftidx=incr_sell_out_value_by_upliftidx,
        incr_sell_out_volume_by_upliftidx=incr_sell_out_volume_by_upliftidx,
    )


def _domain_to_curve_uplifts_dict(
    set_region_market_brand_channel_speciality_segment_upliftidx_domain,
):
    """
    Turns a domain of (market x brand x channel x speciality x segment x uplift)
    into required dictionary format.
    """
    upliftidx_at_region_market_brand_channel_speciality_segment = defaultdict(list)
    for (
        region,
        market,
        brand,
        channel,
        speciality,
        segment,
        upliftidx,
    ) in set_region_market_brand_channel_speciality_segment_upliftidx_domain:
        upliftidx_at_region_market_brand_channel_speciality_segment[
            (region, market, brand, channel, speciality, segment)
        ].append(upliftidx)

    return upliftidx_at_region_market_brand_channel_speciality_segment

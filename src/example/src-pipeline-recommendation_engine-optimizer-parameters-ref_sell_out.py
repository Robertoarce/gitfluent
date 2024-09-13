"""
Calculate sell out volume and value parameters at reference year.
"""
from collections import defaultdict
from dataclasses import dataclass
from typing import Dict

import pandas as pd


@dataclass
class RefSellOut:
    """
    Dataclass to hold reference volume
    """

    incr_sell_out_volume_ref_dic: Dict
    base_sell_out_volume_ref_dic: Dict
    incr_sell_out_value_ref_dic: Dict
    base_sell_out_value_ref_dic: Dict


def compute_ref_sell_out_parameters(response_curves_reference_df: pd.DataFrame):
    """
    Calculates the following dictionary as in `RefSellOut`:

    incr_volume_ref_dic:{
        (region, market, brand, channel, speciality, segment): value
    }
    where value is the amount of incremental volume (units)

    base_volume_ref_dic:{
        (region, market, brand): value
    }
    where value is the amount of baseline volume (units)

    incr_sell_out_value_ref_dic:{
        (region, market, brand, channel, speciality, segment): value
    }
    where value is the amount of incremental sell out (currency)

    base_sell_out_value_ref_dic:{
        (region, market, brand): value
    }
    where value is the amount of baseline sell out (currency)
    """
    if ("incremental_sell_out_units" in response_curves_reference_df.columns) and (
        "baseline_sell_out_units" in response_curves_reference_df.columns
    ):
        incr_sell_out_volume_ref_dic = response_curves_reference_df.set_index(
            [
                "region_name",
                "market_code",
                "brand_name",
                "channel_code",
                "speciality_code",
                "segment_value",
            ]
        )["incremental_sell_out_units"].to_dict()

        # baseline can only be identified at brand level.
        base_sell_out_volume_ref_dic = response_curves_reference_df.set_index(
            [
                "region_name",
                "market_code",
                "brand_name",
            ]
        )["baseline_sell_out_units"].to_dict()
    else:
        # Special case where units not provided
        incr_sell_out_volume_ref_dic = defaultdict(lambda: 0)
        base_sell_out_volume_ref_dic = defaultdict(lambda: 0)

    incr_sell_out_value_ref_dic = response_curves_reference_df.set_index(
        [
            "region_name",
            "market_code",
            "brand_name",
            "channel_code",
            "speciality_code",
            "segment_value",
        ]
    )["incremental_sell_out_value"].to_dict()

    base_sell_out_value_ref_dic = response_curves_reference_df.set_index(
        [
            "region_name",
            "market_code",
            "brand_name",
        ]
    )["baseline_sell_out_value"].to_dict()

    return RefSellOut(
        incr_sell_out_volume_ref_dic=incr_sell_out_volume_ref_dic,
        base_sell_out_volume_ref_dic=base_sell_out_volume_ref_dic,
        incr_sell_out_value_ref_dic=incr_sell_out_value_ref_dic,
        base_sell_out_value_ref_dic=base_sell_out_value_ref_dic,
    )

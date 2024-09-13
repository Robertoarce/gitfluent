"""
Calculate spend parameters at reference year.
"""
from dataclasses import dataclass
from typing import Dict

import pandas as pd


@dataclass
class RefSpend:
    """
    Dataclass to hold spend references.
    """

    spend_ref_dic: Dict


def compute_ref_spend_parameters(
    response_curves_reference_df: pd.DataFrame,
) -> RefSpend:
    """
    Calculates the following dictionary as in `RefSpend`:

    spend_ref_dic:{
        (region, market, brand, channel, speciality, segment): value
    }
    where value is the amount of spend
    """
    spend_ref_dic = response_curves_reference_df.set_index(
        [
            "region_name",
            "market_code",
            "brand_name",
            "channel_code",
            "speciality_code",
            "segment_value",
        ]
    )["spend"].to_dict()

    return RefSpend(
        spend_ref_dic=spend_ref_dic,
    )

"""
Financial parameters
"""
from collections import defaultdict
from dataclasses import dataclass
from typing import Dict

import pandas as pd


@dataclass
class FinancialParameters:
    """
    Various financial facts.
    Each key-value is a dictionary as created in `compute_financial_parameters`.
    """

    price_per_unit: Dict  # Average sales price / unit
    gm_of_sell_out: Dict  # Contributive margin %


def compute_financial_parameters(
    response_curves_reference_projected_df: pd.DataFrame,
) -> FinancialParameters:
    """
    Returns a nested dictionary-like:
    {
        metric:{
            (market, brand):
                value
        }
    }
    for each metric defined in FinancialParameters class.
    for each (market, brand) available in the response curves
    """
    # metric name -> column name
    metric_columns = {
        "price_per_unit": "price_per_unit",
        "gm_of_sell_out": "gm_of_sell_out",
    }

    financial_parameters = {}
    idx = [
        "region_name",
        "market_code",
        "brand_name",
    ]
    for metric, col in metric_columns.items():
        # Special case for when price per unit is not provided in the data.
        if (col not in response_curves_reference_projected_df.columns) and (
            metric == "price_per_unit"
        ):
            financial_parameters[metric] = defaultdict(lambda: 0)
            continue

        financial_parameters[metric] = (
            response_curves_reference_projected_df[idx + [col]]
            .drop_duplicates(subset=idx)
            .set_index(idx)[col]
            .to_dict()
        )

    return FinancialParameters(**financial_parameters)

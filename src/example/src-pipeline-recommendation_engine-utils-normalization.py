"""
Module regarding normalization for numerical stability.
"""
from typing import Dict

import pandas as pd

# normalize all columns that are spend (currency) or units.
COLUMNS_TO_SCALE = (
    "spend",
    "total_net_sales",
    "total_gm_incremental_sales",
    "baseline_sell_out_value",
    "incremental_sell_out_value",
    "total_units",
    "total_incremental_units",
    "baseline_sell_out_units",
    "incremental_sell_out_units",
)


def normalize_curves(
    response_curves_df: pd.DataFrame, config: Dict, pre: bool
) -> pd.DataFrame:
    """
    Renormalization for numerical stability.

    pre=True: preprocessing -> divide by normalization factor
    pre=False: postprocessing -> multiply by normalization factor
    """
    factor = config["normalization_factor"]
    if pre:
        factor = 1 / factor

    for col in COLUMNS_TO_SCALE:
        if col in response_curves_df.columns:
            response_curves_df[col] = response_curves_df[col] * factor

    return response_curves_df

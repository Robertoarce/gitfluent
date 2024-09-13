"""
Functions backing `/mmm-contributions/` endpoint.
"""
from typing import List, Optional

import numpy as np
import pandas as pd

from ..schemas import GBUCodeInput, MMMSalesContribution
from ..shared import (
    inner_join_query_to_available_models_str,
    pivot_response_curve_metrics,
)
from ..utils import query_to_pandas


def _build_query_mmm_contributions(
    gbu: GBUCodeInput, market_code: str, version_codes: Optional[List[str]]
):
    """
    Build the query for sales contribution data.
    """
    query = f"""
    SELECT
        rc.gbu_code,
        rc.market_code,
        rc.brand_name,
        rc.channel_code,
        CASE
            WHEN cm.channel_desc IS NOT NULL THEN cm.channel_desc
            ELSE rc.channel_code
        END AS channel_desc
        ,
        rc.speciality_code,
        rc.segment_value,
        rc.start_date,
        rc.version_code,
        rc.spend,
        rc.gm_adjusted_incremental_value_sales,
        rc.metric,
        rc.value
    FROM DMT_MMX.RESPONSE_CURVE rc
    LEFT JOIN DMT_MMX.CHANNEL_MASTER cm
        ON rc.channel_code = cm.channel_code
    {inner_join_query_to_available_models_str("rc", "am")}
    WHERE rc.uplift = 1
        AND rc.metric IN ('total_net_sales', 'gm_of_sell_out')
        AND am.gbu_code = %(gbu)s
        AND am.market_code = %(market_code)s
    """

    params = {"gbu": gbu.value, "market_code": market_code}

    if version_codes:
        query = query + "\n"
        query = query + "  AND rc.version_code IN (%(version_codes)s)"
        params["version_codes"] = version_codes

    return query, params


def get_mmm_contributions(gbu: GBUCodeInput, market_code: str, version_codes: Optional[List[str]]):
    """
    Function to get sales contribution data by channel for MMM Screens
    """

    # ------------------------
    #  Step 1: Query
    # ------------------------
    query, params = _build_query_mmm_contributions(
        gbu=gbu,
        market_code=market_code,
        version_codes=version_codes,
    )

    df = query_to_pandas(query, no_data_return=[], params=params)

    # ------------------------
    #  Step 2: Transform
    # ------------------------
    df["year"] = df["start_date"].dt.year
    df = df.drop(["start_date"], axis=1)

    df = pivot_response_curve_metrics(df)
    df["sell_out"] = df["gm_adjusted_incremental_value_sales"]

    # We can aggregate out the granularities below channel (specialty and
    # segment)
    agg_dims = [
        "speciality_code",
        "segment_value",
    ]

    outputs = []
    for d in range(0, len(agg_dims) + 1):
        # Brand is above channel granularity, so it is not aggregated out.
        # Year is also not aggregated out.
        idx = [
            "year",
            "market_code",
            "brand_name",
            "channel_code",
            "channel_desc",
        ] + agg_dims[:d]
        temp = (
            df.copy()
            .groupby(idx)
            .agg(
                {
                    "spend": "sum",
                    "sell_out": "sum",
                    "total_net_sales": "max",  # assumed to be unique across year and brand
                }
            )
        )
        temp = temp.reset_index()

        # append baseline level of sales at channel level
        if d == 0:
            baseline_dict = temp.copy().drop_duplicates(["year", "market_code", "brand_name"])
            baseline_dict["channel_code"] = "BASE"
            baseline_dict["channel_desc"] = "Base"
            baseline_dict["spend"] = np.nan
            baseline_dict["sell_out"] = baseline_dict["total_net_sales"] - temp["sell_out"].sum()
            temp = pd.concat([temp, baseline_dict])

        temp["ROI"] = temp["sell_out"] / temp["spend"]
        temp = temp.to_dict("records")

        outputs = outputs + [
            MMMSalesContribution(
                **{
                    k: (v if (not isinstance(v, float)) or (np.isfinite(v)) else None)
                    for k, v in d.items()
                }
            )
            for d in temp
        ]

    # ------------------------
    # Step 3: Return
    # ------------------------

    return outputs

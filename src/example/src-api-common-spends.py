"""
Functions backing the /spends/ endpoint.
"""

from typing import List, Optional, Tuple, Union

import numpy as np
import pandas as pd

from ..schemas import BrandSpend, ChannelSpend, GBUCodeInput, GBUMarketSpend, YearSpend
from ..utils import query_to_pandas


def _build_query_spends(
    gbu: GBUCodeInput,
    market_code: str,
    brand_name: List[str],
    min_year: Optional[int] = None,
    max_year: Optional[int] = None,
):
    """
    Build the query to get spend data
    """
    # fmt: off
    query = """
    SELECT
        s.gbu_code,
        s.market_code,
        mr.market_name,
        s.brand_name,
        s.year,
        s.channel_code,
        cm.channel_desc,
        s.interactions,
        -s.salesforce_spend AS salesforce_spend,
        -s.salesforce_cpi AS salesforce_cost_per_interaction,
        -s.promotion_spend AS promotion_spend,
        -s.promotion_cpi AS promotion_cost_per_interaction,
        -s.total_spend AS total_spend,
        -s.total_cost_per_interaction AS total_cost_per_interaction,
        s.currency
    FROM DMT_MMX.YEARLY_FINANCIAL_SPEND_EUR s
    JOIN DMT_MMX.MARKET_REGION_NO_CURRENCY mr
        ON s.market_code = mr.market_code
    JOIN DMT_MMX.CHANNEL_MASTER cm
        ON s.channel_code = cm.channel_code
    WHERE s.gbu_code = %(gbu)s
        AND s.market_code = %(market_code)s
    """
    # fmt: on

    params = {
        "gbu": gbu.value,
        "market_code": market_code,
    }

    if brand_name:
        query = query + "\n  AND s.brand_name IN (%(brand_name)s)"
        params["brand_name"] = brand_name

    if min_year:
        query = query + "\n  AND s.year >= %(min_year)s"
        params["min_year"] = min_year

    if max_year:
        query = query + "\n  AND s.year <= %(max_year)s"
        params["max_year"] = max_year

    return query, params


def _multi_column_match(
    df: pd.DataFrame, cols: Union[List[str], str], vals: Union[Tuple[str], str]
):
    """
    Returns the subset of the dataframe `df`
    where the values of `cols` match those of `vals`.
    """
    if isinstance(cols, str):
        return df[df[cols] == vals]

    return df[df.apply(lambda row: tuple(row[cols]) == vals, axis=1)]


def get_spends(
    gbu: GBUCodeInput,
    market_code: str,
    brand_name: List[str],
    min_year: Optional[int] = None,
    max_year: Optional[int] = None,
):
    """
    Get spend data for a given GBU/market/brand
    """

    # ------------------------
    #  Step 1: Query
    # ------------------------
    query, params = _build_query_spends(
        gbu=gbu,
        market_code=market_code,
        brand_name=brand_name,
        min_year=min_year,
        max_year=max_year,
    )

    df = query_to_pandas(query, no_data_return=[], params=params)

    # ------------------------
    # Step 2: Transform and Return
    # ------------------------
    idx_level = [
        ["gbu_code", "market_code", "market_name"],
        "brand_name",
        "year",
        ["channel_code", "channel_desc"],
    ]

    return [
        GBUMarketSpend(
            gbu_code=gc,
            market_code=mc,
            market_name=mn,
            brands=[
                BrandSpend(
                    brand_name=bd,
                    years=[
                        YearSpend(
                            year=yr,
                            channels=[
                                ChannelSpend(
                                    channel_code=chn_cd,
                                    channel_desc=chn_ds,
                                    # take the first one; assumed to be unique
                                    interactions=(
                                        df_gmbyc["interactions"].iloc[0]
                                        if not np.isnan(
                                            df_gmbyc["interactions"].iloc[0]
                                        )
                                        else None
                                    ),
                                    promotion_spend=(
                                        df_gmbyc["promotion_spend"].iloc[0]
                                        if not np.isnan(
                                            df_gmbyc["promotion_spend"].iloc[0]
                                        )
                                        else None
                                    ),
                                    salesforce_spend=df_gmbyc["salesforce_spend"].iloc[
                                        0
                                    ]
                                    if not np.isnan(
                                        df_gmbyc["salesforce_spend"].iloc[0]
                                    )
                                    else None,
                                    total_spend=df_gmbyc["total_spend"].iloc[0]
                                    if not np.isnan(df_gmbyc["total_spend"].iloc[0])
                                    else None,
                                    promotion_cost_per_interaction=(
                                        df_gmbyc["promotion_cost_per_interaction"].iloc[
                                            0
                                        ]
                                        if not np.isnan(
                                            df_gmbyc[
                                                "promotion_cost_per_interaction"
                                            ].iloc[0]
                                        )
                                        else None
                                    ),
                                    salesforce_cost_per_interaction=(
                                        df_gmbyc[
                                            "salesforce_cost_per_interaction"
                                        ].iloc[0]
                                        if not np.isnan(
                                            df_gmbyc[
                                                "salesforce_cost_per_interaction"
                                            ].iloc[0]
                                        )
                                        else None
                                    ),
                                    total_cost_per_interaction=(
                                        df_gmbyc["total_cost_per_interaction"].iloc[0]
                                        if not np.isnan(
                                            df_gmbyc["total_cost_per_interaction"].iloc[
                                                0
                                            ]
                                        )
                                        else None
                                    ),
                                    currency=df_gmbyc["currency"].iloc[0],
                                )
                                for (chn_cd, chn_ds), df_gmbyc in _multi_column_match(
                                    df_gmby, idx_level[2], yr
                                ).groupby(idx_level[3])
                            ],
                        )
                        for yr, df_gmby in _multi_column_match(
                            df_gmb, idx_level[1], bd
                        ).groupby(idx_level[2])
                    ],
                )
                for bd, df_gmb in _multi_column_match(
                    df_gm, idx_level[0], (gc, mc, mn)
                ).groupby(idx_level[1])
            ],
        )
        for (gc, mc, mn), df_gm in df.groupby(idx_level[0])
    ]

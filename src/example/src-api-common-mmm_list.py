"""
Functions backing `/mmm-list/` endpoint.
"""
import itertools
from collections import defaultdict
from typing import List

import pandas as pd

from ..schemas import GBUCodeInput, MMMScope, MMMSummary
from ..shared import inner_join_query_to_available_models_str, period_as_string
from ..utils import query_to_pandas


def _build_query_mmm_list(gbu: GBUCodeInput, market_code: str):
    """
    Builds the sqlalchemy query object to retrieve the required model data.
    """
    query = f"""
    SELECT DISTINCT
        am.version_code,
        am.model_name,
        ae.exercise_name,
        UPPER(rc.brand_name) AS brand_name,
        rc.start_date,
        rc.end_date,
        UPPER(rc.channel_code) AS channel_code,
        NVL(cm.channel_desc, rc.channel_code) AS channel_desc,
        UPPER(rc.speciality_code) AS speciality_code,
        UPPER(rc.segment_code) AS segment_code,
        UPPER(rc.segment_value) AS segment_value,
        rc.spend,
        rc.gm_adjusted_incremental_value_sales
    FROM DMT_MMX.RESPONSE_CURVE rc
    {inner_join_query_to_available_models_str("rc", "am", "ae", exercise_table_join_type="LEFT")}
    LEFT JOIN DMT_MMX.CHANNEL_MASTER cm
        ON rc.channel_code = cm.channel_code
    WHERE am.gbu_code = %(gbu)s
        AND am.market_code = %(market_code)s
        AND rc.uplift = 1
    """

    params = {
        "gbu": gbu.value,
        "market_code": market_code,
    }

    return query, params


def _get_year_scope(df: pd.DataFrame, col: str, desc_col: str = None) -> List[MMMScope]:
    """
    Get the list of years for which each value in column `col` exists.
    """
    if desc_col is None:
        desc_col_iter = itertools.repeat(None)
    else:
        desc_col_iter = df[desc_col].values

    key_iter = zip(df[col].values, desc_col_iter)

    key_year_set = sorted(
        list(set(zip(key_iter, df["start_year"].values, df["end_year"].values))),
        key=lambda x: x[1],
    )

    scope_dict = defaultdict(list)
    for key, start_yr, end_yr in key_year_set:
        scope_dict[key].append(start_yr)
        scope_dict[key].append(end_yr)

    return [
        MMMScope(scope_name=scope_name, scope_desc=scope_desc, integrated_years=years)
        for (scope_name, scope_desc), years in scope_dict.items()
    ]


def _get_avg_roi(df: pd.DataFrame):
    """
    Calculate ROI across all the curves.
    """
    # ensure we only take one point per curve

    df_unique = df.drop_duplicates(
        subset=[
            "brand_name",
            "channel_code",
            "speciality_code",
            "segment_code",
            "segment_value",
        ]
    )

    return (
        df_unique["gm_adjusted_incremental_value_sales"].sum()
        / df_unique["spend"].sum()
    )


def get_mmm_list(gbu: GBUCodeInput, market_code: str) -> List[MMMSummary]:
    """
    Function to get, transform, and return data for the model listing screen.
    """
    # ------------------------
    #  Step 1: Query
    # ------------------------
    query, params = _build_query_mmm_list(gbu=gbu, market_code=market_code)
    df = query_to_pandas(query, no_data_return=[], params=params)

    # ------------------------
    # Step 2: Transform
    # ------------------------

    df["start_year"] = df["start_date"].dt.year
    df["end_year"] = df["end_date"].dt.year

    out = []
    for (version_code, model_name), sub_df in df.groupby(
        ["version_code", "model_name"]
    ):
        out.append(
            MMMSummary(
                version_code=version_code,
                model_name=model_name,
                exercise_names=list(sub_df["exercise_name"].dropna().unique()),
                period=(sub_df["start_year"].min(), sub_df["end_year"].max()),
                period_str=period_as_string(
                    sub_df["start_date"].min(), sub_df["end_date"].max()
                ),
                cnt_brands=sub_df["brand_name"].nunique(),
                avg_roi=_get_avg_roi(sub_df),
                avg_saturation=None,  # TODO: provide this output
                scope_brands=_get_year_scope(sub_df, "brand_name"),
                scope_channels=_get_year_scope(sub_df, "channel_code", "channel_desc"),
            )
        )

    # ------------------------
    # Step 3: Return
    # ------------------------
    return out

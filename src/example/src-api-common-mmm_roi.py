"""
Functions backing `/mmm-roi/` endpoint.
"""
from typing import List, Optional

import numpy as np

from ..schemas import MMMROI, GBUCodeInput, MMMResults, PeriodValue
from ..shared import (
    argsort_by_uplift,
    calc_roi_mroi_gmroi,
    inner_join_query_to_available_models_str,
    period_as_string,
    pivot_response_curve_metrics,
)
from ..utils import query_to_pandas

RC_METRICS = [
    "gm_of_sell_out",
    "price_per_unit",
    "currency",
    "total_units",
    "total_net_sales",
]


# pylint: disable=unused-argument
def _build_query_mmm_roi(
    gbu: GBUCodeInput,
    market_code: str,
    version_codes: Optional[List[str]],
    brand_name: Optional[str],
    channel_code: Optional[str],
    speciality_code: Optional[str],
    segment_value: Optional[str],
):
    """
    Builds the sqlalchemy query object to retrieve the relevant response curve data.
    """
    query = f"""
    SELECT
        rc.gbu_code,
        rc.version_code,
        rc.market_code,
        mr.region_name,
        UPPER(rc.brand_name) AS brand_name,
        UPPER(rc.channel_code) as channel_code,
        CASE
            WHEN cm.channel_desc IS NOT NULL THEN cm.channel_desc
            ELSE rc.channel_code
        END AS channel_desc,
        UPPER(rc.speciality_code) AS speciality_code,
        UPPER(rc.segment_value) AS segment_value,
        rc.start_date,
        rc.end_date,
        rc.metric,
        rc.value,
        rc.spend,
        rc.uplift,
        rc.gm_adjusted_incremental_value_sales
    FROM DMT_MMX.RESPONSE_CURVE rc
    JOIN DMT_MMX.MARKET_REGION_NO_CURRENCY mr
        ON rc.market_code = mr.market_code
    LEFT JOIN DMT_MMX.CHANNEL_MASTER cm
        ON rc.channel_code = cm.channel_code
    {inner_join_query_to_available_models_str("rc", "am")}
    WHERE am.gbu_code = %(gbu)s
        AND am.market_code = %(market_code)s
        AND rc.metric IN (%(metrics)s)
    """

    params = {"gbu": gbu.value, "market_code": market_code, "metrics": RC_METRICS}

    if version_codes:
        query = query + "\n"
        query = query + "  AND rc.version_code IN (%(version_codes)s)"
        params["version_codes"] = version_codes
    if channel_code:
        query = query + "\n"
        query = query + "  AND rc.channel_code = %(channel_code)s"
        params["channel_code"] = channel_code
    if brand_name:
        query = query + "\n"
        query = query + "  AND rc.brand_name = %(brand_name)s"
        params["brand_name"] = brand_name
    if speciality_code:
        query = query + "\n"
        query = query + "  AND rc.speciality_code = %(speciality_code)s"
        params["speciality_code"] = speciality_code
    if segment_value:
        query = query + "\n"
        query = query + "  AND rc.segment_value = %(segment_value)s"
        params["segment_value"] = segment_value

    return query, params


# pylint: disable=unused-argument,too-many-locals
def get_mmm_roi(
    gbu: GBUCodeInput,
    market_code: str,
    version_codes: Optional[List[str]],
    brand_name: Optional[str],
    channel_code: Optional[str],
    speciality_code: Optional[str],
    segment_value: Optional[str],
) -> MMMResults:
    """
    Function to get, transform, and return ROI data for MMM screens.
    """

    # ------------------------
    #  Step 1: Query
    # ------------------------
    query, params = _build_query_mmm_roi(
        gbu=gbu,
        market_code=market_code,
        version_codes=version_codes,
        brand_name=brand_name,
        channel_code=channel_code,
        speciality_code=speciality_code,
        segment_value=segment_value,
    )
    df = query_to_pandas(query, no_data_return={}, params=params)

    # MOCK DATA FOR COST PER INTERACTION
    # df["cost_per_interaction"] = 5
    # df["num_interactions"] = df["spend"] / df["cost_per_interaction"]
    # ------------------------
    # Step 2: Transform
    # ------------------------
    df["num_interactions"] = 0  # PATCH: fake data.
    df["period"] = df.apply(
        lambda row: period_as_string(row["start_date"], row["end_date"]), axis=1
    )
    df = df.drop(["start_date", "end_date"], axis=1)

    df = pivot_response_curve_metrics(df)

    # fill unavailable metrics with nan.
    # non-string metrics should be float.
    for m in RC_METRICS:
        if m not in df.columns:
            df[m] = np.nan

    df["historical"] = df["uplift"] == 1

    df["incr_sellout"] = df["gm_adjusted_incremental_value_sales"]

    # aggregate as appropriate
    df = df.groupby(
        [
            "version_code",
            "market_code",
            "region_name",
            "brand_name",
            "channel_code",
            "channel_desc",
            "speciality_code",
            "segment_value",
            "period",
            "currency",
        ]
    ).agg(
        {
            "num_interactions": list,
            "spend": list,
            "uplift": list,
            "historical": list,
            "incr_sellout": list,
            "gm_of_sell_out": "mean",
            "price_per_unit": "mean",
            "total_units": "mean",
            "total_net_sales": "mean",
        }
    )

    # transform lists to arrays
    for c in [
        "num_interactions",
        "spend",
        "uplift",
        "historical",
        "incr_sellout",
    ]:
        df[c] = df[c].apply(np.array)

    df = argsort_by_uplift(
        df,
        uplift_col="uplift",
        cols_to_sort=[
            "num_interactions",
            "spend",
            "historical",
            "incr_sellout",
        ],
    )

    df["historical_index"] = df["historical"].apply(lambda a: np.min(np.nonzero(a)[0]))

    df = calc_roi_mroi_gmroi(
        df,
        sell_out_input_col="incr_sellout",
        spend_input_col="spend",
    )

    # ------------------------
    # Step 3: Return
    # ------------------------
    curves = [
        MMMROI(
            version_code=vc,
            market_name=market_nm,  # TO BE REMOVED
            market_code=market_nm,
            region_name=region_nm,
            brand_name=brand_nm,
            channel_code=channel_cd,
            channel_desc=channel_desc,
            specialty_name=specialty_nm,  # TO BE REMOVED
            speciality_code=specialty_nm,
            segment_name=segment_val,  # TO BE REMOVED
            segment_value=segment_val,
            period=period,
            currency=currency,
            historical_index=value["historical_index"],
            # Points along the curve collected in lists.
            # Filter out np.nan for JSON compatibility.
            **{
                kpi: [x if np.isfinite(x) else None for x in value[kpi]]
                for kpi in [
                    "num_interactions",
                    "spend",
                    "historical",
                    "incr_sellout",
                    "uplift",
                    "ROI",
                    "MROI",
                    "GMROI",
                ]
            },
        )
        for (
            vc,
            market_nm,
            region_nm,
            brand_nm,
            channel_cd,
            channel_desc,
            specialty_nm,
            segment_val,
            period,
            currency,
        ), value in df.to_dict("index").items()
    ]

    df = df.reset_index()

    # Index of actual spend/sellout (where uplift == 1), and calculate results
    df["actual_index"] = df["uplift"].apply(lambda x: np.flatnonzero(x == 1)[0])

    # Note total sales is taken directly from a provided metric, and not extracted from the curve.
    df["total_sales"] = df["total_net_sales"]
    df["incr_sales"] = df.apply(lambda row: row["incr_sellout"][row["actual_index"]], axis=1)
    df["total_spend"] = df.apply(lambda row: row["spend"][row["actual_index"]], axis=1)

    # extract actuals
    actual_total_sales = (
        df.groupby(["version_code", "period"])  # total sales is unique by version_code
        .agg({"total_sales": "max"})
        .reset_index()
        .groupby(["period"])
        .agg({"total_sales": "sum"})
        .rename(columns={"total_sales": "value"})
    )
    actual_total_spend = (
        df.groupby(["period"]).agg({"total_spend": "sum"}).rename(columns={"total_spend": "value"})
    )
    actual_incr_sales = (
        df.groupby(["period"])
        .agg({"incr_sales": "sum", "gm_of_sell_out": "first"})
        .rename(columns={"incr_sales": "value"})
    )

    # Need to remove the gm adjustment for calculating carryover
    actual_incr_sales_for_carryover = actual_incr_sales.copy()
    actual_incr_sales_for_carryover["value"] = (
        actual_incr_sales_for_carryover["value"] / actual_incr_sales_for_carryover["gm_of_sell_out"]
    )
    actual_incr_sales_for_carryover.drop("gm_of_sell_out", axis=1, inplace=True)
    actual_incr_sales.drop("gm_of_sell_out", axis=1, inplace=True)

    actual_carryover_sales = actual_total_sales - actual_incr_sales_for_carryover
    actual_carryover_sales_pct = actual_carryover_sales / actual_total_sales

    actual_avg_roi = actual_incr_sales / actual_total_spend

    actual_stats = {
        kpi: [PeriodValue(**d) for d in kpi_df.reset_index().to_dict("records")]
        for kpi, kpi_df in (
            ("total_sales", actual_total_sales),
            ("total_spend", actual_total_spend),
            ("incr_sales", actual_incr_sales),
            ("carryover_sales", actual_carryover_sales),
            ("carryover_sales_pct", actual_carryover_sales_pct),
            ("avg_roi", actual_avg_roi),
        )
    }

    return MMMResults(curves=curves, **actual_stats)

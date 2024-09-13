"""
Arrange the curves with optimized and historical points
for a nice format to API.
"""

from collections import defaultdict
from typing import Dict

from pyomo.environ import Model
import numpy as np
import pandas as pd

from src.api.schemas import ScenarioCurve, ConstraintDirection, ConstraintKPI
from src.api.shared import argsort_by_uplift, calc_roi_mroi_gmroi, period_as_string
from src.pipeline.recommendation_engine.optimizer.constraints.constraint_parser import (
    split_constraint_name
)
from src.pipeline.recommendation_engine.optimizer.constraints.constraint_factory import (
    ConstraintFactory
)
from src.pipeline.recommendation_engine.optimizer.domain import DIMENSIONS
from src.pipeline.recommendation_engine.optimizer.parameters.reference_values import (
    RecommendationEngineReferenceValues,
)
from src.pipeline.recommendation_engine.utils.normalization import normalize_curves

# KPIs which we can reduce to create bounds
SUPPORTED_KPIS_BOUND_REDUCTION = (
    ConstraintKPI.spend.upper(),
)


def arrange_optimization_curves(
    data_dict: Dict,
    solution: Dict,
    model: Model,
    reference_values: RecommendationEngineReferenceValues,
    config: Dict,
):
    """
    Takes the solution and presents the curves.
    """
    curves_df = reference_values.response_curves_projected_df.copy()
    curves_df = normalize_curves(curves_df, config=config, pre=False)

    channel_master = data_dict["channel_master"]

    # Where a channel_code is not found in the channel master, replace the channel_desc
    # with the channel_code
    curves_df = curves_df.merge(
        channel_master, on="channel_code", how="left", validate="m:1"
    )
    curves_df["channel_desc"] = curves_df["channel_desc"].fillna(
        curves_df["channel_code"]
    )

    curves_df["historical"] = curves_df["uplift"] == 1  # bool column

    curves_df["optimized"] = curves_df.apply(
        # Check "equality" to 1 by finding a number smaller than the mipgap (tolerance)
        lambda row: abs(
            (
                solution["var_uplift_selected"][
                    row["region_name"],
                    row["market_code"],
                    row["brand_name"],
                    row["channel_code"],
                    row["speciality_code"],
                    row["segment_value"],
                    row["curve_uplift_idx"],
                ]
            )
            - 1
        ) < config["mipgap"] 
        ,
        axis=1,
    )

    # incr_sellout represents the GM adjusted value
    # which will be dispayed on curves and used for ROI calc.
    curves_df["incr_sellout"] = (
        curves_df["incremental_sell_out_value"] * curves_df["gm_of_sell_out"]
    )

    curves_df["period"] = curves_df.apply(
        lambda row: period_as_string(row["start_date"], row["end_date"]), axis=1
    )

    curves_idx_levels = [
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

    curves_df = curves_df.groupby(
        curves_idx_levels
    ).agg(
        {
            "spend": list,
            "uplift": list,
            "incr_sellout": list,
            "gm_of_sell_out": "mean",
            "historical": list,
            "optimized": list,
        }
    )

    for c in [
        "spend",
        "uplift",
        "incr_sellout",
        "historical",
        "optimized",
    ]:
        curves_df[c] = curves_df[c].apply(np.array)

    curves_df = argsort_by_uplift(
        curves_df,
        uplift_col="uplift",
        cols_to_sort=[
            "spend",
            "incr_sellout",
            "historical",
            "optimized",
        ],
    )

    # Get upper and lower bounds
    bounds_df, bounded_kpis = bounds_by_kpi(model)
    bounds_df = reduce_bounds(
        model=model,
        curves_df=curves_df,
        bounds_df=bounds_df,
        bounded_kpis=bounded_kpis
    )

    if bounds_df.empty:
        curves_df["spend_upper_bound"] = np.nan
        curves_df["spend_lower_bound"] = np.nan
        curves_df["sell_out_upper_bound"] = np.nan
        curves_df["sell_out_lower_bound"] = np.nan
    else:
        bounds_df.index.names = list(DIMENSIONS.values())[1:-1]

        curves_df = curves_df.merge(
            bounds_df,
            how="left",
            left_index=True,
            right_index=True
        )

    curves_df["historical_index"] = curves_df["historical"].apply(
        lambda a: np.min(np.nonzero(a)[0])
    )
    curves_df["optimized_index"] = curves_df["optimized"].apply(
        lambda a: np.min(np.nonzero(a)[0])
    )

    curves_df = calc_roi_mroi_gmroi(
        curves_df,
        sell_out_input_col="incr_sellout",
        spend_input_col="spend",
    )

    curves_df = curves_df.reorder_levels(curves_idx_levels)

    return [
        ScenarioCurve(
            market_code=mkt,
            region_name=reg,
            brand_name=brd,
            channel_code=chn_cd,
            channel_desc=chn_dsc,
            speciality_code=spc,
            segment_value=seg,
            period=per,
            currency=cur,
            historical_index=value["historical_index"],
            optimized_index=value["optimized_index"],
            **{
                kpi: value[kpi]
                if np.isfinite(value[kpi])
                else None
                for kpi in [
                    "spend_lower_bound",
                    "sell_out_lower_bound",
                    "spend_upper_bound",
                    "sell_out_upper_bound"
                ]
            },
            **{
                kpi: (
                    [x if np.isfinite(x) else None for x in value[kpi]]
                    if isinstance(value[kpi], np.ndarray)
                    else value[kpi]
                )
                for kpi in [
                    "spend",
                    "incr_sellout",
                    "uplift",
                    "ROI",
                    "MROI",
                    "GMROI",
                    "optimized",
                    "historical",
                ]
            },
        )
        for (
            mkt,
            reg,
            brd,
            chn_cd,
            chn_dsc,
            spc,
            seg,
            per,
            cur,
        ), value in curves_df.to_dict("index").items()
    ]


def bounds_by_kpi(model):
    """
    Get upper and lower bounds for each KPI.
    """
    constraints = model.settings["constraints"]

    # Only take the constraints that can be represented on the curve (full granularity)
    curve_level_constraints = [
        (k, split_constraint_name(k)) for k
        in constraints.keys()
    ]
    curve_level_constraints = [
        (c, (direction, delta, granularity, kpi)) for c, (direction, delta, granularity, kpi)
        in curve_level_constraints
        if granularity == tuple(DIMENSIONS.keys())[1:-1]
    ]

    # Dictionary to keep track of bounds by KPI
    # {
    #   kpi: {
    #       (market, brand, channel, specialty, segment): bound    
    #   }
    # }
    upper_bound = defaultdict(dict)
    lower_bound = defaultdict(dict)

    # KPIs for which constraints have been given
    bounded_kpis = []

    for constraint_name, (direction, delta, granularity, kpi) in curve_level_constraints:
        for domain_slice, constraint_value in constraints[constraint_name]:
            _, bound = ConstraintFactory.get_constraint_lhs_rhs(model, domain_slice, granularity, kpi)

            if direction == ConstraintDirection.maximum.upper():
                upper_bound[kpi][domain_slice] = (
                    min(
                        bound,
                        upper_bound[kpi].setdefault(domain_slice, bound)
                    ) # minimum (strictest) upper bound
                ) 
            else:
                lower_bound[kpi][domain_slice] = (
                    max(
                        bound,
                        lower_bound[kpi].setdefault(domain_slice, bound)
                    ) # maximum (strictest) lower bound
                )
        bounded_kpis.append(kpi)
    
    bounded_kpis = list(set(bounded_kpis))

    # convert back to normal dict
    upper_bound = dict(upper_bound)
    lower_bound = dict(lower_bound)

    upper_bound = [
        pd.Series(d, name=f"upper_bound_{kpi}")
        for kpi, d
        in upper_bound.items()
    ]
    lower_bound = [
        pd.Series(d, name=f"lower_bound_{kpi}")
        for kpi, d
        in lower_bound.items()
    ]

    if not (upper_bound + lower_bound):
        return pd.DataFrame(), []

    # Dataframe
    bounds_df = pd.concat(
        upper_bound + lower_bound,
        axis=1,
        join="outer",
        ignore_index=False
    )

    return bounds_df, bounded_kpis


def reduce_bounds(model, curves_df, bounds_df, bounded_kpis):
    """
    From bounds_df we have bounds specified for multiple KPIs,
    need to summarize this into one upper bound and one lower bound
    for spend and sell out which can be placed on the curve.
    """
    # check that we can reduce all the KPIs for which a bound exists
    assert all(
        [
            kpi in SUPPORTED_KPIS_BOUND_REDUCTION
            for kpi in bounded_kpis
        ] 
    ), (
        "Unsupported KPIs "
        f"{tuple(set(bounded_kpis) - set(SUPPORTED_KPIS_BOUND_REDUCTION))}"
        " not yet implemented!"
    )

    spend_upper_bound = {}
    spend_lower_bound = {}
    sell_out_upper_bound = {} # *GM adjusted* sell out
    sell_out_lower_bound = {} # *GM adjusted* sell out

    for kpi in bounded_kpis:
        upper_bound_series = bounds_df.get(f"upper_bound_{kpi}", pd.Series())
        lower_bound_series = bounds_df.get(f"lower_bound_{kpi}", pd.Series())

        if kpi.upper() == ConstraintKPI.spend.upper():
            # Update spend bounds directly.
            for domain_slice, bound in upper_bound_series.items():
                spend_upper_bound[domain_slice] = min(
                    bound,
                    spend_upper_bound.setdefault(domain_slice, bound)
                )
            for domain_slice, bound in lower_bound_series.items():
                spend_lower_bound[domain_slice] = max(
                    bound,
                    spend_lower_bound.setdefault(domain_slice, bound)
                )

            # Update sell out bounds by taking corresponding points on curve.
            for domain_slice, bound in upper_bound_series.items():
                mkt, brd, chn, spc, seg = domain_slice
                try:
                    curve = curves_df.loc[
                        (mkt, slice(None), brd, chn, slice(None), spc, seg, slice(None), slice(None)), :
                    ].iloc[0]
                except KeyError:
                    continue
                
                # find the closest point with bound >= spend
                upper_bound_closest_idx = np.where(
                    bound >= curve["spend"],
                    bound - curve["spend"],
                    np.inf
                ).argmin()

                # Update sell out upper bound
                sell_out_upper_bound[domain_slice] = min(
                    curve["incr_sellout"][upper_bound_closest_idx],
                    sell_out_upper_bound.setdefault(
                        domain_slice,
                        curve["incr_sellout"][upper_bound_closest_idx]
                    )
                )

            for domain_slice, bound in lower_bound_series.items():
                mkt, brd, chn, spc, seg = domain_slice
                try:
                    curve = curves_df.loc[
                        (mkt, slice(None), brd, chn, slice(None), spc, seg, slice(None), slice(None)), :
                    ].iloc[0]
                except KeyError:
                    continue

                # find the closest point with bound <= spend
                lower_bound_closest_idx = np.where(
                    bound <= curve["spend"],
                    bound - curve["spend"],
                    -np.inf
                ).argmax()

                # Update sell out lower bound
                sell_out_lower_bound[domain_slice] = min(
                    curve["incr_sellout"][lower_bound_closest_idx],
                    sell_out_lower_bound.setdefault(
                        domain_slice,
                        curve["incr_sellout"][lower_bound_closest_idx]
                    )
                )

    return pd.concat(
        [
            pd.Series(d, name=name)
            for d, name in (
                (spend_upper_bound, "spend_upper_bound"),
                (spend_lower_bound, "spend_lower_bound"),
                (sell_out_upper_bound, "sell_out_upper_bound"),
                (sell_out_lower_bound, "sell_out_lower_bound")
            )
        ],
        axis=1,
        join="outer",
        ignore_index=False
    )

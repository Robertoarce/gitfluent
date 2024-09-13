"""
Post processing functions for arranging the optimization results
into a nice format for the API
"""
from copy import deepcopy
from itertools import chain, repeat
from typing import Dict, List, Tuple

import numpy as np
import pandas as pd
from pyomo.environ import Model

from src.api.schemas import (
    AllocationKPIValue,
    RecommendationSummary,
    ScenarioAllocation,
    ScenarioResults,
    ScopeValue,
)
from src.pipeline.recommendation_engine.utils.aggregation import (
    pad_key,
    padded_key_is_match,
)


def arrange_optimization_results(
    data_dict: Dict,
    solution: Dict,
    model: Model,
    historical: bool,
    config: Dict,
) -> ScenarioResults:
    """
    Arranges the relevant model variables and parameters from the model.

    solution: optimized model variables.
    model: optimized model.
    historical: boolean indicating whether we are arranging results for
        historical (True), or
        optimized (False)
    """
    normalization_factor = config["normalization_factor"]

    channel_master = data_dict["channel_master"]
    channel_master = dict(
        zip(channel_master["channel_code"], channel_master["channel_desc"])
    )

    curve_col = "historical" if historical else "optimized"

    detailed_incremental, detailed_total, detailed_carryover = _get_detailed_allocation(
        solution, model, historical, normalization_factor, channel_master
    )
    summary = _get_summary_kpis(
        detailed_incremental, detailed_total, detailed_carryover
    )

    return ScenarioResults(
        detailed_incremental=detailed_incremental,
        detailed_total=detailed_total,
        detailed_carryover=detailed_carryover,
        summary=summary,
    )


# pylint:disable=too-many-locals
# fmt: off
def _get_detailed_allocation(
    solution: Dict,
    model: Model,
    historical: bool,
    normalization_factor: float,
    channel_master: Dict,
) -> Tuple[List[ScenarioAllocation], List[ScenarioAllocation]]:
    """
    This function aggregates the key KPIs
        - sell out value
        - sell out volume
        - spend
        - gross margin
    at each of the MMX hierachical levels.

    The `historical` parameter controls whether KPIs are calculated on reference
    values, or the optimized values.

    This is first done at the incremental level (in the case of `historical`=False, by aggregating
    model solution values); the total levels are then calculated by adding
    historical baselines.
    """
    detailed_incremental = []
    detailed_total = []

    # For historical KPI values, get from model parameters.
    # For optimized KPI values, get from optimized solution.
    if historical:
        allocation_kpi_source = {
            "sell_out_value": model.param_incr_sell_out_value_ref_dic_projected,
            "sell_out_volume": model.param_incr_sell_out_volume_ref_dic_projected,
            "spend": model.param_spend_ref_dic_projected,
            "gross_margin": model.param_incr_gm_ref_dic_projected,
        }
    else:
        allocation_kpi_source = {
            "sell_out_value": solution["var_incr_sell_out_value_selected"],
            "sell_out_volume": solution["var_incr_sell_out_volume_selected"],
            "spend": solution["var_spend_selected"],
            "gross_margin": solution["var_incr_gm_selected"],
        }

    # this `chain` is clunky but it is for avoidance of nested looping over domain then key
    for key, domain_name in chain(
        # Core MMX Hierarchy
        zip(
            model.set_region_market_brand_channel_speciality_segment_domain,
            repeat("region_market_brand_channel_speciality_segment")
        ),
        zip(
            model.set_region_market_brand_channel_speciality_domain,
            repeat("region_market_brand_channel_speciality")
        ),
        zip(
            model.set_region_market_brand_channel_domain,
            repeat("region_market_brand_channel")
        ),
        zip(model.set_region_market_brand_domain, repeat("region_market_brand")),
        zip(model.set_region_market_domain, repeat("region_market")),

        # Non-Core granularities (for UI aggregation in Global Scenarios)
        zip(model.set_brand_domain, repeat("brand")),
        zip(model.set_region_domain, repeat("region")),
        zip(model.set_channel_domain, repeat("channel")),
        zip(model.set_channel_speciality_domain, repeat("channel_speciality")),
        zip(model.set_channel_speciality_segment_domain, repeat("channel_speciality_segment")),
        zip(model.set_brand_channel_domain, repeat("brand_channel")),
        zip(model.set_market_channel_domain, repeat("market_channel")),
        zip(model.set_region_channel_domain, repeat("region_channel")),
        zip(model.set_region_channel_speciality_domain, repeat("region_channel_speciality")),
        zip(
            model.set_region_channel_speciality_segment_domain,
            repeat("region_channel_speciality_segment")
        ),
        zip(model.set_market_channel_speciality_domain, repeat("market_channel_speciality")),
        zip(
            model.set_market_channel_speciality_segment_domain,
            repeat("market_channel_speciality_segment")
        ),
        zip(model.set_brand_channel_speciality_domain, repeat("brand_channel_speciality")),
        zip(
            model.set_brand_channel_speciality_segment_domain,
            repeat("brand_channel_speciality_segment")
        ),
    ):
        padded_key = pad_key(
            key=key,
            key_granularity=domain_name.split("_"),
        )
        (
            region_name,
            market_code,
            brand_name,
            channel_code,
            speciality_code,
            segment_value
        ) = padded_key

        # Calculate incrementals
        alloc_incr = dict(
            market_code=market_code,
            region_name=region_name,
            brand_name=brand_name,
            brand_category="CATEGORY1" if brand_name else None,  # TODO: NEED TO GET MAPPING
            channel_code=channel_code,
            channel_desc=channel_master.get(channel_code, channel_code),
            speciality_code=speciality_code,
            segment_code="potential_qs__c" if segment_value else None,  # TODO: harcoded
            segment_value=segment_value,
        )

        for kpi, source in allocation_kpi_source.items():
            alloc_incr[kpi] = sum(
                source[rgn, mkt, brd, chn, spc, seg]
                * normalization_factor
                for rgn, mkt, brd, chn, spc, seg
                in model.set_region_market_brand_channel_speciality_segment_domain
                if padded_key_is_match(padded_key, (rgn, mkt, brd, chn, spc, seg))
            )

        # Net sales = Sell out - Sell in; but sell in is 0 in MMX
        alloc_incr["net_sales"] = alloc_incr["sell_out_value"]
        alloc_incr["gross_margin_minus_spend"] = (
            alloc_incr["gross_margin"] - alloc_incr["spend"]
        )
        # Sell out ROI is GM adjusted.
        alloc_incr["sell_out_roi"] = (
            alloc_incr["gross_margin"]
            / (alloc_incr["spend"] + 1e-8)  # epsilon to avoid 0 division
        )
        alloc_incr["gross_margin_minus_spend_over_net_sales"] = (
            alloc_incr["gross_margin_minus_spend"]
            / (alloc_incr["net_sales"] + 1e-8)  # epsilon to avoid 0 division
        )

        detailed_incremental.append(alloc_incr)

    # sort for deterministic results
    detailed_incremental = sorted(
        detailed_incremental,
        key=lambda x: tuple(x[k] if x[k] is not None else "" for k in ScopeValue.__fields__.keys())
    )
    detailed_incremental = [ScenarioAllocation(**x) for x in detailed_incremental]

    detailed_total, detailed_carryover = _calculate_total_and_carryover(
        detailed_incremental=detailed_incremental,
        historical=historical,
        model=model,
        normalization_factor=normalization_factor
    )

    return detailed_incremental, detailed_total, detailed_carryover
# fmt: on


def _calculate_total_and_carryover(
    detailed_incremental: List[Dict],
    historical: bool,
    model: Model,
    normalization_factor: float,
):
    """
    Add baseline amounts to incrementals to get totals.
    """
    # Totals and Baselines(carryover): can only occur above channel hierarchy.
    detailed_total = deepcopy(detailed_incremental)
    detailed_total = [
        x
        for x in detailed_total
        if not any((x.channel_code, x.speciality_code, x.segment_value))
    ]
    detailed_carryover = deepcopy(detailed_total)

    for total_alloc, carryover_alloc in zip(detailed_total, detailed_carryover):
        alloc_key = (
            total_alloc.region_name,
            total_alloc.market_code,
            total_alloc.brand_name,
        )

        # baselines will differ between historical and optimized if they have been scaled by budget
        carryover_suffix = "historical" if historical else "optimized"

        carryover_alloc.sell_out_value = sum(
            getattr(
                model,
                f"param_base_sell_out_value_ref_dic_projected_{carryover_suffix}",
            )[rgn, mkt, brd]
            * normalization_factor
            for (rgn, mkt, brd) in model.set_region_market_brand_domain
            if padded_key_is_match(alloc_key, (rgn, mkt, brd))
        )
        total_alloc.sell_out_value += carryover_alloc.sell_out_value

        carryover_alloc.sell_out_volume = sum(
            getattr(
                model,
                f"param_base_sell_out_volume_ref_dic_projected_{carryover_suffix}",
            )[rgn, mkt, brd]
            * normalization_factor
            for (rgn, mkt, brd) in model.set_region_market_brand_domain
            if padded_key_is_match(alloc_key, (rgn, mkt, brd))
        )
        total_alloc.sell_out_volume += carryover_alloc.sell_out_volume

        carryover_alloc.spend = 0  # baseline means no spend.
        total_alloc.spend += carryover_alloc.spend

        carryover_alloc.gross_margin = sum(
            getattr(
                model,
                f"param_base_gm_ref_dic_projected_{carryover_suffix}",
            )[rgn, mkt, brd]
            * normalization_factor
            for (rgn, mkt, brd) in model.set_region_market_brand_domain
            if padded_key_is_match(alloc_key, (rgn, mkt, brd))
        )
        total_alloc.gross_margin += carryover_alloc.gross_margin

        # Net sales = Sell out - Sell in; but sell in is 0 in MMX
        carryover_alloc.net_sales = carryover_alloc.sell_out_value
        total_alloc.net_sales = total_alloc.sell_out_value

        carryover_alloc.gross_margin_minus_spend = (
            carryover_alloc.gross_margin - carryover_alloc.spend
        )
        total_alloc.gross_margin_minus_spend = (
            total_alloc.gross_margin - total_alloc.spend
        )

        # Sell out ROI is GM adjusted.
        carryover_alloc.sell_out_roi = carryover_alloc.gross_margin / (
            carryover_alloc.spend + 1e-8
        )  # epsilon to avoid 0 division
        total_alloc.sell_out_roi = total_alloc.gross_margin / (
            total_alloc.spend + 1e-8
        )  # epsilon to avoid 0 division

        carryover_alloc.gross_margin_minus_spend_over_net_sales = (
            carryover_alloc.gross_margin_minus_spend
            / (carryover_alloc.net_sales + 1e-8)  # epsilon to avoid 0 division
        )
        total_alloc.gross_margin_minus_spend_over_net_sales = (
            total_alloc.gross_margin_minus_spend
            / (total_alloc.net_sales + 1e-8)  # epsilon to avoid 0 division
        )

    return detailed_total, detailed_carryover


def _get_summary_kpis(
    detailed_incremental: List[ScenarioAllocation],
    detailed_total: List[ScenarioAllocation],
    detailed_carryover: List[ScenarioAllocation],
) -> RecommendationSummary:
    """
    Calculate summary KPIs by aggregating over the detailed KPIs at the lowest granularity.
    """
    summable_kpis = [
        "sell_out_value",
        "sell_out_volume",
        "spend",
        "gross_margin",
        "net_sales",
        "gross_margin_minus_spend",
    ]

    incremental = {}
    total = {}
    carryover = {}
    carryover_pct = {}

    # Sum the KPIs only at the max granularity (to avoid double counting)
    for kpi in summable_kpis:
        incremental[kpi] = sum(
            getattr(x, kpi)
            for x in detailed_incremental
            if all(
                (
                    x.region_name,
                    x.market_code,
                    x.brand_name,
                    x.channel_code,
                    x.speciality_code,
                    x.segment_value,
                )
            )
        )
        total[kpi] = sum(
            getattr(x, kpi)
            for x in detailed_total
            if all(
                (
                    x.region_name,
                    x.market_code,
                    x.brand_name,
                )
            )
        )

        carryover[kpi] = sum(
            getattr(x, kpi)
            for x in detailed_carryover
            if all(
                (
                    x.region_name,
                    x.market_code,
                    x.brand_name,
                )
            )
        )

        # Carryover as a percentage of total.
        carryover_pct[kpi] = carryover[kpi] / (total[kpi] + 1e-8)

    # Non Summable KPIs
    for d in (incremental, total, carryover):
        # small epsilon to avoid division by 0

        # NOTE: Sell out ROI is calculated using *incremental* GM / spend for
        # both incremental and total. This is because it is not sensible to calculate ROI
        # using total sell out.
        d["sell_out_roi"] = incremental["gross_margin"] / (incremental["spend"] + 1e-8)

        d["gross_margin_minus_spend_over_net_sales"] = d["gross_margin_minus_spend"] / (
            d["net_sales"] + 1e-8
        )
    carryover_pct["sell_out_roi"] = None
    carryover_pct["gross_margin_minus_spend_over_net_sales"] = None

    return RecommendationSummary(
        incremental=AllocationKPIValue(**incremental),
        total=AllocationKPIValue(**total),
        carryover=AllocationKPIValue(**carryover),
        carryover_pct=AllocationKPIValue(**carryover_pct),
    )

"""
Apply scaling according to budget
"""

from copy import deepcopy
from typing import Dict, Tuple

from pyomo.environ import Model

from src.pipeline.recommendation_engine.utils.aggregation import (
    pad_key,
    padded_key_is_match,
)


def budget_df_to_dict(budget_df, normalization_factor=1):
    """
    Converts budget dataframe containing columns
    "market_code", "brand_name", "sales", "total_opex" into a dictionary
    with key-value mapping as:
        (market_code, brand_name) : (sales, total_opex)

    Sales and total opex values are normalized.
    """
    if budget_df.empty:
        return {}

    budget_dict = budget_df.set_index(["market_code", "brand_name"])

    budget_dict["sales"] = budget_dict["sales"] / normalization_factor
    budget_dict["total_opex"] = (
        -budget_dict["total_opex"] / normalization_factor
    )  # opex numbers provided as negative.
    budget_dict = {
        k: (v["sales"], v["total_opex"])
        for k, v in budget_dict.to_dict("index").items()
    }

    return budget_dict


def scaling_factor_denominator(source_dict, source_dict_domain, padded_budget_key):
    """
    Results are scaled to budget by multiplying a total number by a factor of
    (budgeted total) / (actual total). We calculate the actual total (i.e., denominator)
    by summing all the values in `source_dict` over the keys in `source_dict_domain`
    which match the `padded_budget_key`.
    """
    return sum(
        source_dict[k]
        for k in source_dict_domain
        if padded_key_is_match(padded_budget_key, k)
    )


def apply_scaling_to_dict(dict_to_scale, padded_budget_key, scaling_factor):
    """
    Applies scaling to `dict_to_scale`

    For all keys within `dict_to_scale` which match `padded_budget_key`, the corresponding
    values are multiplied by a factor of `scaling_factor`.
    """
    for k in dict_to_scale.keys():
        if padded_key_is_match(padded_budget_key, k):
            dict_to_scale[k] = dict_to_scale[k] * scaling_factor


def apply_budget_scaling_postprocess(
    data_dict: Dict, solution: Dict, model: Model, config: Dict
):
    """
    Based on the budget data, scale the appropriate model parameters and solution.
    """
    # We create new model attributes for historical baseline vs optimized baseline sales/gm;
    # These are used to store the rescaled baselines.
    # Baseline OPEX is always 0 so we do not need to create new attributes.
    model.param_base_sell_out_value_ref_dic_projected_historical = deepcopy(
        model.param_base_sell_out_value_ref_dic_projected
    )
    model.param_base_sell_out_value_ref_dic_projected_optimized = deepcopy(
        model.param_base_sell_out_value_ref_dic_projected
    )
    model.param_base_sell_out_volume_ref_dic_projected_historical = deepcopy(
        model.param_base_sell_out_volume_ref_dic_projected
    )
    model.param_base_sell_out_volume_ref_dic_projected_optimized = deepcopy(
        model.param_base_sell_out_volume_ref_dic_projected
    )
    model.param_base_gm_ref_dic_projected_historical = deepcopy(
        model.param_base_gm_ref_dic_projected
    )
    model.param_base_gm_ref_dic_projected_optimized = deepcopy(
        model.param_base_gm_ref_dic_projected
    )

    budget_dict = budget_df_to_dict(data_dict["budget"], config["normalization_factor"])

    for key, (budgeted_sales, budgeted_spend) in budget_dict.items():
        # padded to full granularity region/market/brand/channel/specialty/segment
        # to match incremental dictionaries
        full_padded_key = pad_key(key=key, key_granularity=["market", "brand"])
        # padded to partial granularity region/market/brand
        # to match baseline dictionaries
        partial_padded_key = pad_key(
            key=key,
            key_granularity=["market", "brand"],
            full_granularity=["region", "market", "brand"],
        )

        # Sales denominator is the sum of total incremental + total baselines
        sales_denom = scaling_factor_denominator(
            model.param_incr_sell_out_value_ref_dic_projected,
            model.set_region_market_brand_channel_speciality_segment_domain,
            full_padded_key,
        ) + scaling_factor_denominator(
            model.param_base_sell_out_value_ref_dic_projected,
            model.set_region_market_brand_domain,
            partial_padded_key,
        )

        # OPEX denominator - baseline is 0.
        spend_denom = scaling_factor_denominator(
            model.param_spend_ref_dic_projected,
            model.set_region_market_brand_channel_speciality_segment_domain,
            full_padded_key,
        )

        # Apply scaling.
        # Sales related parameters are scaled by (budgeted_sales)/(total_sales)
        # Spend related parameters are scaled by (budgeted_spend)/(total_spend)
        # Small epsilon is added to avoid zero-division
        sales_scaling_factor = budgeted_sales / (sales_denom + 1e-8)
        spend_scaling_factor = budgeted_spend / (spend_denom + 1e-8)

        solution, model = _scale_baselines(
            partial_padded_key, solution, model, sales_scaling_factor
        )

        solution, model = _scale_incrementals(
            full_padded_key, solution, model, sales_scaling_factor, spend_scaling_factor
        )

    return solution, model


def _scale_baselines(
    partial_padded_key: Tuple, solution: Dict, model: Model, sales_scaling_factor: float
):
    """
    Scale the baseline sales in the model and solution

    partial_padded_key: padded key of the budget we are applying.
    solution: optimization solution dictionary
    model: model
    sales_scaling_factor: factor used to scale sales
    """
    for dict_to_scale in (
        model.param_base_sell_out_value_ref_dic_projected_historical,
        model.param_base_sell_out_value_ref_dic_projected_optimized,
        model.param_base_sell_out_volume_ref_dic_projected_historical,
        model.param_base_sell_out_volume_ref_dic_projected_optimized,
        model.param_base_gm_ref_dic_projected_historical,
        model.param_base_gm_ref_dic_projected_optimized,
    ):
        apply_scaling_to_dict(
            dict_to_scale=dict_to_scale,
            padded_budget_key=partial_padded_key,
            scaling_factor=sales_scaling_factor,
        )

    return solution, model


def _scale_incrementals(
    full_padded_key: Tuple,
    solution: Dict,
    model: Model,
    sales_scaling_factor: float,
    spend_scaling_factor: float,
):
    """
    Scale the incremental sales and opex in the model and solution

    full_padded_key: padded key of the budget we are applying.
    solution: optimization solution dictionary
    model: model
    sales_scaling_factor: factor used to scale sales
    spend_scaling_factor: factor used to scale spend
    """
    for dict_to_scale, scaling_factor in (
        (model.param_incr_sell_out_value_ref_dic_projected, sales_scaling_factor),
        (model.param_incr_sell_out_volume_ref_dic_projected, sales_scaling_factor),
        (model.param_spend_ref_dic_projected, spend_scaling_factor),
        (model.param_incr_gm_ref_dic_projected, sales_scaling_factor),
        (solution["var_incr_sell_out_value_selected"], sales_scaling_factor),
        (solution["var_incr_sell_out_volume_selected"], sales_scaling_factor),
        (solution["var_spend_selected"], spend_scaling_factor),
        (solution["var_incr_gm_selected"], sales_scaling_factor),
    ):
        apply_scaling_to_dict(
            dict_to_scale=dict_to_scale,
            padded_budget_key=full_padded_key,
            scaling_factor=scaling_factor,
        )

    return solution, model

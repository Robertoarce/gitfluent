"""
Optimizer Objective:
    Objective function of the model.

Objective functions return minimand expressions as a function
of model variables and parameters.
"""

from pyomo.environ import Model, Objective, minimize

from src.api.schemas import ScenarioCriteria
from src.utils.exceptions import InvalidScenarioSpec


def _obj_max_sell_out(model: Model):
    """
    Objective:
        maximize: sell out
    Returns:
        -(sell out)
    """
    # fmt: off
    incr_sell_out = sum(
        model.var_incr_sell_out_value_selected[region, market, brand, channel, speciality, segment]
        for region, market, brand, channel, speciality, segment
        in model.set_region_market_brand_channel_speciality_segment_domain
    )
    # fmt: on

    # does not actually affect minimization since base sell out is a constant.
    base_sell_out = sum(
        model.param_base_sell_out_value_ref_dic_projected[region, market, brand]
        for region, market, brand in model.set_region_market_brand_domain
    )

    return -incr_sell_out - base_sell_out


def _obj_min_spend(model: Model):
    """
    Objective:
        Minimize: spend
    Returns:
        spend
    """
    # fmt: off
    return sum(
        model.var_spend_selected[region, market, brand, channel, speciality, segment]
        for region, market, brand, channel, speciality, segment
        in model.set_region_market_brand_channel_speciality_segment_domain
    )
    # fmt: on


def _obj_max_gm(model: Model):
    """
    Objective:
        maximize: GM

    Returns:
        -GM
    """
    # pylint: disable=duplicate-code
    # fmt: off
    gm = (
        sum(
            model.var_incr_gm_selected[region, market, brand, channel, speciality, segment]
            for region, market, brand, channel, speciality, segment
            in model.set_region_market_brand_channel_speciality_segment_domain
        )
        + sum(
            model.param_base_gm_ref_dic_projected[region, market, brand]
            for region, market, brand
            in model.set_region_market_brand_domain
        )
    )
    # fmt: on

    return -gm


def _obj_max_gm_minus_spend(model: Model):
    """
    Objective:
        maximize: GM - spend

    Returns:
        -GM + spend
    """
    # fmt: off
    gm = (
        sum(
            model.var_incr_gm_selected[region, market, brand, channel, speciality, segment]
            for region, market, brand, channel, speciality, segment
            in model.set_region_market_brand_channel_speciality_segment_domain
        )
        + sum(
            model.param_base_gm_ref_dic_projected[region, market, brand]
            for region, market, brand
            in model.set_region_market_brand_domain
        )
    )

    spend = sum(
        model.var_spend_selected[region, market, brand, channel, speciality, segment]
        for region, market, brand, channel, speciality, segment
        in model.set_region_market_brand_channel_speciality_segment_domain
    )
    # fmt: on

    return -gm + spend


def declare_model_objective(model: Model):
    """
    Given a model and a valid objective identifier,
    applies the objective to the model.
    """
    objective = model.settings["scenario_objective"]["criteria"]

    function_mapping = {
        ScenarioCriteria.max_sell_out: _obj_max_sell_out,
        ScenarioCriteria.min_spend: _obj_min_spend,
        ScenarioCriteria.max_gm: _obj_max_gm,
        ScenarioCriteria.max_gm_minus_spend: _obj_max_gm_minus_spend,
    }

    obj_fn = function_mapping.get(objective)
    if obj_fn is None:
        raise InvalidScenarioSpec(f"Objective {objective} not recognized")

    minimand = obj_fn(model)
    model.objective = Objective(rule=minimand, sense=minimize)

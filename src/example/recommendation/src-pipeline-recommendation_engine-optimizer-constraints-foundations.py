"""
Foundational MMX model constraints.
These constraints confine the solution space to points that lie
    on the response curves.
"""
from pyomo.environ import Constraint


# ------------------------------------
# Constraint declaration function
# ------------------------------------
def declare_foundational_constraints(model):
    """
    Function to activate all foundational constraints.
    """
    rules_to_declare = (
        enforce_uniqueness_uplift,
        define_spend_selected,
        define_incr_sell_out_value_selected,
        define_incr_sell_out_volume_selected,
        define_incr_gm_selected,
    )
    for rule in rules_to_declare:
        setattr(
            model,
            f"constraint_{rule}",
            Constraint(
                model.set_region_market_brand_channel_speciality_segment_domain,
                rule=rule,
            ),
        )


# ------------------------------------
# Constraints
# ------------------------------------
def enforce_uniqueness_uplift(
    model, region, market, brand, channel, speciality, segment
):
    """
    One and only one point on each response curve is selected.

    Sum of all indicator variables (indicated selected uplift) == 1
    """
    # pylint: disable=line-too-long
    return (
        sum(
            model.var_uplift_selected[
                region, market, brand, channel, speciality, segment, upliftidx
            ]
            for upliftidx in model.param_upliftidx_at_region_market_brand_channel_speciality_segment[
                region, market, brand, channel, speciality, segment
            ]
        )
        == 1
    )


def define_spend_selected(model, region, market, brand, channel, speciality, segment):
    """
    The spend amount selected must correspond to the selected uplift
    on the response curve.

    Spend selected == sum(base spend * indicator * uplift value)
    """
    return model.var_spend_selected[
        region, market, brand, channel, speciality, segment
    ] == sum(
        model.param_spend_at_uplift_1[
            region, market, brand, channel, speciality, segment
        ]
        * model.var_uplift_selected[
            region, market, brand, channel, speciality, segment, upliftidx
        ]
        * model.param_uplift_at_region_market_brand_channel_speciality_segment_upliftidx[
            region, market, brand, channel, speciality, segment, upliftidx
        ]
        for upliftidx in model.param_upliftidx_at_region_market_brand_channel_speciality_segment[
            region, market, brand, channel, speciality, segment
        ]
    )


def define_incr_sell_out_value_selected(
    model, region, market, brand, channel, speciality, segment
):
    """
    The incr sell out value amount selected must correspond to the selected uplift
    on the response curve.

    Incr sell out value selected == sum(sell out value at uplift* indicator)
    """
    return model.var_incr_sell_out_value_selected[
        region, market, brand, channel, speciality, segment
    ] == sum(
        model.param_incr_sell_out_value_by_upliftidx[
            region, market, brand, channel, speciality, segment, upliftidx
        ]
        * model.var_uplift_selected[
            region, market, brand, channel, speciality, segment, upliftidx
        ]
        for upliftidx in model.param_upliftidx_at_region_market_brand_channel_speciality_segment[
            region, market, brand, channel, speciality, segment
        ]
    )


def define_incr_sell_out_volume_selected(
    model, region, market, brand, channel, speciality, segment
):
    """
    The incr sell out volume amount selected must correspond to the selected uplift
    on the response curve.

    Incr sell out volume selected == sum(sell out volume at uplift * indicator)
    """
    return model.var_incr_sell_out_volume_selected[
        region, market, brand, channel, speciality, segment
    ] == sum(
        model.param_incr_sell_out_volume_by_upliftidx[
            region, market, brand, channel, speciality, segment, upliftidx
        ]
        * model.var_uplift_selected[
            region, market, brand, channel, speciality, segment, upliftidx
        ]
        for upliftidx in model.param_upliftidx_at_region_market_brand_channel_speciality_segment[
            region, market, brand, channel, speciality, segment
        ]
    )


def define_incr_gm_selected(model, region, market, brand, channel, speciality, segment):
    """
    Incr GM selected == (incr sell out selected * GM%)
    """
    return model.var_incr_gm_selected[
        region, market, brand, channel, speciality, segment
    ] == (
        model.var_incr_sell_out_value_selected[
            region, market, brand, channel, speciality, segment
        ]
        * model.param_gm_of_sell_out[region, market, brand]
    )

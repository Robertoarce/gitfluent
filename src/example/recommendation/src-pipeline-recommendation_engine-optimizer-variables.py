"""
Optimizer variables:
    Degrees of freedom for allocation.
"""
from pyomo.environ import Binary, Model, NonNegativeReals, Var


def declare_model_variables(model: Model):
    """
    Define the variables for the model.
    Each variable is indexed by a domain set (granularity)
    and a set of possible values (`within` argument)
    """
    # Indicator variable whether that uplift point was selected.
    model.var_uplift_selected = Var(
        model.set_region_market_brand_channel_speciality_segment_upliftidx_domain,
        within=Binary,
    )

    # Selected spend
    model.var_spend_selected = Var(
        model.set_region_market_brand_channel_speciality_segment_domain,
        within=NonNegativeReals,
    )

    # Selected incremental sell out value
    model.var_incr_sell_out_value_selected = Var(
        model.set_region_market_brand_channel_speciality_segment_domain,
        within=NonNegativeReals,
    )

    # Selected incremental sell out volume
    model.var_incr_sell_out_volume_selected = Var(
        model.set_region_market_brand_channel_speciality_segment_domain,
        within=NonNegativeReals,
    )

    # Selected incremental GM
    model.var_incr_gm_selected = Var(
        model.set_region_market_brand_channel_speciality_segment_domain,
        within=NonNegativeReals,
    )

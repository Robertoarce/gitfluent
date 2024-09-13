"""
Optimizer domain:
Combinations of - market x brand x channel x speciality x segment
    over which spend can be allocated.
"""
from collections import OrderedDict
from itertools import combinations

from pyomo.environ import Set

# dimension -> column name in response_curve_df
# order matches the MMX hierarchy.
DIMENSIONS = OrderedDict(
    (
        ("region", "region_name"),
        ("market", "market_code"),
        ("brand", "brand_name"),
        ("channel", "channel_code"),
        ("speciality", "speciality_code"),
        ("segment", "segment_value"),
        ("upliftidx", "curve_uplift_idx"),
    )
)


def declare_model_domain(model, response_curves_df):
    """
    Given a model and response curves, define the domains, which slices along
    the ordered MMX hierarchy (as in OrderedDict `DIMENSIONS`).

    e.g., we will get domain space `market_brand` but never `brand_market`.
    """
    domain_spaces = []
    for n_dims in range(1, len(DIMENSIONS) + 1):
        domain_spaces = domain_spaces + list(
            combinations(list(DIMENSIONS.keys()), n_dims)
        )

    # unique combinations of the dimensions in each domain space.
    for space in domain_spaces:
        space_cols = [DIMENSIONS[s] for s in space]
        domain_set = list(set(zip(*(response_curves_df[col] for col in space_cols))))

        # declare the pyomo Set object to the model
        attr_name = "set_" + "_".join(space) + "_domain"
        attr_value = Set(initialize=domain_set)
        setattr(model, attr_name, attr_value)

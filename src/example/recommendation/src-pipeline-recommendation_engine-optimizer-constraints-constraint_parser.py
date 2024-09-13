"""
Parse constraints provided from API input JSON into
a dictionary format that is easy for use in Pyomo Constraint.
"""
from collections import defaultdict
from typing import List

from src.api.schemas import (
    Constraint,
    ConstraintDirection,
    ConstraintKPI,
    ScenarioCriteria,
    ScenarioObjective,
)
from src.pipeline.recommendation_engine.optimizer.domain import DIMENSIONS

SUPPORTED_CONSTRAINTS = [
    "MIN_VARIATION_SPEND",
    "MAX_VARIATION_SPEND",
    "MIN_VARIATION_MARKET_SPEND",
    "MAX_VARIATION_MARKET_SPEND",
    "MIN_VARIATION_MARKET_BRAND_SPEND",
    "MAX_VARIATION_MARKET_BRAND_SPEND",
    "MIN_VARIATION_MARKET_BRAND_CHANNEL_SPEND",
    "MAX_VARIATION_MARKET_BRAND_CHANNEL_SPEND",
    "MIN_VARIATION_MARKET_BRAND_CHANNEL_SPECIALITY_SPEND",
    "MAX_VARIATION_MARKET_BRAND_CHANNEL_SPECIALITY_SPEND",
    "MIN_VARIATION_MARKET_BRAND_CHANNEL_SPECIALITY_SEGMENT_SPEND",
    "MAX_VARIATION_MARKET_BRAND_CHANNEL_SPECIALITY_SEGMENT_SPEND",
    "MIN_VARIATION_BRAND_SPEND",
    "MAX_VARIATION_BRAND_SPEND",
    "MIN_VARIATION_BRAND_CHANNEL_SPEND",
    "MAX_VARIATION_BRAND_CHANNEL_SPEND",
    "MIN_VARIATION_BRAND_CHANNEL_SPECIALITY_SPEND",
    "MAX_VARIATION_BRAND_CHANNEL_SPECIALITY_SPEND",
    "MIN_VARIATION_BRAND_CHANNEL_SPECIALITY_SEGMENT_SPEND",
    "MAX_VARIATION_BRAND_CHANNEL_SPECIALITY_SEGMENT_SPEND",
    "MIN_ABSOLUTE_SPEND",
    "MAX_ABSOLUTE_SPEND",
    "MIN_ABSOLUTE_MARKET_SPEND",
    "MAX_ABSOLUTE_MARKET_SPEND",
    "MIN_ABSOLUTE_MARKET_BRAND_SPEND",
    "MAX_ABSOLUTE_MARKET_BRAND_SPEND",
    "MIN_ABSOLUTE_MARKET_BRAND_CHANNEL_SPEND",
    "MAX_ABSOLUTE_MARKET_BRAND_CHANNEL_SPEND",
    "MIN_ABSOLUTE_MARKET_BRAND_CHANNEL_SPECIALITY_SPEND",
    "MAX_ABSOLUTE_MARKET_BRAND_CHANNEL_SPECIALITY_SPEND",
    "MIN_ABSOLUTE_MARKET_BRAND_CHANNEL_SPECIALITY_SEGMENT_SPEND",
    "MAX_ABSOLUTE_MARKET_BRAND_CHANNEL_SPECIALITY_SEGMENT_SPEND",
    "MIN_ABSOLUTE_BRAND_SPEND",
    "MAX_ABSOLUTE_BRAND_SPEND",
    "MIN_ABSOLUTE_BRAND_CHANNEL_SPEND",
    "MAX_ABSOLUTE_BRAND_CHANNEL_SPEND",
    "MIN_ABSOLUTE_BRAND_CHANNEL_SPECIALITY_SPEND",
    "MAX_ABSOLUTE_BRAND_CHANNEL_SPECIALITY_SPEND",
    "MIN_ABSOLUTE_BRAND_CHANNEL_SPECIALITY_SEGMENT_SPEND",
    "MAX_ABSOLUTE_BRAND_CHANNEL_SPECIALITY_SEGMENT_SPEND",
    "MIN_VARIATION_SELLOUT",
    "MIN_ABSOLUTE_SELLOUT",
]


def parse_constraints(constraints: List[Constraint], objective: ScenarioObjective):
    """
    Parsing the constraints into a dictionary.

    Example output format:
    {
        "MAX_VARIATION_MARKET_BRAND_SPEND": (
            (("FRANCE", "HEXYON"), 0.1),
            (("FRANCE", "TOUJEO"), -0.5)
        )
        "MIN_VARIATION_MARKET_SPEND": (
            ("FRANCE", 0.1),
        )
    }
    """

    constraints_dict = defaultdict(tuple)

    for c in constraints:
        key = []
        key.append(c.direction.value.upper())
        key.append(c.delta.upper())

        value = []
        for key_gran, attr_name in list(DIMENSIONS.items())[1:-1]:
            if getattr(c, attr_name, None) is not None:
                key.append(key_gran.upper())
                value.append(getattr(c, attr_name))

        key.append(c.kpi.upper())
        value.append(c.value)

        key = "_".join(key)

        if len(value) == 1:
            # universal constraint
            constraints_dict[key] = constraints_dict[key] + (value[0],)
        else:
            constraints_dict[key] = constraints_dict[key] + (
                (tuple(value[:-1]), value[-1]),
            )

    # If the scenario is to minimize spend, impose a floor on sell out
    # Else, impose a cap on spend.
    if objective.criteria == ScenarioCriteria.min_spend:
        objective_kpi_direction, objective_kpi = (
            ConstraintDirection.minimum.upper(),
            ConstraintKPI.sell_out.upper(),
        )
    else:
        objective_kpi_direction, objective_kpi = (
            ConstraintDirection.maximum.upper(),
            ConstraintKPI.spend.upper(),
        )
    key = f"{objective_kpi_direction}_{objective.delta.upper()}_{objective_kpi}"
    constraints_dict[key] = constraints_dict[key] + (objective.value,)

    for k in constraints_dict.keys():
        if k not in SUPPORTED_CONSTRAINTS:
            raise NotImplementedError(f"Constraint {k} not yet implemented!")

    return dict(constraints_dict)


def split_constraint_name(constraint_name):
    """
    Given an identifier string (i.e. from SUPPORTED_CONSTRAINTS)
    parse out the direction, delta, granularity, and kpi.
    """

    parts = constraint_name.split("_")

    direction = parts[0]
    delta = parts[1]
    granularity = tuple(g.lower() for g in parts[2:-1])
    kpi = parts[-1]

    return direction, delta, granularity, kpi


def get_constraint_mask(constraint_name):
    """
    Returns a partial constraint specification,
    given an identifier string (i.e., from SUPPORTED_CONSTRAINTS)
    """
    direction, delta, granularity, kpi = split_constraint_name(constraint_name)

    mask = dict(kpi=kpi.lower(), delta=delta.lower(), direction=direction.lower())

    for gran, key in list(DIMENSIONS.items())[1:-1]:
        if gran not in granularity:
            mask[key] = None

    return mask

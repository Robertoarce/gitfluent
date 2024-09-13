"""
Functions to get reference values for the objective screen.
"""
import json
from typing import List

from src.pipeline.recommendation_engine.optimizer.constraints.constraint_parser import (
    SUPPORTED_CONSTRAINTS,
    get_constraint_mask,
)

from ..schemas import Constraint, ScopeValue


def get_available_constraints(
    scope_values: List[ScopeValue],
):
    """
    Returns list of available constraints.
    """
    masks = [get_constraint_mask(c) for c in SUPPORTED_CONSTRAINTS]

    # TEMPORARY: The UI can only handle Spend constraints for now
    masks = [m for m in masks if m["kpi"] == "spend"]

    available_constraints = []
    for item in scope_values:
        for mask in masks:
            masked_constraint_args = {
                **item.dict(),
                **mask,  # None values in `mask` overwrite values in `item`
                "value": 0,  # dummy
            }
            available_constraints.append(masked_constraint_args)

    # take unique by converting to string and applying set
    # sorted for consistency
    available_constraints = [Constraint(**x) for x in available_constraints]
    available_constraints = sorted(
        set(json.dumps(dict(x)) for x in available_constraints)
    )
    available_constraints = [Constraint(**json.loads(x)) for x in available_constraints]

    return available_constraints

"""
Test budget scaling feature
"""

from unittest.mock import MagicMock

import pandas as pd

from src.pipeline.recommendation_engine.budget_scaling import (
    apply_budget_scaling_postprocess,
)


def test_budget_scaling():
    """
    Unit test for the apply_budget_scaling function
    """

    # Fake budget with one market/brand
    data_dict = {
        "budget": pd.DataFrame(
            {
                "market_code": ["FR"],
                "brand_name": ["Br1"],
                "sales": [1],
                "total_opex": [0.5],
            }
        )
    }

    # Fake model solution with incremental values
    solution = {
        "var_incr_sell_out_value_selected": {("D", "FR", "Br1", "C", "S", "S"): 0.1},
        "var_incr_sell_out_volume_selected": {("D", "FR", "Br1", "C", "S", "S"): 0.1},
        "var_spend_selected": {("D", "FR", "Br1", "C", "S", "S"): 0.1},
        "var_incr_gm_selected": {("D", "FR", "Br1", "C", "S", "S"): 0.1},
    }

    # Mock model
    model = MagicMock()

    # Fake config with normalization factor
    config = {"normalization_factor": 1}

    apply_budget_scaling_postprocess(
        data_dict=data_dict, solution=solution, model=model, config=config
    )

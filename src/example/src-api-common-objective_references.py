"""
Functions to get reference values for the objective screen.
"""
from typing import List

import yaml

from src.pipeline.recommendation_engine.optimizer.parameters import (
    RecommendationEngineReferenceValues,
)
from src.pipeline.recommendation_engine.preprocessing import reco_engine_preprocessing
from src.pipeline.recommendation_engine.run_pipeline import RecommendationEnginePipeline
from src.utils.data.async_data.async_data_manager import DataManager

from ..schemas import ObjectiveReference, ScopeValue
from ..shared import period_as_string


# pylint:disable=too-many-locals
def get_objective_references(
    exercise_code: str,
    selected_period_setting: str,
    selected_budget: str,
    scope_values: List[ScopeValue],
):
    """
    Returns reference values for the objective scenario creation screen

    - sell out value
    - spend
    - gross margin
    - gross margin - spend
    """

    # Load data from matching config.
    with open("src/config/recommendation_engine/config.yaml") as config_file:
        config = yaml.safe_load(config_file)
    config = RecommendationEnginePipeline.update_data_config(
        config,
        exercise_code=exercise_code,
        scope_values=scope_values,
        selected_period_setting=selected_period_setting,
        budget=selected_budget,
        references_only=True,
    )

    data_manager = DataManager(
        data_sources_config=config["data_sources"],
        data_validation_config=config["data_validation"],
        data_cleaning_config=config["data_cleaning"],
        data_outputs_config={},
    )
    data_manager.load_validate_clean()
    data_dict = data_manager.get_data_dict()

    (
        response_curves_df,
        response_curves_reference_df,
        response_curves_projected_df,
        response_curves_reference_projected_df,
    ) = reco_engine_preprocessing(
        data_dict=data_dict,
        config={"normalization_factor": 1},  # no renorm as we will not run the optimizer.
    )

    ref_values = RecommendationEngineReferenceValues(
        response_curves_df=response_curves_df,
        response_curves_reference_df=response_curves_reference_df,
        response_curves_projected_df=response_curves_projected_df,
        response_curves_reference_projected_df=response_curves_reference_projected_df,
    )
    ref_spend, ref_sell_out, ref_gm = ref_values.reference_parameters(projected=True)

    # Original totals.
    total_spend, total_sell_out, total_gm = ref_values.reference_totals(
        ref_spend=ref_spend, ref_sell_out=ref_sell_out, ref_gm=ref_gm
    )

    (
        total_budgeted_spend,
        total_budgeted_sell_out,
        total_budgeted_gm,
    ) = ref_values.budgeted_reference_totals(
        ref_spend=ref_spend,
        ref_sell_out=ref_sell_out,
        ref_gm=ref_gm,
        budget_df=data_dict["budget"],
    )

    return ObjectiveReference(
        original_timeframe=period_as_string(
            start_date=ref_values.response_curves_df["start_date"].min(),
            end_date=ref_values.response_curves_df["end_date"].max(),
        ),
        sell_out_value=total_sell_out,
        model_spend=-total_spend,  # display spend as negative
        gross_margin=total_gm,
        gross_margin_minus_spend=(total_gm - total_spend),
        budget_timeframe=selected_budget,
        budgeted_sell_out_value=total_budgeted_sell_out,
        budgeted_model_spend=-total_budgeted_spend,  # display spend as negative
        budgeted_gross_margin=total_budgeted_gm,
        budgeted_gross_margin_minus_spend=(total_budgeted_gm - total_budgeted_spend),
        currency=ref_values.currency,
    )

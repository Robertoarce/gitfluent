"""
Post processing method for recommendation engine.
"""
from typing import Dict

from pyomo.environ import Model

from src.api.schemas import RecommendationEngineOutput
from src.pipeline.recommendation_engine.budget_scaling import (
    apply_budget_scaling_postprocess,
)
from src.pipeline.recommendation_engine.optimizer.parameters.reference_values import (
    RecommendationEngineReferenceValues,
)
from src.pipeline.recommendation_engine.postprocessing.arrange_curves import (
    arrange_optimization_curves,
)
from src.pipeline.recommendation_engine.postprocessing.arrange_results import (
    arrange_optimization_results,
)
from src.pipeline.recommendation_engine.postprocessing.get_deltas import (
    calculate_result_deltas,
)


def reco_engine_postprocessing(
    data_dict: Dict,
    solution: Dict,
    model: Model,
    reference_values: RecommendationEngineReferenceValues,
    config: Dict,
    run_name: str,
    warnings=None,
):
    """
    Arrange the model outputs.
    """
    curves = arrange_optimization_curves(
        data_dict=data_dict,
        solution=solution,
        model=model,
        reference_values=reference_values,
        config=config,
    )

    # Update the solution and model by scaling for budget.
    solution, model = apply_budget_scaling_postprocess(
        data_dict=data_dict, solution=solution, model=model, config=config
    )

    historical_results = arrange_optimization_results(
        data_dict=data_dict,
        solution=solution,
        model=model,
        historical=True,
        config=config,
    )
    optimized_results = arrange_optimization_results(
        data_dict=data_dict,
        solution=solution,
        model=model,
        historical=False,
        config=config,
    )

    delta_results_absolute = calculate_result_deltas(
        optimized_results, historical_results, absolute=True
    )

    delta_results_relative = calculate_result_deltas(
        optimized_results, historical_results, absolute=False
    )

    out = RecommendationEngineOutput(
        run_name=run_name,
        selected_period_setting=model.settings["selected_period_setting"],
        budget=model.settings["budget"],
        historic_results=historical_results,
        optimized_results=optimized_results,
        delta_results_absolute=delta_results_absolute,
        delta_results_relative=delta_results_relative,
        curves=curves,
        warnings=warnings if warnings is not None else [],
    )

    out = display_spends_as_negative(out)
    
    return out


def display_spends_as_negative(output: RecommendationEngineOutput):
    """
    This function is used to flip the sign of all spend numbers
    so that they are shown as negative in the final output.
    """

    for results in (output.historic_results, output.optimized_results):
        results.summary.incremental.spend = -results.summary.incremental.spend
        results.summary.total.spend = -results.summary.total.spend
    
        for detail in (results.detailed_incremental, results.detailed_total):
            for d in detail:
                d.spend = -d.spend

    return output

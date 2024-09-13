"""
End-to-end recommendation engine.
"""

import json
from typing import Dict, List, Literal, Union

from pyomo.environ import ConcreteModel

from src.api.constants import DEFAULT_BUDGET_NAME
from src.api.exceptions import EmptyScope
from src.api.schemas import RecommendationEngineSettings, ScopeValue
from src.pipeline.recommendation_engine.optimizer.constraints import (
    declare_custom_constraints,
    declare_foundational_constraints,
    parse_constraints,
)
from src.pipeline.recommendation_engine.optimizer.domain import declare_model_domain
from src.pipeline.recommendation_engine.optimizer.objective import (
    declare_model_objective,
)
from src.pipeline.recommendation_engine.optimizer.parameters import (
    RecommendationEngineReferenceValues,
)
from src.pipeline.recommendation_engine.optimizer.solvers import get_solver
from src.pipeline.recommendation_engine.optimizer.variables import (
    declare_model_variables,
)
from src.pipeline.recommendation_engine.postprocessing import reco_engine_postprocessing
from src.pipeline.recommendation_engine.preprocessing import reco_engine_preprocessing
from src.pipeline.recommendation_engine.utils.warnings import BUDGET_SCALING_WARNING
from src.utils.data.async_data.async_data_manager import DataManager
from src.utils.experiment_tracking import BaseTracker


# pylint:disable=too-few-public-methods
class RecommendationEnginePipeline:
    """
    Pipeline object to run the recommendation engine.

    - Load input data
    - Perform preprocessing
    - Calculate reference values
    - Run optimizer
    - Post processing
    """

    def __init__(
        self,
        config: Dict,
        experiment_tracker: BaseTracker,
        recommendation_engine_settings: RecommendationEngineSettings = None,
        reference_values: RecommendationEngineReferenceValues = None,
        payload_json: str = None,
        **kwargs,  # pylint: disable=unused-argument
    ):
        """
        Initializes the submodules required to run the recommendation engine.

        Reference values are optionally provided; if provided, these reference values are
        used directly in the optimization. Else, a data manager is initiated using the config
        to load the required inputs and calculate the reference values.
        """
        self.config = config["config_optimizer"]
        self.country = config["country"]
        self.run_date = config["run_date"]
        self.run_code = config["run_code"]
        self.version_code = config["version_code"]

        self.experiment_tracker = experiment_tracker

        # List of warnings that will be passed via output
        self.warnings = []

        # Parse settings.
        # Read from JSON available for development use.
        if payload_json is not None:
            print("`payload_json` was provided! " f"Settings will be read from {payload_json}")
            with open(payload_json, "r") as stream:
                payload = json.load(stream)
            recommendation_engine_settings = RecommendationEngineSettings.parse_obj(payload)
        else:
            recommendation_engine_settings = RecommendationEngineSettings.parse_obj(
                recommendation_engine_settings
            )

        self.experiment_tracker.log_dict(
            recommendation_engine_settings.dict(), "reco_engine_settings.json"
        )
        self.experiment_tracker.log_params({"userid": recommendation_engine_settings.userid})

        self.model_settings = self._parse_settings(recommendation_engine_settings)

        config = self.update_data_config(
            config,
            exercise_code=recommendation_engine_settings.exercise_code,
            scope_values=recommendation_engine_settings.scope_values,
            selected_period_setting=recommendation_engine_settings.selected_period_setting,
            budget=recommendation_engine_settings.budget,
        )

        self.experiment_tracker.log_dict(config, "reco_engine_config.yaml")

        self.reference_values = reference_values
        if self.reference_values is None:
            self.data_manager = DataManager(
                data_sources_config=config["data_sources"],
                data_validation_config=config["data_validation"],
                data_cleaning_config=config["data_cleaning"],
                data_outputs_config=config["data_outputs"],
            )
        else:
            self.data_manager = None

    @staticmethod
    def build_scope_filter(scope_values: List[ScopeValue], mode: Literal["curves", "budget"]):
        """
        Build a SQL filter from the scope values. This allows us to only load the data
        that is required by the scope of the scenario.

        Filters are case insensitive to prevent issues from curves
        that were generated with different casing.

        Filter can be built for curves dataframe or budget dataframe
        """

        fltr = []

        if mode == "curves":
            for s in scope_values:
                f = f"""
                (
                    DMT_MMX.RESPONSE_CURVE.MARKET_CODE ILIKE '{s.market_code}'
                    AND DMT_MMX.RESPONSE_CURVE.BRAND_NAME ILIKE '{s.brand_name}'
                    AND DMT_MMX.RESPONSE_CURVE.CHANNEL_CODE ILIKE '{s.channel_code}'
                    AND DMT_MMX.RESPONSE_CURVE.SPECIALITY_CODE ILIKE '{s.speciality_code}'
                    AND DMT_MMX.RESPONSE_CURVE.SEGMENT_CODE ILIKE '{s.segment_code}'
                    AND DMT_MMX.RESPONSE_CURVE.SEGMENT_VALUE ILIKE '{s.segment_value}'
                )
                """
                fltr.append(f)

        else:  # mode == "budget"
            for s in scope_values:
                f = f"""
                (
                    DMT_MMX.EXERCISE_BUDGET.MARKET_CODE ILIKE '{s.market_code}'
                    AND DMT_MMX.EXERCISE_BUDGET.BRAND_NAME ILIKE '{s.brand_name}'
                )
                """
                fltr.append(f)

        fltr = "(" + " OR ".join(fltr) + ")"

        return fltr

    @staticmethod
    def update_data_config(
        cfg,
        exercise_code: str,
        scope_values: List[ScopeValue],
        selected_period_setting: Union[str, int] = None,
        budget: str = None,
        references_only: bool = False,
    ):
        """
        Updates the config to add the exercise_code to the prefilter
        of the data manager config.

        `cfg`: The config dict of the data manager
        `exercise_code`: exercise code to filter on
        `scope_values`: scope values to filter on
        `references_only`: set to True when calculating references (uplift=1)
            to reduce the amount of data queried.
        """
        if not scope_values:
            raise EmptyScope("Scenario scope does not contain valid values.")

        # Only read curves that match the provided exercise code.
        dict_update = {
            "pre_filters": {
                "API_AVAILABLE_EXERCISE.exercise_code": {
                    "type": "equal",
                    "value": exercise_code,
                }
            },
            "literal_filters": [
                RecommendationEnginePipeline.build_scope_filter(scope_values, mode="curves")
            ],
        }

        if references_only:
            dict_update["pre_filters"]["RESPONSE_CURVE.uplift"] = {
                "type": "equal",
                "value": 1,
            }

        cfg["data_sources"]["Snowflake"]["tables"]["response_curve"].update(dict_update)

        # Only read projection settings that match the provided exercise code and the related
        # projection year. Where the projection year is not provided, we force the projection
        # settings to be empty by filtering the period_name (one of the pkeys) on null
        proj_dict_update = {
            "pre_filters": {
                "API_AVAILABLE_PROJECTION_PERIOD.exercise_code": {
                    "type": "equal",
                    "value": exercise_code,
                },
                "API_AVAILABLE_PROJECTION_PERIOD.period_name": {
                    "type": "equal",
                    "value": str(selected_period_setting)
                    if selected_period_setting is not None
                    else "NULL",
                },
            }
        }
        cfg["data_sources"]["Snowflake"]["tables"]["projection_settings"].update(proj_dict_update)

        # Only read budget that match the provided exercise code and budget name
        budget_dict_update = {
            "pre_filters": {
                "EXERCISE_BUDGET.mmm_exercise": {
                    "type": "equal",
                    "value": exercise_code,
                },
                "EXERCISE_BUDGET.budget_name": {
                    "type": "equal",
                    "value": budget if budget is not None else "NULL",
                },
            },
            "literal_filters": [
                RecommendationEnginePipeline.build_scope_filter(scope_values, mode="budget")
            ],
        }
        cfg["data_sources"]["Snowflake"]["tables"]["budget"].update(budget_dict_update)

        return cfg

    def __call__(self):
        """
        Runs the pipeline.
        """
        if self.reference_values is None:
            # Load, preprocess, clean data
            self.data_manager.load_validate_clean()
            data_dict = self.data_manager.get_data_dict()

            # Preprocess, calculate references
            (
                response_curves_df,
                response_curves_reference_df,
                response_curves_projected_df,
                response_curves_reference_projected_df,
            ) = reco_engine_preprocessing(data_dict, self.config)

            self.experiment_tracker.log_table(response_curves_df, "response_curves_df.json")
            self.experiment_tracker.log_table(
                response_curves_reference_df, "response_curves_reference_df.json"
            )
            self.experiment_tracker.log_table(
                response_curves_projected_df, "response_curves_projected_df.json"
            )
            self.experiment_tracker.log_table(
                response_curves_reference_projected_df,
                "response_curves_reference_projected_df.json",
            )

            self.reference_values = RecommendationEngineReferenceValues(
                response_curves_df=response_curves_df,
                response_curves_reference_df=response_curves_reference_df,
                response_curves_projected_df=response_curves_projected_df,
                response_curves_reference_projected_df=response_curves_reference_projected_df,
            )

        solution, model = self._run_optimizer()

        formatted_output = reco_engine_postprocessing(
            data_dict=data_dict,
            solution=solution,
            model=model,
            reference_values=self.reference_values,
            config=self.config,
            run_name=self.version_code,
            warnings=self.warnings,
        )
        formatted_output = formatted_output.dict()

        self.experiment_tracker.log_dict(formatted_output, "reco_engine_output.json")

        return formatted_output

    def _parse_settings(self, recommendation_engine_settings):
        """
        Parse the `recommendation_engine_settings` objects
        into configs that can be used in each step.
        """
        model_settings = {
            "constraints": parse_constraints(
                recommendation_engine_settings.constraints,
                recommendation_engine_settings.scenario_objective,
            ),
            "scenario_objective": recommendation_engine_settings.scenario_objective.dict(),
            "scope": recommendation_engine_settings.scope_values,
            "selected_period_setting": recommendation_engine_settings.selected_period_setting,
            "budget": recommendation_engine_settings.budget,
        }

        if recommendation_engine_settings.budget != DEFAULT_BUDGET_NAME:
            self.warnings.append(BUDGET_SCALING_WARNING)

        return model_settings

    def _run_optimizer(self):
        """
        Runs the optimizer and returns a solution.
        """
        model = ConcreteModel()
        model.settings = self.model_settings

        # Declare various model components
        self._declare_domain(model)
        self._declare_parameters(model)
        self._declare_variables(model)
        self._declare_objective(model)
        self._declare_constraints(model)
        self._validate_model(model)

        solver = get_solver(model, self.config)
        solution = solver.solve()

        return solution, model

    def _declare_domain(self, model):
        """
        Identifies the domain of the model;
        declares the pyomo.Set attributes of the model object.
        """
        declare_model_domain(model, response_curves_df=self.reference_values.response_curves_df)

    def _declare_parameters(self, model):
        """
        Identifies the parameters of the model;
        declares the pyomo.Param attributes of the model object.
        """
        self.reference_values.declare_model_parameters(model)

    def _declare_variables(self, model):
        """
        Identifies the variables of the model;
        declares the pyomo.Var attributes of the model object.
        """
        declare_model_variables(model)

    def _declare_constraints(self, model):
        """
        Identifies the constraints of the model;
        declares the pyomo.Constraint attributes of the model object.
        """
        declare_foundational_constraints(model)
        declare_custom_constraints(model)

    def _declare_objective(self, model):
        """
        Identifies the objective of the model;
        declares the pyomo.Objective attributes of the model object.
        """
        declare_model_objective(model)

    def _validate_model(self, model):
        """
        Basic logical checks that the optimization conditions make sense.
        """
        # TO BE IMPLEMENETED - this will create better error messages than
        # uninformational Gurobi "model is infeasible" exception

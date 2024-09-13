"""
Main function to be imported to the entry point.

Note that this is deprecated - please use the function
`run_metaflow` in `run_flow.py` to trigger a metaflow flow; or run
the respective metaflow file from the CLI directly. e.g.

    python src/flows/{pipeline_name}.py [args]
"""
import os

from src.pipeline.external_response_curves.run_pipeline import (
    IngestionExtRespCurvesPipeline,
)
from src.pipeline.group_models.run_pipeline import GroupModelsPipeline
from src.pipeline.migrate_internal_curve.run_pipeline import MigrateCurvesPipeline
from src.pipeline.publish_exercise.run_pipeline import PublishExercisePipeline
from src.pipeline.publish_model.run_pipeline import PublishModelPipeline
from src.pipeline.recommendation_engine.run_pipeline import RecommendationEnginePipeline
from src.pipeline.response_model.brick_breaking.run_pipeline import (
    BrickBreakingPipeline,
)
from src.pipeline.response_model.run_pipeline import ResponseModelPipeline
from src.utils.config import ConfigParser
from src.utils.exceptions import DatabricksCredentialsNotProvided
from src.utils.experiment_tracking import BaseTracker, MLFlowTracker
from src.utils.snowflake_utils import MMXSnowflakeConnection

DEFAULT_CONFIG_FILES = [
    "src/config/{pipeline}/*.yaml",
    "src/config/{country}/{pipeline}/*.yaml",
    "src/config/brick_breaking/*.yaml",
]

PIPELINE_CLASSES = {
    "response_model": ResponseModelPipeline,
    "recommendation_engine": RecommendationEnginePipeline,
    "external_response_curve": IngestionExtRespCurvesPipeline,
    "publish_model": PublishModelPipeline,
    "publish_exercise": PublishExercisePipeline,
    "migrate_internal_curve": MigrateCurvesPipeline,
    "group_models": GroupModelsPipeline,
    "brick_breaking": BrickBreakingPipeline,
}


def run(**kwargs):
    """
    Entry point to run pipelines
    """
    pipeline = kwargs["pipeline"]
    country = kwargs.get("country", "NONE")
    version_code = kwargs.get("version_code")
    user_email = kwargs.get("user_email", "NONE")
    experiment_workspace = kwargs.get("experiment_workspace", os.getenv('EXPERIMENT_WORKSPACE'))

    # multiple country optimizer
    if isinstance(country, list):
        country = "multiple"

    # Read config
    config_parser = ConfigParser(DEFAULT_CONFIG_FILES, country, pipeline)
    config = config_parser.get_config()

    # Override version code if provided in the args
    if (version_code is not None):
        config["version_code"] = version_code

    print(f"[{experiment_workspace}] Running pipeline: {pipeline} with country {country} and version_code {config['version_code']}")

    # Experiment tracking
    try:
        experiment_tracker = MLFlowTracker(
            {
                # Experiment name in OneAI is /prj0060690-mmx-codebase-emea01/{pipeline}
                "experiment_name": f"/prj0060690-mmx-codebase-emea01/response_model",
                "run_name": "test",
                "user_email": "test"
            }
        )
    except DatabricksCredentialsNotProvided:
        print("Databricks credentials not provided, using Base tracker")
        experiment_tracker = BaseTracker(
            {
                "experiment_name": pipeline,
                "run_name": config["version_code"],
            }
        )

    pipeline_class = PIPELINE_CLASSES.get(pipeline)
    if pipeline_class is None:
        raise NotImplementedError(f"Pipeline '{pipeline}'")

    # run
    try:
        pipeline_obj = pipeline_class(config, experiment_tracker, **kwargs)
        result = pipeline_obj()
        return result
    except Exception as e:  # pylint: disable=broad-except # noqa: E722
        experiment_tracker.end_run("FAILED")
        raise e
    finally:
        if experiment_tracker.get_status() == "RUNNING":
            experiment_tracker.end_run("FINISHED")
        MMXSnowflakeConnection.close_all()  # close all snowflake connections.

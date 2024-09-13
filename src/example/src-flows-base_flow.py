"""
Base Metaflow Flow for MMX
"""

import pickle
import sys

from metaflow import FlowSpec, Parameter

from src.pipeline.external_response_curves.run_pipeline import (
    IngestionExtRespCurvesPipeline,
)
from src.pipeline.group_models.run_pipeline import GroupModelsPipeline
from src.pipeline.migrate_internal_curve.run_pipeline import MigrateCurvesPipeline
from src.pipeline.publish_exercise.run_pipeline import PublishExercisePipeline
from src.pipeline.publish_model.run_pipeline import PublishModelPipeline
from src.pipeline.recommendation_engine.run_pipeline import RecommendationEnginePipeline
from src.utils.config import ConfigParser
from src.utils.experiment_tracking import MetaflowTracker
from src.utils.snowflake_utils import MMXSnowflakeConnection

DEFAULT_CONFIG_FILES = [
    "src/config/{pipeline}/*.yaml",
    "src/config/{country}/{pipeline}/*.yaml",
]

PIPELINE_CLASSES = {
    "recommendation_engine": RecommendationEnginePipeline,
    "external_response_curve": IngestionExtRespCurvesPipeline,
    "publish_model": PublishModelPipeline,
    "publish_exercise": PublishExercisePipeline,
    "migrate_internal_curve": MigrateCurvesPipeline,
    "group_models": GroupModelsPipeline,
}


class BaseFlow(FlowSpec):
    """
    Base flow contains parameters and steps common to all pipelines
    """

    country = Parameter("country", type=str, default="NONE")
    output_file = Parameter("output_file", type=str)

    def __init__(self):
        """
        Custom init logic:
            -   Make parameter names accessible to pipeline code
        """
        self._parameter_names = [
            x
            for x in dir(self.__class__)
            if isinstance(getattr(self.__class__, x), Parameter)
        ]

        super().__init__()

    def start(self):
        """
        Set up config
        """
        config_parser = ConfigParser(
            DEFAULT_CONFIG_FILES, self.country, self.pipeline_name
        )
        self.config = config_parser.get_config()

    def pipeline_step(self):
        """
        In subclasses, this step should contain the required code
        to execute the pipeline.
        """
        experiment_tracker = self.get_experiment_tracker(self.config)
        pipeline_class = self.get_pipeline_class()

        kwargs = {x: getattr(self, x) for x in self._parameter_names}

        pipeline_obj = pipeline_class(self.config, experiment_tracker, **kwargs)

        try:
            result = pipeline_obj()
        except Exception as e:
            result = e
            sys.exit(1)
        finally:
            if self.output_file is not None:
                with open(self.output_file, "wb") as stream:
                    pickle.dump(result, stream)
            MMXSnowflakeConnection.close_all()

    def end(self):
        """
        End the flow
        """

    def get_experiment_tracker(self, config):
        """
        Creates the experiment tracking object
        """
        return MetaflowTracker(config, self)

    def get_pipeline_class(self):
        """
        Gets the pipeline class
        """
        return PIPELINE_CLASSES[self.pipeline_name]

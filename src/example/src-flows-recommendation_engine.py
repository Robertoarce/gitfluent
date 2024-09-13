"""
Metaflow Flow for recommendation engine.
"""
import os
import sys

from dotenv import load_dotenv
from metaflow import (  # pylint: disable=no-name-in-module
    JSONType,
    Parameter,
    card,
    step,
)

sys.path.append(os.path.join(os.path.dirname(__file__), "../../"))

# pylint: disable=wrong-import-position
from src.flows.base_flow import BaseFlow  # noqa: E402


class RecommendationEngineFlow(BaseFlow):
    """
    Wrapping the recommendation engine pipeline in
    a Metaflow Flow for experiment tracking
    """

    pipeline_name = "recommendation_engine"

    gbu = Parameter("gbu", type=str, required=True)
    recommendation_engine_settings = Parameter(
        "recommendation_engine_settings", type=JSONType, required=False
    )
    payload_json = Parameter("payload_json", type=str, required=False)

    @step
    def start(self):
        """
        Wrapper for BaseFlow.start and next().

        We have to do this here due to Metaflow static code analysis restrictions.
        """
        super().start()
        self.next(self.pipeline_step)

    @card
    @step
    def pipeline_step(self):
        """
        Wrapper for BaseFlow.pipeline_step and next().

        We have to do this here due to Metaflow static code analysis restrictions.
        """
        super().pipeline_step()
        self.next(self.end)

    @step
    def end(self):
        """
        Wrapper for BaseFlow.end and next().

        We have to do this here due to Metaflow static code analysis restrictions.
        """
        super().end()


if __name__ == "__main__":
    load_dotenv(override=False)
    RecommendationEngineFlow()

"""
Metaflow Flow for publishing exercises
"""
import os
import sys

from dotenv import load_dotenv
from metaflow import Parameter, card, step  # pylint: disable=no-name-in-module

sys.path.append(os.path.join(os.path.dirname(__file__), "../../"))

# pylint: disable=wrong-import-position
from src.flows.base_flow import BaseFlow  # noqa: E402


class PublishExerciseFlow(BaseFlow):
    """
    Wrapping the exercise publishing pipeline in
    a Metaflow Flow for experiment tracking
    """

    pipeline_name = "publish_exercise"

    model_version_code = Parameter(
        "model_version_code", type=str, required=True, multiple=True
    )
    exercise_code = Parameter("exercise_code", type=str, required=True)
    exercise_name = Parameter("exercise_name", type=str, required=True)
    env = Parameter("env", type=str, required=True)
    append = Parameter("append", type=bool, required=False)

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
    PublishExerciseFlow()

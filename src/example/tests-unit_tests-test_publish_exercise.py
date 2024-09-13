"""
Unit tests for the exercise publishing pipeline
"""
from unittest.mock import MagicMock, patch

import pandas as pd
import pytest

from src.run import run


@pytest.mark.parametrize(
    "country,model_version_code,exercise_code,exercise_name",
    [
        (
            "FR",
            ["FAKE VERSION CODE1", "FAKE VERSION CODE2"],
            "FAKE EXERCISE CODE",
            "FAKE EXERCISE NAME",
        ),
    ],
)
def test_publish_exercise_e2e(
    country, model_version_code, exercise_code, exercise_name
):
    """
    Run the pipeline with appropriate patching
    so that the database is not actually modified.
    """

    with patch("src.utils.experiment_tracking.BaseTracker"):
        with patch(
            "src.pipeline.publish_exercise.run_pipeline.snowflake_to_pandas",
            new=MagicMock(return_value=pd.DataFrame()),
        ):
            with patch(
                "snowflake.connector.cursor.SnowflakeCursor.execute"
            ) as cursor_execute:
                run(
                    country=country,
                    pipeline="publish_exercise",
                    model_version_code=model_version_code,
                    exercise_code=exercise_code,
                    exercise_name=exercise_name,
                    env=None,
                    append=False
                )

                assert cursor_execute.called

"""
Unit tests for the response curve publishing pipeline
"""
from unittest.mock import MagicMock, patch

import pandas as pd
import pytest

from src.run import run


@pytest.mark.parametrize(
    "country,model_version_code,model_name",
    [
        ("FR", ["FAKE VERSION CODE"], ["FAKE MODEL NAME"]),
    ],
)
def test_publish_model_e2e(country, model_version_code, model_name):
    """
    Run the pipeline with appropriate patching
    so that the database is not actually modified.
    """

    with patch("src.utils.experiment_tracking.BaseTracker"):
        with patch(
            "src.pipeline.publish_model.run_pipeline.snowflake_to_pandas",
            new=MagicMock(return_value=pd.DataFrame()),
        ):
            with patch(
                "snowflake.connector.cursor.SnowflakeCursor.execute"
            ) as cursor_execute:
                run(
                    country=country,
                    pipeline="publish_model",
                    model_version_code=model_version_code,
                    model_name=model_name,
                    env=None,
                )

                assert cursor_execute.called

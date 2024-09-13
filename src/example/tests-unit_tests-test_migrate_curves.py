"""
Unit tests for curve migration pipeline
"""
from unittest.mock import MagicMock, patch

import pandas as pd
import pytest

from src.run import run


@pytest.mark.parametrize(
    "country,model_version_code,from_env,to_env",
    [
        (
            "FR",
            ["FAKE VERSION CODE1", "FAKE VERSION CODE2"],
            "DEV",
            "UAT",
        ),
    ],
)
def test_migrate_curve_e2e(country, model_version_code, from_env, to_env):
    """
    Run the pipeline with appropriate patching
    so that the database is not actually modified.
    """
    with patch("src.utils.experiment_tracking.BaseTracker"):
        with patch(
            "src.pipeline.migrate_internal_curve.run_pipeline.snowflake_to_pandas",
            new=MagicMock(return_value=pd.DataFrame()),
        ):
            with patch(
                "src.pipeline.migrate_internal_curve.run_pipeline.MMXSnowflakeConnection",
                new=MagicMock(),
            ) as mock_connection_fn:
                mock_con = mock_connection_fn.return_value
                mock_cur = mock_con.cursor.return_value

                run(
                    country=country,
                    pipeline="migrate_internal_curve",
                    model_version_code=model_version_code,
                    from_env=from_env,
                    to_env=to_env,
                )

                assert mock_cur.execute.called

"""
Pipeline to migrate internal response curves between environments.
"""

from typing import Dict, List

from snowflake.connector.errors import DatabaseError

from src.pipeline.publish_model.run_pipeline import PublishModelPipeline
from src.utils.experiment_tracking import BaseTracker
from src.utils.snowflake_utils import MMXSnowflakeConnection, snowflake_to_pandas


# pylint: disable=too-few-public-methods
class MigrateCurvesPipeline:
    """
    Pipeline object to copy response curve data between environments.
    """

    def __init__(
        self,
        config: Dict,
        experiment_tracker: BaseTracker,
        model_version_code: List[str],
        from_env: str,
        to_env: str,
        autopublish: bool = False,
        model_name: List[str] = None,
        **kwargs,  # pylint: disable=unused-argument
    ):
        """
        Initialize the pipeline.
        """
        self.experiment_tracker = experiment_tracker
        self.model_version_code = model_version_code

        assert from_env != to_env, "`from_env` must be different from `to_env1`!"
        self.from_env = from_env
        self.to_env = to_env

        self.autopublish = autopublish
        if self.autopublish:
            assert model_name is not None, "Cannot autopublish without `model_name`!"
            self.publish_pipeline = PublishModelPipeline(
                config=config,
                experiment_tracker=experiment_tracker,
                model_version_code=model_version_code,
                model_name=model_name,
                env=to_env,
            )

    def __call__(self):
        """
        Migrate the curve between environments and optionally publish it.
        """
        # Check that the model is not already in the database
        query = f"""
        SELECT *
        FROM MMX_{self.to_env}.DMT_MMX.RESPONSE_CURVE
        WHERE VERSION_CODE IN (%(model_version_code)s)
        """
        params = {"model_version_code": self.model_version_code}

        already_exists_version_code = snowflake_to_pandas(query, params=params, env=self.to_env)

        if not already_exists_version_code.empty:
            raise ValueError(
                f"Model version code {already_exists_version_code['VERSION_CODE'].values} "
                f"already exists in {self.to_env} environment!"
            )

        query = f"""
        INSERT INTO MMX_{self.to_env}.DMT_MMX.RESPONSE_CURVE
        SELECT *
        FROM MMX_{self.from_env}.DMT_MMX.RESPONSE_CURVE
        WHERE VERSION_CODE IN (%(model_version_code)s)
        """
        params = {
            "model_version_code": self.model_version_code,
        }

        try:
            connection = MMXSnowflakeConnection(
                env="MIGRATION"
            )  # migration credentials
            cur = connection.cursor()  # pylint: disable=no-member
            # This pipeline expected to be run by someone with cross env privileges
            cur.execute("USE SECONDARY ROLES ALL")
            cur.execute(query, params=params)
        except DatabaseError as de:
            raise de
        finally:
            MMXSnowflakeConnection.close_all()

        self.experiment_tracker.log_dict(
            {
                "Model Version Codes": self.model_version_code,
                "From Environment": self.from_env,
                "To Environment": self.to_env,
            },
            "migrated_curves"
        )

        if self.autopublish:
            self.publish_pipeline()

"""
Pipeline to publish response curves to the API.
"""

from typing import Dict, List

from snowflake.connector.errors import DatabaseError

from src.utils.experiment_tracking import BaseTracker
from src.utils.snowflake_utils import MMXSnowflakeConnection, snowflake_to_pandas


# pylint: disable=too-few-public-methods
class PublishModelPipeline:
    """
    Pipeline object to publish the model by adding it
    to the API_AVAILABLE_RESPONSE_MODEL table in Snowflake DMT.
    """

    def __init__(
        self,
        config: Dict,
        experiment_tracker: BaseTracker,
        model_version_code: List[str],
        model_name: List[str],
        env: str,
        **kwargs,  # pylint: disable=unused-argument
    ):
        """
        Initialize the pipeline.
        """
        self.experiment_tracker = experiment_tracker
        self.model_version_code = model_version_code
        self.model_name = model_name
        self.env = env

        if len(model_version_code) != len(model_name):
            raise ValueError(
                f"{len(model_version_code)} version codes were provided, but only "
                f"{len(model_name)} model names were provided!"
            )

    def __call__(self):
        """
        Publish the model by executing the snowflake query.
        """
        # Check if the model is already published
        query = """
        SELECT *
        FROM DMT_MMX.API_AVAILABLE_RESPONSE_MODEL
        WHERE version_code IN (%(model_version_code)s)
        """

        params = {"model_version_code": self.model_version_code}

        already_published_models = snowflake_to_pandas(
            query, params=params, env=self.env
        )

        if not already_published_models.empty:
            raise ValueError(
                "Model version codes "
                f"{already_published_models['VERSION_CODE'].values} "
                f"already published!"
            )

        query = """
        INSERT INTO DMT_MMX.API_AVAILABLE_RESPONSE_MODEL
        (
            gbu_code,
            market_code,
            brand_name,
            channel_code,
            speciality_code,
            segment_code,
            segment_value,
            version_code,
            model_name
        )

        SELECT DISTINCT
            gbu_code,
            market_code,
            brand_name,
            channel_code,
            speciality_code,
            segment_code,
            segment_value,
            version_code,
            %(mn)s AS model_name
        FROM DMT_MMX.RESPONSE_CURVE
        WHERE version_code IN (%(mvc)s)
        """

        try:
            connection = MMXSnowflakeConnection(env=self.env)
            cur = connection.cursor()  # pylint: disable=no-member
            for mn, mvc in zip(self.model_name, self.model_version_code):
                params = {"mn": mn, "mvc": mvc}
                cur.execute(query, params=params)
        except DatabaseError as de:
            raise de
        finally:
            MMXSnowflakeConnection.close_all()

        self.experiment_tracker.log_dict(
            {
                "Published Model Version Codes": self.model_version_code,
                "Model Names": self.model_name,
                "Environment": self.env,
            },
            "published_models",
        )

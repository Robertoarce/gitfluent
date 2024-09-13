"""
Pipeline to group response models in the API
"""

from typing import Dict, List

from snowflake.connector.errors import DatabaseError

from src.pipeline.publish_model.run_pipeline import PublishModelPipeline
from src.utils.experiment_tracking import BaseTracker
from src.utils.snowflake_utils import MMXSnowflakeConnection


# pylint: disable=too-few-public-methods
class GroupModelsPipeline:
    """
    Takes two or more version codes, and copies them into a new response curve version code
    such that they can be viewed in one screen on the UI.
    """

    def __init__(
        self,
        config: Dict,
        experiment_tracker: BaseTracker,
        model_version_code: List[str],
        model_name: str,
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

        # The new version code which will be assigned to the grouped model
        self.new_version_code = config["version_code"]

        if len(model_version_code) <= 1:
            raise ValueError(
                "Only one model_version_code was provided. To publish a single model, "
                "please use '--pipeline=publish_model' instead."
            )

        self.publish_pipeline = PublishModelPipeline(
            config=config,
            experiment_tracker=experiment_tracker,
            model_version_code=[self.new_version_code],
            model_name=[model_name],
            env=env,
        )

    def __call__(self):
        """
        Create a new version code, then publish it as a new model.
        """

        # Create the new version code in the RESPONSE_CURVE TABLE
        query = f"""
        INSERT INTO DMT_MMX.RESPONSE_CURVE
        SELECT * REPLACE('{self.new_version_code}' AS VERSION_CODE)
        FROM DMT_MMX.RESPONSE_CURVE
        WHERE VERSION_CODE IN (%(model_version_code)s)
        """
        params = {"model_version_code": self.model_version_code}

        try:
            connection = MMXSnowflakeConnection(env=self.env)
            cur = connection.cursor()  # pylint: disable=no-member
            cur.execute(query, params=params)
        except DatabaseError as de:
            raise de

        # Publish using the new version code
        self.publish_pipeline()

        self.experiment_tracker.log_dict(
            {
                "Old version codes": self.model_version_code,
                "New version code": self.new_version_code,
                "Environment": self.env,
            },
            "Grouped models",
        )

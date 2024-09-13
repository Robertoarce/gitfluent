"""
Pipeline to publish an exercise to the API.
"""

from typing import Dict, List

from snowflake.connector.errors import DatabaseError

from src.utils.experiment_tracking import BaseTracker
from src.utils.snowflake_utils import MMXSnowflakeConnection, snowflake_to_pandas


# pylint: disable=too-few-public-methods
class PublishExercisePipeline:
    """
    Pipeline object to publish the model by adding it
    to the API_AVAILABLE_EXERCISE table in Snowflake DMT.
    """

    def __init__(
        self,
        config: Dict,
        experiment_tracker: BaseTracker,
        model_version_code: List[str],
        exercise_name: str,
        env: str,
        append: bool,
        exercise_code: str = None,
        **kwargs,  # pylint: disable=unused-argument
    ):
        """
        Initialize the pipeline.
        """
        self.experiment_tracker = experiment_tracker
        self.model_version_code = model_version_code
        self.exercise_code = exercise_code or config["version_code"]
        self.exercise_name = exercise_name
        self.env = env
        self.append = append

    def __call__(self):
        """
        Publish the exercise by executing the snowflake query.
        """
        # Check if the model is already published
        query = """
        SELECT *
        FROM DMT_MMX.API_AVAILABLE_EXERCISE
        WHERE (exercise_code = %(exercise_code)s)
        OR (exercise_name = %(exercise_name)s)
        """
        params = {
            "exercise_code": self.exercise_code,
            "exercise_name": self.exercise_name,
        }

        if not snowflake_to_pandas(query, params=params, env=self.env).empty:
            if self.append:
                query = """
                SELECT *
                FROM DMT_MMX.API_AVAILABLE_EXERCISE
                WHERE (exercise_code = %(exercise_code)s)
                AND (version_code in (%(model_version_code)s))
                """
                params = {
                    "exercise_code": self.exercise_code,
                    "model_version_code": self.model_version_code,
                }
                models_already_in_exercise = snowflake_to_pandas(query, params=params, env=self.env)
                
                if not models_already_in_exercise.empty:
                    raise ValueError(
                        f"Cannot append: the following model version codes already exist in exercise "
                        f"{self.exercise_code}: {models_already_in_exercise['VERSION_CODE'].values}"
                    )

                print(
                    f"Appending {len(self.model_version_code)} version codes to "
                    f"existing exercise {self.exercise_code}"
                )
            else:
                raise ValueError(
                    f"Exercise already exists with exercise_code {self.exercise_code}"
                    f" or exercise_name {self.exercise_name} ! Please use option --append "
                    " to confirm you wish to add the model(s) to the existing exercise"
                )

        query = """
        INSERT INTO DMT_MMX.API_AVAILABLE_EXERCISE
        (
            exercise_code,
            gbu_code,
            market_code,
            brand_name,
            channel_code,
            speciality_code,
            segment_code,
            segment_value,
            version_code,
            exercise_name
        )

        SELECT DISTINCT
            %(exercise_code)s AS exercise_code,
            gbu_code,
            market_code,
            brand_name,
            channel_code,
            speciality_code,
            segment_code,
            segment_value,
            version_code,
            %(exercise_name)s AS exercise_name
        FROM DMT_MMX.API_AVAILABLE_RESPONSE_MODEL
        WHERE version_code IN (%(version_codes)s)
        """

        params = {
            "exercise_code": self.exercise_code,
            "exercise_name": self.exercise_name,
            "version_codes": self.model_version_code,
        }

        try:
            connection = MMXSnowflakeConnection(env=self.env)
            cur = connection.cursor()
            cur.execute(query, params=params)
        except DatabaseError as de:
            raise de
        finally:
            MMXSnowflakeConnection.close_all()

        self.experiment_tracker.log_dict(
            {
                "Model Versions": self.model_version_code,
                "Exercise Name": self.exercise_name,
                "Exercise Code": self.exercise_code,
                "Environment": self.env,
            },
            "published_exercises"
        )

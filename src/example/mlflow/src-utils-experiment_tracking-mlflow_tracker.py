"""
Module for managing connection to MLFlow to log experiment artifacts
"""
import os
from typing import Dict

from mlflow import MlflowClient

from src.utils.exceptions import DatabricksCredentialsNotProvided
from src.utils.experiment_tracking.base_tracker import BaseTracker


class MLFlowTracker(BaseTracker):
    """
    Manages I/O with MLFlow / Databricks
    """

    def __init__(self, config: Dict, **kwargs):
        """
        `config` is a dictionary containing:
            "experiment_id": the name of the experiment in databricks
            "run_name": experiment run identifier
        """
        super().__init__(config)
        self._validate_databricks_credentials()
        self._client = MlflowClient(tracking_uri="databricks")
        self.experiment_id = self._client.get_experiment_by_name(self.experiment_name).experiment_id

        tags = { "user_email": self.user_email }

        self.run_id = self._client.create_run(
            experiment_id=self.experiment_id, run_name=self.run_name, tags=tags
        ).info.run_id

    def log_params(self, params: Dict):
        """
        `params` is a dictionary containing the key value mapping
        of the parameters to be logged.
        """
        for k, v in params.items():
            self._client.log_param(self.run_id, k, v)

    def log_metrics(self, metrics: Dict, step: int = None):
        """
        `metrics` is a dictionary containing the key value mapping
        of the metrics to be logged.
        """
        for k, v in metrics.items():
            self._client.log_metric(self.run_id, k, v, step=step)

    def log_artifacts(self, artifacts: Dict):
        """
        `artifacts` is a dictionary mapping local filepath to
        relative filepath within the experiment to save the artifact
        """
        for k, v in artifacts.items():
            self._client.log_artifact(self.run_id, k, v)

    def log_dict(self, d: Dict, filepath: str):
        """
        Log dict `d`
        """
        self._client.log_dict(self.run_id, d, filepath)

    # pylint:disable=no-member
    def log_table(self, table, filepath: str):
        """
        Log pandas dataframe `table`
        """
        self._client.log_table(self.run_id, table, filepath)

    def end_run(self, status: str = "FINISHED"):
        """
        Terminate the run and fetch updated status. By default,
        the status is set to "FINISHED". Other values you can
        set are "KILLED", "FAILED", "RUNNING", or "SCHEDULED".
        """
        self._client.set_terminated(self.run_id, status=status)

    def get_status(self):
        """
        Returns the run status.
        """
        return self._client.get_run(self.run_id).info.status

    def _validate_databricks_credentials(self):
        """
        Validates that the databricks credentials exist in environment secrets
        """
        # All Sanofi users should be using SSO -> no user/password available.
        validation_methods = (
            ("DATABRICKS_HOST", "DATABRICKS_TOKEN"),
            # ("DATABRICKS_USERNAME", "DATABRICKS_PASSWORD")
        )

        if not any(all(os.getenv(k) for k in method) for method in validation_methods):
            raise DatabricksCredentialsNotProvided

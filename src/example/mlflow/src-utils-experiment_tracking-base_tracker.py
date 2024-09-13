"""
Base Experiment Tracker
"""
from typing import Dict


class BaseTracker:
    """
    Base Tracking class with unimplemented logging functions.
    Can be used as a mock tracker to execute experiments when
    databricks credentials are not available.
    """

    def __init__(self, config: Dict, **kwargs):
        """
        `config` is a dictionary containing:
            "experiment_id": the name of the experiment in databricks
            "run_name": experiment run identifier
        """
        self.experiment_name = config["experiment_name"]
        self.run_name = config["run_name"]
        self.user_email = config["user_email"]

    def log_params(self, params: Dict):
        """
        `params` is a dictionary containing the key value mapping
        of the parameters to be logged.
        """

    def log_metrics(self, metrics: Dict, step: int = None):
        """
        `metrics` is a dictionary containing the key value mapping
        of the metrics to be logged.
        """

    def log_artifacts(self, artifacts: Dict):
        """
        `artifacts` is a dictionary mapping local filepath to
        relative filepath within the experiment to save the artifact
        """

    def log_dict(self, d: Dict, filepath: str):
        """
        Log dict `d`
        """

    def log_table(self, table, filepath: str):
        """
        Log pandas dataframe `table`
        """

    def end_run(self, status: str = "FINISHED"):
        """
        Terminate the run and fetch updated status.
        """

    def get_status(self):
        """
        Returns the run status.
        """

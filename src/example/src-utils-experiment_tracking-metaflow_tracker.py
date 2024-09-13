"""
Module for managing connection to MLFlow to log experiment artifacts
"""
import os
from typing import Dict

from src.utils.experiment_tracking.base_tracker import BaseTracker

class MetaflowTracker(BaseTracker):
    """
    Manages artifacts for Metaflow tracking
    """

    def __init__(self, config: Dict, metaflow_obj):
        """
        `config` is a dictionary containing:
            "experiment_id": the name of the experiment
            "run_name": experiment run identifier
        
        These were mainly implemented for use in databricks but we can continue
        to use them in Metaflow.

        `metaflow_obj` is the metaflow Flow which we use to attach artifacts
        """
        self.metaflow_obj = metaflow_obj

    def log_params(self, params: Dict):
        """
        `params` is a dictionary containing the key value mapping
        of the parameters to be logged.
        """
        for k, v in params.items():
            setattr(self.metaflow_obj, k, v)

    def log_metrics(self, metrics: Dict, step: int = None):
        """
        `metrics` is a dictionary containing the key value mapping
        of the metrics to be logged.
        """
        for k, v in metrics.items():
            setattr(
                self.metaflow_obj,
                f"{k}_{step}" if step is not None else k,
                v
            )

    def log_artifacts(self, artifacts: Dict):
        """
        `artifacts` is a dictionary mapping local filepath to
        relative filepath within the experiment to save the artifact
        """
        for local_path, server_path in artifacts.items():
            with open(local_path, "rb") as stream:
                setattr(self.metaflow_obj, server_path, stream)

    def log_dict(self, d: Dict, filepath: str):
        """
        Log dict `d`
        """
        setattr(self.metaflow_obj, filepath, d)

    def log_table(self, table, filepath: str):
        """
        Log pandas dataframe `table`
        """
        setattr(self.metaflow_obj, filepath, table)
    
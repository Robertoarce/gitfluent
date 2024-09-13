"""
This file contains all the utilities related to mlflow
"""
import mlflow
import pandas as pd
from mlflow.store.artifact.models_artifact_repo import ModelsArtifactRepository


def setup_mlflow_for_turing(mlflow_params: dict) -> dict:
    """
    Set mlflow parameters such as mlflow server uri, experiment path and locations

    Args:
        mlflow_params (dict): mlflow parameters

    Returns:
        dict:  mlflow parameters
    """
    mlflow.set_tracking_uri(mlflow_params["REMOTE_SERVER_URL"])
    mlflow.set_experiment(
        mlflow_params["EXPERIMENT_PATH"] +
        mlflow_params["EXPERIMENT_LOCATION"])
    return mlflow_params

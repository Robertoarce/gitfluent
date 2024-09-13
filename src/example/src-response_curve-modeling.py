"""
Module to run bayedian model and train on samples
"""
import logging
import os
import sys

import pandas as pd

from src.pipeline.response_model.utils import transformed_features
from src.response_curve.generative_model.stan_builder import StanBuilder
from src.response_curve.post_processing import BayesianPostProcess
from src.response_curve.st_response_model import BayesianResponseModel

sys.path.insert(0, os.getcwd())

logger = logging.getLogger(__name__)


def run_bayesian_model(
    features_df: pd.DataFrame,
    normalized_features_df: pd.DataFrame,
    transformation_params: dict,  # TransformationParams
    channel_code: str,
    config,
    experiment_tracker,
    levels,
):
    """
    Function to fit and generate relevant predictions with the bayesian model

    Returns:
        - samples_full_df: Data frame with the samples of all relevant parameters from the
        bayesian model, which are needed in the response curve generation
        - bayesian_model_indexes (MappingIndexes): mapping of integer indexes in the bayesian model
        code to the corresponding business values
    """

    # << (1) INITIALIZATION: BayesianResponseModel>>
    print("... (1) INITIALIZATION: BayesianResponseModel")
    print(f"Dataframe size going for modeling is: {features_df.shape}")
    stan_model_file_list = config.get("STAN_MODEL_FILE")
    stan_model_file = stan_model_file_list[stan_model_file_list.index(channel_code) + 1]
    print("stan model file: ", stan_model_file)
    stan_model_parameters = {k[0]: k[1] for k in config.get("STAN_MODEL_PARAMETERS")}

    if "region" not in normalized_features_df.columns:
        normalized_features_df["region"] = config.get("GEO_LEVEL")  # "national"

    if config.get("USE_BUILDER"):
        sb = StanBuilder(channel_code, config)
        sb.build_and_save_model(stan_model_file)

    bayesian_model = BayesianResponseModel(
        stan_model_path=stan_model_file,
        stan_model_parameters=stan_model_parameters,
        normalized_features_df=normalized_features_df,
        transformation_params=transformation_params,
        channel_code=channel_code,
        config=config,
    )

    # << (2) MODEL INPUT CREATION >>
    print("... (2) MODEL INPUT CREATION: BayesianResponseModel")
    logger.info("[STAN] Model input creation")
    bayesian_model.create_data_input()
    print("    ---> bayesian_model.data", bayesian_model.data.keys())

    # << (3) MODEL COMPILATION >>
    print("... (3) MODEL COMPILATION: BayesianResponseModel")
    logger.info("[STAN] Model compilation: SKIP for now")

    bayesian_model.compile_model()

    # << (4) MODEL TRAINING >>
    print("... (4) MODEL TRAINING: BayesianResponseModel")
    logger.info("[STAN] Model training")
    bayesian_model.train_model()

    # Compute sample and mean_adstock
    samples_df = bayesian_model.fit.draws_pd()
    print(transformed_features(config))
    adstock_variables = [
        touchpoint
        for touchpoint, transformation in transformed_features(config)[channel_code].items()
        if "adstock" in transformation
    ]

    lambda_adstock = []
    for touchpoint in range(len(adstock_variables)):
        lambda_adstock.append(samples_df[f"lambda_adstock[{touchpoint + 1}]"])

    # Compute mean lambda adstock value per touchpoint
    lambda_adstock = [
        (variable, lambda_adstock_sample.mean())
        for variable, lambda_adstock_sample in zip(adstock_variables, lambda_adstock)
    ]

    print(bayesian_model.fit.stan_variables().keys())

    # << (5) POST PROCESSSING>>  - Check the A&P Code in Details since this is a part of it.
    print("... (4) POST PROCESSSING: BayesianResponseModel")
    logger.info("[STAN] Model post-processing")
    model_post_process = BayesianPostProcess(
        bayesian_model=bayesian_model,
        config=config,
        channel_code=channel_code,
        experiment_tracker=experiment_tracker,
        levels=levels,
    )
    model_post_process.run_post_processing()
    params_summary_df = model_post_process.params_summary.copy()
    return (
        bayesian_model.indexes,
        lambda_adstock,
        bayesian_model,
        params_summary_df,
    )

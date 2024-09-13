"""
Regression Metrics generation module
"""
from typing import Tuple

import numpy as np
import pandas as pd
from sklearn.metrics import mean_absolute_error, r2_score
from statsmodels.stats.stattools import durbin_watson

from src.pipeline.feature_engineering.utils import save_file
from src.response_curve.output_formatting.utils import add_total_metrics
from src.utils.names import (
    F_CHANNEL_CODE,
    F_MAPE,
    F_MEAN_ABSOLUTE_ERROR,
    F_R_SQUARE,
    F_UPLIFT,
    F_VALUE,
    F_VALUE_PRED,
    F_YEAR_MONTH,
    F_VALUE_PRED_p10,
    F_VALUE_PRED_p90,
)
from src.utils.schemas.response_model.input.product_master import ProductMasterSchema

pms = ProductMasterSchema()


def create_regression_metrics_table(
    denormalized_output_df: pd.DataFrame, national_features_df: pd.DataFrame, config
) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """
    Main function, launch the calculation of relevant linear regression metrics

    Args:
        - national_features_df: Table with all transformed features at national level.
        This table is used to collect the actual volume for any given brand x year_week.
    :return:
    """
    pred_vs_actual_df = combine_actual_and_predictions(
        denormalized_output_df=denormalized_output_df,
        national_features_df=national_features_df,
        config=config,
    )

    pred_vs_actual_df = add_total_metrics(pred_vs_actual_df, config.get("RESPONSE_LEVEL_TIME"))

    regression_metrics_df = compute_accuracy_metrics(
        pred_vs_actual_df=pred_vs_actual_df, config=config
    )

    residuals_df = compute_residuals(pred_vs_actual_df=pred_vs_actual_df, config=config)

    return regression_metrics_df, pred_vs_actual_df, residuals_df


def compute_accuracy_train_test(
    pred_vs_actual_brand_df: pd.DataFrame,
    test_length: int,
    brand_name: str,
    channel_code: str,
) -> list:
    """
    docstring
    """
    metrics = []

    max_train_index = len(pred_vs_actual_brand_df) - test_length

    if test_length == 0:
        indexes = {"train": (0, max_train_index)}
    else:
        indexes = {
            "train": (0, max_train_index),
            "test": (max_train_index, len(pred_vs_actual_brand_df)),
        }

    for st, (start, end) in indexes.items():
        r_squared, mae, mape = _compute_accuracy_metrics(
            y_true=pred_vs_actual_brand_df[F_VALUE][start:end],
            y_pred=pred_vs_actual_brand_df[F_VALUE_PRED][start:end],
        )

        metrics.append(
            [
                channel_code,
                brand_name,
                r_squared,
                mae,
                mape,
                st,
            ]
        )

    return metrics


def combine_actual_and_predictions(
    denormalized_output_df: pd.DataFrame, national_features_df: pd.DataFrame, config
) -> pd.DataFrame:
    """
    Function centralizing the logic used to combine predicted sell-out volumes at uplift = 1
    and actual sell-out volumes
    """
    ref = [
        "brand_name",
        config.get("RESPONSE_LEVEL_TIME"),
        F_CHANNEL_CODE,
    ]
    pred_relevant_columns = [
        *ref,
        # F_VOLUME_PRED,
        # F_VOLUME_PRED_p10,
        # F_VOLUME_PRED_p90,
        F_VALUE_PRED,
        F_VALUE_PRED_p10,
        F_VALUE_PRED_p90,
    ]

    # Predictions at uplift = 1 (mean of Bayesian model samples)
    pred_df = denormalized_output_df[
        (denormalized_output_df[F_UPLIFT] == 1) & (denormalized_output_df[F_CHANNEL_CODE] != "all")
    ]
    pred_df = pred_df[pred_relevant_columns].drop_duplicates()
    pred_df = pred_df.groupby([*ref], as_index=False).max()

    # Actual sell-out volumes (smoothed if smoothing of volume applied in
    # feature engineering)
    actual_relevant_columns = [
        *ref,
        config.get("TARGET_VARIABLE"),
    ]
    pred_vs_actual_df = pred_df.merge(
        national_features_df[actual_relevant_columns],
        on=[*ref],
        how="inner",
    )
    assert not pred_vs_actual_df.duplicated([*ref]).any()

    return pred_vs_actual_df


def compute_accuracy_metrics(pred_vs_actual_df: pd.DataFrame, config):
    """
    Compute all relevant linear regression metrics to measure the accuracy of our Bayesian
    reconstruction of observed volumes based on explanatory variables
    """
    accuracy_metrics = []

    for (
        channel_code,
        brand_name,
    ), pred_vs_actual_brand_df in pred_vs_actual_df.groupby([F_CHANNEL_CODE, "brand_name"]):
        accuracy_metric = compute_accuracy_train_test(
            pred_vs_actual_brand_df.copy(),
            config.get("TEST_DURATION"),
            brand_name,
            channel_code,
        )

        accuracy_metrics += accuracy_metric

    relevant_columns = [
        F_CHANNEL_CODE,
        "brand_name",
        F_R_SQUARE,
        F_MEAN_ABSOLUTE_ERROR,
        F_MAPE,
        "set",
    ]
    return pd.DataFrame(data=accuracy_metrics, columns=relevant_columns)


def compute_residuals(pred_vs_actual_df: pd.DataFrame, config) -> pd.DataFrame:
    """
    Compute residuals, aka the delta between predicted and actual values
    """
    pred_vs_actual_df = format_forecast_vs_actual_overview(pred_vs_actual_df.copy())
    residuals_dfs = []
    for (
        channel_code,
        brand_name,
    ), residuals_df in pred_vs_actual_df.groupby([F_CHANNEL_CODE, "brand_name"]):
        residuals_df = residuals_df.copy()
        residuals_df[F_YEAR_MONTH] = residuals_df[F_YEAR_MONTH].astype(str)

        for suffix in ["", "_p10", "_p90"]:
            residuals_df["residuals" + suffix] = (
                residuals_df[F_VALUE] - residuals_df[F_VALUE_PRED + suffix]
            )

        residuals_df[F_CHANNEL_CODE] = channel_code
        residuals_df["brand_name"] = brand_name
        residuals_df = residuals_df[
            [
                F_CHANNEL_CODE,
                "brand_name",
                config.get("RESPONSE_LEVEL_TIME"),
            ]
            + ["residuals" + suffix for suffix in ["", "_p10", "_p90"]]
        ]
        residuals_dfs.append(residuals_df)

    return pd.concat(residuals_dfs)


def _compute_mape(y_true: pd.Series, y_pred: pd.Series):
    """Compute Mean Absolute Percentage Error"""
    y_true, y_pred = np.array(y_true), np.array(y_pred)
    return np.mean(np.abs((y_true - y_pred) / y_true)) * 100


def _compute_accuracy_metrics(y_true: pd.Series, y_pred: pd.Series):
    """
    Compute R2, MAE and MAPE metrics for channel of interest
    """
    # remove inf pred values
    y_pred = y_pred.replace(np.inf, np.nan).fillna(0)

    # comput metrics
    r_squared = r2_score(y_true=y_true, y_pred=y_pred)
    mae = mean_absolute_error(y_true=y_true, y_pred=y_pred)
    mape = _compute_mape(y_true=y_true, y_pred=y_pred)
    return r_squared, mae, mape


def format_forecast_vs_actual_overview(actual_vs_pred_df: pd.DataFrame):
    """
    docstring
    """
    aggregation = {
        F_VALUE: "mean",
        # F_VOLUME_PRED: "mean",
        # F_VOLUME_PRED_p10: "mean",
        # F_VOLUME_PRED_p90: "mean",
        F_VALUE_PRED: "mean",
        F_VALUE_PRED_p10: "mean",
        F_VALUE_PRED_p90: "mean",
    }
    aggregation = dict(
        filter(
            lambda k: k[0] in actual_vs_pred_df.columns and actual_vs_pred_df[k[0]].notnull().any(),
            aggregation.items(),
        )
    )
    assert not actual_vs_pred_df.duplicated([F_CHANNEL_CODE, "brand_name", F_YEAR_MONTH]).any()
    return actual_vs_pred_df.groupby(
        [F_CHANNEL_CODE, "brand_name", F_YEAR_MONTH], as_index=False
    ).agg(aggregation)


def save_durbin_watson_results(residuals_df, config, experiment_tracker, channel_code):
    """
    Compute and save Durbin-Watson test results for residuals.

    This function computes the Durbin-Watson statistic for residuals grouped by brand_name,
    and saves the results to a CSV file.

    Args:
        residuals_df (pd.DataFrame): DataFrame containing residuals.
        config (dict): Configuration parameters.
        experiment_tracker: Experiment tracker for logging.
        channel_code (str): Channel code for organizing the saved file.

    Returns:
        None
    """
    dw_results = []

    for brand_name, residuals_ft in residuals_df.groupby(["brand_name"]):
        residuals_ft = residuals_ft.copy()
        residuals_ft.drop(
            columns=[
                "brand_name",
                F_CHANNEL_CODE,
                config.get("RESPONSE_LEVEL_TIME"),
            ],
            inplace=True,
        )
        results = pd.DataFrame.from_dict(
            {
                "brand_name": brand_name,
                "dw_score": durbin_watson(residuals_ft["residuals"]),
            },
            orient="index",
        ).T
        dw_results.append(results)

    save_file(
        data=pd.concat(dw_results),
        file_name="metrics/durbin_watson.csv",
        experiment_tracker=experiment_tracker,
        mlflow_directory=channel_code,
    )

"""
Utility methods for feature engineering
"""
import json
import logging
import os
import pickle
from typing import Tuple

import pandas as pd
import yaml

from src.pipeline.feature_engineering.feature_names import Features
from src.pipeline.feature_engineering.features_anp import (
    compute_effective_adstock_length,
)
from src.utils.names import F_BRAND_INDEX, F_VALUE, F_YEAR_MONTH
from src.utils.settings_utils import (
    get_name_from_feature,
    get_stan_transformation_index,
    get_touchpoints_from_tags,
)

logger = logging.getLogger(__name__)

_COMPULSORY_FEATURES = {F_VALUE}


def add_brand_index_for_bayesian_model(features_df: pd.DataFrame) -> pd.DataFrame:
    """Function to add the brand index to the features table"""

    brand_index = {
        brand: b
        # for b, brand in
        # enumerate(sorted(set(features_df["internal_product_code"])))
        for b, brand in enumerate(
            sorted(set(features_df["brand_name"]))
        )  # TODO: added by Dip, we don't have product codes, data is at brand level
    }
    features_df[F_BRAND_INDEX] = (
        # features_df["internal_product_code"].map(brand_index) + 1
        features_df["brand_name"].map(brand_index)
        + 1  # TODO: added by Dip, we don't have product codes, data is at brand level
    )

    return features_df


def add_missing_compulsory_features(
    config,
    normalized_features_df: pd.DataFrame,
) -> pd.DataFrame:
    """Adding features needed to compute the models, on on-trade and off-trade channels"""

    for col in sorted(list(_COMPULSORY_FEATURES.difference(normalized_features_df.columns))):
        normalized_features_df[col] = 0

    assert normalized_features_df[config.get("TARGET_VARIABLE")].sum() != 0
    return normalized_features_df


def apply_time_scope_filter(
    features_df: pd.DataFrame, year_month_start: int = None, year_month_end: int = None
) -> pd.DataFrame:
    """Applies time scope filter"""
    if year_month_start is None:
        year_month_start = features_df[F_YEAR_MONTH].min()

    if year_month_end is None:
        year_month_end = features_df[F_YEAR_MONTH].max()

    return features_df[
        features_df[F_YEAR_MONTH].between(year_month_start, year_month_end, inclusive=True)
    ].copy()


def get_feature_from_name(config, predictor):
    """Gets the feature from the predictor name"""
    # TODO : abstract spend vs exec logic
    for param_dicts in config["STAN_PARAMETERS"].values():
        if predictor in param_dicts:
            if any(
                tag in ["media", "trade_marketing"]
                for tag in param_dicts[predictor].get("tags", [])
            ):
                return "spend_" + predictor
            return predictor
    if predictor == config.get("TARGET_VARIABLE"):
        return predictor
    raise ValueError


def predictor_features_name(config):
    """[summary]

    Arguments:
        config {[type]} -- [description]

    Returns:
        [type] -- [description]
    """
    return {
        channel_code: {
            get_feature_from_name(config, k): v
            for k, v in config["STAN_PARAMETERS"]["predictor_parameters"].items()
            if channel_code in v.get("channel", [channel_code])
        }
        for channel_code in config["STAN_PARAMETERS"]["channels"]
    }


def seasonality_features(config):
    """[summary]

    Arguments:
        config {[type]} -- [description]

    Returns:
        [type] -- [description]
    """
    if "seasonality_parameters" in config.get("STAN_PARAMETERS"):
        return {
            channel_code: {
                p: v
                for p, v in config["STAN_PARAMETERS"]["seasonality_parameters"].items()
                if channel_code in v.get("channel", [channel_code])
            }
            for channel_code in config["STAN_PARAMETERS"]["channels"]
        }
    return {}


def validate_features_table(
    config, features_df: pd.DataFrame, response_level: Tuple[str], channel_code: str
):
    """
    Validation of the features table:
    - check one row per relevant combination
    - unique index per brand
    - no missing `year_week` on a given brand
    - presence of all tables needed
    """
    assert not features_df.empty

    assert not features_df.duplicated(list(response_level)).any()

    assert (features_df.groupby(["brand_name"])[F_BRAND_INDEX].nunique() == 1).all()

    seasonal_feature = seasonality_features(config)
    if bool(seasonal_feature):
        feature_list = list(predictor_features_name(config)[channel_code]) + list(
            seasonality_features(config)[channel_code]
        )
    else:
        feature_list = list(predictor_features_name(config)[channel_code])
    for feature in feature_list:
        try:
            if feature == "seasonality":
                for m in Features.seasonality.months():
                    assert m in features_df.columns
            else:
                assert feature in features_df.columns
        except AssertionError:
            logger.error(
                f"Your feature dataframe is missing the following feature: {feature}. "
                "Model settings and feature engineering should be consistent"
            )


def get_metric(config, feature):
    """[summary]

    Arguments:
        config {[type]} -- [description]
        feature {[type]} -- [description]

    Returns:
        [type] -- [description]
    """
    name = get_name_from_feature(feature)
    for v in config.get("STAN_PARAMETERS").values():
        if name in v:
            return v[name].get("metric", "spend_value")
    return None

def save_file(
    data,
    file_name,
    mlflow_directory,
    allow_append=False,
    experiment_tracker=None,
    dpi=200,
    **kwargs,
):
    """Save files to databricks

    Arguments:
        data {[type]} -- [description]
        file_name {[type]} -- [description]
        mlflow_directory {[type]} -- [description]

    Keyword Arguments:
        allow_append {bool} -- [description] (default: {False})
        experiment_tracker {[type]} -- [description] (default: {None})
        dpi {int} -- [description] (default: {200})
    """
    name_of_file = os.path.basename(file_name)
    file_name = os.path.join(os.getcwd(), "output")
    file_name = os.path.join(file_name, name_of_file)
    print("saving file_name: ", file_name)
    if isinstance(data, pd.DataFrame):
        data.to_csv(file_name)

    elif file_name.endswith(".pkl"):
        with open(file_name, "wb") as f:
            pickle.dump(data, f)

    elif file_name.endswith(".json"):
        with open(file_name, "w") as f:
            json.dump(data, f)

    elif file_name.endswith(".yaml") or file_name.endswith(".yml"):
        with open(file_name, "w") as f:
            yaml.dump(data, f)

    elif file_name.endswith(".csv"):
        if not os.path.isfile(file_name) or not allow_append:
            data.to_csv(file_name, index=data.index.name is not None, **kwargs)
            return

        # Append to existing file
        with open(file_name, "a") as file:
            file.write(data.to_csv(index=data.index.name is not None, header=False, **kwargs))
            logger.info("[SAVE DATA] Data appended to existing csv file")
    elif file_name.endswith(".png"):
        data.savefig(fname=file_name, dpi=dpi, **kwargs)

    if experiment_tracker:
        experiment_tracker.log_artifacts({os.path.join("output", name_of_file): mlflow_directory})
    os.remove(file_name)


def get_adstock_lengths(touchpoints, adstock_means, channel_code, config):
    """
    Get the adstock length for touchpoints
    """
    adstock = {}
    for tp in touchpoints:
        if tp in [
            y
            for x, y in get_stan_transformation_index(
                config=config, transformation="adstock", channel_code=channel_code
            )
        ]:
            adstock_length = config.get("STAN_PARAMETERS")["predictor_parameters"][
                tp
            ]["transformations"]["adstock"]["length"]

            if tp in get_touchpoints_from_tags(config, tags=["full_adstock"], return_feature=True) and (not config.get("use_own_adstock_length")):
                adstock[tp] = compute_effective_adstock_length(
                    lambda_mean=adstock_means[tp],
                    adstock_length_min=adstock_length,
                )
            
            else:
                message = (
                    f"[ADSTOCK] Effective length used to build response curves "
                    f"{'for ' + tp if tp is not None else ''} = {adstock_length:.3f} months"
                    f"(mean lambda_adstock = {adstock_means[tp]:.3f})"
                )
                print(message)
                adstock[tp] = adstock_length
        else:
            adstock[tp] = 0
    return adstock

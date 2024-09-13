"""
Module centralizing all functions used to implement the feature engineering performed inside
the PyStan model or the feature engineering of the frequentist model (e.g. shape, adstock
transformations)
"""

import logging
import re
from typing import Dict

import numpy as np
import pandas as pd

from src.utils.names import (
    F_FEATURE,
    F_SAMPLE_ID,
    F_TOUCHPOINT,
    F_VOLUME_SO_FORECAST,
    F_YEAR_MONTH,
)
from src.utils.schemas.response_model.input.geo_master import GeoMasterSchema
from src.utils.schemas.response_model.input.product_master import ProductMasterSchema
from src.utils.settings_utils import (
    get_name_from_feature,
    get_stan_transformation_index,
    get_touchpoints_from_tags,
)
from src.utils.timing import timing

logger = logging.getLogger(__name__)

gs = GeoMasterSchema()
pms = ProductMasterSchema()


def _compute_adstock_variable(
    samples_adstock: np.array,
    samples_feature: pd.DataFrame,
    adstock_length: int,
    touchpoint: str = None,
) -> pd.DataFrame:
    """
    Ad-stock for that touchpoint & all volume samples

    Remark: Implementation must be in line with adstock formulation in STAN code
    """
    # Careful - Need to properly order rows in the data frame beforehand
    # Remark: creating a copy of df here (hence increasing memory usage)
    print(f"Computing adstock for {touchpoint} touchpoint.")
    samples_feature["adstock"] = samples_feature[F_SAMPLE_ID].map(samples_adstock)
    samples_feature["spend_adstock"] = 0
    for i in range(adstock_length + 1):
        # Spend from previous weeks multiplied by adstock coefficient (with
        # right power value)
        adstock_spend = (samples_feature["adstock"] ** i) * (
            samples_feature.groupby([pms.internal_product_code, gs.internal_geo_code, F_SAMPLE_ID])[
                F_FEATURE
            ]
            .shift(i)
            .fillna(0)
        )

        # Sum over all adstock indexes
        samples_feature["spend_adstock"] += adstock_spend

    return samples_feature["spend_adstock"]


def compute_effective_adstock_length(
    lambda_mean: float,
    adstock_length_min: int,
    adstock_length_max: int = 5,
    threshold: float = 0.01,
    is_logged: bool = True,
    touchpoint: str = None,
) -> int:
    """
    Function to compute the effective adstock length based on the value of the adstock decay factor

    Args:
        - lambda_mean (float): Mean of the distribution of the lambda_astock of the touchpoint
        - adstock_length_min (int): Min length to consider (usually length in Bayesian model)
        - adstock_length_max (int): Max length (half-year by default)
        - threshold (float): cut-off to define the effective adstock length (e.g. residual spend
            smaller than 1% or 5% of actual spend)
    """
    adstock_length = adstock_length_min
    while lambda_mean**adstock_length > threshold and adstock_length <= adstock_length_max:
        adstock_length += 1

    if is_logged:
        message = (
            f"[ADSTOCK] Effective length used to build response curves "
            f"{'for ' + touchpoint if touchpoint is not None else ''} = {adstock_length:.3f} months"
            f"(mean lambda_adstock = {lambda_mean:.3f})"
        )
        logger.info(message)

    return adstock_length


def compute_weibull_shape_variable(
    samples_feature: pd.DataFrame,
    threshold: float,
) -> pd.Series:
    """
    Weibull shape function in charge of taking saturation effects into account in the Bayesian model

    Args:
        - threshold: value below which the model consider that the impact is equivalent to a
        situation with no spend (i.e. the minimum spend needed to see an impact)
    """

    scale = samples_feature["scale"].values
    shape = samples_feature["shape"].values
    feature = samples_feature["feature"].values
    feature = np.where(feature < threshold, threshold, feature)
    feature = 1 - np.exp(-(((feature - threshold) / scale) ** shape))
    return pd.Series(feature, name="feature", index=samples_feature.index)


def get_formatted_samples_for_param(
    samples_df: pd.DataFrame,
    param_name: str,
    index_mapping: pd.DataFrame,
):
    """
    Method to get the formatted samples for parameters.
    """
    param_pattern = re.compile(rf"^{param_name}\[[0-9]*]$")
    return (
        samples_df[[c for c in samples_df.columns if param_pattern.match(c)]]
        .T.reset_index()
        .rename(columns={"index": "stan_index"})
        .assign(
            stan_index=lambda df: df.stan_index.str.findall(rf"{param_name}\[([0-9]*)]")
            .str[0]
            .astype(int)
        )
        .merge(
            index_mapping,
            on=["stan_index"],
            how="outer",
            validate="1:1",
        )
        .drop(columns=["stan_index"])
        .melt(
            id_vars=[c for c in index_mapping if c != "stan_index"],
            var_name=F_SAMPLE_ID,
            value_name=param_name,
        )
    )


def get_full_mapping_indexes(normalized_features_df: pd.DataFrame):
    """ "
    Method to get full mapping indexes
    """
    return (
        normalized_features_df.sort_values(
            [pms.internal_product_code, gs.internal_geo_code, F_YEAR_MONTH],
            ascending=True,
        )
        .drop_duplicates()[[pms.internal_product_code, gs.internal_geo_code, F_YEAR_MONTH]]
        .reset_index(drop=True)
        .reset_index()
        .rename(columns={"index": "stan_index"})
        .assign(stan_index=lambda df: df.stan_index + 1)
    )


@timing
def compute_transformed_model_feature(
    samples_df: pd.DataFrame,
    normalized_features_df: pd.DataFrame,
    touchpoint: str,
    transformations_feature: Dict,
    model_indexes,
    channel_code: str,
    config,
) -> pd.DataFrame:
    """
    Compute value of feature in linear regression model incl. adstock transformation

    Args:
        - samples_df: Table containing all samples of the transformation parameters and the base
        normalized feature before transformation (specified in column_feature)

        - transformation_feature: List of tuples specifying the successive transformation applied
        to the raw feature in the PyStan code to construct the feature used in the linear regression
        model; e.g. transformation_feature = [(<transfo_type>, <parameters>), ...]


    Returns:
        - Updated samples_df dataframe with a couple of additional columns (
        `spend_adstock`, `spend_shape`) for debugging purposes, and the `feature_regression`
        column with the value of feature after all feature engineering transformation(s). This value
        can be used as an input of the linear regression model.
    """
    response_level_tp = [pms.internal_product_code, gs.internal_geo_code, F_YEAR_MONTH]
    feature_indexed = normalized_features_df[response_level_tp + [touchpoint]].copy()

    samples_feature = feature_indexed.values
    samples_feature = np.tile(samples_feature, (len(samples_df), 1))
    samples_feature = pd.DataFrame(samples_feature, columns=feature_indexed.columns)
    samples_feature[F_SAMPLE_ID] = samples_feature.index.values // len(feature_indexed)
    samples_feature = (
        samples_feature.rename({touchpoint: F_FEATURE}, axis=1)
        .sort_values([F_SAMPLE_ID] + response_level_tp, ascending=True)
        .reset_index(drop=True)
    )
    samples_feature[F_FEATURE] = samples_feature[F_FEATURE].astype(float)
    samples_feature["initial_feature"] = samples_feature[F_FEATURE].copy()

    for step_type, step_params in transformations_feature.items():
        transformation_stan_index = {
            y: x for x, y in get_stan_transformation_index(config, step_type, channel_code)
        }.get(touchpoint)

        if step_type == "adstock":
            column_adstock_coef = f"lambda_adstock[{transformation_stan_index}]"
            adstock_length = step_params["length"]

            if get_name_from_feature(touchpoint) in get_touchpoints_from_tags(
                config, ["full_adstock"]
            ):
                adstock_length = compute_effective_adstock_length(
                    lambda_mean=samples_df[column_adstock_coef].mean(),
                    adstock_length_min=adstock_length,
                    touchpoint=touchpoint,
                )

            samples_feature["adstock_length"] = adstock_length
            samples_feature["spend_adstock"] = _compute_adstock_variable(
                samples_adstock=samples_df[column_adstock_coef],
                samples_feature=samples_feature,
                adstock_length=adstock_length,
                touchpoint=touchpoint,
            )
            samples_feature["feature"] = samples_feature["spend_adstock"].copy()

        elif step_type == "shape":
            samples_feature["scale"] = samples_feature[F_SAMPLE_ID].map(
                samples_df[f"scale_param[{transformation_stan_index}]"]
            )
            samples_feature["shape"] = samples_feature[F_SAMPLE_ID].map(
                samples_df[f"shape_param[{transformation_stan_index}]"]
            )
            samples_feature["threshold"] = step_params["threshold"]
            samples_feature["spend_shape"] = compute_weibull_shape_variable(
                samples_feature=samples_feature,
                threshold=samples_feature["threshold"],
            )

            samples_feature["feature"] = samples_feature["spend_shape"].copy()

        elif step_type == "log":
            samples_feature["feature"] = np.log(samples_feature["feature"] + 1)

    samples_feature = (
        samples_feature.assign(
            beta_touchpoint=(
                "beta_"
                + touchpoint
                + "["
                + (
                    samples_feature[pms.internal_product_code]
                    .map(model_indexes.brand_index)
                    .astype(str)
                )
                + "]"
            )
        )
        .merge(
            samples_df.reset_index()
            .rename(columns={"index": F_SAMPLE_ID})
            .melt(
                id_vars=[F_SAMPLE_ID],
                value_vars=[
                    beta_feature_col
                    for beta_feature_col in samples_df
                    if beta_feature_col.startswith(f"beta_{touchpoint}[")
                ],
                var_name="beta_touchpoint",
                value_name="beta",
            ),
            on=["beta_touchpoint", F_SAMPLE_ID],
            validate="m:1",
        )
        .merge(
            get_formatted_samples_for_param(
                samples_df=samples_df,
                param_name=F_VOLUME_SO_FORECAST,
                index_mapping=get_full_mapping_indexes(normalized_features_df),
            ),
            on=[
                pms.internal_product_code,
                gs.internal_geo_code,
                F_YEAR_MONTH,
                F_SAMPLE_ID,
            ],
            validate="1:1",
        )
        .drop(columns=["beta_touchpoint"])
    )

    samples_feature["incremental_so_uplift"] = (
        np.exp(samples_feature["feature"]) ** samples_feature["beta"]
    )

    samples_feature[F_VOLUME_SO_FORECAST] = np.exp(samples_feature[F_VOLUME_SO_FORECAST]) - 1e-6
    samples_feature[F_TOUCHPOINT] = touchpoint
    return samples_feature

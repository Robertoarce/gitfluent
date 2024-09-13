"""
Module to normalize and denormalize features
"""
import logging
from copy import copy
from dataclasses import dataclass
from typing import Dict, List, Tuple

import numpy as np
import pandas as pd

from src.pipeline.feature_engineering.utils import get_feature_from_name
from src.utils.names import F_BRAND, F_FEATURE, F_YEAR_MONTH
from src.utils.settings_utils import get_feature_param_value


@dataclass(frozen=True)
class TransformationFeature:
    """Object to handle transformation / inverse-transformation of a single feature"""

    steps: List
    parameters: Dict

    @property
    def normalize(self):
        """
        Returns the list of steps involved in normalizing a feature/s
        """
        return [(step, self.parameters.get(step, [])) for step in self.steps]

    @property
    def denormalize(self):
        """
        Returns the list of steps involved in normalizing a feature/s
        """
        return [(step, self.parameters.get(step, [])) for step in self.steps[::-1]]


@dataclass(frozen=True)
class TransformationParams:
    """Object centralizing information to transform all features"""

    transformation_log: Dict  # constants used to normalized features
    channel_code: str

    def get_feature_params(self, feature_name: str, config) -> TransformationFeature:
        """
        Genreate feature param from model_config.yaml file
        """
        return TransformationFeature(
            steps=list(
                get_feature_param_value(config, feature_name, "normalization", self.channel_code)
            ),
            parameters={
                k[1]: v for k, v in self.transformation_log.items() if k[0] == feature_name
            },
        )


def normalize_feature(
    feature_df: pd.DataFrame,
    normalization_params_feature: TransformationFeature,
    column_feature: str = F_FEATURE,
    key_cols=F_BRAND,
) -> pd.Series:
    """
    Scaling factor is brand and / or feature specific
    This function normalizes / transforms a single feature.

    Args:
        - feature_df: data frame with the feature value and the corresponding brand
        - feature_raw: name of the column with the raw / de-normalized feature values
    """
    normalized_feature, brands = (
        feature_df[column_feature].copy(),
        feature_df[key_cols],
    )
    for step, params in normalization_params_feature.normalize:
        if step == "log":
            normalized_feature = np.log(normalized_feature + 1)

        elif step == "log_epsilon":
            normalized_feature = np.log(normalized_feature + 1e-6)

        elif step == "neg_log":
            normalized_feature = np.log(1 - normalized_feature)

        elif step in ["max", "div_max_minus_mean", "std"]:
            try:
                scaling_factor = brands.apply(lambda x: params[(x["brand_name"])], axis=1)
            except TypeError:
                scaling_factor = brands.map(params)
            normalized_feature = normalized_feature / scaling_factor

        elif step in ["minus_mean", "minus_min", "minus_max", "minus_min_capped"]:
            try:
                scaling_factor = brands.apply(lambda x: params[(x["brand_name"])], axis=1)
            except TypeError:
                scaling_factor = brands.map(params)

            normalized_feature = normalized_feature - scaling_factor

        elif step in ["max_across_brands", "custom_normalization"]:
            scaling_factor = params
            normalized_feature = normalized_feature / scaling_factor

        else:
            raise NotImplementedError(f"Unknown normalization step ... {step}")

    return normalized_feature


def denormalize_feature(
    feature_df: pd.DataFrame,
    normalization_params_feature: TransformationFeature,
    column_feature: str = F_FEATURE,
) -> pd.Series:
    """
    De-normalize / inverse data transformation from pre-processing
    """

    denormalized_feature, brands = (
        feature_df[column_feature].copy(),
        feature_df["brand_name"],
    )

    for step, params in normalization_params_feature.denormalize:
        if step == "log":
            denormalized_feature = np.exp(denormalized_feature) - 1

        elif step == "log_epsilon":
            denormalized_feature = np.exp(denormalized_feature) - 1e-6

        elif step == "neg_log":
            denormalized_feature = 1 - np.exp(denormalized_feature)

        elif step in ["max_across_brands", "custom_normalization"]:
            scaling_factor = params
            denormalized_feature = denormalized_feature * scaling_factor

        elif step in ["max", "std", "div_max_minus_mean"]:
            try:
                scaling_factor = brands.apply(
                    lambda x: params[(x["brand_name", F_YEAR_MONTH])],
                    axis=1,
                )
            except TypeError:
                scaling_factor = brands.map(params)
            denormalized_feature = denormalized_feature * scaling_factor

        elif step in ["minus_mean", "minus_min", "minus_max", "minus_min_capped"]:
            try:
                scaling_factor = brands.apply(
                    lambda x: params[(x["brand_name", F_YEAR_MONTH])],
                    axis=1,
                )
            except TypeError:
                scaling_factor = brands.map(params)
            denormalized_feature = denormalized_feature + scaling_factor

        else:
            raise NotImplementedError(f"Unknown normalization step ... {step}")

    return denormalized_feature


def model_inputs_dict(config):
    """
    Provides model input dictionary from the model config yaml file
    """
    output = {}
    for channel_code, value in config.get("STAN_PARAMETERS")["channels"].items():
        buffer_dict = {
            k: v
            for k, v in config.get("STAN_PARAMETERS")["predictor_parameters"].items()
            if channel_code in v.get("channel", [channel_code])
        }
        buffer_dict.update({config.get("TARGET_VARIABLE"): value})
        output[channel_code] = buffer_dict
    return output


def normalize_raw_data(
    config,
    transformed_features: pd.DataFrame,
    channel_code: str,
) -> Tuple[pd.DataFrame, TransformationParams]:
    """
    Normalize pre-processed features / signals using the strategies specified by developers

    Args:
        - raw_features_df: Features table
        - normalization_steps: ordered sequence of transformations to apply for each feature
        - normalization_custom: custom normalization values for specific touchpoints (e.g.
        saturation of media touchpoints).
    """
    # Reset index
    normalized_features = transformed_features.copy()
    transformation_log = {}

    # Creation and population of dict on which to iterate

    for predictor, values in model_inputs_dict(config)[channel_code].items():
        preprocessing_dict = values["normalization"]
        feature = get_feature_from_name(config, predictor)
        normalization_level = "brand_name"  # "internal_product_code"

        for step, custom_value in preprocessing_dict.items():
            if step == "log":
                normalized_features[feature] = np.log(normalized_features[feature] + 1)

            elif step == "log_epsilon":
                normalized_features[feature] = np.log(normalized_features[feature] + 1e-6)

            elif step == "neg_log":
                normalized_features[feature] = np.log(1 - normalized_features[feature])

            elif step == "max":
                # Assumption: When normalizing, whenever there is no spend on a brand (max = 0),
                # then transformation_log forces it to be equal at 1
                group = normalized_features.groupby(by=normalization_level)[feature]
                coef_to_apply_per_brand = group.max().replace(0, 1).to_dict()
                transformation_log[(feature, step)] = coef_to_apply_per_brand
                scaling_factor = normalized_features.set_index(normalization_level).index.map(
                    coef_to_apply_per_brand
                )
                normalized_features[feature] = normalized_features[feature] / scaling_factor

            elif step == "max_across_brands":
                coef_to_apply = normalized_features[feature].max()
                if coef_to_apply == 0:
                    coef_to_apply = 1  # If no value, divide 0 by 1
                transformation_log[(feature, step)] = coef_to_apply
                normalized_features[feature] = normalized_features[feature] / coef_to_apply

            elif step == "div_max_minus_mean":
                group = normalized_features.groupby(by=normalization_level)[feature]
                mean = group.mean().replace(0, 1).to_dict()
                max = group.max().replace(0, 1).to_dict()
                coef_to_apply_per_brand = {brand: max[brand] - mean[brand] for brand in mean.keys()}
                transformation_log[(feature, step)] = coef_to_apply_per_brand
                scaling_factor = normalized_features[normalization_level].map(
                    coef_to_apply_per_brand
                )
                normalized_features[feature] = normalized_features[feature] / scaling_factor
                normalized_features[feature] = (
                    normalized_features[feature] + 1
                )  # TODO: Dip added this line

            elif step == "minus_mean":
                group = normalized_features.groupby(by=normalization_level)[feature]
                coef_to_apply_per_brand = group.mean().to_dict()
                transformation_log[(feature, step)] = coef_to_apply_per_brand
                normalized_features[feature] = group.transform(lambda x: x - x.mean())

            elif step == "std":
                # Assumption: When normalizing, if no spend for a given category (max = 0),
                # then transformation_log put equal at 1
                group = normalized_features.groupby(by=normalization_level)[feature]
                coef_to_apply_per_brand = group.std().replace(0, 1).to_dict()
                transformation_log[(feature, "std")] = coef_to_apply_per_brand
                normalized_features[feature] = group.transform(
                    lambda x: x / x.std() if x.std() != 0 else x
                )

            elif step == "minus_min":  # Subtract minimum value for the brand
                group = normalized_features.groupby(by=normalization_level)[feature]
                coef_to_apply_per_brand = group.min().to_dict()
                transformation_log[(feature, step)] = coef_to_apply_per_brand
                normalized_features[feature] = group.transform(lambda x: x - x.min())

            elif (
                step == "minus_min_capped"
            ):  # Subtract minimum value for the brand only for non null values
                group_ft = normalized_features[normalized_features[feature] > 0].groupby(
                    by=normalization_level
                )[feature]
                group = normalized_features.groupby(by=normalization_level)[feature]
                coef_to_apply_per_brand = group_ft.min().to_dict()
                transformation_log[(feature, step)] = coef_to_apply_per_brand
                normalized_features[feature] = group.transform(lambda x: x - x[x > 0].min())
                normalized_features[feature] = normalized_features[feature].clip(0)

            elif step == "minus_max":  # Subtract minimum value for the brand
                group = normalized_features.groupby(by=normalization_level)[feature]
                coef_to_apply_per_brand = group.max().to_dict()
                transformation_log[(feature, step)] = coef_to_apply_per_brand
                normalized_features[feature] = group.transform(lambda x: x - x.max())

            elif step == "custom_normalization":
                try:
                    coef_to_apply = custom_value["saturation"]
                    transformation_log[(feature, step)] = coef_to_apply
                    normalized_features[feature] = normalized_features[feature] / coef_to_apply
                except KeyError as err:
                    logging.critical(f"No normalization parameter specified for feature {feature}")
                    raise err

            else:
                raise NotImplementedError(f"Step {step} not implemented")

    transformation_params = TransformationParams(transformation_log, channel_code)
    return normalized_features, transformation_params


def denormalize_value_array(
    norm_value: np.array, transformation_feature: TransformationFeature
) -> np.array:
    """
    It takes the array apply denormalization on them based on
    transformation feature detail saved during normalization
    """
    denormalized_feature = copy(norm_value)

    for step, params in transformation_feature.denormalize:
        if step == "log":
            denormalized_feature = np.exp(denormalized_feature) - 1

        elif step == "log_epsilon":
            denormalized_feature = np.exp(denormalized_feature) - 1e-6

        elif step in ["max", "std", "div_max_minus_mean"]:
            if step == "div_max_minus_mean":
                # TODO: Dip added this if block, remove it if not adding 1
                # manually
                denormalized_feature = denormalized_feature - 1
            n_brands = len(params)
            for i, value in enumerate(params.values()):
                denormalized_feature[:, i::n_brands] *= value

        elif step in ["minus_mean", "minus_min", "minus_max"]:
            n_brands = len(params)
            for i, value in enumerate(params.values()):
                denormalized_feature[:, i::n_brands] += value
        elif step == "custom_normalization":
            denormalized_feature = denormalized_feature * params
    return denormalized_feature

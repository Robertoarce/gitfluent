"""
Module preapres feature engineering dataframe
"""
import logging
from typing import Dict, List, Union

import pandas as pd
from box import Box

from src.pipeline.feature_engineering.channel_feature import ChannelFeature
from src.pipeline.feature_engineering.datamart_aggregator import DatamartAggregator
from src.pipeline.feature_engineering.feature_builder import FeatureBuilder
from src.pipeline.feature_engineering.utils import (
    add_brand_index_for_bayesian_model,
    add_missing_compulsory_features,
    apply_time_scope_filter,
    validate_features_table,
)
from src.utils.names import F_CHANNEL_CODE
from src.utils.normalization import normalize_raw_data
from src.utils.schemas.response_model.input import (
    GeoMasterSchema,
    ProductMasterSchema,
    TouchpointMasterSchema,
)

gs = GeoMasterSchema()
pms = ProductMasterSchema()
tms = TouchpointMasterSchema()

logger = logging.getLogger(__name__)

def model_inputs_dict(model_settings, channel_code):
    """
    Method to preapre model input dictionary
    """
    output = {}
    for channel_code, value in model_settings.get("STAN_PARAMETERS")["channels"].items():
        buffer_dict = {
            k: v
            for k, v in model_settings.get("STAN_PARAMETERS")["predictor_parameters"].items()
            if channel_code in v.get("channel", [channel_code])
        }
        buffer_dict.update({model_settings.get("TARGET_VARIABLE"): value})
        output[channel_code] = buffer_dict
    return output


def channel_max_response_level(model_settings, channel_code, internal) -> List[str]:
    """
    Returns the macimum response level for channel
    """
    if "granularity" in model_settings["STAN_PARAMETERS"]["channels"][channel_code]:
        for values in list(model_inputs_dict(model_settings, channel_code).values()):
            if "granularity" in values and not internal:
                return [
                    model_settings.RESPONSE_LEVEL_PRODUCT,
                    model_settings.RESPONSE_LEVEL_GEO,
                    model_settings.get("RESPONSE_LEVEL_TIME"),
                ]
            return [
                "brand_name",
                gs.internal_geo_code,
                model_settings.get("RESPONSE_LEVEL_TIME"),
            ]
    if not internal:
        return list(model_settings.RESPONSE_LEVEL)
    return model_settings.get("RESPONSE_LEVEL")


def maximum_response_level_internal(model_settings) -> Dict[str, List]:
    """
    Calculate the maximum response level for each channel in the given model settings.

    This function iterates through the specified channels in the model settings and computes
    the maximum response level for each channel.

    Args:
        model_settings (dict): A dictionary containing model configuration settings.

    Returns:
        Dict[str, List]: A dictionary where keys are channel codes, and values are lists
        containing the maximum response levels for each channel.
    """
    response_level = {}
    for channel_code in model_settings["STAN_PARAMETERS"]["channels"]:
        response_level[channel_code] = channel_max_response_level(
            model_settings, channel_code, True
        )
    return response_level


def _main_create_raw_features_table(
    model_settings, feature_builder: FeatureBuilder, channel_code
) -> pd.DataFrame:
    """
    Main function to create table containing all relevant raw features
    Returns:
        - features_df: Table with all relevant features

    Improvement ideas:
        - create object handling feature type (execution, conversion_type, etc.)
    """

    feature_builder.set_channel_code(channel_code)

    features_df = feature_builder.construct_features_table()

    # Filling missing values (ie no execution spend) by 0
    features_df = features_df.fillna(0)

    # Add brand index to features table
    # TODO: Commented. by Dip. self.index already adds brand,year_month as
    # index
    features_df = add_brand_index_for_bayesian_model(features_df=features_df)

    # Enforce right time scope (e.g. filtering out COVID period)
    features_df = enforce_time_scope(model_settings, features_df, channel_code)

    if gs.internal_geo_code not in maximum_response_level_internal(model_settings)[channel_code]:
        features_df[gs.internal_geo_code] = "national"

    validate_features_table(
        model_settings,
        features_df=features_df,
        response_level=maximum_response_level_internal(model_settings)[channel_code],
        channel_code=channel_code,
    )
    return features_df


def enforce_time_scope(model_settings, features_df, channel_code):
    """
    Apply time scope filtering to a DataFrame of features based on the given model settings.

    This function filters the features DataFrame `features_df` to include only data within
    the specified time scope for a particular channel. The time scope is determined by the
    `model_settings` and may vary by brand if specified in `BRAND_SPECIFIC_TIME_HORIZON`.

    Args:
        model_settings (dict): A dictionary containing model configuration settings.
        features_df (pd.DataFrame): The DataFrame containing the features to be filtered.
        channel_code (str): The channel code for which the time scope should be applied.

    Returns:
        pd.DataFrame: A filtered DataFrame containing features within the specified time scope
        for the given channel and brand (if applicable).
    """
    scoped_features_df = []
    # for product in features_df[pms.internal_product_code].unique():
    for brand in features_df[
        model_settings.get("RESPONSE_LEVEL_PRODUCT")
    ].unique():  # TODO: Dip - changed this line to filter products at brand level
        if (
            hasattr(model_settings, "BRAND_SPECIFIC_TIME_HORIZON")
            and brand in model_settings.BRAND_SPECIFIC_TIME_HORIZON
        ):
            scoped_features_df.append(
                apply_time_scope_filter(
                    features_df=features_df[
                        features_df[model_settings.get("RESPONSE_LEVEL_PRODUCT")]
                        == brand
                    ],
                    year_month_start=model_settings.BRAND_SPECIFIC_TIME_HORIZON[brand][0],
                    year_month_end=model_settings.BRAND_SPECIFIC_TIME_HORIZON[brand][1],
                )
            )
        else:
            scoped_features_df.append(
                apply_time_scope_filter(
                    features_df=features_df[
                        features_df[model_settings.get("RESPONSE_LEVEL_PRODUCT")]
                        == brand
                    ],
                    year_month_start=model_settings.get("MODEL_TIME_HORIZON_START"),
                    year_month_end=model_settings.get("MODEL_TIME_HORIZON_END"),
                )
            )
    features_df = (
        pd.concat(scoped_features_df, axis=0)
        .sort_values(maximum_response_level_internal(model_settings)[channel_code])
        .reset_index(drop=True)
    )
    return features_df


def prepare_data_for_response_model_target(
    raw_data: Box,
    feature_builder: FeatureBuilder,
    data_aggregator: DatamartAggregator,
    config,
):
    """
    Function handling all feature engineering operations to prepare data
    for the bayesian response model using the data_manager_output here
    to print diagnostics plots in the run folder
    """

    feature_builder.add_data(
        raw_data=raw_data,
        data_aggregator=data_aggregator,
        config=config,
    )

    touchpoints_spend_df = feature_builder.extract_touchpoints_spend()

    all_channel_features = {}
    for channel_code in config["STAN_PARAMETERS"]["channels"]:
        # Aggregate data at the same granularity in a common dataframe
        features_df = _main_create_raw_features_table(
            config,
            feature_builder=feature_builder,
            channel_code=channel_code,
        )

        # Normalize data
        normalized_features_df, transformation_params = normalize_raw_data(
            config,
            transformed_features=features_df,
            channel_code=channel_code,
        )

        normalized_features_df = add_missing_compulsory_features(
            config, normalized_features_df=normalized_features_df
        )

        features_df[F_CHANNEL_CODE] = channel_code
        normalized_features_df[F_CHANNEL_CODE] = channel_code

        all_channel_features[channel_code] = ChannelFeature(
            features_df=features_df,
            normalized_features_df=normalized_features_df,
            transformation_params=transformation_params,
            channel_code=channel_code,
            config=config,
        )

    return all_channel_features, touchpoints_spend_df


def split_trade_media(
    touchpoint_facts_df: pd.DataFrame, touchpoint_master_df: pd.DataFrame
) -> Dict[str, Union[pd.DataFrame, pd.Series]]:
    """
    Split a DataFrame of touchpoint facts into media and trade marketing executions.

    This function takes a DataFrame of touchpoint facts (`touchpoint_facts_df`) and
    a DataFrame of touchpoint master data (`touchpoint_master_df`). It then merges
    the facts data with the master data based on the internal channel code and
    splits the merged DataFrame into two separate DataFrames: one for media executions
    and another for trade marketing executions.

    Args:
        touchpoint_facts_df (pd.DataFrame): The DataFrame containing touchpoint facts data.
        touchpoint_master_df (pd.DataFrame): The DataFrame containing touchpoint master data.

    Returns:
        dict: A dictionary containing two entries:
            - "media_execution": A DataFrame containing media execution data.
            - "trade_marketing_execution": A DataFrame containing trade marketing execution data.
    """
    keep_columns = touchpoint_facts_df.columns

    touchpoint_facts_df = touchpoint_facts_df.merge(
        touchpoint_master_df, on=tms.internal_channel_code, validate="m:1"
    )

    media_df = touchpoint_facts_df[touchpoint_facts_df.touchpoint_lvl0 == "media"].drop(
        columns=[tms.touchpoint_lvl0]
    )[keep_columns]

    trade_df = touchpoint_facts_df[touchpoint_facts_df.touchpoint_lvl0 == "trade"].drop(
        columns=[tms.touchpoint_lvl0]
    )[keep_columns]

    return {"media_execution": media_df, "trade_marketing_execution": trade_df}

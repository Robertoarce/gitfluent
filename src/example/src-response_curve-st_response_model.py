"""
This is a calss to initiate and train the Bayseian model
Future job: TransformationParams
"""
import logging
import os
from collections import defaultdict  # for creating model input
from typing import Any, Dict, Tuple

import cmdstanpy
import numpy as np
import pandas as pd

from src.pipeline.feature_engineering.utils import seasonality_features
from src.pipeline.response_model.utils import transformed_features
from src.response_curve.mapping_indexes import MappingIndexes
from src.utils.datetime import get_months_delta
from src.utils.names import F_BRAND_INDEX, F_REGION_INDEX, F_TIME_INDEX, F_YEAR_MONTH
from src.utils.settings_utils import (
    _get_index_mapping,
    get_stan_transformation_index,
)
from src.utils.timing import timing

logger = logging.getLogger(__name__)


class BayesianResponseModel:
    """
    Class to preapre data input for model, train and provide model params to post processing class
    """

    data = None
    fit = None
    model = None

    __indexes = None

    def __init__(
        self,
        stan_model_path: str,
        stan_model_parameters: Tuple[Tuple[str, Any]],
        normalized_features_df: pd.DataFrame,
        transformation_params: dict,  # TransformationParams,
        channel_code: str,
        config,
    ):
        self.stan_model_path = stan_model_path
        self.stan_model_parameters = stan_model_parameters
        self.normalized_features_df = normalized_features_df
        self.transformation_params = transformation_params
        self.test_duration = config.get("TEST_DURATION")
        self.channel_code = channel_code
        self.config = config

        # Brand index in Stan model
        (
            time_index_dict,
            brand_index_df,
            region_index_df,
        ) = self._get_stan_index_mapping_tables(self.normalized_features_df, self.channel_code)

        self.__indexes = MappingIndexes(
            time_index_dict=time_index_dict,
            brand_index_df=brand_index_df,
            region_index_df=region_index_df,
            adstock_touchpoint_index_df=_get_index_mapping(
                get_stan_transformation_index(self.config, "adstock", channel_code)
            ),
            shape_touchpoint_index_df=_get_index_mapping(
                get_stan_transformation_index(self.config, "shape", channel_code)
            ),
        )

    @property
    def indexes(self):
        """
        Return Model indexes
        """
        return self.__indexes

    def _create_stan_input(self) -> Dict:
        """
        :param normalized_features_df:
        :param target:
        :return:
        """
        data = {}
        stan_input_df = (
            self.normalized_features_df.sort_values(
                [
                    "brand_name",
                    "internal_geo_code",
                    "year_month",
                ]  # internal_product_code
            )
            .reset_index(drop=True)
            .copy()
        )
        stan_input_df = (
            stan_input_df.groupby(
                ["brand_name", "internal_geo_code"],
                as_index=False,  # internal_product_code
            )
            .apply(lambda x: x.iloc[: -self.test_duration] if self.test_duration > 0 else x)
            .reset_index(drop=True)
        )

        # DOUBLE-CHECK <brand_time_horizon>: reason to add 1? test_duration
        # meaning?
        data["T"] = self.brand_time_horizon

        data["I"] = self.brand_region_stan_index

        data["N"] = data["I"][-1][-1][-1]

        # internal_product_code
        data["B"] = stan_input_df["brand_name"].nunique()

        data["R"] = stan_input_df["internal_geo_code"].nunique()

        # COMMENTS: The <transformation_length> function location is changed.
        if transformation_length(self.config, "adstock", self.channel_code) > 0:
            data["M"] = transformation_length(self.config, "adstock", self.channel_code)
            data.update(get_transformation_params(self.config, "adstock", self.channel_code))
        else:
            data["M"] = 0

        data["S"] = 0
        if transformation_length(self.config, "shape", self.channel_code) > 0:
            data["S"] = transformation_length(self.config, "shape", self.channel_code)
            data.update(get_transformation_params(self.config, "shape", self.channel_code))
        else:
            data["S"] = 0

        # Initialize features dictionary with target variable
        new_features_dict = {self.config.get("TARGET_VARIABLE"): self.config.get("TARGET_VARIABLE")}

        # Add variables
        # Comment: update channel_code by checking the config file
        channel_code = list(self.config.get("STAN_PARAMETERS")["channels"].keys())[0]
        new_features_dict.update({i: i for i in predictor_features_name(self.config)[channel_code]})

        if bool(seasonality_features(self.config)):
            new_features_dict.update(
                {
                    event: event
                    # for event in
                    # model_settings.seasonality_features[self.channel_code] #
                    # reference: A&P
                    for event in seasonality_features(self.config)[channel_code]
                    if event != "seasonality"
                }
            )
        if (
            bool(seasonality_features(self.config))
            and "seasonality" in seasonality_features(self.config)[channel_code]
        ):
            data["seasonality"] = stan_input_df[self.config.get("SEASONALITY_MTH")].values

        for feature_name, corresponding_base_feature in new_features_dict.items():
            data[feature_name] = stan_input_df[corresponding_base_feature].values

        return data

    @timing
    def create_data_input(self) -> None:
        """
        Generate dictionary data input where key of dictionary
        is a dataframe name and value is a dataframe
        """
        self.data = self._create_stan_input()
        for k, v in self.data.items():
            if isinstance(v, pd.DataFrame):
                self.data[k] = v.values

    @timing
    def compile_model(self):
        """
        Compliles the model
        """
        self.model = cmdstanpy.CmdStanModel(
            stan_file=os.getcwd() + self.stan_model_path,
            stanc_options= {"auto-format": True},
            compile="force"
        )
        self.stan_code = self.model.code()


    @timing
    def train_model(self):
        """
        Model samplping process
        """
        print(
            "DEBUG st_resp_model.py: model.sample",
            self.data.keys(),
            self.stan_model_parameters,
        )
        # Use metadata to train the model
        self.fit = self.model.sample(
            data=self.data, show_progress=True, **self.stan_model_parameters
        )

    @property
    def brand_time_horizon(self):
        """Returns brand time horizon list
        """
        output = []
        for brand in self.normalized_features_df["brand_name"].unique():
            if self.config.get("BRAND_SPECIFIC_TIME_HORIZON") is not None:
                output.append(
                    get_months_delta(
                        self.config.get("BRAND_SPECIFIC_TIME_HORIZON")[brand][0],
                        self.config.get("BRAND_SPECIFIC_TIME_HORIZON")[brand][1],
                    )
                    + 1
                    - self.test_duration
                )
            else:
                output.append(
                    get_months_delta(
                        self.config.get("MODEL_TIME_HORIZON_START"),
                        self.config.get("MODEL_TIME_HORIZON_END"),
                    )
                    - self.test_duration
                )
        return output

    @property
    def brand_region_stan_index(self):
        """Returns brand region stan index

        Returns:
            [type] -- [description]
        """
        idx = (
            self.normalized_features_df[
                ["brand_name", "internal_geo_code"]
            ]  # internal_product_code
            .drop_duplicates()
            .reset_index(drop=True)
            .copy()
        )
        idx["duration"] = idx["brand_name"].apply(  # internal_product_code
            lambda x: self.brand_time_horizon[self.indexes.brand_index[x] - 1]
        )
        idx["stan_end_idx"] = idx["duration"].cumsum()
        idx["stan_start_idx"] = idx.stan_end_idx - idx.duration + 1
        output = np.zeros(
            (
                self.normalized_features_df["brand_name"].nunique(),  # internal_product_code
                self.normalized_features_df["internal_geo_code"].nunique(),
                2,
            )
        )
        output[:, :, 0] = idx.pivot(
            values="stan_start_idx",
            columns="internal_geo_code",
            index="brand_name",  # internal_product_code
        ).values
        output[:, :, 1] = idx.pivot(
            values="stan_end_idx",
            columns="internal_geo_code",
            index="brand_name",  # internal_product_code
        ).values
        output = output.astype(int)
        return output

    @staticmethod
    def _get_stan_index_mapping_tables(
        normalized_features_df: pd.DataFrame,
        channel_code: str,
    ) -> Tuple[Dict, pd.DataFrame, pd.DataFrame]:
        """
        Mapping between the brand and time indexes
        inside the Stan model & the actual business values
        """
        print(channel_code)
        # Time index in Stan model
        time_index_dict = {}
        time_index_df = (
            normalized_features_df[
                ["brand_name", F_YEAR_MONTH]
            ].sort_values(
                ["brand_name", F_YEAR_MONTH]
            )
            .drop_duplicates(["brand_name", F_YEAR_MONTH])
        )
        for brand in time_index_df["brand_name"].unique():
            time_index_dict[brand] = (
                time_index_df[time_index_df["brand_name"] == brand]
                .reset_index(drop=True)
                .reset_index()
                .rename({"index": F_TIME_INDEX}, axis=1)
            )

        # Brand index in Stan model
        brand_index_df = (
            normalized_features_df[[F_BRAND_INDEX, "brand_name"]]
            .drop_duplicates()
            .sort_values([F_BRAND_INDEX])
            .reset_index(drop=True)
        )

        region_index_df = (
            normalized_features_df[["internal_geo_code"]]
            .drop_duplicates()
            .sort_values(["internal_geo_code"])
            .reset_index(drop=True)
        )

        region_index_df.index = region_index_df.index.rename(F_REGION_INDEX)
        region_index_df = region_index_df.reset_index()
        region_index_df[F_REGION_INDEX] += 1

        return time_index_dict, brand_index_df, region_index_df


def get_transformation_params(config, transformation, channel_code):
    """
    Returns list of ordered values of a parameter for a transformation
    """
    output = defaultdict(list)
    for touchpoint, value in transformed_features(config)[channel_code].items():
        print(touchpoint)
        if transformation in value:
            for key, value in value[transformation].items():
                output[f"{transformation}_{key}"] += [value]
    return output


def transformation_length(config, transformation, channel_code):
    """Returns the number of transformed variables for a given transformation"""
    return sum(
        [
            transformation in value.get("transformations", [])
            for value in config.get("STAN_PARAMETERS")["predictor_parameters"].values()
            if channel_code in value.get("channel", [channel_code])
        ]
    )


def _is_channel(value_dict, channel_code):
    """Detects if the value dict contains a channel

    Arguments:
        value_dict {[type]} -- [description]
        channel_code {[type]} -- [description]

    Returns:
        [type] -- [description]
    """
    return channel_code in value_dict.get("channel", [channel_code])


def get_feature_from_name(config, predictor):
    """Return feature from predictor name

    Arguments:
        config {[type]} -- [description]
        predictor {[type]} -- [description]

    Raises:
        ValueError: [description]

    Returns:
        [type] -- [description]
    """
    # TODO : abstract spend vs exec logic
    for param_dicts in config.get("STAN_PARAMETERS").values():
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
    """Returns dictionary with key as channel code and value as stan paramters from config file

    Arguments:
        config {[type]} -- [description]

    Returns:
        [type] -- [description]
    """
    return {
        channel_code: {
            get_feature_from_name(config, k): v
            for k, v in config.get("STAN_PARAMETERS")["predictor_parameters"].items()
            if _is_channel(v, channel_code)
        }
        for channel_code in config.get("STAN_PARAMETERS")["channels"]
    }

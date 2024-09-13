"""
Created By  : MMX DS Team (Jeeyoung, DipKumar, Youssef)
Created Date: 16/12/2022
Description : Features Engineering component
"""
import itertools
import sys
from copy import copy
from typing import Dict, List

import pandas as pd
from box import Box

from src.pipeline.feature_engineering.datamart_aggregator import DatamartAggregator
from src.pipeline.feature_engineering.execution_media import (
    construct_media_execution_features,
)
from src.pipeline.feature_engineering.price import (
    construct_basic_price_discount_feature,
    response_level_for_touchpoint,
)
from src.pipeline.feature_engineering.seasonality import (
    add_control_variables,
    construct_seasonality_and_event_features,
)
from src.utils.data_frames import reduce_data_frames
from src.utils.names import (
    F_PERIOD_START,
    F_PRICE_ASP,
    F_VALUE,
    F_VOLUME,
)
from src.utils.schemas.response_model.input.sell_out_own import SellOutOwnSchema
from src.utils.schemas.response_model.input.touchpoint_master import (
    TouchpointMasterSchema,
)
from src.utils.schemas.response_model.output.response_curve import ResponseCurveSchema
from src.utils.settings_utils import get_touchpoints_from_tags

rcs = ResponseCurveSchema()
tms = TouchpointMasterSchema()
soos = SellOutOwnSchema()


class FeatureBuilder:

    """
    Main object responsible of transforming raw datas into a features
    dataframe that can be fed into the Response Curve model.
    This object can be inherited in client side code, to customize
    the feature engineering steps
    """

    def __init__(self):
        self.sell_out_df = None
        self.sell_out_competitors_df = None
        self.sell_out_distribution_df = None
        self.media_execution_df = None
        self.trade_marketing_execution_df = None
        self.external_facts_df = None
        self.product_master_df = None
        self.touchpoints_spend_df = None
        self.geo_master_df = None
        self.touchpoint_master_df = None

        self.channel_code = -1
        self.data_aggregator = None
        # self.dico_common =  load_config(common=True)
        # self.dico_fe = load_config(pipeline='feature_engineering')

    def add_data(
        self,
        raw_data: Box,
        data_aggregator: DatamartAggregator,
        config: Box,
    ):
        """
        Add the referential data to the raw data by joining with the master tables and assign
        the resulting dataframe as class attribute.

        :param raw_data: Box of Pandas dataframes
        :type raw_data: Box
        :param data_aggregator: DataAggregator object that applies standard transformations to
        the raw data
        :type data_aggregator: DatatamartAggregator
        :param config: `config` object created from the yml configuration files
        :type config: Config
        """
        self.data_aggregator = data_aggregator
        self.config = config

        self.sell_out_df = self.data_aggregator.get_master_attributes(raw_data.get("sell_out_own"))

        # TODO: We don't have sell out data
        # self.sell_out_competitors_df = self.data_aggregator.get_master_attributes(
        #     raw_data.sell_out_competitors
        # )

        # TODO: We don't have distribution data
        # self.sell_out_distribution_df = self.data_aggregator.get_master_attributes(
        #     raw_data.distribution_own
        # )

        # TODO: We don't have media execution data
        self.media_execution_df = self.data_aggregator.get_master_attributes(
            self._map_raw_touchpoint_to_response_level(raw_data.get("media_execution"))
        )

        # We don't have a trade marketing execution data
        # self.trade_marketing_execution_df = self.data_aggregator.get_master_attributes(
        #     self._map_raw_touchpoint_to_response_level(
        #         raw_data.trade_marketing_execution
        #     )
        # )

        # TODO: We don't have external facts data
        # self.external_facts_df = self.data_aggregator.get_master_attributes(
        #     raw_data.external_facts
        # )

        self.product_master_df = raw_data.get("product_master")
        self.geo_master_df = raw_data.get("geo_master")
        self.touchpoints_spend_df = raw_data.get("touchpoint_facts")
        self.touchpoint_master_df = raw_data.get("touchpoint_master")
        if "control_variables" in raw_data:
            self.control_variables = self.data_aggregator.get_master_attributes(
                raw_data.get("control_variables")
            )
        else:
            self.control_variables = pd.DataFrame()

    # TODO: Can't run this method (it creates touchpoint spend) as we do not have
    #  media execution df or trade marketing execution
    # def extract_touchpoints_spend(self) -> pd.DataFrame:
    #     """
    #     Concatenates media and trade touchpoints and filter on the spends

    #     :return: A dataFrame containing touchpoint spends and the dimension
    #     attributes
    #     :rtype: pd.DataFrame
    #     """
    #     media_df = self.data_aggregator.aggregate(
    #         self.media_execution_df.query("metric == 'spend_value'")
    #     )
    #     trade_marketing_df = self.data_aggregator.aggregate(
    #         self.trade_marketing_execution_df.query("metric == 'spend_value'")
    #     )

    #     touchpoints_spend_df = pd.concat([media_df, trade_marketing_df], axis=0)
    # return self.data_aggregator.get_master_attributes(touchpoints_spend_df)

    def model_inputs_dict(self, channel_code):
        """
        Featches model configuration from the config file
        """
        output = {}
        for channel_code, value in self.config.get("STAN_PARAMETERS")["channels"].items():
            buffer_dict = {
                k: v
                for k, v in self.config.get("STAN_PARAMETERS")["predictor_parameters"].items()
                if self._is_channel(v, channel_code)
            }
            self.TARGET_VARIABLE = self.config.get(F_VOLUME)
            buffer_dict.update({self.TARGET_VARIABLE: value})
            output[channel_code] = buffer_dict
        return output

    def _map_raw_touchpoint_to_response_level(self, df: pd.DataFrame):
        """
        Aggregates touchpoints into response level touchpoints, based on
        the master data touchpoints master (different table from
        datamarts's touchpoint master)
        """
        assert tms.internal_channel_code in df.columns, "df must have touchpoint dimension"

        touchpoint_mapping = self.data_aggregator.response_touchpoint_mapping

        df[rcs.response_touchpoint] = df[tms.internal_channel_code].map(touchpoint_mapping)

        na_touchpoints = (
            df[df[rcs.response_touchpoint].isna()][tms.internal_channel_code].unique().tolist()
        )
        self.data_aggregator.fill_touchpoint_mapping(na_touchpoints)

        df[rcs.response_touchpoint] = df[rcs.response_touchpoint].fillna(
            df[tms.internal_channel_code].apply(lambda x: x.split("-")[-1])
        )

        df = df.drop(columns=[tms.internal_channel_code])

        return df

    def extract_touchpoints_spend(self) -> pd.DataFrame:
        """
        Concatenates media and trade touchpoints and filter on the spends

        :return: A dataFrame containing touchpoint spends and the dimension attributes
        :rtype: pd.DataFrame
        """
        media_df = self.data_aggregator.aggregate(
            self.media_execution_df.query("metric == 'spend_value'")
        )
        # trade_marketing_df = self.data_aggregator.aggregate(
        #     self.trade_marketing_execution_df.query("metric == 'spend_value'")
        # )

        # touchpoints_spend_df = pd.concat([media_df, trade_marketing_df], axis=0)
        # TODO: Added by Dip, since we don't have trade marketing, adding only
        # media df to touchpoint spend df.
        touchpoints_spend_df = media_df
        return self.data_aggregator.get_master_attributes(touchpoints_spend_df)

    def channel_max_response_level(self, channel_code, internal) -> List[str]:
        """
        Determine maximum response level for a channel
        """
        if "granularity" in self.config.get("STAN_PARAMETERS")["channels"][channel_code]:
            for values in list(self.model_inputs_dict(channel_code).values()):
                if "granularity" in values and not internal:
                    return [
                        "brand_name",
                        self.config.RESPONSE_LEVEL_GEO,
                        self.config.RESPONSE_LEVEL_TIME,
                    ]
                return [
                    self.config.get("RESPONSE_LEVEL_PRODUCT"),
                    "internal_geo_code",
                    self.config.get("RESPONSE_LEVEL_TIME"),
                ]
        if not internal:
            return list(self.config.get("RESPONSE_LEVEL"))
        return ["brand_name", self.config.get("RESPONSE_LEVEL_TIME")]

    def maximum_response_level(self) -> Dict[str, List]:
        """
        Fetches maximum response level from config
        """
        response_level = {}
        for channel_code in self.config.get("STAN_PARAMETERS")["channels"]:
            response_level[channel_code] = self.channel_max_response_level(channel_code, False)
        return response_level

    @property
    def index_df(self) -> pd.DataFrame:
        """
        Creates the unique index (granularity) expected by the Stan model

        :return: A dataFrame composed of the 3 dimension columns used by the Stan model
        internal_product_code, internal_geo_code, year_week
        :rtype: pd.DataFrame
        """
        response_values = []
        ref_level = self.maximum_response_level()

        sell_out_channel_df = self.sell_out_df.copy()
        sell_out_channel_df = sell_out_channel_df[
            sell_out_channel_df.channel_code == self.channel_code
        ].reset_index()
        result = sell_out_channel_df.groupby(["internal_geo_code"])["value"].sum().reset_index()
        geo_codes_with_zero_values = (
            result[result["value"] == 0]["internal_geo_code"].unique().tolist()
        )
        sell_out_channel_df = sell_out_channel_df[
            ~sell_out_channel_df.internal_geo_code.isin(geo_codes_with_zero_values)
        ]

        index_source = self.data_aggregator.aggregate(sell_out_channel_df).rename(
            columns={soos.period_start: self.data_aggregator._config.get("RESPONSE_LEVEL_TIME")}
        )

        for col in ref_level[self.channel_code]:
            response_values.append(index_source[col].unique())

        index_df = pd.DataFrame(
            data=itertools.product(*response_values),
            columns=ref_level[self.channel_code],
        )

        index_df[self.config.get("RESPONSE_LEVEL_TIME")] = (
            pd.to_datetime(index_df[self.config.get("RESPONSE_LEVEL_TIME")])
            .dt.strftime("%Y%m").astype(int)
        )

        index_df = index_df.drop_duplicates()
        return index_df

    @property
    def feature_seasonality_df(self) -> pd.DataFrame:
        """
        Method to add seasonality features in feature df
        """

        filtered_events = self.filter_touchpoints_on_channel(
            list(self.config["STAN_PARAMETERS"]["seasonality_parameters"]),
            self.channel_code,
        )
        seasonality_channel_features = {
            event: self.config["STAN_PARAMETERS"]["seasonality_parameters"][event]
            for event in filtered_events
        }

        if (
            self.config.get("use_control_variables_using_query")
            and not self.control_variables.empty
        ):
            database_control_variables = self.control_variables[
                self.control_variables.channel_code == self.channel_code
            ]
        else:
            database_control_variables = None

        if self.config.get("use_control_variables_using_config"):
            self.config.get("control_variables")

        seasonality_df = construct_seasonality_and_event_features(
            index_df=self.index_df,
            seasonality_features=seasonality_channel_features,
            control_variables=self.config.get("control_variables"),
            database_control_variables=database_control_variables,
        )
        return seasonality_df

    @property
    def additional_features(self) -> List[pd.DataFrame]:
        """
        Creates additional features that are not declared in this class.
        There are two ways to customize the feature engineering in
        the response model, either override an existing feature creation
        method or add totally new features in this method.

        :return: A list of feature dataframes
        :rtype: List[pd.DataFrame]
        """
        return []

    def set_channel_code(self, channel_code):
        """
        sets the channel code in an instance variable
        """
        self.channel_code = channel_code

    def check_channel_codes_in_data(self):
        """Assert prensence of the desired channel code in main dataframes"""
        for k, df in {
            "sell_out": self.sell_out_df,
        }.items():
            if not df.empty:
                try:
                    assert (
                        self.channel_code
                        in df.channel_code.unique()
                    )
                except AssertionError:
                    print(f"Missing {self.channel_code} in DataFrame {k}")
                    sys.exit(1)
            else:
                print(f"Empty {k} dataframe")

    def construct_features_table(self) -> pd.DataFrame:
        """
        Main aggregation of raw data into a single dataframe

        :return: A dataframe containing all the features aggregated
                to the expected  granularity from the Stan model
        :rtype: pd.DataFrame
        """

        self.check_channel_codes_in_data()

        features = [
            self.features_channel_df,
            self.feature_media_execution_df,
            # self.feature_external_data_df,
            self.feature_seasonality_df,
            *self.additional_features,
        ]
        features_df = reduce_data_frames(
            frames=[self.index_df] + features,
            how="left",
        )
        return features_df

    @property
    def features_channel_df(self) -> pd.DataFrame:
        """
        Creates the target variable, the sellout volume, and the control
        features for the Stan model, including the price features,
        competitors features and distribution features.

        The control features are learned by the model and constitute
        the baseline which is the expected sales without any marketing effect.

        :return: A dataFrame containing the baseline features
        :rtype: pd.DataFrame
        """
        # volume_df = self._construct_volume_df()
        price_df = self._construct_price_features()
        # price_competitors_df = self._construct_competitors_features(price_df)
        # feature_distribution_df = self._construct_distribution_features()

        features = [
            # volume_df,
            price_df,
            # price_competitors_df,
            # feature_distribution_df,
        ]

        # --- Aggregation of all features ---
        features_channel_df = reduce_data_frames(
            frames=[self.index_df] + features,
            how="left",
        )

        return features_channel_df

    @property
    def feature_media_execution_df(self) -> pd.DataFrame:
        """
        Creates a dataframe with media touchpoints spend or exec.
        The list of touchpoints and the corresponding metric
        are configured in the model settings.

        :return: A dataFrame containing the media spend or
                 exec aggregated to the target granularity
        :rtype: pd.DataFrame
        """

        media_execution_df = self.media_execution_df[
            self.media_execution_df.segment == self.channel_code
        ].copy()

        features, ref_level = construct_media_execution_features(
            config=self.config,
            spend_media_execution_df=media_execution_df,
            touchpoints_media=self.get_channel_tag_touchpoints(["mmx"]),  # media
            channel_code=self.channel_code,
        )

        media_execution_df = reduce_data_frames(
            frames=[self.index_df, *features], on=ref_level, how="left"
        )
        return media_execution_df

    def get_channel_tag_touchpoints(self, tags: List[str]) -> List[str]:
        """
        Gets the list of predictor parameters that contain one of
        the specified tags then filter on the channel code attribute.

        :param tags: List of tags identifying the relevant model settings parameters
        :type tags: List[str]
        :return: A list of touchpoints corresponding to the tags filtered
                 on the channel code attribute
        :rtype: List[str]
        """
        tp = get_touchpoints_from_tags(self.config, tags)

        return self.filter_touchpoints_on_channel(tp, self.channel_code)

    def _construct_price_features(self):
        """
        Method to construct price realted features in a feature df
        """
        sell_out_channel_df = self.data_aggregator.aggregate(
            self.sell_out_df[self.sell_out_df.channel_code == self.channel_code].copy()
        ).reset_index()

        result = sell_out_channel_df.groupby(["internal_geo_code"])["value"].sum().reset_index()
        geo_codes_with_zero_values = (
            result[result["value"] == 0]["internal_geo_code"].unique().tolist()
        )
        sell_out_channel_df = sell_out_channel_df[
            ~sell_out_channel_df.internal_geo_code.isin(geo_codes_with_zero_values)
        ]

        price_df, ref_level = construct_basic_price_discount_feature(
            self.config,
            sell_out_df=sell_out_channel_df,
            quantile_reference=0.9,
            channel_code=self.channel_code,
        )

        price_df.drop(
            [F_VOLUME, F_PRICE_ASP, "relative_gap_to_90th_price"],
            axis=1,
            inplace=True,
            errors="ignore",
        )
        
        return price_df

    def _is_channel(self, value_dict, channel_code):
        """
        Check if channel is in a model config yaml file
        """
        return channel_code in value_dict.get("channel", [channel_code])

    def _construct_volume_df(self):
        """
        construct volume feature in feture df
        """
        sell_out_channel_df = self.data_aggregator.aggregate(
            self.sell_out_df[
                self.sell_out_df.sales_channel_code == self.channel_code
            ].copy()
        ).reset_index()

        response_level_target = response_level_for_touchpoint(
            self.data_aggregator._config,
            self.data_aggregator._config["TARGET_VARIABLE"],
            self.channel_code,
        )

        sell_out_channel_df[self.data_aggregator._config["RESPONSE_LEVEL_TIME"]] = (
            pd.to_datetime(sell_out_channel_df[F_PERIOD_START])
            .dt.strftime("%Y%m").astype(int)
        )

        volume_df = (
            sell_out_channel_df.groupby(response_level_target)[
                [F_VOLUME, F_VALUE]
            ]
            .sum()
            .reset_index()
        )
        return volume_df

    def all_settings_dict(self):
        """
        Get the setting dictionary from model config
        """
        output = {}
        for channel_code, value in self.config["STAN_PARAMETERS"]["channels"].items():
            buffer_dict = copy(self.config["STAN_PARAMETERS"]["predictor_parameters"])
            # buffer_dict.update({self.TARGET_VARIABLE: value})
            buffer_dict.update(self.config["STAN_PARAMETERS"]["standard_parameters"])
            buffer_dict.update(self.config["STAN_PARAMETERS"]["transformation_parameters"])
            if "seasonality_parameters" in self.config.get("STAN_PARAMETERS"):
                buffer_dict.update(self.config.get("STAN_PARAMETERS").get("seasonality_parameters"))

            output[channel_code] = {
                k: v for k, v in buffer_dict.items() if self._is_channel(v, channel_code)
            }

        return output

    def filter_touchpoints_on_channel(
            self,
            tp_list: List[str],
            channel_code: str
        ) -> List[str]:
        """
        Get the list of touchpoints that apply to the channnel.
        Both shared and channel specific channels are returned.

        :param tp_list: Input touchpoint list
        :type tp_list: List[str]
        :param channel_code: Channel code to filter on
        :type channel_code: str
        :return: A list of touchpoints filtered on the channel code
        :rtype: List[str]
        """
        tp_list_filtered = []
        output = self.all_settings_dict()
        for tp in tp_list:
            if tp in output[channel_code]:
                tp_list_filtered.append(tp)
        return tp_list_filtered

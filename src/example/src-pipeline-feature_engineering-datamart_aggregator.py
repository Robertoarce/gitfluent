"""
Modules to aggregate dataframes
"""

import copy
from collections import defaultdict
from dataclasses import dataclass
from typing import Dict, List

import pandas as pd

from src.utils.schemas.response_model.input import (
    GeoMasterSchema,
    ProductMasterSchema,
    TouchpointMasterSchema,
)
from src.utils.settings_utils import get_feature_from_name, strategic_touchpoint_mapping

gs = GeoMasterSchema()
pms = ProductMasterSchema()
tms = TouchpointMasterSchema()


@dataclass
class AggregationDetail:
    """[Class to aggregate details]"""

    key_col: str
    target_level_value: str
    master_table: pd.DataFrame

    tables_to_aggregate = [
        "touchpoint_facts",
        "sellout_own",
        "sellout_competitors",
        "external_facts",
        "distribution_own",
        "distribution_competitors",
    ]

    master_tables = [
        "product_master",
        "touchpoint_master",
        "channel_master",
        "geo_master",
        "campaign_master",
        "currency_master",
    ]


class DatamartAggregator:
    """
    Class to aggregate dataframes
    """

    def __init__(self, config, raw_data_formatted):
        """
        Constructor to set aggregation class's instance variables

        Arguments:
            config -- Model and feature engineering configuration
            raw_data_formatted  -- Raw data dictioanry containing all dataframes
        """
        self._config = copy.deepcopy(config)
        # Address edge case where  all the values are NaN
        self.agg_functions_by_metric = defaultdict(lambda: lambda x: x.sum(min_count=1))
        self.agg_functions_by_metric.update(self._config.AGGREGATION_FUNCTIONS_METRIC)
        self.data_formatted = raw_data_formatted
        self.response_touchpoint_mapping = self._set_response_touchpoint_mapping()
        self.strategic_touchpoint_mapping = {}

    def fill_touchpoint_mapping(self, touchpoints: List[str]):
        """
        Fills touchpoint mapping
        """
        touchpoint_mapping = {
            "touchpoint_mapping": {
                touchpoint.split("-")[-1]: [touchpoint] for touchpoint in touchpoints
            }
        }
        self._config["touchpoint_mapping"] = touchpoint_mapping

    def _set_response_touchpoint_mapping(self) -> Dict[str, List[str]]:
        """Set response touchpoint mapping

        Returns:
            Dict[str, List[str]] -- [description]
        """
        try:
            touchpoint_config = self._config.touchpoint_mapping
            touchpoint_mapping = {
                touchpoint: k for k, v in touchpoint_config.items() for touchpoint in v
            }
        except AttributeError:
            touchpoint_mapping = {}
        return touchpoint_mapping

    def set_strategic_touchpoint_mapping(self) -> Dict[str, str]:
        """[sets strategic touchpoint mapping]

        Returns:
            Dict[str, str] -- [description]
        """
        touchpoint_config = self._config.touchpoint_mapping

        self.data_formatted.touchpoint_master.level = (
            self.data_formatted.touchpoint_master.level.str.lower()
        )
        # Auto-join to get strategic internal codes
        strategic_touchpoint_df = self.data_formatted.touchpoint_master.merge(
            self.data_formatted.touchpoint_master.query("level=='channel_lvl3'")[
                ["internal_channel_code", "channel_lvl3"]
            ],
            on="channel_lvl3",
            suffixes=["_orig", "_strat"],
        )

        touchpoint_master_dict = strategic_touchpoint_df.set_index(
            "internal_channel_code" + "_orig"
        )["internal_channel_code" + "_strat"].to_dict()

        touchpoint_mapping = {
            get_feature_from_name(self._config, k): touchpoint_master_dict[v[0]]
            for k, v in touchpoint_config.items()
            if k in self._config.STAN_PARAMETERS["predictor_parameters"]
        }

        # Init strategic touchpoint mapping from the model settings predictor
        # attributes
        self.strategic_touchpoint_mapping = strategic_touchpoint_mapping(self._config).copy()
        # Update strategic internal code from the touchpoint master
        self.strategic_touchpoint_mapping.update(touchpoint_mapping)

    def aggregate(self, df_to_aggregate, product: bool = True, geo: bool = True):
        """[Aggregate dataframes]

        Arguments:
            df_to_aggregate {[type]} -- [description]

        Keyword Arguments:
            product {bool} -- [description] (default: {True})
            geo {bool} -- [description] (default: {True})

        Returns:
            [type] -- [description]
        """
        aggregations_to_process = []
        if product:
            # TODO: move to global product master
            aggregations_to_process.append(
                AggregationDetail(
                    key_col="internal_product_code",
                    target_level_value=self._config.RESPONSE_LEVEL_PRODUCT,
                    master_table=self.data_formatted.product_master,
                )
            )
        if geo:
            # TODO: move to global geo master
            aggregations_to_process.append(
                AggregationDetail(
                    key_col="internal_geo_code",
                    target_level_value=self._config.RESPONSE_LEVEL_GEO,
                    master_table=self.data_formatted.geo_master,
                )
            )

        # For all the aggregation we need to do,
        aggregated_table = df_to_aggregate
        for agg_detail in aggregations_to_process:
            # Go through all the fact tables
            original_table = aggregated_table
            aggregated_table = self._aggregate_to_level(
                df_to_agg=original_table, agg_detail=agg_detail
            )

        aggregated_table = self.get_master_attributes(aggregated_table)
        return aggregated_table

    def _aggregate_to_level(self, df_to_agg: pd.DataFrame, agg_detail: AggregationDetail):
        """
        df_to_agg: The data frame that we want to aggregate
        The DF to aggregate has a key for product,
        that is probably different from the target granularity
        The objective
        """
        # If the table to aggregate doesn't contain information to be
        # aggregated, return it unmodified
        if agg_detail.key_col not in df_to_agg.columns:
            return df_to_agg

        if df_to_agg.empty:
            return df_to_agg
        # Otherwise, we need to do the actual aggregation
        # Auto-join on the master table to get the internal_code

        diff_cols = list(set(df_to_agg.columns).difference(agg_detail.master_table.columns)) + [
            agg_detail.key_col,
        ]

        df_to_agg = df_to_agg[diff_cols].merge(
            agg_detail.master_table[
                [
                    agg_detail.key_col,
                    agg_detail.target_level_value.lower(),
                ]
            ],
            on=agg_detail.key_col,
        )

        if df_to_agg[agg_detail.target_level_value.lower()].dropna().empty:
            df_to_agg = df_to_agg.drop(columns=[agg_detail.target_level_value.lower()])
        else:
            df_to_agg = (
                df_to_agg.drop(columns=[agg_detail.key_col])
                .merge(
                    agg_detail.master_table.loc[
                        agg_detail.master_table.level == agg_detail.target_level_value,
                        [
                            agg_detail.key_col,
                            agg_detail.target_level_value.lower(),
                        ],
                    ],
                    on=agg_detail.target_level_value.lower(),
                )
                .drop(columns=[agg_detail.target_level_value.lower()])
            )

        # Remove empty columns so the rows are not excluded from the group by
        df_to_agg = df_to_agg.dropna(how="all", axis=1)

        # Detect columns on which we need to do an aggregation
        # TODO: differentiate metrics that need to be summed VS. averaged
        cols_to_agg = ["value"]
        cols_key = [c for c in df_to_agg.columns if c not in cols_to_agg]

        aggregated = pd.DataFrame()
        # Aggregate, but before, split on metric if any
        if "metric" in df_to_agg.columns:
            for metric in df_to_agg["metric"].unique():
                sub_df = df_to_agg.loc[df_to_agg["metric"] == metric]
                sub_df = (
                    sub_df.groupby(cols_key)
                    .agg({"value": self.agg_functions_by_metric[metric]})
                    .reset_index()
                )
                aggregated = aggregated.append(sub_df)
        else:
            aggregated = (
                df_to_agg.groupby(cols_key)
                .agg(
                    {
                        "value": lambda x: x.sum(min_count=1),
                    }
                )
                .reset_index()
            )
        return aggregated

    def get_master_attributes(self, df: pd.DataFrame) -> pd.DataFrame:
        """[Get master attributes from dataframe]

        Returns:
            pd.DataFrame -- [description]
        """
        # List of master table of associated schema
        master_tables = [
            (self.data_formatted.product_master, pms),
            (self.data_formatted.geo_master, gs),
            (self.data_formatted.touchpoint_master, tms),
        ]

        for master_table, schema in master_tables:
            internal_code = schema.get_primary_key()[0]
            if internal_code in df.columns:
                diff_cols = list(set(df.columns).difference(master_table.columns)) + [internal_code]
                df = df[diff_cols].merge(
                    master_table.drop(columns=("level"), errors="ignore"),
                    on=schema.get_primary_key()[0],
                    how="left",
                    validate="m:1",
                )

        return df

    def convert_to_internal_codes(
        self, df: pd.DataFrame, response_level: List[str]
    ) -> pd.DataFrame:
        """Convert dataframe in internal codes"""
        # List of master table of associated schema
        master_tables = [
            (self.data_formatted.product_master, pms),
            (self.data_formatted.geo_master, gs),
            (self.data_formatted.touchpoint_master, tms),
        ]

        for master_table, schema in master_tables:
            for col in response_level:
                if col in schema.get_column_names():
                    diff_cols = list(set(df.columns).difference(master_table)) + [col]
                    df = (
                        df[diff_cols]
                        .merge(
                            # merged_df,
                            master_table.loc[
                                master_table.level == col,
                                [col] + schema.get_primary_key(),
                            ],
                            on=col,
                        )
                        .drop(columns=[col])
                    )

        return df

    @property
    def valid_touchpoint_granu(self):
        """
        Returns list of toouchpoint granularity
        """
        return [
            "touchpoint_raw",
            "touchpoint_response",
        ]

    @property
    def valid_product_granu(self):
        """
        Returns list of valid product granularity
        """
        return [
            "product_id",
            "ean",
            "category",
            "sub_brand",
            "brand",
            "company",
            "own_product",
        ]

    @property
    def valid_geo_granu(self):
        """
        Returns valid geo code granularity
        """
        return ["region_code", "region_name", "market_code", "market_name"]

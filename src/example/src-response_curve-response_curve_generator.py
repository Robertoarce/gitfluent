"""
Utility classes to generate response curves
"""
import csv
import logging
import multiprocessing as mp
import os
import time
from collections import defaultdict
from copy import copy
from functools import partial
from typing import Dict, List, Tuple

import cmdstanpy
import numpy as np
import pandas as pd
from box import Box
from pathos.multiprocessing import Pool

from src.pipeline.feature_engineering.channel_feature import ChannelFeature
from src.pipeline.feature_engineering.price import response_level_for_touchpoint
from src.pipeline.feature_engineering.utils import (
    get_adstock_lengths,
    predictor_features_name,
)
from src.pipeline.response_model.utils import transformation_length
from src.response_curve.conversion_financial_returns import build_finance_facts
from src.response_curve.mapping_indexes import MappingIndexes
from src.response_curve.st_response_model import BayesianResponseModel
from src.response_curve.stan_generated_quantities_builder import (
    GeneratedQuantitiesBuilder,
)
from src.utils.data_frames import ResultsBayesianUpliftChannel
from src.utils.datetime import _get_monday_of_week
from src.utils.names import (
    F_CHANNEL_CODE,
    F_CONTRIBUTION_MARGIN_PER_UNIT,
    F_DELTA_TO_NULL_VALUE,
    F_FEATURE,
    F_PERIOD_START,
    F_PRICE_ASP_UNIT,
    F_PRICE_ASP_UNIT_NET,
    F_SPEND,
    F_TOUCHPOINT,
    F_UPLIFT,
    F_VALUE,
    F_VALUE_PRED,
    F_VOLUME,
    F_YEAR,
    F_YEAR_CALENDAR,
    F_YEAR_FISCAL,
    F_YEAR_MONTH,
    F_YEAR_WEEK,
    F_DELTA_TO_NULL_VALUE_p10,
    F_DELTA_TO_NULL_VALUE_p90,
    F_VALUE_PRED_p10,
    F_VALUE_PRED_p90,
)
from src.utils.normalization import (
    TransformationParams,
    denormalize_value_array,
    normalize_feature,
)
from src.utils.schemas.response_model.input import GeoMasterSchema, ProductMasterSchema
from src.utils.schemas.response_model.output.response_curve import ResponseCurveSchema
from src.utils.settings_utils import (
    as_columns,
    as_records,
    from_records,
    get_feature_from_name,
    get_feature_param_value,
    get_name_from_feature,
    get_spend_column,
    get_stan_transformation_index,
    get_touchpoints_from_tags,
    get_uplift_time_scope,
    get_year_for_response_curve,
    get_year_for_response_curve_from_period_start,
    get_year_for_response_curve_from_year_months,
)
from src.utils.timing import timing

logger = logging.getLogger(__name__)
logger_cmdstan = logging.getLogger("cmdstanpy")

gs = GeoMasterSchema()
pms = ProductMasterSchema()
rcs = ResponseCurveSchema()


class ProfitabilityMetrics:
    """
    class to capture profatibility metrics
    """

    def __init__(
        self,
        config,
        finance_facts_yr_df: pd.DataFrame = None,
        sell_out_yr_df: pd.DataFrame = None,
        granularity_sell_in_metrics: List[str] = None,
        column_year: str = F_YEAR_CALENDAR,
    ):
        """
        Args:
            - sell_in_yr_df: sell_in table with relevant year info (in <column_name>)
            - sell_out_yr_df: sell_out table with relevant year info (in <column_name>)
        """

        # Configuration
        self._column_year = column_year
        self._granularity_sell_in_metrics = granularity_sell_in_metrics
        self.config = config

        # Contribution margin & asp used to compute financial returns (ROS,
        # ROI, CAAP uplift)

        self.finance_reference_year = str(config.get("EXECUTION_REFERENCE_YEAR"))

        self.finance_facts_consolidated_df = build_finance_facts(
            finance_facts=finance_facts_yr_df,
            sellout_df=sell_out_yr_df,
            granularity=granularity_sell_in_metrics,
            column_year=column_year,
            config=config,
        )

        sell_in_cm_df = self.get_sell_in_contribution_margin()
        sell_in_asp_df = self.get_sell_in_net_average_selling_prices()

        self._sell_in_cm = as_records(sell_in_cm_df)
        self._sell_in_asp_net = as_records(sell_in_asp_df[[F_PRICE_ASP_UNIT_NET]])

        sell_out_asp_df = self.get_sell_out_average_selling_prices()
        self._sell_out_asp = as_records(sell_out_asp_df[[F_PRICE_ASP_UNIT]])

    @property
    def granularity_sell_in_metrics(self) -> List[str]:
        """
        [provides granularity sell in metrics]
        """
        if self._granularity_sell_in_metrics is None:
            # pms.internal_product_code
            return ["brand_name", self._column_year]

        return self._granularity_sell_in_metrics

    @property
    def sell_in_cm_df(self) -> pd.DataFrame:
        """cm = Contribution Margin (local currency per unit)"""
        columns = self.granularity_sell_in_metrics + [F_CONTRIBUTION_MARGIN_PER_UNIT]
        return from_records(data=self._sell_in_cm, columns=as_columns(columns))

    @property
    def sell_in_asp_net_df(self) -> pd.DataFrame:
        """asp_net = Net Sales per unit (in local currency)"""
        columns = self.granularity_sell_in_metrics + [F_PRICE_ASP_UNIT_NET]
        return from_records(data=self._sell_in_asp_net, columns=as_columns(columns))

    @property
    def sell_out_asp_df(self) -> pd.DataFrame:
        """asp = sell-out Average Selling Price per unit (in local currency)"""
        columns = (
            # pms.internal_product_code,
            "brand_name",
            self._column_year,
            F_PRICE_ASP_UNIT,
        )
        return from_records(data=self._sell_out_asp, columns=as_columns(columns))

    def get_sell_in_contribution_margin(self) -> pd.DataFrame:
        """
        Contribution margin per unit (per brand x sales channel)
        Args:
            - finance_facts: Table containing all relevant sell-in information
                Assumption - Table must be properly scoped outside of this function to compute the
                profitability only on the sales channels of interest
            - granularity: granularity used to compute the profitability metric (cm per unit)
        """

        cm = (
            self.finance_facts_consolidated_df[
                self.finance_facts_consolidated_df[self._column_year].astype(str)
                == self.finance_reference_year
            ]
            .groupby(self.granularity_sell_in_metrics)[[F_CONTRIBUTION_MARGIN_PER_UNIT]]
            .sum()
        )

        return cm

    def get_sell_in_net_average_selling_prices(self) -> pd.DataFrame:
        """
        Net asp per unit (per brand x sales channel) -> Net Sales
        Args:
            - granularity: granularity used to compute the profitability metric (net sales per unit)
        """
        sales_df = (
            self.finance_facts_consolidated_df[
                self.finance_facts_consolidated_df[self._column_year].astype(str)
                == self.finance_reference_year
            ]
            .groupby(self.granularity_sell_in_metrics)[[F_PRICE_ASP_UNIT_NET]]
            .sum()
        )

        return sales_df

    def get_sell_out_average_selling_prices(self) -> pd.DataFrame:
        """
        Compute Average Selling Prices per brandxyear (based on all sales)

        Args:
            - sell_out_yr_df: Table containing all sell-out information
                for relevant company brands including a column to specify
                the relevant year granularity to compute the ASP)

                Assumption - Same information as the one in sell_out_df + relevant
                            `column_year`, & the sales columns are assumed to converted
                             to a unit of local currency
        """
        if F_PRICE_ASP_UNIT not in self.finance_facts_consolidated_df.columns:
            self.finance_facts_consolidated_df[F_PRICE_ASP_UNIT] = (
                self.finance_facts_consolidated_df[F_VALUE]
                / self.finance_facts_consolidated_df[F_VOLUME]
            )

        sales_df = self.finance_facts_consolidated_df.groupby(
            ["brand_name", self._column_year]  # pms.internal_product_code
        )[[F_PRICE_ASP_UNIT]].sum()

        return sales_df


class ConversionManager:
    """
    Object handling conversion from execution to spend
    """

    _touchpoints_spend_df = None

    def __init__(
        self,
        config,
        channel_features: Dict[str, ChannelFeature],
        is_fiscal_year_response_curve: bool = False,
    ):
        """
        Initialize a ConversionManager instance.

        Args:
            config: The configuration for the ConversionManager.
            channel_features (Dict[str, ChannelFeature]): A dictionary of channel features.
            is_fiscal_year_response_curve (bool, optional): Whether it is
            a fiscal year response curve. Defaults to False.
        """
        self.config = config
        self.channel_features = channel_features
        self._is_fiscal_year_response_curve = is_fiscal_year_response_curve

    @property
    def is_fiscal_year_response_curve(self) -> bool:
        """
        Property to get whether it is a fiscal year response curve.

        Returns:
            bool: True if it's a fiscal year response curve, False otherwise.
        """
        return self._is_fiscal_year_response_curve

    @property
    def column_year(self) -> str:
        """
        Property to get the column representing the year.

        Returns:
            str: The column representing the year.
        """
        return F_YEAR_FISCAL if self._is_fiscal_year_response_curve else F_YEAR_CALENDAR

    @property
    def unit_exec_cost(self) -> pd.DataFrame:
        """
        Calculate unit execution cost.

        Returns:
            pd.DataFrame: A DataFrame with unit execution costs.
        """
        features_df = list(self.channel_features.values()).pop().features_df
        features_df[F_YEAR] = features_df[F_YEAR_MONTH] // 100
        actionable_touchpoints = [col for col in features_df.columns if col.startswith("spend_")]
        nb_exec = features_df.groupby(
            [
                "brand_name",
                F_YEAR,
            ],
            as_index=False,
        )[actionable_touchpoints].sum()
        nb_exec = nb_exec.melt(
            id_vars=[
                "brand_name",
                F_YEAR,
            ],
            value_name=F_SPEND,
            var_name=F_TOUCHPOINT,
        )

        return nb_exec.merge(
            self._touchpoints_spend_df,
            left_on=[
                "brand_name",
                F_TOUCHPOINT,
                F_YEAR,
            ],
            right_on=[
                "brand_name",
                F_TOUCHPOINT,
                self.column_year,
            ],
            how="left",
            validate="1:1",
            suffixes=("_exec", ""),
        ).assign(unit_exec_cost=lambda df: df[F_SPEND] / df[f"{F_SPEND}_exec"])[
            [
                "brand_name",
                F_TOUCHPOINT,
                F_YEAR,
                "unit_exec_cost",
            ]
        ]

    def add_year(self, data_df: pd.DataFrame) -> pd.DataFrame:
        """
        Function that retrieves the data a instances belongs to.
        For that, it takes into account the time_horizon for each sub-brand
        Currently>Edited for deal with customizable time horizons.
        Args:
            data_df (pd.DataFrame): Dataframe to process.
            For instance, data_df = scenarios_output_df.
        Returns:
            pd.DataFrame: Input Dataframe but including the years info.
        """
        if "sub_brand" in data_df.columns:
            if self.config.get("BRAND_SPECIFIC_TIME_HORIZON_END", False):
                # Triggers the dynamic calculation for sub-brand specific
                years_per_sub_brand = []
                for sub_brand in data_df.sub_brand.unique():
                    # Iteration over sub-brand
                    sub_brand_data_df = data_df[data_df.sub_brand == sub_brand]
                    if sub_brand in self.config.get("BRAND_SPECIFIC_TIME_HORIZON_END"):
                        # Calculation using the specific case passed in the
                        # dictionary
                        sub_brand_years = self.get_calendar_year_from_time_horizon(
                            sub_brand_data_df,
                            self.config.get("BRAND_SPECIFIC_TIME_HORIZON_END")[sub_brand],
                        )
                    else:
                        # Calculation using the default case
                        sub_brand_years = self.get_calendar_year_from_time_horizon(
                            sub_brand_data_df, self.config.get("MODEL_TIME_HORIZON_END")
                        )
                    years_per_sub_brand.append(sub_brand_years)
                # Final aggregation
                years = pd.concat(years_per_sub_brand)
                # Sort index
                years.sort_index(inplace=True)
            else:
                # Common method in case we do not have the dictionary
                years = self.get_calendar_year_from_time_horizon(
                    data_df, self.config.get("MODEL_TIME_HORIZON_END")
                )
        else:
            # Common method
            years = self.get_calendar_year_from_time_horizon(
                data_df, self.config.get("MODEL_TIME_HORIZON_END")
            )

        return data_df.copy().assign(**{years.name: years})

    def get_calendar_year_from_time_horizon(
        self, data_df: pd.DataFrame, model_horizon_end: int
    ) -> pd.Series:
        """_summary_

        Args:
            data_df (pd.DataFrame): Dataframe to be processed in order to
            calculate the corresponding year.
            model_horizon_end (int): Specific horizon time end for a sub-brand

        Raises:
            KeyError: Raises when there is no  time frequency column on which
                     to extract year information in table.

        Returns:
            pd.Series: Values for the years for the different instances of the dataframe
        """
        fiscal_year_final_week = model_horizon_end % 100
        fiscal_year_final_month = int(_get_monday_of_week(model_horizon_end).strftime("%m"))

        if F_YEAR_WEEK in data_df.columns:
            years = get_year_for_response_curve(
                year_weeks=data_df[F_YEAR_WEEK],
                is_fiscal_year_response_curve=self._is_fiscal_year_response_curve,
                fiscal_year_final_week=fiscal_year_final_week,
            )
        elif F_YEAR_MONTH in data_df.columns:
            years = get_year_for_response_curve_from_year_months(
                year_months=data_df[F_YEAR_MONTH],
                is_fiscal_year_response_curve=self._is_fiscal_year_response_curve,
                fiscal_year_final_month=fiscal_year_final_month,
            )
        elif F_PERIOD_START in data_df.columns:
            years = get_year_for_response_curve_from_period_start(
                period_start=pd.to_datetime(data_df[F_PERIOD_START]),
                is_fiscal_year_response_curve=self._is_fiscal_year_response_curve,
                fiscal_year_final_week=model_horizon_end % 100,
            )
        else:
            raise KeyError(
                f"No time frequency column on which to"
                f" extract year information in table {data_df.name}"
            )

        return years

    def check_is_set(self, attribute_name: str):
        """
        Check if an attribute is already set and raise an error if it is.

        Args:
            attribute_name (str): The name of the attribute to check.
        """
        if getattr(self, attribute_name):
            raise AttributeError(
                f"Attribute `{attribute_name} cannot be set twice (immutable)!"
            )

    def set_touchpoints_spend(self, touchpoints_spend_df: pd.DataFrame):
        """
        This function is used to store the time series of spend per touchpoint at
        the very begining of the response_model pipeline.
        We do this in order to have the right spend level when we do a model in execution
        and need to compute ROIs at the end of the pipeline.
        """
        idx = [*self.config.get("granularity_output"), self.column_year]
        touchpoints_spend_df = touchpoints_spend_df.rename(
            columns={
                rcs.response_touchpoint: F_TOUCHPOINT,
                F_PERIOD_START: F_YEAR_MONTH,
                F_VALUE: F_SPEND,
            }
        )

        touchpoints_spend_df[F_YEAR_MONTH] = (
            pd.to_datetime(touchpoints_spend_df[F_YEAR_MONTH]).dt.strftime("%Y%m").astype(int)
        )
        touchpoints_spend_df = self.add_year(touchpoints_spend_df)
        touchpoints_spend_df = touchpoints_spend_df.groupby(idx, as_index=False)[F_SPEND].sum()
        touchpoints_spend_df[F_TOUCHPOINT] = touchpoints_spend_df[F_TOUCHPOINT].apply(
            get_spend_column
        )
        # touchpoints_spend_df = self._add_halo_effect(touchpoints_spend_df)
        # #TODO: Dip - Work on this method to remove internal_product_code
        self._touchpoints_spend_df = touchpoints_spend_df

    def correct_yearly_spend_level(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        This function is used to replace and apply the "raw" time series of spend per
        touchpoint stored at the very begining of the response_model pipeline.
        We do this in order to have the right spend level when we do a model in execution
        and need to compute ROIs.
        """
        idx = [*self.config.get("granularity_output"), self.column_year]

        touchpoints = [
            tp
            for tp in df[F_TOUCHPOINT].unique()
            if tp
            in get_touchpoints_from_tags(self.config, ["media", "trade_marketing", "mmx"], True)
        ]

        df = df.merge(self._touchpoints_spend_df, on=idx, how="left", suffixes=("", "_correct"))

        tp_spend_correct = df.loc[df[F_TOUCHPOINT].isin(touchpoints)]

        if tp_spend_correct[F_SPEND + "_correct"].isna().sum():
            tp = tp_spend_correct[tp_spend_correct[F_SPEND + "_correct"].isna()][
                F_TOUCHPOINT
            ].unique()
            logger.debug(f"No spend found for touchpoint {tp}, no spend correction applied")

        df.loc[df[F_TOUCHPOINT].isin(touchpoints), F_SPEND] = (
            df.loc[df[F_TOUCHPOINT].isin(touchpoints), F_SPEND + "_correct"].fillna(
                df.loc[df[F_TOUCHPOINT].isin(touchpoints), F_SPEND]
            )
        ) * df.loc[df[F_TOUCHPOINT].isin(touchpoints), F_UPLIFT]

        df = df.drop(columns=[F_SPEND + "_correct"])

        return df

    def _add_halo_effect(self, touchpoints_spend_df) -> pd.DataFrame:
        """
        Function adding the spend of the source touchpoint spend to halo features
        """

        for (
            touchpoint,
            halo_config,
        ) in self.config.response_model.features.get("halo_effect", {}).items():
            if halo_config["activate"]:
                brands_with_halo = halo_config[self.config.get("RESPONSE_LEVEL_PRODUCT")]

                for origin, target in brands_with_halo:
                    # For each source target couple for halo, we query the right spend,
                    # and we use it as the spend to the target brand halo effect
                    response_level_product = self.config.get("RESPONSE_LEVEL_PROCUCT")
                    halo_spend_source = touchpoints_spend_df.query(
                        # pms.internal_product_code
                        f"{'brand_name'} == '{'-'.join([response_level_product, origin])}' & "
                        f"{F_TOUCHPOINT} == '{get_feature_from_name(self.config, touchpoint)}'"
                    ).copy()
                    halo_spend_source["brand_name"] = "-".join(  # pms.internal_product_code
                        [self.config.get("RESPONSE_LEVEL_PRODUCT"), target]
                    )
                    halo_spend_source[F_TOUCHPOINT] = f"spend_halo_{touchpoint}"
                    touchpoints_spend_df = pd.concat(
                        [touchpoints_spend_df, halo_spend_source], axis=0, sort=False
                    )

                touchpoints_spend_df = touchpoints_spend_df.sort_values(
                    [
                        "brand_name",
                        F_TOUCHPOINT,
                        self.column_year,
                    ],  # pms.internal_product_code
                    ascending=True,
                ).reset_index(drop=True)

        return touchpoints_spend_df


class ResponseCurvesManager:
    """
    All relevant parameters used to build response curves and compute financial ratios
    (i.e. relevant params used in M&T effectiveness measurements)
    """

    _profitability_metrics = {}

    def __init__(
        self,
        config,
        is_fiscal_year_response_curve: bool,
        is_sell_in_profitability_per_year: bool,
        channel_features: Dict[str, ChannelFeature],
    ):
        """
        Initialize a ResponseCurvesManager instance.

        Args:
            config: The configuration for the ResponseCurvesManager.
            is_fiscal_year_response_curve (bool): Whether it is a fiscal year response curve.
            is_sell_in_profitability_per_year (bool): True if sell-in profitability metrics 
            are differentiated between years.
            channel_features (Dict[str, ChannelFeature]): A dictionary of channel features.
        """
        self.config = Box(config)

        # True = sell-in profitability metrics are differentiated between year
        self._is_sell_in_profitability_per_year = is_sell_in_profitability_per_year

        # Init conversion
        self._conversion_manager = ConversionManager(
            config=config,
            is_fiscal_year_response_curve=is_fiscal_year_response_curve,
            channel_features=channel_features,
        )
        self.channel_features = channel_features

    @property
    def is_fiscal_year_response_curve(self) -> bool:
        """
        Property to get whether it is a fiscal year response curve.

        Returns:
            bool: True if it's a fiscal year response curve, False otherwise.
        """
        return self._conversion_manager.is_fiscal_year_response_curve

    @property
    def column_year(self) -> str:
        """
        Property to get the column representing the year.

        Returns:
            str: The column representing the year.
        """
        return self._conversion_manager.column_year

    @property
    def conversion(self) -> ConversionManager:
        """Access to conversion manager from outside of the object"""
        return self._conversion_manager

    @property
    def profitability(self) -> ProfitabilityMetrics:
        """Access to profitability metrics manager from outside of the object"""
        return self._profitability_metrics

    @property
    def granularity_sell_in_metrics(self) -> List[str]:
        """
        Property to get granularity for sell-in metrics.

        Returns:
            List[str]: List of columns for granularity in sell-in metrics.
        """
        if self._is_sell_in_profitability_per_year:
            return [
                # pms.internal_product_code,
                "brand_name",
                self.column_year,
            ]
        return ["brand_name"]

    @property
    def national_aggregated_features(self):
        """Return national features dataframe for all channels concatenated"""
        return pd.concat(
            [
                channel_feature.national_features_df
                for channel_feature in self.channel_features.values()
            ],
            axis=0,
        )

    def add_year(self, data_df: pd.DataFrame) -> pd.DataFrame:
        """
        Add year to DataFrame as a new column, named according to
        the required aggregation (calendar or fiscal)
        """
        return self._conversion_manager.add_year(data_df=data_df)

    def get_conversion_table(
        self,
        attribute_name: str,
    ) -> pd.DataFrame:
        """
        Get the conversion table for a specific attribute.

        Args:
            attribute_name (str): The name of the attribute.

        Returns:
            pd.DataFrame: The conversion table for the attribute.
        """
        return getattr(
            self._profitability_metrics,
            "_".join([attribute_name, "df"]),
        )

    def set_conversion_params(
        self,
        touchpoints_spend_df: pd.DataFrame,
    ):
        self._conversion_manager.set_touchpoints_spend(touchpoints_spend_df=touchpoints_spend_df)

    def set_profitability_metrics(
        self,
        sell_out_df: pd.DataFrame,
        finance_facts: pd.DataFrame,
        data_aggregator,
    ):
        """
        Args:
            - sell_out_df & sell_in_df are assumed to have all columns in standard units
                (i.e. unit, local currency)
            - suffixes_sales_channels: relevant sales_channel to consider
        """
        # 0. Check that object has not already been created
        if self._profitability_metrics:
            raise AttributeError("Cannot be set twice (immutable)!")

        # convert to standard units if requested
        if self.config.get("convert_to_standard_units"):
            sell_out_df = data_aggregator.get_master_attributes(sell_out_df)
            sell_out_df[F_VOLUME] *= sell_out_df["standard_unit_coefficient"].fillna(1)

        # 1. Add year information to sell-out & financial facts
        sell_out_df = data_aggregator.aggregate(sell_out_df).reset_index()
        sell_out_yr_df = self.add_year(data_df=sell_out_df)

        if finance_facts is not None:
            finance_facts_yr_df = self.add_year(data_df=finance_facts).query(
                f"scenario == @self.config.response_model.finance_scenario & "
                f"{rcs.internal_geo_code} == @self.config.scope.attributes.internal_response_geo_code",
            )
        else:
            finance_facts_yr_df = pd.DataFrame(
                columns=self.granularity_sell_in_metrics + [self.column_year, "account", "value"]
            )

        self._profitability_metrics = ProfitabilityMetrics(
            column_year=self.column_year,
            granularity_sell_in_metrics=self.granularity_sell_in_metrics,
            finance_facts_yr_df=finance_facts_yr_df,
            sell_out_yr_df=sell_out_yr_df,
            config=self.config,
        )


class UpliftFeatureManager:
    """
    Uplift feature manager class
    """
    def __init__(
        self,
        transformed_features_df: pd.DataFrame,
        transformation_params: TransformationParams,
        touchpoints: List,
        bayesian_model_indexes: MappingIndexes,
        response_curves_manager: ResponseCurvesManager,
        channel_code: str,
        config,
    ):
        """Constructor method

        Arguments:
            transformed_features_df {pd.DataFrame} -- [description]
            transformation_params {TransformationParams} -- [description]
            touchpoints {List} -- [description]
            bayesian_model_indexes {MappingIndexes} -- [description]
            response_curves_manager {ResponseCurvesManager} -- [description]
            channel_code {str} -- [description]
            config {[type]} -- [description]
        """
        self.touchpoints = touchpoints
        self.channel_code = channel_code
        self.transformed_features_df = transformed_features_df
        self.transformation_params = transformation_params
        self.bayesian_model_indexes = bayesian_model_indexes
        self.response_curves_manager = response_curves_manager
        self.config = config

    def compute_feature_df(self, uplift, year, is_contrib) -> Tuple[pd.DataFrame, pd.DataFrame]:
        """
        Compute uplifted feature DataFrames for a specific year.

        This method computes two DataFrames:
        1. An uplifted feature DataFrame where the uplift is applied to the specified touchpoints.
        2. A normalized uplifted feature DataFrame where the uplifted values are normalized.

        Args:
            uplift (float or pd.Series): The uplift factor(s) to apply to the touchpoints.
                If a single float is provided, it is applied uniformly to all touchpoints.
                If a pd.Series is provided, it should have touchpoint names as indices, and
                the corresponding uplift factors as values.
            year (int): The year for which the uplift is applied.
            is_contrib (bool): A flag indicating whether the uplift is additive (contributory).
                If True, the uplift is applied directly to the touchpoints. If False,
                the uplift is applied conditionally based on the specified year.

        Returns:
            Tuple[pd.DataFrame, pd.DataFrame]: A tuple containing two DataFrames:
                1. The uplifted feature DataFrame with uplift applied.
                2. The normalized uplifted feature DataFrame.
        """
        uplifted_features_df = self.transformed_features_df.copy()
        normalized_uplifted_features_df = self.transformed_features_df.copy()

        if is_contrib:
            uplifted_features_df[self.touchpoints] *= uplift
        else:
            uplifted_features_df[self.touchpoints] = uplifted_features_df[self.touchpoints].mask(
                uplifted_features_df[self.response_curves_manager.column_year] == year,
                uplifted_features_df[self.touchpoints] * uplift,
            )

        for tp in self.touchpoints:
            response_level = response_level_for_touchpoint(
                self.config, get_name_from_feature(tp), self.channel_code
            )
            response_level.remove(F_YEAR_MONTH)

            if len(response_level) == 2:
                key_cols = [
                    "brand_name",
                    gs.internal_geo_code,
                ]
            else:
                key_cols = ["brand_name"]

            normalized_uplifted_features_df[tp] = normalize_feature(
                uplifted_features_df,
                self.transformation_params.get_feature_params(tp, self.config),
                tp,
                key_cols,
            )

        normalized_uplifted_features_df.rename(
            {tp: f"u_{tp}" for tp in self.touchpoints}, inplace=True, axis=1
        )

        return normalized_uplifted_features_df, uplifted_features_df


class StanUpliftComputation:
    """
    class for stan uplift computation
    """
    def __init__(
        self,
        bayesian_model: BayesianResponseModel,
        channel_features: ChannelFeature,
        bayesian_model_indexes: MappingIndexes,
        response_curves_manager: ResponseCurvesManager,
        config,
        lambda_adstocks: Dict,
    ):
        """
        Constructor method
        """
        self.bayesian_model = bayesian_model
        self.bayesian_model.test_duration = 0
        self.bayesian_model.create_data_input()
        self.features_df = (
            response_curves_manager.add_year(channel_features.features_df)
            .sort_values(
                [
                    "brand_name",
                    gs.internal_geo_code,
                    F_YEAR_MONTH,
                ]
            )
            .reset_index(drop=True)
        )
        self.transformation_params = channel_features.transformation_params
        self.bayesian_model_indexes = bayesian_model_indexes
        self.response_curves_manager = response_curves_manager
        self.channel_code = channel_features.channel_code
        self.config = config
        self.brand_time_horizon = self.bayesian_model.brand_time_horizon
        self.brand_region_stan_index = self.bayesian_model.brand_region_stan_index

        self.transfo_target = self.transformation_params.get_feature_params(
            self.config.get("TARGET_VARIABLE"), self.config
        )
        self.n_brands = len(self.bayesian_model_indexes.index_brand)
        self.brand_time_index = (
            self.features_df[
                list(("brand_name", F_YEAR_MONTH)) + [self.response_curves_manager.column_year]
            ]
            .drop_duplicates(subset=["brand_name", F_YEAR_MONTH])
            .sort_values(["brand_name", F_YEAR_MONTH])
            .reset_index(drop=True)
            .copy()
        )

        self.uplift_aggregation_index = None
        self.national_features = channel_features.national_features_df

        self.touchpoints = list(
            filter(
                lambda tp: tp in self.features_df.columns
                and f"beta_{tp}" in self.bayesian_model.fit.stan_vars_dims,
                list(predictor_features_name(self.config)[self.channel_code]),
            )
        )
        self.contribs_names = {f"contrib_{i}": i for i in self.touchpoints}
        self.adstock_lengths = get_adstock_lengths(
            self.touchpoints, dict(lambda_adstocks), self.channel_code, self.config
        )
        self.uplift_manager = UpliftFeatureManager(
            self.features_df,
            self.transformation_params,
            self.touchpoints,
            self.bayesian_model_indexes,
            response_curves_manager,
            self.channel_code,
            self.config,
        )

        if self.config.get("CUSTOM_GQ"):
            stan_file = dict(self.config.get("STAN_GENERATED_QUANTITIES_FILE"))[self.channel_code]
        else:
            tmp_folder = self.bayesian_model.fit.runset.csv_files[0].split("/")[:-1]
            stan_file = "/".join(tmp_folder + ["stan_gq.stan"])
            sb = GeneratedQuantitiesBuilder(
                self.bayesian_model.stan_code, self.channel_code, self.config
            )
            sb.build_and_save_model(stan_file)
        stan_file = os.getcwd() + stan_file
        self.gq_model = cmdstanpy.CmdStanModel(stan_file=stan_file, logger=logger_cmdstan, stanc_options= {"auto-format": True},)
        self.gq_model.compile()

    @timing
    def compute_df(self, years: List) -> ResultsBayesianUpliftChannel:
        """
        Computes all the dataframes necessary for uplifts and contribution computation.
        The necessary datframes are the following:
            - Sales contribution: contains for each year and touchpoint the delta
             to null volumes for uplift 0 and 1, with contribution method for uplifted feature
            calculation (see doc for more information)
            - sales distribution df: contains for each month, each uplift value, and each touchpoint,
             the delta to null volumes
            - Volumes uplifts uplift: contains for each year, each uplift value, and each touchpoint,
             the delta to null volumes
        :rtype: ResultsBayesianUpliftChannel
        :return: Object containing the
        """
        # volume_contribution, volume_distribution, volume_uplifts = (
        value_contribution, value_distribution, value_uplifts = (
            pd.DataFrame(),
            pd.DataFrame(),
            pd.DataFrame(),
        )

        for year in years:
            self.uplift_aggregation_index = get_uplift_time_scope(
                year,
                self.brand_time_index,
                self.adstock_lengths,
                self.response_curves_manager,
            )

            time.sleep(40)
            logger.info(f"Computing contributions value for year {year}")
            value_contribution_year, _ = self.compute_uplift_df(
                uplifts=[0, 1], year=year, is_contrib=True
            )
            value_contribution = pd.concat(
                [value_contribution, value_contribution_year],
                axis=0,
                sort=False,
            )

            time.sleep(30)
            logger.info(f"Computing uplifted value for year {year}")
            value_uplifts_year, value_distribution_year = self.compute_uplift_df(
                uplifts=list(self.config.get("UPLIFT_VALUES_TO_COMPUTE")),
                year=year,
                is_contrib=False,
            )
            value_distribution = pd.concat(
                [value_distribution, value_distribution_year],
                axis=0,
                sort=False,
            )
            value_uplifts = pd.concat(
                [value_uplifts, value_uplifts_year],
                axis=0,
                sort=False,
            )
        value_distribution = value_distribution.drop_duplicates()
        results_uplift_channel = ResultsBayesianUpliftChannel(
            channel_code=self.channel_code,
            denormalized_output_df=value_distribution,
            value_contribution_df=value_contribution,
            value_uplift_df=value_uplifts,
        )
        return results_uplift_channel

    def compute_uplift_df(
        self, uplifts: List, year: int, is_contrib: bool
    ) -> Tuple[pd.DataFrame, pd.DataFrame]:
        """
        Performs the computation of delta to null values for all uplifts in 2 steps:
            1. Compute the samples for all the values
            2. Compute delta to null values
            3. Aggregate the results and format them in a dataframe
        :param year: Year on which to compute the uplifts
        :return: Two dataframes containing the delta to null values for all uplifts,
         aggregated per year or per year week
        :rtype: Tuple[pd.DataFrame, pd.DataFrame]
        """

        # volume_uplifts_df = pd.DataFrame(
        value_uplift_df = pd.DataFrame(
            columns=[
                F_CHANNEL_CODE,
                # pms.internal_product_code,
                "brand_name",
                F_TOUCHPOINT,
                F_UPLIFT,
                self.response_curves_manager.column_year,
                F_DELTA_TO_NULL_VALUE,
                F_DELTA_TO_NULL_VALUE_p10,
                F_DELTA_TO_NULL_VALUE_p90,
            ]
        )

        value_distribution = pd.DataFrame(
            columns=[
                F_CHANNEL_CODE,
                "brand_name",
                F_YEAR_MONTH,
                F_UPLIFT,
                F_TOUCHPOINT,
                F_FEATURE,
                F_VALUE_PRED,
                F_VALUE_PRED_p10,
                F_VALUE_PRED_p90,
            ]
        )

        samples_dict = self.compute_samples_for_uplifts(uplifts, year, is_contrib=is_contrib)

        for contrib, tp in self.contribs_names.items():
            value_uplift_df = pd.concat(
                [
                    value_uplift_df,
                    self.compute_delta_to_null_values(samples_dict[contrib], tp, year, is_contrib),
                ],
                axis=0,
                sort=False,
            )

            if not is_contrib:
                for uplift, samples in samples_dict[contrib].items():
                    value_distribution = pd.concat(
                        [
                            value_distribution,
                            self.compute_distribution_values(samples, uplift, tp, year),
                        ],
                        axis=0,
                        sort=False,
                    )

        return value_uplift_df, value_distribution

    def compute_samples_for_uplifts(
        self, uplifts: List, year: int, is_contrib: bool
    ) -> Tuple[Dict, Dict]:
        """
        Performs the computation of samples for all the inputed uplifts in a parallelized manner.
        Number of core is determined by the n_job value in the config. Operates in 3 steps
            1. Compute the uplifted features_df for a given uplift
            2. Runs stan model with the new features to compute associated volume uplift
                for each touchpoint
            3. Denormalizes the samples, and if necessary, reduces the geo dimension to national
        :return:
            - Samples dict, which contains for each touchpoint, and for each uplift,
              the denormalized samples
            - Features dict, which contains the uplifted features_df used
        :rtype: Tuple[Dict, Dict]
        """

        # Using box instead of dict here so we can use merge_update
        final_samples_box = Box()
        final_features_box = Box()

        def compute_samples_for_uplift_parallelized(uplift: float, year: int, is_contrib: bool):
            samples_dict = defaultdict(dict)
            features_dict = {}

            (
                normalized_uplifted_features_df,
                uplifted_features_df,
            ) = self.uplift_manager.compute_feature_df(
                uplift=uplift, year=year, is_contrib=is_contrib
            )
            time.sleep(30)
            if not is_contrib:
                features_dict[uplift] = uplifted_features_df

            uplifts_data_dict = copy(self.bayesian_model.data)
            uplifts_data_dict.update(self.create_data_dict(normalized_uplifted_features_df))

            gq_contrib = self.gq_model.generate_quantities(
                data=uplifts_data_dict,
                mcmc_sample=self.bayesian_model.fit,
                seed=13,
            )
            time.sleep(30)

            gq_samples = _read_cmdstan_outputs(gq_contrib)
            for contrib, tp in self.contribs_names.items():
                col_contrib = [col.startswith(contrib + "[") for col in gq_contrib.column_names]
                denormalized_samples = denormalize_value_array(
                    gq_samples[:, col_contrib], self.transfo_target
                )
                if get_feature_param_value(
                    self.config,
                    self.config.get("TARGET_VARIABLE"),
                    "granularity",
                    self.channel_code,
                ):
                    denormalized_samples = self.reduce_dimensions_to_brand_time(
                        denormalized_samples
                    )
                samples_dict[contrib][uplift] = denormalized_samples

            for f in gq_contrib.runset._csv_files:
                os.remove(f)
            return samples_dict, features_dict

        n_jobs = self.config.get("n_jobs")

        with Pool(min(mp.cpu_count(), n_jobs)) as p:
            samples = list(
                p.map(
                    partial(
                        compute_samples_for_uplift_parallelized,
                        year=year,
                        is_contrib=is_contrib,
                    ),
                    uplifts,
                )
            )

        for item in samples:
            final_samples_box.merge_update(Box(item[0]))
            final_features_box.merge_update(Box(item[1]))

        return final_samples_box.to_dict()

    def create_data_dict(self, uplifted_features_df: pd.DataFrame) -> Dict:
        """
        Computes, from the uplifted features df, the corresponding data dict
        to be used as an input of STAN
        :param uplifted_features_df: Features df to be used with the stan model
        :return: Dictionary readable by Stan
        """
        new_features_dict = {}
        data = {}

        if transformation_length(self.config, "adstock", self.channel_code) > 0:
            data["adstock_length"] = [
                self.adstock_lengths[param]
                for i, param in get_stan_transformation_index(
                    self.config, "adstock", self.channel_code
                )
            ]

        # Add variables
        new_features_dict.update({f"u_{i}": f"u_{i}" for i in self.uplift_manager.touchpoints})

        for feature_name, corresponding_base_feature in new_features_dict.items():
            data[feature_name] = uplifted_features_df[corresponding_base_feature].values

        return data

    def compute_distribution_values(
        self,
        samples: np.array,
        uplift: float,
        tp: str,
        year: int,
    ) -> pd.DataFrame:
        """
        Aggregates the N samples output from STAN into aggregated statistics :
            mean, percentile 10 and 90, aggregated per year week and touchpoint
        :param samples: array of samples for a given touchpoint and a given uplift.
        Expected dimensions are n_iter x n_weeks
        :param uplift: uplift value
        :param features_df: uplifted features df
        :param tp: touchpoint of interest
        :param year: year considered
        :return: Dataframe containing the delta to null volumes stats for each week
        """
        value_aggregated = pd.DataFrame(
            np.transpose(
                [
                    np.mean(samples, axis=0),
                    np.quantile(samples, 0.1, axis=0),
                    np.quantile(samples, 0.9, axis=0),
                ]
            ),
            columns=[
                F_VALUE_PRED,
                F_VALUE_PRED_p10,
                F_VALUE_PRED_p90,
            ],
        )
        value_aggregated = pd.concat(
            [self.brand_time_index, value_aggregated],
            axis=1,
            sort=False,
        )
        if uplift != 1:
            value_aggregated = value_aggregated[
                value_aggregated[self.response_curves_manager.column_year] == year
            ]

        value_aggregated.drop(self.response_curves_manager.column_year, axis=1, inplace=True)
        value_aggregated[F_CHANNEL_CODE] = self.channel_code
        value_aggregated[F_TOUCHPOINT] = tp
        value_aggregated[F_UPLIFT] = uplift

        value_aggregated = value_aggregated.merge(
            self.national_features[["brand_name", F_YEAR_MONTH, tp]],
            on=["brand_name", F_YEAR_MONTH],
            how="left",
        )
        value_aggregated.rename({tp: F_FEATURE}, axis=1, inplace=True)
        return value_aggregated

    def compute_delta_to_null_values(
        self, samples_dict: Dict, tp: str, year: int, is_contrib: bool
    ) -> pd.DataFrame:
        """
        Computes the delta to null values statistics aggregated on a full year from the samples
        :param samples_dict: dictionary containing the samples for all uplift values for a touchpoint.
        Expected dimension is for each array n_iter x n_months
        :param tp: touchpoint of interest
        :param year: year of interest
        :param is_contrib: computing contribution or uplift
        :return: Dataframe containing the delta to null value statistics for the considered year
        """
        # delta_volume_tp_df = pd.DataFrame(
        delta_value_tp_df = pd.DataFrame(
            columns=[
                F_CHANNEL_CODE,
                "brand_name",
                F_TOUCHPOINT,
                F_UPLIFT,
                self.response_curves_manager.column_year,
                F_DELTA_TO_NULL_VALUE,
                F_DELTA_TO_NULL_VALUE_p10,
                F_DELTA_TO_NULL_VALUE_p90,
            ]
        )

        if is_contrib:
            index = self.uplift_aggregation_index["contrib"].values
        else:
            index = self.uplift_aggregation_index[tp].values
        brands_index_scoped = self.brand_time_index[index].groupby("brand_name").size()
        for brand in self.bayesian_model.indexes.brand_index:
            if brand not in brands_index_scoped.index:
                brands_index_scoped.loc[brand] = 0
        brands_index_scoped = brands_index_scoped.sort_index().values

        null_spend = self.sum_over_months(samples_dict[0][:, index], brands_index_scoped)
        for uplift, samples in samples_dict.items():
            samples_scoped = samples[:, index]
            delta_samples = self.sum_over_months(samples_scoped, brands_index_scoped) - null_spend
            delta_value_aggregated = pd.DataFrame(
                np.transpose(
                    [
                        np.mean(delta_samples, axis=0),
                        np.quantile(delta_samples, 0.1, axis=0),
                        np.quantile(delta_samples, 0.9, axis=0),
                    ]
                ),
                columns=[
                    F_DELTA_TO_NULL_VALUE,
                    F_DELTA_TO_NULL_VALUE_p10,
                    F_DELTA_TO_NULL_VALUE_p90,
                ],
            )
            delta_value_aggregated[F_CHANNEL_CODE] = self.channel_code
            delta_value_aggregated["brand_name"] = self.bayesian_model_indexes.brand_index_df[
                "brand_name"
            ]
            delta_value_aggregated[F_TOUCHPOINT] = tp
            delta_value_aggregated[F_UPLIFT] = uplift
            delta_value_aggregated[self.response_curves_manager.column_year] = year
            delta_value_tp_df = pd.concat(
                [delta_value_tp_df, delta_value_aggregated], sort=False, axis=0
            )
        delta_value_tp_df.reset_index(drop=True, inplace=True)
        return delta_value_tp_df

    def sum_over_months(self, norm_array: np.array, brands_index_scoped: np.array) -> np.array:
        """
        Utility function computing, given an array, the sum of each brand over all the months,
        assuming that the indexing cycles first through time, then through brands
        :param brands_index_scoped:
        :param norm_array: normalized array, dimensions being n_iter x (n_months * n_brands)
        :return: summed array, dimensions being n_iter x n_brands
        """

        brand_time_index = [0] + list(brands_index_scoped)
        brand_time_index = np.cumsum(brand_time_index)

        a = np.array(
            [
                np.sum(
                    norm_array[:, brand_time_index[i] : brand_time_index[i + 1]],
                    axis=1,
                )
                for i in range(self.n_brands)
            ]
        )
        return np.transpose(a)

    def get_regional_sellout_table(self, array: np.array) -> pd.DataFrame:
        """
        Annual regional forecasted volume over the last 52 weeks per brand x region
        :param array: samples
        :type array: np.array
        :return: forecasted volume df
        :rtype: pd.DataFrame
        """
        n_regions = self.features_df[gs.internal_geo_code].nunique()

        brand_latest_year = np.array(
            [
                [
                    np.sum(
                        array[
                            :,
                            self.brand_region_stan_index[b, r, 1]
                            - 52 : self.brand_region_stan_index[b, r, 1],
                        ],
                        axis=1,
                    )
                    for r in range(0, n_regions)
                ]
                for b in range(self.n_brands)
            ]
        ).mean(axis=2)

        region_sellout_table = pd.concat(
            [
                (
                    pd.DataFrame([brand_latest_year[brand, region]], columns=["volume_forecast"])
                    .assign(r=region + 1)
                    .assign(b=brand + 1)
                )
                for brand in range(self.n_brands)
                for region in range(n_regions)
            ]
        )
        region_sellout_table[
            "brand_name"
        ] = region_sellout_table.b.map(  # pms.internal_product_code
            {v: k for k, v in self.bayesian_model_indexes.brand_index.items()}
        )
        region_sellout_table[gs.internal_geo_code] = region_sellout_table.r.map(
            {v: k for k, v in self.bayesian_model_indexes.region_index.items()}
        )

        return region_sellout_table

    def reduce_dimensions_to_brand_time(self, array: np.array) -> np.array:
        """
        Utility function computing, given a STAN array containing values for brand,
        time and region, an array where values are aggregated to brand and time.
        This function assumes that the indexing order is brand, region, and time
        :param array: array of dimension n_iter x (n_weeks * n_brands * n_region)
        :return: Numpy array of dimension n_iter x (n_weeks * n_brands)
        """
        n_regions = len(self.brand_region_stan_index[0])
        brand_national = np.array(
            [
                np.sum(
                    array[
                        :,
                        self.brand_region_stan_index[b, 0, 0]
                        - 1
                        + t : self.brand_region_stan_index[
                            b, n_regions - 1, 1
                        ] : self.brand_time_horizon[b],
                    ],
                    axis=1,
                )
                for b in range(self.n_brands)
                for t in range(self.brand_time_horizon[b])
            ]
        )
        return np.transpose(brand_national)


def _read_chain_cmdstanpy_samples(file) -> np.ndarray:
    """
    Generator to read the output csv of CmdStanPy containing the samples
    of a given chain line by line
    """
    with open(file, "r") as csv_file:
        reader = csv.reader(csv_file, quoting=csv.QUOTE_NONNUMERIC)
        while True:
            try:
                yield np.array(next(reader)).astype(np.float32)
            except StopIteration:
                break
            except ValueError:
                # Error raised by generator `reader` when reading non-numeric
                # rows, such as headers and field names
                pass


def _read_cmdstan_outputs(gq_contrib: cmdstanpy.CmdStanGQ) -> np.ndarray:
    """
    Reader to load the output of the sampler from disk

    Structure of the CmdStanPy output:
        - 1 csv file per chain
        - header with the information of the STAN sampling
        - 1 line in csv file = 1 sampling iteration (ordered 1 to N)-random variables as columns
        (one can access the variable names using `gq_contrib.column_names` - same order)

    Return:
        - gq_samples: Corresponding samples (rows = samples, columns = random variables)
            All chains are flattened into a single array (one chain after another)
            Columns are in the same order as `gq_contrib.column_names`
    """
    return np.array(
        sum(
            [list(_read_chain_cmdstanpy_samples(file)) for file in gq_contrib.runset.csv_files],
            [],
        )
    )

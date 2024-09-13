"""
End-to-end response model generation.
"""
import logging
import os.path as osp
from datetime import datetime
from itertools import product
from typing import Dict

import pandas as pd
from box import Box

from src.pipeline.feature_engineering.datamart_aggregator import DatamartAggregator
from src.pipeline.feature_engineering.feature_builder import FeatureBuilder
from src.pipeline.feature_engineering.run_feature_engineering import (
    prepare_data_for_response_model_target,
)
from src.pipeline.feature_engineering.utils import predictor_features_name, save_file
from src.pipeline.response_model.brick_breaking.run_pipeline import (
    BrickBreakingPipeline,
)
from src.response_curve.modeling import run_bayesian_model
from src.response_curve.response_curve_generator import (
    ResponseCurvesManager,
    StanUpliftComputation,
)
from src.response_curve.response_model_output import ResponseModelOutput
from src.utils.data.data_manager import DataManager
from src.utils.data_frames import aggregate_results
from src.utils.plots import print_correlations, print_preprocessing_plots
from src.utils.schemas.response_model.input.distribution_own import (
    DistributionOwnSchema,
)

# TODO: just for using the SalesAllocation regression lib
logger = logging.getLogger()
logger.setLevel("INFO")

dos = DistributionOwnSchema()


# pylint:disable=too-few-public-methods
class ResponseModelPipeline:
    """
    Pipeline object to generate the response model.

    Steps:
        - Load + Preprocess/clean data
        - Data grain via regression: Brick -> HCP
        - Feature engineering (feature builders)
        - Bayesian Response model
        - Post processing
        - Save outputs
    """

    mrds_variable = "variable"
    mrds_value = "value"

    def __init__(self, config: Dict, experiment_tracker, **kwargs):
        """
        Initializes the submodules required to run the various steps in the
        pipeline, based on the config provided.
        """
        self.config = config
        self.country = config["country"]
        self.run_date = config["run_date"]
        self.run_code = config["run_code"]
        self.version_code = config["version_code"]
        self.brick_breaking = BrickBreakingPipeline(config, experiment_tracker, **kwargs)
        self.data_manager = DataManager(
            data_sources_config=config["data_sources"],
            data_validation_config=config["data_validation"],
            data_cleaning_config=config["data_cleaning"],
            data_outputs_config=config["data_outputs"],
        )
        self.mrds_builder = (
            None  # TODO: Dip - Remove this line after uncommenting following two line
        )
        self.experiment_tracker = experiment_tracker

    def update_data_dict_with_missing_levels(self):
        """
        This module update all missing combinations for sales and spend data frames
        """
        columns = [
            "period_start",
            "internal_geo_code",
        ]
        if self.config.get("model_type").lower() != "pooled":
            columns.extend(
                [
                    "specialty_code",
                    "segment_code",
                    "segment_value",
                ]
            )

        if self.config.get("model_type").lower() != "pooled":
            self.data_dict["touchpoint_facts"]["segment_value"] = self.data_dict[
                "touchpoint_facts"
            ]["segment_value"].str.lower()
            speciality_values = self.data_dict["sell_out_own"]["specialty_code"].unique()
            segment_code_values = self.data_dict["sell_out_own"]["segment_code"].unique()
            segment_value_values = self.data_dict["sell_out_own"]["segment_value"].unique()
        else:
            speciality_values = segment_code_values = segment_value_values = []

        # Extract the unique 'internal_geo_code' entries from the filtered
        # DataFrame
        geo_codes = self.data_dict["sell_out_own"]["internal_geo_code"].unique()
        geo_codes = geo_codes.tolist()

        # Define the possible values for each column
        internal_geo_code_values = geo_codes

        channel_code_values = self.data_dict["touchpoint_facts"]["channel_code"].unique()
        channel_code_values = [x.upper() for x in channel_code_values]

        date_str = str(self.config.get("MODEL_TIME_HORIZON_START"))
        year = date_str[:4]
        month = date_str[4:6]
        self.start_date = f"{year}-{month}-01"

        date_str = str(self.config.get("MODEL_TIME_HORIZON_END"))
        year = date_str[:4]
        month = date_str[4:6]
        self.end_date = f"{year}-{month}-01"

        dates = []
        dates = pd.date_range(start=self.start_date, end=self.end_date, freq="MS")

        df = self.data_dict["sell_out_own"].copy()

        if self.config.get("model_type").lower() != "pooled":
            all_combinations = pd.DataFrame(
                list(
                    product(
                        dates,
                        internal_geo_code_values,
                        speciality_values,
                        segment_code_values,
                        segment_value_values,
                    )
                ),
                columns=columns,
            )
        else:
            all_combinations = pd.DataFrame(
                list(product(dates, internal_geo_code_values)), columns=columns
            )

        if(self.config.get("model_type").lower() == 'pooled'):
            df.period_start = pd.to_datetime(df["period_start"], format="%Y%m")
        else:
            df.period_start = pd.to_datetime(df["period_start"], format="%Y-%m-%d")
        
        df["period_start"] = df["period_start"].dt.strftime("%Y-%m-01")
        all_combinations["period_start"] = all_combinations["period_start"].dt.strftime("%Y-%m-%d")
        # Merge with the original DataFrame to add missing combinations
        df = pd.merge(
            df,
            all_combinations,
            on=columns,
            how="right",
        )

        # Fill missing values with 0
        df["value"] = df["value"].fillna(0)
        df["volume"] = df["volume"].fillna(0)
        df["frequency"] = self.data_dict["sell_out_own"]["frequency"].unique()[0]
        df["currency"] = df["currency"].fillna(
            self.data_dict["sell_out_own"]["currency"].unique()[0]
        )
        df["brand_code"] = df["brand_code"].fillna(
            self.data_dict["sell_out_own"]["brand_code"].unique()[0]
        )
        df["brand_name"] = df["brand_name"].fillna(
            self.data_dict["sell_out_own"]["brand_name"].unique()[0]
        )
        df["sales_channel_code"] = df["sales_channel_code"].fillna(
            self.data_dict["sell_out_own"]["sales_channel_code"].unique()[0]
        )

        self.data_dict["sell_out_own"] = df.copy()
        # code ends here

        df = self.data_dict["touchpoint_facts"].copy()
        # Create a DataFrame with all possible combinations
        columns.append("channel_code")
        if self.config.get("model_type").lower() != "pooled":
            all_combinations = pd.DataFrame(
                list(
                    product(
                        dates,
                        internal_geo_code_values,
                        speciality_values,
                        segment_code_values,
                        segment_value_values,
                        channel_code_values,
                    )
                ),
                columns=columns,
            )
        else:
            all_combinations = pd.DataFrame(
                list(product(dates, internal_geo_code_values, channel_code_values)),
                columns=columns,
            )

        # Merge with the original DataFrame to add missing combinations
        df = pd.merge(
            df,
            all_combinations,
            on=columns,
            how="right",
        )

        # Fill missing values with 0
        df["value"] = df["value"].fillna(0)
        df["country_code"] = df["country_code"].fillna(
            self.data_dict["touchpoint_facts"]["country_code"].unique()[0]
        )
        df["frequency"] = df["country_code"].fillna(
            self.data_dict["touchpoint_facts"]["frequency"].unique()[0]
        )
        df["brand_code"] = df["brand_code"].fillna(
            self.data_dict["touchpoint_facts"]["brand_code"].unique()[0]
        )
        df["brand_name"] = df["brand_name"].fillna(
            self.data_dict["touchpoint_facts"]["brand_name"].unique()[0]
        )
        # self.data_dict["touchpoint_facts"]["metric"].unique()[0]
        df["metric"] = "spend_value"

        channel_mapping = dict(
            zip(
                self.data_dict["touchpoint_facts"]["channel_code"].unique(),
                self.data_dict["touchpoint_facts"]["internal_channel_code"].unique(),
            )
        )

        df["internal_channel_code"] = (
            df["channel_code"].map(channel_mapping).fillna(df["internal_channel_code"])
        )
        # Create the geo_mapping dictionary from geo_master DataFrame
        geo_mapping = (
            self.data_dict["geo_master"]
            .set_index("internal_geo_code")["sub_national_code"]
            .to_dict()
        )
        df["sub_national_code"] = (
            df["internal_geo_code"].map(geo_mapping).fillna(df["sub_national_code"])
        )

        self.data_dict["touchpoint_facts"] = df.copy()

        geo_codes = df["internal_geo_code"].unique()
        self.data_dict["geo_master"] = self.data_dict["geo_master"][
            self.data_dict["geo_master"]["internal_geo_code"].isin(geo_codes)
        ]

    def data_loading(self):
        """
        Method to load required dataframes in data_dict dictionary
        """

        # Load, preprocess, clean data
        self.data_manager.load_validate_clean(config=self.config)
        self.data_dict = self.data_manager.get_data_dict()

        self.data_dict["touchpoint_facts"].internal_geo_code = self.data_dict[
            "touchpoint_facts"
        ].internal_geo_code.str.lower()
        self.data_dict["distribution_own"] = pd.DataFrame(columns=dos.get_column_names())

        # changes in the data received to comply witht the code
        self.data_dict["touchpoint_facts"]["value"] = self.data_dict["touchpoint_facts"][
            "value"
        ].abs()
        self.data_dict["product_master"].level = self.data_dict["product_master"].level.replace(
            ["BRAND"], "brand_name"
        )
        self.data_dict["touchpoint_facts"]["metric"] = "spend_value"

        self.data_dict["geo_master"].drop_duplicates(
            subset=["internal_geo_code"], keep="last", inplace=True, ignore_index=True
        )

        # self.update_data_dict_with_missing_levels()

        # storing config used in the MlFlow directory
        self.experiment_tracker.log_artifacts(
            {f"src/config/{self.country}/response_model/model_config.yaml": None, f"src/config/{self.country}/response_model/config.yaml": None}
        )

    def __call__(self):
        """
        Runs the pipeline.
        """
        self.data_loading()
        # self.load_sell_out_data()
        self.update_data_dict_with_missing_levels()
        result_df = pd.DataFrame()
        model_type = self.config.get("model_type")
        if model_type.lower() == "pooled":
            self.data_dict["touchpoint_facts"]["segment"] = "one-segment-run"
            self.data_dict["sell_out_own"]["channel_code"] = "one-segment-run"
            for name in ["touchpoint_facts", "sell_out_own"]:
                self.data_dict[name].drop(
                    ["segment_value", "segment_code", "specialty_code"],
                    axis=1,
                    inplace=True,
                    errors="ignore",
                )
            self.data_dict["sell_out_own"].drop("sales_channel_code", axis=1, inplace=True)
            self.data_dict["media_execution"] = self.data_dict["touchpoint_facts"].copy()
            result_df = self.generate_response_curve(result_df, level=None)
            self.save_results(result_df)
        elif model_type.lower() == "independent":
            """
            This code block runs bayesian modeling for all segments at once.
            It is not a quite hierarchical modeling we expect but this block
            will be updated to have the common priors
            """

            # 1. Creating a segment column
            df = self.data_dict["sell_out_own"].copy()
            df["channel_code"] = (
                df["specialty_code"].replace({" ": "_", "/": "_"}, regex=True)
                + "-"
                + df["segment_code"].replace({" ": "_", "/": "_"}, regex=True)
                + "-"
                + df["segment_value"].replace({" ": "_", "/": "_"}, regex=True)
            )
            df.drop(
                ["specialty_code", "segment_code", "segment_value"],
                axis=1,
                inplace=True,
            )
            df.drop("sales_channel_code", axis=1, inplace=True)
            df.reset_index(drop=True, inplace=True)
            self.data_dict["sell_out_own"] = df.copy()

            df = self.data_dict["touchpoint_facts"].copy()
            df["segment"] = (
                df["specialty_code"].replace({" ": "_", "/": "_"}, regex=True)
                + "-"
                + df["segment_code"].replace({" ": "_", "/": "_"}, regex=True)
                + "-"
                + df["segment_value"].replace({" ": "_", "/": "_"}, regex=True)
            )
            df.drop(
                ["segment_value", "segment_code", "specialty_code"],
                axis=1,
                inplace=True,
            )
            df.reset_index(drop=True, inplace=True)
            self.data_dict["touchpoint_facts"] = df.copy()

            if "control_variables" in self.data_dict:
                df = self.data_dict["control_variables"].copy()
                df["channel_code"] = (
                    df["specialty_code"].replace({" ": "_", "/": "_"}, regex=True)
                    + "-"
                    + df["segment_code"].replace({" ": "_", "/": "_"}, regex=True)
                    + "-"
                    + df["segment_value"].replace({" ": "_", "/": "_"}, regex=True)
                )
                df.drop(
                    ["specialty_code", "segment_code", "segment_value"],
                    axis=1,
                    inplace=True,
                )
                df.reset_index(drop=True, inplace=True)
                self.data_dict["control_variables"] = df.copy()

            # self.data_dict['touchpoint_facts'].drop('channel_code1', axis=1, inplace=True)

            # 2. Creating which hold channel related details channel master
            # dataframe
            self.data_dict["media_execution"] = self.data_dict["touchpoint_facts"].copy()
            self.data_dict["channel_master"] = pd.DataFrame(
                columns=["channel_code", "channel_name"]
            )
            unique_values = self.data_dict["sell_out_own"].channel_code.unique()
            self.data_dict["channel_master"]["channel_code"] = unique_values
            self.data_dict["channel_master"]["channel_name"] = unique_values

            result_df = self.generate_response_curve(result_df)
            self.save_results(result_df)

    def load_sell_out_data(self):
        """Method to load sell out data using brick breaking library"""
        result = self.brick_breaking()
        result.columns = result.columns.str.lower()
        brand_code = self.data_dict["touchpoint_facts"]["brand_code"].unique()[0]
        result = result[
            (result["brand_code"] == brand_code)
            & (result["period_start"] >= self.start_date)
            & (result["period_start"] <= self.end_date)
        ]
        result["brand_name"] = self.data_dict["touchpoint_facts"]["brand_name"].unique()[0]
        result["frequency"] = "MONTH"
        result = result[
            result["internal_geo_code"].isin(self.data_dict["geo_master"]["internal_geo_code"])
        ]
        result = result.rename(
            columns={
                "sales_value": "value",
                "segment_value_lower": "segment_value",
                "sales_volume": "volume",
            }
        )
        result = result.drop("version_code", axis=1)
        self.data_dict["sell_out_own"] = result.copy()

    def save_results(self, result_df):
        """Method to save response curve dataframe in the database

        Arguments:
            result_df {[DataFrame]} -- [Final response curve output dataframe]
        """

        result_df["channel_code"] = result_df["response_touchpoint"].str[6:]
        result_df["channel_code"] = result_df["channel_code"].str.upper()
        result_df = result_df.drop(
            [
                "internal_geo_code",
                "response_touchpoint",
                "internal_strat_touchpoint_code",
                # "period_start",
                "frequency",
                "baseline_value",
                "unit",
                "filter_out",
                "curve_type",
                "internal_response_geo_code",
            ],
            axis=1,
            errors="ignore",
        )

        agg_functions = {
            'spend': 'sum',
            'incremental_sell_out_units': 'sum',
            'gm_adjusted_incremental_value_sales': 'sum'
        }   
        def custom_agg(group):
            try:
                if(float(group.unique()[0]) == self.config.get('gm_of_sell_out')):
                    return float(group.iloc[0])
                else:
                    return group.astype(float).sum()
            except ValueError:
                return group.iloc[0]

        aggregated_df = result_df.groupby(
            ['channel_code', 'brand_name', 'uplift', 'metric', 'speciality_code', 'segment_code', 'segment_value']).agg({
            'value': custom_agg,
            **agg_functions
        }).reset_index()
        result_df = aggregated_df.reset_index()
        result_df['value'] = result_df['value'].apply(lambda x: str(x)).astype('object')

        date_str = str(self.config.get("MODEL_TIME_HORIZON_START"))
        year = date_str[:4]
        month = date_str[4:6]
        self.start_date = f"{year}-{month}-01"

        date_str = str(self.config.get("MODEL_TIME_HORIZON_END"))
        year = date_str[:4]
        month = date_str[4:6]
        self.end_date = f"{year}-{month}-01"

        result_df["start_date"] = datetime.strptime(self.start_date, "%Y-%m-%d").timestamp()
        result_df["end_date"] = datetime.strptime(self.end_date, "%Y-%m-%d").timestamp()
        result_df["gbu_code"] = self.config["GBU_CODE"]
        result_df["market_code"] = self.data_dict["touchpoint_facts"]["country_code"].unique()[0]
        result_df["created_ts"] = datetime.now().strftime(r"%Y-%m-%d %H:%M:%S")
        result_df["internal_response_code"] = "DSCOMM-" + self.config["version_code"]

        result_df["version_code"] = self.config["version_code"]
        result_df = result_df.drop(['INDEX','index'], errors='ignore', axis=1)
        save_file(
            data=result_df,
            file_name=f'{"output/rc_result.csv"}',
            experiment_tracker=self.experiment_tracker,
            mlflow_directory=None,
        )

        self.data_manager.save_table(result_df, "response_curve")

    def apply_feature_engineering(self):
        """Method to apply steps of feature engineering to preapre feature dataframe for modeling"""
        # do feature engineering
        self.data_aggregator = DatamartAggregator(Box(self.config), Box(self.data_dict))
        feature_builder = FeatureBuilder()
        (
            all_channel_features,
            touchpoints_spend_df,
        ) = prepare_data_for_response_model_target(
            self.data_dict, feature_builder, self.data_aggregator, self.config
        )
        self.response_curves_manager = ResponseCurvesManager(
            config=self.config,
            is_sell_in_profitability_per_year=self.config.get("IS_PROFITABILITY_SELL_IN_PER_YEAR"),
            is_fiscal_year_response_curve=self.config.get("RESPONSE_CURVE_IS_FISCAL_YEAR"),
            channel_features=all_channel_features,
        )
        self.response_curves_manager.set_conversion_params(
            touchpoints_spend_df=touchpoints_spend_df,
        )
        return all_channel_features

    def bayesian_modeling(self, all_channel_features, channel_code, level=None):
        """Method to apply bayesian modeling"""
        response = run_bayesian_model(
            all_channel_features[channel_code].features_df,
            all_channel_features[channel_code].normalized_features_df,
            all_channel_features[channel_code].transformation_params,
            all_channel_features[channel_code].channel_code,
            self.config,
            self.experiment_tracker,
            level,
        )

        save_file(
            data=all_channel_features[channel_code].features_df,
            file_name=f'{"output/features_df.csv"}',
            experiment_tracker=self.experiment_tracker,
            mlflow_directory=channel_code
            if level is None
            else osp.join(level["speciality"], level["segment_code"], level["segment_value"]),
        )
        save_file(
            data=all_channel_features[channel_code].normalized_features_df,
            file_name=f'{"output/normalized_features_df.csv"}',
            experiment_tracker=self.experiment_tracker,
            mlflow_directory=channel_code
            if level is None
            else osp.join(level["speciality"], level["segment_code"], level["segment_value"]),
        )
        save_file(
            data=response[0].region_index_df,
            file_name=f'{"output/region_index_df.csv"}',
            experiment_tracker=self.experiment_tracker,
            mlflow_directory=channel_code
            if level is None
            else osp.join(level["speciality"], level["segment_code"], level["segment_value"]),
        )
        return response

    def generate_response_curve(self, result_df, level=None):
        """
        Method to generate res curve using prep. data & modeling methods declared above
        """
        results_channels = []
        results_channel_dict = {}
        all_channel_features = self.apply_feature_engineering()
        lambda_adstocks = {}
        # run response model
        for channel_code in list(self.config.get("STAN_PARAMETERS")["channels"].keys()):
            if self.config.get("save_debug_preprocessing_plots"):
                relevant_features = [self.config.get("TARGET_VARIABLE")]
                relevant_features += predictor_features_name(self.config)[channel_code]

                print_preprocessing_plots(
                    raw_features_df=all_channel_features[channel_code].features_df,
                    normalized_features_df=all_channel_features[
                        channel_code
                    ].normalized_features_df,
                    relevant_features=relevant_features,
                    channel_code=channel_code,
                    experiment_tracker=self.experiment_tracker,
                )

                print_correlations(
                    normalized_features_df=all_channel_features[
                        channel_code
                    ].normalized_features_df,
                    relevant_features=relevant_features,
                    channel_code=channel_code,
                    experiment_tracker=self.experiment_tracker,
                )

            response = self.bayesian_modeling(
                all_channel_features=all_channel_features,
                channel_code=channel_code,
                level=level,
            )

            lambda_adstocks[channel_code] = response[1]

            uplift_computation = StanUpliftComputation(
                bayesian_model=response[2],
                channel_features=all_channel_features[channel_code],
                bayesian_model_indexes=response[0],
                response_curves_manager=self.response_curves_manager,
                config=self.config,
                lambda_adstocks=lambda_adstocks[channel_code],
            )
            results_bayesian_uplift_channel = uplift_computation.compute_df(
                self.config.get("RESPONSE_CURVE_YEARS")
            )
            results_channels.append(results_bayesian_uplift_channel)
            results_channel_dict[channel_code] = results_bayesian_uplift_channel

        lambda_adstock_df, results_bayesian_uplift = aggregate_results(
            results_channels=results_channels,
            lambda_adstocks=lambda_adstocks,
        )

        self.response_curves_manager.set_profitability_metrics(
            finance_facts=None,
            sell_out_df=self.data_dict["sell_out_own"],
            data_aggregator=self.data_aggregator,
        )

        for channel_code in list(self.config.get("STAN_PARAMETERS")["channels"].keys()):
            rsp_model_op = ResponseModelOutput(
                self.config,
                self.response_curves_manager,
                results_channel_dict[channel_code],
                self.experiment_tracker,
                lambda_adstock_df[lambda_adstock_df.channel_code == channel_code],
                self.data_aggregator,
                level=level,
                channel_code=channel_code,
            )
            rsp_response = rsp_model_op.run()

            if level is not None:
                rsp_response["st_response_curve_output_df"] = rsp_response[
                    "st_response_curve_output_df"
                ].assign(
                    speciality_code=level["speciality"],
                    segment_code=level["segment_code"],
                    segment_value=level["segment_value"],
                )
            else:
                speciality_code, segment_code, segment_value = (
                    channel_code.split("-")[0],
                    channel_code.split("-")[1],
                    channel_code.split("-")[2],
                )
                rsp_response["st_response_curve_output_df"] = rsp_response[
                    "st_response_curve_output_df"
                ].assign(
                    speciality_code=speciality_code,
                    segment_code=segment_code,
                    segment_value=segment_value,
                )
            if result_df.empty:
                result_df = rsp_response["st_response_curve_output_df"]
            else:
                result_df = result_df.append(
                    rsp_response["st_response_curve_output_df"], ignore_index=True
                )
        return result_df

    def save_mrds_df(self, mrds_df: pd.DataFrame):
        """
        As MRDS dataframe can have any number of features (columns),
        We need to melt the dataframe before saving it.
        """
        df_to_save = mrds_df.copy()

        df_to_save = df_to_save.melt(
            id_vars=self.mrds_builder.mrds_schema.keys(),
            var_name=self.mrds_variable,
            value_name=self.mrds_value,
        )

        # For enforceable schema
        df_to_save["value"] = df_to_save["value"].astype("str")

        # Version tag
        df_to_save["version_code"] = self.version_code

        # Uppercase for standard databases
        df_to_save.columns = [c.upper() for c in df_to_save.columns]

        self.data_manager.save_table(df_to_save, "mrds")

    def format_loaded_mrds_df(self, mrds_df: pd.DataFrame):
        """
        Where we have loaded a previously saved MRDS dataframe,
        We need to pivot back to a format compatible with the regression model.

        This is essentially the inverse of the `.save_mrds_df()` method.
        """
        mrds_df = mrds_df.pivot(
            index=self.mrds_builder.mrds_schema.keys(),
            columns=self.mrds_variable,
            values=self.mrds_value,
        ).reset_index(drop=False)

        mrds_df = mrds_df.sort_values("row_number")

        self.mrds_builder.enforce_schema(mrds_df)

        return mrds_df

    def apply_brick_breaking_coefficients(self, mrds_df: pd.DataFrame, model: Dict):
        """
        Allocate the sales to each segment, for each coefficient provided
        in the sales_allocation model.
        `mrds_df`: Dataframe containing HCP counts
                for each brick/market/product/period/sales, and a column for
                each {feature}_{value}, indicating the count of HCPs with that
                feature x value combination.
        `model`: Output from sales_allocation, containing coefficients.

        returns:
            `sales_allocation_df`: Dataframe containing same columns as `mrds_df`;
             each {feature}_{value} column now indicates the amount of sales allocated
            to *each* HCP with that feature x value combination, using that feature.
        """
        coefs = model["coeffcient_dict"]

        # Proportionalize the coefficients
        # To allocate sales using a feature with n possible values
        #    V = {v_1, v_2, v_3, ...v_n}
        # The amount of sales allocated to the group of HCPs with
        #    coefficient value v_i is equal to:
        # coefficient(v_i) / Σ_(1<j<=n)(coefficient(v_j))
        # To revisit the formula
        scaled_coefs = {}
        for feat in self.config["brick_breaking"]["features"]:
            denom = sum(v for k, v in coefs.items() if k.startswith(feat + "_"))

            scaled_coefs.update(
                {k: v / denom for k, v in coefs.items() if k.startswith(feat + "_")}
            )

        sales_allocation_df = mrds_df.copy()
        for col, coef in scaled_coefs.items():
            sales_allocation_df[col] = (
                sales_allocation_df["sales"] * coef / sales_allocation_df[col]
            )

        return sales_allocation_df

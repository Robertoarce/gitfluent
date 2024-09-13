"""
End-to-end External Response Curve Ingestion...
"""
from typing import Dict

import pandas as pd

from src.pipeline.publish_model.run_pipeline import PublishModelPipeline
from src.utils.data.data_manager import DataManager
from src.utils.experiment_tracking import BaseTracker
from src.utils.extrcs.consistency_checks import check_external_curve_consistency
from src.utils.extrcs.normalization import normalize_external_curve
from src.utils.extrcs.preprocessing import preprocess_external_curve


# pylint:disable=too-few-public-methods
class IngestionExtRespCurvesPipeline:
    """
    Pipeline object to ingest External Response Curve Model.

    Steps:
        - Load from DWH_EXTERNAL_RESPONSE_CURVE + Preprocess/clean data
        - Normalization
        - Consistency Checkers
        - Save outputs on DMT_RESPONSE_CURVE
    """

    def __init__(
        self,
        config: Dict,
        experiment_tracker: BaseTracker,
        internal_response_code: str,
        env: str,
        autopublish: bool = False,
        model_name: str = None,
        **kwargs,  # pylint: disable=unused-argument
    ):
        """
        Initializes the submodules required to run the various steps in the
        pipeline, based on the config provided.
        """
        # Apply pre-filter to internal_response_code
        for table_name, table_config in config["data_sources"]["Snowflake"]["tables"].items():
            config["data_sources"]["Snowflake"]["tables"][table_name].update(
                {
                    "pre_filters": {
                        f"{table_config['table']}.internal_response_code": {
                            "type": "equal",
                            "value": internal_response_code,
                        }
                    }
                }
            )

        self.config = config
        self.country = config["country"]
        self.run_date = config["run_date"]
        self.run_code = config["run_code"]
        self.version_code = config["version_code"]

        self.experiment_tracker = experiment_tracker

        self.data_manager = DataManager(
            data_sources_config=config["data_sources"],
            data_validation_config=config["data_validation"],
            data_cleaning_config=config["data_cleaning"],
            data_outputs_config=config["data_outputs"],
            env=env,
        )
        self.data_aggregator = None

        self.autopublish = autopublish
        if self.autopublish:
            assert model_name is not None, "Cannot autopublish without `model_name`!"
            self.publish_pipeline = PublishModelPipeline(
                config=config,
                experiment_tracker=experiment_tracker,
                model_version_code=self.version_code,
                model_name=model_name,
                env=env,
            )

    def __call__(self):
        """
        Runs the pipeline.
        """
        # Load, preprocess, clean data
        self.data_manager.load_validate_clean()
        data_dict = self.data_manager.get_data_dict()

        # Load External RCs
        summary_df = data_dict.get("external_response_curve_summary")
        extrcs_df = data_dict.get("external_response_curve_detail")

        # PATCH: need to change DMT tables to use specialty code, without extra
        # "i"
        extrcs_df.rename(
            columns={"specialty_code": "speciality_code", "segment": "segment_value"},
            inplace=True,
        )

        # PATCH: Pipeline expects GM adjusted incremental sales.
        summary_df["total_gm_incremental_sales"] = (
            summary_df["total_incremental_sales"] * summary_df["gm_of_sell_out"]
        )
        summary_df.drop("total_incremental_sales", axis=1, inplace=True)

        # PATCH: not provided in DE pipeline yet.
        extrcs_df["segment_code"] = "potential_qs__c"

        summary_df.columns = [c.lower() for c in summary_df.columns]

        for date_col in ["start_date", "end_date", "created_ts"]:
            summary_df[date_col] = (summary_df[date_col].apply(pd.Timestamp)).dt.tz_localize("UTC")
        extrcs_df.columns = [c.lower() for c in extrcs_df.columns]

        # ---------------------------------------------------------

        extrcs_df = self.preprocess(extrcs_df, summary_df)
        extrcs_df = self.apply_normalization(extrcs_df)
        self.check_consistency(extrcs_df)

        (
            response_curve_table,
            model_settings_table,
            regression_metrics_table,
        ) = self.postprocess(extrcs_df)

        self.save_to_dmt(
            response_curve_table=response_curve_table,
            model_settings_table=model_settings_table,
            regression_metrics_table=regression_metrics_table,
        )

        if self.autopublish:
            self.publish_pipeline()

    def preprocess(self, extrcs_df: pd.DataFrame, summary_df: pd.DataFrame):
        """
        Perform some simple calculations on extrcs.
        """
        return preprocess_external_curve(extrcs_df=extrcs_df, summary_df=summary_df)

    def apply_normalization(self, extrcs_df: pd.DataFrame):
        """
        Apply Normalization on External Response Curves
        This is required before saving External Rcs on DMT Response Curve Table
        """
        return normalize_external_curve(extrcs_df)

    def check_consistency(self, extrcs_df: pd.DataFrame):
        """
        Apply Consistency Checkers on External Response Curve Dataframe
        before saving data on DMT EXTERNAL_RESPONSE_CURVE Snowflake Table
        """
        check_external_curve_consistency(extrcs_df)

    def postprocess(self, extrcs_df: pd.DataFrame):
        """
        Format the tables to save format (melt)

        Response curve table: table containing curves
        Model settings table: containing settings (adstock, threshold, etc.)
        Regression metrics table: R2, MAPE, etc.
        """
        # version code to identify curve
        extrcs_df["version_code"] = self.version_code

        # columns that identify the curve
        id_cols = [
            "internal_response_code",
            "gbu_code",
            "market_code",
            "brand_name",
            "channel_code",
            "speciality_code",
            "segment_code",
            "segment_value",
            "start_date",
            "end_date",
            "created_ts",
            "version_code",
        ]

        response_curve_table = extrcs_df.melt(
            id_vars=id_cols
            + [
                "spend",
                "uplift",
                "incremental_sell_out_units",
                "gm_adjusted_incremental_value_sales",
            ],
            value_vars=[
                "price_per_unit",
                "currency",
                "gm_of_sell_out",
                "total_units",
                "total_net_sales",
                "total_incremental_units",
                "total_gm_incremental_sales",
            ],
            var_name="metric",
        )

        model_settings_table = extrcs_df.melt(
            id_vars=id_cols,
            value_vars=[
                "threshold_model",
                "saturation_model",
            ],
            var_name="setting",
        ).drop_duplicates()

        regression_metrics_table = extrcs_df.melt(
            id_vars=id_cols,
            value_vars=[
                "r2_model",
                "mape_model",
            ],
            var_name="metric",
        ).drop_duplicates()

        return response_curve_table, model_settings_table, regression_metrics_table

    def save_to_dmt(
        self,
        response_curve_table: pd.DataFrame = None,
        model_settings_table: pd.DataFrame = None,  # pylint:disable=unused-argument
        regression_metrics_table: pd.DataFrame = None,  # pylint:disable=unused-argument
    ):
        """
        Save information from the external response curves.
        """
        # map table name (from save locations config) to df
        table_mapping = {
            "response_curve": response_curve_table,
            # TODO: NOT USED YET, NEED TO REFACTOR
            # "model_settings": model_settings_table,
            # "regression_metric": regression_metrics_table,
        }

        for table_name, df in table_mapping.items():
            # cast value column (from melt) to string
            # for consistent dtype
            df["value"] = df["value"].astype(str)

            # Uppercase for standard databases
            df.columns = [c.upper() for c in df.columns]

            self.data_manager.save_table(df, table_name)

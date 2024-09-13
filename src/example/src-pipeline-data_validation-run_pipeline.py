"""
End-to-end Data Validation Checks...
"""
import os
from typing import Dict

import nbformat
import pandas as pd
from nbconvert.preprocessors import ExecutePreprocessor

from src.pipeline.response_model.brick_breaking.run_pipeline import (
    BrickBreakingPipeline,
)
from src.utils.data.data_manager import DataManager
from src.utils.experiment_tracking import BaseTracker


# pylint:disable=too-few-public-methods
class DataValidationChecksPipeline:
    """
    Pipeline object to Data Validation Checks

    Steps:
        - Load Required Data for Analysis
        - Generate Analysis
    """

    def __init__(
        self,
        config: Dict,
        experiment_tracker: BaseTracker,
        internal_response_code: str,
        **kwargs,  # pylint: disable=unused-argument
    ):
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
        self.experiment_tracker = experiment_tracker

        self.data_manager = DataManager(
            data_sources_config=config["data_sources"],
            data_validation_config=config["data_validation"],
            data_cleaning_config=config["data_cleaning"],
            data_outputs_config=config["data_outputs"],
        )
        self.data_aggregator = None

    def __call__(self):
        """
        Runs the pipeline.
        """
        # Load, preprocess, clean data
        self.data_manager.load_validate_clean()
        self.data_loading()
        self.load_sell_out_data()
        self.get_validation_report()  # validation report

    def data_loading(self):
        # Load, preprocess, clean data
        self.data_manager.load_validate_clean()
        self.data_dict = self.data_manager.get_data_dict()

        # changes in the data received to comply witht the code
        self.data_dict["touchpoint_facts"]["value"] = self.data_dict["touchpoint_facts"][
            "value"
        ].abs()
        self.data_dict["product_master"].level = self.data_dict["product_master"].level.replace(
            ["BRAND"], "brand_name"
        )
        self.data_dict["touchpoint_facts"]["metric"] = "spend_value"

        # self.data_dict['media_execution']["internal_touchpoint_code"] = self.data_dict['media_execution']["internal_channel_code"]
        self.data_dict["geo_master"].drop_duplicates(
            subset=["internal_geo_code"], keep="last", inplace=True, ignore_index=True
        )

    def load_sell_out_data(self):
        result = self.brick_breaking()
        result.columns = result.columns.str.lower()
        result = result[
            (result["brand_code"] == "14e72dfac4ed1add9f9a4d4b92074130")
            & (result["period_start"] >= "2021-01-01")
            & (result["period_start"] <= "2022-11-01")
        ]
        # result['brand_name'] = self.config.get("BRANDS_NAME")[0]
        result["brand_name"] = "Hexyon"
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

    def get_validation_report(self):
        for k in self.data_dict:
            if k in self.config["input_validation"]["tables"]:
                path = os.getcwd()
                self.data_dict[k].to_csv(
                    f"{path}/src/pipeline/data_validation/output/{k}.csv", index=False
                )
        filename = path + "/src/pipeline/data_validation/data_validation.ipynb"
        with open(filename) as ff:
            nb_in = nbformat.read(ff, nbformat.NO_CONVERT)
        ep = ExecutePreprocessor(timeout=600, kernel_name="python3")
        nb_out = ep.preprocess(nb_in)

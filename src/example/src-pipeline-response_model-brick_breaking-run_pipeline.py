"""
Pipeline to demonstrate the use of the brick breaking modules.
"""
from typing import Dict

from src.pipeline.response_model.brick_breaking.brick_breaker import BrickBreaker
from src.pipeline.response_model.brick_breaking.mrds_builder import MRDSBuilder
from src.utils.data.data_manager import DataManager


class BrickBreakingPipeline:
    """
    Creates the MRDS dataframe and runs brick breaking.
    """

    # pylint: disable=unused-argument, too-few-public-methods
    def __init__(self, config: Dict, experiment_tracker, **kwargs):
        """
        Read config and initialize classes
        """
        self.config = config
        self.country = config["country"]
        self.run_date = config["run_date"]
        self.run_code = config["run_code"]
        self.version_code = config["version_code"]

        self.data_manager = DataManager(
            data_sources_config={},
            data_validation_config={},
            data_cleaning_config={},
            data_outputs_config=config["data_outputs"],
        )

        self.experiment_tracker = experiment_tracker

        self.dataset_builder = MRDSBuilder(
            config=config, experiment_tracker=experiment_tracker
        )

    def __call__(self, **kwargs):
        """
        1. Create dataset
        2. Brick break
        """

        self.experiment_tracker.log_dict(self.config, "config.yaml")

        mrds_df = self.dataset_builder.get_sales_allocation_mrds()

        brick_breaker = BrickBreaker(config=self.config, mrds_df=mrds_df)

        coefs_df, allocated_sales_df = brick_breaker.run_sales_allocation()

        coefs_df["version_code"] = self.version_code
        allocated_sales_df["version_code"] = self.version_code
        self.data_manager.save_table(coefs_df, "sales_allocation_coefficients")
        self.data_manager.save_table(allocated_sales_df, "sales_allocation")
        return allocated_sales_df

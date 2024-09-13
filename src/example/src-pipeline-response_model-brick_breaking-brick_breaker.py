"""
Use the Turing SalesAllocation library to allocate sales
"""

import logging
from collections import defaultdict
from copy import deepcopy
from typing import Dict

import mlflow
import pandas as pd

from src.lib.sales_allocation.turing_sales_allocation.modelling.sales_allocation import (
    SalesAllocationModelling,
)

# TODO: just for using the SalesAllocation regression lib
logger = logging.getLogger()
logger.setLevel("INFO")


# pylint:disable=too-few-public-methods
class BrickBreaker:
    """
    Class to apply the SalesAllocation library and allocate sales based on coefficients
    """

    def __init__(self, config: Dict, mrds_df: pd.DataFrame):
        """
        Read the config and the dataframe.
        """

        self.config = config
        self.modelling_config = deepcopy(config["modelling"])
        self.mrds_index = mrds_df.index.names
        self.mrds_df = mrds_df.reset_index().copy()

    # pylint: disable=too-many-locals
    def run_sales_allocation(self):
        """
        Applies the sales allocation.

        Returns:
            coefs_dict: Dictionary of normalized coefficients applied to allocate sales.
            allocated_sales_df: Dataframe with allocated sales value, for each
                internal_geo_code x brand_code x specialty_code x period_start
        """
        coefs_dict = defaultdict(dict)
        allocated_sales_df = []

        if len(self.config["features"]) == 1:
            feat = self.config["features"][0]["segment_code"]
        else:  # 2 features to combine
            feat = f"{self.config['features'][0]['name']}_{self.config['features'][1]['name']}"

        for year in self.config["years"]:
            # Create SalesALlocation model
            model_config_with_feat = self._update_modelling_config_features(
                self.modelling_config, feat
            )
            allocation_model = SalesAllocationModelling(logger, model_config_with_feat)

            iter_df = self.mrds_df[self.mrds_df["period_start"].str.startswith(str(year))].copy()

            date_range = [{"start_date": f"{year}-01-01", "end_date": f"{year}-12-31"}]

            best_model = allocation_model.get_model(iter_df, date_range)

            if best_model is None:
                print("Unable to get coefficients for " f"year {year} x segment type {feat}")
                continue

            model_coefs = {
                k: v for k, v in best_model["coeffcient_dict"].items() if f"/{feat}/" in k
            }

            # Allocate the sales using the coefficients.
            alloc_df = iter_df[
                [
                    *self.mrds_index,
                    self.modelling_config["DATA"]["TARGET_COL"],
                    "sales_volume",
                    *model_coefs.keys(),  # each col is HCP count for a feature value
                ]
            ].copy()

            # Normalize so that the total allocated sales == original sales
            # To allocate sales using a feature with n possible values V = {v_1, v_2, v_3, ...v_n}
            # The sales allocated to the ith group of HCPs with `n_i` HCPs and coefficient `c_i` is:
            # (n_i * c_i) / [Σ_(1<j<=n)(n_i * c_i)]
            alloc_df["normalizer"] = 0
            for col, coef in model_coefs.items():
                alloc_df[col] = alloc_df[col].astype(float)
                alloc_df["normalizer"] = alloc_df["normalizer"] + alloc_df[col] * coef

            for col, coef in model_coefs.items():
                # column now represents tuple of (num_hcp, allocated sales,
                # allocated volume)
                alloc_df[col] = alloc_df.apply(
                    lambda row: (
                        row[col],
                        row[self.modelling_config["DATA"]["TARGET_COL"]]
                        * row[col]
                        * coef
                        / row["normalizer"],
                        row["sales_volume"] * row[col] * coef / row["normalizer"],
                    ),
                    axis=1,
                )

            # melt to lengthwise
            alloc_df = pd.melt(
                alloc_df,
                id_vars=[*self.mrds_index],
                value_vars=model_coefs.keys(),
                var_name="specialty_segment",
                value_name="allocation",
            )

            # extract segment, specialty into columns
            alloc_df["specialty_segment"] = alloc_df["specialty_segment"].str.split("/")
            alloc_df["specialty_code"] = alloc_df["specialty_segment"].apply(lambda x: x[0])
            alloc_df["segment_code"] = alloc_df["specialty_segment"].apply(lambda x: x[1])
            alloc_df["segment_value_lower"] = alloc_df["specialty_segment"].apply(lambda x: x[2])
            alloc_df = alloc_df.drop("specialty_segment", axis=1)

            # unpack the tuple
            alloc_df["num_hcp"] = alloc_df["allocation"].apply(lambda x: x[0])
            alloc_df[self.modelling_config["DATA"]["TARGET_COL"]] = alloc_df["allocation"].apply(
                lambda x: x[1]
            )
            alloc_df["sales_volume"] = alloc_df["allocation"].apply(lambda x: x[2])
            alloc_df = alloc_df.drop("allocation", axis=1)

            allocated_sales_df.append(alloc_df)

            coefs_dict[year][feat] = model_coefs

            # The SalesALlocation library internally uses mlflow...
            # which causes issues with this loop - end run every iteration
            mlflow.end_run()

        allocated_sales_df = pd.concat(allocated_sales_df)
        allocated_sales_df["period_start"] = allocated_sales_df["period_start"].dt.strftime(
            date_format=r"%Y-%m-%d"
        )

        return self._coef_dict_to_df(coefs_dict), allocated_sales_df

    def _update_modelling_config_features(self, modelling_config, feature):
        """
        Update the modelling config to use the one-hot encoded values for a given feature
        so that it is compatible with the SalesAllocation library.
        """
        temp_config_with_feature = deepcopy(modelling_config)

        temp_config_with_feature["DATA"] = temp_config_with_feature.get("DATA", {})
        temp_config_with_feature["DATA"]["FEATURE_LIST"] = temp_config_with_feature["DATA"].get(
            "FEATURE_LIST", {}
        )
        temp_config_with_feature["DATA"]["FEATURE_LIST"].update(
            {feature: [c for c in self.mrds_df.columns if f"/{feature}/" in c]}
        )

        return temp_config_with_feature

    # pylint: disable=no-self-use
    def _coef_dict_to_df(self, coef_dict):
        """
        Coefficients dictionary has nested structure
        {
            `year` (int): {
                `specialty_code` (str): {
                    `segment_code` (str):{
                        `segment_value_lower` (str): coef (float)
                    }
                }
            }
        }

        We want to turn into a dataframe so we can store it in snowflake.
        """
        records = []
        for year, year_dict in coef_dict.items():
            for segment_code, segment_code_dict in year_dict.items():
                for k, coef in segment_code_dict.items():
                    spec_code, _, seg_val = k.split("/")
                    records.append(
                        (
                            year,
                            spec_code,
                            segment_code,
                            seg_val,
                            coef,
                        )
                    )

        return pd.DataFrame.from_records(
            records,
            columns=[
                "year",
                "specialty_code",
                "segment_code",
                "segment_value_lower",
                "normalized_sales_coefficient",
            ],
        )

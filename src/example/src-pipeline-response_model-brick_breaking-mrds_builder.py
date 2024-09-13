"""
Base MRDS Builder class.
Creates a dataset that can be used with Turing Brick Breaking library.
"""
from typing import Dict

import pandas as pd

from src.utils.snowflake_utils import mmx_snowflake_connection


# pylint: disable=too-few-public-methods
class MRDSBuilder:
    """
    Class to build MRDS dataframe.
    """

    def __init__(self, config: Dict, experiment_tracker):
        """
        Read the config
        """
        self.config = config
        if isinstance(config["features"], list):
            assert len(config["features"]) in (1, 2), "Can only use 1 or 2 features"
            self.features = config["features"]
        else:
            self.features = [config["features"]]
        self.experiment_tracker = experiment_tracker

    # pylint: disable=too-many-locals, too-many-statements, too-many-branches
    def get_sales_allocation_mrds(self) -> pd.DataFrame:
        """
        Method to get the MRDS dataset.
        """
        if len(self.config["specialty_codes"]) > 1:
            specialty_codes_filter = "IN " + str(tuple(self.config["specialty_codes"]))
        else:
            specialty_codes_filter = f"= '{self.config['specialty_codes'][0]}'"

        if len(self.config["years"]) > 1:
            year_filter = "IN " + str(tuple(self.config["years"]))
        else:
            year_filter = f"= '{self.config['years'][0]}'"

        # Get the list of possible feature values to pivot on, for each
        # feature.
        segment_vals_by_feature = {}
        for feature_dict in self.features:
            feat_name = feature_dict["name"]
            segment_vals_by_feature[feat_name] = {}
            segment_value_filter = feature_dict.get("allowed_values")

            if segment_value_filter is None:
                segment_vals_by_feature[feat_name]["filter"] = ""
            elif len(segment_value_filter) > 1:
                segment_vals_by_feature[feat_name]["filter"] = "AND sm.segment_value IN " + str(
                    tuple(segment_value_filter)
                )
            else:
                segment_vals_by_feature[feat_name]["filter"] = (
                    "AND sm.segment_value = " + segment_value_filter[0]
                )

            with open("src/pipeline/response_model/brick_breaking/sql/segments_generic.sql") as f:
                q = f.read().format(
                    segment_code_filter=feature_dict["segment_code"],
                    specialty_codes_filter=specialty_codes_filter,
                    segment_value_filter=segment_vals_by_feature[feat_name]["filter"],
                )
                segment_vals = self._run_query(q)
                assert len(segment_vals) > 0, f"No valid values for {feat_name}"

                segment_vals_by_feature[feat_name]["tuple"] = tuple(segment_vals["VALS"])
                segment_vals_by_feature[feat_name]["string"] = str(
                    segment_vals_by_feature[feat_name]["tuple"]
                )
                segment_vals_by_feature[feat_name]["list"] = ", ".join(
                    (f"\"'{x}'\"" for x in (segment_vals_by_feature[feat_name]["tuple"]))
                )

        # If we have multiple features, combine them to make a combined
        # segment.
        if len(self.features) > 1:
            combined_feat_name = f"{self.features[0]['name']}_{self.features[1]['name']}"
            segment_vals_by_feature[combined_feat_name] = {}

            with open(
                "src/pipeline/response_model/brick_breaking/sql/combined_segment_generic.sql",
                "r",
            ) as f:
                q = f.read().format(
                    specialty_codes_filter=specialty_codes_filter,
                    feature_1=self.features[0]["segment_code"],
                    segment_value_filter_1=segment_vals_by_feature[self.features[0]["name"]][
                        "filter"
                    ],
                    feature_2=self.features[1]["segment_code"],
                    segment_value_filter_2=segment_vals_by_feature[self.features[1]["name"]][
                        "filter"
                    ],
                    combined_feat_name=combined_feat_name,
                )
                segment_vals = self._run_query(q)
                segment_vals_by_feature[combined_feat_name]["tuple"] = tuple(segment_vals["VALS"])
                segment_vals_by_feature[combined_feat_name]["string"] = str(
                    segment_vals_by_feature[combined_feat_name]["tuple"]
                )
                segment_vals_by_feature[combined_feat_name]["list"] = ", ".join(
                    (f"\"'{x}'\"" for x in (segment_vals_by_feature[combined_feat_name]["tuple"]))
                )

        # Build and Run the main SQL
        mrds_query_parts = {}

        if len(self.features) == 1:
            feature_cols_index = self.features[0]["name"]
        else:
            feature_cols_index = f"{self.features[0]['name']}_{self.features[1]['name']}"

        mrds_query_parts["sum_hcp_counts_clause"] = ", ".join(
            [
                f"SUM(\"'{col}'\" * num_hcp) AS \"'{col}'\""
                for col in segment_vals_by_feature[feature_cols_index]["tuple"]
            ]
        )
        mrds_query_parts["all_feature_columns_plain_list"] = segment_vals_by_feature[
            feature_cols_index
        ]["list"]

        if len(self.features) == 1:
            feature_dict = self.features[0]
            feat_name = feature_dict["name"]
            with open(
                "src/pipeline/response_model/brick_breaking/sql/mrds_segment_pivot.sql",
                "r",
            ) as f:
                mrds_query_parts["segment_pivot"] = f.read().format(
                    feature_name=feat_name,
                    feature_segment_values=segment_vals_by_feature[feat_name]["string"],
                    feature_segment_filter=segment_vals_by_feature[feat_name]["filter"],
                    specialty_codes_filter=specialty_codes_filter,
                    brand_code=self.config["brand_code"],
                )

            mrds_query_parts["join_segment_pivot"] = (
                f"JOIN {feat_name}_segment_pivot sp" " ON hm.hcp_code = sp.hcp_code"
            )

        else:
            combined_feat_name = f"{self.features[0]['name']}_{self.features[1]['name']}"
            with open(
                "src/pipeline/response_model/brick_breaking/sql/mrds_combined_segment_pivot.sql",
                "r",
            ) as f:
                mrds_query_parts["segment_pivot"] = f.read().format(
                    feature_1=self.features[0]["segment_code"],
                    feature_2=self.features[1]["segment_code"],
                    brand_code=self.config["brand_code"],
                    specialty_codes_filter=specialty_codes_filter,
                    segment_value_filter_1=segment_vals_by_feature[self.features[0]["name"]][
                        "filter"
                    ],
                    segment_value_filter_2=segment_vals_by_feature[self.features[1]["name"]][
                        "filter"
                    ],
                    combined_feat_name=combined_feat_name,
                    combined_segment_values=segment_vals_by_feature[combined_feat_name]["string"],
                )

            mrds_query_parts[
                "join_segment_pivot"
            ] = "JOIN combined_segment_pivot sp ON hm.hcp_code = sp.hcp_code"

        with open("src/pipeline/response_model/brick_breaking/sql/mrds.sql", "r") as f:
            q = f.read().format(
                segment_pivot=mrds_query_parts["segment_pivot"],
                all_feature_columns_plain_list=mrds_query_parts["all_feature_columns_plain_list"],
                join_segment_pivot=mrds_query_parts["join_segment_pivot"],
                sum_hcp_counts_clause=mrds_query_parts["sum_hcp_counts_clause"],
                brand_code=self.config["brand_code"],
                market_code=self.config["country"],
                specialty_codes_filter=specialty_codes_filter,
                year_filter=year_filter,
            )

        self.experiment_tracker.log_text(q, "mrds.sql")

        mrds_df = self._run_query(q)
        assert not mrds_df.empty, "No Sales Data!"

        # simple preprocessing
        mrds_df.columns = [c.lower() for c in mrds_df.columns]

        # Strip characters that cannot be used in MLFlow (brick breaking
        # library)
        mrds_df.columns = [c.replace("'", "").replace("|", "/") for c in mrds_df.columns]
        mrds_df.columns = [self._strip_noncompatible_characters(c) for c in mrds_df.columns]

        mrds_df = mrds_df.fillna(0)
        mrds_df["period_start"] = pd.to_datetime(mrds_df["period_start"]).dt.strftime("%Y%m")

        mrds_df = mrds_df.set_index(
            [
                "sales_channel_code",
                "internal_geo_code",
                "brand_code",
                "period_start",
                "currency",
            ]
        )

        return mrds_df

    # pylint: disable=no-self-use
    def _run_query(self, query):
        """
        TODO: move this to utils.
        """
        try:
            connection = mmx_snowflake_connection()
            cur = connection.cursor()
            cur.execute(query)
            df = cur.fetch_pandas_all()
        finally:
            connection.close()

        return df

    # pylint: disable=no-self-use
    def _strip_noncompatible_characters(self, s):
        """
        The MLFlow code in the brick breaking library does not work when the column names
        (containing specialty / segment_code / segment_value) have some special characters

        Use this helper to strip the values.
        """
        chars_to_strip = "()"

        for c in chars_to_strip:
            s = s.replace(c, "")

        return s

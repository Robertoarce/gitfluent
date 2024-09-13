from dataclasses import dataclass

import pandas as pd

from src.pipeline.response_model.utils import stan_response_level
from src.utils.normalization import TransformationParams, model_inputs_dict
from src.utils.schemas.response_model.input import GeoMasterSchema, ProductMasterSchema
from src.utils.settings_utils import get_feature_from_name

gs = GeoMasterSchema()
pms = ProductMasterSchema()


AGGREGATION_POLICY = {
    # "distribution": "mean",
    "relative_gap_to_90th_price": "mean",
    "average_selling_price": "mean",
    "basic_average_selling_price": "mean",
    # "ref_90th_price": "mean",
    "distribution_points": "mean",
    "volume": "sum",
    "value": "sum",
    "channel_code": "first",
}


@dataclass
class ChannelFeature:

    """
    This class stores the dataframes and objects required to run the response model. The feature df and normalized
    features df are the dataframes of features, and transformation_params is the object allowing to go to one to another
    It also contains methods to get national features df
    """

    features_df: pd.DataFrame()
    normalized_features_df: pd.DataFrame()
    transformation_params: TransformationParams
    channel_code: str

    def __init__(
        self,
        features_df,
        normalized_features_df,
        transformation_params,
        channel_code,
        config,
    ):
        self.features_df = features_df
        self.normalized_features_df = normalized_features_df
        self.transformation_params = transformation_params
        self.channel_code = channel_code
        self.config = config

    @property
    def columns_aggregation_dict(self):
        """
        This method creates the aggregation dict for the features_df to go from regional to national level. The rules
        are the following :
        - by default, we take the first value for each features
        - then for each feature that has the granularity parameter and is therefore at regional level, we aggregate
        using a summation
        - finally, for some special columns, such as distribution or price, we take special aggregation functions,
        defined in the AGGREGATION_policy dict.
        :return: aggregation dict, to be applied to the features_df
        """
        agg_dict = {
            col: "first"
            for col in self.features_df.columns
            if col not in stan_response_level(self.config)
        }

        for touchpoint, params in model_inputs_dict(self.config)[
            self.channel_code
        ].items():
            if params.get("granularity", "") in gs.get_column_names():
                agg_dict.update({get_feature_from_name(self.config, touchpoint): "sum"})

        agg_dict.update(
            {
                k: v
                for k, v in AGGREGATION_POLICY.items()
                if k in model_inputs_dict(self.config)[self.channel_code]
            }
        )

        return agg_dict

    @property
    def national_features_df(self):
        if self.features_df[gs.internal_geo_code].nunique() == 1:
            return self.features_df
        else:
            return (
                self.features_df.groupby(
                    [
                        self.config.get("RESPONSE_LEVEL_PRODUCT"),
                        self.config.get("RESPONSE_LEVEL_TIME"),
                    ],
                    as_index=False,
                )
                .agg(self.columns_aggregation_dict)
                .sort_values(
                    [
                        self.config.get("RESPONSE_LEVEL_PRODUCT"),
                        self.config.get("RESPONSE_LEVEL_TIME"),
                    ],
                    ascending=True,
                )
                .reset_index(drop=True)
            )

"""
Constructs media execution features
"""
import logging
from typing import List, Tuple

import pandas as pd

from src.pipeline.feature_engineering.price import response_level_for_touchpoint
from src.utils.names import (
    F_GEO_VALUE,
    F_GRP,
    F_IMPRESSIONS,
    F_PERIOD_START,
    F_PRODUCT_VALUE,
    F_VALUE,
)
from src.utils.schemas.response_model.output.response_curve import ResponseCurveSchema
from src.utils.settings_utils import get_spend_column

_EXECUTION_METRICS = (
    ("F2F", F_IMPRESSIONS),
    ("PHO", F_GRP),
    ("REM", F_GRP),
)


logger = logging.getLogger(__name__)

rcs = ResponseCurveSchema()


def construct_media_execution_features(
    config,
    spend_media_execution_df: pd.DataFrame,
    touchpoints_media: List[str],
    channel_code: str,
) -> Tuple[List, List]:
    """
    Build relevant media_execution features (based on execution spend for now)
    """
    spend_media_execution_df["response_touchpoint"] = spend_media_execution_df[
        "channel_code"
    ].str.lower()

    cols_response_level = response_level_for_touchpoint(config, touchpoints_media, channel_code)

    spend_media_execution_df = spend_media_execution_df.rename(
        columns={
            F_GEO_VALUE: config.get("RESPONSE_LEVEL_GEO"),
            F_PRODUCT_VALUE: config.get("RESPONSE_LEVEL_PRODUCT"),
            F_PERIOD_START: config.get("RESPONSE_LEVEL_TIME"),
        }
    )

    spend_media_execution_df[config.get("RESPONSE_LEVEL_TIME")] = (
        pd.to_datetime(spend_media_execution_df[config.get("RESPONSE_LEVEL_TIME")])
        .dt.strftime("%Y%m")
        .astype(int)
    )

    # Initialize list of dataframes with empty dataframe, for index reference
    features = []

    for touchpoint, media_touchpoint_df in spend_media_execution_df.groupby(
        [rcs.response_touchpoint]
    ):
        feature_df = (
            media_touchpoint_df.groupby(cols_response_level, as_index=False)
            .agg({F_VALUE: "sum"})
            .rename(columns={F_VALUE: get_spend_column(touchpoint)})
        )

        features.append(feature_df)

    return features, cols_response_level

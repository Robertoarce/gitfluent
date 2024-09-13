"""
Utility functions specific for response curve.
"""
import pandas as pd

from src.utils.names import (
    F_CAAP,
    F_CHANNEL_CODE,
    F_DELTA_TO_NULL_REVENUES,
    F_DELTA_TO_NULL_VOLUME,
    F_IS_FISCAL_YEAR,
    F_IS_REFERENCE_OPTIMIZER,
    F_SELL_OUT,
    F_SPEND,
    F_TOUCHPOINT,
    F_UPLIFT,
    F_VOLUME,
    F_VOLUME_PRED,
    F_YEAR,
    F_YEAR_CALENDAR,
    F_YEAR_FISCAL,
    F_DELTA_TO_NULL_VALUE,
    F_VALUE,
    F_VALUE_PRED,
)
from src.utils.schemas.response_model.input.product_master import (
    ProductMasterSchema as pms,
)


def add_total_metrics(df, response_level_time) -> pd.DataFrame:
    """
    Function aggregating multiple channels into one overall channel. The function only sums
    additive metrics, and adds a new channel to the input dataframe, called "all" as for
    "all channels". This channels is then used in several operations. If there is only one
    channel, then this channel is renamed to all, so that we have only one channel output.
    Aggregation policy is basic, but could be extended if needed in further developments
    """

    if df[F_CHANNEL_CODE].nunique() == 1:
        df[F_CHANNEL_CODE] = "all"
        return df

    aggregation_level = [
        response_level_time,
        "brand_name",
        # pms.internal_product_code,
        F_TOUCHPOINT,
        F_YEAR_CALENDAR,
        F_YEAR_FISCAL,
        F_UPLIFT,
    ]
    aggregation_level = [col for col in aggregation_level if col in df.columns]

    aggregation_policy = {
        F_VOLUME: "sum",
        F_SPEND: "first",
        F_VOLUME_PRED: "sum",
        F_DELTA_TO_NULL_VOLUME: "sum",
        F_DELTA_TO_NULL_REVENUES: "sum",
        F_CAAP: "sum",
        F_SELL_OUT: "sum",
        "contribution_margin": "sum",
        F_VALUE: "sum",
        F_VALUE_PRED: "sum",
        F_DELTA_TO_NULL_VALUE: "sum"
    }
    aggregation_policy = {
        k + suffix: v
        for k, v in aggregation_policy.items()
        for suffix in ["", "_p10", "_p90"]
    }

    output = df.groupby(aggregation_level, as_index=False).agg(
        {k: v for k, v in aggregation_policy.items() if k in df.columns}
    )
    output[F_CHANNEL_CODE] = "all"

    output = pd.concat([df, output], axis=0, sort=False).reset_index(drop=True)

    return output


def add_year_info_columns(data_df, response_curves_manager, config):
    """
    Update the current dataframe to add year information:
        - the type of run (fiscal or calendar)
        - the year (according to the type of run)
        - identify the year used in the optimizer
    """
    data_df[F_YEAR] = data_df[response_curves_manager.column_year]
    data_df[F_IS_FISCAL_YEAR] = response_curves_manager.is_fiscal_year_response_curve
    data_df[F_IS_REFERENCE_OPTIMIZER] = (
        data_df[F_YEAR] == config.get("RESPONSE_CURVE_YEAR_OPTIMIZER")
    )
    return data_df

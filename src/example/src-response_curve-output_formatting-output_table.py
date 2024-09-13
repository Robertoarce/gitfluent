"""
Module for creating and formatting the response curve output table
"""
from collections import ChainMap

# import numpy as np
import pandas as pd

from src.response_curve.output_formatting.utils import (
    add_total_metrics,
    add_year_info_columns,
)
from src.utils.names import F_CHANNEL_CODE, F_TOUCHPOINT, F_VALUE, F_YEAR
from src.utils.schemas.response_model.output.response_curve import ResponseCurveSchema

rcs = ResponseCurveSchema()


def add_response_curve_metrics(pred_vs_actual_df, df, config):
    """Returns dataframe with additional columns contatining key metrics outlined below:
    1. Total spend
    2. Toal net sales
    3. GM of sell out
    4. Currency
    5. Total GM incremental sales

    Arguments:
        df {[pd.DataFrame]} -- [Response curve dataframe contatining sales
                         and interactions detail per uplift]

    Returns:
        [pd.DatFrame] -- [output dataframe]
    """

    filtered_df = df[
        ["calendar_year", "uplift", "value_f_denorm", "spend", "delta_to_null_value"]
    ].copy()
    grouped_df = (
        filtered_df.groupby(["calendar_year", "uplift"])
        .agg({"value_f_denorm": "mean", "spend": "sum", "delta_to_null_value": "sum"})
        .reset_index()
    )

    # Filter records where B equals 1 for each A
    filtered_df = grouped_df[grouped_df["uplift"] == 1]

    pred_vs_actual_df["calendar_year"] = pred_vs_actual_df["year_month"].map(
        lambda x: int(str(x)[:4])
    )
    # Total sales are taken from acutals dataframe instead of model fitted values. 
    total_sales_dict = pred_vs_actual_df.groupby("calendar_year")["value"].sum().to_dict()
    # total_sales_dict = filtered_df.groupby("calendar_year")["value_f_denorm"].sum().to_dict()

    interaction_dict = filtered_df.groupby("calendar_year")["spend"].sum().to_dict()
    # base_sales_dict = filtered_df.groupby('calendar_year')['delta_to_null_value'].sum().to_dict()
    # incremental_sales_dict = {}
    # for k,v in total_sales_dict:
    #     incremental_sales_dict[k] = v - base_sales_dict[k]

    # Create a new column 'D' in the original DataFrame
    df["total_net_sales"] = df["year"].map(total_sales_dict)
    df["total_spend"] = df["year"].map(interaction_dict)
    df["gm_of_sell_out"] = config.get("gm_of_sell_out")
    df["currency"] = config.get("CURRENCY")

    # df['incremental_sales'] = df['year'].map(incremental_sales_dict)
    df["total_gm_incremental_sales"] = df["delta_to_null_value"] * config.get("gm_of_sell_out")
    # df.drop('incremental_sales', inplace=True)

    df["incremental_sell_out_units"] = df["value_f_denorm"]
    df["gm_adjusted_incremental_value_sales"] = (
        config.get("gm_of_sell_out") * df["delta_to_null_value"]
    )

    return df


def create_st_response_curve_output_table(
    pred_vs_actual_df,
    roi_table_df,
    national_features_df,
    lambda_adstock_df,
    response_curves_manager,
    config,
    data_aggregator,
):
    """
    Main S.T. Response curve output table (i.e. response curves per se)
    """
    column_year = response_curves_manager.column_year
    reference_response_curve_df = add_year_info_columns(
        data_df=roi_table_df.copy(),
        response_curves_manager=response_curves_manager,
        config=config,
    )
    reference_response_curve_df = add_response_curve_metrics(
        pred_vs_actual_df, reference_response_curve_df, config
    )
    # --- Add actual sell-out Value ---
    value_per_year = response_curves_manager.add_year(data_df=national_features_df.copy())
    value_per_year = value_per_year.groupby(
        [F_CHANNEL_CODE, "brand_name", column_year],
        as_index=False,
    )[F_VALUE].sum()
    value_per_year = add_total_metrics(value_per_year, config.get("RESPONSE_LEVEL_TIME"))

    reference_response_curve_df = reference_response_curve_df.merge(
        value_per_year.rename(columns={column_year: F_YEAR}),
        on=[F_CHANNEL_CODE, "brand_name", F_YEAR],
    )

    # --- Add lambda adstock ---
    reference_response_curve_df = reference_response_curve_df.merge(
        lambda_adstock_df, on=[F_CHANNEL_CODE, F_TOUCHPOINT], how="left"
    )

    reference_response_curve_df[rcs.filter_out] = False

    reference_response_curve_df = _format_st_response_curve_output(
        reference_response_curve_df, config, data_aggregator
    )
    return reference_response_curve_df


def _format_st_response_curve_output(
    reference_response_curve_df,
    config,
    data_aggregator=None,
):
    """
    docstring
    """
    formatted_response_curves = reference_response_curve_df.copy()

    # Initialize config model attributes
    # currency = config.get("CURRENCY") #'EUR'  #TODO: Dip - update this line
    # to get currency dynamically from the db tables
    internal_geo_code = config.get(
        "GEO_LEVEL"
    )  # "national" #config.scope.attributes.internal_response_geo_code

    # Formatting touchpoint granularity
    formatted_response_curves = formatted_response_curves.rename(
        columns={F_TOUCHPOINT: rcs.response_touchpoint}
    )

    if data_aggregator:
        # Create strategic touchpoint mapping
        data_aggregator.set_strategic_touchpoint_mapping()
        strategic_touchpoint_mapping = data_aggregator.strategic_touchpoint_mapping

        formatted_response_curves[rcs.internal_strat_touchpoint_code] = formatted_response_curves[
            rcs.response_touchpoint
        ].map(strategic_touchpoint_mapping)
    else:
        formatted_response_curves[rcs.internal_strat_touchpoint_code] = None

    # Formatting time granularity
    formatted_response_curves[rcs.frequency] = config.get("FREQUENCY")
    formatted_response_curves[rcs.period_start] = pd.to_datetime(
        formatted_response_curves["year"].astype(int).astype(str) + "-01-01",
        format="%Y-%m-%d",
    )

    formatted_response_curves[rcs.internal_geo_code] = internal_geo_code
    formatted_response_curves[rcs.internal_response_geo_code] = internal_geo_code
    formatted_response_curves[rcs.curve_type] = "tactic"

    # Formatting table
    idx = [
        rcs.channel_code,
        rcs.internal_geo_code,
        "brand_name",
        rcs.response_touchpoint,
        rcs.internal_strat_touchpoint_code,
        rcs.frequency,
        rcs.period_start,
        rcs.uplift,
        rcs.spend,
        rcs.baseline_value,
        rcs.filter_out,
        rcs.curve_type,
        rcs.internal_response_geo_code,
        rcs.incremental_sell_out_units,
        rcs.gm_adjusted_incremental_value_sales,
    ]

    values_units = dict(ChainMap(*config.get("values_units")))

    # TODO find a dynamic way to remove unecessary fields
    formatted_response_curves = formatted_response_curves.drop(
        columns=[
            "brand",
            "sub_brand",
            "year",
            "is_fiscal_year",
            "is_reference_optimizer",
            "calendar_year",
            "fiscal_year",
            "delta_to_null_revenues",
            "delta_to_null_revenues_p10",
            "delta_to_null_revenues_p90",
            "feature",
            "value_f_denorm",
            "contribution_margin_p10",
            "contribution_margin",
            "contribution_margin_p90",
            "ros",  # TODO: Dip - Added new entries from here..These entries are old metric values
            "ros_p10",
            "ros_p90",
            "roi",
            "roi_p10",
            "roi_p90",
            "mroi",
            "delta_to_null_value",
            "delta_to_null_value_p10",
            "delta_to_null_value_p90",
            "asp_per_unit",
            "net_sales_asp_per_unit",
            "contribution_margin_per_unit",
            "lambda_adstock",
        ],
        errors="ignore",
    )
    formatted_response_curves = formatted_response_curves.drop(
        "contribution_margin_p10", errors="ignore"
    )
    formatted_response_curves = formatted_response_curves.rename(
        columns={F_VALUE: rcs.baseline_value}
    )

    formatted_response_curves_long = pd.melt(
        formatted_response_curves,
        id_vars=idx,
        value_vars=formatted_response_curves.columns.difference(idx),
        var_name=rcs.metric,
        value_name=rcs.value,
    ).query(f"{rcs.value}.notnull()")

    formatted_response_curves_long[rcs.unit] = formatted_response_curves_long[rcs.metric].map(
        values_units
    )

    # formatted_response_curves_long[rcs.currency] = np.where(
    #     formatted_response_curves_long[rcs.unit] == "currency", currency, ""
    # )

    # rcs.validate(formatted_response_curves_long)     #TODO- DIP - UNCOMMENT
    # THIS LINE LATER
    formatted_response_curves_long = formatted_response_curves_long[rcs.get_column_names()]
    formatted_response_curves_long = rcs.cast(formatted_response_curves_long)
    return formatted_response_curves_long

"""
Functions to perform preprocessing on response curves.
"""
import pandas as pd

from src.pipeline.recommendation_engine.utils.normalization import (
    COLUMNS_TO_SCALE,
    normalize_curves,
)


def reco_engine_preprocessing(data_dict, config):
    """
    This function will perform preprocessing on the elements of the data dictionary.

    returns:
    - response_curve_df: Full response curves without projection
    - response_curve_reference_df: Uplift==1 without projection
    - response_curve_projected_df: Full response curves with projection
    - response_curves_reference_projected_df: Uplift==1 with projection
    """

    # Load RCs
    response_curves_df = data_dict["response_curve"]

    # Apply Pivot on RCs
    idx = [
        "market_code",
        "region_name",
        "brand_name",
        "channel_code",
        "speciality_code",
        "segment_code",
        "segment_value",
        "start_date",
        "end_date",
        "uplift",
        "spend",
        "gm_adjusted_incremental_value_sales",
    ]

    # units data is not always provided in the response curves.
    units_provided = (
        ~(response_curves_df["incremental_sell_out_units"].isna().any())
        and ("total_units" in response_curves_df["metric"].values)
        and ("total_incremental_units" in response_curves_df["metric"].values)
        and ("price_per_unit" in response_curves_df["metric"].values)
        and not (
            (
                response_curves_df[
                    response_curves_df["metric"].isin(
                        ["total_units", "total_incremental_units", "price_per_unit"]
                    )
                ]["value"]
                == "nan"  # metrics are saved as strings in Snowflake
            ).any()
        )
    )

    if units_provided:
        idx.append("incremental_sell_out_units")

    # metrics are assumed to be unique for the entire curve (by idx)
    response_curves_df = response_curves_df.pivot_table(
        index=idx, columns="metric", values="value", aggfunc="first"
    ).reset_index()

    # metrics
    metrics = [
        "total_net_sales",
        "total_gm_incremental_sales",
        "gm_of_sell_out",
    ]
    if units_provided:
        metrics = metrics + ["total_units", "total_incremental_units", "price_per_unit"]

    for m in metrics:
        response_curves_df[m] = response_curves_df[m].astype(float)

    additional_required_columns = ["currency"]

    response_curves_df["baseline_sell_out_value"] = response_curves_df["total_net_sales"] - (
        response_curves_df["total_gm_incremental_sales"] / response_curves_df["gm_of_sell_out"]
    )
    additional_required_columns.append("baseline_sell_out_value")

    response_curves_df["incremental_sell_out_value"] = (
        response_curves_df["gm_adjusted_incremental_value_sales"]
        / response_curves_df["gm_of_sell_out"]
    )
    additional_required_columns.append("incremental_sell_out_value")

    if units_provided:
        response_curves_df["baseline_sell_out_units"] = (
            response_curves_df["total_units"] - response_curves_df["total_incremental_units"]
        )
        additional_required_columns.append("baseline_sell_out_units")

    # assign each uplift point on a curve an "index";
    # this is done so that the optimizer can have integer indexed keys.
    response_curves_df["curve_uplift_idx"] = (
        response_curves_df.sort_values(idx)
        .groupby(
            [
                "market_code",
                "brand_name",
                "channel_code",
                "speciality_code",
                "segment_code",
                "segment_value",
            ]
        )
        .cumcount()
    )
    additional_required_columns.append("curve_uplift_idx")

    # Only take the columns we need; for easy debugging
    required_cols = idx + metrics + additional_required_columns
    response_curves_df = response_curves_df[required_cols]

    # Normalization for optimizer numerical stability
    response_curves_df = normalize_curves(response_curves_df, config, pre=True)

    # freeze raw reference values before applying projection
    response_curves_reference_df = response_curves_df[response_curves_df["uplift"] == 1].copy()

    # Apply Projection
    response_curves_projected_df = apply_projection(
        response_curves_df.copy(), data_dict["projection_settings"]
    )

    # Save reference_projected_df before optimization
    response_curves_reference_projected_df = response_curves_projected_df[
        response_curves_df["uplift"] == 1
    ].copy()

    return (
        response_curves_df,
        response_curves_reference_df,
        response_curves_projected_df,
        response_curves_reference_projected_df,
    )


def _projection_months(curves_df, n_months):
    """
    Apply the projection setting given by API_AVAILABLE_PROJECTION_SETTING_MONTHS_FACTOR.N_MONTHS

    Given a set of response curves with modelling period of m months, scale the curves by n/m.
    """
    if n_months is None:
        return curves_df

    modelling_period_months = (
        curves_df["end_date"].max().to_period("M") - curves_df["start_date"].min().to_period("M")
    ).n

    for col in COLUMNS_TO_SCALE:
        if col in curves_df.columns:
            curves_df[col] = curves_df[col] * n_months / modelling_period_months

    return curves_df


def apply_projection(curves_df: pd.DataFrame, projection_settings: pd.DataFrame):
    """
    Apply the projections based on the settings.

    `curves_df` is the response curve dataframe.
    `projection_settings` is the dataframe with columns reprsenting the supported settings.
    """
    if projection_settings.empty:
        return curves_df

    # setting should be a single row
    projection_settings = projection_settings.iloc[0].to_dict()

    # Apply the settings
    curves_df = _projection_months(curves_df, int(projection_settings["n_months"]))

    return curves_df

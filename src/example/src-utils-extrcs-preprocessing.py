"""
Preprocessing functions for external response curves.
"""

import pandas as pd


def prepend_zero_uplift(extrcs_df: pd.DataFrame, idx):
    """
    For each response curve in the dataframe, there should be a point for uplift = 0.
    Add this point if it doesn't already exist.
    """
    min_uplifts = (
        extrcs_df.copy()
        .sort_values(idx + ["uplift"], ascending=True)
        .drop_duplicates(subset=idx, keep="first")
    )

    # where the min uplift != 0, add a point.
    uplifts_to_add = min_uplifts[min_uplifts["uplift"] != 0].copy()

    uplifts_to_add["uplift"] = 0
    uplifts_to_add["spend"] = 0
    uplifts_to_add["gm_adjusted_incremental_value_sales"] = 0
    uplifts_to_add["incremental_sell_out_units"] = 0
    uplifts_to_add["is_actual"] = 0

    return (
        pd.concat([extrcs_df, uplifts_to_add])
        .sort_values(idx + ["uplift"], ascending=True)
        .reset_index(drop=True)
    )


def apply_column_name_mappings(extrcs_df: pd.DataFrame):
    """
    Map column names in the external RC ingestion table
    back to master table column names.
    """
    extrcs_df_column_mappings = {"channel_name": "channel_code"}

    extrcs_df = extrcs_df.rename(columns=extrcs_df_column_mappings)

    return extrcs_df


def preprocess_external_curve(extrcs_df: pd.DataFrame, summary_df: pd.DataFrame):
    """
    Main preprocessing flow.
    """

    extrcs_df = apply_column_name_mappings(extrcs_df)

    idx = [
        "internal_response_code",
        "channel_code",
        "speciality_code",
        "segment_code",
        "segment_value",
    ]

    # Uplift
    extrcs_df = (
        extrcs_df.set_index(idx)
        .join(
            extrcs_df[extrcs_df["is_actual"] == 1].set_index(idx)["spend"],
            how="left",
            rsuffix="_denom",
            validate="m:1",
        )
        .reset_index()
    )
    extrcs_df["uplift"] = extrcs_df["spend"] / extrcs_df["spend_denom"]
    extrcs_df = extrcs_df.drop("spend_denom", axis=1)

    # Add a point where uplift is 0, if it doesn't already exist.
    extrcs_df = prepend_zero_uplift(extrcs_df, idx)

    # add the details
    for c in summary_df.columns:
        extrcs_df[c] = summary_df[c].iloc[0]

    return extrcs_df

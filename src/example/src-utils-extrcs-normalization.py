"""
Normalizations for externally provided curves
"""
import pandas as pd


def normalize_external_curve(extrcs_df: pd.DataFrame):
    """
    Function for performing normalization on external response curves
    """
    extrcs_df = enforce_monotonicity(extrcs_df)

    return extrcs_df


# pylint:disable=duplicate-code
def enforce_monotonicity(
    response_curve: pd.DataFrame,
) -> pd.DataFrame:
    """
    Make curves monotnously inreasing
    Monotonicity of sell out w.r.t uplift (spend) is enforced.
    Curves are made flat once the sell out begins to decrease.
    """
    monotonous_response_curve = response_curve.copy()

    monotonous_response_curve = monotonous_response_curve.sort_values(
        [
            "gbu_code",
            "market_code",
            "brand_name",
            "channel_code",
            "speciality_code",
            "segment_code",
            "segment_value",
            "uplift",
        ],
        ascending=True,
    )

    for c in ("gm_adjusted_incremental_value_sales", "incremental_sell_out_units"):
        monotonous_response_curve[c] = (
            monotonous_response_curve[c]
            .where(
                # Use the OR condition so the first and last points don't only get
                #    compared to nulls.
                (monotonous_response_curve[c] <= monotonous_response_curve[c].shift(-1))
                | (
                    monotonous_response_curve[c]
                    >= monotonous_response_curve[c].shift(1)
                )
            )
            .fillna(method="ffill")
        )

    return monotonous_response_curve

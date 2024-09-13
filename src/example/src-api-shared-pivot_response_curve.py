"""
RESPONSE_CURVE table is stored with metrics in melted format
with columns `metric` and `value`.
"""
import pandas as pd


def pivot_response_curve_metrics(df, copy=False):
    """
    Given dataframe `df`, pivot the metric/value columns.

    Casts the metrics into correct dtypes.
    """
    if copy:
        new_df = df.copy()
    else:
        new_df = df

    # Set the index as all the other columns
    # list.remove implicitly checks the presence of
    #    `metric` and `value` columns.
    idx = list(df.columns)
    idx.remove("metric")
    idx.remove("value")

    # pivot
    # we use "first" as an aggfunc because string metrics cannot be aggregated
    #   this requires the assumption that the metric is unique across the index.
    # "first" is also much faster than something like np.max
    new_df = pd.pivot_table(
        new_df, values="value", index=idx, columns="metric", aggfunc="first"
    ).reset_index()

    # cast
    for m, t in [
        ("price_per_unit", float),
        ("currency", str),
        ("gm_of_sell_out", float),
        ("total_units", float),
        ("total_net_sales", float),
        ("total_gm_incremental_sales", float),
        ("total_incremental_units", float),
    ]:
        if m in new_df.columns:
            new_df[m] = new_df[m].astype(t)

    return new_df

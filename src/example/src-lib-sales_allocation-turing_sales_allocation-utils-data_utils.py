"""
This util file contains the functions required to impute the data.
"""
import sys
import warnings
from typing import List
import pandas as pd
from turing_generic_lib.utils.logging import get_logger

warnings.filterwarnings("ignore")

logger_obj = get_logger("turing_sales_allocation Utils")


def impute_column(data_frame: pd.DataFrame,
                  impute_columns_dict: dict) -> pd.DataFrame:
    """This function imputes any column with null values with any required value.

    Arguments:
        data_frame {pd.DataFrame} -- Input DataFrame.
        impute_columns_dict {dict} -- Column & Values to be Imputed.

    Returns:
        pd.DataFrame -- Output DataFrame.
    """
    for cols in impute_columns_dict:
        data_frame[cols] = data_frame[cols].fillna(impute_columns_dict[cols])
        logger_obj.info(
            f"{cols} containing null values filled with {impute_columns_dict[cols]}")
    return data_frame


def get_first_row_on_group(
        data_frame: pd.DataFrame,
        rows_partition_by: List[str],
        rows_order_by_dict: dict) -> pd.DataFrame:
    """This function gets the first row per group to remove duplicate.

    Arguments:
        data_frame {pd.DataFrame} -- Input DataFrame
        rows_partition_by {List[str]} -- List of strings for partitioning the data
        rows_order_by_dict {dict} -- Dictionary for Order by

    Returns:
        pd.DataFrame -- Output DataFrame
    """
    data_frame["rank"] = (
        data_frame.sort_values(
            list(rows_order_by_dict.keys()), ascending=list(rows_order_by_dict.values())
        )
        .groupby(rows_partition_by)
        .cumcount()
        + 1
    )
    data_frame = data_frame[data_frame["rank"] == 1]
    return data_frame.drop("rank", axis=1)


def pivot_column_group(
    data_frame: pd.DataFrame,
    data_level_col_list: List[str],
    feature_list: List[List[str]],
    value_for_agg: str,
) -> pd.DataFrame:
    """Pivot based on group of columns and merge into final dataframe

    Arguments:
        data_frame {pd.DataFrame} -- Input DataFrame
        data_level_col_list {List[str]} -- Group By or Pivot Data level column list
        feature_list {List[List[str]]} -- List of List of Features on which pivot is needed
        value_for_agg {str} -- Key col for aggrivation on pivot

    Returns:
        pd.DataFrame -- Output DataFrame
    """
    final_df = data_frame[data_level_col_list].drop_duplicates()
    for feature in feature_list:
        tgt_col_name = "HCP_" + "_".join(feature)
        data_frame[tgt_col_name] = ""
        for col in feature:
            data_frame[col] = data_frame[col].astype(str)
            data_frame[tgt_col_name] = data_frame[tgt_col_name] + \
                "_" + data_frame[col]
        data_frame[tgt_col_name] = tgt_col_name + data_frame[tgt_col_name]
        pivot_df = data_frame.pivot_table(
            values=value_for_agg,
            fill_value=0,
            index=data_level_col_list,
            columns=[tgt_col_name],
            aggfunc=pd.Series.nunique,
        )
        pivot_df_reset = pivot_df.reset_index()
        final_df = final_df.merge(
            pivot_df_reset,
            how="left",
            on=data_level_col_list)
    return final_df


def select_and_dropna_on_cols(
        data_frame: pd.DataFrame,
        col_list: List[str],
        drop_null_col: List[str] = None) -> pd.DataFrame:
    """Selects and drops null values on a column list

    Arguments:
        data_frame {pd.DataFrame} -- [description]
        col_list {List[str]} -- [description]

    Keyword Arguments:
        drop_null_col {List[str]} -- [description] (default: {None})

    Returns:
        pd.DataFrame -- [description]
    """
    if drop_null_col is not None:
        data_frame = data_frame.dropna(subset=drop_null_col)
    data_frame = data_frame[col_list].drop_duplicates()
    return data_frame


def null_outlier_treatment(
        data_frame: pd.DataFrame,
        target_dict: dict) -> pd.DataFrame:
    """Clips the outliers, fills the null values of the target column with a given value

    Arguments:
        data_frame {pd.DataFrame} -- Input DataFrame
        target_dict {dict} -- Target Column Dictionary

    Returns:
        pd.DataFrame -- Output DataFrame
    """
    # Outlier Treatment
    limit = data_frame[target_dict["TARGET_COL"]
                       ].quantile(target_dict["QUANTILE"])
    data_frame[target_dict["TARGET_COL"]
               ] = data_frame[target_dict["TARGET_COL"]].clip(upper=limit)

    # Null Value Treatment
    if target_dict["VALUE"] == "MEAN":
        data_frame[target_dict["TARGET_COL"]] = data_frame[target_dict["TARGET_COL"]].fillna(
            data_frame[target_dict["TARGET_COL"]].mean())
    elif target_dict["VALUE"] == "MIN":
        data_frame[target_dict["TARGET_COL"]] = data_frame[target_dict["TARGET_COL"]].fillna(
            data_frame[target_dict["TARGET_COL"]].min())
    elif target_dict["VALUE"] >= 0 and target_dict["VALUE"] < sys.maxsize:
        data_frame[target_dict["TARGET_COL"]] = data_frame[target_dict["TARGET_COL"]].fillna(
            target_dict["VALUE"])
    else:
        raise ValueError("Incorrect target column input range.")

    return data_frame


def replace_space_col_name(data_frame: pd.DataFrame) -> pd.DataFrame:
    """Replace space & special chars in column names with underscores

    Arguments:
        data_frame {pd.DataFrame} -- Input DataFrame

    Returns:
        pd.DataFrame -- Output DataFrame
    """
    data_frame.columns = data_frame.columns.str.replace(" ", "_")
    data_frame.columns = data_frame.columns.str.replace("-", "_")
    data_frame.columns = data_frame.columns.str.replace(">", "GTR")
    data_frame.columns = data_frame.columns.str.replace("<", "LSR")
    data_frame.columns = data_frame.columns.str.replace("=", "EQL")
    return data_frame

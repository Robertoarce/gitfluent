""" All seasonality & events related features """
from typing import Dict
import pandas as pd
from src.pipeline.feature_engineering.feature_names import SeasonalityFeatures


def add_monthly_seasonality(df: pd.DataFrame) -> pd.DataFrame:
    """
    Adds monthly seasonality features to the DataFrame.

    Args:
        df (pd.DataFrame): The DataFrame to which seasonality features will be added.

    Returns:
        pd.DataFrame: The DataFrame with added seasonality features.
    """
    features = df["year_month"].astype(str).str.extract(r".*(\d{2})", expand=False)
    features = pd.get_dummies(features)
    num_columns = features.shape[1]
    features.columns = SeasonalityFeatures.months()[0:num_columns]
    return pd.concat([df, features], axis=1)


def construct_seasonality_and_event_features(
    index_df: pd.DataFrame,
    seasonality_features: Dict,
    control_variables: Dict,
    database_control_variables,
) -> pd.DataFrame:
    """
    Constructs seasonality and event-related features in the DataFrame.

    Args:
        index_df (pd.DataFrame): The DataFrame containing index information.
        seasonality_features (Dict): A dictionary specifying seasonality features.
        control_variables (Dict): A dictionary specifying control variables.
        database_control_variables: Control variables from the database.

    Returns:
        pd.DataFrame: The DataFrame with constructed seasonality and event features.
    """
    features_df = index_df.copy()
    features_df["month"] = features_df["year_month"] % 100

    for feature in seasonality_features:
        if feature == "seasonality":
            features_df = add_monthly_seasonality(features_df)
    features_df = features_df.drop(columns={"month"}, axis=1, errors="ignore")
    if control_variables:
        features_df = add_control_variables(features_df, control_variables)

    if isinstance(database_control_variables, pd.DataFrame) and (
        not database_control_variables.empty
    ):
        features_df = add_control_variables_from_snowflake(
            features_df, database_control_variables, index_df
        )
    return features_df


def add_control_variables(df, control_variables):
    """
    Adds control variable-related features to the DataFrame.

    Args:
        df (pd.DataFrame): The DataFrame to which control variables will be added.
        control_variables: A dictionary specifying control variables.

    Returns:
        pd.DataFrame: The DataFrame with added control variable features.
    """
    for control_variable in control_variables:
        column_name = control_variable["name"]
        default_value = control_variable["default_value"]
        custom_values = control_variable.get("custom_values", {})

        # Add the new column with default values
        df[column_name] = default_value

        # Update custom values based on the reference column (period_start)
        for ref_value, custom_value in custom_values.items():
            df.loc[df["year_month"] == ref_value, column_name] = custom_value

    return df


def add_control_variables_from_snowflake(df, database_control_variables, index_df):
    """
    Reads control variables from Snowflake and adds them to the DataFrame.

    Args:
        df (pd.DataFrame): The DataFrame to which control variables will be added.
        database_control_variables: Control variables from the Snowflake database.
        index_df (pd.DataFrame): The DataFrame containing index information.

    Returns:
        pd.DataFrame: The DataFrame with added control variable features from Snowflake.
    """
    flag_columns = [col for col in database_control_variables.columns if col.endswith("_flag")]
    index_columns = list(index_df.columns)
    columns_to_merge = index_columns + flag_columns
    # Convert 'period_start' column to datetime format
    database_control_variables["period_start"] = pd.to_datetime(
        database_control_variables["period_start"]
    )

    # Create 'year_month' column in yyyymm format
    database_control_variables["year_month"] = (
        database_control_variables["period_start"].dt.year * 100
        + database_control_variables["period_start"].dt.month
    )

    selected_df = database_control_variables[columns_to_merge]
    df1 = df.merge(selected_df, on=index_columns, how="left")
    return df1

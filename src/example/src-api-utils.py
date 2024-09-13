"""
Utility functions for the MLAPI.
"""
import pandas as pd

from ..utils.snowflake_utils import snowflake_to_pandas, snowflake_to_pandas_async
from .exceptions import NoDataError


def clean_query_result(df: pd.DataFrame, no_data_return, check_empty: bool):
    """
    Clean the result from a query for use in MLAPI.
    """
    df.columns = [c.lower() for c in df.columns]

    if check_empty and df.empty:
        raise NoDataError(message="No data", return_content=no_data_return)

    return df


def query_to_pandas(
    query: str, no_data_return, params=None, check_empty: bool = True, env=None
) -> pd.DataFrame:
    """
    Query snowflake synchronously.
    """
    df = snowflake_to_pandas(query=query, params=params, env=env)

    return clean_query_result(df, no_data_return, check_empty)


async def query_to_pandas_async(
    query: str, no_data_return, params=None, check_empty: bool = True, env=None
) -> pd.DataFrame:
    """
    Async function to use with snowflake connector execute_async.
    """
    df = await snowflake_to_pandas_async(query=query, params=params, env=env)

    return clean_query_result(df, no_data_return, check_empty)


def pydantic_to_json_str(d):
    """
    Given pydantic object (from API input typing), serialize the object into JSON
    string and wrap it in single quote so that it can be passed to CLI (used for running
    metaflow flows)
    """
    return f"'{d.json()}'"

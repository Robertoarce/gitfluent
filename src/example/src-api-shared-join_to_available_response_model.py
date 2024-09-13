"""
API queries are often joined to API_AVAILABLE_REPSONSE_MODEL table
in Snowflake.

This module includes functions to reduce duplicate code.
"""


def inner_join_query_to_available_models_str(
    query_table,
    available_model_alias,
    exercise_table_alias=None,
    exercise_table_join_type="INNER",
):
    """
    Returns a string of JOIN and ON clauses that can be inserted in a string query,
    in order to join to the API_AVAILABLE_RESPONSE_MODEL table, and optionally the
    API_AVAILABLE_EXERCISE_MODEL.
    """
    out = f"""
    JOIN DMT_MMX.API_AVAILABLE_RESPONSE_MODEL {available_model_alias}
        ON {query_table}.gbu_code = {available_model_alias}.gbu_code
        AND {query_table}.market_code = {available_model_alias}.market_code
        AND {query_table}.brand_name = {available_model_alias}.brand_name
        AND {query_table}.channel_code = {available_model_alias}.channel_code
        AND {query_table}.speciality_code = {available_model_alias}.speciality_code
        AND {query_table}.segment_value = {available_model_alias}.segment_value
        AND {query_table}.version_code = {available_model_alias}.version_code
    """
    if exercise_table_alias is None:
        return out

    out = out + "\n"
    out = (
        out
        + f"""
    {exercise_table_join_type} JOIN DMT_MMX.API_AVAILABLE_EXERCISE {exercise_table_alias}
        ON {exercise_table_alias}.gbu_code = {available_model_alias}.gbu_code
        AND {exercise_table_alias}.market_code =
            {available_model_alias}.market_code
        AND {exercise_table_alias}.brand_name =
            {available_model_alias}.brand_name
        AND {exercise_table_alias}.channel_code =
            {available_model_alias}.channel_code
        AND {exercise_table_alias}.speciality_code =
            {available_model_alias}.speciality_code
        AND {exercise_table_alias}.segment_code =
            {available_model_alias}.segment_code
        AND {exercise_table_alias}.segment_value =
            {available_model_alias}.segment_value
        AND {exercise_table_alias}.version_code =
            {available_model_alias}.version_code
    """
    )

    return out

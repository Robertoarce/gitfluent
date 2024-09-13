"""
Functions backing the `/list-exercises/` endpoint.
"""
from typing import List

from ..constants import DEFAULT_BUDGET_NAME
from ..schemas import Brand, ExerciseInfo, GBUCodeInput, Market, ScopeValue
from ..shared import inner_join_query_to_available_models_str
from ..utils import query_to_pandas


def _build_query_exercises(
    gbu: GBUCodeInput,
    market_code: List[str],
):
    """
    Builds the query to return available exercises.
    """
    # Single country: Only return exercises with matching country
    # Multiple country: Only return exercises with multiple matching countries.
    n_markets_operator = ">" if len(market_code) > 1 else ">="

    query = f"""
    WITH
    channel_master_subquery AS (
        SELECT DISTINCT
            channel_code,
            channel_desc
        FROM DMT_MMX.CHANNEL_MASTER
    ),
    projection_periods_subquery AS (
        SELECT
            exercise_code,
            LISTAGG(DISTINCT period_name, '|') WITHIN GROUP (ORDER BY period_name) AS period_name
        FROM DMT_MMX.API_AVAILABLE_PROJECTION_PERIOD
        GROUP BY 1
    ),
    budgets_subquery AS (
        SELECT
            mmm_exercise AS exercise_code,
            LISTAGG(DISTINCT budget_name, '|') WITHIN GROUP (ORDER BY budget_name) AS budget_name
        FROM DMT_MMX.EXERCISE_BUDGET
        GROUP BY 1
    ),
    exercises_info AS (
        SELECT DISTINCT
            ae.exercise_code,
            ae.exercise_name,
            EXTRACT(year from rc.end_date) AS year,
            ae.gbu_code,
            ae.market_code,
            mr.market_name,
            mr.region_name,
            mr.region_code,
            mr.currency,
            UPPER(ae.brand_name) AS brand_name,
            UPPER(ae.channel_code) AS channel_code,
            CASE
                WHEN cms.channel_desc IS NOT NULL THEN cms.channel_desc
                ELSE ae.channel_code
            END AS channel_desc,
            UPPER(ae.speciality_code) AS speciality_code,
            UPPER(ae.segment_code) AS segment_code,
            UPPER(ae.segment_value) AS segment_value,
            COUNT(DISTINCT ae.market_code)
            OVER (
                PARTITION BY ae.exercise_code
                ORDER BY brand_name -- any column
                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
            ) AS n_markets_exercise,
            pps.period_name,
            bs.budget_name
        FROM DMT_MMX.RESPONSE_CURVE rc
        {inner_join_query_to_available_models_str("rc", "am", "ae")}
        JOIN DMT_MMX.MARKET_REGION mr
            ON mr.market_code = ae.market_code
        LEFT JOIN channel_master_subquery cms
            ON cms.channel_code = ae.channel_code
        LEFT JOIN projection_periods_subquery pps
            on ae.exercise_code = pps.exercise_code
        LEFT JOIN budgets_subquery bs
            ON ae.exercise_code = bs.exercise_code
        WHERE ae.gbu_code = %(gbu)s
    )
    SELECT *
    FROM exercises_info
        WHERE market_code IN (%(market_code)s)
        AND n_markets_exercise {n_markets_operator} 1
    """

    params = {
        "gbu": gbu.value,
        "market_code": market_code,
    }

    return query, params


# pylint: disable=unused-argument, too-many-locals
def get_exercises(
    gbu: GBUCodeInput,
    market_code: List[str],
) -> List[ExerciseInfo]:
    """
    Function to get the available response models and scope data for scenario creation.
    """
    # ------------------------
    #  Step 1: Query
    # ------------------------
    query, params = _build_query_exercises(gbu=gbu, market_code=market_code)
    df = query_to_pandas(query, no_data_return=[], params=params)

    # ------------------------
    # Step 2: Transform
    # ------------------------

    # TODO: this is a mock data column
    df["brand_category"] = "CATEGORY1"

    grouped_data = df.groupby("exercise_code")

    exercises = []
    for exercise_code, sub_df in grouped_data:
        markets = (
            sub_df[list(Market.__fields__.keys())].drop_duplicates().to_dict("records")
        )
        brands = (
            sub_df[list(Brand.__fields__.keys())].drop_duplicates().to_dict("records")
        )
        channels = list(set(sub_df["channel_code"]))
        specialities = list(set(sub_df["speciality_code"]))
        segments = list(set(sub_df["segment_value"]))
        scope_values = (
            sub_df[list(ScopeValue.__fields__.keys())]
            .drop_duplicates()
            .to_dict("records")
        )

        exercises.append(
            ExerciseInfo(
                exercise_code=exercise_code,
                exercise_name=sub_df["exercise_name"].iloc[0],
                markets=markets,
                brands=brands,
                channels=channels,
                specialities=specialities,
                segments=segments,
                scope_values=scope_values,
                available_period_settings=(
                    ["default"]
                    if sub_df["period_name"].iloc[0] is None
                    else sub_df["period_name"].iloc[0].split("|")
                ),
                available_budget=(
                    [DEFAULT_BUDGET_NAME]
                    + (
                        []
                        if sub_df["budget_name"].iloc[0] is None
                        else sub_df["budget_name"].iloc[0].split("|")
                    )
                ),
            )
        )

    # ------------------------
    # Step 3: Return
    # ------------------------
    return exercises

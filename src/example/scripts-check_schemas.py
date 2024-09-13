"""
Ensure DMT schema consistency between environments.
"""

import argparse

from src.utils.snowflake_utils import snowflake_to_pandas

# Tables not to check (e.g. any dev only tables that are not needed/used in uat/prod.)
# this will be matched using LIKE
IGNORE_TABLE_NAME_PATTERNS = [
    "%TEST%",
    "%TEMP%",
    "FEATURE",
    "MODEL_SETTINGS",
    "PRODUCT_TOUCHPOINT_PLANNING",
    "REPORTING_SELLOUT",
    "TOUCHPOINT_MAPPING",
    "API_BOOST_ROI",
    "API_INFLATION_RATES",
    "API_PLAY_GROWTH_RATES",
    "PRODUCT_MASTER",
    "REPORTING_TOUCHPOINT",
    "ST_LT_RESPONSE_CURVE",
    "API_AVAILABLE_MARKET",
    "FEATURE_PRODUCT_CONTRIBUTION",
    "GLOBAL_OVERVIEW",
    "ACTUAL_VS_PREDICTION",
    "ACTUAL_VS_PREDICTION_VALUES",
    "API_BRAND_EQUITY",
    "TOUCHPOINT_MASTER",
    "REGRESSION_METRIC",
]

if __name__ == "__main__":
    args = argparse.Namespace()
    parser = argparse.ArgumentParser()
    parser.add_argument("--from_env", choices=["DEV", "UAT"], type=str, required=True)
    parser.add_argument("--to_env", choices=["UAT", "PROD"], type=str, required=True)
    parser.parse_args(namespace=args)

    from_env = args.from_env
    to_env = args.to_env

    schema = {}
    for env in (from_env, to_env):
        query = f"""
        SELECT *
        FROM MMX_{env}.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = 'DMT_MMX'
        """
        for pattern in IGNORE_TABLE_NAME_PATTERNS:
            query = query + f"\nAND TABLE_NAME NOT LIKE '{pattern}'"

        # Use migration creds which can access both from_env and to_env
        schema[env] = (
            snowflake_to_pandas(query, env=env)
            .drop(["TABLE_CATALOG"], axis=1)
            .set_index(["TABLE_SCHEMA", "TABLE_NAME", "COLUMN_NAME"])
        )

    schema_diffs = schema[from_env].compare(
        schema[to_env], result_names=(from_env, to_env)
    )

    try:
        assert schema_diffs.empty(), "Schema Differences Found!"
    except AssertionError as e:
        print("Schema differences: ")
        print(schema_diffs)
        raise e

    print("Schema OK!")

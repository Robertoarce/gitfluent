"""
Module for loading data from Snowflake
"""
from typing import Dict

from snowflake.connector.errors import DatabaseError

from src.utils.data.data_loader import DataLoader
from src.utils.snowflake_utils import MMXSnowflakeConnection


# pylint: disable=too-few-public-methods
class SnowflakeDataLoader(DataLoader):
    """
    Collection of functions and utilities to load data from Snowflake.
    Init params:
        `config` is a dictionary with the following nested structure:

        tables:
            {table_name (str)}: # this is an identifier string, doesn't need to match SF table name
                schema: {name of schema in Snowflake (str)}
                table: {name of table in Snowflake (str)}
                pre_filters:
                    {column name (str)}:
                        type: {equal/not_equal/less/less_equal/greater/greater_equal}
                        value: int/float/string
    """

    def _update_query(self, query, config, is_national=False):
        """
        This method raplace tags with its equivalent values.
        At present, following tags are supported
        $BRAND_NAME, $COUNTRY_CODE, $START_DATE, $END_DATE, $VERSION_CODE
        """
        start_date = str(config.get("MODEL_TIME_HORIZON_START"))
        end_date = str(config.get("MODEL_TIME_HORIZON_END"))
        
        if not is_national:
            start_date = start_date[0:4] + "-" + start_date[4:6] + "-01"
            end_date = end_date[0:4] + "-" + end_date[4:6] + "-01"

        tags = ["BRAND_NAME", "COUNTRY_CODE", "VERSION_CODE"]
        for tag in tags:
            if "$" + tag in query:
                query = query.replace("$" + tag, config.get(tag))
        if "$START_DATE" in query:
            query = query.replace("$START_DATE", start_date)
        if "$END_DATE" in query:
            query = query.replace("$END_DATE", end_date)
        return query

    # pylint:disable=no-member
    def _load_table_from_source(self, table_config: dict, config=None):
        """
        Loads the table from Snowflake as a pandas df
        """
        is_national = False
        if table_config.get("query") is None:
            query = self._build_query(table_config)
        else:
            if (config.get("model_type").lower() == "pooled") and table_config[
                "table"
            ] == "DWH_SELL_OUT_OWN":
                query = table_config.get("national_query")
                is_national = True
            else:
                query = table_config.get("query")

        if config is not None:
            query = self._update_query(query, config, is_national)
        try:
            connection = MMXSnowflakeConnection(
                env=self.env, **self.config.get("snowflake_connection", {})
            )
            cur = connection.cursor()
            cur.execute(query)
            df = cur.fetch_pandas_all()
        except DatabaseError:
            connection.close()

        return df

    def _build_query(self, table_config: Dict):
        """
        Builds the SQL query based on the table config.
        """
        columns = self._build_columns(table_config)
        filters = self._build_filters(table_config)
        joins = self._build_joins(table_config)

        query = f"""
        SELECT {columns}
        FROM {table_config["schema"]}.{table_config["table"]}
        {joins}
        {filters}
        """

        return query

    def _build_columns(self, table_config: Dict):
        """
        Builds the columns in the select statement.
        """
        distinct = table_config.get("distinct", [])
        if distinct:
            columns = "DISTINCT " + ", ".join(distinct)
        else:
            columns = f"{table_config['table']}.*"

        # additional columns selected in the joined tables.
        for join_config_key in ["inner_joins", "left_joins", "right_joins"]:
            for right_table in table_config.get(join_config_key, []):
                for c in right_table.get("columns", []):
                    columns += f", {right_table['table']}.{c}"

        return columns

    def _build_filters(self, table_config: Dict):
        """
        Builds the SQL WHERE clause based on the table config.
        """
        filters = []
        for col_name, fltr in table_config.get("pre_filters", {}).items():
            filter_fn = self.filter_functions.get(fltr["type"])
            if filter_fn is None:
                raise ValueError(f"Filter type {fltr['type']} not implemented!")

            filter_value = fltr["value"]
            if isinstance(filter_value, str):
                # enclose string with single quotes
                filter_value = f"'{filter_value}'"

            filters.append(f"{col_name} {filter_fn} {filter_value}")

        filters = filters + table_config.get("literal_filters", [])

        if not filters:
            return ""

        filters = "\n AND ".join(filters)
        filters = "WHERE " + filters

        return filters

    def _build_joins(self, table_config: Dict):
        """
        INNER JOIN the table to another table
        used for filtering.
        """
        joins = []

        for join_config_key, join_type in [
            ("inner_joins", "INNER JOIN"),
            ("left_joins", "LEFT JOIN"),
            ("right_joins", "RIGHT JOIN"),
        ]:
            for right_table in table_config.get(join_config_key, []):
                join_string = f"{join_type} {right_table['schema']}.{right_table['table']}"
                join_string = join_string + "\n ON "
                join_string = join_string + "\n AND ".join(right_table["join_on"])
                joins.append(join_string)

        if not joins:
            return ""

        joins = "\n".join(joins)

        return joins

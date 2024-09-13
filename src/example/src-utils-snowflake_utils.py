"""
Created By  : MMX Team
Created Date: 16/12/2022
Description : Utility Functions for Snowflake
"""
import asyncio
import os

import snowflake.connector
from snowflake.connector.errors import DatabaseError


class MMXSnowflakeConnection:
    """
    Singleton connection class to avoid closing and reopening connections

    Once a connection is created with a given set of arguments (credentials),
    that connection is persisted for the lifetime of the process unless it becomes
    inactive
    """

    _connections = {}

    def __new__(cls, env=None, **kwargs):
        """
        Checks if a connection has already been created (and is still active)
        If so, returns the active connection,
        else creates and returns a new connection.
        """
        conn_key = cls._get_conn_key(env=env, **kwargs)

        if (conn_key not in cls._connections) or (
            cls._connections[conn_key].is_closed()
        ):
            cls._connections[conn_key] = cls.create_connection(env=env, **kwargs)

        return cls._connections[conn_key]

    @staticmethod
    def _get_conn_key(env=None, **kwargs):
        """
        Hashable key used to identify connections.
        """
        return tuple(
            sorted(
                {"env": env, **kwargs}.items(),
                key=lambda x: x[0],  # sort by kwarg name.
            )
        )

    @classmethod
    def refresh_connection(cls, env=None, **kwargs):
        """
        If the connection is not working for whatever reason,
        close it and create a new one
        """
        conn_key = cls._get_conn_key(env=env, **kwargs)

        try:
            cls._connections[conn_key].close()
        finally:
            cls._connections[conn_key] = cls.create_connection(env=env, **kwargs)

        return cls._connections[conn_key]

    @classmethod
    def create_connection(cls, env=None, **kwargs):
        """
        Connect to the MMX Snowflake database server.
        """
        if env is None:
            env = os.environ["ENVNAME"]

        # patch, as OneAI secrets cannot have quote marks
        password = kwargs.get("password", os.getenv(f"SNOW_PASSWORD_{env}"))
        if password is not None:
            password = password.replace("/SINGLEQUOTE/", "'")

        connection_kwargs = dict(
            account=kwargs.get("account", os.environ[f"SNOW_ACCOUNT_{env}"]),
            user=kwargs.get("user", os.environ[f"SNOW_USER_{env}"]),
            authenticator=kwargs.get(
                "authenticator", os.getenv(f"SNOW_AUTHENTICATOR_{env}")
            ),
            password=password,
            warehouse=kwargs.get("warehouse", os.environ[f"SNOW_WAREHOUSE_{env}"]),
            database=kwargs.get("database", os.environ[f"SNOW_DATABASE_{env}"]),
            schema=kwargs.get("schema", os.getenv(f"SNOW_SCHEMA_{env}")),
            role=kwargs.get("role", os.environ[f"SNOW_ROLE_{env}"]),
            client_session_keep_alive=True,
        )
        connection_kwargs.update(kwargs)

        connection_kwargs = {
            k: v for k, v in connection_kwargs.items() if v is not None
        }
        connection = snowflake.connector.connect(
            **connection_kwargs, network_timeout=60
        )

        return connection

    @classmethod
    def close_all(cls):
        """
        Close all connections
        """
        for conn in cls._connections.values():
            try:
                conn.close()
            except DatabaseError:
                pass


def mmx_snowflake_connection(env=None, **kwargs):
    """
    Legacy function retained for backward compatibility
    """
    return MMXSnowflakeConnection(env=env, **kwargs)


def read_table_pandas(connection, query):
    """Gets table for a given table and schema name .
    Parameters:
        connection: A connection object to a Snowflake database server
        retrieved using the snowflake_connect function.
        query: User Input for Query
    Returns:
        Table displayed as Pandas dataframe.
    Raises:
        Exception Error: If the connection to the database is not
        successful or if the schema does not exist.
    """
    try:
        cur = connection.cursor()
        cur.execute(query)
        dataframe = cur.fetch_pandas_all()
    except Exception as error:
        print(f"Error during reading a table: {error}")
        raise error

    print(f"Successful Query: {query}")
    return dataframe


def snowflake_to_pandas(query: str, params=None, env=None):
    """
    Accepts SQL query string and executes synchronously.
    """
    try:
        connection = MMXSnowflakeConnection(env=env)
        cur = connection.cursor()  # pylint: disable=no-member
        cur.execute(query, params=params)
        df = cur.fetch_pandas_all()
    except DatabaseError as e:
        connection.close()
        raise e

    return df


async def snowflake_to_pandas_async(
    query: str, params=None, poll_freq=0.5, max_n_poll=100, env=None
):
    """
    Accepts SQL query string and executes async.
    """
    try:
        connection = MMXSnowflakeConnection(env=env)
        cur = connection.cursor()  # pylint: disable=no-member
        cur.execute_async(query, params=params)
        query_id = cur.sfqid
        n_poll = 0

        # pylint: disable=no-member
        while connection.is_still_running(connection.get_query_status(query_id)):
            await asyncio.sleep(poll_freq)
            n_poll += 1
            if n_poll >= max_n_poll:
                raise TimeoutError("Reached max polls. Closing snowflake connection")

        cur.get_results_from_sfqid(query_id)
        df = cur.fetch_pandas_all()
    except DatabaseError:
        connection.close()

    return df

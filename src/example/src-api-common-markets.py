"""
Functions backing the `/markets/` endpoint.
"""
from typing import List

from ..schemas import GBUCodeInput, Market
from ..utils import query_to_pandas


def _build_query_markets(
    gbu: GBUCodeInput,
):
    """
    Builds the query to geo master table to get available markets
    """
    query = """
    SELECT DISTINCT mr.*
    FROM DMT_MMX.MARKET_REGION mr
    """

    params = {
        "gbu": gbu.value,
    }

    return query, params


# pylint: disable=unused-argument
def get_markets(
    gbu: GBUCodeInput,
) -> List[Market]:
    """
    Function to return the list of available markets.
    """
    query, params = _build_query_markets(gbu=gbu)
    df = query_to_pandas(query, no_data_return=[], params=params)

    df = df.dropna()

    # MOCK DATA
    return [
        Market(**d) for d in df.to_dict("records")  # pylint: disable=not-an-iterable
    ]

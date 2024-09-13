"""
Functions backing the /recommendations/ endpoint.
"""
import json

import aiofiles

from ...run_flow import run_metaflow_async
from ..schemas import (
    GBUCodeInput,
    RecommendationEngineOutput,
    RecommendationEngineSettings,
)


async def run_reco_engine(
    gbu: GBUCodeInput,
    market_code: str,
    recommendation_engine_settings: RecommendationEngineSettings,
) -> RecommendationEngineOutput:
    """
    Runs recommender engine using parameters provided in API.
    """

    print("Running recommendation")

    # As we have to trigger the metaflow flow using command line
    # arguments may exceed the CLI length limit if scenarios get very large
    # we work around this by writing the payload to a temporary json file
    async with aiofiles.tempfile.NamedTemporaryFile(suffix=".json") as f:
        await f.write(json.dumps(recommendation_engine_settings.dict()).encode())
        await f.flush()  # flush is required because metaflow will run in a different proces

        res = await run_metaflow_async(
            gbu=gbu.value,
            country=market_code,
            pipeline="recommendation_engine",
            payload_json=f.name,
        )

    return res

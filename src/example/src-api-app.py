# pylint:disable=unused-argument
"""
Entry point for the MLAPI.

Please run from the CLI: uvicorn src.api.app:app --host 0.0.0.0 --port {DESIRED PORT} --root-path .

DEBUG COMMAND: uvicorn src.api.app:app --host 0.0.0.0 --port 8000 --root-path . --reload
"""

import asyncio
import traceback
from concurrent.futures import ProcessPoolExecutor
from contextlib import asynccontextmanager
from typing import Dict, List, Optional, Union

from fastapi import Depends, FastAPI, Query
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from starlette.requests import Request

from .auth import Validate
from .cache import (
    check_specified_cache_size,
    clear_specified_cache,
    exercises_cache,
    markets_cache,
    mmm_contributions_cache,
    mmm_list_cache,
    mmm_roi_cache,
    spends_cache,
)
from .common import get_available_constraints, get_objective_references, run_reco_engine
from .exceptions import NoDataError
from .schemas import (
    Constraint,
    ExerciseInfo,
    GBUCodeInput,
    GBUMarketSpend,
    Market,
    MMMResults,
    MMMSalesContribution,
    MMMSummary,
    ObjectiveReference,
    RecommendationEngineOutput,
    RecommendationEngineSettings,
    ScopeValue,
)

# ======================================================
# Startup
# ======================================================


@asynccontextmanager
async def lifespan(fastapi_app: FastAPI):
    """
    Open a process pool on startup to enable parallelism

    We set a maximum of 8 processes for memory concerns.
    """
    process_pool_executor = ProcessPoolExecutor(max_workers=8)
    app.state.executor = process_pool_executor
    # pylint: disable=protected-access
    print(f"Started process pool with {process_pool_executor._max_workers} workers")

    # Attach the process pool to each of the caches
    exercises_cache.executor = process_pool_executor
    markets_cache.executor = process_pool_executor
    mmm_contributions_cache.executor = process_pool_executor
    mmm_list_cache.executor = process_pool_executor
    mmm_roi_cache.executor = process_pool_executor
    spends_cache.executor = process_pool_executor

    yield

    # On app shutdown, shutdown the process pool.
    print("Shutting down process pool")
    process_pool_executor.shutdown()


app = FastAPI(lifespan=lifespan, docs_url="/docs")
app.add_middleware(GZipMiddleware, minimum_size=1000)


async def _run_in_process(endpoint_name, fn, *args):
    """
    Function to allow execution in the process pool.
    """
    loop = asyncio.get_event_loop()
    print(f"Running {endpoint_name} in {app.state.executor}")
    return await loop.run_in_executor(app.state.executor, fn, *args)


# ======================================================
# Exception Handlers
# ======================================================


@app.exception_handler(NoDataError)
async def empty_exception_handler(request: Request, exception: Exception):
    """
    In the case of no data, it is useful to return an
    empty response to signify that the code is not broken,
    but just that the data is missing.
    """
    return JSONResponse(
        status_code=200,
        content=exception.return_content,
    )


@app.exception_handler(Exception)
async def base_exception_handler(request: Request, exception: Exception):
    """
    Sends traceback in event of error; exception can be parsed through key "detail"
    """
    return JSONResponse(
        status_code=400,
        content={"detail": str(exception), "stack_trace": traceback.format_exc()},
    )


# ======================================================
# Admin
# ======================================================


@app.get("/admin-auth-test/", response_model=Dict[str, str], tags=["Admin"])
async def admin_auth_test(
    authorized=Depends(Validate(admin_required=True)),
) -> Dict[str, str]:
    """
    Test whether the basic auth credentials are correct.
    """
    return {"message": "Authorization success"}


@app.get("/check-cache-size/", response_model=Dict[str, int], tags=["Admin"])
async def check_cache_size(
    endpoint: str, authorized=Depends(Validate(admin_required=True))
):
    """
    Check the size of the specified cache
    """
    return check_specified_cache_size(endpoint)


@app.delete("/clear-cache/", response_model=Dict[str, str], tags=["Admin"])
async def clear_cache(endpoint: str, authorized=Depends(Validate(admin_required=True))):
    """
    Function to allow admin with admin credentials to
    clear endpoint caches without redeployment.
    """
    return clear_specified_cache(endpoint)


# ======================================================
# Endpoints: Testing
# ======================================================


@app.get("/api-test/", response_model=Dict[str, str], tags=["API tests"])
async def api_test() -> Dict[str, str]:
    """
    Test function which returns a simple message.
    """
    return {"message": "API is alive!"}


@app.get("/auth-test/", response_model=Dict[str, str], tags=["API tests"])
async def auth_test(
    authorized=Depends(Validate(admin_required=False)),
) -> Dict[str, str]:
    """
    Test whether the basic auth credentials are correct.
    """
    return {"message": "Authorization success"}


# ======================================================
# Endpoints: MMM Screens
# ======================================================


@app.get("/mmm-contributions/", response_model=List[MMMSalesContribution], tags=["MMM"])
async def mmm_contributions(
    gbu: GBUCodeInput,
    market_code: str,
    version_codes: Union[List[str], None] = Query(default=None),
    authorized: bool = Depends(Validate(admin_required=False)),
) -> [MMMSalesContribution]:
    """
    Returns sales contributions data.
    """
    cache_key = (
        gbu,
        market_code,
        tuple(sorted(version_codes)) if version_codes else None,
    )

    return await mmm_contributions_cache[cache_key]


@app.get("/mmm-roi/", response_model=MMMResults, tags=["MMM"])
async def mmm_roi(
    gbu: GBUCodeInput,
    market_code: str,
    version_codes: Union[List[str], None] = Query(default=None),
    brand_name: Optional[str] = None,
    channel_code: Optional[str] = None,
    speciality_code: Optional[str] = None,
    segment_value: Optional[str] = None,
    authorized: bool = Depends(Validate(admin_required=False)),
) -> MMMResults:
    """
    Returns ROI data of the response curves, given a specific market.
    """
    cache_key = (
        gbu,
        market_code,
        tuple(sorted(version_codes)) if version_codes else None,
        brand_name,
        channel_code,
        speciality_code,
        segment_value,
    )

    return await mmm_roi_cache[cache_key]


@app.get("/mmm-list/", response_model=List[MMMSummary], tags=["MMM"])
async def mmm_list(
    gbu: GBUCodeInput,
    market_code: str,
    authorized: bool = Depends(Validate(admin_required=False)),
) -> List[MMMSummary]:
    """
    Returns a simple summary of the model.
    """
    cache_key = (gbu, market_code)

    return await mmm_list_cache[cache_key]


@app.get("/spends/", response_model=List[GBUMarketSpend], tags=["Base Data"])
async def historical_spends(
    gbu: GBUCodeInput,
    market_code: str,
    brand_name: List[str] = Query(default=None),
    min_year: Optional[int] = None,
    max_year: Optional[int] = None,
    authorized: bool = Depends(Validate(admin_required=False)),
):
    """
    Returns historical salesforce and promotional spends.
    """

    cache_key = (
        gbu,
        market_code,
        tuple(sorted(brand_name)) if brand_name else None,
        min_year,
        max_year,
    )

    return await spends_cache[cache_key]


# ======================================================
# Endpoints: Homepage
# ======================================================


@app.get("/markets/", response_model=List[Market], tags=["markets"])
async def markets(
    gbu: GBUCodeInput,
    authorized: bool = Depends(Validate(admin_required=False)),
) -> List[Market]:
    """
    Return the markets (and associated data) supported by the MLAPI.
    """
    cache_key = (gbu,)

    return await markets_cache[cache_key]


# ======================================================
# Endpoints: Scenario Creation
# ======================================================


@app.get("/list-exercises/", response_model=List[ExerciseInfo], tags=["Scenarios"])
async def list_exercises(
    gbu: GBUCodeInput,
    market_code: List[str] = Query(min_length=1),
    authorized: bool = Depends(Validate(admin_required=False)),
) -> List[ExerciseInfo]:
    """
    Returns the list of exercises
    """
    cache_key = (gbu, tuple(sorted(market_code)))

    return await exercises_cache[cache_key]


@app.post(
    "/objective-references/", response_model=ObjectiveReference, tags=["Scenarios"]
)
async def objective_references(
    gbu: GBUCodeInput,  # pylint: disable=unused-argument
    exercise_code: str,
    scope_values: List[ScopeValue],
    selected_period_setting: str,
    selected_budget: str,
    market_code: Union[List[str], None] = Query(
        default=None
    ),  # pylint: disable=unused-argument
    authorized: bool = Depends(Validate(admin_required=False)),
) -> ObjectiveReference:
    """
    Returns a list of reference values for the scenario, given the selected scope.

    For now, gbu and market code not used, kept for consistency.
    """
    return await _run_in_process(
        "/objective-references/",
        get_objective_references,
        exercise_code,
        selected_period_setting,
        selected_budget,
        scope_values,
    )


@app.post(
    "/available-constraint/",
    response_model=List[Constraint],
    tags=["Scenarios"],
)
async def available_constraints(
    scope_values: List[ScopeValue],
    gbu: Optional[GBUCodeInput] = None,  # pylint: disable=unused-argument
    market_code: Union[List[str], None] = Query(
        default=None
    ),  # pylint: disable=unused-argument
    authorized: bool = Depends(Validate(admin_required=False)),
) -> List[Constraint]:
    """
    Returns possible constraints, given scope

    For now, GBU and Marketcode not used, but kept for consistent
    interfacing with UI.
    """
    return await _run_in_process(
        "/available-constraint/", get_available_constraints, scope_values
    )


@app.post(
    "/recommendations/",
    response_model=RecommendationEngineOutput,
    tags=["recommendations"],
)
async def recommendations(
    gbu: GBUCodeInput,
    recommendation_engine_settings: RecommendationEngineSettings,
    market_code: List[str] = Query(min_length=1),
    authorized: bool = Depends(Validate(admin_required=False)),
):
    """
    Runs the recommender engine.
    """
    return await run_reco_engine(gbu, market_code, recommendation_engine_settings)

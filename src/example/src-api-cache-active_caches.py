"""
Declaration of active caches in the API.
"""

from ..common import (
    get_exercises,
    get_markets,
    get_mmm_contributions,
    get_mmm_list,
    get_mmm_roi,
    get_spends,
)
from .async_cache import AsyncCache

# ======================================================
# Caches
# ======================================================

# ROI endpoint is queried by UI using version codes, which should not change.
# No need to refresh
mmm_roi_cache = AsyncCache(
    maxsize=100,
    fn=get_mmm_roi,
    endpoint_name="/mmm-roi/",
    expiration=None,
    background_refresh=False,
)

# Contributions endpoint is queried by UI using version codes, which should not change.
# No need to refresh
mmm_contributions_cache = AsyncCache(
    maxsize=100,
    fn=get_mmm_contributions,
    endpoint_name="/mmm-contributions/",
    expiration=None,
    background_refresh=False,
)

# Cache size to accomodate approximately number of GBU x markets.
# Short expiry to catch updates (new models published)
mmm_list_cache = AsyncCache(
    maxsize=100,
    fn=get_mmm_list,
    endpoint_name="/mmm-list/",
    expiration=5 * 60,
    background_refresh=True,
)

# Cache size is approximately number of GBU x markets x brands.
# Updates not expected often - long expiry of 24 hours.
spends_cache = AsyncCache(
    maxsize=100,
    fn=get_spends,
    endpoint_name="/spends/",
    expiration=60 * 60 * 24,
    background_refresh=True,
)

# There are only 3 GBUs to cache.
# Updates not expected often - long expiry of 24 hours.
markets_cache = AsyncCache(
    maxsize=3,
    fn=get_markets,
    endpoint_name="/markets/",
    expiration=60 * 60 * 24,
    background_refresh=True,
)

# Cache size is approximately number of GBU x markets.
# Short expiry to catch updates (new models published)
exercises_cache = AsyncCache(
    maxsize=100,
    fn=get_exercises,
    endpoint_name="/list-exercises/",
    expiration=5 * 60,
    background_refresh=True,
)

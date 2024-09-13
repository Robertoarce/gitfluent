"""
Clearing caches.
"""

from .active_caches import (
    exercises_cache,
    markets_cache,
    mmm_contributions_cache,
    mmm_list_cache,
    mmm_roi_cache,
    spends_cache,
)

_endpoint_to_cache_obj = {
    "exercises": exercises_cache,
    "markets": markets_cache,
    "mmm-contributions": mmm_contributions_cache,
    "mmm-list": mmm_list_cache,
    "mmm-roi": mmm_roi_cache,
    "spends": spends_cache,
}


def clear_specified_cache(endpoint):
    """
    Based on the cache name provided in `endpoint`, 
    clear the respective cache.
    """
    cache_obj = _endpoint_to_cache_obj.get(endpoint)
    if cache_obj is not None:
        cache_obj.clear()
        return {"message": f"Successfully cleared cache for {endpoint}."}
    
    raise ValueError(f"{endpoint} is not a valid cache identifier.")


def check_specified_cache_size(endpoint):
    """
    Based on the cache name provided in `endpoint`, 
    return the cache size
    """
    cache_obj = _endpoint_to_cache_obj.get(endpoint)
    if cache_obj is not None:
        return {
            "size": cache_obj.currsize
        }
    
    raise ValueError(f"{endpoint} is not a valid cache identifier.")
"""
Calculate deltas between optimized results and historical results.
"""
from typing import Union

from src.api.schemas import AllocationKPIValue, ScenarioResults, ScopeValue


def _delta(a: Union[float, int], b: Union[float, int], absolute: bool):
    """
    Absolute or relative delta.
    """
    if (a is None) or (b is None):
        return None

    if absolute:
        return a - b

    return (a - b) / b if b != 0 else 0  # avoid div by 0


def calculate_result_deltas(
    optimized: ScenarioResults, historical: ScenarioResults, absolute: bool = False
):
    """
    Calculates the deltas optimized - historical.

    Absolute flag determines whether results are
    absolute (currency) or relative (%).
    """
    optimized_dict = optimized.dict()
    historical_dict = historical.dict()

    delta_dict = {}

    # Summary deltas.
    delta_dict["summary"] = {}
    for k in ("incremental", "total", "carryover", "carryover_pct"):
        delta_dict["summary"][k] = {}
        for kk in AllocationKPIValue.__fields__.keys():
            delta_dict["summary"][k][kk] = _delta(
                optimized_dict["summary"][k][kk],
                historical_dict["summary"][k][kk],
                absolute=absolute,
            )

    # For detailed KPIs,
    # we sort by the ScopeValue keys (market, brand, channel, speciality, segment)
    # and then zip to ensure the deltas are calculated on matching items.
    scope_keys = ScopeValue.__fields__.keys()

    for suffix in ("incremental", "total", "carryover"):
        optimized_detailed_sorted = sorted(
            optimized_dict[f"detailed_{suffix}"],
            # for sortability
            key=lambda x: tuple(x[k] if x[k] is not None else "" for k in scope_keys),
        )
        historical_detailed_sorted = sorted(
            historical_dict[f"detailed_{suffix}"],
            # for sortability
            key=lambda x: tuple(x[k] if x[k] is not None else "" for k in scope_keys),
        )

        delta_dict[f"detailed_{suffix}"] = []
        for opt, hist in zip(optimized_detailed_sorted, historical_detailed_sorted):
            delta_dict[f"detailed_{suffix}"].append(
                {
                    **{k: opt[k] for k in scope_keys},
                    **{
                        k: _delta(opt[k], hist[k], absolute=absolute)
                        for k in AllocationKPIValue.__fields__.keys()
                    },
                }
            )

    return ScenarioResults.parse_obj(delta_dict)

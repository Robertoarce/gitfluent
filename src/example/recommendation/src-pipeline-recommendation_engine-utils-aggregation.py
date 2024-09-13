"""
Utility functions for aggregation.

Useful for aggregating across domains that are lower than the
desired granularity.
"""

from src.pipeline.recommendation_engine.optimizer.domain import DIMENSIONS


def pad_key(key, key_granularity, full_granularity=tuple(DIMENSIONS.keys())[:-1]):
    """
    Full granularity is (Region, Market, Brand, Channel, Speciality, Segment).
    Model domains are defined as slices of this full granularity, and this function
        will pad a key (with None values) so that we can aggregate across dimensions.

    `key`: A tuple or string representing a subset of the full granularity of MMX.
    `key_granularity`: A tuple indicating which dimension(s) are included in `key`.
        This is expected to follow the order of MMX hierarchy.

    Example:
        `key` is ("HEXYON", "PED")
        `key_granularity` is ("brand", "speciality")

        The function would return (None, None, "HEXYON", None, "PED", None)
    """
    if isinstance(key, str):
        key = [key]
    key_dict = dict(zip(key_granularity, key))

    padded_key = tuple(key_dict.get(g) for g in full_granularity)

    return padded_key


def padded_key_is_match(padded_key, other):
    """
    Comparison function that ignores None entries in the padded key
    to determine whether a variable value should be included in the higher
    level aggregation.
    """
    return (len(padded_key) == len(other)) & all(
        x == y for x, y in zip(padded_key, other) if x is not None
    )

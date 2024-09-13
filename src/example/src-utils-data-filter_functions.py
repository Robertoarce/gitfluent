"""
Mapping strings to function symbols for applying query condtions.
"""
FILTER_FUNCTIONS = set(
    [
        ("equal", "="),
        ("not_equal", "!="),
        ("less", "<"),
        ("less_equal", "<="),
        ("greater", ">"),
        ("greater_equal", ">="),
    ]
)

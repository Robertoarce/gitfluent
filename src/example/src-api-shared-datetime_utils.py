"""
Utilities to work with datetime transformations.
"""

from datetime import datetime


def period_as_string(
    start_date: datetime.date, end_date: datetime.date, fmt="%m/%Y"
) -> str:
    """
    Convert start date and end date into a string.
    """
    return start_date.strftime(fmt) + " - " + end_date.strftime(fmt)

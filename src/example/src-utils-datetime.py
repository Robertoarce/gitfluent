"""
Contains utiliy methods for the date time management
"""
import datetime as dt
from typing import List, Union

import numpy as np
import pandas as pd


def get_year_week_from_date(dates: pd.Series, is_week_sunday_start: bool = False):
    """
    Return iso-calendar year_week number (consistent with Nielsen definition) assuming the
    assuming the week starts on:
    - Sunday whenever `is_week_sunday_start` = True
    - Monday whenever `is_week_sunday_start` = False
    """

    if is_week_sunday_start:
        return (dates + np.timedelta64(1, "D")).dt.strftime("%G%V").astype(int)

    return dates.dt.strftime("%G%V").astype(int)


def get_week(dates: Union[pd.Series, int], check: bool = False):
    """
    Compute the week number for a corresponding date
    (Assumption: Weeks start on a Monday)

    By default, pandas assume that the week starts on Monday
    """
    if check:
        assert (dates % 100 > 0).all()
        assert (dates % 100 < 53).all()

    return dates % 100


def get_calendar_year_from_year_week(dates: Union[pd.Series, int], check: bool = False):
    """
    Compute the week number for a corresponding date
    (Assumption: Weeks start on a Monday)

    By default, pandas assume that the week starts on Monday
    Args:
        dates: year_weeks or year_months
    """
    if check:
        current_year = dt.datetime.now().year
        assert (dates // 100 >= current_year - 20).all()
        assert (dates // 100 <= current_year + 20).all()

    return dates // 100


def get_calendar_year_from_period_start(period_starts: pd.Series) -> pd.Series:
    """
    Method to get the calendar year from the date
    """
    return period_starts.dt.strftime("%Y")


def get_fiscal_year_from_year_month(
    year_month: Union[pd.Series, int],
    fiscal_year_final_month: int,
) -> Union[pd.Series, int]:
    """
    Method to get the fiscal uear from the year month formatted date
    """
    return (year_month + ((year_month % 100 - 1) // fiscal_year_final_month) * 100) // 100


def get_fiscal_year_from_period_start(
    period_starts: Union[pd.Series, int],
    fiscal_year_final_week: int,
) -> Union[pd.Series, int]:
    """
    Method to get the fiscal year from the date format
    """
    year_week = period_starts.dt.strftime("%G%V").astype(int)
    return (
        year_week
        + ((year_week % 100 - 1) // fiscal_year_final_week - (year_week % 100) // 53) * 100
    ) // 100


def get_fiscal_year_from_year_week(
    year_week: Union[pd.Series, int],
    fiscal_year_final_week: int,
) -> Union[pd.Series, int]:
    """(year_week % 100) // 53 is handling the case where there are 53 weeks in a year"""
    return (
        year_week
        + ((year_week % 100 - 1) // fiscal_year_final_week - (year_week % 100) // 53) * 100
    ) // 100


def _get_monday_of_week(year_week: int):
    """
    Method to get the Monday week number
    """
    monday = pd.to_datetime(str(year_week) + "-1", format="%Y%W-%w")
    if monday.week != year_week % 100:
        monday = monday - np.timedelta64(7, "D")

    assert (monday.week == year_week % 100) and (monday.dayofweek == 0)
    return monday


def get_weeks_after(first_week: int, number_of_weeks: int) -> List:
    """
    Returns the week after listed week
    """
    first_monday = _get_monday_of_week(first_week)
    weeks = pd.date_range(start=first_monday, periods=number_of_weeks, freq="W-MON")

    return list(get_year_week_from_date(pd.Series(weeks)))


def add_weeks_to_year_week(yearweek: int, weeks_addition: int) -> int:
    """Add or substract weeks to a year week value"""
    date_limit = dt.datetime.strptime(str(yearweek) + "-1", "%Y%W-%u") + pd.Timedelta(
        f"{weeks_addition-1} W"
    )
    computed_yearweek = int(date_limit.strftime("%G%V"))
    return computed_yearweek


def filter_time_span(
    df: pd.DataFrame, time_start: str, time_end: str, time_column: str = "year_week"
) -> pd.DataFrame:
    """[summary]
    Returns:
        pd.DataFrame -- [Filtered dataframe between start and end date]
    """
    return df[(df[time_column] >= time_start) & (df[time_column] <= time_end)]


def get_months_delta(year_month_1, year_month_2):
    """Returns months delta between two dates"""
    year_month_1 = dt.datetime(year_month_1 // 100, year_month_1 % 100, 1)
    year_month_2 = dt.datetime(year_month_2 // 100, year_month_2 % 100, 1)
    month_delta = (
        (year_month_2.year - year_month_1.year) * 12 + year_month_2.month - year_month_1.month
    )
    return month_delta + 1

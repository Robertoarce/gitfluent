import calendar
from dataclasses import dataclass
from typing import List


@dataclass(frozen=True)
class SeasonalityFeatures:
    """
    Data class for seasonality and event-related features.
    """

    # Events
    SUMMER = "summer"
    CHRISTMAS = "christmas"
    EASTER = "easter"
    OKTOBERFEST = "oktoberfest"

    # specific events
    IS_PAY_DAY = "is_pay_day"
    IS_GOLDEN_WEEK_HOLIDAYS = "is_holidays"

    # Major weeks in the year
    IS_FIRST_WEEK_OF_MONTH = "is_first_week_of_month"
    IS_WEEK_50 = "is_week_50"
    IS_WEEK_51 = "is_week_51"
    IS_WEEK_52 = "is_week_52"
    IS_WEEK_01 = "is_week_01"
    IS_WEEK_YEAR_END = "is_year_end_week"

    # Months
    JANUARY = "january"
    FEBRUARY = "february"
    MARCH = "march"
    APRIL = "april"
    MAY = "may"
    JUNE = "june"
    JULY = "july"
    AUGUST = "august"
    SEPTEMBER = "september"
    OCTOBER = "october"
    NOVEMBER = "november"
    DECEMBER = "december"

    # Quarters
    QUARTER_FIRST = "first_quarter"
    QUARTER_SECOND = "second_quarter"
    QUARTER_THIRD = "third_quarter"

    @classmethod
    def is_month(cls, feature_name: str) -> bool:
        """
        Check if a given feature name corresponds to a month.

        Args:
            feature_name (str): The name of the feature.

        Returns:
            bool: True if the feature corresponds to a month, False otherwise.
        """
        return feature_name.lower() in cls.months()

    @classmethod
    def months(cls) -> List[str]:
        """
        Get a list of all month feature names.

        Returns:
            List[str]: A list of month feature names.
        """
        return [str(getattr(cls, calendar.month_name[i].upper())) for i in range(1, 13)]


@dataclass(frozen=True)
class Features:
    """
    Data class for various features, including seasonality features.
    """

    seasonality = SeasonalityFeatures

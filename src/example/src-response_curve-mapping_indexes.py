"""
Class to map between indexes names in model (=column name) and the actual business values
"""
import logging
from dataclasses import dataclass
from typing import Dict

import pandas as pd

from src.utils.names import (
    F_BRAND_INDEX,
    F_REGION_INDEX,
    F_TIME_INDEX,
    F_TOUCHPOINT,
    F_TOUCHPOINT_INDEX,
    F_YEAR_MONTH,
)

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class MappingIndexes:
    """
    Mapping between indexes names in model (=column name) and the actual business values
        - p = touchpoint index
        - t = time index
        - b = brand index
        - r = region index
    """

    time_index_dict: Dict
    brand_index_df: pd.DataFrame
    region_index_df: pd.DataFrame
    adstock_touchpoint_index_df: pd.DataFrame
    shape_touchpoint_index_df: pd.DataFrame

    @property
    def index_brand(self) -> Dict:
        """
        Return brand index name
        """
        return self.brand_index_df.set_index([F_BRAND_INDEX])["brand_name"].to_dict()

    @property
    def brand_index(self) -> Dict:
        """
        Return brand index
        """
        return self.brand_index_df.set_index(["brand_name"])[F_BRAND_INDEX].to_dict()

    @property
    def index_region(self) -> Dict:
        """
        Return index region name
        """
        return self.region_index_df.set_index([F_REGION_INDEX])["internal_geo_code"].to_dict()

    @property
    def region_index(self) -> Dict:
        """
        Return index region
        """
        return self.region_index_df.set_index(["internal_geo_code"])[F_REGION_INDEX].to_dict()

    @property
    def index_time(self) -> Dict:
        """
        Return time index name
        """
        index_time = {}
        for brand, df in self.time_index_dict.items():
            index_time[brand] = df.set_index([F_TIME_INDEX])[F_YEAR_MONTH].to_dict()
        return index_time

    @property
    def time_index(self) -> Dict:
        """
        Return time index
        """
        index_time = {}
        for brand, df in self.time_index_dict.items():
            index_time[brand] = df.set_index([F_YEAR_MONTH])[F_TIME_INDEX].to_dict()
        return index_time

    @property
    def time_index_df(self) -> pd.DataFrame:
        """
        Return time index data frame
        """
        return pd.concat(list(self.time_index_dict.values())).reset_index(drop=True)


    @property
    def adstock_index(self) -> Dict:
        """
        Return adstock index
        """
        return self.adstock_touchpoint_index_df.set_index([F_TOUCHPOINT])[
            F_TOUCHPOINT_INDEX
        ].to_dict()

    @property
    def shape_index(self) -> Dict:
        """
        Return shape index
        """
        return self.shape_touchpoint_index_df.set_index([F_TOUCHPOINT])[
            F_TOUCHPOINT_INDEX
        ].to_dict()

from typing import Dict, Tuple

from src.utils.schemas.base_schema import BaseSchema


class GeoMasterSchema(BaseSchema):

    _label = "geo_master"

    _columns: Dict[str, Tuple[str, type]] = {
        "internal_geo_code": ("internal_geo_code", str),
        "region_code": ("region_code", str),
        "region_name": ("region_name", str),
        # "zone_code": ("zone_code", str),
        # "zone_name": ("zone_name", str),
        "market_code": ("market_code", str),
        "market_name": ("market_name", str),
        "sub_national_code": ("sub_national_code", str),
        "sub_national_name": ("sub_national_name", str),
        "currency": ("currency", str),
        "level": ("level", str),
        "sub_national_type": ("sub_national_type", str)
    }

    def __init__(self):
        super().__init__()

        self._primary_key = [self.internal_geo_code]

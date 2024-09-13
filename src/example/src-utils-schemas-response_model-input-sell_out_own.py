from typing import Dict, Tuple

from src.utils.schemas.base_schema import BaseSchema
from src.utils.enums_utils import Frequency


class SellOutOwnSchema(BaseSchema):

    _label = "sell_out_own"

    _columns: Dict[str, Tuple[str, type]] = {
        "sales_channel_code": ("channel_code", str),
        "internal_geo_code": ("internal_geo_code", str),
        # "internal_product_code": ("internal_product_code", str),
        "period_start": ("period_start", "datetime64"),
        "frequency": ("frequency", str),
        "value": ("value", float),
        "currency": ("currency", str),
        "volume": ("volume", float),
        "internal_response_geo_code": ("internal_response_geo_code", str)
    }

    def __init__(self):
        super().__init__()

        self._primary_key = [
            # self.channel_code,   #TODO: changed by Dip
            self.sales_channel_code,
            self.internal_geo_code,
            # self.internal_product_code,
            self.period_start,
        ]

        self._enum = {
            self.frequency: Frequency.get_values_aslist(),
        }

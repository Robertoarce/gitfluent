from typing import Dict, Tuple

from src.utils.schemas.base_schema import BaseSchema

from src.utils.enums_utils import Frequency


class FinanceFactsSchema(BaseSchema):

    _label = "finance_facts"

    _columns: Dict[str, Tuple[str, type]] = {
        "channel_code": ("channel_code", str),
        "internal_geo_code": ("internal_geo_code", str),
        "internal_product_code": ("internal_product_code", str),
        "period_start": ("period_start", "datetime64"),
        "frequency": ("frequency", str),
        "scenario": ("scenario", str),
        "account": ("account", str),
        "value": ("value", float),
        "currency": ("currency", str),
    }

    def __init__(self):
        super().__init__()

        self._primary_key = [
            self.channel_code,
            self.internal_geo_code,
            self.internal_product_code,
            self.period_start,
            self.scenario,
            self.account,
        ]

        self._enum = {
            self.frequency: Frequency.get_values_aslist(),
        }

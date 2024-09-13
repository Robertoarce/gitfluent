from typing import Dict, Tuple

from src.utils.enums_utils import DistributionMetric, Frequency, Unit
from src.utils.schemas.base_schema import BaseSchema


class DistributionOwnSchema(BaseSchema):
    _label = "distribution_own"

    _columns: Dict[str, Tuple[str, type]] = {
        "channel_code": ("channel_code", str),
        "internal_geo_code": ("internal_geo_code", str),
        "internal_product_code": ("internal_product_code", str),
        "period_start": ("period_start", "datetime64"),
        "frequency": ("frequency", str),
        "metric": ("metric", str),
        "unit": ("unit", str),
        "value": ("value", float),
        "currency": ("currency", str),
        "internal_response_geo_code": ("internal_response_geo_code", str),
    }

    def __init__(self):
        super().__init__()

        self._primary_key = [
            self.channel_code,
            self.internal_geo_code,
            self.internal_product_code,
            self.period_start,
            self.metric,
        ]

        self._enum = {
            self.frequency: Frequency.get_values_aslist(),
            self.metric: DistributionMetric.get_values_aslist(),
            self.unit: Unit.get_values_aslist(),
        }

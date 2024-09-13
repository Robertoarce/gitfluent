from typing import Dict, Tuple

from src.utils.schemas.base_schema import BaseSchema

from src.utils.enums_utils import Frequency, Unit


class ExternalFactsSchema(BaseSchema):

    _label = "external_facts"

    _columns: Dict[str, Tuple[str, type]] = {
        "internal_geo_code": ("internal_geo_code", str),
        "period_start": ("period_start", "datetime64"),
        "frequency": ("frequency", str),
        "metric": ("metric", str),
        "unit": ("unit", str),
        "value": ("value", float),
        "currency": ("currency", str),
    }

    def __init__(self):
        super().__init__()

        self._primary_key = [
            self.internal_geo_code,
            self.period_start,
            self.metric,
        ]

        self._enum = {
            self.frequency: Frequency.get_values_aslist(),
            self.unit: Unit.get_values_aslist(),
        }

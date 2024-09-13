from typing import Dict, Tuple

import pandas as pd

from src.utils.schemas.base_schema import BaseSchema

from src.utils.enums_utils import Frequency, TouchpointMetric, Unit


class TouchpointFactsSchema(BaseSchema):

    _label = "touchpoint_facts"

    _columns: Dict[str, Tuple[str, type]] = {
        "internal_geo_code": ("internal_geo_code", str),
        # "internal_product_code": ("internal_product_code", str),
        # "internal_touchpoint_code": ("internal_touchpoint_code", str),
        "internal_channel_code": ("internal_channel_code", str),
        "campaign_code": ("campaign_code", str),
        "period_start": ("period_start", "datetime"),
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
            # self.internal_product_code,       #TODO: Dip - not present in the table...confirming with DE team to add this column
            # self.internal_touchpoint_code,
            self.internal_channel_code,
            self.campaign_code,
            self.period_start,
            self.metric,
        ]

        self._enum = {
            self.frequency: Frequency.get_values_aslist(),
            self.unit: Unit.get_values_aslist(),
        }

    def check_enum_values(self, data: pd.DataFrame) -> None:
        super().check_enum_values(data)

        if TouchpointMetric.spend not in data[self.metric].unique():
            raise ValueError(
                f"'{TouchpointMetric.spend}' value hasn't been found in the {self.metric} column in table '{self._label}'."
            )

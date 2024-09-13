"""Currency master schema
"""
from typing import Dict, Tuple

from src.utils.enums_utils import Frequency
from src.utils.schemas.base_schema import BaseSchema


class CurrencyMasterSchema(BaseSchema):
    """Currency master schema class
    """
    _label = "currency_master"

    _columns: Dict[str, Tuple[str, type]] = {
        "from_currency": ("from_currency", str),
        "to_currency": ("to_currency", str),
        "period_start": ("period_start", "datetime64"),
        "frequency": ("frequency", str),
        "fx_rate": ("fx_rate", float),
    }

    def __init__(self):
        """Constructor method
        """
        super().__init__()

        self._primary_key = [self.from_currency, self.to_currency, self.period_start]
        self._enum = {self.frequency: Frequency.get_values_aslist()}

from typing import Dict, Tuple

from src.utils.schemas.base_schema import BaseSchema


class ChannelMasterSchema(BaseSchema):

    _label = "channel_master"

    _columns: Dict[str, Tuple[str, type]] = {
        "channel_code": ("channel_code", str),
        "channel_name": ("channel_name", str),
    }

    def __init__(self):
        super().__init__()

        self._primary_key = [self.channel_code]

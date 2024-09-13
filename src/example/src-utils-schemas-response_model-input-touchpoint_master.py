"""
Schema of Touchpoint Master dataframe
"""
from typing import Dict, Tuple

from src.utils.schemas.base_schema import BaseSchema


class TouchpointMasterSchema(BaseSchema):
    """
    Touchpoint Master class which contains touchpoint details
    """

    _label = "touchpoint_master"

    _columns: Dict[str, Tuple[str, type]] = {
        # "internal_touchpoint_code": ("internal_touchpoint_code", str),
        "internal_channel_code": ("internal_channel_code", str),
        "channel_code": ("channel_code", str),
        # "touchpoint_lvl0": ("touchpoint_lvl0", str),
        # "touchpoint_lvl1": ("touchpoint_lvl1", str),
        # "touchpoint_lvl2": ("touchpoint_lvl2", str),
        # "touchpoint_lvl3": ("touchpoint_lvl3", str),
        # "touchpoint_lvl4": ("touchpoint_lvl4", str),
        "channel_lvl0": ("channel_lvl0", str),
        "channel_lvl1": ("channel_lvl1", str),
        "channel_lvl2": ("channel_lvl2", str),
        "channel_lvl3": ("channel_lvl3", str),
        "channel_lvl4": ("channel_lvl4", str),
        # "channel_owner": ("channel_owner", str),   #TODO: new column in DWH - Dip
        # "channel_desc": ("channel_desc", str),     #TODO: new column in DWH - Dip
        "level": ("level", str),
    }

    def __init__(self):
        super().__init__()

        self._primary_key = [self.internal_channel_code]

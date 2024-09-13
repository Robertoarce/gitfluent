from typing import Dict, Tuple

from src.utils.schemas.base_schema import BaseSchema


class CampaignMasterSchema(BaseSchema):

    _label = "campaign_master"

    _columns: Dict[str, Tuple[str, type]] = {
        "campaign_code": ("campaign_code", str),
        "campaign_name": ("campaign_name", str),
        "campaign_start": ("campaign_start", "datetime64[ns]"),
        "campaign_end": ("campaign_end", "datetime64[ns]"),
    }

    def __init__(self):
        super().__init__()

        self._primary_key = [self.campaign_code]

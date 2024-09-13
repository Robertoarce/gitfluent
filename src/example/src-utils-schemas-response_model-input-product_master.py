from typing import Dict, Tuple

from src.utils.schemas.base_schema import BaseSchema


class ProductMasterSchema(BaseSchema):

    _label = "product_master"

    _columns: Dict[str, Tuple[str, type]] = {
        "internal_product_code": ("internal_product_code", str),
        "product_code": ("product_code", str),
        "product_name": ("product_name", str),
        "standard_unit_coefficient": ("standard_unit_coefficient", float),
        "gbu_code": ("gbu_code", str),
        # "category": ("category", str),
        # "sub_category": ("sub_category", str),
        # "segment": ("segment", str),
        # "brand": ("brand", str),
        # "sub_brand": ("sub_brand", str),
        "brand_name": ("brand_name", str),
        "brand_code": ("brand_code", str),
        "corporation": ("corporation", str),
        "own_product": ("own_product", bool),
        "level": ("level", str),
    }

    def __init__(self):
        super().__init__()

        self._primary_key = [self.internal_product_code]

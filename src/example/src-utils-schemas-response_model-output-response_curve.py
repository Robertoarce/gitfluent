"""
Class to capture response curve schema
"""
from typing import Dict, Tuple

from src.utils.schemas.base_schema import BaseSchema


class ResponseCurveSchema(BaseSchema):
    """
    Schema for the response curve outputted by the response model
    """

    _label = "st_response_curve_output"

    _columns: Dict[str, Tuple[str, type]] = {
        "channel_code": ("channel_code", str),
        "internal_geo_code": ("internal_geo_code", str),
        "brand_name": ("brand_name", str),
        "response_touchpoint": ("response_touchpoint", str),
        "internal_strat_touchpoint_code": ("internal_strat_touchpoint_code", str),
        "period_start": ("period_start", "datetime"),
        "frequency": ("frequency", str),
        "uplift": ("uplift", float),
        "spend": ("spend", float),
        "baseline_value": ("baseline_value", float),
        "metric": ("metric", str),
        "unit": ("unit", str),
        "value": ("value", str),
        # "currency": ("currency", str),
        "filter_out": ("filter_out", bool),
        "curve_type": ("curve_type", str),
        "internal_response_geo_code": ("internal_response_geo_code", str),
        "incremental_sell_out_units": ("incremental_sell_out_units", float),
        "gm_adjusted_incremental_value_sales": (
            "gm_adjusted_incremental_value_sales",
            float,
        ),
    }

    def __init__(self):
        self._primary_key = [
            self.channel_code,
            self.internal_geo_code,
            # self.internal_product_code,
            "brand_name",
            self.response_touchpoint,
            self.internal_strat_touchpoint_code,
            self.period_start,
            self.uplift,
            self.metric,
            self.curve_type,
            self.internal_response_geo_code,
        ]

        self._enum = {
            self.frequency: ["week", "month", "year"],
            self.metric: [
                "total_gm_incremental_sales",
                "currency",
                "gm_of_sell_out",
                "total_net_sales",
                "total_spend",
            ],
            self.unit: ["currency", "percent", "unit"],
        }


"""
self.metric: [
    "ros",
    "ros_p10",
    "ros_p90",
    "roi",
    "roi_p10",
    "roi_p90",
    "delta_to_null_value",
    "delta_to_null_value_p10",
    "delta_to_null_value_p90",
    "asp_per_unit",
    "net_sales_asp_per_unit",
    "contribution_margin_per_unit",
    "lambda_adstock",
],
"""

"""
Tests functionality of main_factory.py
"""
from unittest import TestCase

from turing_sales_allocation.main_factory import sales_allocation_factory_func
from turing_sales_allocation.mrds.sales_allocation_it import SalesAllocationIT
# from turing_sales_allocation.mrds.sales_allocation_jp import SalesAllocationJP

code_params_it = {
    "BRAND_LIST": "TOUJEO",
    "HCP_KEY": "HCP_ID",
    "SALES_JOIN_KEY": [
        "BRICK_CD",
        "BRAND_NM"],
    "IMPUTE_COLUMNS": {
        "ADOPTION_LEVEL": "NO",
        "POTENTIAL_LEVEL": "NOT",
        "SPECIALITY_NM": "OTHERS",
        "SPECIALITY_NM_2": "OTHERS",
    },
    "IMPUTE_TARGET_COL": {
        "TARGET_COL": "AGG_SALES",
        "QUANTILE": 0.98,
        "VALUE": 10},
    "TOP_ROW_REMOVE_DUPLICATE": {
        "PARTITION_BY": "HCP_ID",
        "ORDER_BY": {
                        "ADOPTION_LEVEL": True,
                        "POTENTIAL_LEVEL": True},
    },
    "OUTPUT_COLUMNS": [
        "HCP_ID",
        "BRICK_CD",
        "BRAND_NM",
        "ADOPTION_LEVEL",
        "SPECIALITY_NM",
        "SPECIALITY_NM_2",
        "AGE_BIN",
        "POTENTIAL_LEVEL",
    ],
    "DROP_NULL_COL": "BRICK_CD",
    "COMBINATION_FEATURE_LIST": [
        "ADOPTION_LEVEL",
        "AGE_BIN",
        "POTENTIAL_LEVEL",
        "SPECIALITY_NM",
        "SPECIALITY_NM_2",
        "ADOPTION_LEVEL",
        "AGE_BIN",
        "ADOPTION_LEVEL",
        "POTENTIAL_LEVEL",
        "ADOPTION_LEVEL",
        "SPECIALITY_NM",
    ],
}

code_params_jp = {
    "BRAND_LIST": "SOLIQUA",
    "HCP_KEY": "FCT_CD",
    "IMPUTE_TARGET_COL": {
        "TARGET_COL": "AGG_SALES",
        "QUANTILE": 0.98,
        "VALUE": 10},
    "TOP_ROW_REMOVE_DUPLICATE": {
        "PARTITION_BY": "FCT_CD",
        "ORDER_BY": {
            "POTENTIAL_LEVEL": True},
    },
    "OUTPUT_COLUMNS": [
        "FCT_CD",
        "BRAND_CD",
        "HCP_2_POTENTIAL",
        "HCP_3_POTENTIAL",
        "HCP_4_POTENTIAL",
        "HCP_NO_POTENTIAL",
        "AGG_SALES",
        "CALMONTH"],
    "DROP_NULL_COL": "FCT_CD",
}


class TestMainFactory(TestCase):
    """
    Class to test mrds_factory.py functions
    """

    def test_sales_allocation_factory_func(self):
        """Tests sales_allocation_factory_func function"""

        sales_allocation_obj = sales_allocation_factory_func(
            "IT", "sales_allocation", code_params_it)
        message = "given object is not instance of SalesAllocationIt"
        self.assertIsInstance(sales_allocation_obj, SalesAllocationIT, message)

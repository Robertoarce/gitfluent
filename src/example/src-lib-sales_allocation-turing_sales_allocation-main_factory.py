"""
This factory code returns a class object for each usecase and country
"""
from turing_sales_allocation.mrds import sales_allocation_de, sales_allocation_it, sales_allocation_jp


def sales_allocation_factory_func(
        country: str,
        usecase: str,
        code_params: dict):
    """Get the country specific class object for each usecase

    Arguments:
        country {str} -- Country String
        usecase {str} -- Use Case String
        code_params {dict} -- Code params from config

    Returns:
        [type] -- crrc class object
    """
    sales_allocation_country_obj_dict = {
        "sales_allocation": {
            "DE": sales_allocation_de.SalesAllocationDE,
            "IT": sales_allocation_it.SalesAllocationIT,
            "JP": sales_allocation_jp.SalesAllocationJP,
        }
    }

    return sales_allocation_country_obj_dict[usecase][country](
        usecase, code_params)

"""
Created By  : Subramanya U S
Created Date: 20/10/2022
Description : Main file to run the process from solution repository
"""
import os
import warnings
import argparse
import yaml
import pandas as pd

# --------------------------------------------------------------------------------------------------------- #
# TODO: How to get turing_generic_lib?
# --------------------------------------------------------------------------------------------------------- #
import logging
import sys
try:
    from turing_generic_lib.mrds_factory import mrds_factory_func
    from turing_generic_lib.utils.logging import get_logger
    from turing_sales_allocation.main_factory import sales_allocation_factory_func
except BaseException:
    pass
# --------------------------------------------------------------------------------------------------------- #
from turing_sales_allocation.modelling.sales_allocation import SalesAllocationModelling

warnings.filterwarnings("ignore")

SCRIPT_DIR = os.path.dirname(__file__)
APP_NAME = "Sales Allocation"
# get_logger(APP_NAME) # won't work without turing_generic_lib
LOGGER = logging.getLogger()
LOGGER.setLevel("DEBUG")
LOGGER.addHandler(logging.StreamHandler(sys.stdout))


def main():
    """Main process"""
    # Set the arguments required for running the code
    # The argument required is--countrycode
    # e.g. --countrycode US
    my_parser = argparse.ArgumentParser(
        description="Run the sales_allocation code")
    my_parser.add_argument(
        "--countrycode",
        action="store",
        type=str,
        required=True,
        help="2 character country code e.g. --countrycode US",
    )
    args = my_parser.parse_args()
    # Get the runtype and countrycode command line arguments
    countrycode = (args.countrycode).upper()
    LOGGER.info(f"Country Code : {countrycode}")

    if len(countrycode) != 2:
        raise ValueError("Country code should be 2 characters e.g. DE")

    with open(
        os.path.join(SCRIPT_DIR, "config", "country_region_mapping.yaml"), "rb"
    ) as config:
        config_params = yaml.safe_load(config)
        config_params["MAPPING"]

    with open(
        os.path.join(SCRIPT_DIR, "config", countrycode, "config.yaml"), "rb"
    ) as config:
        config_params = yaml.safe_load(config)

        data_processing_params = config_params["DATA_PROCESSING"]
        snowflake_params = config_params["SNOWFLAKE"]
        date_params = config_params["DATE"]
        date_range_params = config_params["RANGE"]
        modelling_param = config_params["MODELLING"]

    LOGGER.info("Configs read successfully")

    # --------------------------------------------------------------------------------------------------------- #
    # TODO: GET MRDS FROM MMX DATA.                                                                             #
    # We don't have the access to source data (GENMED Snowflake database)                                       #
    # We also don't have the equivalent source data yet for MMX.                                                #
    # Just skip this step for now, since we were already provided with the output data. (sample_data_italy.csv) #
    # --------------------------------------------------------------------------------------------------------- #
    if 0 == 1:
        # Get the country specific mrds object
        sales_allocation_obj = sales_allocation_factory_func(
            countrycode, "sales_allocation", data_processing_params
        )

        # Set the date params
        sales_allocation_obj.set_date_params(date_params)

        generic_lib_obj = mrds_factory_func(
            countrycode, "channeleffectiveness", "TOJ")
        generic_lib_obj.set_snowflake_connection(snowflake_params)
        sales_allocation_obj.set_snowflake_connection(
            generic_lib_obj.snowflake_con)

        # Get the dataset for sales allocation in a Dataframe
        sales_allocation_df = sales_allocation_obj.get_sales_allocation_mrds()

    # TODO: Instead, we read the pre-computed expected output from csv.
    # A copy of `sample_data_italy.csv` is already provided in the repo under (tests/unit_tests/modelling/Italy mrds.csv)
    # Just use that file, don't need to reupload it.
    sales_allocation_df = pd.read_csv(
        os.path.join(
            SCRIPT_DIR,
            "tests",
            "unit_tests",
            "modelling",
            "Italy mrds.csv"))
    # --------------------------------------------------------------------------------------------------------- #

    sales_allocation = SalesAllocationModelling(LOGGER, modelling_param)
    best_model = sales_allocation.get_model(
        sales_allocation_df, date_range_params["DATE_RANGE"]
    )
    LOGGER.info("------- Code Execution Complete -----------")


if __name__ == "__main__":
    main()

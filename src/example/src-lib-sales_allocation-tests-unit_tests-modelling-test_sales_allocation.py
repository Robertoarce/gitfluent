from unittest import TestCase

import datetime
import pandas as pd
from turing_generic_lib.utils.logging import get_logger
from sklearn.linear_model import LinearRegression
from turing_sales_allocation.modelling.sales_allocation import SalesAllocationModelling


APP_NAME = "Sales Allocation"
LOGGER = get_logger(APP_NAME)

modelling_params = {
    "MODEL": {"COEFFICIENT_POSITIVE": False, "MODEL_TYPE": "LINEAR"},
    "DATA": {
        "RANDOM_STATE": 43,
        "TEST_SIZE": 0.10,
        "TARGET_COL": "AGG_SALES",
        "DATE_COL": "CALMONTH",
        "FEATURE_LIST": {
            "ADOPTION": [
                "HCP_ADOPTION_LEVEL_USER",
                "HCP_ADOPTION_LEVEL_LAPSED_USER",
                "HCP_ADOPTION_LEVEL_NO",
            ]
        },
    },
    "MLFLOW": {
        "REMOTE_SERVER_URL": "databricks",
        "EXPERIMENT_RUN_NAME": "uca-std-rs_2nov",
        "EXPERIMENT_PATH": "/prj0020597-genmed-turing-emea01/channel_effectiveness/",
        "EXPERIMENT_LOCATION": "amber",
        "PARAMETERS": '["time_frame", "coeffcient_dict"]',
        "METRICS": "r2_score",
        "MODEL": "model",
    },
}

data_frame = pd.read_csv(
    "tests/unit_tests/modelling/Italy mrds.csv",
    nrows=100)
# data_frame = pd.concat([data_frame] * 100)
variables = modelling_params["DATA"]["FEATURE_LIST"]["ADOPTION"]
training_df = data_frame[variables]
target_col = data_frame["AGG_SALES"]


class TestSalesAllocationModelling(TestCase):
    """
    Tests the SalesAllocationModelling class
    """

    def test_get_analysis_linear_model(self):
        """
        Tests get_analysis function if model type is linear

        """
        sales_allocation_obj = SalesAllocationModelling(
            LOGGER, modelling_params)
        result = sales_allocation_obj.get_analysis(training_df, target_col)
        expected_output = {
            "coeffcient_dict": {
                "HCP_ADOPTION_LEVEL_USER": -1343.0207539682533,
                "HCP_ADOPTION_LEVEL_LAPSED_USER": -160.5687103174605,
                "HCP_ADOPTION_LEVEL_NO": -1941.7164880952378,
            },
            "coeff_analysis": False,
            "r2_score": 0.6599812482767271,
            "model": LinearRegression(),
        }
        number_of_coefficients = 3
        coeff_dict = result["coeffcient_dict"]
        self.assertEqual(len(coeff_dict), number_of_coefficients)
        self.assertListEqual(list(result), list(expected_output))

    def test_get_analysis_non_linear_model(self):
        """
        Tests get_analysis function if model type is non-linear
        """
        sales_allocation_obj = SalesAllocationModelling(
            LOGGER, modelling_params)
        result = sales_allocation_obj.get_analysis(training_df, target_col)
        number_of_coefficients = 3
        coeff_dict = result["coeffcient_dict"]
        self.assertEqual(len(coeff_dict), number_of_coefficients)

        # with self.assertLogs(LOGGER, level='INFO') as cm:
        #     sales_allocation_obj.get_analysis

    def test_dateformat_check_correct_format(self):
        """
        Tests dateformat_check function if the format is in "%Y-%m-%d"
        """
        input_date = "2022-10-10"
        sales_allocation_obj = SalesAllocationModelling(
            LOGGER, modelling_params)
        if datetime.datetime.strptime(input_date, "%Y-%m-%d"):
            expected_output = True
            result = sales_allocation_obj.dateformat_check(input_date)
            self.assertEqual(result, expected_output)

    def test_dateformat_check_incorrect_format(self):
        """
        Tests dateformat_check function if incorrect date format is provided
        """
        input_date = "2020-10-40"
        sales_allocation_obj = SalesAllocationModelling(
            LOGGER, modelling_params)
        self.assertRaises(
            ValueError,
            sales_allocation_obj.dateformat_check,
            input_date)

    def test_get_model_proper_time_range(self):
        """
        Tests get_model function for a proper time range
        """
        time = [
            {"start_date": "2020-03-29", "end_date": "2020-05-12"},
            {"start_date": "2021-05-20", "end_date": "2021-11-01"},
        ]
        sales_allocation_obj = SalesAllocationModelling(
            LOGGER, modelling_params)
        print(data_frame)
        result = sales_allocation_obj.get_model(data_frame, time)
        if result is None:
            expected_output = None
            self.assertEqual(result, expected_output)
        else:
            expected_output = result["r2_score"]
            self.assertIsNotNone(expected_output)

    def test_get_model_improper_time_range(self):
        """
        Tests get_model function if improper time range is given
        """
        time = [
            {"start_date": "2020-03-29", "end_date": "2020-05-12"},
            {"start_date": "2021-07-20", "end_date": "2021-02-01"},
        ]
        sales_allocation_obj = SalesAllocationModelling(
            LOGGER, modelling_params)
        self.assertRaises(
            ValueError,
            sales_allocation_obj.get_model,
            data_frame,
            time)

    def test_get_best_model(self):
        """
        Tests get_best_model function
        """
        input_dict = {
            "ADOPTION'": {
                "coeffcient_dict": {
                    "HCP_ADOPTION_LEVEL_USER": 46.959341318267704,
                    "HCP_ADOPTION_LEVEL_LAPSED_USER": 324.39476308851266,
                    "HCP_ADOPTION_LEVEL_NO": 957.627706817326,
                },
                "coeff_analysis": True,
                "r2_score": 0.743763787907306,
                "model": LinearRegression(),
                "time_frame": {
                    "start_date": "2021-05-20",
                    "end_date": "2021-11-01"},
            }}
        sales_allocation_obj = SalesAllocationModelling(
            LOGGER, modelling_params)
        result = sales_allocation_obj.get_best_model(input_dict)
        expected_output = {
            "coeffcient_dict": {
                "HCP_ADOPTION_LEVEL_USER": 46.959341318267704,
                "HCP_ADOPTION_LEVEL_LAPSED_USER": 324.39476308851266,
                "HCP_ADOPTION_LEVEL_NO": 957.627706817326,
            },
            "coeff_analysis": True,
            "r2_score": 0.743763787907306,
            "model": LinearRegression(),
            "time_frame": {
                "start_date": "2021-05-20",
                "end_date": "2021-11-01"},
        }
        r2_score = result["r2_score"]
        self.assertIsNotNone(r2_score)
        self.assertListEqual(list(result), list(expected_output))

    def test_get_coefficient_analysis_positive_coefficient(self):
        """
        Tests get_coefficient_analysis function for positive coefficient values and "COEFFICIENT_POSITIVE" is True
        """
        input_dict = {
            "HCP_ADOPTION_LEVEL_USER": 46.959341318267704,
            "HCP_ADOPTION_LEVEL_LAPSED_USER": 324.39476308851266,
            "HCP_ADOPTION_LEVEL_NO": 957.627706817326,
        }

        coeff_positive = modelling_params["MODEL"]["COEFFICIENT_POSITIVE"]
        output = True
        for val in input_dict.values():
            if (coeff_positive is False and val < 0) or (
                    coeff_positive is True and val == 0):
                output = False
        sales_allocation_obj = SalesAllocationModelling(
            LOGGER, modelling_params)
        result = sales_allocation_obj.get_coefficient_analysis(
            input_dict, coeff_positive)
        self.assertEqual(result, output)

    def test_get_coefficient_analysis_negative_coefficient(self):
        """
        Tests get_coefficient_analysis function for other coefficient cases
        """
        input_dict = {
            "HCP_ADOPTION_LEVEL_USER": 474.37336308851266,
            "HCP_ADOPTION_LEVEL_LAPSED_USER": 126.465341318267704,
            "HCP_ADOPTION_LEVEL_NO": 0,
        }

        coeff_positive = modelling_params["MODEL"]["COEFFICIENT_POSITIVE"]
        output = True
        for val in input_dict.values():
            if (coeff_positive is False and val < 0) or (
                    coeff_positive is True and val == 0):
                output = False
        sales_allocation_obj = SalesAllocationModelling(
            LOGGER, modelling_params)
        result = sales_allocation_obj.get_coefficient_analysis(
            input_dict, coeff_positive)
        self.assertEqual(result, output)

    def test_get_regression_analysis(self):
        """
        Tests get_regression_analysis function
        """
        sales_allocation_obj = SalesAllocationModelling(
            LOGGER, modelling_params)
        result = sales_allocation_obj.get_regression_analysis(
            training_df, target_col)
        number_of_coefficients = 3
        coeff_dict = result["coeffcient_dict"]
        expected_output = {
            "coeffcient_dict": {
                "HCP_ADOPTION_LEVEL_USER": -1343.0207539682533,
                "HCP_ADOPTION_LEVEL_LAPSED_USER": -160.5687103174605,
                "HCP_ADOPTION_LEVEL_NO": -1941.7164880952378,
            },
            "coeff_analysis": False,
            "r2_score": 0.6599812482767271,
            "model": LinearRegression(),
        }
        self.assertEqual(len(coeff_dict), number_of_coefficients)
        self.assertListEqual(list(result), list(expected_output))

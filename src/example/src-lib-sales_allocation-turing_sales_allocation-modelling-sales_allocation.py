""" This module compare the models for sales allocation
    and provide the best model for sales alloaction"""
import warnings
import datetime
import pandas as pd
import mlflow

from sklearn.model_selection import train_test_split
from sklearn.linear_model import LinearRegression
from sklearn.metrics import r2_score

from ..utils import mlflow_utils
from ..constants.constants_base import PROJECT_NAME as project


PROJECT_NAME = project

warnings.filterwarnings("ignore")


class SalesAllocationModelling:
    """This class generate best sales allocation model"""

    def __init__(self, logger, param):
        self.model_param = param["MODEL"]
        self.data_param = param["DATA"]
        self.mlflow_params = param["MLFLOW"]
        self.model_type = param["MODEL"]["MODEL_TYPE"]
        self.logger_obj = logger

    def get_analysis(self, model_data: pd.DataFrame,
                     model_target_col: pd.Series) -> dict:
        """Invokes sales allocation model methodology based on the user input.

        Arguments:
            model_data {pd.DataFrame} -- Training data
            model_target_col {pd.Series} -- Target column

        Returns:
            dict -- model artifacts
        """

        if self.model_type == "LINEAR":
            return self.get_regression_analysis(model_data, model_target_col)
        elif self.model_type == "NON-LINEAR":
            self.logger_obj.info("Implementation is not yet available")
        else:
            self.logger_obj.info(
                "Implementation is not yet available,\
                 please pass LINEAR in model type"
            )

    def dateformat_check(self, date: str):
        """Checks if the date format is YYYY-MM-DD

        Arguments:
            date {str} -- A date string

        Returns:
            Boolean -- Returns True / Raises value error depending on the inpur format
        """
        if datetime.datetime.strptime(date, "%Y-%m-%d"):
            return True
        else:
            raise ValueError("Incorrect date format, should be YYYY-MM-DD")

    def mlflow_execute(self):
        """This function will start and run the mlflow"""
        mlflow_utils.setup_mlflow_for_turing(self.mlflow_params)
        mlflow.autolog()
        with mlflow.start_run(run_name=self.mlflow_params["EXPERIMENT_RUN_NAME"]) as run:
            self.run_id = run.info.run_id

    def get_model(self, data: pd.DataFrame, date_range_list: list) -> dict:
        """Provide the best model fitted on the data

        Arguments:
            data {pd.DataFrame} -- Training data for the model
            time_frame {list} -- Parameter for best model generation within a time frame

        Returns:
            dict -- Dictionary containing best model object,
            evaluation metric output and model related artifacts
        """
        # Features, target column, date column is taken from config
        feature_list_dict = self.data_param["FEATURE_LIST"]
        target_col = self.data_param["TARGET_COL"]
        data[self.data_param["DATE_COL"]] = pd.to_datetime(
            data[self.data_param["DATE_COL"]], format="%Y%m")
        result_dict = {}

        # Iterating over date range and feature list for best model
        for idx, date_range in enumerate(date_range_list):
            if self.dateformat_check(
                    date_range["start_date"]) and self.dateformat_check(
                    date_range["end_date"]):
                start_date = date_range["start_date"]
                end_date = date_range["end_date"]
            if start_date > end_date:
                raise ValueError("Improper range given.")
            else:
                data_range = data[(data[self.data_param["DATE_COL"]] >= start_date) & (
                    data[self.data_param["DATE_COL"]] <= end_date)]
                data_range[target_col] = data_range[target_col].fillna(0)
                target_data = data_range[target_col]
                data_range = data_range.drop(target_col, axis=1)
                model_target_col = target_data.copy()
            for index, variable in enumerate(feature_list_dict.keys()):
                model_data = data_range[feature_list_dict[variable]]
                regression_result_dict = self.get_analysis(
                    model_data, model_target_col)
                regression_result_dict["date_range"] = {
                    "start_date": start_date, "end_date": end_date}
                result_dict[variable +
                            '_' +
                            str(idx) +
                            '_' +
                            str(index)] = regression_result_dict
        best_model_dict = self.get_best_model(result_dict)
        if best_model_dict is None:
            self.logger_obj.info("No model satisfy the requried criterion")
        else:
            # Starting and logging into Ml Flow
            self.mlflow_execute()
            params_log = {"coeff_analysis": best_model_dict["coeff_analysis"]}
            for key in self.mlflow_params["PARAMETERS"]:
                params_log.update(best_model_dict[key])
            mlflow.log_params(params_log)
            mlflow.log_metric("r2_score",
                              best_model_dict[self.mlflow_params["METRICS"]])
            mlflow.sklearn.log_model(
                best_model_dict[self.mlflow_params["MODEL"]], "best_model")
        return best_model_dict

    def get_best_model(self, models_coefficient_dict: dict) -> dict:
        """Select the best model based on the R2 and beta-coefficient values

        Arguments:
            models_coefficient_dict {dict} -- nested dictionary of model artifacts for various feature groups

        Returns:
            dict -- model artifacts of best model
        """
        if self.model_type == "LINEAR":
            best_result = None
            best_r2 = 0
            for key in models_coefficient_dict.keys():
                if (
                    models_coefficient_dict[key]["coeff_analysis"] is True
                    and best_r2 < models_coefficient_dict[key]["r2_score"]
                ):
                    best_r2 = models_coefficient_dict[key]["r2_score"]
                    best_result = models_coefficient_dict[key]
            return best_result

    def get_coefficient_analysis(
            self,
            coeffcient_dict: dict,
            coefficient_positive: bool) -> bool:
        """Analysis the beta-coefficient values

        Arguments:
            coeffcient_dict {dict} -- coefficient values
            coefficient_positive {bool} -- postive coefficient enforcer

        Returns:
            bool -- return boolean value satisfying the coefficient analysis logic
        """
        positive_coeff = True
        for coeff_val in coeffcient_dict.values():
            if (coefficient_positive is False and coeff_val < 0) or (
                coefficient_positive is True and coeff_val == 0
            ):
                positive_coeff = False
        return positive_coeff

    def get_regression_analysis(
            self,
            data: pd.DataFrame,
            target_data: pd.Series) -> dict:
        """Fit Regression Model

        Arguments:
            data {pd.DataFrame} -- training data
            target_data {pd.Series} -- target data

        Returns:
            dict -- model artifacts
        """
        random_state = self.data_param["RANDOM_STATE"]
        test_size = self.data_param["TEST_SIZE"]
        coefficient_positive = self.model_param["COEFFICIENT_POSITIVE"]
        regression_result_dict = {}

        # data should be sorted
        x_train, x_test, y_train, y_test = train_test_split(
            data, target_data, test_size=test_size, random_state=random_state
        )
        # adding coefficient is positive
        model = LinearRegression(positive=coefficient_positive)
        model.fit(x_train, y_train)
        predictions = model.predict(x_test)
        r2_score_val = r2_score(y_test, predictions)
        # log r2, beta coefficient and variables in mlflow

        # generate df with coefficient and variable name
        coeffcient_dict = dict(
            zip(list(model.feature_names_in_), list(model.coef_)))
        coeff_analysis = self.get_coefficient_analysis(
            coeffcient_dict, coefficient_positive)

        regression_result_dict["coeffcient_dict"] = coeffcient_dict
        regression_result_dict["coeff_analysis"] = coeff_analysis
        regression_result_dict["r2_score"] = r2_score_val
        regression_result_dict["model"] = model

        return regression_result_dict

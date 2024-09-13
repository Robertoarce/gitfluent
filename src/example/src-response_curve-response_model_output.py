"""
Prepare response curve output table
"""
import os.path as osp

import pandas as pd

from src.pipeline.feature_engineering.utils import save_file
from src.response_curve.output_formatting.aggregation import get_spend_value_yr_df
from src.response_curve.output_formatting.contribution import (
    compute_feature_brand_contribution_df,
)
from src.response_curve.output_formatting.output_table import (
    create_st_response_curve_output_table,
)
from src.response_curve.output_formatting.regression_metrics import (
    create_regression_metrics_table,
    save_durbin_watson_results,
)
from src.response_curve.output_formatting.roi import (
    compute_revenues_and_caap,
    compute_roi_table,
)
from src.response_curve.output_formatting.st_curve_metrics import (
    create_st_response_curve_metrics_table,
)
from src.response_curve.output_formatting.utils import add_total_metrics
from src.response_curve.plot_response_curves import plot_response_curves
from src.response_curve.response_curve_generator import ResponseCurvesManager
from src.utils.data_frames import reduce_data_frames
from src.utils.plot_fit_regression import PlotFitRegression


class ResponseModelOutput:
    """
    Class to prepare response curve output
    """

    def __init__(
        self,
        config,
        response_curves_manager,
        results_bayesian_uplift,
        experiment_tracker,
        lambda_adstock_df,
        data_aggregator,
        level,
        channel_code,
    ):
        """
        Constructor method
        """
        self.config = config
        self.response_curves_manager = response_curves_manager

        self.delta_to_null_value_uplift_df = results_bayesian_uplift.value_uplift_df

        self.national_features_df = response_curves_manager.national_aggregated_features
        self.denormalized_output_df = results_bayesian_uplift.denormalized_output_df
        self.delta_to_null_value_contribution_df = results_bayesian_uplift.value_contribution_df
        self.experiment_tracker = experiment_tracker
        self.lambda_adstock_df = lambda_adstock_df
        self.data_aggregator = data_aggregator
        self.level = level
        self.channel_code = channel_code

    def run(self):
        """
        Method to generate ROI, ROS, response curve metric and output table
        """
        df = self.denormalized_output_df.copy()
        # Extract the year from the 'year_month' column
        df["year"] = df["year_month"].astype(str).str.slice(0, 4).astype(int)
        df["touchpoint_name"] = df["touchpoint"].astype(str).str.slice(start=6).str.upper()
        for year, touchpoint_dict in self.config.get("interaction_to_spend").items():
            for touchpoint, value in touchpoint_dict.items():
                df.loc[
                    (df["year"] == int(year)) & (df["touchpoint_name"] == touchpoint),
                    "feature",
                ] *= value
        df.drop(["year", "touchpoint_name"], axis=1, inplace=True)
        self.denormalized_output_df = df.copy()

        df = self.national_features_df.copy()
        df["year"] = df["year_month"].astype(str).str.slice(0, 4).astype(int)
        for year, touchpoint_dict in self.config.get("interaction_to_spend").items():
            for touchpoint, value in touchpoint_dict.items():
                df.loc[(df["year"] == year), "spend_" + touchpoint.lower()] *= value
        df.drop("year", axis=1, inplace=True)
        self.national_features_df = df.copy()

        spend_value_yr_df = get_spend_value_yr_df(
            denormalized_output_df=self.denormalized_output_df,
            response_curves_manager=self.response_curves_manager,
            config=self.config,
        )

        feature_brand_contribution_df = compute_feature_brand_contribution_df(
            delta_to_null_value_contribution_df=self.delta_to_null_value_contribution_df,
            spend_value_yr_df=spend_value_yr_df,
            response_curves_manager=self.response_curves_manager,
            config=self.config,
        )

        roi_table_df, roi_table_new = compute_roi_table(
            delta_to_null_value_uplift_df=self.delta_to_null_value_uplift_df,
            spend_value_yr_df=spend_value_yr_df,
            response_curves_manager=self.response_curves_manager,
            config=self.config,
        )
        roi_table_df.fillna(0, inplace=True)
        save_file(
            data=roi_table_df,
            file_name=f'{"metrics/roi_table_original.csv"}',
            experiment_tracker=self.experiment_tracker,
            mlflow_directory=self.channel_code
            if self.level is None
            else osp.join(
                self.level["speciality"],
                self.level["segment_code"],
                self.level["segment_value"],
            ),
        )

        save_file(
            data=roi_table_new,
            file_name=f'{"metrics/roi_table_new.csv"}',
            experiment_tracker=self.experiment_tracker,
            mlflow_directory=self.channel_code
            if self.level is None
            else osp.join(
                self.level["speciality"],
                self.level["segment_code"],
                self.level["segment_value"],
            ),
        )

        # Relevant metrics characterizing the results of the Bayesian model
        # (contribution, R2, etc.)
        (
            regression_metrics_df,
            pred_vs_actual_df,
            residuals_df,
        ) = create_regression_metrics_table(
            denormalized_output_df=self.denormalized_output_df,
            national_features_df=self.national_features_df,
            config=self.config,
        )

        if self.config.get("save_debug_fit_plots"):
            fit_regression = PlotFitRegression(
                pred_vs_actual_df=pred_vs_actual_df,
                residuals_df=residuals_df,
                experiment_tracker=self.experiment_tracker,
                config=self.config,
                segment_code=self.channel_code,
            )
            fit_regression.plot_true_vs_pred_hist()
            fit_regression.plot_true_vs_pred_scatter(self.channel_code)
            fit_regression.plot_residuals()
            del fit_regression

        if self.config.get("save_debug_model_metrics"):
            save_durbin_watson_results(
                residuals_df, self.config, self.experiment_tracker, self.channel_code
            )

        save_file(
            data=regression_metrics_df,
            file_name=f'{"metrics/regression_metrics.csv"}',
            experiment_tracker=self.experiment_tracker,
            mlflow_directory=self.channel_code
            if self.level is None
            else osp.join(
                self.level["speciality"],
                self.level["segment_code"],
                self.level["segment_value"],
            ),
        )

        save_file(
            data=pred_vs_actual_df,
            file_name=f'{"metrics/pred_vs_actual_df.csv"}',
            experiment_tracker=self.experiment_tracker,
            mlflow_directory=self.channel_code
            if self.level is None
            else osp.join(
                self.level["speciality"],
                self.level["segment_code"],
                self.level["segment_value"],
            ),
        )
        st_response_curve_metrics_df = create_st_response_curve_metrics_table(
            regression_metrics_df=regression_metrics_df,
            feature_brand_contribution_df=feature_brand_contribution_df,
            response_curves_manager=self.response_curves_manager,
            config=self.config,
        )
        save_file(
            data=st_response_curve_metrics_df,
            file_name=f'{"metrics/response_curve_metric.csv"}',
            experiment_tracker=self.experiment_tracker,
            mlflow_directory=self.channel_code
            if self.level is None
            else osp.join(
                self.level["speciality"],
                self.level["segment_code"],
                self.level["segment_value"],
            ),
        )

        # Reference ROI table for optimizer & table with bayesian model metrics
        # for WebApp
        st_response_curve_output_df = create_st_response_curve_output_table(
            pred_vs_actual_df=pred_vs_actual_df,
            roi_table_df=roi_table_df,
            national_features_df=self.national_features_df,
            lambda_adstock_df=self.lambda_adstock_df,
            response_curves_manager=self.response_curves_manager,
            config=self.config,
            data_aggregator=self.data_aggregator,
        )
        save_file(
            data=st_response_curve_output_df,
            file_name=f'{"metric/response_curve_output.csv"}',
            experiment_tracker=self.experiment_tracker,
            mlflow_directory=self.channel_code
            if self.level is None
            else osp.join(
                self.level["speciality"],
                self.level["segment_code"],
                self.level["segment_value"],
            ),
        )

        self.prepare_debug_outputs(
            roi_table_df=roi_table_df,
            response_curves_manager=self.response_curves_manager,
            config=self.config,
            # **output_dict,
        )

        return {
            "st_response_curve_metrics_df": st_response_curve_metrics_df,
            "st_response_curve_output_df": st_response_curve_output_df,
        }

    def prepare_debug_outputs(
        self,
        roi_table_df: pd.DataFrame,
        response_curves_manager,
        config,
    ):
        """
        Function centralizing all the calls to the debugging functions. This function returns the formatted outputs to be
        saved as a dict
        """
        if config.get("save_debug_response_curve_plots"):
            plot_response_curves(
                roi_table_df=roi_table_df,
                column_year=response_curves_manager.column_year,
                config=config,
                experiment_tracker=self.experiment_tracker,
                levels=self.level,
                channel_code=self.channel_code,
            )

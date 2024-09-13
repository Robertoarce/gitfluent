"""
Class to plot debug regression plots
"""
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

from src.pipeline.feature_engineering.utils import save_file
from src.utils.names import (
    F_CHANNEL_CODE,
    F_VALUE,
    F_VALUE_PRED,
    F_YEAR_MONTH,
    F_VALUE_PRED_p10,
    F_VALUE_PRED_p90,
)
from src.utils.plots import (
    add_plot_info,
    get_plot_arrays,
    plot_actual_target_line,
    plot_curve_with_confidence_interval,
    plot_xticks_beautiful_str,
)
from src.utils.schemas.response_model.input import ProductMasterSchema

pms = ProductMasterSchema()


def format_forecast_vs_actual_overview(actual_vs_pred_df: pd.DataFrame):
    """
    Formats the actual vs predicted dataframe
    """
    aggregation = {
        F_VALUE: "mean",
        F_VALUE_PRED: "mean",
        F_VALUE_PRED_p10: "mean",
        F_VALUE_PRED_p90: "mean",
    }
    aggregation = dict(
        filter(
            lambda k: k[0] in actual_vs_pred_df.columns and actual_vs_pred_df[k[0]].notnull().any(),
            aggregation.items(),
        )
    )
    assert not actual_vs_pred_df.duplicated([F_CHANNEL_CODE, "brand_name", F_YEAR_MONTH]).any()
    return actual_vs_pred_df.groupby(
        [F_CHANNEL_CODE, "brand_name", F_YEAR_MONTH], as_index=False
    ).agg(aggregation)


class PlotFitRegression:
    """
    Create graphs:
    - Historic sales value vs spends
    -
    """

    def __init__(
        self,
        pred_vs_actual_df: pd.DataFrame,
        residuals_df: pd.DataFrame,
        experiment_tracker,
        config,
        segment_code,
    ):
        self.actual_vs_pred_df = format_forecast_vs_actual_overview(pred_vs_actual_df)
        self.residuals_df = residuals_df
        self.config = config
        self.experiment_tracker = experiment_tracker
        self.segment_code = segment_code

    def plot_residuals(self):
        """
        :return:
        """

        channels = self.residuals_df[F_CHANNEL_CODE].unique()

        for channel in channels:
            df = self.residuals_df[self.residuals_df[F_CHANNEL_CODE] == channel].copy()
            brands = df["brand_name"].unique()
            fig, ax = plt.subplots(figsize=(15, 8 * len(brands)), nrows=max(len(brands), 2))
            cur_ax = 0
            for brand in brands:
                to_plot_df = df[df["brand_name"] == brand].copy()
                to_plot_df[
                    ["residuals", "residuals_p10", "residuals_p90"]
                ] /= to_plot_df.residuals.std()

                x, y, lb, ub = get_plot_arrays(to_plot_df, x_name=F_YEAR_MONTH, y_name="residuals")
                ax[cur_ax] = plot_curve_with_confidence_interval(
                    ax[cur_ax], x, y, lb, ub, label="Pred"
                )

                add_plot_info(
                    ax[cur_ax],
                    xlabel="year_month",
                    ylabel="Residuals",
                    title=f"{brand} - Residuals actual vs predicted value",
                    config=self.config,
                )
                ax[cur_ax] = plot_xticks_beautiful_str(ax[cur_ax])
                ax[cur_ax].legend()
                ax[cur_ax].tick_params(axis="x", labelrotation=45)
                cur_ax += 1

            save_file(
                data=fig,
                file_name=f"fit_residuals_{self.segment_code}.png",
                experiment_tracker=self.experiment_tracker,
                mlflow_directory=self.segment_code,
            )

            plt.close()

    def plot_true_vs_pred_hist(self):
        """
        Wrapper method to plot the true vs. predicted value plot
        """
        for channel in self.actual_vs_pred_df[F_CHANNEL_CODE].unique():
            self._plot_true_vs_pred_hist(
                col_true=F_VALUE,
                col_pred=F_VALUE_PRED,
                channel_code=channel,
            )

    def _plot_true_vs_pred_hist(self, col_true: str, col_pred: str, channel_code: str):
        """
        Internal method to plot the true vs. predicted value plot
        """
        df_channel = self.actual_vs_pred_df[
            self.actual_vs_pred_df[F_CHANNEL_CODE] == channel_code
        ].copy()
        brand_set = set(df_channel["brand_name"].unique())
        fig, ax = plt.subplots(figsize=(8, 8 * len(brand_set)), nrows=max(len(brand_set), 2))

        cur_ax = 0
        for brand in brand_set:
            to_plot_df = df_channel[df_channel["brand_name"] == brand].copy()
            to_plot_df[F_YEAR_MONTH] = to_plot_df[F_YEAR_MONTH].astype(str)

            x, y, lb, ub = get_plot_arrays(to_plot_df, x_name=F_YEAR_MONTH, y_name=col_pred)
            ax[cur_ax] = plot_curve_with_confidence_interval(ax[cur_ax], x, y, lb, ub, label="Pred")
            ax[cur_ax] = plot_actual_target_line(ax[cur_ax], x, to_plot_df[col_true])
            ax[cur_ax].set_ylim(bottom=0)
            add_plot_info(
                ax[cur_ax],
                xlabel="year_month",
                ylabel="sales value",
                title=f"{brand} - Actual vs predicted sales value",
                config=self.config,
            )
            ax[cur_ax] = plot_xticks_beautiful_str(ax[cur_ax])
            ax[cur_ax].legend()
            ax[cur_ax].tick_params(axis="x", labelrotation=45)
            cur_ax += 1

        save_file(
            data=fig,
            file_name=f"fit_quality_history_{self.segment_code}.png",
            experiment_tracker=self.experiment_tracker,
            mlflow_directory=self.segment_code,
        )

    def plot_true_vs_pred_scatter(self, channel_code):
        """
        Method to plot true vs. predicted scatter plot
        """
        print(f"Plotting actual vs. predicted curve for channel code: {channel_code}")
        brand_set = set(self.actual_vs_pred_df["brand_name"].unique())
        fig, ax = plt.subplots(figsize=(8, 8 * len(brand_set)), nrows=max(len(brand_set), 2))

        cur_ax = 0
        for brand in brand_set:
            to_plot_df = self.actual_vs_pred_df[
                self.actual_vs_pred_df["brand_name"] == brand
            ].copy()

            # --- Scatterplot of the fit ---
            Y_true = to_plot_df[F_VALUE]
            Y_pred = to_plot_df[F_VALUE_PRED]

            min_scale = min(Y_true.min(), Y_pred.min())
            max_scale = max(Y_true.max(), Y_pred.max())
            ax[cur_ax].plot([min_scale, max_scale], [min_scale, max_scale])

            sns.scatterplot(x=F_VALUE, y=F_VALUE_PRED, data=to_plot_df, ax=ax[cur_ax])
            ax[cur_ax].set_title(f"True vs predicted value for {brand}")
            ax[cur_ax].set_ylabel("Pred")
            ax[cur_ax].set_xlabel("True")
            cur_ax += 1

        save_file(
            data=fig,
            file_name=f"fit_quality_scatter_{self.segment_code}.png",
            experiment_tracker=self.experiment_tracker,
            mlflow_directory=self.segment_code,
        )

        plt.close()

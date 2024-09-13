"""
Functions to plot response curves
"""
import logging
import os.path as osp
from typing import List

import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns
from box import Box

from src.pipeline.feature_engineering.utils import save_file
from src.utils.names import (
    F_CHANNEL_CODE,
    F_DELTA_TO_NULL_REVENUES,
    F_ROI,
    F_ROS,
    F_SPEND,
    F_TOUCHPOINT,
    F_UPLIFT,
)
from src.utils.plots import (
    add_plot_info,
    get_plot_arrays,
    highlight_status_quo,
    plot_curve_with_confidence_interval,
)
from src.utils.schemas.response_model.input import ProductMasterSchema
from src.utils.settings_utils import get_feature_from_name, get_touchpoints_from_tags

pms = ProductMasterSchema()


def plot_response_curves(
    roi_table_df: pd.DataFrame,
    column_year: str,
    config,
    experiment_tracker,
    levels,
    channel_code,
):
    """
    Function to plot all response curves
    """
    if not config["UPLIFT_VALUES_TO_COMPUTE"]:
        return

    # Compute revenue uplift on total market
    roi_table_full_df = roi_table_df[roi_table_df[F_CHANNEL_CODE] == "all"]

    # Save all relevant plots
    response_curve = PlotResponseCurve(
        config=config,
        roi_table_df=roi_table_full_df,
        column_year=column_year,
        experiment_tracker=experiment_tracker,
    )
    response_curve.plot_response_curves(
        x_variable=F_SPEND,
        y1_variable=F_ROS,
        y2_variable=None,
        levels=levels,
        channel_code=channel_code,
    )


class PlotResponseCurve():
    """Class to plot response curve

    """
    def __init__(
        self,
        config,
        roi_table_df: pd.DataFrame,
        column_year: str,
        experiment_tracker,
    ):
        self.config = Box(config)
        self.roi_table_df = roi_table_df
        self.column_year = column_year
        self.experiment_tracker = experiment_tracker

    def _get_scoped_results(
        self,
        year: int,
        brand: str = None,
        touchpoints: List[str] = None,
        is_limited_scope: bool = True,
    ) -> pd.DataFrame:
        idx = self.roi_table_df[self.column_year] == year
        if brand is not None:
            idx = idx & (
                self.roi_table_df[self.config.get("RESPONSE_LEVEL_PRODUCT")] == brand
            )  # pms.internal_product_code

        if touchpoints is not None:
            idx = idx & (
                self.roi_table_df[F_TOUCHPOINT].isin(
                    # list(map(lambda x: "spend_" + x, touchpoints))    #TODO:
                    # Dip -  config names are in spend_ format
                    touchpoints
                )
            )

        if is_limited_scope:
            idx = idx & (
                self.roi_table_df[F_TOUCHPOINT].isin(
                    self.selected_touchpoints_for_response_curves()
                )
            )

        results_scoped_df = self.roi_table_df[idx].copy()
        results_scoped_df["key"] = results_scoped_df[self.config.get("granularity_output")].apply(
            tuple, axis=1
        )

        return results_scoped_df

    def selected_touchpoints_for_response_curves(self) -> List[str]:
        """Returns selected touchpoint for the reseponse curves

        Returns:
            List[str] -- [description]
        """
        tags = ["media", "trade_marketing", "visibility", "mmx"]
        return_feature = True
        output = []
        for _, param_dict in self.config.get("STAN_PARAMETERS").items():
            for predictor, value in param_dict.items():
                if "tags" in value:
                    for tag in tags:
                        if tag in value["tags"] and return_feature is False:
                            output.append(predictor)
                        elif tag in value["tags"]:
                            output.append(get_feature_from_name(self.config, predictor))
        return output

    def _plot_response_curves_with_confidence_interval(
        self,
        response_results_df: pd.DataFrame,
        x_name: str,
        y1_name: str,
        y2_name: str,
        file_name: str,
        brand: str,
        year: int,
        common_axis=False,
        levels=None,
        channel_code: str = "",
    ):
        ncols = response_results_df["key"].nunique()

        if common_axis:
            fig, ax = plt.subplots(
                figsize=(8 * ncols, 16),
                nrows=2,
                ncols=ncols,
                sharex="all",
                sharey="row",
                squeeze=False,
            )
        else:
            # fig, ax = plt.subplots(
            #     figsize=(8 * ncols, 16), nrows=2, ncols=ncols, squeeze=False
            # )                                                                             
            # #TODO: Updated by Dip - We don't need delta to null curves so removing them
            fig, ax = plt.subplots(figsize=(8 * ncols, 8), nrows=1, ncols=ncols, squeeze=False)

        fig.suptitle(
            f"Response curves for {brand.replace('_', ' ')} on year {year}",
            fontsize=self.config.plot_font_size,
        )

        cur_ax = 0
        max_spend = response_results_df[x_name].max()
        if common_axis:
            ax[0, cur_ax].set_xlim(xmin=0, xmax=max_spend)

        for key in response_results_df["key"].unique():
            to_plot_df = response_results_df[response_results_df["key"] == key]

            if to_plot_df[y2_name].notnull().sum() == 0:
                continue

            current_spend = to_plot_df.loc[to_plot_df["uplift"] == 1][x_name].values
            if y1_name:
                current_revenues = to_plot_df.loc[to_plot_df["uplift"] == 1][y1_name].values
            if y2_name:
                current_roi = to_plot_df.loc[to_plot_df["uplift"] == 1][y2_name].values
            i = 0
            if y1_name:
                # --- Response curve ---
                x, y, lb, ub = get_plot_arrays(to_plot_df, x_name, y1_name)
                ax[i, cur_ax] = plot_curve_with_confidence_interval(ax[i, cur_ax], x, y, lb, ub)
                ax[i, cur_ax] = highlight_status_quo(ax[i, cur_ax], current_spend, current_revenues)
                ax[i, cur_ax].ticklabel_format(style="sci", axis="both", scilimits=(0, 0))
                ax[i, cur_ax] = add_plot_info(
                    ax[i, cur_ax],
                    title=key[1],
                    xlabel="interactions",
                    ylabel="Delta to zero-spend revenues",
                    config=self.config,
                )
                i += 1

            # --- ROI curve ---
            x, y, lb, ub = get_plot_arrays(to_plot_df, x_name, y2_name)
            ax[i, cur_ax] = plot_curve_with_confidence_interval(ax[i, cur_ax], x, y, lb, ub)
            ax[i, cur_ax] = highlight_status_quo(ax[i, cur_ax], current_spend, current_roi)
            ax[i, cur_ax].ticklabel_format(style="sci", axis="x", scilimits=(0, 0))
            ax[i, cur_ax] = add_plot_info(
                ax[i, cur_ax],
                title=key[1],
                xlabel="interactions",
                ylabel=y2_name.upper(),
                config=self.config,
            )
            ax[i, cur_ax].set_xlim(left=ax[0, cur_ax].get_xlim()[0])

            cur_ax += 1

        # fig.tight_layout()
        if common_axis:
            save_file(
                data=fig,
                # response_curves/per_brand_per_touchpoint_common_axis/
                file_name=f"{file_name}",
                experiment_tracker=self.experiment_tracker,
                mlflow_directory=channel_code
                if levels is None
                else osp.join(
                    levels["speciality"],
                    levels["segment_code"],
                    levels["segment_value"],
                ),
            )
        else:
            save_file(
                data=fig,
                file_name=f"response_curves/per_brand_per_touchpoint/{file_name}",
                experiment_tracker=self.experiment_tracker,
                mlflow_directory=channel_code
                if levels is None
                else osp.join(
                    levels["speciality"],
                    levels["segment_code"],
                    levels["segment_value"],
                ),
            )

        plt.close()

    def _plot_overlaying_response_curves(
        self,
        response_results_df: pd.DataFrame,
        x_name: str,
        y1_name: str,
        y2_name: str,
        file_name: str,
        year: int,
        levels: dict,
        channel_code: str,
    ):
        # pms.internal_product_code
        ncols = response_results_df["brand_name"].nunique()

        fig, ax = plt.subplots(figsize=(8 * ncols, 8), nrows=1, ncols=ncols, squeeze=False)
        fig.suptitle(
            f"Response curves per brand on year {year}",
            fontsize=self.config.plot_font_size,
        )

        cur_ax = 0

        for brand, to_plot_df in response_results_df.groupby(
            ["brand_name"]  # pms.internal_product_code
        ):
            current_to_plot_df = to_plot_df.loc[to_plot_df[F_UPLIFT] == 1]
            i = 0
            if y1_name:
                # --- Response curve ---
                ax[i, cur_ax] = sns.lineplot(
                    x=x_name,
                    y=y1_name,
                    hue=F_TOUCHPOINT,
                    data=to_plot_df,
                    ax=ax[i, cur_ax],
                )
                ax[i, cur_ax] = sns.scatterplot(
                    x=x_name,
                    y=y1_name,
                    hue=F_TOUCHPOINT,
                    data=current_to_plot_df,
                    ax=ax[i, cur_ax],
                    legend=False,
                )
                ax[i, cur_ax].ticklabel_format(style="sci", axis="both", scilimits=(0, 0))
                ax[i, cur_ax] = add_plot_info(
                    ax[i, cur_ax],
                    title=brand,
                    xlabel="Interactions",
                    ylabel="Delta to zero-spend revenues",
                    config=self.config,
                )
                i += 1
            if y2_name:
                # --- Return curve ---
                sns.lineplot(
                    x=x_name,
                    y=y2_name,
                    hue=F_TOUCHPOINT,
                    data=to_plot_df,
                    ax=ax[i, cur_ax],
                )
                sns.scatterplot(
                    x=x_name,
                    y=y2_name,
                    hue=F_TOUCHPOINT,
                    data=current_to_plot_df,
                    ax=ax[i, cur_ax],
                    legend=False,
                )
                ax[i, cur_ax].ticklabel_format(style="sci", axis="both", scilimits=(0, 0))
                ax[i, cur_ax] = add_plot_info(
                    ax[i, cur_ax],
                    title=brand,
                    xlabel="Interactions",
                    ylabel=y2_name.upper(),
                    config=self.config,
                )
                ax[i, cur_ax].set_xlim(left=ax[0, cur_ax].get_xlim()[0])

            cur_ax += i

        save_file(
            data=fig,
            file_name=f"{file_name}",  # response_curves/per_brand/
            experiment_tracker=self.experiment_tracker,
            mlflow_directory=channel_code
            if levels is None
            else osp.join(levels["speciality"], levels["segment_code"], levels["segment_value"]),
        )
        plt.close()

    def plot_response_curves(
        self,
        x_variable: str = F_SPEND,
        y1_variable: str = F_ROS,
        y2_variable: str = F_ROI,
        levels=None,
        channel_code=None,
    ):
        """

        :param country:
        :param x_variable: n.F_FEATURE ou n.F_SPEND
        :param y1_variable:
        :param y2_variable:
        :return:
        """
        # Overlaying response curves
        for year in self.config.get("RESPONSE_CURVE_YEARS"):
            for touchpoints, touchpoint_type in (
                (
                    get_touchpoints_from_tags(self.config, ["trade_marketing"]),
                    "trade_marketing",
                ),
                (
                    get_touchpoints_from_tags(self.config, ["media"]),
                    "media",
                ),
                (
                    get_touchpoints_from_tags(self.config, ["mmx"]),
                    "mmx",
                ),
            ):
                # Saving plots only if there are touchpoints
                if len(touchpoints) > 0:
                    response_results_df = self._get_scoped_results(
                        brand=None,
                        year=year,
                        touchpoints=touchpoints,
                        is_limited_scope=True,
                    )

                    self._plot_overlaying_response_curves(
                        response_results_df=response_results_df,
                        x_name=x_variable,
                        # y1_name=F_DELTA_TO_NULL_REVENUES,
                        y1_name=None,
                        y2_name=y1_variable,
                        file_name=f"response_revenues_{y1_variable.lower()}_{touchpoint_type}_{year}.png",
                        year=year,
                        levels=levels,
                        channel_code=channel_code,
                    )
                else:
                    log = logging.getLogger(__name__)
                    log.warning(
                        "There are no available touchpoints of type {touchpoint_type}. Response curve for "
                        "{touchpoint_type} has not been generated".format(
                            touchpoint_type=touchpoint_type
                        )
                    )

        for brand in self.roi_table_df["brand_name"].unique():  # pms.internal_product_code
            for year in self.config.get("RESPONSE_CURVE_YEARS"):
                response_results_df = self._get_scoped_results(
                    brand=brand, year=year, touchpoints=None, is_limited_scope=True
                )

                if len(response_results_df) > 0:
                    # Plot response curves on separate graphs
                    self._plot_response_curves_with_confidence_interval(
                        file_name=f"joint_response_revenues_{y1_variable.lower()}_{brand}_{year}.png",
                        response_results_df=response_results_df,
                        x_name=x_variable,
                        y1_name=None,  # F_DELTA_TO_NULL_REVENUES,
                        y2_name=y1_variable,
                        brand=brand,
                        year=year,
                        common_axis=False,
                        levels=levels,
                        channel_code=channel_code,
                    )

                    # Plot response curves on separate graphs with the same
                    # x-axis
                    self._plot_response_curves_with_confidence_interval(
                        file_name=f"joint_response_revenues_{y1_variable.lower()}_{brand}_{year}.png",
                        response_results_df=response_results_df,
                        x_name=x_variable,
                        y1_name=F_DELTA_TO_NULL_REVENUES,
                        y2_name=y1_variable,
                        brand=brand,
                        year=year,
                        common_axis=True,
                        levels=levels,
                    )

                    # Plot ROI response curves
                    if y2_variable:
                        self._plot_response_curves_with_confidence_interval(
                            file_name=f"joint_response_revenues_{y2_variable.lower()}_{brand}_{year}.png",
                            response_results_df=response_results_df,
                            x_name=x_variable,
                            # y1_name=F_DELTA_TO_NULL_REVENUES,
                            y1_name=None,
                            y2_name=y2_variable,
                            brand=brand,
                            year=year,
                            common_axis=False,
                            levels=levels,
                        )

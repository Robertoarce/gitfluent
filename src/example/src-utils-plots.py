from typing import List, Tuple

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
from matplotlib.axes import Axes

from src.pipeline.feature_engineering.utils import save_file
from src.utils.data.data_manager import DataManager
from src.utils.names import F_YEAR_MONTH
from src.utils.timing import timing


class ColorTemplate:
    ORANGE_DARK = "#ED7F33"
    BLUE_MED = "#4081C8"
    BLUE_LIGHT = "#7FA5D0"
    BLUE_DARK = "#023466"

    # Plot parameters for confidence intervals
    PARAMS_CI = {"color": BLUE_LIGHT, "alpha": 0.1}

    # Plot parameters for line plots
    PARAMS_LINE = {"color": BLUE_DARK, "linestyle": "--", "linewidth": 2, "marker": "o"}
    PARAMS_LINE_REF = {"color": ORANGE_DARK, "linestyle": ":", "linewidth": 1}
    PARAMS_LINE_TARGET = {
        "color": ORANGE_DARK,
        "label": "Actual",
        "zorder": 1,
    }  # always first


plt.switch_backend("agg")


def print_correlations(
    normalized_features_df: pd.DataFrame,
    relevant_features: List[str],
    channel_code: str,
    experiment_tracker,
):
    model_df = normalized_features_df[
        ["brand_name", F_YEAR_MONTH] + relevant_features
    ].copy()

    for brand in model_df["brand_name"].unique():
        brand_model_df = model_df[model_df["brand_name"] == brand][
            relevant_features
        ].copy()
        corr = brand_model_df.corr()

        ax = sns.heatmap(
            corr,
            vmin=-1,
            vmax=1,
            center=0,
            cmap=sns.diverging_palette(20, 220, n=200),
            square=True,
        )
        ax.set_xticklabels(
            ax.get_xticklabels(), rotation=45, horizontalalignment="right", ha="right"
        )

        corr_figure = ax.get_figure()
        corr_figure.tight_layout()

        save_file(
            data=corr_figure,
            file_name=f"features_correlations_{brand}_{channel_code}.png",
            experiment_tracker=experiment_tracker,
            mlflow_directory=channel_code,
        )
        plt.close()


def _print_preprocessing_plot(
    features_df: pd.DataFrame,
    normalize_df: pd.DataFrame,
    col_to_plot: str,
    legend: str,
    channel_code: str,
    experiment_tracker,
):
    nb_brands = len(features_df["brand_name"].unique())
    fig, ax = plt.subplots(
        figsize=(21, 8 * nb_brands),
        nrows=max(nb_brands, 2),
        ncols=2,
        gridspec_kw={"width_ratios": [3, 1]},
    )

    cur_ax = 0
    for brand in features_df["brand_name"].unique():
        to_plot_df = features_df[features_df["brand_name"] == brand].copy()
        to_plot_df[F_YEAR_MONTH] = to_plot_df[F_YEAR_MONTH].astype(str)
        sns.lineplot(
            x=F_YEAR_MONTH,
            y=col_to_plot,
            data=to_plot_df,
            label="True",
            ax=ax[cur_ax, 0],
        )
        ax[cur_ax, 0].set_title(
            f"{col_to_plot} before  normalization for brand {brand}"
        )

        # Density plot for relevant features
        if to_plot_df[col_to_plot].nunique() > 2:
            to_plot_df[col_to_plot].plot.density(ax=ax[cur_ax, 1])
            ax[cur_ax, 1].set_title(
                f"{col_to_plot} before normalization for brand {brand}"
            )

        cur_ax += 1

        features_df = normalize_df
        to_plot_df = features_df[features_df["brand_name"] == brand].copy()
        to_plot_df[F_YEAR_MONTH] = to_plot_df[F_YEAR_MONTH].astype(str)
        sns.lineplot(
            x=F_YEAR_MONTH,
            y=col_to_plot,
            data=to_plot_df,
            label="True",
            ax=ax[cur_ax, 0],
        )
        ax[cur_ax, 0].set_title(f"{col_to_plot} after normalization for brand {brand}")

        # Density plot for relevant features
        if to_plot_df[col_to_plot].nunique() > 2:
            to_plot_df[col_to_plot].plot.density(ax=ax[cur_ax, 1])
            ax[cur_ax, 1].set_title(
                f"{col_to_plot} after  normalization for brand {brand}"
            )

        cur_ax += 1

    save_file(
        data=fig,
        file_name=f"{legend}_normalization/{col_to_plot}_{channel_code}.png",
        experiment_tracker=experiment_tracker,
        mlflow_directory=channel_code,
    )
    plt.close()


def print_preprocessing_plots(
    raw_features_df: pd.DataFrame,
    normalized_features_df: pd.DataFrame,
    relevant_features: List[str],
    channel_code: str,
    experiment_tracker,
):
    for col_to_plot in relevant_features:
        _print_preprocessing_plot(
            features_df=raw_features_df,
            normalize_df=normalized_features_df,
            col_to_plot=col_to_plot,
            legend="before",
            channel_code=channel_code,
            experiment_tracker=experiment_tracker,
        )

        # _print_preprocessing_plot(
        #     features_df=normalized_features_df,
        #     col_to_plot=col_to_plot,
        #     legend="after",
        #     channel_code=channel_code,
        #     experiment_tracker=experiment_tracker,
        # )


def get_plot_arrays(
    to_plot_df: pd.DataFrame, x_name: str, y_name: str
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    x = np.array(to_plot_df[x_name])
    lb = np.array(to_plot_df[y_name + "_p10"])
    ub = np.array(to_plot_df[y_name + "_p90"])
    y = np.array(to_plot_df[y_name])
    return x, y, lb, ub


def plot_curve_with_confidence_interval(
    ax: Axes, x: np.ndarray, y: np.ndarray, lb: np.ndarray, ub: np.ndarray, **kwargs
) -> Axes:
    ax.plot(x, y, **ColorTemplate.PARAMS_LINE, **kwargs)
    ax.fill_between(x, lb, ub, **ColorTemplate.PARAMS_CI)
    return ax


def plot_actual_target_line(ax: Axes, x: np.ndarray, y: np.ndarray) -> Axes:
    ax.plot(x, y, **ColorTemplate.PARAMS_LINE_TARGET)
    return ax


def highlight_status_quo(ax: Axes, current_spend, current_value) -> Axes:
    """Vertical line on plot to highlight the current situation"""
    dy = dict(zip(["ymin", "ymax"], ax.get_ylim()))
    ax.vlines(current_spend, **ColorTemplate.PARAMS_LINE_REF, **dy)
    ax.scatter(
        x=current_spend,
        y=current_value,
        c=ColorTemplate.ORANGE_DARK,
        marker="o",
        zorder=10,
    )
    return ax


def add_plot_info(ax: Axes, title: str, xlabel: str, ylabel: str, config) -> Axes:
    ax.set_title(title.replace("_", " "), fontsize=int(config["plot_font_size"]) / 1.5)
    ax.set_xlabel(xlabel.replace("_", " "), fontsize=int(config["plot_font_size"]) / 2)
    ax.set_ylabel(ylabel.replace("_", " "), fontsize=int(config["plot_font_size"]) / 2)
    return ax


def plot_xticks_beautiful_str(ax: Axes):
    xticks = ax.get_xticks()
    # labels = np.array(ax.get_xticklabels())

    try:
        step = len(xticks) // 100 * 20
        idx = [0] + list(np.arange(len(xticks) - 1, 0, step=-step))[::-1]
        ax.set_xticks(idx)
    except ZeroDivisionError:
        pass

    return ax

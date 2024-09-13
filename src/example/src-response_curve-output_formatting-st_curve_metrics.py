"""
Module to create output table with response curve metrics
"""
from collections import OrderedDict

import numpy as np
import pandas as pd

from src.response_curve.output_formatting.utils import add_year_info_columns
from src.utils.data_frames import add_missing_columns
from src.utils.names import (
    F_BRAND,
    F_CHANNEL_CODE,
    F_FEATURE_BRAND_CONTRIBUTION,
    F_IS_FISCAL_YEAR,
    F_IS_REFERENCE_OPTIMIZER,
    F_R_SQUARE,
    F_TOUCHPOINT,
    F_YEAR,
)
from src.utils.schemas.response_model.input.product_master import ProductMasterSchema

pms = ProductMasterSchema()


def create_st_response_curve_metrics_table(
    regression_metrics_df,
    feature_brand_contribution_df,
    response_curves_manager,
    config,
) -> pd.DataFrame:
    """
    Create standard output table with all tracked metrics for the Response Model (i.e. R2,
    volume contributions)
    """
    # Combine relevant metrics tables
    metrics_df = feature_brand_contribution_df.merge(
        regression_metrics_df,
        on=[F_CHANNEL_CODE, "brand_name"],
        how="outer",
    )

    # Create standard output table with all tracked metrics for the Response
    # Model
    st_response_curve_metrics_df = _construct_st_response_curve_metrics_table(
        metrics_df=metrics_df[metrics_df.set == "train"],
        response_curves_manager=response_curves_manager,
        config=config,
    )

    return st_response_curve_metrics_df


def _construct_st_response_curve_metrics_table(
    metrics_df, response_curves_manager, config
) -> pd.DataFrame:
    """
    Function to create the standard output table with all tracked metrics for the Response Model
    """
    # --- Add configuration info. that are needed to run the recommendation engine ---
    st_response_curve_metrics_df = add_year_info_columns(
        data_df=metrics_df.copy(),
        response_curves_manager=response_curves_manager,
        config=config,
    )

    # --- Validate final output ---
    # FIXME : @SIZD - patching STResponseCurvesMetrics to pass the validation
    # ~ ~ ~ ~ ~ ~ ~ ~ [PATCH START]
    patched_columns = list(STResponseCurvesMetrics.COLUMNS.items())
    patched_columns[0] = ("brand_name", str)
    patched_columns = OrderedDict(patched_columns)
    STResponseCurvesMetrics.COLUMNS = patched_columns
    STResponseCurvesMetrics.PRIMARY_KEYS[0] = "brand_name"
    # ~ ~ ~ ~ ~ ~ ~ ~ [PATCH END]

    st_response_curve_metrics_df = add_missing_columns(
        data_df=st_response_curve_metrics_df,
        set_missing_colums=set(STResponseCurvesMetrics.COLUMNS)
        - set(st_response_curve_metrics_df.columns),
    )
    st_response_curve_metrics_df = st_response_curve_metrics_df[STResponseCurvesMetrics.COLUMNS]
    st_response_curve_metrics_df = STResponseCurvesMetrics.cast(st_response_curve_metrics_df)
    STResponseCurvesMetrics.validate(st_response_curve_metrics_df)

    return st_response_curve_metrics_df


class STResponseCurvesMetrics:
    """
    Metrics after response curves simulation, only for uplift == 1 and years which are
    in reference for optimizer
    """

    label = "st_response_curve_metrics"

    COLUMNS = OrderedDict(
        {
            F_BRAND: str,
            F_CHANNEL_CODE: str,
            F_TOUCHPOINT: str,
            F_YEAR: np.int16,
            F_IS_FISCAL_YEAR: np.bool,
            F_IS_REFERENCE_OPTIMIZER: np.bool,
            F_FEATURE_BRAND_CONTRIBUTION: np.float,
            F_R_SQUARE: np.float,
        }
    )

    PRIMARY_KEYS = [
        F_BRAND,
        F_CHANNEL_CODE,
        F_TOUCHPOINT,
        F_YEAR,
        F_IS_FISCAL_YEAR,
        F_IS_REFERENCE_OPTIMIZER,
    ]

    @classmethod
    def validate(cls, data: pd.DataFrame) -> None:
        """
        docstring
        """
        assert not data.duplicated(cls.PRIMARY_KEYS).any(), "Error: duplicated primary keys"
        assert len(data.columns.intersection(cls.COLUMNS)) == len(
            cls.COLUMNS
        ), "Error: some columns are missing / surplus to requirement"

    @classmethod
    def cast(cls, data: pd.DataFrame) -> pd.DataFrame:
        """
        docstring
        """
        return data.astype(cls.COLUMNS)

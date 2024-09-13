"""Utils methods collection to support scalability of the project
"""
from copy import copy
from typing import Dict, Tuple

import pandas as pd

from src.utils.datetime import (
    get_calendar_year_from_period_start,
    get_calendar_year_from_year_week,
    get_fiscal_year_from_period_start,
    get_fiscal_year_from_year_month,
    get_fiscal_year_from_year_week,
    get_weeks_after,
)
from src.utils.names import (
    F_TOUCHPOINT,
    F_TOUCHPOINT_INDEX,
    F_YEAR_CALENDAR,
    F_YEAR_FISCAL,
    F_YEAR_MONTH,
)


def _is_channel(value_dict, channel_code):
    """
    Check if promotional channels exits in the config file
    """
    return channel_code in value_dict.get("channel", [channel_code])


def all_settings_dict(config):
    """
    Return the config options in dictionary format
    """
    output = {}
    for channel_code, value in config["STAN_PARAMETERS"]["channels"].items():
        buffer_dict = copy(config["STAN_PARAMETERS"]["predictor_parameters"])
        buffer_dict.update({config.get("TARGET_VARIABLE"): value})
        buffer_dict.update(config["STAN_PARAMETERS"]["standard_parameters"])
        buffer_dict.update(config["STAN_PARAMETERS"]["transformation_parameters"])
        if "seasonality_parameters" in config.get("STAN_PARAMETERS"):
            buffer_dict.update(config["STAN_PARAMETERS"]["seasonality_parameters"])

        output[channel_code] = {
            k: v for k, v in buffer_dict.items() if _is_channel(v, channel_code)
        }

    return output


def transformed_features(config):
    """Returns a dict of the transformed variables and their transformations"""
    return {
        channel_code: {
            predictor: value["transformations"]
            for predictor, value in config.get("STAN_PARAMETERS")["predictor_parameters"].items()
            if "transformations" in value and _is_channel(value, channel_code)
        }
        for channel_code in config.get("STAN_PARAMETERS")["channels"]
    }


def get_name_from_feature(name):
    """Returns a name from feature

    Arguments:
        name {[name]} -- [Name of the feature]

    Returns:
        [type] -- [Returns the name of feature by cropping spend_ from the name]
    """
    if name.startswith("spend_"):
        return name[6:]
    return name


def get_feature_param_value(config, feature, param, channel_code=None):
    """Returns param value

    Arguments:
        config {[type]} -- [description]
        feature {[type]} -- [description]
        param {[type]} -- [description]

    Keyword Arguments:
        channel_code {[type]} -- [description] (default: {None})
    """
    name = feature
    if channel_code is not None:
        return all_settings_dict(config).get(channel_code).get(name, {}).get(param, {})
    for v in config.get("STAN_PARAMETERS").values():
        if name in v:
            return v[name].get(param, {})
    return None

def get_feature_from_name(config, predictor):
    """Returns feature from the predictor name"""
    # TODO : abstract spend vs exec logic
    for param_dicts in config.get("STAN_PARAMETERS").values():
        if predictor in param_dicts:
            if any(
                tag in ["media", "trade_marketing"]
                for tag in param_dicts[predictor].get("tags", [])
            ):
                return "spend_" + predictor
            return predictor
    if predictor == config.get("TARGET_VARIABLE"):
        return predictor
    raise ValueError


def get_strategic_touchpoint_mapping(config):
    """Returns the touchpoint mapping dictionary"""
    return {
        get_feature_from_name(config, k): v.get("internal_strat_touchpoint")
        for k, v in config.STAN_PARAMETERS["predictor_parameters"].items()
        if v.get("internal_strat_touchpoint")
    }


def _get_index_mapping(touchpoint_indexes: Tuple[Tuple[int, str]]) -> pd.DataFrame:
    """
    Index of the touchpoint in the parameters used to transform features inside the PyStan model
    (e.g. adstock variables & Weibull shape functions)
    """
    return pd.DataFrame(data=list(touchpoint_indexes), columns=[F_TOUCHPOINT_INDEX, F_TOUCHPOINT])


def get_year_for_response_curve(
    year_weeks: pd.Series,
    is_fiscal_year_response_curve: bool,
    fiscal_year_final_week: int,
) -> pd.Series:
    """
    Centralizing logic in charge of converting year_weeks to the relevant year type
    (i.e. calendar vs fiscal)
    """
    if is_fiscal_year_response_curve:
        return get_fiscal_year_from_year_week(year_weeks, fiscal_year_final_week).rename(
            F_YEAR_FISCAL
        )

    return get_calendar_year_from_year_week(year_weeks).rename(F_YEAR_CALENDAR)


def get_year_for_response_curve_from_year_months(
    year_months: pd.Series,
    is_fiscal_year_response_curve: bool,
    fiscal_year_final_month: int,
) -> pd.Series:
    """
    Centralizing logic in charge of converting year_weeks to the relevant year type
    (i.e. calendar vs fiscal)
    """
    if is_fiscal_year_response_curve:
        return get_fiscal_year_from_year_month(year_months, fiscal_year_final_month).rename(
            F_YEAR_FISCAL
        )

    return get_calendar_year_from_year_week(year_months).rename(F_YEAR_CALENDAR)


def get_year_for_response_curve_from_period_start(
    period_start: pd.Series,
    is_fiscal_year_response_curve: bool,
    fiscal_year_final_week: int,
) -> pd.Series:
    """
    Centralizing logic in charge of converting period_starts to the relevant year type
    (i.e. calendar vs fiscal)
    """
    if is_fiscal_year_response_curve:
        return get_fiscal_year_from_period_start(period_start, fiscal_year_final_week).rename(
            F_YEAR_FISCAL
        )

    return get_calendar_year_from_period_start(period_start).rename(F_YEAR_CALENDAR)


def as_columns(columns) -> Tuple[str]:
    """Returns tuple of columns

    Returns:
        Tuple[str] -- [description]
    """
    return tuple([str(col) for col in columns])


def as_records(df: pd.DataFrame, keep_all_nan: bool = False) -> Tuple:
    """
    Function to convert the information in the data frame to records (immutable tuples)
    to prevent mutability errors for those critical metrics.
    """
    if df.isnull().all(axis=1).all() and not keep_all_nan:
        return tuple()

    return tuple(df.to_records().copy())


def from_records(data: Tuple, columns: Tuple[str]) -> pd.DataFrame:
    """
    Function to convert back the information parsed with as_records function, and return the
    information as a data frame with the right column names
    """
    if data is None:
        return from_records(data=tuple(), columns=columns)

    return pd.DataFrame.from_records(data=data, columns=columns)


def get_spend_column(touchpoint: str) -> str:
    """
    Returns spend column
    """
    return "_".join(["spend", touchpoint])


def get_touchpoints_from_tags(config, tags, return_feature=False):
    """Return a list of touchpoints for a tag, with a prefix if provided"""
    output = []
    for _, param_dict in config.get("STAN_PARAMETERS").items():
        for predictor, value in param_dict.items():
            if "tags" in value:
                for tag in tags:
                    if tag in value["tags"] and return_feature is False:
                        output.append(predictor)
                    elif tag in value["tags"]:
                        output.append(get_feature_from_name(config, predictor))
    return output


def get_stan_transformation_index(config, transformation, channel_code, return_feature=True):
    """Return indexes of touchpoints or feature name in Stan for a transformation"""
    index = []
    value = 1

    for predictor, transformations in transformed_features(config)[channel_code].items():
        if transformation in transformations and return_feature is True:
            index.append((value, predictor))
            value += 1
        elif transformation in transformations and return_feature is False:
            index.append((value, get_name_from_feature(predictor)))
            value += 1
    return tuple(index)


def get_uplift_time_scope(
    uplift_year: int,
    time_index_df: pd.DataFrame,
    adstock_lengths,
    response_curves_manager,
):
    """
    Scoped year_weeks for uplift computation
    Assumption: time_index_df contains the exact same weeks compared to transformed_features_df

    Args:
        uplift_year: Either a year e.g. 2020 or None. Whenever None, the method for volume
            contributions is used.
        time_index_df:
        adstock_length: Adstock length (effective length depending on model_settings)
        response_curves_manager:

    Returns:
    """
    uplift_aggregation_index = {}

    # Scope year_weeks for uplift computation
    def get_time_scope(df) -> Tuple:
        return tuple(df[F_YEAR_MONTH].apply(["min", "max"]))

    year_start, year_end = get_time_scope(
        time_index_df[time_index_df[response_curves_manager.column_year] == uplift_year]
    )

    adstock_lengths["contrib"] = 0

    for tp, adstock_length in adstock_lengths.items():
        scope_end = get_weeks_after(year_end, adstock_length + 1)[-1]
        uplift_aggregation_index[tp] = time_index_df[F_YEAR_MONTH].between(
            year_start, scope_end, inclusive=True
        )

    return uplift_aggregation_index


def strategic_touchpoint_mapping(config) -> Dict[str, str]:
    """
    Returns predictor parameters in dictionary
    """
    return {
        get_feature_from_name(config, k): v.get("internal_strat_touchpoint")
        for k, v in config["STAN_PARAMETERS"]["predictor_parameters"].items()
        if v.get("internal_strat_touchpoint")
    }

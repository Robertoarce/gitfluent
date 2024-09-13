# pylint: disable=invalid-name, too-few-public-methods
"""
Defining API input / output objects.
"""
from enum import Enum
from logging import getLogger
from typing import List, Tuple, Union

from pydantic import BaseModel, validator  # pylint: disable=no-name-in-module

logger = getLogger(__name__)

# Number of decimal places to round to in the output.
FLOAT_PRECISION = 5

# =========================================================================
# INPUT COMPONENTS
# These are Enum components that denote accepted inputs values for API parameters.
# =========================================================================


class GBUCodeInput(str, Enum):
    """
    Input based on the 6 level hierarchy
    *GBU* > market > product > channel > specialty > segment

    Member values are aligned with GBU_CD in DWH_GBU_MASTER
    """

    VACCINES = "VAC"
    GENERAL_MEDICINES = "GMD"
    SPECIALITY_CARE = "SPC"  # British English spelling


# =========================================================================
# OUTPUT COMPONENTS
# =========================================================================


class Base(BaseModel):
    """
    Base class contains helpful functions that can be used to
    easily create outputs that inherit from this class.
    """

    def __hash__(self):
        """
        Define a hash function to be able to remove duplicate objects in a list.
        Inspired by https://stackoverflow.com/a/4173307
        """
        return hash(((field_name, getattr(self, field_name)) for field_name in self.field_names))

    @validator("*", pre=True)
    @classmethod
    def round_floats(cls, x):
        """
        Round all floats in a Base to FLOAT_PRECISION decimal places.

        NOTE: there is probably a more eloquent way to do this, especially
        for the nested structures.
        """
        if isinstance(x, float):
            return round(x, FLOAT_PRECISION)

        if isinstance(x, list):
            return [round(v, FLOAT_PRECISION) if isinstance(v, float) else v for v in x]

        if isinstance(x, dict):
            return {
                k: (round(v, FLOAT_PRECISION) if isinstance(v, float) else v) for k, v in x.items()
            }

        return x


class Market(Base):
    """
    Available market that has been modeled.
    """

    market_code: str
    market_name: str
    region_code: str
    region_name: str
    currency: str


class Brand(Base):
    """
    Available brand that has been modeled.
    """

    brand_name: str
    brand_category: str


class Channel(Base):
    """
    Available channel that has been modeled.
    """

    channel_code: str
    channel_desc: str


class Specialty(Base):
    """
    Available specialty that has been modeled.
    """

    specialty_code: str
    specialty_name: str


class Segment(Base):
    """
    Available segment that has been modeled.
    """

    segment_code: str
    segment_name: str


class Curve(Base):
    """
    Base class for response curve details.

    Most keys are used to identify the curve (e.g. market, brand, channel, etc.)

    The curve is discretized and is represented in parallel, equally-sized arrays
    `spend`, `incr_sellout`, `uplift`, `ROI`, `MROI`, `GMROI` containing the data
    at each point along the curve.

    The `historical` array is a boolean array with one *True* element which identifies
    the actual historical spend scenario.
    """

    market_name: Union[str, None]  # TO BE REMOVED once UI dependency removed
    market_code: str
    region_name: str
    brand_name: str
    channel_code: str
    channel_desc: str
    # TO BE REMOVED once UI dependency removed
    specialty_name: Union[str, None]
    speciality_code: str
    segment_name: Union[str, None]  # TO BE REMOVED once UI dependency removed
    segment_value: str
    period: str
    currency: str
    spend: List[float]
    incr_sellout: List[float]
    uplift: List[float]
    ROI: List[Union[float, None]]
    MROI: List[Union[float, None]]
    GMROI: List[Union[float, None]]
    historical: List[bool]
    historical_index: float


class MMMROI(Curve):
    """
    Schema used to display curve on MMM Results screen.
    Inherits all keys from `Curve` object, with `version_code` and
    `num_interactions` which is used to identify the number of HCP interactions
    at each point of the curve.
    """

    version_code: str
    num_interactions: List[float]


class PeriodValue(Base):
    """
    Generic class for statistics by period.
    """

    period: str
    value: Union[float, int, None]


class MMMResults(Base):
    """
    Response curves and summary statistics for the MMM Results screen.
    """

    avg_roi: List[PeriodValue]
    total_sales: List[PeriodValue]
    incr_sales: List[PeriodValue]
    carryover_sales: List[PeriodValue]
    carryover_sales_pct: List[PeriodValue]
    total_spend: List[PeriodValue]
    curves: List[MMMROI]


class MMMSalesContribution(Base):
    """
    Sales Contribution
    """

    year: int
    market_code: str
    brand_name: str
    channel_code: str
    channel_desc: str
    speciality_code: Union[str, None]
    segment_value: Union[str, None]
    spend: Union[float, None]
    sell_out: float
    ROI: Union[float, None]


class ModelMetrics(Base):
    """MAPE and Rsquared metrics for model evaluation."""

    mape: float
    r_square: float


class ModelSettingsDetail(Base):
    """Adstock/Threshold/Saturation settings for a given channel"""

    channel: str
    adstock: float
    threshold: float
    saturation: float


class FeatureContributionDetail(Base):
    """Sales contributions of a given feature"""

    feature: str
    feature_type: str
    contribution: float
    fiscal_year: int


class MMMProductModelDetail(Base):
    """Collection of model information for a given product"""

    product_code: str
    model_metrics: List[ModelMetrics]
    model_settings: List[ModelSettingsDetail]
    feature_contributions: List[FeatureContributionDetail]


class MMMPredictedValues(Base):
    """
    Actual vs. modelled sales for model evaluation on historical data.
    """

    product_code: str
    actual_volume: List[float]
    predicted_volume: List[float]
    year_week: List[str]


class MMMScope(Base):
    """
    Scope (name of a product/channel/channel, and the years it is integrated)
    """

    scope_name: str
    scope_desc: Union[str, None]  # optional description (e.g. channel_desc)
    integrated_years: List[int]


class MMMSummary(Base):
    """
    Basic summary of model (scope of years, products, features).

    This is used to list the models that are available (MMM Library)
    """

    version_code: str
    model_name: str
    exercise_names: List[str]
    period: Tuple[int, int]
    period_str: str
    cnt_brands: int
    avg_roi: float
    avg_saturation: Union[float, None]
    scope_brands: List[MMMScope]
    scope_channels: List[MMMScope]


class ChannelSpend(Base):
    """
    Historical salesforce and promotional spend detail
    at Channel level.
    """

    channel_code: str
    channel_desc: str
    interactions: Union[float, None]
    promotion_spend: Union[float, None]
    salesforce_spend: Union[float, None]
    total_spend: Union[float, None]
    promotion_cost_per_interaction: Union[float, None]
    salesforce_cost_per_interaction: Union[float, None]
    total_cost_per_interaction: Union[float, None]
    currency: Union[str, None]


class YearSpend(Base):
    """
    Historical salesforce and promotional spend detail
    at Year level.
    """

    year: int
    channels: List[ChannelSpend]


class BrandSpend(Base):
    """
    Historical salesforce and promotional spend detail
    at Brand level.
    """

    brand_name: str
    years: List[YearSpend]


class GBUMarketSpend(Base):
    """
    Historical salesforce and promotional spend detail
    at GBU / market level.
    """

    gbu_code: str
    market_code: str
    market_name: str
    brands: List[BrandSpend]


# =========================================================================
# RECOMMENDATION ENGINE
# =========================================================================


class ConstraintKPI(str, Enum):
    """
    KPIs available to be used for optimizer

    Note: ConstraintKPI values (strings on the right side of the '=' on enum members below)
        can't contain underscores because it will break constraint parser logic
    """

    spend = "spend"
    sell_out = "sellout"
    gm = "gm"
    gm_minus_spend = "gmminusspend"


class ConstraintDelta(str, Enum):
    """
    Delta types available to be used for optimizer
    """

    variation = "variation"
    absolute = "absolute"


class ConstraintDirection(str, Enum):
    """
    Min or Max
    """

    minimum = "min"
    maximum = "max"


class ScopeValue(Base):
    """
    A combination of the 5 hierarchical levels below GBU

    market (with associated region)
    brand (with associated category)
    channel (code and desc)
    specialty (code)
    segment(code and value)
    """

    market_code: Union[str, None]
    region_name: Union[str, None]
    brand_name: Union[str, None]
    brand_category: Union[str, None]
    channel_code: Union[str, None]
    channel_desc: Union[str, None]
    speciality_code: Union[str, None]
    segment_code: Union[str, None]
    segment_value: Union[str, None]


class Constraint(Base):
    """
    Input constraint into the recommender engine.
    """

    market_code: Union[str, None]
    brand_name: Union[str, None]
    channel_code: Union[str, None]
    speciality_code: Union[str, None]
    segment_value: Union[str, None]
    kpi: ConstraintKPI
    delta: ConstraintDelta
    direction: ConstraintDirection
    value: float


class ScenarioCriteria(str, Enum):
    """
    Scenario objectives.
    """

    max_sell_out = "max_sell_out"
    min_spend = "min_spend"
    max_gm = "max_gm"
    max_gm_minus_spend = "max_gm_minus_spend"


class ScenarioObjective(Base):
    """
    Specifying the objective.
    """

    criteria: ScenarioCriteria
    delta: ConstraintDelta
    value: float


class RecommendationEngineSettings(Base):
    """
    API request body format for running the recommendation engine
    """

    exercise_code: str
    scenario_objective: ScenarioObjective
    scope_values: List[ScopeValue]
    budget: str
    selected_period_setting: str
    constraints: List[Constraint]
    userid: Union[str, None]


class AllocationKPIValue(Base):
    """
    Aggregate KPIs for a historical or optimized scenario.
    """

    sell_out_value: float
    sell_out_volume: float
    spend: float
    net_sales: float
    gross_margin: float
    gross_margin_minus_spend: float
    sell_out_roi: Union[float, None]
    gross_margin_minus_spend_over_net_sales: Union[float, None]


class RecommendationSummary(Base):
    """
    KPI summary for the impact screen
    """

    incremental: AllocationKPIValue
    total: AllocationKPIValue
    carryover: AllocationKPIValue
    carryover_pct: AllocationKPIValue


class ScenarioAllocation(ScopeValue, AllocationKPIValue):
    """
    KPI values at a given granularity
    """


class ScenarioResults(Base):
    """
    Allocation for a historical or optimized scenario
    """

    summary: RecommendationSummary
    detailed_incremental: List[ScenarioAllocation]
    detailed_total: List[ScenarioAllocation]
    detailed_carryover: List[ScenarioAllocation]


class ScenarioCurve(Curve):
    """
    Response curves with indicator for optimized point,
    and constraints to visualize
    """

    optimized: List[bool]
    optimized_index: int
    spend_lower_bound: Union[float, None]
    sell_out_lower_bound: Union[float, None]
    spend_upper_bound: Union[float, None]
    sell_out_upper_bound: Union[float, None]


class RecommendationEngineOutput(Base):
    """
    API response format for running the recommendation engine
    """

    run_name: str
    selected_period_setting: Union[str, None]
    budget: str
    historic_results: ScenarioResults
    optimized_results: ScenarioResults
    delta_results_absolute: ScenarioResults
    delta_results_relative: ScenarioResults
    curves: List[ScenarioCurve]
    warnings: List[str]


class ExerciseInfo(Base):
    """
    Detail of available exercise for use in optimization, including the scope.
    """

    exercise_code: str
    exercise_name: str
    available_period_settings: List[str]
    available_budget: List[str]
    markets: List[Market]
    brands: List[Brand]
    channels: List[str]
    specialities: List[str]
    segments: List[str]
    scope_values: List[ScopeValue]


class ObjectiveReference(Base):
    """
    Reference values for the objective scenario creation screen.
    """

    original_timeframe: str
    sell_out_value: float
    model_spend: float
    gross_margin: float
    gross_margin_minus_spend: float
    budget_timeframe: Union[str, None]  # to be mandatory
    budgeted_sell_out_value: float
    budgeted_model_spend: float
    budgeted_gross_margin: float
    budgeted_gross_margin_minus_spend: float
    currency: str

from dataclasses import asdict, dataclass


class SchemaEnum:
    @classmethod
    def get_values_aslist(cls):
        return list(asdict(cls()).values())


@dataclass
class Frequency(SchemaEnum):
    day: str = "day"
    week: str = "week"
    month: str = "month"
    year: str = "year"
    quarter: str = "quarter"


@dataclass
class Unit(SchemaEnum):
    currency: str = "currency"
    index: str = "index"
    mm: str = "mm"
    percent: str = "percent"
    ratio: str = "ratio"
    unit: str = "unit"
    number: str = "number"
    max: str = "max"
    rolling_7d: str = "7d_rolling"


@dataclass
class DistributionMetric(SchemaEnum):
    num_distrib_selling: str = "num_distrib_selling"
    num_distrib_handling: str = "num_distrib_handling"
    wt_distrib_selling: str = "wt_distrib_selling"
    wt_distrib_handling: str = "wt_distrib_handling"
    num_distrib_display: str = "num_distrib_display"
    wt_distrib_display: str = "wt_distrib_display"


@dataclass
class TouchpointMetric(SchemaEnum):
    spend: str = "spend_value"

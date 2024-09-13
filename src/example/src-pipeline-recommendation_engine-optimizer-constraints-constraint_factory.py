"""
Generic function to create model constraints
in order to reduce duplicate code.
"""
from typing import Callable

from pyomo.environ import Constraint, Model

from src.api.schemas import ConstraintDelta, ConstraintDirection, ConstraintKPI
from src.pipeline.recommendation_engine.optimizer.constraints.constraint_parser import (
    SUPPORTED_CONSTRAINTS,
    split_constraint_name,
)
from src.pipeline.recommendation_engine.utils.aggregation import (
    pad_key,
    padded_key_is_match,
)


def declare_custom_constraints(model: Model):
    """
    Declare all the supported constraint rules using ConstraintFactory.
    """
    for constraint_name in SUPPORTED_CONSTRAINTS[::-1]:
        ConstraintFactory.declare(model, constraint_name)


class ConstraintFactory:
    """
    Factory class for custom user constraints
    as they are parsed from the payload.
    """

    @classmethod
    def declare(cls, model, constraint_name):
        """
        Given model and constraint name, declare that constraint on the model.
        """
        direction, delta, granularity, kpi = split_constraint_name(constraint_name)

        rule = cls.create_rule(direction, delta, granularity, kpi, constraint_name)

        if len(granularity) > 0:
            domain = getattr(model, "set_" + "_".join(granularity) + "_domain")

            setattr(model, f"constraint_{rule}", Constraint(domain, rule=rule))
        else:
            setattr(model, f"constraint_{rule}", Constraint(rule=rule))

    @classmethod
    def create_rule(cls, direction, delta, granularity, kpi, constraint_name) -> Callable:
        """
        Return a rule that can be used in a Pyomo Constraint.
        """

        def rule(model, *domain_slice):
            """
            Length and values of domain_slice will depend on the domain
            on which the function applies.

            e.g. if the rule is applied on model.set_brand_market_domain, then
                a possible value of domain_slice is (FR, HEXYON)
            """
            setting = model.settings["constraints"].get(constraint_name, ())

            # For granular (non-universal) constraints, domain slice is passed
            # as (None, ) by Pyomo
            is_granular = (len(domain_slice) > 0) & (domain_slice[0] is not None)
            if is_granular:
                setting = tuple(v for k, v in setting if k == domain_slice)

            if not setting:
                return Constraint.Skip

            # Take the strictest bounds (highest lower bound and lowest upper bound)
            if direction.upper() == ConstraintDirection.minimum.upper():
                setting = max(setting)
            else:
                setting = min(setting)

            # Log
            log_string = f"Activating {constraint_name} "
            if is_granular:
                log_string += "(" + ", ".join(domain_slice) + ") "
            log_string += f"= {setting}"
            print(log_string)

            lhs, rhs = cls.get_constraint_lhs_rhs(model, domain_slice, granularity, kpi)
            if delta.upper() == ConstraintDelta.variation.upper():
                rhs = rhs * (1 + setting)
            elif delta.upper() == ConstraintDelta.absolute.upper():
                rhs = setting  # absolute value just take as given.
            else:
                raise NotImplementedError(
                    f"Constraints for delta type {delta.upper()} not yet implemented!"
                )

            if direction.upper() == "MIN":
                return lhs >= rhs
            return lhs <= rhs

        return rule

    # fmt: off
    @classmethod
    def get_constraint_lhs_rhs(cls, model, domain_slice, granularity, kpi):
        """
        Construct the LHS and RHS of the inequality using the
        model variables and parameters, depedning on the KPI.

        The LHS will be the variable.
        The RHS will be the bound.
        """
        padded_key = pad_key(domain_slice, key_granularity=granularity)

        if kpi.upper() == ConstraintKPI.spend.upper():
            lhs = sum(
                model.var_spend_selected[rgn, mkt, brd, chn, spc, seg]
                for rgn, mkt, brd, chn, spc, seg
                in model.set_region_market_brand_channel_speciality_segment_domain
                if padded_key_is_match(padded_key, (rgn, mkt, brd, chn, spc, seg))
            )

            rhs = sum(
                model.param_spend_ref_dic_projected[rgn, mkt, brd, chn, spc, seg]
                for rgn, mkt, brd, chn, spc, seg
                in model.set_region_market_brand_channel_speciality_segment_domain
                if padded_key_is_match(padded_key, (rgn, mkt, brd, chn, spc, seg))
            )
        elif kpi.upper() == ConstraintKPI.sell_out.upper():
            lhs = sum(
                model.var_incr_sell_out_value_selected[rgn, mkt, brd, chn, spc, seg]
                for rgn, mkt, brd, chn, spc, seg
                in model.set_region_market_brand_channel_speciality_segment_domain
                if padded_key_is_match(padded_key, (rgn, mkt, brd, chn, spc, seg))
            )

            rhs = sum(
                model.param_incr_sell_out_value_ref_dic_projected[rgn, mkt, brd, chn, spc, seg]
                for rgn, mkt, brd, chn, spc, seg
                in model.set_region_market_brand_channel_speciality_segment_domain
                if padded_key_is_match(padded_key, (rgn, mkt, brd, chn, spc, seg))
            )

            # if the granularity is above channel level (i.e. market or market-brand),
            # then we need to also include baseline.
            if not any(padded_key[3:]):
                baseline = sum(
                    model.param_base_sell_out_value_ref_dic_projected[rgn, mkt, brd]
                    for rgn, mkt, brd
                    in model.set_region_market_brand_domain
                    if padded_key_is_match(padded_key[:3], (rgn, mkt, brd))
                )
                lhs = lhs + baseline
                rhs = rhs + baseline
        else:
            raise NotImplementedError(f"Constraints for kpi {kpi.upper()} not yet implemented!")

        return lhs, rhs
    # fmt: on

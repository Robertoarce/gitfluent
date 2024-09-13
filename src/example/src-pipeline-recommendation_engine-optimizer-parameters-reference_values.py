"""
Calculating the parameters required for the recommendation engine.
"""
from copy import deepcopy

import pandas as pd

from src.pipeline.recommendation_engine.budget_scaling import (
    apply_scaling_to_dict,
    budget_df_to_dict,
    scaling_factor_denominator,
)
from src.pipeline.recommendation_engine.optimizer.parameters.financial import (
    compute_financial_parameters,
)
from src.pipeline.recommendation_engine.optimizer.parameters.piecewise import (
    compute_piecewise_parameters,
)
from src.pipeline.recommendation_engine.optimizer.parameters.ref_gm import (
    compute_ref_gross_margin_parameters,
)
from src.pipeline.recommendation_engine.optimizer.parameters.ref_sell_out import (
    compute_ref_sell_out_parameters,
)
from src.pipeline.recommendation_engine.optimizer.parameters.ref_spend import (
    compute_ref_spend_parameters,
)
from src.pipeline.recommendation_engine.utils.aggregation import pad_key


class RecommendationEngineReferenceValues:
    """
    Dataclass to hold reference values
    """

    def __init__(
        self,
        response_curves_df: pd.DataFrame,
        response_curves_reference_df: pd.DataFrame,
        response_curves_projected_df: pd.DataFrame,
        response_curves_reference_projected_df: pd.DataFrame,
    ):
        """
        Takes preprocessed data as input, and declares them as attributes
        available to calculate other parameters.
        """
        # copy to break aliasing
        self._response_curves_df = response_curves_df.copy()
        currency = self._response_curves_df["currency"].unique()
        assert len(currency) == 1, "More than one currency found!"
        self.currency = currency[0]

        self._response_curves_reference_df = response_curves_reference_df.copy()
        self._response_curves_projected_df = response_curves_projected_df.copy()

        self._response_curves_reference_projected_df = response_curves_reference_projected_df.copy()

    @property
    def response_curves_df(self):
        """
        Break alias
        """
        return self._response_curves_df.copy()

    @property
    def response_curves_reference_df(self):
        """
        Break alias
        """
        return self._response_curves_reference_df.copy()

    @property
    def response_curves_projected_df(self):
        """
        Break alias
        """
        return self._response_curves_projected_df.copy()

    @property
    def response_curves_reference_projected_df(self):
        """
        Break alias
        """
        return self._response_curves_reference_projected_df.copy()

    def declare_model_parameters(self, model):
        """
        Given a model, declares the appropriate parameters
        based on self class properties.
        """
        for parameter_group in (
            self.financial_parameters,
            self.piecewise_parameters(model),
            *self.reference_parameters(projected=False),
        ):
            for name, value in parameter_group.__dict__.items():
                setattr(model, f"param_{name}", value)

        # add "_projected" suffix to projected parameters
        for parameter_group in self.reference_parameters(projected=True):
            for name, value in parameter_group.__dict__.items():
                setattr(model, f"param_{name}_projected", value)

    @property
    def financial_parameters(self):
        """
        Financial parameters for each market x brand x channel x speciality x segment.
        """
        return compute_financial_parameters(self.response_curves_reference_projected_df)

    def piecewise_parameters(self, model):
        """
        Piecewise parameters for integer programming.
        """
        return compute_piecewise_parameters(
            self.response_curves_projected_df,
            model.set_region_market_brand_channel_speciality_segment_upliftidx_domain,
        )

    def reference_parameters(self, projected=False):
        """
        Spend, sell_out, GM, etc.
        base values in reference year.
        """
        if projected:
            df = self.response_curves_reference_projected_df
        else:
            df = self.response_curves_reference_df

        ref_spend = compute_ref_spend_parameters(df)
        ref_sell_out = compute_ref_sell_out_parameters(df)
        ref_gm = compute_ref_gross_margin_parameters(ref_sell_out, self.financial_parameters)

        return ref_spend, ref_sell_out, ref_gm

    @staticmethod
    def reference_totals(ref_spend, ref_sell_out, ref_gm):
        """
        Given reference spend/sellout/gm (as returned by `reference_parameters`)

        Summarize total spend, total sell out, and total GM
        """
        total_spend = sum(ref_spend.spend_ref_dic.values())
        total_sell_out = sum(ref_sell_out.incr_sell_out_value_ref_dic.values()) + sum(
            ref_sell_out.base_sell_out_value_ref_dic.values()
        )
        total_gm = sum(ref_gm.incr_gm_ref_dic.values()) + sum(ref_gm.base_gm_ref_dic.values())

        return total_spend, total_sell_out, total_gm

    # pylint: disable=too-many-locals
    @staticmethod
    def budgeted_reference_totals(ref_spend, ref_sell_out, ref_gm, budget_df):
        """
        Adjust the original reference totals by the budget
        """
        budgeted_ref_spend = deepcopy(ref_spend)
        budgeted_ref_sell_out = deepcopy(ref_sell_out)
        budgeted_ref_gm = deepcopy(ref_gm)

        budget_dict = budget_df_to_dict(budget_df)

        for key, (budgeted_sales, budgeted_spend) in budget_dict.items():
            full_padded_key = pad_key(key=key, key_granularity=["market", "brand"])
            partial_padded_key = pad_key(
                key=key,
                key_granularity=["market", "brand"],
                full_granularity=["region", "market", "brand"],
            )

            # Calculate scaling factors
            sales_denom = scaling_factor_denominator(
                ref_sell_out.incr_sell_out_value_ref_dic,
                ref_sell_out.incr_sell_out_value_ref_dic.keys(),
                full_padded_key,
            ) + scaling_factor_denominator(
                ref_sell_out.base_sell_out_value_ref_dic,
                ref_sell_out.base_sell_out_value_ref_dic.keys(),
                partial_padded_key,
            )
            spend_denom = scaling_factor_denominator(
                budgeted_ref_spend.spend_ref_dic,
                budgeted_ref_spend.spend_ref_dic.keys(),
                full_padded_key,
            )
            sales_scaling_factor = budgeted_sales / (sales_denom + 1e-8)
            spend_scaling_factor = budgeted_spend / (spend_denom + 1e-8)

            # Apply scaling to all relevant dictionaries
            apply_scaling_to_dict(
                budgeted_ref_sell_out.incr_sell_out_value_ref_dic,
                full_padded_key,
                sales_scaling_factor,
            )
            apply_scaling_to_dict(
                budgeted_ref_sell_out.base_sell_out_value_ref_dic,
                partial_padded_key,
                sales_scaling_factor,
            )
            apply_scaling_to_dict(
                budgeted_ref_gm.incr_gm_ref_dic,
                full_padded_key,
                sales_scaling_factor,
            )
            apply_scaling_to_dict(
                budgeted_ref_gm.base_gm_ref_dic,
                partial_padded_key,
                sales_scaling_factor,
            )
            apply_scaling_to_dict(
                budgeted_ref_spend.spend_ref_dic, full_padded_key, spend_scaling_factor
            )

        # Calculate totals of scaled reference values
        total_budgeted_spend = sum(budgeted_ref_spend.spend_ref_dic.values())
        total_budgeted_sell_out = sum(
            budgeted_ref_sell_out.incr_sell_out_value_ref_dic.values()
        ) + sum(budgeted_ref_sell_out.base_sell_out_value_ref_dic.values())
        total_budgeted_gm = sum(budgeted_ref_gm.incr_gm_ref_dic.values()) + sum(
            budgeted_ref_gm.base_gm_ref_dic.values()
        )

        return total_budgeted_spend, total_budgeted_sell_out, total_budgeted_gm

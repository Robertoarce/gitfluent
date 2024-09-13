"""
Calculate gross margin parameters at reference year.
"""
from dataclasses import dataclass
from typing import Dict


@dataclass
class RefGrossMargin:
    """
    Dataclass to store gross margin parameters at reference.
    """

    incr_gm_ref_dic: Dict
    base_gm_ref_dic: Dict


def compute_ref_gross_margin_parameters(ref_sell_out, financial_parameters):
    """
    Calculates the following dictionary as in `RefGrossMargin`:

    incr_gm_ref_dic:{
        (region, market, brand, channel, speciality, segment): value
    }
    where value is the incremental gross margin

    base_gm_ref_dic:{
        (region, market, brand): value
    }
    where value is the baseline gross margin
    """

    incr_gm_ref_dic = {}
    for rgn, mkt, brd, chn, spc, seg in ref_sell_out.incr_sell_out_value_ref_dic.keys():
        incr_gm_ref_dic[(rgn, mkt, brd, chn, spc, seg)] = (
            ref_sell_out.incr_sell_out_value_ref_dic[(rgn, mkt, brd, chn, spc, seg)]
            * financial_parameters.gm_of_sell_out[(rgn, mkt, brd)]
        )

    # baseline can only be identified at brand level.
    base_gm_ref_dic = {}
    for rgn, mkt, brd in ref_sell_out.base_sell_out_value_ref_dic.keys():
        base_gm_ref_dic[(rgn, mkt, brd)] = (
            ref_sell_out.base_sell_out_value_ref_dic[(rgn, mkt, brd)]
            * financial_parameters.gm_of_sell_out[(rgn, mkt, brd)]
        )

    return RefGrossMargin(incr_gm_ref_dic=incr_gm_ref_dic, base_gm_ref_dic=base_gm_ref_dic)

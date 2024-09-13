"""
Utility module with granularity related methods
"""
from copy import copy

from src.utils.schemas.response_model.input import GeoMasterSchema, ProductMasterSchema

gs = GeoMasterSchema()
pms = ProductMasterSchema()


def transformation_length(config, transformation, channel_code):
    """Returns the number of transformed variables for a given transformation"""
    return sum(
        [
            transformation in value.get("transformations", [])
            for value in config.get("STAN_PARAMETERS")["predictor_parameters"].values()
            if channel_code in value.get("channel", [channel_code])
        ]
    )


def _is_channel(value_dict, channel_code):
    """
    Check if value dictionary contains channel code
    """
    return channel_code in value_dict.get("channel", [channel_code])


def all_settings_dict(config):
    """
    Returns dictionary of stan parameters
    """
    output = {}
    for channel_code, value in config["STAN_PARAMETERS"]["channels"].items():
        buffer_dict = copy(config["STAN_PARAMETERS"]["predictor_parameters"])
        print("Iterating on value: {value}")
        buffer_dict.update(config["STAN_PARAMETERS"]["standard_parameters"])
        buffer_dict.update(config["STAN_PARAMETERS"]["transformation_parameters"])
        if "seasonality_parameters" in config.get("STAN_PARAMETERS"):
            buffer_dict.update(config["STAN_PARAMETERS"]["seasonality_parameters"])

        output[channel_code] = {
            k: v for k, v in buffer_dict.items() if _is_channel(v, channel_code)
        }

    return output


def stan_response_level(config):
    """
    Returns stan model response level
    """
    return [
        # pms.internal_product_code,
        "brand_name",
        gs.internal_geo_code,
        config.get("RESPONSE_LEVEL_TIME"),
    ]


def transformed_features(config):
    """Returns a dict of the transformed variables and their transformations"""
    return {
        channel_code: dict(
            [
                (predictor, value["transformations"])
                for (predictor, value) in config.get("STAN_PARAMETERS")[
                    "predictor_parameters"
                ].items()
                if "transformations" in value and _is_channel(value, channel_code)
            ]
        )
        for channel_code in config.get("STAN_PARAMETERS")["channels"]
    }


def get_mmx_granularity_combinmations(sell_out_own_df, touchpoint_facts_df, segment_code):
    """
    Returns segments present in the sales and spend data frames
    """
    sell_out_own_df = sell_out_own_df[sell_out_own_df["segment_code"] == segment_code]
    touchpoint_facts_df = touchpoint_facts_df[touchpoint_facts_df["segment_code"] == segment_code]

    sell_out_speciality = list(map(str.lower, sell_out_own_df.specialty_code.unique()))
    touchpoint_facts_speciality = list(map(str.lower, touchpoint_facts_df.specialty_code.unique()))

    sell_out_segment_value = list(map(str.lower, sell_out_own_df.segment_value.unique()))
    touchpoint_facts_segment_value = list(
        map(str.lower, touchpoint_facts_df.segment_value.unique())
    )

    print("sell_out_speciality: ", sell_out_speciality)
    print("touchpoint_facts_speciality: ", touchpoint_facts_speciality)
    print("sell_out_segment_value: ", sell_out_segment_value)
    print("touchpoint_facts_segment_value: ", touchpoint_facts_segment_value)
    speciality_list = list(set(sell_out_speciality).intersection(touchpoint_facts_speciality))
    segment_value_list = list(
        set(sell_out_segment_value).intersection(touchpoint_facts_segment_value)
    )
    return speciality_list, segment_value_list

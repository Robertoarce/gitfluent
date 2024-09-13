""" Module to standardize the column names in the code """

# Dates
F_DATE_WHEN_PREDICTING = "date_when_predicting"
F_DATE_TO_PREDICT = "date_to_predict"
F_HORIZON_WEEKS = "horizon_weeks"

F_YEAR_WEEK = "year_week"
F_YEAR_MONTH = "year_month"
F_YEAR_FISCAL = "fiscal_year"
F_YEAR_CALENDAR = "calendar_year"
F_YEAR_UPLIFT = "year_aggregation_uplift"  # Utility column used in aggregation of volume uplifts
F_YEAR = "year"
F_QUARTER = "quarter"
F_QUARTER_FISCAL = "fiscal_quarter"
F_QUARTER_CALENDAR = "calendar_quarter"
F_IS_FISCAL_YEAR = "is_fiscal_year"
F_IS_REFERENCE_OPTIMIZER = "is_reference_optimizer"
F_IS_BELOW_MIN_SPEND_SALES_RATIO = "filter_ratio_spend_sales"

# Geography
F_REGION = "region"

# Key columns
F_MARKET = "market"
F_PRICE_BAND = "price_band"
F_REF_PRICE = "reference_price"
F_CHANNEL_CODE = "channel_code"

# Product hierarchy
F_SKU_ID = "sku_id"
F_SKU = "sku"
F_SUB_BRAND = "sub_brand"
F_SUB_BRAND_COMPETITOR = "sub_brand_competitor"
F_BRAND = "brand"
F_BRAND_COMPETITOR = "brand_competitor"
F_BRAND_QUALITY_ID = "brand_quality_id"
F_BRAND_QUALITY = "brand_quality"  # BQ
F_BRAND_QUALITY_SIZE = "brand_quality_size"  # BQS = Product Group
F_CATEGORY = "category"
F_SUB_CATEGORY = "sub_category"
F_SKU_EAN = "ean"  # sell-out (case or bottle)
F_SKU_EAN_CASE = "ean_case"
F_SKU_EAN_BOTTLE = "ean_bottle"

# Sell-in
F_SALES_NET = "net_sales"
F_SALES_GROSS = "gross_sales"
F_CHANNEL_SALES = "sales_channel"  # on-trade, off-trade, e-com
F_COGS = "cogs"
F_PRICE_BASE = "base_price"
F_PRICE_ASP_NET = "net_sales_asp"  # Computed based on Net Sales
F_PRICE_ASP_UNIT_NET = "net_sales_asp_per_unit"  # Computed based on Net Sales
F_CONTRIBUTION_MARGIN = "contribution_margin"
F_CONTRIBUTION_MARGIN_PER_UNIT = "contribution_margin_per_unit"

# Sell-out
F_CHANNEL_DISTRIBUTION = "distribution_channel"  # on-trade, off-trade, e-com
F_CHANNEL_DISTRIBUTION_CODE = "distribution_code"
F_COMPANY = "company"  # Owner / manufacturer
F_IS_CHANNEL_2 = "is_on_trade"
F_SALES_SO = "sales_so"
F_SALES_SO_CHANNEL_2 = "sales_so_channel_2"
F_SALES_SO_CHANNEL_1 = "sales_so_channel_1"
F_SALES_SO_PROMO = "sales_so_promo"
F_SKU_SO = "sku_so"
F_VOLUME_SO = "volume_so"  # in 9l c/s
F_BASELINE_VOLUME = "baseline_volume"
F_VOLUME_SO_LY = "volume_so_ly"
F_VOLUME_SO_CHANNEL_2 = "volume_so_channel_2"
F_VOLUME_SO_CHANNEL_1 = "volume_so_channel_1"
F_VOLUME_SO_PROMO = "volume_so_promo"  # in 9l c/s
F_VOLUME_UNITS_SO = "units_sold_so"
F_VOLUME_UNITS_SO_PROMO = "units_sold_so_promo"
F_WEIGHT_DISTRIBUTION = "distribution_weight"
F_PRICE_ASP = "average_selling_price"
F_PRICE_ASP_PROMO = "average_selling_price_on_promo"
F_PRICE_DISCOUNT_FEATURE = "relative_gap_to_90th_price"
F_PRICE_ASP_UNIT = "asp_per_unit"
F_PRICE_ASP_UNIT_PROMO = "asp_promo_per_unit"

F_COMPETITORS_PRICE_ASP = "price_competitors"
F_COMPETITORS_PRICE_FEATURE = "discount_price_competitors"
F_DISTRIBUTION = "distribution"
F_DISTRIBUTION_PROMO = "distribution_promo"
F_DISTRIBUTION_DISPLAY = "num_distrib_display"
F_DISTR_HANDLING = "num_distrib_handling"
F_DISTRIBUTION_FEATURE = "distribution_feature"
F_DISTRIBUTION_FEATURE_DISPLAY = "wt_distrib_display"
F_VISIBILITY = "visibility"
F_SPEND_VISIBILITY = "spend_visibility"
# Promo distribution feature + display

# Signal uplift
F_SIGNAL = "signal"
F_SIGNAL_VOLUME = "signal_volume"
F_ACTIVABLE_SIGNAL = "activable_signal"
F_IS_ACTIVATED = "is_activated"
F_UPLIFT_WEAKSIGNALS = "uplift_weak_signals"
F_UPLIFT_SELLOUT_CAT = "uplift_sell_out_category"
F_WEIGHT = "weight"

# MOC per category
F_MOC = "moc"
F_MOC_WEIGHT = "moc_weight"
F_OTHER = "OTHER"
F_INTERCEPT = "intercept"

# Covid simulation
F_STRINGENCY_INDEX = "stringency_index"
F_SIM_MOC_UPLIFT = "sim_moc_uplift"
F_STRINGENCY_BUCKET = "stringency_bucket"

# Forecast
F_FORECAST = "forecast"
F_CBP_FORECAST = "cbp_forecast"
F_CBP_FORECASTS = "cbp_forecasts"
F_CBP_FORECAST_MODEL = "cbp_forecast_model"
F_AVG_SELLING_PRICE = "asp_07L"  # List price without promo per 0.7L
F_DISCOUNT_RATE = "discount_rate"
F_DISCOUNT = "discount_abs"

# Uplift
F_PREDICTED_VALUE = "predicted"
F_OBSERVED_VALUE = "observed"
F_UPLIFT_MOC = "uplift_moc"
F_UPLIFT_PREDICTED = "uplift_predicted"
F_UPLIFT_CORRECTED = "uplift_corrected"
F_UPLIFT_OBSERVED = "uplift_observed"
F_UPLIFT_SIMULATION = "uplift_simulation"
F_FORECAST_CORRECTED = "forecast_corrected"
F_FORECAST_SIMULATION = "forecast_simulation"
F_FORECAST_BASE = "forecast_base"
F_GROWTH_PERCENT = "growth_percent"
F_GROWTH_PERCENT_SIMULATED = "growth_percent_simulated"
F_GROWTH_PERCENT_BASE = "growth_percent_base"
F_GROWTH_PERCENT_CORRECTED = "growth_percent_corrected"
F_GROWTH_PERCENT_OBSERVED = "growth_percent_observed"

# Execution spend
F_GRP = "grp"
F_REACH = "reach"
F_REACH_PERC = "reach_perc"
F_IMPRESSIONS = "impressions"
F_CLICKS = "clicks"
F_GLASS_IN_HANDS = "gih"  # Brand experience
F_BUDGET = "budget"  # Brand experience
F_PURCHASE_AMOUNT = "purchase_amount"  # On-trade visibility
F_LIFETIME = "lifetime_weeks"

# ERP spend data
F_ACCOUNT_DESC = "account_desc"
F_PROJECT_DESC = "project_desc"
F_SEGMENT_CODE = "segment_code"
F_SEGMENT = "segment"
F_TOUCHPOINT_GROUP = "touchpoint_group"
F_TOUCHPOINT = "touchpoint"
F_TOUCHPOINT_EXEC = "touchpoint_exec"
F_SPEND = "spend"  # euros
F_SPEND_TYPE = "spend_type"

# Spend promo data
F_SPEND_PROMO = "spend_promo"
F_SPEND_PROMO_SHARE = "spend_promo_share"

# Response curve model
# indexes
F_BRAND_KEY = "brand_key"
F_BRAND_INDEX = "b"  # brand index (in Stan model)
F_TIME_INDEX = "t"  # time index (in Stan model)
F_REGION_INDEX = "r"  # time index (in Stan model)
F_TOUCHPOINT_INDEX = "p"  # touchpoint index (in Stan model)
F_TOUCHPOINT_ID = "touchpoint_id"
F_UPLIFT = "uplift"

# Columns in standard Stan summary table
F_CHAIN = "chain"
F_DRAW = "draw"
F_WARMUP = "warmup"
F_SAMPLE_ID = "sample_id"

# Computed quantities
F_FEATURE = "feature"
F_FEATURE_NORM = "feature_normalized"
F_FEATURE_REG = "feature_regression"  # co-variate in regression model
F_FEATURE_BULK = "feature_bulk"
F_FILTER_BULK = "filter_bulk"
F_VOLUME_SO_PRED_NORM = "volume_so_f_normalized"
F_VOLUME_SO_CHANNEL_2_PRED_NORM = "volume_so_channel_2_f_normalized"
F_VOLUME_SO_CHANNEL_1_PRED_NORM = "volume_so_channel_1_f_normalized"
F_VOLUME_SO_FORECAST = "volume_so_f"  # STAN model output
F_VOLUME_SO_CHANNEL_2_FORECAST = "volume_so_f_channel_2"
F_VOLUME_SO_CHANNEL_1_FORECAST = "volume_so_f_channel_1"
F_VOLUME_PRED = "volume_f_denorm"  # denormalized forecast
F_VOLUME_SO_CHANNEL_2_PRED = "volume_so_f_denorm_channel_2"
F_VOLUME_SO_CHANNEL_1_PRED = "volume_so_f_denorm_channel_1"
F_VOLUME_PRED_p10 = "volume_f_denorm_p10"
F_VOLUME_PRED_p90 = "volume_f_denorm_p90"
F_REVENUES = "revenues"
F_REVENUES_p10 = "revenues_p10"
F_REVENUES_p90 = "revenues_p90"
F_FEATURE_BRAND_CONTRIBUTION = "feature_brand_contribution"
F_REF_VOLUME = "ref_volume"
F_REF_SALES = "ref_sales"
F_NULL_VOLUME = "null_volume"
F_NULL_REVENUES = "null_revenues"
F_DELTA_VOLUME_SO_UPLIFT = "delta_volume_so_uplift"
F_DELTA_TO_NULL_VOLUME = "delta_to_null_volume"
F_DELTA_TO_NULL_VOLUME_CHANNEL_2 = "delta_to_null_volume_channel_2"
F_DELTA_TO_NULL_VOLUME_CHANNEL_1 = "delta_to_null_volume_channel_1"
F_DELTA_TO_NULL_VOLUME_p10 = "delta_to_null_volume_p10"
F_DELTA_TO_NULL_VOLUME_CHANNEL_2_p10 = "delta_to_null_volume_channel_2_p10"
F_DELTA_TO_NULL_VOLUME_CHANNEL_1_p10 = "delta_to_null_volume_channel_1_p10"
F_DELTA_TO_NULL_VOLUME_p90 = "delta_to_null_volume_p90"
F_DELTA_TO_NULL_VOLUME_CHANNEL_2_p90 = "delta_to_null_volume_channel_2_p90"
F_DELTA_TO_NULL_VOLUME_CHANNEL_1_p90 = "delta_to_null_volume_channel_1_p90"
F_DELTA_TO_NULL_REVENUES = "delta_to_null_revenues"
F_DELTA_TO_NULL_REVENUES_p10 = "delta_to_null_revenues_p10"
F_DELTA_TO_NULL_REVENUES_p90 = "delta_to_null_revenues_p90"
F_LAMBDA_ADSTOCK = "lambda_adstock"
F_DELTA_TO_NULL_VOLUME_PERCENT = "delta_to_null_volume_percent"

# Metrics
F_R_SQUARE = "r_square"
F_MEAN_ABSOLUTE_ERROR = "mean_absolute_error"
F_MAPE = "MAPE"

# Accounting metrics
F_SPEND_CONVERSION_RATE = "spend_conversion_rate"  # Conversion Marketing & Trade execution to spend
F_SELL_OUT = "sell_out"
# CAAP = Contribution After A&P = (Contributive margin * Volume uplift) -
# A&P spend
F_CAAP = "caap"
# CAAP = Contribution After A&P = (Contributive margin * Volume uplift) -
# A&P spend
F_CAAP_p10 = "caap_p10"
# CAAP = Contribution After A&P = (Contributive margin * Volume uplift) -
# A&P spend
F_CAAP_p90 = "caap_p90"
# ROS = Return on Sell-out = (sell-out ASP * Volume uplift / Spend)
F_ROS = "ros"
F_ROS_p10 = (
    # ROS = Return on Sell-out = (sell-out ASP * Volume uplift / Spend)
    "ros_p10"
)
F_ROS_p90 = (
    # ROS = Return on Sell-out = (sell-out ASP * Volume uplift / Spend)
    "ros_p90"
)
F_ROI = "roi"  # ROI = (Contributive margin / Spend)
F_ROI_p10 = "roi_p10"  # ROI = (Contributive margin / Spend)
F_ROI_p90 = "roi_p90"  # ROI = (Contributive margin / Spend)
F_MROI = "mroi"  # mROI = Marginal incremental sales / marginal spend
F_GMROI = "gmroi"  # GM ROI = incremental sales * gross margin factor / spend
F_NETROI = "netroi"  # NET ROI = incremental sales / spend

# Brand equity
F_CUSTOMER_LIFETIME_VALUE = "customer_lifetime_value"
F_BRAND_RECOMMENDATION = "brand_recommendation"
F_BRAND_AWARENESS = "brand_awareness"
F_PURCHASE_FREQUENCY = "frequency_of_purchase"
F_LAST_YEAR_SPEND = "last_year_spend"
F_LAST_YEAR_CONTRIBUTIVE_MARGIN = "last_year_contributive_margin"
F_GROWTH_CONTRIBUTIVE_MARGIN = "growth_contributive_margin"
F_LAST_YEAR_MARKET_SHARE = "last_year_market_share"

# Recommendation engine outputs
F_METRIC = "metric"
F_TIME_HORIZON = "time_horizon"
F_IS_LT_INCLUDED = "is_long_term_effect_included"
F_IS_WITH_BASELINE = "is_with_baseline"
F_IS_NEW_TOUCHPOINT = "is_new_touchpoint"
F_MARKETING_TRADE_OVER_NET_SALES_RATIO = "marketing_trade_over_net_sales_ratio"
F_VALUE_METRIC = "value"
F_VALUE_FROM_ALLOC = "value_from_alloc"
F_VALUE_FROM_ROI_BOOST = "value_from_roi_boost"
F_VALUE_FROM_SPEND_BEYOND_RC = "value_from_spend_beyond_response_curves"
F_LAST_YEAR_VALUE_METRIC = "last_year_value"
F_LAST_YEAR_WITH_GROWTH_VALUE_METRIC = "last_year_with_growth_value"
F_REFERENCE_VALUE = "reference_value"
F_REFERENCE_VALUE_WITH_GROWTH = "reference_value_with_growth"
F_REFERENCE_VALUE_PROJECTED = "reference_value_projected"
F_LAST_YEAR_DELTA_VALUE_METRIC = "last_year_delta"
F_DELTA_FROM_GROWTH = "delta_from_growth"
F_DELTA_FROM_RECO = "delta_from_reco"
F_LAST_YEAR_VARIATION_VALUE_METRIC = "last_year_variation"
F_VARIATION_FROM_GROWTH = "variation_from_growth"
F_VARIATION_FROM_RECO = "variation_from_reco"
F_IS_IN_SCOPE_OPTI = "is_in_scope_optimizer"
F_HAS_FIXED_SPEND = "has_fixed_spend"
F_FILTER_RATIO_SPEND_SALES = "filter_ratio_spend_sales"
F_FILTER_OUT = "filter_out"
F_HOUSE_OF_BRANDS = "house_of_brands"


# Data schema
F_PRODUCT_LEVEL = "product_level"
F_PRODUCT_VALUE = "product_value"
F_FREQUENCY = "frequency"
F_PERIOD_START = "period_start"
F_REFERENCE_PERIOD_START = "reference_period_start"
F_GEO_LEVEL = "geo_level"
F_GEO_VALUE = "geo_value"
F_TOUCHPOINT_LEVEL = "touchpoint_level"
F_TOUCHPOINT_VALUE = "touchpoint_value"
F_RESPONSE_TOUCHPOINT = "response_touchpoint"
F_CHANNEL = "channel_code"
F_CURRENCY = "currency"
F_UNIT = "unit"
F_PERCENT = "percent"
F_CAMPAIGN_ID = "campaign_id"
F_CHANNEL_ID = "channel_id"
F_VOLUME = "volume"
F_VALUE = "value"

# value uplift calculation param
F_DELTA_TO_NULL_VALUE = "delta_to_null_value"
F_DELTA_TO_NULL_VALUE_p10 = "delta_to_null_value_p10"
F_DELTA_TO_NULL_VALUE_p90 = "delta_to_null_value_p90"
F_DELTA_TO_NULL_VALUE_PERCENT = "delta_to_null_volume_percent"
F_VALUE_PRED_p10 = "value_f_denorm_p10"
F_VALUE_PRED_p90 = "value_f_denorm_p90"
F_VALUE_PRED = "value_f_denorm"
F_VALUE_PRED_p10 = "value_f_denorm_p10"
F_VALUE_PRED_p90 = "value_f_denorm_p90"

"""
    Created by: Dipkumar Patel
"""
import logging
import os
import time

import arviz as az
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import scipy
import seaborn as sns
from pandas.api.types import is_numeric_dtype
from sklearn.linear_model import LinearRegression

from src.pipeline.feature_engineering.utils import save_file
from src.utils.names import (
    F_CHANNEL_CODE,
    F_SALES_SO,
    F_TOUCHPOINT,
    F_VALUE,
    F_VOLUME,
    F_YEAR_MONTH,
)
from src.utils.schemas.response_model.input import GeoMasterSchema
from src.utils.settings_utils import get_feature_param_value

gs = GeoMasterSchema()
logger = logging.getLogger(__name__)


def _pdf_normal_distribution(x: np.ndarray, mu: float, sigma: float, **kwargs):
    """
    Function to plot the pdf of a normally distributed prior
    Args:
        mu : mean of distribution
        sigma: <standard_deviation> of distribution
            - scipy.stats.norm(loc = mean, scale = std dev)
            - vs normal(mu = mean, sigma = std dev) in PyStan
    """
    print(f"Receved kwargs {kwargs}")
    y = scipy.stats.norm.pdf(x, loc=mu, scale=sigma)
    return y


def _pdf_gamma_distribution(x: np.ndarray, alpha: float, beta: float, offset=0, **kwargs):
    """
    Function to plot the pdf of a prior following a Gamma distribution
    Args:
        alpha : mean of distribution
        beta: <standard_deviation> of distribution
            - scipy.stats.gamma(a = alpha, scale = 1 / beta, loc = offset)
            - vs gamma(alpha, beta) in PyStan
    https://mc-stan.org/docs/2_21/functions-reference/gamma-distribution.html
    """
    print(f"Receved kwargs {kwargs}")
    y = scipy.stats.gamma.pdf(x, a=alpha, scale=1 / beta, loc=offset)
    return y


def _pdf_beta_distribution(x: np.ndarray, alpha: float, beta: float, **kwargs):
    """
    Function to plot the pdf of a prior following a beta distribution
    Args:
       - scipy.stats.beta(a = alpha, b = beta)
       - vs beta(alpha, beta) in PyStan
    https://mc-stan.org/docs/2_21/functions-reference/beta-distribution.html
    """
    print(f"Receved kwargs {kwargs}")
    y = scipy.stats.beta.pdf(x, a=alpha, b=beta)
    return y


def _pdf_exp_distribution(x: np.ndarray, lambda_exp: float, **kwargs):
    """
    Function to plot the pdf of a prior following a beta distribution
    Args:
       - scipy.stats.expon(scale = 1 / lambda_exp)
       - vs exponential(lambda_exp) in PyStan
    https://mc-stan.org/docs/2_22/functions-reference/exponential-distribution.html
    """
    print(f"Receved kwargs {kwargs}")
    y = scipy.stats.expon.pdf(x, scale=1 / lambda_exp)
    return y


# pylint:disable=too-few-public-methods


class BayesianPostProcess:
    """
    Class to perform validations on the Bayesian model outputs.
    """

    def __init__(self, bayesian_model, channel_code, config, experiment_tracker, levels):
        self.bayesian_model = bayesian_model
        self.model_fit = self.bayesian_model.fit
        self.fit_summary = self.model_fit.summary(sig_figs=3)
        self.config = config
        self.channel_code = channel_code
        self.experiment_tracker = experiment_tracker
        self.levels = levels

    def run_post_processing(self):
        """
        Method to perform the post process validations
        """
        logger.info(self.model_fit)
        time.sleep(40)
        self._check_intercept()
        time.sleep(40)
        self._check_betas()
        print("POST-DEBUG 3: _check_betas")
        time.sleep(40)
        self._get_metrics()
        print("POST-DEBUG 4: _get_metrics")
        time.sleep(40)
        if self.config.get("save_debug_traces_plots"):
            self._get_params_traces()
        time.sleep(30)
        self._check_rhat()
        print("POST-DEBUG 5: _check_rhat")
        time.sleep(40)
        self._check_div()
        print("POST-DEBUG 5: _check_div")
        if self.config.get("save_debug_model_metrics"):
            time.sleep(40)
            self._get_p_values()
            time.sleep(40)
            self._get_vif()
            time.sleep(40)

    def _check_intercept(self):
        """
        This check is meant to verify that intercept posterior created based on target values
        are likely (within 3 s.d. of prior N(ref, 2 * sigma) )
        """
        fit_summary = self.fit_summary
        target_variable = self.config.get("TARGET_VARIABLE")
        # intercepts_indexes_list = list(
        #     fit_summary.filter(like=f"generated_{target_variable}_ref", axis=0)
        #     .reset_index()["name"]
        #     .apply(lambda x: "[" + x.split("[")[-1])
        #     .values
        # )
        temp_list = list(fit_summary.filter(like=f"generated_{target_variable}_ref", axis=0).index)
        intercepts_indexes_list = [x[x.index("[") :] for x in temp_list]
        # intercepts_indexes_list = [ str(x)[-5:] for x in  temp_list].
        # #TODO: Dip - added a new line above to handle two digit number list
        print("DEBUG - post_processing:", intercepts_indexes_list)

        for index in intercepts_indexes_list:
            intercept_name = "intercept" + index
            target_ref_name = "generated_" + target_variable + "_ref" + index
            target_std_name = "generated_" + target_variable + "_std" + index

            intercept = fit_summary.loc[intercept_name]["Mean"]
            target_ref = fit_summary.loc[target_ref_name]["Mean"]
            target_std = fit_summary.loc[target_std_name]["Mean"]

            target_lowerbound = target_ref - 2 * 3 * target_std
            target_upperbound = target_ref + 2 * 3 * target_std
            print("...target_low", target_lowerbound, "target_upper", target_upperbound)

            if intercept < target_lowerbound or intercept > target_upperbound:
                logger.debug(f"{intercept_name} is likely to have a too narrow prior")
                logging.debug(
                    f"intercept value is {intercept};"
                    f"likely bounds are [{target_lowerbound:.1f}, {target_upperbound:.1f}]"
                )

    def _check_betas(self):
        print("DEBUG CHECK BETA: start", self.model_fit.stan_variables().keys())
        for param in self.model_fit.stan_variables().keys():
            if param.startswith("beta_"):
                feature = param[5:]
                # prior_tuple = self.config[feature]["prior"][self.channel_code]
                prior_tuple = get_feature_param_value(
                    self.config, feature, "prior", self.channel_code
                )
                print(".........", feature, prior_tuple)

                if isinstance(prior_tuple, tuple):
                    prior, prior_parameters = prior_tuple
                    if prior == "normal":
                        self._check_posterior_vs_prior(
                            param, prior_parameters["mu"], prior_parameters["sigma"]
                        )
                    else:
                        logging.info(f"Posterior check not implemented yet for {prior}")

    def _check_posterior_vs_prior(self, param, prior_mean, prior_std):
        fit_summary = self.fit_summary
        param_indexes_list = list(
            fit_summary.filter(like=f"{param}[", axis=0)
            .reset_index()["name"]
            .apply(lambda x: "[" + x.split("[")[-1])
            .values
        )
        for index in param_indexes_list:
            param_name = param + index
            param_posterior_mean = fit_summary.loc[param_name]["Mean"]

            target_lowerbound = prior_mean - 3 * prior_std
            target_upperbound = prior_mean + 3 * prior_std

            if param_posterior_mean < target_lowerbound or param_posterior_mean > target_upperbound:
                logger.debug(
                    f"{param_name} is likely to have a too narrow prior : "
                    f"Posterior mean value is {param_posterior_mean} and "
                    f"likely bounds are [{target_lowerbound:.1f}, {target_upperbound:.1f}]"
                )

    def _check_rhat(self):
        """
        Checks the potential scale reduction factors
        :param fit:
        :return:
        """
        fit_summary = self.fit_summary
        rhats = fit_summary["R_hat"]
        # self.experiment_tracker.log_params({"r_hat": rhats})
        rhats_warning = rhats[(rhats > 1.1) | (rhats.isna()) | ~np.isfinite(rhats)]

        if len(rhats_warning) > 0:
            buffer = []
            na_warning = True
            for param, value in zip(rhats_warning.index, rhats_warning):
                feature = param.split("[")[0]
                if feature in buffer:
                    continue

                if na_warning and np.isnan(value):
                    buffer.append(feature)
                    logging.debug(
                        f"Rhat for parameter {param} is Nan. "
                        "Showing only one NaN warning, check debug outputs"
                    )
                    na_warning = False
                elif value is not np.nan:
                    buffer.append(feature)
                    logging.debug(
                        f"Rhat for parameter {param} is {value}. "
                        "Showing only one value for this parameter"
                    )
            logging.info("Rhat above 1.1 indicates that the chains very likely have not mixed")
            logging.info(
                "Check r_hats_warning output for in-depth information on r_hat pathological values"
            )
        else:
            logging.info("Rhat looks reasonable for all parameters")

    def _check_div(self):
        """
        Check transitions that ended with a divergence
        :param fit:
        :return:
        """
        divergent = self.model_fit.sampler_variables()["divergent__"].flatten()
        # self.experiment_tracker.log_params({"divergent": divergent})
        n = sum(divergent)
        N = len(divergent)
        logging.info(f"{n} of {N} iterations ended with a divergence ({100 * n / N}%)")
        if n > 0:
            logging.info("  Try running with larger adapt_delta to remove the divergences")

    def _get_metrics(self):
        target_variable = self.config.get("TARGET_VARIABLE")
        inference_data = az.from_cmdstanpy(
            self.model_fit,
            observed_data={target_variable: target_variable},
            log_likelihood="log_likelihood",
        )
        waic = az.waic(data=inference_data, scale="deviance")
        loo = az.loo(data=inference_data, scale="deviance")
        logger.info(f"Model LOO is {loo}")
        logger.info(f"Model WAIC is {waic}")
        # Track metrics
        # self.model_tracker.log_metrics({"WAIC": waic.waic, "LOO": loo.loo})

    def _get_vif(self):
        data = self.bayesian_model.normalized_features_df
        not_exogs = [
            "brand_name",
            F_YEAR_MONTH,
            F_CHANNEL_CODE,
            gs.internal_geo_code,
            "week",
            F_VOLUME,
            F_VALUE,
            F_SALES_SO,
            "average_selling_price",
            "ref_90th_price",
        ]
        exogs = [i for i in data.columns if (i not in not_exogs) and (is_numeric_dtype(data[i]))]

        dfs_vif = []
        for brand in data["brand_name"].unique():
            vif_dict, tolerance_dict = {}, {}
            data_ft = data[data["brand_name"] == brand]
            for exog in exogs:
                not_exog = [i for i in exogs if i != exog]
                X, y = data_ft[not_exog], data_ft[exog]

                # extract r-squared from the fit
                r_squared = LinearRegression().fit(X, y).score(X, y)

                # calculate VIF
                if r_squared != 1:
                    vif = 1 / (1 - r_squared)
                else:
                    vif = np.inf
                vif_dict[exog] = vif

                # calculate tolerance
                tolerance = 1 - r_squared
                tolerance_dict[exog] = tolerance

            # return VIF DataFrame
            df_vif = pd.DataFrame({"VIF": vif_dict, "Tolerance": tolerance_dict})
            df_vif["brand_name"] = brand
            dfs_vif.append(df_vif.reset_index())

        df_vif = pd.concat(dfs_vif)
        df_vif = df_vif[np.isfinite(df_vif.VIF)]

        save_file(
            data=df_vif,
            file_name=f"metrics/vif_summary_{self.channel_code}.csv",
            experiment_tracker=self.experiment_tracker,
            mlflow_directory=self.channel_code
            if self.levels is None
            else os.path.join(
                self.levels["speciality"],
                self.levels["segment_code"],
                self.levels["segment_value"],
            ),
        )

    def _get_p_values(self):
        stan_summary = self.model_fit.summary()

        BETA_PARAMS = ["beta"]
        SHAPE_PARAMS = ["shape_param", "shape_param_raw", "scale_param"]
        ADSTOCK_PARAMS = ["lambda_adstock"]

        params_summary = stan_summary.loc[
            stan_summary.index.str.contains("|".join(BETA_PARAMS + SHAPE_PARAMS + ADSTOCK_PARAMS)),
            ["Mean", "StdDev"],
        ]
        params_summary["T_stat"] = params_summary["Mean"] / params_summary["StdDev"]
        params_summary["p_value"] = 2 * (
            1 - scipy.stats.t.cdf(np.abs(params_summary["T_stat"]), df=1e6)
        )

        params_summary["mapping_index"] = list(
            params_summary.index.str.extract(r"^[a-zA-Z0-9]\w+\[([0-9]+)")[0].astype(int)
        )

        # -------- ADHOC post-processing:
        # This will probably needs to be rewritten if model formulation changes
        brand_index_df = pd.DataFrame(
            self.bayesian_model.indexes.brand_index.items(),
            columns=["brand_name", "mapping_index"],
        )
        shape_index_df = pd.DataFrame(
            self.bayesian_model.indexes.shape_index.items(),
            columns=[F_TOUCHPOINT, "mapping_index"],
        )
        adstock_index_df = pd.DataFrame(
            self.bayesian_model.indexes.adstock_index.items(),
            columns=[F_TOUCHPOINT, "mapping_index"],
        )

        params_summary = params_summary.reset_index()
        beta_params_summary = (
            params_summary.loc[params_summary["name"].str.contains("|".join(BETA_PARAMS)), :]
            .merge(brand_index_df, on=["mapping_index"], how="left")
            .drop(columns=["mapping_index"])
        )
        beta_params_summary[F_TOUCHPOINT] = beta_params_summary["name"].str.extract(
            r"^beta_([a-zA-Z0-9]\w+)\["
        )
        shape_params_summary = (
            params_summary.loc[params_summary["name"].str.contains("|".join(SHAPE_PARAMS)), :]
            .merge(shape_index_df, on=["mapping_index"], how="left")
            .drop(columns=["mapping_index"])
            .assign(key=1)
            .merge(
                brand_index_df[["brand_name"]].assign(key=1),
                on=["key"],
            )
            .drop(columns=["key"])
        )
        adstock_params_summary = (
            params_summary.loc[params_summary["name"].str.contains("|".join(ADSTOCK_PARAMS)), :]
            .merge(adstock_index_df, on=["mapping_index"], how="left")
            .drop(columns=["mapping_index"])
            .assign(key=1)
            .merge(
                brand_index_df[["brand_name"]].assign(key=1),
                on=["key"],
            )
            .drop(columns=["key"])
        )

        params_summary = (
            pd.concat(
                [beta_params_summary, shape_params_summary, adstock_params_summary],
                sort=False,
            )
            .sort_values(["brand_name", F_TOUCHPOINT])
            .rename(columns={"name": "param_name"})
        )

        # Trick to avoid breaking the Excel csv reader with a comma
        params_summary["param_name"] = params_summary["param_name"].str.replace(",", "-")
        self.params_summary = params_summary.copy()
        save_file(
            data=params_summary,
            file_name=f"metrics/params_p_value_summary_{self.channel_code}.csv",
            experiment_tracker=self.experiment_tracker,
            mlflow_directory=self.channel_code
            if self.levels is None
            else os.path.join(
                self.levels["speciality"],
                self.levels["segment_code"],
                self.levels["segment_value"],
            ),
        )

    def _get_params_traces(self):
        # Improvement : use arviz
        logging.info("[STAN] Model bayesian_validation_model -- Traces")

        for param, values in self.model_fit.stan_variables().items():
            if len(values.shape) == 1:
                self._plot_trace(self.model_fit[param], param=param, param_name=param)

            if len(values.shape) == 2:
                if param in [
                    "shape_param",
                    "scale_param",
                    "lambda_adstock",
                ]:
                    mapping = self.bayesian_model.indexes.shape_index
                    if param == "lambda_adstock":
                        mapping = self.bayesian_model.indexes.adstock_index

                    for touchpoint, index in mapping.items():
                        trace = values[:, index - 1]
                        self._plot_trace(
                            trace,
                            param=" - ".join([param, touchpoint]),
                            param_name=" - ".join([param, touchpoint]),
                        )
                else:
                    if param.startswith("beta") or param in ["intercept", "sigma"]:
                        for (
                            index,
                            brand,
                        ) in self.bayesian_model.indexes.index_brand.items():
                            trace = values[:, index - 1]
                            self._plot_trace(trace, param=param, param_name=param + " - " + brand)
            if len(values.shape) == 3:
                if param.startswith("beta") or param in ["intercept", "sigma"]:
                    for i_b, brand in self.bayesian_model.indexes.index_brand.items():
                        for (
                            i_r,
                            region,
                        ) in self.bayesian_model.indexes.index_region.items():
                            trace = values[:, i_b - 1, i_r - 1]
                            self._plot_trace(
                                trace,
                                param=param,
                                param_name=param + " - " + brand + " - " + region,
                            )

    def _plot_trace(self, trace, param, param_name="parameter"):
        """Plot the trace and posterior of a parameter."""

        # Summary statistics
        mean = np.mean(trace)
        median = np.median(trace)
        cred_min, cred_max = np.percentile(trace, 2.5), np.percentile(trace, 97.5)

        # Plotting
        fig = plt.figure(figsize=(20, 8))
        plt.subplot(3, 1, 1)
        plt.plot(trace)
        plt.xlabel("samples")
        plt.ylabel(param_name)
        plt.axhline(mean, color="r", lw=2, linestyle="--", label="mean")
        plt.axhline(median, color="c", lw=2, linestyle="--", label="median")
        plt.axhline(cred_min, linestyle=":", color="k", alpha=0.2)
        plt.axhline(cred_max, linestyle=":", color="k", alpha=0.2)
        plt.title(f"Trace and Posterior Distribution for {param_name}")
        plt.legend()

        ax1 = plt.subplot(3, 1, 2)
        plt.hist(trace, 30, density=True)
        sns.kdeplot(trace, shade=True)
        plt.xlabel(param_name)
        plt.ylabel("density")
        plt.axvline(mean, color="r", lw=2, linestyle="--", label="mean")
        plt.axvline(median, color="c", lw=2, linestyle="--", label="median")
        plt.axvline(cred_min, linestyle=":", color="k", alpha=0.2, label="95% CI")
        plt.axvline(cred_max, linestyle=":", color="k", alpha=0.2)
        plt.legend()

        plt.subplot(3, 1, 3, sharex=ax1)

        if param.startswith("beta_"):
            feature = param[5:]
        else:
            feature = param

        prior_tuple = get_feature_param_value(self.config, feature, "prior", self.channel_code)

        if isinstance(prior_tuple, tuple):
            prior, prior_parameters = prior_tuple
            x = np.arange(trace.min(), trace.max(), 0.001)
            if prior == "normal":
                y = _pdf_normal_distribution(x=x, **prior_parameters)
            elif prior in ["gamma", "gamma_offset"]:
                y = _pdf_gamma_distribution(x=x, **prior_parameters)
            elif prior == "beta":
                y = _pdf_beta_distribution(x=x, **prior_parameters)
            elif prior == "exponential":
                y = _pdf_exp_distribution(x=x, **prior_parameters)
        else:
            x = np.linspace(0, 1, 100)
            y = np.array([0.5 for i in range(len(x))])

        plt.plot(x, y)
        plt.ylim(bottom=0)
        # plt.legend()

        plt.xlabel(f"Prior on {param_name}")
        plt.ylabel("density")
        plt.xticks(rotation=45)
        plt.xlim()
        plt.gcf().tight_layout()

        save_file(
            data=fig,
            file_name=f"output/traceplot_{param_name}_{self.channel_code}.png",
            experiment_tracker=self.experiment_tracker,
            mlflow_directory=self.channel_code + "/traceplot/"
            if self.levels is None
            else os.path.join(
                self.levels["speciality"],
                self.levels["segment_code"],
                self.levels["segment_value"],
                "traces",
            ),
        )
        plt.close()

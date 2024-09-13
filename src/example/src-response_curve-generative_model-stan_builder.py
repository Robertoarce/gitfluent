import os
import textwrap
from collections import defaultdict

import pandas as pd

from src.pipeline.feature_engineering.run_feature_engineering import model_inputs_dict
from src.pipeline.feature_engineering.utils import (
    predictor_features_name,
    seasonality_features,
)
from src.pipeline.response_model.utils import (
    all_settings_dict,
    stan_response_level,
    transformation_length,
)
from src.response_curve.st_response_model import transformed_features
from src.utils.names import F_YEAR_MONTH
from src.utils.schemas.response_model.input import GeoMasterSchema, ProductMasterSchema
from src.utils.settings_utils import get_feature_from_name, get_name_from_feature

gs = GeoMasterSchema()
pms = ProductMasterSchema()


class StanBuilder:
    """
    StanBuilder class is responsible for generating Stan code based on
    configuration settings and channel code. 
    It provides methods to build and save the Stan model.
    """
    def __init__(self, channel_code, config):
        """
        Initialize a StanBuilder object.

        Args:
            channel_code (str): The channel code.
            config (dict): The configuration settings.
        """
        self.target_variable = config.get("TARGET_VARIABLE")
        self.channel_code = channel_code
        self.config = config
        self.mapping_dimensions = {
            # pms.internal_product_code: "B",
            "brand_name": "B",
            gs.internal_geo_code: "R",
            gs.sub_national_code: "R",
            F_YEAR_MONTH: "T[B]",
            "shape": "S",
            "adstock": "M",
        }

        self.mapping_dimensions.get
        stan_response_level(self.config)
        self.target_dim = ",".join(
            list(map(self.mapping_dimensions.get, stan_response_level(self.config)))
        )[:-5]
        self.target_ind = ",".join(
            list(map(self.mapping_dimensions.get, stan_response_level(self.config)))
        ).lower()[:-5]
        self.bounds = f"I[{self.target_ind},1]:I[{self.target_ind},2]"
        self.bounds_brand = f"I[{self.target_ind},1]:I[{self.target_ind},2]"
        self.dim_beta = {}
        for param, value in all_settings_dict(self.config)[self.channel_code].items():
            if "parameter_dimension" in value:
                self.dim_beta[get_feature_from_name(self.config, param)] = list(
                    map(self.mapping_dimensions.get, value["parameter_dimension"])
                )

        self.transfos = defaultdict(list)
        for transformations in transformed_features(self.config)[self.channel_code].values():
            for transfo, params in transformations.items():
                for param in params:
                    self.transfos[transfo] += [param]
                self.transfos[transfo] = list(set(self.transfos[transfo]))

    def build_and_save_model(self, path_to_stan):
        """
        Build and save the Stan model to a file.

        Args:
            path_to_stan (str): The path to save the Stan model.
        """
        model = self.build_stan_code()
        os.makedirs(os.getcwd() + os.path.dirname(path_to_stan), exist_ok=True)
        with open(
            os.getcwd() + path_to_stan,
            "w",
        ) as f:
            f.write(model)

    def build_data_block(self):
        stan_data = f"""{self._dimensions_data_input()}
{self._transformations_input()}
{self._variables_data_input()}"""
        return stan_data

    def build_transformed_data_block(self):
        """
        Priors of intercept will be N(ref_volume, 2 * std_volume) with ref_volume the 10th percentile of volume
        i.e. ref_volume = min_volume + 0.1 * (max_volume - min_volume)
        """
        stan_transformed_data = f"""real {self.target_variable}_ref[{self.target_dim}];
real {self.target_variable}_std[{self.target_dim}];
{self.target_variable}_ref[{self.target_ind}] = quantile({self.target_variable}[{self.bounds}], 0.1);
{self.target_variable}_std[{self.target_ind}] = sd({self.target_variable}[{self.bounds}]);"""
        return stan_transformed_data

    def build_parameters_block(self):
        """
        Method to build parameters block in stan file
        """
        stan_parameters = f"""{self._standard_parameters()}
{self._transformation_parameters()}
{self._dependent_variables_parameters()}
{self._seasonality_parameters()}"""
        return stan_parameters

    def build_transformed_parameters(self):
        """
        Method to build transformed parameters in stan file
        """
        stan_transformed_parameters = f"""row_vector[N] mu;
{self._build_intercept()}
{self._build_stan_param_transformation()}
{self._hierarchical_transformed_parameters()}
{self._build_stan_feature_transformation()}
{self._build_equation()}"""
        return stan_transformed_parameters

    def build_priors(self):
        """
        Method to build priors in stan file
        """
        stan_model = f"""{self._static_prior_input()}
{self._transformations_prior_input()}
{self._dependent_variables_prior()}
{self._seasonality_priors()}
{self.target_variable}[{self.bounds}] ~  normal(mu[{self.bounds}], sigma[{self.target_ind}]);"""
        return stan_model

    def build_generated_quantities(self):
        """
        Method to build generated quantities block in stan file
        """
        print("Inside stan_builder build_generated_quantities method ")
        output = f"""real generated_{self.target_variable}_ref[{self.target_dim}] = {self.target_variable}_ref;
real generated_{self.target_variable}_std[{self.target_dim}] = {self.target_variable}_std;
row_vector[N] sigma_N;
sigma_N[{self.bounds}] = rep_row_vector(sigma[{self.target_ind}], T[b]);
row_vector[N] log_likelihood;
row_vector[N] value_so_f;
log_likelihood[n] = normal_lpdf({self.target_variable}[n] | mu[n], sigma_N[n]);
value_so_f[n] = normal_rng(mu[n], sigma_N[n]);"""
        return output

    def build_stan_code(self):
        """
        Build the Stan code for the model.

        Returns:
            str: The generated Stan code.
        """
        return f"""functions {{

        real shape_value_with_threshold(
            real shape_param,
            real scale_param,
            real threshold,
            real spend_value
        ){{
            real returned_value;

            if (spend_value < threshold)
                returned_value = 0;
            else
                returned_value = 1 - exp(
                    - 1 * pow(
                        (spend_value - threshold) / scale_param,
                        shape_param
                    )
                );

            return returned_value;
        }}

        // Shape function
        row_vector shape(
            real shape_param,
            real scale_param,
            real threshold,
            data int T,
            row_vector spend
        ){{
            row_vector[T] shaped_spend_brand;

            for (t in 1:T){{
                shaped_spend_brand[t] =
                    shape_value_with_threshold(
                        shape_param,
                        scale_param,
                        threshold,
                        spend[t]
                    );
            }}

            return shaped_spend_brand;
        }}

        // Parametric adstock function
        row_vector parametric_spend_touchpoint_adstock_per_brand(
            real lambda_adstock_touchpoint,
            data int T,
            row_vector spend_touchpoint_brand,
            int adstock_length
        ){{
            row_vector[T] spend_touchpoint_adstock_brand;

            row_vector[adstock_length+1] lambda_powers;
            matrix[adstock_length + 1, T] matrix_shifted_features;

            // Row vector of coefficients
            // For now, coefficients are increasing powers of lambda
           for (l in 1:adstock_length + 1){{
                lambda_powers[l] = pow(lambda_adstock_touchpoint, l-1);
           }}

            // Matrix of shifted spend
            matrix_shifted_features[1] = spend_touchpoint_brand;
            for (l in 1:adstock_length){{
                matrix_shifted_features[l+1] = append_col(0, head(row(matrix_shifted_features, l), T-1));
            }}

            // Adstock calculation
            spend_touchpoint_adstock_brand = lambda_powers * matrix_shifted_features;

            return spend_touchpoint_adstock_brand;
        }}
        // Parametric adstock with lag function
        row_vector parametric_spend_touchpoint_adstock_per_brand_with_lag(
            real lambda_adstock_touchpoint,
            real lag_adstock_touchpoint,
            data int T,
            row_vector spend_touchpoint_brand,
            int adstock_length
        ){{
            row_vector[T] spend_touchpoint_adstock_brand;

            row_vector[adstock_length+1] lambda_powers;
            matrix[adstock_length + 1, T] matrix_shifted_features;

            // Row vector of coefficients
            // For now, coefficients are increasing powers of lambda
           for (l in 1:adstock_length + 1){{
                lambda_powers[l] = pow(lambda_adstock_touchpoint, pow(l-1-lag_adstock_touchpoint, 2));
           }}

            // Matrix of shifted spend
            matrix_shifted_features[1] = spend_touchpoint_brand;
            for (l in 1:adstock_length){{
                matrix_shifted_features[l+1] = append_col(0, head(row(matrix_shifted_features, l), T-1));
            }}

            // Adstock calculation
            spend_touchpoint_adstock_brand = (lambda_powers/sum(lambda_powers)) * matrix_shifted_features;

            return spend_touchpoint_adstock_brand;
        }}
}}
data{{
{loop_and_indent(self.config, self.build_data_block())}
}}
transformed data{{
{loop_and_indent(self.config, self.build_transformed_data_block())}
}}
parameters{{
{loop_and_indent(self.config, self.build_parameters_block())}
}}
transformed parameters{{
{loop_and_indent(self.config, self.build_transformed_parameters())}
}}
model{{
{loop_and_indent(self.config, self.build_priors())}
}}
generated quantities{{
{loop_and_indent(self.config, self.build_generated_quantities())}
}}
"""

    def _dimensions_data_input(self):
        """
        Build the dimensions data input block for the Stan model.

        Returns:
            str: The dimensions data input block.
        """
        output = "int N;\n"
        dimensions = model_dimensions(self.config, self.channel_code)
        model_dims = sorted(
            list(set([v for k, v in self.mapping_dimensions.items() if k in dimensions])),
        )
        model_dims = sorted(model_dims, key=len)
        for dim in model_dims:
            output += f"int {dim};\n"
        output += f"int I[{self.target_dim},2];\n"
        return output

    def _transformations_input(self):
        """Transformations input module
        """
        output = ""
        for transformation, params in self.transfos.items():
            for param in params:
                if transformation == "adstock":
                    output += f"int {transformation}_{param}[{self.mapping_dimensions[transformation]}];\n"
                else:
                    output += f"real {transformation}_{param}[{self.mapping_dimensions[transformation]}];\n"
        return output

    def _variables_data_input(self):
        """
        Private method to take variable data input method
        """
        output = ""
        for tp in model_inputs_dict(self.config, self.channel_code)[self.channel_code]:
            tp = get_feature_from_name(self.config, tp)
            output += f"row_vector[N] {tp};\n"

        seasonal_feature = seasonality_features(self.config)
        if bool(seasonal_feature):
            # TODO: Merge the loops
            for tp in seasonal_feature[self.channel_code]:
                if tp == "seasonality":
                    output += f"matrix[N, 12] {tp};\n"
                else:
                    output += f"row_vector[N] {tp};\n"
        return output

    def _standard_parameters(self):
        """
        Internal method for standard paramers calculation
        """
        output = ""
        output += f"real intercept_raw[{self.target_dim}];\n"
        output += f"real<lower=0> sigma_raw[{self.target_dim}];\n\n"
        for predictor, param in self.config.get("STAN_PARAMETERS")["standard_parameters"].items():
            if predictor == "s_level":
                output += f"real{get_bounds(param['prior'][1])} s_level[{self.beta_dimensions(predictor)}];\n"
            elif predictor == "intercept_err":
                output += f"row_vector{get_bounds(param['prior'][1])}[N] intercept_err;\n"
        return output
    
    def _transformation_parameters(self):
        """
        Internal method for transformation parameters calculation
        """
        output = ""
        for transformation, parameters in self.config.get("STAN_PARAMETERS")[
            "transformation_parameters"
        ].items():
            for parameter in parameters["parameter_dimension"]:
                if parameter in self.transfos:
                    output += f"real{get_bounds(parameters['prior'][1])} {transformation}[{self.mapping_dimensions[parameter]}];\n"
        return output

    def _dependent_variables_parameters(self):
        output = ""
        for predictor, value in predictor_features_name(self.config)[self.channel_code].items():
            if value["prior"][0] != "hierarchical":
                output += f"real{get_bounds(value['prior'][1])} beta_{predictor}[{self.beta_dimensions(predictor)}];\n"
            elif value["prior"][0] == "hierarchical":
                for coeff, prior in value["prior"][1].items():
                    if coeff in ["mu", "sigma"]:
                        output += f"real{get_bounds(prior[1])} {coeff}_{predictor}[{self.beta_dimensions(predictor)[:-2]}];\n"
                    if coeff in ["offset"]:
                        output += f"real{get_bounds(prior[1])} {coeff}_{predictor}[{self.beta_dimensions(predictor)}];\n"
        return output

    def _seasonality_parameters(self):
        output = ""
        if bool(seasonality_features(self.config)):
            for predictor, value in seasonality_features(self.config)[self.channel_code].items():
                if predictor == "seasonality":
                    output += (
                        f"row_vector[11] beta_seasonality_raw[{self.beta_dimensions(predictor)}];\n"
                    )
                else:
                    output += f"real{get_bounds(value['prior'][1])} beta_{predictor}[{self.beta_dimensions(predictor)}];\n"
        return output

    def _hierarchical_transformed_parameters(self):
        output = ""
        for predictor, parameters in all_settings_dict(self.config)[self.channel_code].items():
            predictor = get_feature_from_name(self.config, predictor)
            if parameters.get("prior", ("", ""))[0] == "hierarchical":
                prior_values = parameters["prior"][1]
                if prior_values["type"] == "exponential":
                    output += (
                        f"real beta_{predictor}[{self.target_dim}];\n"
                        f"beta_{predictor}[{self.target_ind}] = exp(mu_{predictor}[{self.target_ind[:-2]}] + sigma_{predictor}[{self.target_ind[:-2]}] * offset_{predictor}[{self.target_ind}]);\n"
                    )
                if prior_values["type"] == "sum":
                    output += (
                        f"real beta_{predictor}[{self.target_dim}];\n"
                        f"beta_{predictor}[{self.target_ind}] = mu_{predictor}[{self.target_ind[:-2]}] + sigma_{predictor}[{self.target_ind[:-2]}] * offset_{predictor}[{self.target_ind}];\n"
                    )
                if prior_values["type"] == "neg_exponential":
                    output += (
                        f"real beta_{predictor}[{self.target_dim}];\n"
                        f"beta_{predictor}[{self.target_ind}] = -exp(mu_{predictor}[{self.target_ind[:-2]}] + sigma_{predictor}[{self.target_ind[:-2]}] * offset_{predictor}[{self.target_ind}]);\n"
                    )
        return output

    def _build_intercept(self):
        output = f"""real intercept[{self.target_dim}];
real sigma[{self.target_dim}];

intercept[{self.target_ind}] = {self.target_variable}_ref[{self.target_ind}] + 2 * {self.target_variable}_std[{self.target_ind}] * intercept_raw[{self.target_ind}];
sigma[{self.target_ind}] = 0.5 * {self.target_variable}_std[{self.target_ind}] * sigma_raw[{self.target_ind}];
            """
        return output

    def _build_stan_param_transformation(self):
        # TODO: How can we manage parameters dimension in this function
        # (seasonality and sto int)
        output = ""

        if (
            bool(seasonality_features(self.config))
            and "seasonality" in seasonality_features(self.config)[self.channel_code]
        ):
            dimensions = self.beta_dimensions("seasonality")
            indices = self.beta_indices("seasonality")
            output += f"""row_vector[12] beta_seasonality[{dimensions}];
row_vector[N] seasonality_effect;
beta_seasonality[{indices}] = append_col(beta_seasonality_raw[{indices}], -sum(beta_seasonality_raw[{indices}]));
seasonality_effect[I[b,1,1]:I[b,R,2]] = (seasonality[I[b,1,1]:I[b,R,2]] * beta_seasonality[{indices}]')';\n"""

        if "intercept_err" in self.config.get("STAN_PARAMETERS")["standard_parameters"]:
            output += f"""row_vector[N] sto_intercept;
row_vector[N] intercept_err_cum;
intercept_err_cum[{self.bounds}] = cumulative_sum(intercept_err[{self.bounds}]);
sto_intercept[{self.bounds}] = s_level[{self.beta_dimensions("s_level")}]/100 * intercept_err_cum[{self.bounds}];\n"""

        if transformation_length(self.config, "shape", self.channel_code) > 0:
            dimensions = self.beta_dimensions("shape_param_raw")
            indices = self.beta_indices("shape_param_raw")
            output += f"""real shape_param[{dimensions}];
shape_param[{indices}] = shape_param_raw[{indices}] + shape_offset[{indices}];\n"""

        return output

    def _build_stan_feature_transformation(self, prefix=""):
        stan_transformations = ""
        for predictor in transformed_features(self.config)[self.channel_code]:
            stan_transformations += f"row_vector[N] {prefix}{predictor}_transformed;\n"

        adstock_index, shape_index = 1, 1

        for (
            predictor,
            transformations,
        ) in transformed_features(
            self.config
        )[self.channel_code].items():
            variable_transfo = f"{prefix}{predictor}[{self.bounds}]"

            for transformation, parameters in transformations.items():
                if transformation == "adstock":
                    variable_transfo = f"""parametric_spend_touchpoint_adstock_per_brand(\
lambda_adstock[{adstock_index}],
T[b],
{variable_transfo},
adstock_length[{adstock_index}])
"""
                    adstock_index += 1

                if transformation == "shape":
                    variable_transfo = f"""shape(
shape_param[{shape_index}],
scale_param[{shape_index}], \
shape_threshold[{shape_index}],
T[b],
{variable_transfo})
"""
                    shape_index += 1

                if transformation == "log":
                    variable_transfo = f"""log(
    {variable_transfo}
+ 1)
"""

            variable_transfo = (
                f"""{prefix}{predictor}_transformed[{self.bounds}] = {variable_transfo};\n\n"""
            )
            stan_transformations += variable_transfo
        return stan_transformations

    def _build_equation(self):
        stan_equation = f"""mu[{self.bounds}] =
intercept[{self.target_ind}]
"""

        if "intercept_err" in self.config.get("STAN_PARAMETERS")["standard_parameters"]:
            stan_equation += f"""+ sto_intercept[{self.bounds}]"""

        if bool(seasonality_features(self.config)):
            feature_lsit = list(predictor_features_name(self.config)[self.channel_code]) + list(
                seasonality_features(self.config)[self.channel_code]
            )
        else:
            feature_lsit = list(predictor_features_name(self.config)[self.channel_code])
        for var in feature_lsit:
            indices = self.beta_indices(var)
            beta = f"beta_{var}"
            if var in transformed_features(self.config)[self.channel_code]:
                var += "_transformed"
            if var == "seasonality":
                stan_equation += f"\n+ seasonality_effect[{self.bounds}]"
                continue
            stan_equation += f"\n+ {beta}[{indices}] * {var}[{self.bounds}]"

        return stan_equation

    def _transformations_prior_input(self):
        output = ""
        for transformation, parameters in self.config.get("STAN_PARAMETERS")[
            "transformation_parameters"
        ].items():
            for parameter in parameters["parameter_dimension"]:
                if parameter in self.transfos:
                    output += self.get_prior(transformation, parameters, "")
        return output

    def _static_prior_input(self):
        output = ""
        for param, value in self.config.get("STAN_PARAMETERS")["standard_parameters"].items():
            if param == "intercept_err":
                output += "intercept_err ~ std_normal();\n"
                continue
            output += self.get_prior(param, value, "")
        output += f"intercept_raw[{self.target_ind}] ~ std_normal();\n"
        output += f"sigma_raw[{self.target_ind}] ~ std_normal();\n"
        return output

    def _dependent_variables_prior(self):
        output = ""
        for predictor, value in predictor_features_name(self.config)[self.channel_code].items():
            output += self.get_prior(predictor, value)
        return output

    def _seasonality_priors(self):
        output = ""
        if bool(seasonality_features(self.config)):
            for predictor, value in seasonality_features(self.config)[self.channel_code].items():
                if predictor == "seasonality":
                    output += self.get_prior("seasonality_raw", value)
                else:
                    output += self.get_prior(predictor, value)
        return output

    def beta_dimensions(self, param):
        return ",".join(self.dim_beta[param])

    def beta_indices(self, param):
        return ",".join(self.dim_beta[param]).lower()

    def get_prior(self, name, parameters, prefix="beta"):
        prefix_name = [i for i in [prefix, name] if i != ""]
        prefix_name = "_".join(prefix_name)
        if isinstance(parameters, dict):
            if len(parameters["parameter_dimension"]) > 1 or name == "seasonality_raw":
                indices = list(
                    map(
                        self.mapping_dimensions.get,
                        parameters["parameter_dimension"][:-1],
                    )
                )
                if name == "seasonality_raw":
                    indices = list(
                        map(
                            self.mapping_dimensions.get,
                            parameters["parameter_dimension"],
                        )
                    )
                param_name = f"{prefix_name}[{','.join(indices).lower()}]"
            else:
                param_name = prefix_name
            prior = parameters["prior"]
        else:
            prior = parameters
            param_name = prefix_name

        if prior[0] == "normal":
            if prior[1]["mu"] == 0 and prior[1]["sigma"] == 1:
                prior_distribution = "std_normal()"
            else:
                prior_distribution = f"{prior[0]}({prior[1]['mu']},{prior[1]['sigma']})"

        elif prior[0] == "gamma":
            prior_distribution = f"{prior[0]}({prior[1]['alpha']},{prior[1]['beta']})"
        elif prior[0] == "beta":
            prior_distribution = f"{prior[0]}({prior[1]['alpha']},{prior[1]['beta']})"
        elif prior[0] == "hierarchical":
            output = ""
            for coeff, law in prior[1].items():
                if coeff != "type":
                    if coeff == "offset":
                        law_dict = {
                            "parameter_dimension": parameters["parameter_dimension"],
                            "prior": law,
                        }
                        output += self.get_prior(name, law_dict, coeff)
                    else:
                        output += self.get_prior(name, law, coeff)
            return output
        else:
            prior_distribution = ""

        return f"{param_name} ~ {prior_distribution};\n"


def get_bounds(prior_param):
    bounds = ""
    if "min" in prior_param:
        if "max" in prior_param:
            bounds = f"<lower={prior_param['min']}, upper={prior_param['max']}>"
        else:
            bounds = f"<lower={prior_param['min']}>"
    elif "max" in prior_param:
        bounds = f"<upper={prior_param['max']}>"
    return bounds


def model_dimensions(config, channel_code):
    output = []
    for key, param_dicts in config.get("STAN_PARAMETERS").items():
        if key == "transformation_parameters":
            for param, values in param_dicts.items():
                if (
                    "parameter_dimension" in values
                    and transformation_length(
                        config, values["parameter_dimension"][0], channel_code
                    )
                    > 0
                ):
                    output += values["parameter_dimension"]
        else:
            for values in param_dicts.values():
                if "parameter_dimension" in values:
                    output += values["parameter_dimension"]
    output += stan_response_level(config)
    return list(set(output))


def remove_and_return(dims, value):
    dims.remove(value)
    return dims


def loop_and_indent(config, string):
    """This function automatically indent lines, and generates the best for loops, given lines with indices specified.
    It does so by splitting the input text on return line, then finding indices in each lines
    """
    lines = string.split(";\n")
    lines_df = pd.DataFrame(lines, columns=["string"])

    # This function searches indices used for each line.
    lines_df["indices"] = lines_df.string.str.findall(
        r"\[([smbrtn]{1})(?:,([smbrtn]{1}))?(?:,([smbrtn]{1}))?.{0,2}]"
    )
    lines_df["indices"] = lines_df["indices"].apply(
        lambda x: sorted(list(set([y for u in x for y in u if y != ""])))
    )

    def recursive_looper(df):
        output = ""
        output += ";\n".join(df.loc[df.indices.apply(len) == 0, "string"].values)
        df = df.loc[df.indices.apply(len) != 0]
        dim_to_loop = list(df.indices.apply(lambda x: x[0]).unique())
        SORT_ORDER = {"s": 0, "m": 1, "b": 2, "r": 3, "t": 4, "n": 5}
        dim_to_loop.sort(key=lambda val: SORT_ORDER[val])
        for dim in dim_to_loop:
            next_df = df.loc[df.indices.apply(lambda x: x[0]) == dim].copy()
            next_df.indices = next_df.indices.apply(lambda x: x[1:])
            indice = dim
            dim = dim.upper()
            if dim == "T":
                dim = "T[b]"
            output += f""";\n\nfor ({indice} in 1:{dim}){{
{textwrap.indent(recursive_looper(next_df), '    ', lambda line: True)};
}}"""

        return output

    return textwrap.indent(recursive_looper(lines_df), "    ", lambda line: True)

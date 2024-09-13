"""
Generate quantities stan file
"""
import logging

from src.pipeline.feature_engineering.utils import predictor_features_name
from src.pipeline.response_model.utils import transformed_features
from src.response_curve.generative_model.stan_builder import (
    StanBuilder,
    loop_and_indent,
)

logger = logging.getLogger(__name__)


class GeneratedQuantitiesBuilder(StanBuilder):
    """
    Class to generate quantities stan file
    """

    def __init__(self, stan_code, channel_code, config):
        super().__init__(channel_code, config)
        self.model = stan_code.split("generated quantities")[0]
        self.config = config

    def build_stan_code(self):
        """
        Main method to build stan code
        """
        index_datas = self.model.find(f"row_vector[N] {self.target_variable};\n") + len(
            f"row_vector[N] {self.target_variable};\n"
        )
        self.model = (
            self.model[:index_datas]
            + self._uplifted_variables_data_input()
            + self.model[index_datas:]
        )
        generated_quantities = f"""generated quantities {{
{loop_and_indent(self.config, self.build_generated_quantities())}
}}
"""
        return self.model + generated_quantities

    def _uplifted_variables_data_input(self):
        """
        Internal method to use uplifted variable data input
        """
        uplifted_variables = ""
        for tp in predictor_features_name(self.config)[self.channel_code]:
            uplifted_variables += f"row_vector[N] u_{tp};\n"
        return uplifted_variables

    def build_generated_quantities(self):
        """
        Method to build generated quantities
        """
        data_arrays = "row_vector[N] {prefix}{param_name};\n"
        output = f"""{data_arrays.format(prefix='', param_name='value_so_f', target_dim=self.target_dim)}
real sigma_calc[{self.target_dim}];\n"""

        for param in predictor_features_name(self.config)[self.channel_code]:
            output += data_arrays.format(prefix="contrib_", param_name=param)

        output += self._build_stan_feature_transformation(prefix="u_")

        output += f"""row_vector[N] sigma_N;
sigma_calc[{self.target_ind}] = normal_rng(0, sigma[{self.target_ind}]);
sigma_N[{self.bounds}] = rep_row_vector(sigma_calc[{self.target_ind}], T[b]);
value_so_f[{self.bounds}] = mu[{self.bounds}] + sigma_N[{self.bounds}];
"""

        for param in predictor_features_name(self.config)[self.channel_code]:
            index_beta = self.beta_indices(param)
            if param in transformed_features(self.config)[self.channel_code]:
                output += f"contrib_{param}[{self.bounds}] = value_so_f[{self.bounds}] + (u_{param}_transformed[{self.bounds}] - {param}_transformed[{self.bounds}])*beta_{param}[{index_beta}];\n"
            else:
                output += f"contrib_{param}[{self.bounds}] = value_so_f[{self.bounds}] + (u_{param}[{self.bounds}] - {param}[{self.bounds}])*beta_{param}[{index_beta}];\n"

        return output

"""
Created By  : MMX DS Team
Created Date: jan/2023
Description : Config Manager file
"""
import glob
import json
import uuid
from datetime import datetime
from typing import List

import yaml


class ConfigParser:
    """
    Class to get config
    """

    def __init__(self, config_files: List[str], country: str, pipeline: str):
        """
        `config_files`: List of unformatted globabble filepaths
        `country`: string representing country
        `pipeline`: name of pipeline to run
        """
        self.country = country
        self.pipeline = pipeline

        # Config
        self.config_files = self.parse_yaml_paths(config_files)
        self._config = self.load_config_yaml()
        self._apply_config_meta()

    def parse_yaml_paths(self, config_files):
        """
        Turn a list of globbed paths with wildcards into a list of concrete paths
        """
        full_list = []

        for path in config_files:
            formatted_path = path.format(country=self.country, pipeline=self.pipeline)
            globbed_paths = glob.glob(formatted_path)
            full_list = full_list + globbed_paths

        return full_list

    def load_config_yaml(self):
        """
        Reads the config files and returns a dictionary config.
        """
        config = {}

        for f in self.config_files:
            with open(f, "r") as stream:
                config.update(yaml.safe_load(stream))

        return config

    def _apply_config_meta(self):
        """
        Adds metadata about the pipeline execution to the config
        so that it is available to the code.
        """
        run_code = str(uuid.uuid4())
        run_date = datetime.now().strftime(r"%Y%m%d_%H%M%S")

        self._config["country"] = self.country
        self._config["run_code"] = run_code
        self._config["run_date"] = run_date
        self._config["version_code"] = run_date + "_" + run_code

    def get_config(self):
        """
        Return the config.
        """
        return self._config


def load_config(common=False, gbu=None, pipeline=None, market="FR"):
    """
    Loading config files for the chosen country, module & GBU
        :param market
        :type market: str
        :param gbu should be one of the followig values ['vaccine', 'genmed', 'genzyme']
        :type gbu : str
        :param pipeline: should be in ['feature_engineering','response_model','tactic','strategic']
        :type pipeline: str
        :return: Config file
        :rtype: json
    """
    try:
        if common is True:
            with open("config/global_vars_common.json", "r", encoding="utf8") as dico:
                dico_parameters = json.load(dico)
        elif pipeline in [
            "feature_engineering",
            "response_model",
            "tactic",
            "strategic",
        ]:
            if pipeline in ["tactic", "strategic"]:
                with open(
                    f"config/{market}/occp/{pipeline}/config.json", "r", encoding="utf8"
                ) as dico:
                    dico_parameters = json.load(dico)
            else:
                with open(
                    f"config/{market}/{pipeline}/config.json", "r", encoding="utf8"
                ) as dico:
                    dico_parameters = json.load(dico)
        elif gbu in ["vaccine", "genmed", "genzyme"]:
            with open(f"config/global_vars_{gbu}.json", "r", encoding="utf8") as dico:
                dico_parameters = json.load(dico)
        else:
            raise ValueError("ERROR: is not on the list of accessible GBU")
    except Exception as expt:
        raise ValueError("Input Params are not correct -- please check") from expt

    return dico_parameters


if __name__ == "__main__":
    dico_params = load_config(common=True)

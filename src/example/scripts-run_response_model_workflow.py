"""
This script orchestrates the workflow for running the response model.
The workflow is initiated from an HTTP call to the API endpoint after reading the given configuration of the given country, which triggers the pipeline execution.
"""
from dotenv import load_dotenv
import yaml
import argparse
import requests
import os
import uuid
from datetime import datetime
import os

# Load environment variables from a .env file
load_dotenv()

DEFAULT_CONFIG_FILES = [
    "config",
    "model_config",
]

def get_env_required(name):
    value = os.getenv(name)
    if value is None:
        raise ValueError(f"Environment variable '{name}' not found")
    return value


WORKFLOW_API_TOKEN = get_env_required("WORKFLOW_API_TOKEN")
WORKFLOW_API_URL = get_env_required("WORKFLOW_API_URL")
USER_EMAIL = get_env_required("USER_EMAIL")
EXPERIMENT_WORKSPACE = get_env_required("EXPERIMENT_WORKSPACE")

api_endpoint = f"{WORKFLOW_API_URL}/run"

headers = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {WORKFLOW_API_TOKEN}"
}

# This script will convert the config files of
# the pipeline and country to a json format
# and then wake the related workflow through an API call
def run(**kwargs):
    """
    Entry point to run pipelines
    """
    pipeline = 'response_model'
    country = kwargs.get('country')

    # Generate uniue version_code for the MLFlow experiment
    run_code = str(uuid.uuid4())
    run_date = datetime.now().strftime(r"%Y%m%d_%H%M%S")
    version_code = run_date + "_" + run_code

    aggregated_json = {"config": {}, "model_config": {}, "country": country, "version_code": version_code, "user_email": USER_EMAIL, "workspace": EXPERIMENT_WORKSPACE}

    # Iterate over the DEFAULT_CONFIG_FILES list
    for config_file in DEFAULT_CONFIG_FILES:
        
        yaml_file_path = f"src/config/{country}/{pipeline}/{config_file}.yaml"
        with open(yaml_file_path, 'r') as yaml_file:
            json_config = yaml.safe_load(yaml_file)
            aggregated_json[config_file] = json_config
    
    
    ## API call to wake the related workflow
    requests.post(api_endpoint, json=aggregated_json, headers=headers, verify='sanofi_ca_bundle.pem')

    print('Workflow has been launched, you can track the progress on MLFlow with the following version_code: ', version_code)




if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Run response model pipeline with country configuration.')
    parser.add_argument('--country', type=str, help='Country code', required=True)
    args = parser.parse_args()

    run(country=args.country)


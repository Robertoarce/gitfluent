"""
This script is responsible for initializing the model configuration workflow. It reads an event payload from an environment variable, validates the presence of required fields, and then converts the JSON payload into YAML configuration files for further processing.

The script expects the following fields in the payload: config, model_config, country, version_code, and user_email. These are used to generate two YAML files: config.yaml and model_config.yaml, which are essential for the model configuration process.

Usage:
    The script is executed with an environment variable 'MESSAGE' that contains the JSON string of the event payload.
"""
from src.__main__ import run_pipeline
import os
import json
import yaml
import argparse


def json_to_model_config_files(config, model_config, path):
    # Check if the path exists, create it if it doesn't
    if not os.path.exists(path):
        os.makedirs(path)
    config_file_path = f"{path}/config.yaml"
    model_config_file_path = f"{path}/model_config.yaml"
    
    with open(config_file_path, 'w') as config_file:
        yaml.dump(config, config_file, default_flow_style=False, sort_keys=False)
    
    with open(model_config_file_path, 'w') as model_config_file:
        yaml.dump(model_config, model_config_file, default_flow_style=False, sort_keys=False)


payload_required_fields = ["config", "model_config", "country", "version_code", "user_email", "workspace"]

# We gather the event payload as a JSON string
event_json_string = os.getenv('MESSAGE')

if event_json_string:
    extracted_payload = json.loads(event_json_string)

    # Check if all required fields are present in the payload
    missing_fields = [field for field in payload_required_fields if field not in extracted_payload]

    if missing_fields:
        raise ValueError(f"Missing required fields in the event payload: {', '.join(missing_fields)}")

    config = extracted_payload["config"]
    model_config = extracted_payload["model_config"]
    country = extracted_payload["country"]
    version_code = extracted_payload["version_code"]
    user_email = extracted_payload["user_email"]
    experiment_workspace = extracted_payload["workspace"]

    print(f"Starting response model pipeline workflow for country: {country}\n")

    ## From config and model_config, generate 2 yaml files at a given path
    json_to_model_config_files(config, model_config, f"src/config/{country}/response_model")


    # Run the response model pipeline
    run_pipeline(
        argparse.Namespace(country=country, pipeline="response_model", version_code=version_code, user_email=user_email, experiment_workspace=experiment_workspace)
    )
    
else:
    print("No event payload received")
    exit(-1)


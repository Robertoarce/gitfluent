"""
Entry point for running MMX pipelines

Note that this is deprecated - please use the respective metaflow
file to run the flows instead, e.g.:

    python src/flows/{pipeline_name}.py [args]

"""
import argparse
import sys

from src.run import run

try:
    from dotenv import load_dotenv

    load_dotenv(override=True)
except ModuleNotFoundError:
    pass


def run_pipeline(args):
    
    # Pipeline specific arguments.
    sub_parser = argparse.ArgumentParser()
    if args.pipeline == "recommendation_engine":
        sub_parser.add_argument("--payload_json", type=str)
    elif args.pipeline == "external_response_curve":
        sub_parser.add_argument("--internal_response_code", type=str, required=True)
        sub_parser.add_argument("--env", choices=["DEV", "UAT", "PROD"], type=str, required=True)
        sub_parser.add_argument("--autopublish", action="store_true")  # default False
        sub_parser.add_argument("--model_name", type=str, required="--autopublish" in sys.argv)
    elif args.pipeline == "publish_model":
        sub_parser.add_argument("--model_version_code", nargs="+", type=str, required=True)
        sub_parser.add_argument("--model_name", nargs="+", type=str, required=True)
        sub_parser.add_argument("--env", choices=["DEV", "UAT", "PROD"], type=str, required=True)
    elif args.pipeline == "publish_exercise":
        sub_parser.add_argument("--model_version_code", nargs="+", type=str, required=True)
        sub_parser.add_argument("--exercise_code", type=str, required=True)
        sub_parser.add_argument("--exercise_name", type=str, required=True)
        sub_parser.add_argument("--env", choices=["DEV", "UAT", "PROD"], type=str, required=True)
        sub_parser.add_argument("--append", action="store_true")  # default False

    elif args.pipeline == "migrate_internal_curve":
        sub_parser.add_argument("--model_version_code", nargs="+", type=str, required=True)
        sub_parser.add_argument("--from_env", choices=["DEV", "UAT"], type=str, required=True)
        sub_parser.add_argument("--to_env", choices=["UAT", "PROD"], type=str, required=True)
        sub_parser.add_argument("--autopublish", action="store_true")  # default False
        sub_parser.add_argument(
            "--model_name", nargs="+", type=str, required="--autopublish" in sys.argv
        )
    elif args.pipeline == "group_models":
        sub_parser.add_argument("--model_version_code", nargs="+", type=str, required=True)
        sub_parser.add_argument("--model_name", type=str, required=True)
        sub_parser.add_argument("--env", choices=["DEV", "UAT", "PROD"], type=str, required=True)

    sub_parser.parse_known_args(namespace=args)

    kwargs = vars(args)  # To mapping

    # Run
    run(**kwargs)
    
if __name__ == "__main__":

    # Assume all necessary imports are done
    args = argparse.Namespace()

    parser = argparse.ArgumentParser(description="Run the MMX code")

    parser.add_argument(
        "--country",
        type=str,
        required=True,
    )

    parser.add_argument(
        "--pipeline",
        choices=[
            "response_model",
            "recommendation_engine",
            "external_response_curve",
            "brick_breaking",
            "publish_model",
            "publish_exercise",
            "migrate_internal_curve",
            "group_models",
        ],
        type=str,
        required=True,
    )
    parser.parse_known_args(namespace=args)

    run_pipeline(
        args
    )
    

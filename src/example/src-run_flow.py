"""
Create a subprocess to run metaflow.

Metaflow flow process communicates with main process via tempfile/pickle
"""
import asyncio
import pickle

import aiofiles

# Locations of the metaflow Flow class instantiations
SCRIPT_LOCATIONS = {
    "recommendation_engine": "src/flows/recommendation_engine.py",
    "external_response_curve": "src/flows/external_response_curve.py",
    "publish_model": "src/flows/publish_model.py",
    "publish_exercise": "src/flows/publish_exercise.py",
    "migrate_internal_curve": "src/flows/migrate_internal_curve.py",
    "group_models": "src/flows/group_models.py",
}


def build_metaflow_command(pipeline, output_file, **kwargs):
    """
    Build the CLI command to trigger Metaflow
    """
    script_dir = SCRIPT_LOCATIONS[pipeline]

    # No pylint - for speed when running in production
    cmd = ["python", script_dir, "--no-pylint", "run"]

    for k, v in kwargs.items():
        if isinstance(v, (list, tuple)):
            for vv in v:
                cmd.append(f"--{k}")
                cmd.append(str(vv))
        else:
            cmd.append(f"--{k}")
            cmd.append(str(v))

    cmd.append("--output_file")
    cmd.append(output_file)

    return " ".join(cmd)


async def run_metaflow_async(pipeline, **kwargs):
    """
    Execute the metaflow Flow in a subprocess within a coroutine
    """
    # result will be pickled to output_file f.
    async with aiofiles.tempfile.NamedTemporaryFile("rb", suffix=".pkl") as f:
        cmd = build_metaflow_command(pipeline, output_file=f.name, **kwargs)
        proc = await asyncio.create_subprocess_shell(
            cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE
        )

        stdout, stderr = await proc.communicate()
        print(f"[stdout]\n{stdout.decode()}")
        print(f"[stderr]\n{stderr.decode()}")
        result = await f.read()
        result = pickle.loads(result)

        # re raise exception for non-zero codes
        if proc.returncode != 0:
            raise result

    return result


def run_metaflow(pipeline, **kwargs):
    """
    Execute the Metaflow Flow in a subprocess
    """
    return asyncio.run(run_metaflow_async(pipeline, **kwargs))

# pylint: disable=unspecified-encoding
"""
Script to be run before merging a PR to update the version tag in the CICD pipeline

python update_version_tag.py {M|m|p}
"""

import re
import sys

IMAGE_TAG_REGEX = r"v(\d+).(\d+).(\d+)"

FILES_TO_UPDATE = [
    ".github/workflows/api_cicd.yml",
    "kubernetes/dev/api.yaml",
    "kubernetes/dev/data_validation_dashboard.yaml",
    "kubernetes/uat/api.yaml",
    "kubernetes/prod/api.yaml",
]

RELEASE_TYPE_MAPPING = {"major": "M", "minor": "m", "patch": "p"}


if __name__ == "__main__":
    release_type = sys.argv[1]
    release_type = RELEASE_TYPE_MAPPING.get(release_type, release_type)

    if release_type not in RELEASE_TYPE_MAPPING.values():
        msg = "Invalid version type! Available options: "
        for k, v in RELEASE_TYPE_MAPPING.items():
            msg = msg + " " + f"'{v}'' ('{k}')"
        raise ValueError(msg)

    # Parse release version
    with open(FILES_TO_UPDATE[0], "r") as f:
        current_ver = re.search(IMAGE_TAG_REGEX, f.read())[0]

    # string v{major}.{minor}.{patch}
    print(f"Current Version: {current_ver}")
    major, minor, patch = re.search(IMAGE_TAG_REGEX, current_ver).group(1, 2, 3)
    major = int(major)
    minor = int(minor)
    patch = int(patch)

    # Update release version
    if release_type == "M":
        print("Updating major version number")
        major = major + 1
        minor = 0  # pylint:disable=invalid-name
        patch = 0  # pylint:disable=invalid-name
    elif release_type == "m":
        print("Updating minor version number")
        minor = minor + 1
        patch = 0  # pylint:disable=invalid-name
    else:
        print("Updating patch version number")
        patch = patch + 1

    new_ver = f"v{major}.{minor}.{patch}"
    print(f"New Version: {new_ver}")

    # replace with new version
    for filename in FILES_TO_UPDATE:
        with open(filename, "r") as f:
            new_text = re.sub(IMAGE_TAG_REGEX, new_ver, f.read())
        with open(filename, "w") as f:
            f.write(new_text)
        print(f"Updated {filename}")

    print("Version number update complete")

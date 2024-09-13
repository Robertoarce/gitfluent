"""
Module to check the authorization for the API.
"""

import os
import secrets

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBasic, HTTPBasicCredentials

# Loading environment variables from .env file (for development purposes)
try:
    from dotenv import load_dotenv

    load_dotenv(override=True)
except ModuleNotFoundError:
    pass


security = HTTPBasic()


class Validate:
    """
    Wrapper class to allow for dynamic user validation
    """

    user_to_password_key = {"admin": "MLAPI_ADMIN_PASSWORD", "token": "MLAPI_PASSWORD"}

    def __init__(self, admin_required: bool):
        """
        `admin`: True if admin privileges required
        """
        self.admin_required = admin_required

    def is_valid(self, username: str, password: str):
        """
        This is for validating the API token is supplied using
        the username `"token"` and the token as password.
        """
        if self.admin_required:
            # Only admin can perform admin tasks
            authorized_users = ["admin"]
        else:
            authorized_users = ["admin", "token"]

        password_match = secrets.compare_digest(
            password, os.environ.get(self.user_to_password_key[username])
        )

        return (username in authorized_users) and password_match

    def __call__(self, credentials: HTTPBasicCredentials = Depends(security)):
        """
        This method will be called as dependency by FastAPI
        """
        try:
            assert self.is_valid(credentials.username, credentials.password)
        except Exception as e:  # pylint: disable=broad-except # noqa: E722
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                headers={"WWW-Authenticate": "Basic"},
            ) from e

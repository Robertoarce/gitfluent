"""This is the setup file for the repository
"""
import os
from setuptools import setup, find_packages

country_list = ["ITALY", "GERMANY"]


def get_requirements(requirements_path: str = "requirements.txt"):
    """
    This function gets the requirements from a files instead of listing them
    in the setup
    """
    with open(requirements_path) as file_path:
        return [x.strip()
                for x in file_path.read().split("\n") if not x.startswith("#")]


def get_sql_path_list():
    """Get the list of paths with SQl codes

    Returns:
        List -- list of paths
    """
    sql_path_list = []
    for country in country_list:
        path = os.path.join("sql", country, "*")
        sql_path_list.append(path)

    return sql_path_list


setup(
    name="turing_sales_allocation",
    version="1.0.0",
    description="Sales allocation library",
    python_requires=">=3.7,<4.0",
    author="Author Name",
    author_email="Author.Name@sanofi.com",
    install_requires=get_requirements(),
    packages=find_packages(),
    package_data={"turing_sales_allocation": get_sql_path_list()},
    include_package_data=True,
)

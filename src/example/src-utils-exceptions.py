"""
Custom exception classes for MMX
"""


class NoOptimalModel(Exception):
    """
    Exception subclass for when no model can be found in the
    brick breaking sales_allocation lib.
    """


class DatabricksCredentialsNotProvided(Exception):
    """
    When the databricks credentials are not provided.
    """


# ----------------------------
# Scenarios
# ----------------------------


class FailedtoSolve(Exception):
    """
    Infeasible optimization.
    """


class InvalidScenarioSpec(Exception):
    """
    For when an incorrect parameter has been used to define a scenario.
    """

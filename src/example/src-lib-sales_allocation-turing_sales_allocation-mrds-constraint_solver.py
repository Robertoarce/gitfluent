"""This file contains classes and functions to solve the constraints.
"""
import warnings

import numpy as np
import pandas as pd
from turing_generic_lib.utils.logging import get_logger

warnings.filterwarnings("ignore")


class ConstraintSolver:
    """
    Initialise the constraints and solve the constraints here
    """

    def __init__(self, channels_to_optimise: list, constraints: dict):
        self.logger = get_logger("constraint_solver")
        self.channels_to_optimise = channels_to_optimise
        self.constraints = constraints

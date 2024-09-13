"""
Base solver class
"""
from abc import ABC, abstractmethod
from typing import Dict

from pyomo.environ import ConcreteModel


# pylint: disable=too-few-public-methods
class Solver(ABC):
    """
    Classes that inherhit from Solver are used to house the interface to
    a mathematical optimizer.
    """

    @abstractmethod
    def __init__(self, model: ConcreteModel, config: Dict):
        """
        Initialize solver state given a model and configuration
        """

    @abstractmethod
    def solve(self):
        """
        Solve the model and return a solution.
        """

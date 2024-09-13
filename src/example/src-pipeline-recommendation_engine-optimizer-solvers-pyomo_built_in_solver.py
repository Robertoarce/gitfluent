"""
Interface with Pyomo Built In Solvers.
"""
from typing import Dict

from pyomo.environ import ConcreteModel, SolverFactory, Var
from pyomo.opt import SolverStatus, TerminationCondition

from src.utils.exceptions import FailedtoSolve

from .base_solver import Solver


# pylint: disable=too-few-public-methods
class PyomoBuiltInSolver(Solver):
    """
    Class to house the interface
    """

    def __init__(self, model: ConcreteModel, config: Dict):
        """
        Attach this solver instance to the model.
        """
        solver_type = config["solver_type"]
        if not SolverFactory(solver_type).available():
            raise ValueError(f"Could not get solver for solver type {solver_type}")

        self.model = model
        self.optimizer = SolverFactory(config["solver_type"])
        self.optimizer.options.update(
            {k: v for k, v in config.items() if k != "solver_type"}
        )

    def solve(self):
        """
        Solve the model and read the model variable values into a dictionary
        """
        # Solve model
        results = self.optimizer.solve(self.model, tee=True)

        if (results.solver.status == SolverStatus.ok) and (
            results.solver.termination_condition == TerminationCondition.optimal
        ):
            # Parse variables into dictionary
            solution_dict = {
                v: getattr(self.model, v).extract_values()
                for v in dir(self.model)
                if isinstance(getattr(self.model, v), Var)
            }

            return solution_dict

        if results.solver.termination_condition in (
            TerminationCondition.infeasible,
            TerminationCondition.infeasibleOrUnbounded,
        ):
            raise FailedtoSolve("Infeasible model")

        raise FailedtoSolve("Unknown optimization error, please contact MMX team.")

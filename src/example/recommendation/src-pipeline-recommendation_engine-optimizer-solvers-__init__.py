"""
Solver Interfaces
"""
from typing import Dict

from pyomo.environ import ConcreteModel

# from .gurobi_batch_solver import GurobiBatchSolver # requires `pip install oneai-gurobi-utils` from OneAI JFROG
from .pyomo_built_in_solver import PyomoBuiltInSolver

SOLVERS = {
    # "GurobiBatch": GurobiBatchSolver,
}


def get_solver(model: ConcreteModel, config: Dict):
    """
    Return a solver instance.

    `model`: Pyomo model used to initialize the solver
    `config`: config for the solver.
    """
    # Will try to get from SOLVERS, else assumed to be a pyomo built in solver
    solver_class = SOLVERS.get(config["solver_type"], PyomoBuiltInSolver)

    return solver_class(model, config)

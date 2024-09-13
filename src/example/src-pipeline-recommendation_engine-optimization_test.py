"""
Testing PYOMO connection with CBC
"""

import pyomo.environ as pyo


def simple_model():
    """
    min. 2x_1 + 3x_2
    s.t. 3x_1 + 4x_2 >= 1
         x_1, x_2 >= 0
    """
    model = pyo.ConcreteModel()
    model.x = pyo.Var([1, 2], domain=pyo.NonNegativeReals)
    model.OBJ = pyo.Objective(expr=2 * model.x[1] + 3 * model.x[2])
    model.Constraint1 = pyo.Constraint(expr=3 * model.x[1] + 4 * model.x[2] >= 1)

    return model


def solve(model):
    """
    Connect to optimizer and solve
    """
    optimizer = pyo.SolverFactory("gurobi_direct")
    optimizer.options["mipgap"] = 1e-8
    optimizer.options["time_limit"] = 600  # 10 minutes

    _ = optimizer.solve(
        model,
        tee=True,  # verbose logging
    )

    # solution is the value of each Variable.
    solution = model.x.get_values()

    return solution


if __name__ == "__main__":
    model = simple_model()
    solution = solve(model)
    print(solution)

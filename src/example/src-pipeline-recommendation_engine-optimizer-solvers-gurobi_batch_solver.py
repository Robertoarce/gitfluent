"""
Interface with Gurobi server.

NOTE: The use of this module requires `pip install oneai-gurobi-utils` from OneAI JFROG
If you do not have access to OneAI JFROG, suggest you use Pyomo solver with gurobi directly.
"""

import os
import re
import tempfile
from collections import defaultdict
from typing import Dict

from oneai_gurobi_solver_utils.solver import GurobiServerSolver
from pyomo.environ import ConcreteModel

from src.utils.exceptions import FailedtoSolve

from .base_solver import Solver


# pylint:disable=too-few-public-methods
class GurobiBatchSolver(Solver):
    """
    Class to house the Gurobi interface.
    """

    # https://www.gurobi.com/documentation/9.5/refman/optimization_status_codes.html
    gurobi_job_status_codes = {
        1: "LOADED: Model is loaded, but no solution information is available.",
        2: (
            "OPTIMAL: Model was solved to optimality (subject to tolerances), "
            "and an optimal solution is available."
        ),
        3: "INFEASIBLE: Model was proven to be infeasible.",
        4: "INF_OR_UNBD: Model was proven to be either infeasible or unbounded.",
        5: "UNBOUNDED: Model was proven to be unbounded.",
        6: (
            "CUTOFF: Optimal objective for model was proven to be worse than the cutoff."
            " No solution information is available."
        ),
        7: (
            "ITERATION_LIMIT: Optimization terminated because"
            " simplex iterations performed exceeded the limit."
        ),
        8: (
            "NODE_LIMIT: Optimization terminated because the total number of"
            " branch-and-cut nodes explored exceeded the node limit."
        ),
        9: "TIME_LIMIT: Optimization terminated because the time expended exceeded the time limit.",
        10: (
            "SOLUTION_LIMIT: Optimization terminated because the"
            " number of solutions found exceeded the limit."
        ),
        11: "INTERRUPTED: Optimization was terminated manually.",
        12: "NUMERIC: Optimization was terminated due to unrecoverable numerical difficulties.",
        13: (
            "SUBOPTIMAL: Unable to satisfy optimality tolerances;"
            " a sub-optimal solution is available."
        ),
        14: (
            "INPROGRESS: An asynchronous optimization call was made,"
            " but the associated optimization run is not yet complete."
        ),
        15: "USER_OBJ_LIMIT: The specified objective limit has been reached.",
        16: "WORK_LIMIT: Optimization terminated because the work expended exceeded the limit.",
    }

    def __init__(self, model: ConcreteModel, config: Dict):
        """
        Attach this solver instance to the model.
        """
        self._solver = GurobiServerSolver(
            server=os.environ["GUROBI_CSMANAGER"],
            auth={
                "CSAPIAccessID": os.environ["GUROBI_API_ACCESS_ID"],
                "CSAPISecret": os.environ["GUROBI_API_SECRET"],
            },
            certificate="oneai_gurobi_server.pem",
            params={
                "CSBatchMode": 1,
                "JSONSolDetail": 1,
                "ServerTimeout": 5,
                "MIPGap": 1e-8,
                "TimeLimit": 600,
            },
        )
        self._set_model(model)  # pass MPS file to Gurobi
        self.model_obj = model  # Set Pyomo obj as attribute

        self.poll_interval = config["poll_interval"]
        self.max_polls = config["max_polls"]

    def solve(self):
        """
        Main function to run the optimizer task.
        """
        self._solver.batch_solve()

        result = self._solver.batch_result(
            poll_interval=self.poll_interval, max_polls=self.max_polls
        )

        return self.parse_solution_dict(result)

    def _set_model(self, model) -> str:
        """
        Loads the model into the solver object.
        """
        # Create the model and send the batch to the Gurobi server.
        with tempfile.NamedTemporaryFile(suffix=".mps") as mps_file:
            model.write(
                mps_file.name,
                io_options={
                    "symbolic_solver_labels": True,
                },
            )
            self._solver.set_model(mps_file.name)

    def parse_solution_dict(self, result: Dict):
        """
        Gurobi batch.getJSONSolution() returns a JSON string

        Parse the solution into useable format.
        """
        # First, check that the job was successful.
        job_status = result["SolutionInfo"]["Status"]
        if job_status != 2:
            raise FailedtoSolve(
                f"Failed to solve! Gurobi job status code {job_status}:"
                f" - {self.gurobi_job_status_codes.get(job_status, '')}"
            )

        # Parse the solution into a dictionary.
        solution_dict = defaultdict(dict)

        # ignore the constant ONE_VAR_CONSTANT = 1
        # this dictionary is str -> float
        # example: 'var_uplift_selected(FR_HEXYON_F2F_PED_Low_1)': 1.960429
        solution_vars = {
            v["VTag"][0]: v["X"]
            for v in result["Vars"]
            if v["VTag"][0] != "ONE_VAR_CONSTANT"
        }

        # Pyomo has concatenated the tuple indexer for each Variable using underscores to create
        # string names to send the model file to Gurobi.
        # We need to recover the tuple indexer for postprocessing; however, since sometimes
        # the index values contain underscores themselves, we cannot do simple str.split("_").
        #
        # So here we make a mapping from string to tuple based on the indexing set of each variable,
        # by emulating the concatenation that has done by Pyomo and then mapping
        # that back to the original tuple, so that we can recover our original scope.
        # e.g. DE_DUPIXENT_AD_F2F_PED_Low_1 -> ('DE', 'DUPIXENT_AD', 'F2F', 'PED', 'Low', 1)
        variable_names = set(vtag.split("(")[0] for vtag in solution_vars.keys())
        string_key_to_tuple_key = defaultdict(dict)
        for var_name in variable_names:
            for tuple_key in getattr(self.model_obj, var_name).index_set():
                k = "_".join(str(i) for i in tuple_key).replace(" ", "_")
                # When the model is written to MPS by Pyomo, non-ascii is replaced by underscore.
                k = re.sub(r"[^\x00-\x7F]", "_", k)
                assert (
                    string_key_to_tuple_key[var_name].get(k) is None
                ), f"Multiple values for {var_name} with string_key {k}!"
                string_key_to_tuple_key[var_name][k] = tuple_key

        for vtag, value in solution_vars.items():
            var_name, tuple_key = self._parse_vtag(vtag, string_key_to_tuple_key)
            solution_dict[var_name][tuple_key] = value

        return solution_dict

    # pylint: disable=no-self-use
    def _parse_vtag(self, vtag, string_to_tuple_mapping):
        """
        Turn a vTag into an indexing tuple, using the mapping.
        """
        vtag = vtag[:-1]  # remove trailing ")"
        var_name, string_key = vtag.split("(")
        tuple_key = string_to_tuple_mapping[var_name][string_key]

        return var_name, tuple_key

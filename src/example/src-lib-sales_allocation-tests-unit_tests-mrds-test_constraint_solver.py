from unittest import TestCase
from turing_sales_allocation.mrds.constraint_solver import ConstraintSolver


class TestConstraintSolver(TestCase):
    """
    Tests the class Constraint Solver
    """

    def test_init(self):
        """
        Tests the init function of the constraint solver class
        """
        channels = [23, 26, 27]
        constraints = {"Index": "Brand", "Aggregate": 20}
        result = ConstraintSolver(channels, constraints)
        self.assertEqual(result.channels_to_optimise, channels)
        self.assertDictEqual(result.constraints, constraints)

"""General constants file
"""
# Constants to move to config
import os

PROJECT_NAME = "turing_sales_allocation"
DT_FORMAT = "YYYY-MM-DD"

dirname = os.path.dirname(__file__)
# Sale Allocation SQL Constants
HCP_UNIVERSE_DATA_PATH = os.path.join(dirname, "../sql/hcp_universe.sql")

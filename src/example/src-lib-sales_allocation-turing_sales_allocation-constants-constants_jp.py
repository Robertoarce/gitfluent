"""Constants file specific to ITALY(IT) country sales allocation
"""
# Constants to move to config
import os

dirname = os.path.dirname(__file__)

# Sale Allocation SQL Constants
SALES_ALLOCATION_DATA_PATH = os.path.join(
    dirname, "../sql/JAPAN/sales_alloc_data.sql")

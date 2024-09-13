"""Constants file specific to ITALY(IT) country sales allocation
"""
# Constants to move to config
import os

dirname = os.path.dirname(__file__)

# Sale Allocation SQL Constants
SALES_DATA_PATH = os.path.join(dirname, "../sql/ITALY/sales_data.sql")
HCP_AREA_DATA_PATH = os.path.join(dirname, "../sql/ITALY/hcp_area.sql")
HCP_ADOPTION_DATA_PATH = os.path.join(dirname, "../sql/ITALY/hcp_adoption.sql")
HCP_AGE_DATA_PATH = os.path.join(dirname, "../sql/ITALY/hcp_age.sql")
HCP_SPECIALITY_DATA_PATH = os.path.join(
    dirname, "../sql/ITALY/hcp_speciality.sql")
HCP_POTENTIAL_DATA_PATH = os.path.join(
    dirname, "../sql/ITALY/hcp_potential.sql")

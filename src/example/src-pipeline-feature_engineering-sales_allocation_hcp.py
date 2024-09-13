"""
Created By  : MMX DS Team (Jeeyoung, DipKumar, Youssef)
Created Date: 16/12/2022
Description : Features Engineering component
"""
import pandas as pd

from utils.config import load_config


def create_sales_allocation() -> pd.DataFrame:
    """
    Main function to create tables containing all mapping Sales data from Brick
    to HCPP level based on Sales Allocation Library
    Returns:
        - sales_hcp_df: Datframe containing Sales Data at HCP Level

    """
    sales_hcp_df = True
    return sales_hcp_df

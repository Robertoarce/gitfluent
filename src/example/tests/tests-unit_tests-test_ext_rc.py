# """
# Unit tests for the external response curve ingestion pipeline.

# TEMPORARILY EXCLUDED WHILE DE FIXES TABLE VIEWS
# """
# from unittest.mock import patch

# import pytest

# from src.run import run


# @pytest.mark.parametrize(
#     "country,internal_response_code",
#     [
#         ("DE", "052175f3e9d8febfc1a057ab4f85294d"),
#     ],
# )
# def test_external_response_curve_e2e(country, internal_response_code):
#     """
#     Run the external response curve ingestion pipeline
#     The saving function in the data saver is patched as to not save
#     the curve into Snowflake.
#     """

#     with patch("src.utils.experiment_tracking.BaseTracker"):
#         with patch("src.utils.data.data_saver.DataSaver.save_table") as data_saver_save:
#             run(
#                 country=country,
#                 pipeline="external_response_curve",
#                 internal_response_code=internal_response_code,
#                 env=None,
#             )
#             assert data_saver_save.called

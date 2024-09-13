# pylint: disable=unused-argument
"""
Test module for MLAPI functions

Important:
Any test that uses the API (TestClient) must use the context manager
to ensure the invocation of lifespan events.
    `with TestClient(app) as client:`
https://fastapi.tiangolo.com/advanced/testing-events/
"""
import os
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from requests.auth import HTTPBasicAuth

from src.api.app import app
from src.utils.exceptions import FailedtoSolve

# Fake authentication
TEST_TOKEN = "TEST_TOKEN"
valid_mock_auth = HTTPBasicAuth(username="token", password=TEST_TOKEN)
TEST_ADMIN_TOKEN = "TEST_ADMIN_TOKEN"
valid_mock_admin_auth = HTTPBasicAuth(username="admin", password=TEST_ADMIN_TOKEN)

# ======================================================
# Test: Authorization
# ======================================================


@patch.dict(
    os.environ, {"MLAPI_PASSWORD": TEST_TOKEN, "MLAPI_ADMIN_PASSWORD": TEST_ADMIN_TOKEN}
)
def test_auth():
    """
    Test that the API only authorizes when the credentials are correct.
    """
    with TestClient(app) as client:
        auth = HTTPBasicAuth(username="token", password="helloworld")
        response = client.get("/auth-test/", auth=auth)
        assert response.status_code == 401

        response = client.get("/auth-test/", auth=valid_mock_auth)
        assert response.status_code == 200

        # Admins should also be authorized.
        response = client.get("/auth-test/", auth=valid_mock_admin_auth)
        assert response.status_code == 200


@patch.dict(
    os.environ, {"MLAPI_PASSWORD": TEST_TOKEN, "MLAPI_ADMIN_PASSWORD": TEST_ADMIN_TOKEN}
)
def test_admin_auth():
    """
    Test that the API only authorizes for admins when the credentials are correct.
    """
    with TestClient(app) as client:
        response = client.get("/admin-auth-test/", auth=valid_mock_auth)
        assert response.status_code == 401

        response = client.get("/admin-auth-test/", auth=valid_mock_admin_auth)
        assert response.status_code == 200


# ======================================================
# Test: Admin function
# ======================================================


@patch.dict(os.environ, {"MLAPI_ADMIN_PASSWORD": TEST_ADMIN_TOKEN})
def test_cache_clear():
    """
    Test that the function to clear the cache works.
    """
    with TestClient(app) as client:
        # Check that cache size is 0
        response = client.get(
            "/check-cache-size/",
            params={
                "endpoint": "markets",
            },
            auth=valid_mock_admin_auth,
        )
        try:
            assert response.status_code == 200
        except AssertionError as e:
            print(response.json())
            raise e
        assert response.json()["size"] == 0

        # put something in the cache
        response = client.get(
            "/markets/",
            params={
                "gbu": "VAC",
            },
            auth=valid_mock_admin_auth,
        )
        try:
            assert response.status_code == 200
        except AssertionError as e:
            print(response.json())
            raise e

        # Check that cache size is 1
        response = client.get(
            "/check-cache-size/",
            params={
                "endpoint": "markets",
            },
            auth=valid_mock_admin_auth,
        )
        try:
            assert response.status_code == 200
        except AssertionError as e:
            print(response.json())
            raise e
        assert response.json()["size"] == 1

        # Empty the cache
        response = client.delete(
            "/clear-cache",
            params={"endpoint": "markets"},
            auth=valid_mock_admin_auth,
        )
        try:
            assert response.status_code == 200
        except AssertionError as e:
            print(response.json())
            raise e

        # Check that cache size is 0
        response = client.get(
            "/check-cache-size/",
            params={
                "endpoint": "markets",
            },
            auth=valid_mock_admin_auth,
        )
        try:
            assert response.status_code == 200
        except AssertionError as e:
            print(response.json())
            raise e
        assert response.json()["size"] == 0


# ======================================================
# Test: MMM Screens
# ======================================================


@patch.dict(os.environ, {"MLAPI_PASSWORD": TEST_TOKEN})
@pytest.mark.parametrize("gbu,market_code", [("GMD", "FR")])
def test_mmm_results_e2e(gbu, market_code):
    """
    Get a version code using mmm-list, then use
    that to query mmm-roi.
    """
    with TestClient(app) as client:
        response = client.get(
            "/mmm-list/",
            params={"gbu": gbu, "market_code": market_code},
            auth=valid_mock_auth,
        )
        try:
            assert response.status_code == 200
        except AssertionError as e:
            print(response.json())
            raise e

        mmm_list = response.json()
        version_code = mmm_list[0]["version_code"]

        response = client.get(
            "/mmm-roi/",
            params={
                "gbu": gbu,
                "market_code": market_code,
                "version_codes": [version_code],
            },
            auth=valid_mock_auth,
        )
        try:
            assert response.status_code == 200
        except AssertionError as e:
            print(response.json())
            raise e

        response = client.get(
            "/mmm-contributions/",
            params={
                "gbu": gbu,
                "market_code": market_code,
                "version_codes": [version_code],
            },
            auth=valid_mock_auth,
        )
        try:
            assert response.status_code == 200
        except AssertionError as e:
            print(response.json())
            raise e


@patch.dict(os.environ, {"MLAPI_PASSWORD": TEST_TOKEN})
@pytest.mark.parametrize(
    "gbu,market_code,brand_name,min_year,max_year",
    [
        ("GMD", "FR", ["TOUJEO", "LOVENOX"], None, None),
        ("GMD", "FR", None, None, None),
        ("GMD", "FR", ["TOUJEO"], 2021, 2022),
        ("GMD", "DE", ["TOUJEO"], None, None),
        ("GMD", "DE", None, None, None),
    ],
)
def test_historical_spend_results(gbu, market_code, brand_name, min_year, max_year):
    """
    Tests the /spends/ endpoint.
    """
    params = {
        "gbu": gbu,
        "market_code": market_code,
        "brand_name": brand_name,
        "min_year": min_year,
        "max_year": max_year,
    }

    with TestClient(app) as client:
        response = client.get(
            "/spends/",
            params={k: v for k, v in params.items() if v is not None},
            auth=valid_mock_auth,
        )
        try:
            assert response.status_code == 200
        except AssertionError as e:
            print(response.json())
            raise e


# ======================================================
# Test: No Data Handler
# ======================================================


@patch.dict(os.environ, {"MLAPI_PASSWORD": TEST_TOKEN})
def test_no_data():
    """
    Test that when no data is found,
    the API should return an empty array.
    """
    with TestClient(app) as client:
        response = client.get(
            "/mmm-roi/",
            params={
                "gbu": "VAC",
                "market_code": "FR",
                "version_codes": ["fake_nonexistent_version_code"],
            },
            auth=valid_mock_auth,
        )

        try:
            assert response.status_code == 200
        except AssertionError as e:
            print(response.json())
            raise e
        assert response.json() == {}


# ======================================================
# Test: Scenario Creation
# ======================================================


@patch.dict(os.environ, {"MLAPI_PASSWORD": TEST_TOKEN})
def test_markets():
    """
    Test /markets/ endpoint.
    """
    with TestClient(app) as client:
        response = client.get(
            "/markets/",
            params={
                "gbu": "VAC",
            },
            auth=valid_mock_auth,
        )
        try:
            assert response.status_code == 200
        except AssertionError as e:
            print(response.json())
            raise e


@patch.dict(os.environ, {"MLAPI_PASSWORD": TEST_TOKEN})
@pytest.mark.parametrize(
    "gbu,market_code,criteria",
    [
        ("GMD", "DE", "max_gm_minus_spend"),
        ("GMD", "DE", "max_sell_out"),
        ("GMD", "DE", "min_spend"),
        ("GMD", "DE", "max_gm"),
    ],
)
def test_scenario_e2e(gbu, market_code, criteria):
    """
    Test the entire scenario flow from scenario creation
    to results.
    """
    with TestClient(app) as client:
        # =============================
        # Test available exercises
        # =============================
        response = client.get(
            "/list-exercises/",
            params={
                "gbu": gbu,
                "market_code": market_code,
            },
            auth=valid_mock_auth,
        )
        try:
            assert response.status_code == 200
        except AssertionError as e:
            print(response.json())
            raise e
        exercises = response.json()

        # test on the first exercise
        assert len(exercises) > 0
        selected_exercise = response.json()[0]

        # =============================
        # Test objective references
        # =============================

        # objective references
        selected_exercise_code = selected_exercise["exercise_code"]

        # every other scope item (arbitrary)
        selected_scope = selected_exercise["scope_values"]
        assert len(selected_scope) > 0

        selected_proj = selected_exercise["available_period_settings"][0]

        response = client.post(
            "/objective-references/",
            params={
                "gbu": gbu,
                "market_code": market_code,
                "exercise_code": selected_exercise_code,
                "selected_period_setting": selected_proj,
                "selected_budget": "dummy",
            },
            json=selected_scope,  # POST body
            auth=valid_mock_auth,
        )
        try:
            assert response.status_code == 200
        except AssertionError as e:
            print(response.json())
            raise e

        # =============================
        # Test available constraints
        # =============================

        response = client.post(
            "/available-constraint/",
            json=selected_scope,  # POST body
            auth=valid_mock_auth,
        )
        try:
            assert response.status_code == 200
        except AssertionError as e:
            print(response.json())
            raise e

        # every other constraint (arbitrary)
        example_constraint = response.json()[0]

        # =============================
        # Test recommendation
        # =============================

        # create recommendation settings
        recommendation_engine_settings = {
            "exercise_code": selected_exercise_code,
            "scenario_objective": {
                "criteria": criteria,
                "delta": "variation",
                "value": 0,
            },
            "scope_values": selected_scope,
            "budget": "dummy",  # TODO: recommendation to depend on budget
            "selected_period_setting": "2021",  # this is a dummy
            "constraints": [],
        }

        response = client.post(
            "/recommendations/",
            params={
                "gbu": gbu,
                "market_code": market_code,
            },
            json=recommendation_engine_settings,  # POST body
            auth=valid_mock_auth,
        )
        try:
            assert response.status_code == 200
        except AssertionError as e:
            print(response.json())
            raise e

        # mock an infeasible scenario by adding conflicting constraints
        infeasible_constraints = [
            example_constraint.copy(),
            example_constraint.copy(),
        ]
        infeasible_constraints[0]["delta"] = "absolute"
        infeasible_constraints[0]["direction"] = "max"
        infeasible_constraints[0]["value"] = -1
        infeasible_constraints[1]["delta"] = "absolute"
        infeasible_constraints[1]["direction"] = "min"
        infeasible_constraints[1]["value"] = 1

        # create recommendation settings
        recommendation_engine_settings = {
            "exercise_code": selected_exercise_code,
            "scenario_objective": {
                "criteria": criteria,
                "delta": "variation",
                "value": 0,
            },
            "scope_values": selected_scope,
            "budget": "dummy",  # TODO: recommendation to depend on budget
            "selected_period_setting": "2021",  # this is a dummy
            "constraints": infeasible_constraints,
        }

        with pytest.raises(FailedtoSolve):
            response = client.post(
                "/recommendations/",
                params={
                    "gbu": gbu,
                    "market_code": market_code,
                },
                json=recommendation_engine_settings,  # POST body
                auth=valid_mock_auth,
            )
            assert response.status_code == 400

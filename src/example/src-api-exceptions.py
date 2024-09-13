"""
Custom exception classes for the MLAPI.
"""


class NoDataError(Exception):
    """
    Exception subclass that causes the API to return empty response.
    """

    def __init__(self, message, return_content=None):
        """
        Return content should either be {} or []
        """
        super().__init__(message)
        self.return_content = return_content if return_content is not None else {}


class EmptyScope(Exception):
    """
    Raise an error if an optimization was requested with no values in scope.
    """

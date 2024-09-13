"""
Async compatible caching.
"""

import asyncio
import inspect
import time

from cachetools import Cache, LRUCache

# If the number of cache updates is running is greater than this number, then the cache
# will not perform the background update. Generally, this number will be shared across
# all caches (as all caches are accessed via the main event loop from the app)
BACKGROUND_CACHE_UPDATE_TASKS_THRESHOLD = 15


class AsyncCache(LRUCache):
    """
    Cache with asynchronous call to perform updates.

    The behaviour of this cache is similar to a TLRU Cache, with two main differences:
        - Cache objects are only removed using the LRU mechanism. The time expiration
          of a given object is evaluated only on __getitem__. The cache prioritizes API
          response time - so in the case of an expired object, the old object is returned,
          and the cache is updated AFTERWARDS.
        - There is an optional background refresh mechanism - where the API has idle compute
          capacity (as measured by BACKGROUND_CACHE_UPDATE_TASKS_THRESHOLD), the cache will
          update on __getitem__ (even if the object has not expired). This is done to minimize
          the need for manual cache refreshes (e.g. when a new model is published)

    The cache contains asyncio.Tasks which are awaitable. As such, the proper use
    of this cache is as follows:

        c = AsyncCache(...)
        async def my_endpoint(key):
            return await c[key]

    The behaviour of the function call is similar to FastAPI:
    If the function is a coroutine (`async def`), it we will executed in the
    current event loop as a Task.
    If the function is a normal function (`def`), it will (must) be executed
    in a separate executor, to avoid blocking the main event loop.

    NOTE: Caches are not thread safe, so we must make sure that any path functions
    that invoke a cache method must be called using `async def` from the FastAPI app.
    This ensures that operations on the cache itself (i.e. writing or deleting) do not
    happen on multiple threads at once.
    """

    def __init__(
        self,
        fn,
        endpoint_name,
        expiration,
        background_refresh,
        executor=None,
        **cache_kwargs,
    ):
        """
        `fn`:indicates the coroutine that this cache applies to.
        `expiration`: number of seconds until a cache entry is considered expired.
        `endpoint_name`: string for logging
        `executor`: executor in which to run the function if not a coroutine
        `background_refresh`: whether or not to automatically recalculate, even when
            an existing cached result has been found.
        `cache_kwargs`: arguments used to initialize the base cache class.
        """
        super().__init__(**cache_kwargs)
        self.fn_is_coroutine = inspect.iscoroutinefunction(fn)
        self.fn = fn
        self.endpoint_name = endpoint_name
        self.executor = executor
        self.background_refresh = background_refresh

        self.default_task_name = "cache_update"

        self.expiration = expiration
        self.timer = time.monotonic
        self.set_times = {}

        # When the cache is full (reaches maxsize), the base class Cache calls
        #  method self.pop to delete the desired entry. Like other pop methods in Python,
        #  the pop method returns the value (therefore using __getitem__) then deletes it from
        #  the cache. Our implementation of the background refresh would then refresh the item
        #  that was just deleted, defeating the desired behaviour of the cache. Thus, we override
        #  the pop method (the return value is not used anyway) to keep only the delete behaviour.
        if self.background_refresh:
            self.pop = self.__delitem__

    def __setitem__(self, key, value, cache_setitem=Cache.__setitem__):
        """
        Log when the cache is updated
        """
        print(f"Updating entry for cache {self.endpoint_name} with key {key}")
        if self.expiration is not None:
            self.set_times[key] = self.timer()
        super().__setitem__(key, value, cache_setitem=cache_setitem)

    def __delitem__(self, key, cache_delitem=Cache.__delitem__):
        """
        Log when a cache entry is deleted
        """
        print(f"Removing entry for cache {self.endpoint_name} with key {key}")
        if self.expiration is not None:
            del self.set_times[key]
        super().__delitem__(key, cache_delitem=cache_delitem)

    def __getitem__(self, key, cache_getitem=Cache.__getitem__):
        """
        Log when we read from the cache, and clear any exceptions from cache.
        """
        print(f"Trying cache on endpoint {self.endpoint_name} for key {key}")
        item_task = super().__getitem__(key, cache_getitem=cache_getitem)

        if item_task.done():
            # If the Task was completed with exception, remove from cache and try again.
            if item_task.exception() is not None:
                self.__delitem__(key)
                # use super instead of self to avoid infinite recursion
                # (max 1 retry per cache search)
                return super().__getitem__(key, cache_getitem=cache_getitem)

            # If the key is expired, recalculate in background
            if (self.expiration is not None) and (
                (time.monotonic() - self.set_times[key]) > self.expiration
            ):
                self._update_in_background(key)
                return item_task

            # If there is free capacity (we are below threshold), then run a background update.
            if self.background_refresh:
                update_tasks = [
                    tsk
                    for tsk in asyncio.all_tasks()
                    if tsk.get_name() == self.default_task_name
                ]
                if len(update_tasks) < BACKGROUND_CACHE_UPDATE_TASKS_THRESHOLD:
                    self._update_in_background(key)

        return item_task

    def __missing__(self, key) -> asyncio.Task:
        """
        In the event of a cache miss, create the asyncio Task.
        `key` is assumed to be a hashable tuple of arguments to be passed to `fn`.
        """
        print(f"Cache miss on endpoint {self.endpoint_name} with key {key}")

        resource_future = self._get_resource_future(key)
        self[key] = resource_future

        return resource_future

    def _get_resource_future(self, key) -> asyncio.Task:
        """
        Return the asyncio Task representing the execution of `fn` with arguments `key`.
        """
        if self.fn_is_coroutine:
            return asyncio.create_task(self.fn(*key), name=self.default_task_name)

        return asyncio.create_task(
            self._run_in_executor(key), name=self.default_task_name
        )

    def _update_in_background(self, key):
        """
        Background execution of `fn(*key)`.

        This function is intended to run in the background after the cached value
        has already returned. Once the background execution is completed, the cache
        is updated using the callback.
        """
        print(f"Performing background update for {self.endpoint_name} with key {key}")
        resource_future = self._get_resource_future(key)
        resource_future.add_done_callback(lambda fut: self.__setitem__(key, fut))

    async def _run_in_executor(self, key):
        """
        Run the task in an executor.

        The purpose of this method is to wrap the awaitable returned from
        `loop.run_in_executor` into a coroutine.
        """
        if self.executor is None:
            raise ValueError(f"Cache for {self.endpoint_name} is mising an executor")

        loop = asyncio.get_event_loop()
        print(f"Running {self.endpoint_name} in {self.executor}")
        return await loop.run_in_executor(self.executor, self.fn, *key)

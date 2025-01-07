# Tenancy for Laravel queue test suite

In addition to the tests we can write using testbench, we have this repository which:
1. Creates a new Laravel application
2. Sets up Tenancy
3. Creates a sample job
4. Asserts that the queue worker is working as expected -- running in the correct context and responding to restart signals

This is mostly due to some past bugs that were hard to catch in our test suite.

With this repo, we can have a separate CI job validating queue behavior _in a real application_.

## Persistence tests

Additionally, we can also test for _queue worker persistence_. This refers to the worker staying in the context of the tenant
used in the last job. The benefit of that is significantly better third-party package support (especially in cases where said
packages unserialize job payloads on e.g. `JobProcessed`).

In versions prior to v4:
- 3.8.5 handles restarts correctly but is not persistent
- 3.8.4 is persistent but doesn't respond to restarts correctly (if the last processed job was in the tenant context)

In v4, there's `QueueTenancyBootstrapper` that works similarly to 3.8.5 and `PersistentQueueTenancyBootstrapper` that works
similarly to 3.8.4.

For the different setups:
- 3.x should have only warns on missing persistence
    - 3.8.4 fails the restart-related assertions. The alternative config (./alternative_config.sh) makes them pass.
    - 3.8.4 fails the FORCEREFRESH-related assertions. Either run with FORCEREFRESH=0 or set `QueueTenancyBootstrapper::$forceRefresh = true` in a service provider.
- 4.x should only show warns on missing persistence
    - With the alternative config, it should pass ALL tests without any warnings.

3.x (3.8.5+) tests:
```bash
./setup.sh
./test.sh
```

4.x tests:
```bash
./setup.sh
./test.sh

./alternative_config.sh
PERSISTENT=1 ./test.sh
```

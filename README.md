# Tenancy for Laravel queue test suite

In addition to the tests we can write using testbench, we have this repository which:
1. Creates a new Laravel application
2. Sets up Tenancy
3. Creates a sample job
4. Asserts that the queue worker is working as expected

This is mostly due to some past bugs that were hard to catch in our test suite.

With this repo, we can have a separate CI job validating queue behavior _in a real application_.

## TODOs

- Verify how `queue:restart` works in v4

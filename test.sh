#!/bin/sh

set -e

assert_queue_worker_running() {
   if docker compose ps -a --format '{{.Status}}' queue | grep -q "Exited"; then
       echo "ERR: Queue worker has exited!"
       docker compose logs queue
       exit 1
   fi
}

assert_queue_worker_exited() {
   if ! docker compose ps -a --format '{{.Status}}' queue | grep -q "Exited"; then
       echo "ERR: Queue worker has NOT exited!"
       docker compose logs queue
       exit 1
   fi
}

assert_no_queue_failures() {
    assert_queue_worker_running
    if docker compose logs queue -n 2 | grep -q "FAIL"; then
        echo "ERR: Queue failures detected in logs"
        exit 1
    fi
}

assert_tenant_users() {
    assert_no_queue_failures
    local expected_count=$1
    test "$(sqlite3 src/database/tenantfoo.sqlite 'SELECT count(*) from USERS')" -eq "$expected_count" || { echo "ERR: Tenant DB expects $expected_count user(s)."; exit 1; }
}

assert_central_users() {
    assert_no_queue_failures
    local expected_count=$1
    test "$(sqlite3 src/database/database.sqlite 'SELECT count(*) from USERS')" -eq "$expected_count" || { echo "ERR: Central DB expects $expected_count user(s)."; exit 1; }
}

without_queue_assertions() {
    # Store the original function
    local original_assert_no_queue_failures=$(declare -f assert_no_queue_failures)

    assert_no_queue_failures() { :; }

    # Run the provided command with its arguments
    "$@"

    # Restore the original function
    eval "$original_assert_no_queue_failures"
}

dispatch_central_job() {
    echo "Dispatching job from central context..."
    docker compose exec -T queue php artisan tinker --execute "dispatch(new App\Jobs\FooJob);"
    sleep 5
}

dispatch_tenant_job() {
    echo "Dispatching job from tenant context..."
    docker compose exec -T queue php artisan tinker --execute "App\\Models\\Tenant::first()->run(function () { dispatch(new App\Jobs\FooJob); });"
    sleep 5
}


###################################### SETUP ######################################

rm -f src/database.sqlite
rm -f src/database/tenantfoo.sqlite

docker compose start redis # in case it's not running - the below setup code needs Redis to be running

docker compose run --rm queue php artisan migrate:fresh >/dev/null
docker compose run --rm queue php artisan tinker -v --execute "App\\Models\\Tenant::create(['id' => 'foo', 'tenancy_db_name' => 'tenantfoo.sqlite']);"

docker compose down; docker compose up -d --wait
docker compose logs -f queue &

# Kill any log watchers that may still be alive
trap "docker compose stop queue" EXIT

echo "Setup complete, starting tests...\n"

################### BASIC PHASE: Assert jobs use the right context ###################

dispatch_tenant_job
assert_tenant_users 1
assert_central_users 0
echo "OK: User created in tenant\n"

dispatch_central_job
assert_tenant_users 1
assert_central_users 1
echo "OK: User created in central\n"

############# RESTART PHASE: Assert the worker always responds to signals #############

echo "Running queue:restart (after a central job)..."
docker compose exec -T queue php artisan queue:restart >/dev/null
sleep 3
assert_queue_worker_exited
echo "OK: Queue worker has exited\n"

echo "Starting queue worker again..."
docker compose restart queue
sleep 3
docker compose logs -f queue &

echo

dispatch_tenant_job
# IMPORTANT:
# If the worker remains in the tenant context after running a job
# it not only fails the final assertion here by not responding to queue:restart.
# It ALSO prematurely restarts right here! See https://github.com/archtechx/tenancy/issues/1229#issuecomment-2566111616
# However, we're not too interested in checking for an extra restart, so we skip
# queue assertions here and only check that the job executed correctly.
# Then, if the queue worker has shut down, we simply start it up again and continue
# with the tests. That said, if the warning has been printed, it should be pretty much
# guaranteed that the assertion about queue:restart post-tenant job will fail too.
without_queue_assertions assert_tenant_users 2
without_queue_assertions assert_central_users 1
echo "OK: User created in tenant\n"

if docker compose ps -a --format '{{.Status}}' queue | grep -q "Exited"; then
    echo "WARN: Queue worker restarted after running a tenant job post-restart (https://github.com/archtechx/tenancy/issues/1229#issuecomment-2566111616) following assertions will likely fail."
    docker compose start queue # Start the worker back up
    sleep 3
    docker compose logs -f queue &
else
    echo "OK: No extra restart took place"
fi

# Following the above, we also want to check if this only happens the first
# time a job is dispatched for a tenant (with central illuminate:queue:restart) filled
# and fills the TENANT's illuminate:queue:restart from then on, or if this happens on
# future jobs of that tenant as well.

# This time, just to add more context, we can try to dispatch a central job first
# in case it changes anything. But odds are that in broken setups we'll see both warnings.
dispatch_central_job
without_queue_assertions assert_tenant_users 2
without_queue_assertions assert_central_users 2
echo "OK: User created in central\n"

dispatch_tenant_job
without_queue_assertions assert_tenant_users 3
without_queue_assertions assert_central_users 2
echo "OK: User created in tenant\n"

if docker compose ps -a --format '{{.Status}}' queue | grep -q "Exited"; then
    echo "WARN: ANOTHER extra restart took place after running a tenant job"
    docker compose start queue # Start the worker back up
    sleep 3
    docker compose logs -f queue &
else
    echo "OK: No second extra restart took place"
fi

# We have to clear the central illuminate:queue:restart value here
# to make the last assertion work, because if the previous WARNs were
# triggered, that means the following *tenant job dispatch* will trigger
# a restart as well.
# -n 1 = DB number for cache connection, configured in setup/database.php
docker compose exec redis redis-cli -n 1 DEL laravel_database_illuminate:queue:restart >/dev/null

# Also make the queue worker reload the value from cache
docker compose restart queue
docker compose logs -f queue &

# Finally, we dispatch a tenant job *immediately* before a restart.
dispatch_tenant_job
assert_tenant_users 4
assert_central_users 2
echo "OK: User created in tenant\n"

echo "Running queue:restart (after a tenant job)..."
docker compose exec -T queue php artisan queue:restart >/dev/null
sleep 3
assert_queue_worker_exited
echo "OK: Queue worker has exited"

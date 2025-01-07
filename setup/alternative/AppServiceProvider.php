<?php

namespace App\Providers;

use Illuminate\Queue\Console\RestartCommand;
use Illuminate\Queue\Console\WorkCommand;
use Illuminate\Queue\Events\JobProcessed;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->extend(RestartCommand::class, function ($_, $app) {
            return new RestartCommand($app['cache']->store('global_redis'));
        });
        $this->app->extend(WorkCommand::class, function ($_, $app) {
            return new WorkCommand($app['queue.worker'], $app['cache']->store('global_redis'));
        });
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Event::listen(JobProcessed::class, function () {
            file_put_contents(base_path('jobprocessed_context'), tenant() ? ('tenant_' . tenant('id')) : 'central');
        });
    }
}

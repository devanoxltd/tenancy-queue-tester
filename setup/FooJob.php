<?php

namespace App\Jobs;

use App\Models\User;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Str;

class FooJob implements ShouldQueue
{
    use Queueable;

    public function handle(): void
    {
        User::create(['name' => Str::random(12), 'email' => Str::random(12), 'password' => Str::random(12)]);
    }
}


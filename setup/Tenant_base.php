<?php

namespace App\Models;

use Devanox\Tenancy\Database\Models\Tenant as BaseTenant;
use Devanox\Tenancy\Contracts\TenantWithDatabase;
use Devanox\Tenancy\Database\Concerns\HasDatabase;
use Devanox\Tenancy\Database\Concerns\HasDomains;

class Tenant extends BaseTenant implements TenantWithDatabase
{
    use HasDatabase, HasDomains;
}

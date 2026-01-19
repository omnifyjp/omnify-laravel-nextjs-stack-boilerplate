<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Omnify\SsoClient\Models\Traits\HasConsoleSso;

class User extends Authenticatable
{
    use HasFactory, Notifiable, HasConsoleSso;

    protected $fillable = [
        'name',
        'email',
        'password',
        'console_user_id',
        'console_access_token',
        'console_refresh_token',
        'console_token_expires_at',
    ];

    protected $hidden = [
        'password',
        'remember_token',
        'console_access_token',
        'console_refresh_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'console_token_expires_at' => 'datetime',
        ];
    }
}

<?php
// Capabilities for local_drccops. Reading activity is the only thing this
// plugin can do, so there is exactly one read capability.

defined('MOODLE_INTERNAL') || die();

$capabilities = [
    'local/drccops:viewactivity' => [
        'captype' => 'read',
        'contextlevel' => CONTEXT_SYSTEM,
        'archetypes' => [
            'manager' => CAP_ALLOW,
        ],
    ],
];

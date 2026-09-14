<?php
// Web service functions exposed by local_drccops. Both are reads of the
// standard log store; the plugin defines no write function at all.

defined('MOODLE_INTERNAL') || die();

$functions = [
    'local_drccops_get_recent_events' => [
        'classname' => 'local_drccops\external\get_recent_events',
        'methodname' => 'execute',
        'description' => 'Recent standard log events, for portal activity reporting.',
        'type' => 'read',
        'capabilities' => 'local/drccops:viewactivity',
        'ajax' => false,
    ],
    'local_drccops_get_failed_logins' => [
        'classname' => 'local_drccops\external\get_failed_logins',
        'methodname' => 'execute',
        'description' => 'Recent failed login events, for portal security reporting.',
        'type' => 'read',
        'capabilities' => 'local/drccops:viewactivity',
        'ajax' => false,
    ],
];

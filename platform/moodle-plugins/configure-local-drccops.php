<?php
// Grants the portal's read-only service access to the two local_drccops
// functions and allows the capability on the portal's read-only role.
//
// Run on the Moodle host: sudo -u www-data php configure-local-drccops.php
// Idempotent, and touches nothing except the service/function map and one
// capability assignment.

define('CLI_SCRIPT', true);
require(__DIR__ . '/config.php');

$functions = ['local_drccops_get_recent_events', 'local_drccops_get_failed_logins'];
$roleshortname = 'drccportalro';

$service = $DB->get_record('external_services', ['shortname' => 'drcc_portal_ro']);
if (!$service) {
    $service = $DB->get_record_select(
        'external_services',
        $DB->sql_like('name', ':name', false),
        ['name' => '%DigitalRCC%'],
        '*',
        IGNORE_MULTIPLE
    );
}
if (!$service) {
    mtrace('No DigitalRCC external service found; nothing changed.');
    exit(1);
}
mtrace("Service: {$service->name} (id {$service->id})");

foreach ($functions as $functionname) {
    if (!$DB->record_exists('external_functions', ['name' => $functionname])) {
        mtrace("Function {$functionname} is not registered in Moodle; run the plugin upgrade first.");
        exit(1);
    }
    $exists = $DB->record_exists('external_services_functions', [
        'externalserviceid' => $service->id,
        'functionname' => $functionname,
    ]);
    if ($exists) {
        mtrace("  already on the service: {$functionname}");
        continue;
    }
    $DB->insert_record('external_services_functions', (object)[
        'externalserviceid' => $service->id,
        'functionname' => $functionname,
    ]);
    mtrace("  added to the service: {$functionname}");
}

$roleid = $DB->get_field('role', 'id', ['shortname' => $roleshortname]);
if (!$roleid) {
    mtrace("Role {$roleshortname} not found; assign local/drccops:viewactivity manually.");
    exit(1);
}
$systemcontext = context_system::instance();
assign_capability('local/drccops:viewactivity', CAP_ALLOW, $roleid, $systemcontext->id, true);
mtrace("Allowed local/drccops:viewactivity on role {$roleshortname} at system context.");

purge_all_caches();
mtrace('Done.');

<?php
namespace local_drccops\external;

defined('MOODLE_INTERNAL') || die();

use context_system;
use core_external\external_api;
use core_external\external_function_parameters;
use core_external\external_multiple_structure;
use core_external\external_single_structure;
use core_external\external_value;

/**
 * Reads recent rows out of the standard log store.
 *
 * Cursor based: callers keep the highest returned id and pass it back as
 * sinceid, so an incremental poll never re-reads what it already has. Rows are
 * always returned in id order and the row count is capped.
 */
class get_recent_events extends external_api {
    /** Largest number of rows a single call may return. */
    const MAX_LIMIT = 5000;

    public static function execute_parameters(): external_function_parameters {
        return new external_function_parameters([
            'sinceid' => new external_value(PARAM_INT, 'Return events with a log id greater than this', VALUE_DEFAULT, 0),
            'since' => new external_value(PARAM_INT, 'Return events created at or after this unix time', VALUE_DEFAULT, 0),
            'limit' => new external_value(PARAM_INT, 'Maximum rows to return', VALUE_DEFAULT, 1000),
            'userid' => new external_value(PARAM_INT, 'Restrict to one Moodle user id, 0 for all', VALUE_DEFAULT, 0),
            'includewebservice' => new external_value(
                PARAM_BOOL,
                'Include web service call events, which are usually this integration polling itself',
                VALUE_DEFAULT,
                false
            ),
        ]);
    }

    public static function execute(
        int $sinceid = 0,
        int $since = 0,
        int $limit = 1000,
        int $userid = 0,
        bool $includewebservice = false
    ): array {
        global $DB;

        $params = self::validate_parameters(self::execute_parameters(), [
            'sinceid' => $sinceid,
            'since' => $since,
            'limit' => $limit,
            'userid' => $userid,
            'includewebservice' => $includewebservice,
        ]);

        $context = context_system::instance();
        self::validate_context($context);
        require_capability('local/drccops:viewactivity', $context);

        $limit = max(1, min(self::MAX_LIMIT, $params['limit']));

        $where = ['l.userid > 0'];
        $queryparams = [];

        if ($params['sinceid'] > 0) {
            $where[] = 'l.id > :sinceid';
            $queryparams['sinceid'] = $params['sinceid'];
        }
        if ($params['since'] > 0) {
            $where[] = 'l.timecreated >= :since';
            $queryparams['since'] = $params['since'];
        }
        if ($params['userid'] > 0) {
            $where[] = 'l.userid = :userid';
            $queryparams['userid'] = $params['userid'];
        }
        if (!$params['includewebservice']) {
            $where[] = 'l.eventname <> :wsevent';
            $queryparams['wsevent'] = '\\core\\event\\webservice_function_called';
        }

        $sql = 'SELECT l.id, l.eventname, l.component, l.action, l.target, l.objectid,
                       l.courseid, l.userid, l.relateduserid, l.origin, l.ip, l.timecreated
                  FROM {logstore_standard_log} l
                 WHERE ' . implode(' AND ', $where) . '
              ORDER BY l.id ASC';

        $rows = $DB->get_records_sql($sql, $queryparams, 0, $limit);

        $events = [];
        $maxid = $params['sinceid'];
        foreach ($rows as $row) {
            $maxid = max($maxid, (int)$row->id);
            $events[] = [
                'id' => (int)$row->id,
                'eventname' => (string)$row->eventname,
                'component' => (string)$row->component,
                'action' => (string)$row->action,
                'target' => (string)$row->target,
                'objectid' => (int)$row->objectid,
                'courseid' => (int)$row->courseid,
                'userid' => (int)$row->userid,
                'relateduserid' => (int)$row->relateduserid,
                'origin' => (string)$row->origin,
                'ip' => (string)$row->ip,
                'timecreated' => (int)$row->timecreated,
            ];
        }

        return [
            'events' => $events,
            'maxid' => $maxid,
            'returned' => count($events),
            'truncated' => count($events) >= $limit,
            'servertime' => time(),
        ];
    }

    public static function execute_returns(): external_single_structure {
        return new external_single_structure([
            'events' => new external_multiple_structure(
                new external_single_structure([
                    'id' => new external_value(PARAM_INT, 'Log row id'),
                    'eventname' => new external_value(PARAM_RAW, 'Fully qualified event class name'),
                    'component' => new external_value(PARAM_RAW, 'Component that raised the event'),
                    'action' => new external_value(PARAM_RAW, 'Event action'),
                    'target' => new external_value(PARAM_RAW, 'Event target'),
                    'objectid' => new external_value(PARAM_INT, 'Object id, 0 when absent'),
                    'courseid' => new external_value(PARAM_INT, 'Course id, 0 for site level events'),
                    'userid' => new external_value(PARAM_INT, 'Acting Moodle user id'),
                    'relateduserid' => new external_value(PARAM_INT, 'Related Moodle user id, 0 when absent'),
                    'origin' => new external_value(PARAM_RAW, 'web, ws, cli or restore'),
                    'ip' => new external_value(PARAM_RAW, 'Source address recorded with the event'),
                    'timecreated' => new external_value(PARAM_INT, 'Unix time the event was created'),
                ])
            ),
            'maxid' => new external_value(PARAM_INT, 'Highest log id returned, to pass back as sinceid'),
            'returned' => new external_value(PARAM_INT, 'Number of rows returned'),
            'truncated' => new external_value(PARAM_BOOL, 'True when the row cap was hit and more rows remain'),
            'servertime' => new external_value(PARAM_INT, 'Moodle server unix time when the read completed'),
        ]);
    }
}

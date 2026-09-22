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
 * Reads failed login events out of the standard log store.
 *
 * A failed login carries no user id when the account does not exist, so the
 * attempted username is taken from the event payload instead.
 */
class get_failed_logins extends external_api {
    /** Largest number of rows a single call may return. */
    const MAX_LIMIT = 2000;

    public static function execute_parameters(): external_function_parameters {
        return new external_function_parameters([
            'sinceid' => new external_value(PARAM_INT, 'Return events with a log id greater than this', VALUE_DEFAULT, 0),
            'since' => new external_value(PARAM_INT, 'Return events created at or after this unix time', VALUE_DEFAULT, 0),
            'limit' => new external_value(PARAM_INT, 'Maximum rows to return', VALUE_DEFAULT, 500),
        ]);
    }

    public static function execute(int $sinceid = 0, int $since = 0, int $limit = 500): array {
        global $DB;

        $params = self::validate_parameters(self::execute_parameters(), [
            'sinceid' => $sinceid,
            'since' => $since,
            'limit' => $limit,
        ]);

        $context = context_system::instance();
        self::validate_context($context);
        require_capability('local/drccops:viewactivity', $context);

        $limit = max(1, min(self::MAX_LIMIT, $params['limit']));

        $where = ['l.eventname = :eventname'];
        $queryparams = ['eventname' => '\\core\\event\\user_login_failed'];

        if ($params['sinceid'] > 0) {
            $where[] = 'l.id > :sinceid';
            $queryparams['sinceid'] = $params['sinceid'];
        }
        if ($params['since'] > 0) {
            $where[] = 'l.timecreated >= :since';
            $queryparams['since'] = $params['since'];
        }

        $sql = 'SELECT l.id, l.userid, l.relateduserid, l.ip, l.timecreated, l.other
                  FROM {logstore_standard_log} l
                 WHERE ' . implode(' AND ', $where) . '
              ORDER BY l.id ASC';

        $rows = $DB->get_records_sql($sql, $queryparams, 0, $limit);

        $failures = [];
        $maxid = $params['sinceid'];
        foreach ($rows as $row) {
            $maxid = max($maxid, (int)$row->id);
            $other = self::decode_other($row->other);
            $failures[] = [
                'id' => (int)$row->id,
                'userid' => (int)($row->relateduserid ?: $row->userid),
                'username' => isset($other['username']) ? (string)$other['username'] : '',
                'reason' => isset($other['reason']) ? (string)$other['reason'] : '',
                'ip' => (string)$row->ip,
                'timecreated' => (int)$row->timecreated,
            ];
        }

        return [
            'failures' => $failures,
            'maxid' => $maxid,
            'returned' => count($failures),
            'truncated' => count($failures) >= $limit,
            'servertime' => time(),
        ];
    }

    /**
     * The log store writes the event payload as json; very old rows may still
     * hold a serialised array.
     *
     * @param string|null $other
     * @return array
     */
    private static function decode_other(?string $other): array {
        if (empty($other)) {
            return [];
        }
        $decoded = json_decode($other, true);
        if (is_array($decoded)) {
            return $decoded;
        }
        $unserialised = @unserialize($other);
        return is_array($unserialised) ? $unserialised : [];
    }

    public static function execute_returns(): external_single_structure {
        return new external_single_structure([
            'failures' => new external_multiple_structure(
                new external_single_structure([
                    'id' => new external_value(PARAM_INT, 'Log row id'),
                    'userid' => new external_value(PARAM_INT, 'Moodle user id when the account exists, otherwise 0'),
                    'username' => new external_value(PARAM_RAW, 'Attempted username'),
                    'reason' => new external_value(PARAM_RAW, 'Moodle failure reason code'),
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

-- Read-only Guacamole database role used by the DRCC session collector.
--
-- The collector runs on the Guacamole host and posts sanitized session rows to
-- the portal, so the portal never holds a Guacamole credential and the Guacamole
-- database is never exposed outside the lab network. This role can read session
-- history and connection names and nothing else: no INSERT/UPDATE/DELETE, no
-- access to guacamole_user password hashes.
--
-- Apply on the Guacamole host:
--   docker exec -i guac-postgres psql -U guacamole_user -d guacamole_db \
--     -v role_password="'<generated>'" -f portal-readonly-role.sql
--
-- Rollback:
--   revoke all on guacamole_connection_history, guacamole_connection from guac_portal_ro;
--   revoke usage on schema public from guac_portal_ro;
--   drop role guac_portal_ro;

\set ON_ERROR_STOP on

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'guac_portal_ro') then
    execute format('create role guac_portal_ro login password %L', :'role_password');
  else
    execute format('alter role guac_portal_ro login password %L', :'role_password');
  end if;
end
$$;

revoke all on database guacamole_db from guac_portal_ro;
grant connect on database guacamole_db to guac_portal_ro;
grant usage on schema public to guac_portal_ro;

grant select on guacamole_connection_history to guac_portal_ro;
grant select on guacamole_connection to guac_portal_ro;

-- Explicitly no default privileges: a future table is not readable until it is
-- granted here on purpose.
alter default privileges in schema public revoke select on tables from guac_portal_ro;

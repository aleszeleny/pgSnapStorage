\set ON_ERROR_ROLLBACK 1
\set ON_ERROR_STOP on
\set snapsns snaps

START TRANSACTION;

SELECT set_config('search_path','snap_storage, public',false);

SELECT plan(6);

-- SELECT roles_are(ARRAY[ 'postgres', 'snaps_ro', 'snaps_rw' ],  'Check roles.');

SELECT diag('Schema(s) tests.');
SELECT schemas_are(ARRAY[ 'public', :'snapsns' ], 'Check schemas.');

SELECT schema_privs_are(
    :'snapsns', 'public', ARRAY[]::text[],
    format('%I should not be granted any privilege on schema %I.', 'public', :'snapsns')
);

SELECT schema_privs_are(
    :'snapsns', 'snaps_ro', ARRAY['USAGE'],
    format('Role %I should be granted USAGE privilege on schema %I.', 'snaps_ro', :'snapsns')
);

SELECT schema_privs_are(
    :'snapsns', 'snaps_rw', ARRAY['USAGE'],
    format('Role %I should be granted USAGE privilege on schema %I.', 'snaps_rw', :'snapsns')
);


SELECT diag('Tables tests.');
SELECT tables_are(
    :'snapsns',
    ARRAY[ 'snap_instance_cfg' ],
    'Check expected tables.'
);

SELECT diag('snap_instance_cfg table tests.');
SELECT bag_eq(
  E'SELECT attname
    FROM pg_catalog.pg_attribute a
    JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
    WHERE c.relname = $$snap_instance_cfg$$
      AND c.relnamespace = ''' || :'snapsns' || E'''::regnamespace::oid
      AND NOT attisdropped AND attnum > 0',
  ARRAY[
      'snap_instance_cfg_id'
    , 'instance_name'
    , 'instance_host_addr'
    , 'instance_port'
    , 'cluster_name'
    , 'systemid'
    , 'registration_time'
  ]::TEXT[],
  'Make sure new columns added to snap_instance_cfg are also added to the tests.'
);

SELECT * FROM finish();

ROLLBACK;

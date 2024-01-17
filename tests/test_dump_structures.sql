\set ON_ERROR_ROLLBACK 1
\set ON_ERROR_STOP on
--\set cfg_ns snaps_cfg

\ir ../sql/010_config.sql

\c :snapsdb

START TRANSACTION;

-- SELECT set_config('search_path', :'cfg_ns' || ', public',false);

SELECT plan(28);

-- SELECT roles_are(ARRAY[ 'postgres', 'snaps_ro', 'snaps_rw' ],  'Check roles.');

SELECT diag('Database tests.');
SELECT database_privs_are(
    :'snapsdb', 'snaps_conn', ARRAY['CONNECT', 'TEMPORARY']
  , format('%I should be granted CONNECT and TERMPORARY on db %I.', 'snaps_conn', :'snapsdb')
);

SELECT database_privs_are(
    :'snapsdb', 'tu_snaps_cfg', ARRAY['CONNECT', 'TEMPORARY']
  , format('%I should be granted CONNECT and TERMPORARY on db %I.', 'tu_snaps_cfg', :'snapsdb')
);

SELECT database_privs_are(
    :'snapsdb', 'tu_snaps_storage', ARRAY['CONNECT', 'TEMPORARY']
  , format('%I should be granted CONNECT and TERMPORARY on db %I.', 'tu_snaps_storage', :'snapsdb')
);

SELECT database_privs_are(
    :'snapsdb', 'tu_snaps_read', ARRAY['CONNECT', 'TEMPORARY']
  , format('%I should be granted CONNECT and TERMPORARY on db %I.', 'tu_snaps_read', :'snapsdb')
);


SELECT diag('Schema(s) tests.');
SELECT schemas_are(ARRAY[ 'public', :'cfg_ns' ], 'Check schemas.');

-- set schema for subsequent tests
\set tap_namespace :cfg_ns

SELECT schema_privs_are(
    :'cfg_ns', 'public', ARRAY[]::text[]
  , format('%I should not be granted any privilege on schema %I.', 'public', :'cfg_ns')
);

SELECT schema_privs_are(
    :'cfg_ns', 'snaps_ro_cfg', ARRAY['USAGE']
  , format('Role %I should be granted USAGE privilege on schema %I.', 'snaps_ro_cfg', :'cfg_ns')
);

SELECT schema_privs_are(
    :'cfg_ns', 'snaps_ro', ARRAY['USAGE']
  , format('Role %I should be granted USAGE privilege on schema %I.', 'snaps_ro', :'cfg_ns')
);

SELECT schema_privs_are(
    :'cfg_ns', 'snaps_rw_cfg', ARRAY['USAGE']
  , format('Role %I should be granted USAGE privilege on schema %I.', 'snaps_rw_cfg', :'cfg_ns')
);

SELECT schema_privs_are(
    :'cfg_ns', 'snaps_rw', ARRAY['USAGE']
  , format('Role %I should be granted USAGE privilege on schema %I.', 'snaps_rw', :'cfg_ns')
);

SELECT schema_privs_are(
    :'cfg_ns', 'snaps_ro_data', ARRAY['USAGE']
  , format('Role %I should be granted USAGE privilege on schema %I.', 'snaps_ro_data', :'cfg_ns')
);

SELECT schema_privs_are(
    :'cfg_ns', 'snaps_rw_data', ARRAY['USAGE']
  , format('Role %I should be granted USAGE privilege on schema %I.', 'snaps_rw_data', :'cfg_ns')
);

SELECT schema_privs_are(
    :'cfg_ns', 'tu_snaps_cfg', ARRAY['USAGE']
  , format('Role %I should be granted USAGE privilege on schema %I.', 'tu_snaps_cfg', :'cfg_ns')
);

SELECT schema_privs_are(
    :'cfg_ns', 'tu_snaps_storage', ARRAY['USAGE']
  , format('Role %I should be granted USAGE privilege on schema %I.', 'tu_snaps_storage', :'cfg_ns')
);

SELECT schema_privs_are(
    :'cfg_ns', 'tu_snaps_read', ARRAY['USAGE']
  , format('Role %I should be granted USAGE privilege on schema %I.', 'tu_snaps_read', :'cfg_ns')
);


-- #############################################################################
SELECT diag('Table tests.');
-- #############################################################################

\set tap_namespace :cfg_ns

PREPARE tap_get_tbl_column_names(name, name) AS
  SELECT attname
  FROM pg_catalog.pg_attribute a
  JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
  WHERE c.relname = $1
    AND c.relnamespace = $2::regnamespace::oid
    AND NOT attisdropped AND attnum > 0;

/*******************************************************************************
Check expected tables.
*******************************************************************************/
SELECT tables_are(
    :'tap_namespace'
  , ARRAY[ 'system', 'system_tree', 'instance' ]
  , 'Check expected tables.'
);

/*******************************************************************************
TABLE: snap_cfg.instance
*******************************************************************************/
\set tap_table_name system
\set tap_table_cols '{system_id, systemid, system_name, system_description, lastmod}'

\ir tst_table_columns.in
\ir tst_table_pkey.in
\ir tst_table_key.in

/*
********************************************************************************
TABLE: snap_cfg.instance
********************************************************************************
*/
\set tap_table_name system_tree
\set tap_table_cols '{system_tree_id, description, ancestor_system_id, descendant_system_id, lastmod}'
\set tap_uq_cols '{ancestor_system_id, descendant_system_id}'

\ir tst_table_columns.in
\ir tst_table_pkey.in
\ir tst_table_key.in
\ir tst_key_columns.in

SELECT fk_ok( :'tap_namespace', :'tap_table_name','ancestor_system_id', :'tap_namespace',  'system', 'system_id');
SELECT fk_ok( :'tap_namespace', :'tap_table_name', 'descendant_system_id', :'tap_namespace',  'system', 'system_id');

/*
********************************************************************************
TABLE: snap_cfg.instance
********************************************************************************
*/
\set tap_table_name instance
\set tap_table_cols '{instance_id, system_id, cluster_name, host_addr, listen_port, instance_name, instance_description, registration_time, lastmod}'
\set tap_uq_cols '{ancestor_system_id, descendant_system_id}'

\ir tst_table_columns.in
\ir tst_table_pkey.in

SELECT fk_ok( :'tap_namespace', :'tap_table_name', 'system_id', :'tap_namespace',  'system', 'system_id');

SELECT * FROM finish();

ROLLBACK;

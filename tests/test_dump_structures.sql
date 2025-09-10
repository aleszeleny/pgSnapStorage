\set ON_ERROR_ROLLBACK 1
\set ON_ERROR_STOP on
--\set cfg_ns snaps_cfg

\ir ../sql/010_config.sql

\c :snapsdb

START TRANSACTION;

-- SELECT set_config('search_path', :'cfg_ns' || ', public',false);

SELECT plan(50);

SELECT diag('Database tests');
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

SELECT diag('Schemas tests.');

SELECT schemas_are(ARRAY[ 'public', :'cfg_ns', :'data_ns' ], 'Check schemas.');

-- set schema for subsequent tests
\set tap_namespace :cfg_ns

-- snapshots storage configuration schema
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

-- snapshots data schema
\set tap_namespace :data_ns
SELECT schema_privs_are(:'tap_namespace', 'public', ARRAY[]::text[]);

SELECT schema_privs_are(:'tap_namespace', 'snaps_ro_cfg', ARRAY[]::text[]);
SELECT schema_privs_are(:'tap_namespace', 'snaps_rw_cfg', ARRAY[]::text[]);

SELECT schema_privs_are(:'tap_namespace', 'snaps_ro_data', ARRAY['USAGE']::text[]);
SELECT schema_privs_are(:'tap_namespace', 'snaps_rw_data', ARRAY['USAGE']::text[]);

SELECT schema_privs_are(:'tap_namespace', 'snaps_ro', ARRAY['USAGE']::text[]);
SELECT schema_privs_are(:'tap_namespace', 'snaps_rw', ARRAY['USAGE']::text[]);

-- #############################################################################
\set tap_namespace :cfg_ns
SELECT diag('Table tests for schema ' || :'tap_namespace');
-- #############################################################################

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
  , ARRAY[ 'system', 'system_tree', 'instance', 'database' ]
  , 'Check expected tables in schema '|| :'tap_namespace'
);

/*******************************************************************************
TABLE: snap_cfg.instance
*******************************************************************************/
\set tap_table_name system
\set tap_table_cols '{system_id, systemid, pg_major_version, system_name, system_description, lastmod}'
\set tap_uq_cols '{systemid}'

\ir tst_table_columns.in
\ir tst_table_pkey.in
\ir tst_table_key.in
\ir tst_key_columns.in

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
\set tap_table_cols '{instance_id, system_id, cluster_name, host_addr, listen_port, instance_name, instance_description, major_version, registration_time, lastmod}'

\ir tst_table_columns.in
\ir tst_table_pkey.in

SELECT fk_ok( :'tap_namespace', :'tap_table_name', 'system_id', :'tap_namespace',  'system', 'system_id');

/*
********************************************************************************
TABLE: snap_cfg.database
********************************************************************************
*/
\set tap_table_name database
\set tap_table_cols '{database_id, instance_id, collect_cluster, collect_db, dbname, connect_string, database_description, registration_time, lastmod}'

\ir tst_table_columns.in
\ir tst_table_pkey.in

SELECT fk_ok( :'tap_namespace', :'tap_table_name', 'instance_id', :'tap_namespace',  'instance', 'instance_id');

-- #############################################################################
\set tap_namespace :data_ns
SELECT diag('Table tests for schema ' || :'tap_namespace');
-- #############################################################################

/*******************************************************************************
Check expected tables.
*******************************************************************************/
SELECT tables_are(
    :'tap_namespace'
  , '{snapshot, snapshot_pg_settings, pg_settings}'::name[]
  , 'Check expected tables in schema '|| :'tap_namespace'
);

/*
********************************************************************************
TABLE: snaps_data.snapshot
********************************************************************************
*/
\set tap_table_name snapshot
\set tap_table_cols '{snapshot_id, snaptime, database_id, cluster_stats, db_stats}'
\set tap_uq_cols '{database_id, snaptime}'

\ir tst_table_columns.in
\ir tst_table_pkey.in
\ir tst_key_columns.in

SELECT fk_ok( :'tap_namespace', :'tap_table_name', 'database_id', :'cfg_ns',  'database', 'database_id');

/*
********************************************************************************
TABLE: snaps_data.pg_settings
********************************************************************************
*/
\set tap_table_name pg_settings
\set tap_table_cols '{hash, name, setting, unit, category, short_desc, extra_desc, context, vartype, source, min_val, max_val, enumvals, boot_val, reset_val, sourcefile, sourceline, pending_restart}'

\ir tst_table_columns.in
\ir tst_table_pkey.in

/*
********************************************************************************
TABLE: snaps_data.snapshot_pg_settings
********************************************************************************
*/
\set tap_table_name snapshot_pg_settings
\set tap_table_cols '{snapshot_id, name, hash}'

\ir tst_table_columns.in
\ir tst_table_pkey.in

SELECT fk_ok( :'tap_namespace', :'tap_table_name', 'snapshot_id', :'tap_namespace',  'snapshot', 'snapshot_id');
SELECT fk_ok( :'tap_namespace', :'tap_table_name', 'hash', :'tap_namespace',  'pg_settings', 'hash');

SELECT * FROM finish();

ROLLBACK;

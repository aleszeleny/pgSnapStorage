-- PostgreSQL Snapshots Storage - snaps
/* https://en.wikipedia.org/wiki/Snaps */

/*
  TODO: split into separate scripts.
*/

\ir ../010_config.sql

/*
\set snapsdb snaps_db
\set snapsdbown snaps
\set cfg_ns snaps_cfg
*/


/*
  CLEANUP - TEMPORARY
*/

\c postgres
DROP DATABASE IF EXISTS :snapsdb;

DROP ROLE IF EXISTS :snapsdbown;
DROP ROLE IF EXISTS snaps_conn;
DROP ROLE IF EXISTS snaps_ro;
DROP ROLE IF EXISTS snaps_ro_cfg;
DROP ROLE IF EXISTS snaps_ro_data;
DROP ROLE IF EXISTS snaps_rw;
DROP ROLE IF EXISTS snaps_rw_cfg;
DROP ROLE IF EXISTS snaps_rw_data;
DROP ROLE IF EXISTS tu_snaps_cfg;
DROP ROLE IF EXISTS tu_snaps_storage;
DROP ROLE IF EXISTS tu_snaps_read;

CREATE ROLE :snapsdbown;
CREATE DATABASE :snapsdb OWNER :snapsdbown;

\c :snapsdb

/*
  END OF CLEANUP
*/

START TRANSACTION;

-- SELECT set_config('search_path', :'cfg_ns' || ', public',false);

CREATE FUNCTION pg_temp.create_role_if_ne(p_role_name name)
RETURNS void
LANGUAGE PLPGSQL AS
$function$
BEGIN
  IF pg_catalog.to_regrole(p_role_name) IS NULL THEN
    EXECUTE format('CREATE ROLE %I', p_role_name);
    RAISE NOTICE 'Created role %', p_role_name;
  ELSE
    RAISE NOTICE 'Role % already exists', p_role_name;
  END IF;
END;
$function$;

-- Create role to control connect privilege to snapshost storage database
SELECT pg_temp.create_role_if_ne(p_role_name => 'snaps_conn');
GRANT CONNECT, TEMPORARY ON DATABASE :snapsdb TO snaps_conn;
REVOKE CONNECT ON DATABASE :snapsdb FROM public;

-- Create roles to grant read access to snapshots tables.
SELECT pg_temp.create_role_if_ne(p_role_name => 'snaps_ro'); -- read all
SELECT pg_temp.create_role_if_ne(p_role_name => 'snaps_ro_cfg'); -- read configuration tables
SELECT pg_temp.create_role_if_ne(p_role_name => 'snaps_ro_data'); -- read snapshots tables

-- Create role to grant write access to snapshots tables.
SELECT pg_temp.create_role_if_ne(p_role_name => 'snaps_rw');
SELECT pg_temp.create_role_if_ne(p_role_name => 'snaps_rw_cfg');
SELECT pg_temp.create_role_if_ne(p_role_name => 'snaps_rw_data');


-- Create example technical user roles (to emuate application access to data).
-- Feel free to set a password for the tu_% roles if you want to use them for an application.
SELECT pg_temp.create_role_if_ne(p_role_name => 'tu_snaps_cfg'); -- configuration data management role
ALTER ROLE tu_snaps_cfg WITH LOGIN;

SELECT pg_temp.create_role_if_ne(p_role_name => 'tu_snaps_storage'); -- snapshots data storage role
ALTER ROLE tu_snaps_storage WITH LOGIN;

SELECT pg_temp.create_role_if_ne(p_role_name => 'tu_snaps_read'); -- snapshots data reader app role
ALTER ROLE tu_snaps_read WITH LOGIN;

/*
"Master" roles with all snapshost read / read & write permissions.
Intended to be granted to some custom roles (together with snaps_conn role).
*/
GRANT snaps_ro_cfg, snaps_ro_data TO snaps_ro;
GRANT snaps_rw_cfg, snaps_rw_data TO snaps_rw;

/*
Grant roles to technical user accounts - they are here to have ability to test permissions works as expected
and as an example for additional custom/presonal roles creation
*/
GRANT snaps_conn, snaps_ro_cfg, snaps_rw_cfg TO tu_snaps_cfg; -- configuration data management user
GRANT snaps_conn, snaps_ro_cfg, snaps_ro_data, snaps_rw_data TO tu_snaps_storage; -- snapshost wiring application user
GRANT snaps_conn, snaps_ro_cfg, snaps_ro_data TO tu_snaps_read; -- an application user providing access to stored data


/*
********************************************************************************
* Schemas                                                                      *
********************************************************************************
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~ Create schema for snapshot tables                                           ~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
CREATE SCHEMA IF NOT EXISTS :cfg_ns AUTHORIZATION :snapsdbown;
REVOKE ALL ON SCHEMA :cfg_ns FROM public;
GRANT USAGE ON SCHEMA :cfg_ns TO snaps_ro_cfg, snaps_rw_cfg, snaps_ro_data, snaps_rw_data;

ALTER DEFAULT PRIVILEGES FOR ROLE :snapsdbown
  IN SCHEMA :cfg_ns
  GRANT SELECT ON TABLES TO snaps_ro_cfg;

ALTER DEFAULT PRIVILEGES FOR ROLE :snapsdbown
  IN SCHEMA :cfg_ns
  GRANT INSERT, UPDATE, DELETE ON TABLES TO snaps_rw_cfg;

ALTER DEFAULT PRIVILEGES FOR ROLE :snapsdbown
  IN SCHEMA :cfg_ns
  GRANT USAGE ON SEQUENCES TO snaps_rw_cfg;

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~ Create schema for snapshot data tables                                      ~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
CREATE SCHEMA IF NOT EXISTS :data_ns AUTHORIZATION :snapsdbown;
REVOKE ALL ON SCHEMA :data_ns FROM public;
GRANT USAGE ON SCHEMA :data_ns TO snaps_ro_data, snaps_rw_data;

ALTER DEFAULT PRIVILEGES FOR ROLE :snapsdbown
  IN SCHEMA :data_ns
  GRANT SELECT ON TABLES TO snaps_ro_data;

ALTER DEFAULT PRIVILEGES FOR ROLE :snapsdbown
  IN SCHEMA :data_ns
  GRANT INSERT, UPDATE, DELETE ON TABLES TO snaps_rw_data;

ALTER DEFAULT PRIVILEGES FOR ROLE :snapsdbown
  IN SCHEMA :data_ns
  GRANT USAGE ON SEQUENCES TO snaps_rw_data;

/*
********************************************************************************
* Generic trigger function(s)                                                  *
********************************************************************************
*/
SET ROLE :snapsdbown;

CREATE OR REPLACE FUNCTION :cfg_ns.lastmod_tf()
RETURNS trigger
LANGUAGE PLPGSQL AS
$function$
BEGIN

  IF NEW.lastmod IS NULL THEN

    NEW.lastmod:= pg_catalog.now();

  END IF;

  RETURN NEW;
END;
$function$;

/*
********************************************************************************
* Configuration tables                                                         *
********************************************************************************
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~ PostgreSQL systems inventory table                                           ~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
CREATE TABLE IF NOT EXISTS :cfg_ns.system (
    system_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY
  , systemid bigint NOT NULL UNIQUE /* remove unique consstraint in the case of an unexpected real-life systemid collision */
  , system_name text
  , system_description text
  , lastmod TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

COMMENT ON TABLE :cfg_ns.system IS
  'Postgresql system(s) inventory.';

COMMENT ON COLUMN :cfg_ns.system.systemid IS
  'System ID, see pg_control_system().';

DROP TRIGGER IF EXISTS system_lastmod
  ON :cfg_ns.system;

CREATE TRIGGER system_lastmod
  BEFORE INSERT OR UPDATE
  ON :cfg_ns.system
  FOR EACH ROW
  EXECUTE FUNCTION :cfg_ns.lastmod_tf();

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~ PostgreSQL systems tree/history relation table                               ~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
CREATE TABLE IF NOT EXISTS :cfg_ns.system_tree (
    system_tree_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY
  , description text
  , ancestor_system_id int NOT NULL REFERENCES :cfg_ns.system(system_id)
  , descendant_system_id int NOT NULL REFERENCES :cfg_ns.system(system_id)
  , lastmod TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
  , CONSTRAINT system_tree_key UNIQUE (ancestor_system_id, descendant_system_id)
);

CREATE INDEX ON :cfg_ns.system_tree(ancestor_system_id);
CREATE INDEX ON :cfg_ns.system_tree(descendant_system_id);

COMMENT ON TABLE :cfg_ns.system_tree IS
E'PostgreSQL systems relation(s)
during migrations, upgrades,
splits or consolidations.';

DROP TRIGGER IF EXISTS system_tree_lastmod
  ON :cfg_ns.system;

CREATE TRIGGER system_tree_lastmod
  BEFORE INSERT OR UPDATE
  ON :cfg_ns.system
  FOR EACH ROW
  EXECUTE FUNCTION :cfg_ns.lastmod_tf();

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~ Postgresql instances inventory table                                         ~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
CREATE TABLE IF NOT EXISTS :cfg_ns.instance (
    instance_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY
  , system_id int NOT NULL REFERENCES :cfg_ns.system(system_id)
  , cluster_name text NOT NULL
  , host_addr inet
  , listen_port integer NOT NULL
  , instance_name text
  , instance_description text
  , major_version text
  , registration_time TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
  , lastmod TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

CREATE INDEX ON :cfg_ns.instance(system_id);

COMMENT ON TABLE :cfg_ns.instance IS
  'Configuration table for snapshots data source instances.';

COMMENT ON COLUMN :cfg_ns.instance.instance_name IS
  'Custom name for the instance (PostgreSQL cluster).';


CREATE OR REPLACE FUNCTION :cfg_ns.instance_defaults_tf()
RETURNS trigger
LANGUAGE PLPGSQL AS
$function$
BEGIN
  IF NEW.instance_name IS NULL THEN
    NEW.instance_name:= format(
        '%s@%s:%s'
      , coalesce(NEW.cluster_name, 'undefined')
      , coalesce(NEW.instance_host_addr::text, 'local')
      , NEW.instance_port
    );
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS instance_defaults
  ON :cfg_ns.instance;

CREATE TRIGGER instance_defaults
  BEFORE INSERT
  ON :cfg_ns.instance
  FOR EACH ROW
  EXECUTE FUNCTION :cfg_ns.instance_defaults_tf();

DROP TRIGGER IF EXISTS instance_lastmod
  ON :cfg_ns.instance;

CREATE TRIGGER instance_lastmod
  BEFORE INSERT OR UPDATE
  ON :cfg_ns.instance
  FOR EACH ROW
  EXECUTE FUNCTION :cfg_ns.lastmod_tf();

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~ Postgresql databases inventory table                                         ~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
CREATE TABLE IF NOT EXISTS :cfg_ns.database (
    database_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY
  , instance_id int NOT NULL REFERENCES :cfg_ns.instance(instance_id)
  , collect_cluster boolean NOT NULL DEFAULT true
  , collect_db boolean NOT NULL DEFAULT true
  , dbname text NOT NULL
  , connect_string text NOT NULL
  , database_description text
  , registration_time TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
  , lastmod TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

CREATE INDEX ON :cfg_ns.database(instance_id);

COMMENT ON TABLE :cfg_ns.database IS
  'Configuration table for source databases.';

COMMENT ON COLUMN :cfg_ns.database.collect_cluster IS
  'Enable instance (PostgreSQL cluster) wide stats collection.';

COMMENT ON COLUMN :cfg_ns.database.collect_db IS
  'Enable connected database wide stats collection.';

DROP TRIGGER IF EXISTS database_lastmod
  ON :cfg_ns.database;

CREATE TRIGGER database_lastmod
  BEFORE INSERT OR UPDATE
  ON :cfg_ns.database
  FOR EACH ROW
  EXECUTE FUNCTION :cfg_ns.lastmod_tf();

/*
********************************************************************************
* Snapshot data tables                                                        *
********************************************************************************
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~ Snapshot table                                                               ~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

CREATE TABLE IF NOT EXISTS :data_ns.snapshot (
    snapshot_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY
  , snaptime TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
  , database_id int NOT NULL REFERENCES :cfg_ns.database(database_id)
  , cluster_stats boolean NOT NULL
  , db_stats boolean NOT NULL
  , CONSTRAINT snapshot_key UNIQUE (database_id, snaptime)
);

COMMENT ON TABLE :data_ns.snapshot IS
'Snapshot metadata.';

COMMENT ON COLUMN :data_ns.snapshot.snaptime IS
'Data collection timestamp.';

COMMENT ON COLUMN :data_ns.snapshot.database_id IS
'Reference to database used to collect snapshot data.';

COMMENT ON COLUMN :data_ns.snapshot.cluster_stats IS
'Cluster (instance) wide statitic were collected.';

COMMENT ON COLUMN :data_ns.snapshot.db_stats IS
'Database wide statitic were collected.';


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~ pg_settings table                                                   ~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
CREATE TABLE IF NOT EXISTS :data_ns.pg_settings (
    hash             text NOT NULL PRIMARY KEY
  , name             text
  , setting          text
  , unit             text
  , category         text
  , short_desc       text
  , extra_desc       text
  , context          text
  , vartype          text
  , source           text
  , min_val          text
  , max_val          text
  , enumvals         text[]
  , boot_val         text
  , reset_val        text
  , sourcefile       text
  , sourceline       integer
  , pending_restart  boolean
);

COMMENT ON TABLE :data_ns.pg_settings IS
E'pg_settings data snapshots.';

CREATE TABLE IF NOT EXISTS :data_ns.snapshot_pg_settings (
    snapshot_id bigint NOT NULL REFERENCES :data_ns.snapshot(snapshot_id)
  , hash text NOT NULL REFERENCES :data_ns.pg_settings(hash)
  , CONSTRAINT snapshot_pg_settings_pkey PRIMARY KEY (snapshot_id, hash)
);


/*
GRANT SELECT ON ALL TABLES IN SCHEMA :cfg_ns TO snaps_ro_cfg;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA :cfg_ns TO snaps_rw_cfg;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA :cfg_ns TO snaps_rw_cfg;
*/

RESET ROLE;

COMMIT;


/* TESTING ONLY */
RESET search_path;
CREATE EXTENSION IF NOT EXISTS pgtap;

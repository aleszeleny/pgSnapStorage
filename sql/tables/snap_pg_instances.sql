/*
  Source PostgreSQL instance(s) configuration.
*/

START TRANSACTION;

SET search_path = snap_storage;

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

-- Create role to grant read access to snapshots tables.
SELECT pg_temp.create_role_if_ne(p_role_name => 'snaps_ro');

-- Create role to grant write access to snapshots tables.
SELECT pg_temp.create_role_if_ne(p_role_name => 'snaps_rw');

-- Create schema for snapshot tables
CREATE SCHEMA IF NOT EXISTS snap_storage;
REVOKE USAGE ON SCHEMA snap_storage FROM public;
GRANT USAGE ON SCHEMA snap_storage TO snaps_ro, snaps_rw;


CREATE TABLE IF NOT EXISTS snap_instance_cfg (
    snap_instance_cfg_id serial PRIMARY KEY
  , instance_name text
  , instance_host_addr inet
  , instance_port integer NOT NULL
  , cluster_name text NOT NULL
  , systemid bigint NOT NULL
  , registration_time TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ON snap_instance_cfg(systemid);

COMMENT ON TABLE snap_instance_cfg IS
$comment$
  Configuration table for snapshots data source instances.
$comment$;

COMMENT ON COLUMN snap_instance_cfg.instance_name IS
$comment$
  Custom name for the instance (PostgreSQL cluster).
$comment$;

COMMENT ON COLUMN snap_instance_cfg.systemid IS
$comment$
  System ID, see pg_control_system().
  Master and slave instances can be identified using
  systemid.
$comment$;

CREATE OR REPLACE FUNCTION snap_instance_cfg_defaults_trg()
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

DROP TRIGGER IF EXISTS snap_instance_cfg_set_defaults
  ON snap_instance_cfg;

CREATE TRIGGER snap_instance_cfg_set_defaults
  BEFORE INSERT
  ON snap_instance_cfg
  FOR EACH ROW
  EXECUTE FUNCTION snap_instance_cfg_defaults_trg();

/*
COMMENT ON COLUMN snap_instance_cfg.systemid_prev IS
$comment$
  Reference to prevoius system to keep track
  of a "logically" same system across upgrades
  or migrations (for cloud to On-premise...).
$comment$;
*/

COMMIT;

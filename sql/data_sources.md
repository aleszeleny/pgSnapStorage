# Data sources

* systemid: `pg_control_system()`
* server version:
  * `SELECT current_setting('cluster_name')`
  * `SELECT current_setting('server_version')`
  * `SELECT current_setting('server_version_num')`
  * `SELECT current_setting('server_version_num')::int/10000 as major_version, current_setting('server_version_num')::int%10000 as minor_version`
* slave instance: `pg_is_in_recovery()`
* staistics data `pg_stat_%` system views
* database block size `pg_control_init()`
* instance start time `pg_postmaster_start_time ()`
* Config load time `pg_conf_load_time ()`
* server IP address `inet_server_addr ()`
* server listening port `inet_server_port ()`
* connected database name `current_database ()`

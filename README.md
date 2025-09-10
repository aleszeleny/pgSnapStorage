# PostgreSQL Snapshot Storage

Storage for Snapshots of Postgresql Statistic tables/views.

## Installation

Review / adjust the file `sql/010_config.sql` where target DB and schemas are defined and then install the schema:

```sh
psql -f install/install.sql
```

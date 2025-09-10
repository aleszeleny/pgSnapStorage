# Tests for pgSnapStorage

## Running the tests

Install packages `pgtap`, `postgresql-17-pgtap`

* pgTap extension must be installed in the database
* tests are executed using pg_prove utility

### Example

_pgSnapStorage_ in installed in database `snaps_db`, instead of command line argument `PGDATABASE` environment variable might be used as well.

```sh
pg_prove --dbname snaps_db tests/*.sql
```

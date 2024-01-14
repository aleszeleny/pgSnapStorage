# Tests for pgSnapStorage

## Running the tests

* pgTap extension must be installed in the databse
* tests are executed using pg_prove utility

### Example
_pgSnapStorage_ in installed in database `snaps`, instead of commnad line argument `PGDATABASE` environment variable might be used as well.
```
pg_prove --dbname snaps tests/*.sql
```

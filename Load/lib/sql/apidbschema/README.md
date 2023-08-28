# CAUTION:  there are two parallel directories here
There are two parallel directories:
- `Oracle/`
- `Postgres/`

The S.O.P. is:
1. The directory names (Oracle and Postgres) must conform to the `dbVendor` property in gus.confg
2. Obviously, changes to either directory must be made in the other one, else bugs will bite your toes.

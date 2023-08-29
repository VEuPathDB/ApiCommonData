#!/bin/bash

set -e

# this is a really fun script 
# it populates a geopackage file (wget https://geodata.ucdavis.edu/gadm/gadm4.1/gadm_410-gpkg.zip) into a PostGIS database using containers

workDir=$1
instanceName=$2
port=$3
gpkgFile=$4

databaseName=gadm

gpkgFileBaseName="${gpkgFile##*/}"

POSTGRES_IMAGE="docker://postgis/postgis:15-3.4";
GDAL_IMAGE="docker://osgeo/gdal:ubuntu-full-latest";

mkdir -p ${workDir}/postgresData ${workDir}/postgresSocket ${workDir}/postgresInit

cp $gpkgFile ${workDir}/postgresInit/

chmod guo+rw -R ${workDir}/postgresData ${workDir}/postgresSocket

echo singularity instance start --bind ${workDir}/postgresSocket:/var/run/postgresql --bind ${workDir}/postgresData:/var/lib/postgresql/data $POSTGRES_IMAGE $instanceName 
singularity instance start --bind ${workDir}/postgresSocket:/var/run/postgresql --bind ${workDir}/postgresData:/var/lib/postgresql/data $POSTGRES_IMAGE $instanceName 

echo APPTAINER_PGDATA=/var/lib/postgresql/data APPTAINERENV_PGPORT=$port APPTAINERENV_POSTGRES_PASSWORD=mypass singularity run instance://$instanceName -p $port & pid=\$!
APPTAINER_PGDATA=/var/lib/postgresql/data APPTAINERENV_PGPORT=$port APPTAINERENV_POSTGRES_PASSWORD=mypass singularity run instance://$instanceName -p $port & pid=\$!

echo timeout 90s bash -c "until singularity exec instance://${instanceName} pg_isready -p ${port}; do sleep 5 ; done;"
timeout 90s bash -c "until singularity exec instance://${instanceName} pg_isready -p ${port}; do sleep 5 ; done;"

# copy the template database
echo singularity exec instance://$instanceName psql -p $port -U postgres -c "create database ${databaseName} template template_postgis"
singularity exec instance://$instanceName psql -p $port -U postgres -c "create database ${databaseName} template template_postgis"

# load the data from gpkgFile
echo singularity exec --bind ${workDir}/postgresInit:/data --bind ${workDir}/postgresSocket:/var/run/postgresql $GDAL_IMAGE ogr2ogr -f PostgreSQL PG:"dbname=${databaseName} user=postgres host=/var/run/postgresql port=${port}" /data/$gpkgFileBaseName
singularity exec --bind ${workDir}/postgresInit:/data --bind ${workDir}/postgresSocket:/var/run/postgresql $GDAL_IMAGE ogr2ogr -f PostgreSQL PG:"dbname=${databaseName} user=postgres host=/var/run/postgresql port=${port}" /data/$gpkgFileBaseName


echo singularity exec instance://$instanceName pg_ctl stop -D /var/lib/postgresql/data -m smart
singularity exec instance://$instanceName pg_ctl stop -D /var/lib/postgresql/data -m smart

echo singularity instance stop $instanceName
singularity instance stop $instanceName

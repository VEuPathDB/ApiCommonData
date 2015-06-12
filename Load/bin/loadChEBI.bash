#!/bin/bash

set -e    # exit if any error!

usage()
{
echo 'loadChEBI.bash -d <DIR> -i instance -u user -p password -h help'
exit 1;
}

if [ -z $1 ]; then
  usage
fi

#--------------------------------------------------------------------------------

while getopts ":h:d:i:u:p:" Option
do
  case $Option in
    d) d=$OPTARG;
       ;;
    i) i=$OPTARG;
       ;;
    u) u=$OPTARG;
       ;;
    p) p=$OPTARG;
       ;;
    h) usage
       ;;
  esac
done

disableConstraintsFile=disable_constraints.sql;
enableConstraintsFile=enable_constraints.sql ;
createTablesFile=create_tables.sql;
parFile=import_all_star.par;
grantGusRolesFile=$GUS_HOME/lib/sql/apidbschema/grantChebiTables.sql;

for f in $d/*
  do
    if [[ $f =~ \.gz$ ]]; then
        gunzip -f $f;
    fi;
done

echo exit|sqlplus $u/$p@$i @$d/$createTablesFile;

echo exit|sqlplus $u/$p@$i @$d/$disableConstraintsFile;

imp $u/$p@$i PARFILE=$d/$parFile

echo exit|sqlplus $u/$p@$i @$d/$enableConstraintsFile;

sqlplus $u/$p@$i @$grantGusRolesFile;






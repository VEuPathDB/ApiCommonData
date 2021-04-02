#!/bin/bash

set -e

while getopts s:t:p:m: flag
do
    case "${flag}" in
        s) sourceBranch=${OPTARG};;
        t) targetBranch=${OPTARG};;
        m) message=${OPTARG};;
        p) project=${OPTARG};;
    esac
done


git clone git@github.com:VEuPathDB/ApiCommonDatasets.git;
cd ApiCommonDatasets;
git checkout $sourceBranch;
git checkout $targetBranch;
git checkout $sourceBranch Datasets/lib/xml/datasets/${project}*;
git commit -m "'"${message}"'";
git push;


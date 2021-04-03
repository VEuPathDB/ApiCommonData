#!/bin/bash

set -e

while getopts d:p:t:m:c: flag
do
    case "${flag}" in
        d) datasetsSourceBranch=${OPTARG};;
        p) presentersSourceBranch=${OPTARG};;
        t) targetBranch=${OPTARG};;
        c) component=${OPTARG};;
    esac
done

git clone git@github.com:VEuPathDB/ApiCommonDatasets.git;
git clone git@github.com:VEuPathDB/ApiCommonPresenters.git;

cd ApiCommonDatasets;
git checkout $datasetsSourceBranch;
git checkout $targetBranch;
git checkout $datasetsSourceBranch Datasets/lib/xml/datasets/${component}*;

if [ -n "$(git status --porcelain)" ]; then
  git commit -m "'tagging ${component} from ${datasetsSourceBranch}'";
  git push;
fi

cd ../ApiCommonPresenters;
git checkout $presentersSourceBranch;
git checkout $targetBranch;
git checkout $presentersSourceBranch Model/lib/xml/datasetPresenters/${component}*;
if [ -n "$(git status --porcelain)" ]; then
  git commit -m "'tagging ${component} from ${presentersSourceBranch}'";
  git push;
fi


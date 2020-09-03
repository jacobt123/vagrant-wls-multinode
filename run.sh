#!/bin/bash

start=`date +%s`
startdate=`date`
echo "Deployment Started at ====> $startdate"
vagrant --c=2 up
end=`date +%s`
enddate=`date`
runtime=$((end-start))
echo "Deployment ended at =====> $enddate"
echo "Total time taken for provisioning============> $((runtime/60)) minutes"


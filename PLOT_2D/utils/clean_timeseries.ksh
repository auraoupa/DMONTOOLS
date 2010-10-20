#!/bin/ksh

if [ ! $# == 2 ] ; then
   echo "USAGE : clean_timeseries.ksh CONFIG CASE "
   echo "       This will erase all .catalog, .gif .sun, and .rgb files for this config "
   echo "       USE WITH CARE ! " ; exit 1
fi

CONFIG=$1
CASE=$2
CONFCASE=$CONFIG-$CASE

if [ ! $SDIR ] ; then 
  echo "SDIR is not defined ; aborting " ; exit 1
fi

cd $SDIR/$CONFIG/PLOTS/$CONFCASE

for dirtmp in $( ls ) ; do

   echo WORKING in directory $SDIR/$CONFIG/PLOTS/$CONFCASE/$dirtmp

   cd $SDIR/$CONFIG/PLOTS/$CONFCASE/$dirtmp ; rm -f *.catalog *.gif *.rgb *.sun

done

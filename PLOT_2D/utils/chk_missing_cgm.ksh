#!/bin/ksh

# This script must be launched from the ../PLOTS/CONFIG-CASE directory.
# This script is used to check whether all the cgm files are build  in the PLOTS/CONFIG-CASE/ subdirs.
# It is used before make_time_series in order to avoid 'holes' in the resulting gif files.
# However, if a kind of plot is missing at all (not even 1 plot of this kind done) the script skip this kind.
# Finally the range of years to be looked for is determine from the directories available in CONFIG-CASE-MEAN
# The path of this MEAN dir follows $SDIR as set in config_def.ksh 
#
# By default it scans all the subdirectories. It is possible to specify a list of directories to be scanned as
# arguments to this script.

case "$1" in
'-h' | '--help') echo 'USAGE: chk_missing_cgm.ksh [-h | --help ] [plot sub dirs]'
                 echo '       -h | --help  : show this message '
                 echo '       If no plot subdirs are indicated, scan all subdirs' 
                 echo
                 echo '  This command should be issued from PLOTS/CONFIG-CASE dir' ;;
*)

CONFCASE=$(basename $(pwd) )
CONFIG=${CONFCASE%-*}
CASE=${CONFCASE#*-}

here=$(pwd)
cd $PDIR/RUN_$CONFIG/$CONFCASE/CTL/CDF

. ./config_def.ksh   # source the correct config_def.ksh dir
cd $SDIR/$CONFIG/${CONFCASE}-MEAN/$XIOS
# look for the years to be looked for:
tmp=$( ls -d  [0-9]??? )

years=''
for f in $tmp ; do
  if [ -d $f ] ; then years="$years $f" ; fi
done
############## JMM ADD ##############################
#  years=$( seq 1958 1969 )
############## JMM ADD ##############################

cd $here

if [ $# !=   0 ] ; then
  list=$*
else
  list=$(ls -1d * | grep -v TIME_SERIES)
fi
echo $list


for d in $list ; do
   if [ -d $d ] ; then
     cd $d

     for typ in $( for f in *.cgm ; do tmp=${f%-${CASE}.cgm}; echo ${tmp%_*} ;  done | sort -u) ; do
        for y in $years ; do
          if [ ! -f ${typ}_${y}-${CASE}.cgm ] ; then
             printf "%12s : %s missing\n" $d ${typ}_${y}-${CASE}.cgm 
          fi
        done
     done
     cd ../
   fi
done ;;

esac

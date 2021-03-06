#!/bin/ksh
#----------------------------------------------------------
# $Id: mkannual_VT.ksh 25 2015-05-23 00:06:34Z molines $  mkannual_VT.ksh : compute annual VT from monthly VT
#----------------------------------------------------------
. ./config_moy.ksh

################################################
freq=1m
REMDIR=/ccc/scratch/cont003/gen0727/molines/
################################################

usage() {
    echo "  USAGE : $(basename $0 ) Y1 [Y2]"
    echo 
    echo "  Purpose:"
    echo "      This script is a wrapper which computes "
    echo "      annual mean for VT files from monthly VT computed with "
    echo "      mkmonthly_VT.ksh script."
    echo "      This script must be run from CTL/CDF dir"
    echo 
    echo " Arguments:"
    echo "   Y1 : first year to compute annual mean. "
    echo "   Y2 : last year to comput annual mean. If missing only work with Y1."
    exit
       }
HERE=$(pwd)
if [ $( basename $HERE ) != CDF ] ; then usage ; fi
if [ $# = 0 ] ; then usage ; fi

tmp=$(dirname `dirname $HERE` ) 
CONFCASE=$(basename $tmp)
CONFIG=$( echo $CONFCASE | awk -F- '{print $1}' )
CASE=$(   echo $CONFCASE | awk -F- '{print $2}' )
freq=$XIOS

y1=$1
y2=$2

y2=${y2:=$y1}
# eventually set -nc4 option for cdftools 
NC4=${NC4:=0}
if [ $NC4 = 1 ] ; then NCOPT='-nc4' ; else NCOPT="" ; fi

case $MACHINE in
   ( curie ) 
submit=ccc_msub
cat << eof > zmkannualvt.ksh
#!/bin/ksh
#MSUB -r anualVT
#MSUB -n  6
#MSUB -T 14600
#MSUB -q standard
#MSUB -o zannualVT.o%I
#MSUB -e zannualVT.e%I

#MSUB -A gen0727
cd \${BRIDGE_MSUB_PWD}
eof
echo " " ;;
    ( * )
  echo " add support for $MACHINE  "
  exit 1 ;;
esac

cat << eof >> zmkannualvt.ksh
DTADIR=$REMDIR/${CONFIG}/${CONFCASE}-S/$freq
#   goto the MEAN directory
cd $DDIR/${CONFIG}/${CONFCASE}-MEAN/$freq/

#   loop on years to process
for y in \$(seq $y1 $y2 ) ; do
  # assume year directory and monthly VT files are already computed. Skip if not
  if [ -d \$y ] ; then
    cd \$y
    if [  -f VT_DONE ] ; then 
      # prepare mpirun command to compute 6 temporary means files corresponding to 6 pairs of input files, and run it
      cmd="mpirun "
      cmd="\$cmd -np 1 cdfmoy -l ${CONFCASE}_y\${y}m0[12].${freq}_VT.nc -o tmpvt12 : "
      cmd="\$cmd -np 1 cdfmoy -l ${CONFCASE}_y\${y}m0[34].${freq}_VT.nc -o tmpvt34 : "
      cmd="\$cmd -np 1 cdfmoy -l ${CONFCASE}_y\${y}m0[56].${freq}_VT.nc -o tmpvt56 : " 
      cmd="\$cmd -np 1 cdfmoy -l ${CONFCASE}_y\${y}m0[78].${freq}_VT.nc -o tmpvt78 : " 
      cmd="\$cmd -np 1 cdfmoy -l ${CONFCASE}_y\${y}m09.${freq}_VT.nc ${CONFCASE}_y\${y}m10.${freq}_VT.nc -o tmpvt910 : " 
      cmd="\$cmd -np 1 cdfmoy -l ${CONFCASE}_y\${y}m1[12].${freq}_VT.nc -o tmpvt1112 " 
      \$cmd

      # prepare mpirun command to compute 3 temporary means files corresponding to 3 pairs of temporary mean from previous step
      cmd="mpirun "
      cmd="\$cmd -np 1 cdfmoy -l tmpvt12.nc tmpvt34.nc -o tmpvt_1 : -np 1 cdfmoy -l tmpvt56.nc tmpvt78.nc -o tmpvt_2 : -np 1 cdfmoy -l tmpvt910.nc tmpvt1112.nc -o tmpvt_3 "
      \$cmd

      # compute mean values of the 3  temporary files obtained at last step
      cdfmoy -l tmpvt_1.nc tmpvt_2.nc tmpvt_3.nc $NCOPT -o  ${CONFCASE}_y\${y}.${freq}_VT

      # clean useless files
      rm -f tmpvt* ${CONFCASE}_y\${y}.${freq}_VT2.nc  cdfmoy2.nc VT_DONE *22.nc
    else
      if [ ! -f ${CONFCASE}_y\${y}.${freq}_VT.nc ] ; then
        # monthly VT not available
        echo Monthly mean for VT files not computed yet for \$y
        echo Use mk_monthlyVT.ksh script first 
      else
        # Annual mean already done
        echo Annual VT file alreadt computed for \$y
      fi
    fi
    cd ../
   else
    # year not ready
    echo year \$y missing in MEAN
   fi
done
eof


$submit  ./zmkannualvt.ksh

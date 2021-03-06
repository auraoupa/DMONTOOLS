#!/bin/ksh

usage() {
   echo USAGE :  $(basename $0)  YEAR 
   echo "       When model output are done on monthly basis, create corresponding "
   echo "       links into the -MEAN directory."
   echo "       This command must be issued from either a CONFIG-CASE-S directory "
   echo "       or a CONFIG-CASE/CTL or CONFIG-CASE/CTL/CDF directory and "
   echo "       there must be 12 files per year in the yearly directory."
   echo "         Then this script launch 2 jobs mkmoy and mkvt for annual mean"
   echo "       computation."
   exit  $1
        }

gettype() {
       #  get file type list. eg; gridT, icemod, flxT ... 
       ( for f in *.nc ; do
         echo ${f%.nc} | awk -F_ '{print  $NF }' 
       done  ) | sort -u 
          }

chkenv()  {
       # check if basic DCM environment variables are set
       #  SWDIR for now
       if [ ! $SWDIR ] ; then
          printf "$r\n"
          echo "  You must set SWDIR environment variable to the location of"
          echo "S working directory, previous the use of this script."
          printf "$k\n"
          exit 1
       fi
          }

getconfig_from_dir()  {
       zsdir=$( basename $( pwd ) )
       CONFIG=$( echo $zsdir | awk -F- '{ print $1 }' )
       CASE=$(   echo $zsdir | awk -F- '{ print $2 }' )
       CONFCASE=${CONFIG}-${CASE}
                    }

# function for text color
set_color() {
       r="\033[31m"  # red
       g="\033[32m"  # green
       b="\033[34m"  # blue
       m="\033[35m"  # magenta
       k="\033[0m"   # black/reset
            }
mkmoy() {
set -x
cat << eof > $PDIR/RUN_${CONFIG}/${CONFCASE}/CTL/CDF/zmkmoy.$yyyy.ksh
#!/bin/ksh
# @ job_name         = zmoy.$yyyy
# @ output           = \$(job_name).o\$(jobid)
# @ error            = \$(job_name).e\$(jobid)
# @ job_type = serial
# @ wall_clock_limit = 10:00:00
# @ queue

set -x

CONFCASE=$CONFCASE
CONFIG=${CONFIG}
CASE=${CASE}

CDFTOOLS=\$WORKDIR/bin

cd \$SWDIR/\$CONFIG/\${CONFCASE}-MEAN/
year=$( printf "%04d" $year )

if [ ! -d \$year ] ; then
    echo directory \$year not ready
    exit 1
fi
echo working for year \$year 

cd \$year
for var in $(echo $lst) ; do

   if [ ! -f \${CONFCASE}_y\${year}_\${var}.nc ] ; then
      \$CDFTOOLS/cdfmoy \${CONFCASE}_y\${year}m??_\${var}.nc
      case \$var in 
        icemod | flxT ) mv cdfmoy.nc \${CONFCASE}_y\${year}_\${var}.nc ; \rm cdfmoy2.nc ;;
        *)   mv cdfmoy.nc  \${CONFCASE}_y\${year}_\${var}.nc ;
             mv cdfmoy2.nc \${CONFCASE}_y\${year}_\${var}2.nc ;;
      esac
   fi
done

eof

cd  $PDIR/RUN_${CONFIG}/${CONFCASE}/CTL/CDF/
llsubmit ./zmkmoy.$yyyy.ksh
        }

mkvt()  {
set -x
cat << eof > $PDIR/RUN_${CONFIG}/${CONFCASE}/CTL/CDF/zmkvt.$yyyy.ksh
#!/bin/ksh
# @ job_name         = zmkvt.$yyyy
# @ output           = \$(job_name).o\$(jobid)
# @ error            = \$(job_name).e\$(jobid)
# @ job_type = serial
# @ wall_clock_limit = 10:00:00
# @ queue


set -x
CONFCASE=$CONFCASE
CONFIG=${CONFIG}
CASE=${CASE}

CDFTOOLS=\$WORKDIR/bin
cd \$SWDIR/\$CONFIG/\${CONFCASE}-MEAN/

year=$( printf "%04d" $year )

if [ ! -d \$year ] ; then
    echo directory \$year not ready
    exit 1
fi
echo working for year \$year 
cd \$year

if [ ! -f \${CONFCASE}_y\${year}_VT.nc ] ; then
   touch \${CONFCASE}_y\${year}_VT.nc  # to prevent a second job to repeat this year
   taglist=''
   for f in \${CONFCASE}_y\${year}m??_gridT.nc ; do
      tag=\$(echo \$f | sed -e 's/_/ /g' | awk '{print \$2}')
      taglist="\$taglist \$tag"
   done
   \$CDFTOOLS/cdfvT \$CONFCASE \$taglist
   mv vt.nc \${CONFCASE}_y\${year}_VT.nc
fi
eof
cd  $PDIR/RUN_${CONFIG}/${CONFCASE}/CTL/CDF/
llsubmit ./zmkvt.$yyyy.ksh
        }

# --- main script start here ---
set_color

if [ $# = 0 ] ; then 
   usage 0
fi

chkenv

year=$1
yyyy=$( printf "%04d" $1 )
here=$( basename $( pwd ) )
tmp=$( echo $here | awk -F- '{ print $NF }' )

case $tmp in 
  S   )  getconfig_from_dir  ;;
  CTL ) 
     cd ../
     getconfig_from_dir
     cd $SWDIR/${CONFIG}/${CONFCASE}-S
     here=$( basename $( pwd ) ) ;;
  CDF )
     cd ../../
     getconfig_from_dir
     cd $SWDIR/${CONFIG}/${CONFCASE}-S
     here=$( basename $( pwd ) ) ;;
  * )
  printf "$r\n"
  echo "  You must be in CONFIG-CASE-S or in a corresponding CTL/ directory "
  echo "and you are in $here !"
  printf "$k\n"
  usage 1  ;;
esac
  
if [ -d $yyyy ] ; then
  cd $yyyy
  lst="$( gettype )"

  for typ in $lst ; do
    nftyp=$( ls -1 *${typ}.nc  | wc -w )
    if [ $nftyp != 12 ] ; then
       echo there are $nftyp files of type $typ, not 12
       exit
    fi
  done
      
else
  echo " ERROR : $yyyy does not exist "
  echo
  usage 1
fi

echo CONFCASE = $CONFCASE

sdiry=$( pwd )
mkdir -p $SWDIR/$CONFIG/${CONFCASE}-MEAN/$yyyy
cd $SWDIR/$CONFIG/${CONFCASE}-MEAN/$yyyy

for typ in $lst ; do
   i=1
  for f in $sdiry/${CONFCASE}_*_$typ.nc ; do
    mm=$( printf "%02d" $i )
    ln -sf $f $SWDIR/$CONFIG/${CONFCASE}-MEAN/$yyyy/${CONFCASE}_y${yyyy}m${mm}_$typ.nc
    i=$(( i + 1 ))
  done
done

mkmoy

mkvt


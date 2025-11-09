#!/bin/csh -f

set startTime = `date +%s`
set workDir = `pwd`
set helpMessage = "\
##############This program runs all tms in the list file.####################\n\
The default list file is named as tm.list.\n\
To put select new list file, put it in the argument 1st.\n\
\n\
List file usage:\n\
# character is used at comment, it can put same as Cshell rules.\n\
\n\
Content of list file:\n\
Part 1: give argument to call and change easily\n\
  + default: this is assigned to "'"'"run pattern_name"'"'"\n\
  + option_##:  this is assigned to "'"'"run pattern_name option#"'"'"\n\
Part 2: tm name and argument.\n\
  + If no argument is assigned, the default option is chosen\n\
  + If one argument is assigned, option_## is chosen\n\
  + If more one arguments are assigned, this parses all arguments to run script\n\
"


if($#argv == 0 ) then
  echo $helpMessage | sed 's/\\n/\n/g'
  exit
else if($#argv == 1) then
  set tmList = $1 
  set enZip  = " "
else if($#argv == 2) then
  set tmList = $1
  set enZip  = $2   #enable compress log file
else
  echo "Too much argument."
  exit
endif
 
echo "Start...................."
#check the existence of list fiel
if(!(-e $tmList)) then
  echo "File $1 is not exist"
  exit
endif

sed 's/#.*//' $tmList >! runningTm
sed -i '/^\s*$/ d' runningTm

#check default arguement
if (`grep -c '^default:' runningTm`) then
    set defaultOpt = `grep '^default:' runningTm | sed 's/^default:\s*//'`
    echo "Default option: $defaultOpt "
else
    echo "Info: $tmList doesn't have default option"
    set defaultOpt = ""
endif
 
foreach line("`cat runningTm`")
    if (`echo $line | egrep -c '^default|^option'`) then
        continue
    endif

    # pause by user
    while (1)
        if (-e ./pause_sim) then
            echo "Simulation is paused. To continue, please delete ${workDir}/pause_sim"
            sleep 30s
        else
            goto runSim
        endif
    end

runSim:
    echo "$line"
#    set argArray = `echo $line | awk '{print $1,$2}'`
    set argArray = `echo $line | awk '{print $0}'`
    set enGroup  = `echo $line | grep -c '\<PC_'`
    if ($enGroup == 0) then
        set argArray = `echo $line | awk '{print $1,$2}'`
        if ($#argArray == 1) then
            echo "Run with default argument............................................"
            set Opt = `grep '^default:' runningTm | sed 's/^default:\s*//'`
            echo "run $argArray[1] $Opt ############################################"
            run.csh $argArray[1] $Opt 
        else if ($#argArray == 2) then
            echo "Run with $argArray[2] argument............................................"
            set Opt = `grep "^${argArray[2]}:" runningTm | sed "s/^${argArray[2]}:\s*//"`
            echo "run $argArray[1] $Opt ############################################"
            run.csh $argArray[1] $Opt 
        endif
    else #parse all argument
        echo "Run with $argArray argument............................................"
        echo "run $argArray ############################################"
        run.csh $argArray 
    endif
end

#Calculate running time
set endTime = `date +%s`
set runTime = `expr \( $endTime - $startTime \) / 60`

echo "`date` Script running time: $runTime minute(s)" >>! runtime.log

rm -f runningTm
echo "All tms have been run.............................................."
if ("$enZip" == "ziplog") then
    echo "Remove compiled data..............................................."
    rm -rf ./output ./partitionlib
endif
echo "Get result for tms ................................................"
#./get_result.pl -i $tmList


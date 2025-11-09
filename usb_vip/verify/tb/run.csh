#!/bin/csh -f

if ($4 == "run") then
    make run TESTNAME=${1} SPEED=${2} SEED=${3}
else
    make TESTNAME=${1} SPEED=${2} SEED=${3}
endif

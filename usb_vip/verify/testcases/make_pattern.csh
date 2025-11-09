#!/bin/csh -f

#set testName = `echo $1 | sed 's/_vseq//'`
set testName = $1

cp brt_usb_model_test.sv ${testName}_test.sv

sed -i 's/brt_usb_model_test/'${testName}'/g' ${testName}_test.sv

if !(`grep -c "${testName}_test.sv" brt_usb_test_pkg.sv`) then
    sed -i 's/endpackage/  `include "'${testName}_test.sv'"\nendpackage/' brt_usb_test_pkg.sv
endif

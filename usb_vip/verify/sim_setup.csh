#!/bin/csh -f

## Common path
setenv BRTVIP_COMMON_ROOT /proj_lib/vip/brt/brt_uvm_layer/latest

## Verif root path
setenv BRTVIP_VERIF_USB_ROOT `pwd`

## VIP root path
setenv BRTVIP_USB_ROOT $BRTVIP_VERIF_USB_ROOT/..  


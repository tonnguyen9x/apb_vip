

`include "brt_usb_ss_serial_dut.v"

// =============================================================================
module brt_usb_ss_serial_dut_sv_wrapper(brt_usb_if brt_usb_host_if, brt_usb_if brt_usb_dev_if);

// ----------------------------------------------------------------------
// DUT Instantiation: Example DUT is just pass-through connection.
// ----------------------------------------------------------------------
brt_usb_ss_serial_dut brt_usb_ss_serial_dut_inst(

        .dp_host (brt_usb_host_if.brt_usb_20_serial_if.dp),
        .dm_host (brt_usb_host_if.brt_usb_20_serial_if.dm),
        .vbus_host (brt_usb_host_if.brt_usb_20_serial_if.vbus),

        .dut_hs_termination_host (brt_usb_host_if.brt_usb_20_serial_if.dut_hs_termination),
        .vip_hs_termination_host (brt_usb_host_if.brt_usb_20_serial_if.vip_hs_termination),
                                 
        .ssrxp_host (brt_usb_host_if.brt_usb_ss_serial_if.ssrxp),
        .ssrxm_host (brt_usb_host_if.brt_usb_ss_serial_if.ssrxm),
        .sstxp_host (brt_usb_host_if.brt_usb_ss_serial_if.sstxp),
        .sstxm_host (brt_usb_host_if.brt_usb_ss_serial_if.sstxm),
        .ssvbus_host (brt_usb_host_if.brt_usb_ss_serial_if.vbus),

        .dut_ss_termination_host (brt_usb_host_if.brt_usb_ss_serial_if.dut_ss_termination),
        .vip_ss_termination_host (brt_usb_host_if.brt_usb_ss_serial_if.vip_ss_termination),
                                 
        .dp_device (brt_usb_dev_if.brt_usb_20_serial_if.dp),
        .dm_device (brt_usb_dev_if.brt_usb_20_serial_if.dm),
        .vbus_device (brt_usb_dev_if.brt_usb_20_serial_if.vbus),

        .dut_hs_termination_device (brt_usb_dev_if.brt_usb_20_serial_if.dut_hs_termination),
        .vip_hs_termination_device (brt_usb_dev_if.brt_usb_20_serial_if.vip_hs_termination),

        .ssrxp_device (brt_usb_dev_if.brt_usb_ss_serial_if.ssrxp),
        .ssrxm_device (brt_usb_dev_if.brt_usb_ss_serial_if.ssrxm),
        .sstxp_device (brt_usb_dev_if.brt_usb_ss_serial_if.sstxp),
        .sstxm_device (brt_usb_dev_if.brt_usb_ss_serial_if.sstxm),
        .ssvbus_device (brt_usb_dev_if.brt_usb_ss_serial_if.vbus),

        .dut_ss_termination_device (brt_usb_dev_if.brt_usb_ss_serial_if.dut_ss_termination),
        .vip_ss_termination_device (brt_usb_dev_if.brt_usb_ss_serial_if.vip_ss_termination)
        );
// ----------------------------------------------------------------------
endmodule

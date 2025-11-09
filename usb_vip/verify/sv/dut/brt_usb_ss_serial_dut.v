
module brt_usb_ss_serial_dut (

            dp_host,
            dm_host,
            vbus_host,

            dut_hs_termination_host,
            vip_hs_termination_host,

            ssrxp_host,
            ssrxm_host,
            sstxp_host,
            sstxm_host,
            ssvbus_host,

            dut_ss_termination_host,
            vip_ss_termination_host,

            dp_device,
            dm_device,
            vbus_device,

            dut_hs_termination_device,
            vip_hs_termination_device,

            ssrxp_device,
            ssrxm_device,
            sstxp_device,
            sstxm_device,
            ssvbus_device,

            dut_ss_termination_device,
            vip_ss_termination_device

            );
// -----------------------------------------------------------------------------
// USB Host Interface Signals
// -----------------------------------------------------------------------------

  inout                                         dp_host;
  inout                                         dm_host;
  inout                                         vbus_host;

  output                                        dut_hs_termination_host;
  input                                         vip_hs_termination_host;

  output                                        ssrxp_host;
  output                                        ssrxm_host;
  input                                         sstxp_host;
  input                                         sstxm_host;
  inout                                         ssvbus_host;

  output                                        dut_ss_termination_host;
  input                                         vip_ss_termination_host;

// =============================================================================

// -----------------------------------------------------------------------------
// USB Device Interface Signals
// -----------------------------------------------------------------------------

  inout                                         dp_device;
  inout                                         dm_device;
  inout                                         vbus_device;

  output                                        dut_hs_termination_device;
  input                                         vip_hs_termination_device;

  output                                        ssrxp_device;
  output                                        ssrxm_device;
  input                                         sstxp_device;
  input                                         sstxm_device;
  inout                                         ssvbus_device;

  output                                        dut_ss_termination_device;
  input                                         vip_ss_termination_device;

// =============================================================================
// Pass-Through Assignments: USB Host Inputs are flipped and copied to USB Device Outputs
// -----------------------------------------------------------------------------
  assign dut_hs_termination_device = vip_hs_termination_host;

  assign ssrxp_device = sstxp_host;
  assign ssrxm_device = sstxm_host;

  assign dut_ss_termination_device = vip_ss_termination_host;

// =============================================================================
// Pass-Through Assignments: USB Device Inputs are flipped and copied to USB Host Outputs
// -----------------------------------------------------------------------------
  assign dut_hs_termination_host = vip_hs_termination_device;

  assign ssrxp_host = sstxp_device;
  assign ssrxm_host = sstxm_device;

  assign dut_ss_termination_host = vip_ss_termination_device;

// =============================================================================
// Pass-Through Assignments: Bi-Directionals Connected by Transmission Gates
// -----------------------------------------------------------------------------
  tran dp_xmit(dp_host, dp_device);
  tran dm_xmit(dm_host, dm_device);
//  tran vbus_host_xmit(vbus_host, ssvbus_host);
//  tran vbus_device_xmit(vbus_device, ssvbus_device);
  tran brt_usb_20_vbus_xmit(vbus_host, vbus_device);
  tran brt_usb_ss_vbus_xmit(ssvbus_host, ssvbus_device);

endmodule
// =============================================================================

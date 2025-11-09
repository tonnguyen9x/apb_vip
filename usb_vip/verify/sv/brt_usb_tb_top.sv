`timescale 1ps/1ps

module brt_usb_tb_top;

  brt_usb_if usb_host_if();
  brt_usb_if usb_dev_if();
  brt_usb_if usb_mon_if();
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import brt_usb_pkg::*;

  brt_usb_ss_serial_dut_sv_wrapper usb_ss_serial_dut_inst(usb_host_if, usb_dev_if);
 
// =============================================================================
// Pass-Through Assignments: Bi-Directionals Connected by Transmission Gates
// -----------------------------------------------------------------------------
  assign usb_mon_if.brt_usb_20_serial_if.dp   = usb_dev_if.brt_usb_20_serial_if.dp;
  assign usb_mon_if.brt_usb_20_serial_if.dm   = usb_dev_if.brt_usb_20_serial_if.dm;
  assign usb_mon_if.brt_usb_20_serial_if.vbus = usb_dev_if.brt_usb_20_serial_if.vbus;

  initial begin
    uvm_config_db#(virtual brt_usb_if)::set(uvm_root::get(), "uvm_test_top.env", "host_brt_usb_if", usb_host_if);
    uvm_config_db#(virtual brt_usb_if)::set(uvm_root::get(), "uvm_test_top.env", "dev_brt_usb_if", usb_dev_if);
    uvm_config_db#(virtual brt_usb_if)::set(uvm_root::get(), "uvm_test_top.env", "mon_brt_usb_if", usb_mon_if);
    run_test();
    end

 `ifdef WAVE
   initial begin
      $vcdpluson;
      $vcdplusmemon;
      $vcdplusautoflushon;
   end
 `endif

	initial forever begin
      `uvm_info("Testbench", "current time ", UVM_LOW);
		#1ms;
		end

endmodule

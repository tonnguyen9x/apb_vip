interface brt_usb_ss_serial_if();

	logic ssclk;
	logic ssrxp;
	logic ssrxm;
	logic sstxp;
	logic sstxm;
	wire vbus;

	logic dut_hs_termination;
	logic vip_hs_termination;
	logic dut_ss_termination;
	logic vip_ss_termination;

endinterface

`ifdef USR_TEST_NAME
    `undef USR_TEST_NAME
    `undef USR_TEST_NAME_VSEQ
`endif

`define USR_TEST_NAME_VSEQ brt_usb_bulk_in_align_short_zerolen_vseq
`define USR_TEST_NAME      `USR_TEST_NAME_VSEQ``_test

class `USR_TEST_NAME extends brt_usb_base_test;
  `brt_component_utils(`USR_TEST_NAME)

  function new(string name = "`USR_TEST_NAME", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_virtual_sequencer.main_phase", "default_sequence", `USR_TEST_NAME_VSEQ::type_id::get());
 // uvm_config_db#(uvm_object_wrapper)	::set(this, "env.dev_agent.brt_usb_layering.link_service_sequencer.main_phase", "default_sequence", brt_usb_link_service_suspend_sequence::type_id::get());
  endfunction

endclass

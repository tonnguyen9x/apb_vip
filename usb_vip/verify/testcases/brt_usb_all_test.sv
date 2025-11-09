//------------------------------------------------------------------------------
// Title    : USB Test
// Project  : 
//------------------------------------------------------------------------------
// Filename : 
// Author   : Aldo Tamaela
// Date     : 
//
//-----------------------------------------------------------------------------
// Description: 
// 
// brt_usb_enum_suspend_wake_test
// brt_usb_enum_suspend_out_test
// brt_usb_enum_bulk_loopback_test
// brt_usb_enum_isochronous_out_test
// brt_usb_enum_isochronous_in_test
// brt_usb_enum_interrupt_out_test
// brt_usb_enum_interrupt_in_test
// brt_usb_enum_bulk_out_test
// brt_usb_enum_bulk_in_test
// brt_usb_bad_address_test
// brt_usb_bad_packet_test
// brt_usb_bulk_out_random_stall_test
// brt_usb_bulk_out_random_nak_test
// brt_usb_control_in_random_nak_test
// brt_usb_bulk_in_random_stall_test
// brt_usb_bulk_in_random_nak_test
// brt_usb_nyet_ping_test
// brt_usb_enumeration_test
// brt_usb_base_test
//
//-----------------------------------------------------------------------------
// Known issues & omissions:
// 
// 
//-----------------------------------------------------------------------------
// Copyright © 2015 FTDI Ltd. All rights reserved.
//-----------------------------------------------------------------------------

class brt_usb_enumeration_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_enumeration_test)

  function new(string name = "brt_usb_enumeration_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", enumeration_sequence::type_id::get());
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.dev_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", brt_usb_device_response_sequence::type_id::get());
  endfunction

endclass

class brt_usb_nyet_ping_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_nyet_ping_test)

  function new(string name = "brt_usb_nyet_ping_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(int)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer", "bulk_out_size", 513);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", enum_bulk_out_sequence::type_id::get());
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.dev_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", nyet_ping_sequence::type_id::get());
  endfunction

endclass

class brt_usb_bulk_in_random_nak_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_bulk_in_random_nak_test)

  function new(string name = "brt_usb_bulk_in_random_nak_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", enum_bulk_in_sequence::type_id::get());
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.dev_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", random_data_ready_sequence::type_id::get());
    uvm_config_db#(brt_usb_transfer::transfer_type_e)	::set(this, "env.dev_agent.brt_usb_layering.xfer_sequencer.random_data_ready_sequence", "intended_tr", brt_usb_transfer::BULK_IN_TRANSFER);
  endfunction

endclass

class brt_usb_bulk_in_random_stall_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_bulk_in_random_stall_test)

  function new(string name = "brt_usb_bulk_in_random_stall_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", enum_bulk_in_sequence::type_id::get());
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.dev_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", random_stall_sequence::type_id::get());
  endfunction

endclass

class brt_usb_control_in_random_nak_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_control_in_random_nak_test)

  function new(string name = "brt_usb_control_in_random_nak_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(int)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer", "bulk_out_size", 1);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", enum_bulk_out_sequence::type_id::get());
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.dev_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", random_data_ready_sequence::type_id::get());
    uvm_config_db#(brt_usb_transfer::transfer_type_e)	::set(this, "env.dev_agent.brt_usb_layering.xfer_sequencer.random_data_ready_sequence", "intended_tr", brt_usb_transfer::CONTROL_TRANSFER);
  endfunction

endclass

class brt_usb_bulk_out_always_nak_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_bulk_out_always_nak_test)

  function new(string name = "brt_usb_bulk_out_always_nak_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(int)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer", "bulk_out_size", 4);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", enum_bulk_out_sequence::type_id::get());
    uvm_config_db#(int)	::set(this, "env.dev_agent.brt_usb_layering.xfer_sequencer", "number_of_nak", 2000);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.dev_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", random_nak_sequence::type_id::get());
  endfunction

endclass

class brt_usb_sof_on_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_sof_on_test)

  function new(string name = "brt_usb_sof_on_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_virtual_sequencer.main_phase", "default_sequence", enum_sof_on_vsequence::type_id::get());
  endfunction

endclass

class brt_usb_sof_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_sof_test)

  function new(string name = "brt_usb_sof_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_virtual_sequencer.main_phase", "default_sequence", enum_sof_vsequence::type_id::get());
  endfunction

endclass

class brt_usb_bulk_out_random_nak_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_bulk_out_random_nak_test)

  function new(string name = "brt_usb_bulk_out_random_nak_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(int)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer", "bulk_out_size", 513);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", enum_bulk_out_sequence::type_id::get());
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.dev_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", random_nak_sequence::type_id::get());
  endfunction

endclass

class brt_usb_bulk_out_random_stall_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_bulk_out_random_stall_test)

  function new(string name = "brt_usb_bulk_out_random_stall_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(int)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer", "bulk_out_size", 513);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", enum_bulk_out_sequence::type_id::get());
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.dev_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", random_stall_sequence::type_id::get());
  endfunction

endclass

class brt_usb_bad_packet_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_bad_packet_test)

  function new(string name = "brt_usb_bad_packet_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", enumeration_sequence::type_id::get());
    factory.set_type_override_by_type(brt_usb_packet::get_type(),brt_usb_bad_packet::get_type(),1);
  endfunction

endclass

class brt_usb_bad_address_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_bad_address_test)

  function new(string name = "brt_usb_bad_address_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", bad_address_sequence::type_id::get());
  endfunction

endclass

class brt_usb_enum_bulk_in_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_enum_bulk_in_test)

  function new(string name = "brt_usb_enum_bulk_in_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", enum_bulk_in_sequence::type_id::get());
  endfunction

endclass

class brt_usb_enum_bulk_out_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_enum_bulk_out_test)

  function new(string name = "brt_usb_enum_bulk_out_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", enum_bulk_out_sequence::type_id::get());
  endfunction

endclass

class brt_usb_enum_interrupt_in_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_enum_interrupt_in_test)

  function new(string name = "brt_usb_enum_interrupt_in_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", enum_interrupt_in_sequence::type_id::get());
  endfunction

endclass

class brt_usb_enum_interrupt_out_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_enum_interrupt_out_test)

  function new(string name = "brt_usb_enum_interrupt_out_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", enum_interrupt_out_sequence::type_id::get());
  endfunction

endclass

class brt_usb_enum_isochronous_in_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_enum_isochronous_in_test)

  function new(string name = "brt_usb_enum_isochronous_in_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", enum_isochronous_in_sequence::type_id::get());
  endfunction

endclass

class brt_usb_enum_isochronous_out_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_enum_isochronous_out_test)

  function new(string name = "brt_usb_enum_isochronous_out_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", enum_isochronous_out_sequence::type_id::get());
  endfunction

endclass

class brt_usb_enum_bulk_loopback_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_enum_bulk_loopback_test)

  function new(string name = "brt_usb_enum_bulk_loopback_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_layering.xfer_sequencer.main_phase", "default_sequence", enum_bulk_loopback_sequence::type_id::get());
  endfunction

endclass

class brt_usb_enum_testmode_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_enum_testmode_test)

  function new(string name = "brt_usb_enum_testmode_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_virtual_sequencer.main_phase", "default_sequence", enum_testmode_vsequence::type_id::get());
  endfunction

endclass

// Suspend and then Host Reset
class brt_usb_enum_suspend_reset_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_enum_suspend_reset_test)

  function new(string name = "brt_usb_enum_suspend_reset_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_virtual_sequencer.main_phase", "default_sequence", enum_suspend_reset_vsequence::type_id::get());
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.dev_agent.brt_usb_layering.link_service_sequencer.main_phase", "default_sequence", brt_usb_link_service_suspend_sequence::type_id::get());
  endfunction

endclass

// Suspend and then Host Resume
class brt_usb_enum_suspend_out_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_enum_suspend_out_test)

  function new(string name = "brt_usb_enum_suspend_out_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_virtual_sequencer.main_phase", "default_sequence", enum_suspend_resume_vsequence::type_id::get());
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.dev_agent.brt_usb_layering.link_service_sequencer.main_phase", "default_sequence", brt_usb_link_service_suspend_sequence::type_id::get());
  endfunction

endclass

// Suspend and then Device Remote Wakeup
class brt_usb_enum_suspend_wake_test extends brt_usb_base_test;
  `brt_component_utils(brt_usb_enum_suspend_wake_test)

  function new(string name = "brt_usb_enum_suspend_wake_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.host_agent.brt_usb_virtual_sequencer.main_phase", "default_sequence", enum_suspend_vsequence::type_id::get());
    uvm_config_db#(uvm_object_wrapper)	::set(this, "env.dev_agent.brt_usb_virtual_sequencer.main_phase", "default_sequence", suspend_wakeup_vsequence::type_id::get());
  endfunction

endclass

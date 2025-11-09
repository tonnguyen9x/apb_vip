class brt_usb_agent_wait_for_link_usb_20_state_virtual_sequence extends brt_sequence#(brt_usb_base_sequence_item);
  rand brt_usb_types::link20sm_state_e 	state;
  `brt_object_utils(brt_usb_agent_wait_for_link_usb_20_state_virtual_sequence)
  `brt_declare_p_sequencer(brt_usb_virtual_sequencer)
  function new(string name="brt_usb_agent_wait_for_link_usb_20_state_virtual_sequence");
    super.new(name);
  endfunction

  virtual task post_start();
    if (get_parent_sequence() == null && starting_phase != null) begin
      starting_phase.drop_objection(get_sequencer());
      end
   endtask

  virtual task pre_start();
    if (get_parent_sequence() == null && starting_phase != null) begin
      starting_phase.raise_objection(get_sequencer());
      end
  endtask

  virtual task body();
    if (state == brt_usb_types::SUSPEND || state == brt_usb_types::SUSPENDED)
      wait (p_sequencer.shared_status.link_usb_20_state == brt_usb_types::SUSPEND || p_sequencer.shared_status.link_usb_20_state == brt_usb_types::SUSPENDED);
    else
      wait (p_sequencer.shared_status.link_usb_20_state == state);
  endtask

endclass

class brt_usb_virtual_sequence extends brt_sequence;

  `brt_object_utils(brt_usb_virtual_sequence)
  `brt_declare_p_sequencer(brt_usb_virtual_sequencer)
  function new(string name="brt_usb_virtual_sequence");
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

endclass

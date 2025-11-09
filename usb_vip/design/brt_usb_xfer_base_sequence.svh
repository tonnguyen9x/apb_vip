class brt_usb_xfer_base_sequence extends brt_sequence#(brt_usb_transfer);

  // data payload generation
  bit[7:0]     data8[];

  `brt_object_utils(brt_usb_xfer_base_sequence)
  `brt_declare_p_sequencer(brt_usb_transfer_sequencer)
  
  function new(string name="brt_usb_xfer_base_sequence");
    super.new(name);
    data8 = new [`DATA8_SIZE];
    for (int i=0; i < `DATA8_SIZE/2; i++) begin
        data8[2*i]   = i/256;
        data8[2*i+1] = i%256;
    end
  endfunction

  virtual task pre_start();
    if (get_parent_sequence() == null && starting_phase != null) begin
      starting_phase.raise_objection(get_sequencer());
      end
  endtask


  virtual task post_start();
    if (get_parent_sequence() == null && starting_phase != null) begin
      starting_phase.drop_objection(get_sequencer());
      end
   endtask

endclass

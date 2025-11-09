class brt_usb_device_response_sequence extends brt_sequence#(brt_usb_transfer);

  `brt_object_utils(brt_usb_device_response_sequence)
  `brt_declare_p_sequencer(brt_usb_transfer_sequencer)

  function new(string name="brt_usb_device_response_sequence");
    super.new(name);
  endfunction
  
  virtual task body();
    brt_usb_transfer a; 

    forever begin
      p_sequencer.prot.transfer_out_port.peek(a);
      $display("Time: %0t, peek a = %s", $time, a.sprint_trace());
      foreach(a.payload.data[i]) a.payload.data[i] = 'hbb;

      end

  endtask

endclass
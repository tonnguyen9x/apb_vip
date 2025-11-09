class brt_usb_base_random_isochronous_xfer_sequence extends brt_usb_base_random_xfer_sequence;

    constraint type_constr {
      ttype inside {brt_usb_transfer::ISOCHRONOUS_IN_TRANSFER, brt_usb_transfer::ISOCHRONOUS_OUT_TRANSFER};
        }

    `brt_object_utils_begin(brt_usb_base_random_isochronous_xfer_sequence)
    `brt_object_utils_end

    virtual function void create_request();
        `brt_info("body",$sformatf("create request payload_size %0d", payload_size), UVM_HIGH);
        if (!req.randomize() with {
                                  if (ep_num >=0) {
                                      endpoint_number           == ep_num;
                                  }
                                  xfer_type                     == ttype; 
                                  // payload  size
                                  if (payload_size >= 0) {
                                      payload_intended_byte_count   == payload_size;
                                  }
                                  else {
                                      if (req.ep_cfg == null) {
                                        payload_intended_byte_count   inside {[0:3*1024]};
                                      }
                                      else {
                                        payload_intended_byte_count   inside {[0:(req.ep_cfg.max_burst_size+1)*req.ep_cfg.max_burst_size]};
                                      }
                                  }
                                  if (ttype ==  brt_usb_transfer::BULK_OUT_TRANSFER && !rand_data_en) {
                                      foreach (payload.data[i]){
                                          payload.data[i] == data8[i%data8.size()];
                                      }
                                  }
        }) begin
         
            if (!randomize_checker) begin
              `brt_fatal("body", "randomize error");   // Default
            end
            else begin
              `brt_warning("body", "randomize checker: constraint does not hold");
            end
        end

        // Check payload size
        req.find_ep_cfg();
        if (req.payload_intended_byte_count > ((req.ep_cfg.max_burst_size+1)*req.ep_cfg.max_packet_size)) begin  // Over range
            if (payload_size > 0) begin
                `uvm_fatal (get_name(), $sformatf ("User used payload size for EP %d ISO is too large: payload_size %d, ESITPayload %d"
                                                   ,req.endpoint_number, payload_size
                                                   ,(req.ep_cfg.max_burst_size+1)*req.ep_cfg.max_packet_size))
            end
            else begin
                // Recursive
                create_request();
            end
        end
    endfunction


    function new(string name="brt_usb_base_random_isochronous_xfer_sequence");
      super.new(name);
    endfunction : new

endclass : brt_usb_base_random_isochronous_xfer_sequence 

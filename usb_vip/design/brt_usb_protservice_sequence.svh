class brt_usb_protservice_sequence extends brt_sequence #(brt_usb_protocol_service);
  bit is_host=0;
  //bit enable_tx_sof=0;
  `brt_object_utils(brt_usb_protservice_sequence)
  
  function new(string name="");
    super.new(name);
  endfunction

  brt_usb_protocol_service_sequencer up_sequencer; 

  virtual task body();
    brt_usb_endpoint_status est;
    brt_usb_protocol_service pserv_req;
    brt_usb_protocol_service pserv_rsp;

    forever begin
      up_sequencer.get(pserv_req);

      `brt_info(get_name(), $psprintf("Packet translate execute new request %s \n %s", pserv_req.sprint(),pserv_req.protocol_command_type.name()), UVM_LOW)


      if (pserv_req.service_type == brt_usb_protocol_service::CMD) begin
        if (pserv_req.protocol_command_type == brt_usb_protocol_service::USB_CLEAR_EP_HALT) begin
          `brt_info(get_name(), $psprintf("CLEAR_EP_HALT %s", up_sequencer.shared_status.sprint()), UVM_LOW)
          if (is_host) begin 
            foreach(up_sequencer.shared_status.remote_device_status[0].endpoint_status[i]) begin
              est = up_sequencer.shared_status.remote_device_status[0].endpoint_status[i];

              if ((pserv_req.endpoint_number == 0 && i == 1)  ||
                  (pserv_req.endpoint_number > 0 && (pserv_req.endpoint_number*2 + pserv_req.direction) == i)
                  ) begin
                est.ep_state = brt_usb_types::EP_ENABLE;
              end
            end // for
          end
        end
        else begin
            `brt_fatal (get_name(), $psprintf ("Not support this command: %s %s", pserv_req.service_type.name(),pserv_req.protocol_command_type.name()))
        end
      end
      else if (pserv_req.service_type == brt_usb_protocol_service::SOF) begin
        if (pserv_req.protocol_20_command_type == brt_usb_protocol_service::USB_20_SOF_ON) begin
          up_sequencer.shared_status.local_host_status.enable_tx_sof=1;
        end
        else if (pserv_req.protocol_20_command_type == brt_usb_protocol_service::USB_20_SOF_OFF) begin
          up_sequencer.shared_status.local_host_status.enable_tx_sof=0;
        end
        else begin
            `brt_fatal (get_name(), $psprintf ("Not support this command: %s %s", pserv_req.service_type.name(),pserv_req.protocol_20_command_type.name()))
        end
      end
      else begin
          `brt_fatal (get_name(), $psprintf ("Not support this command: %s %s", pserv_req.service_type.name(),pserv_req.protocol_20_command_type.name()))
      end


      $cast(pserv_rsp, pserv_req.clone());
      pserv_rsp.set_id_info(pserv_req);
      up_sequencer.put(pserv_rsp);
      end
  endtask

endclass

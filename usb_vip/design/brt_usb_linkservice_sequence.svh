class brt_usb_linkservice_sequence extends brt_sequence #(brt_usb_link_service);

  event wait_tmode_pkt_e;

  `brt_object_utils(brt_usb_linkservice_sequence)
  
  function new(string name="");
    super.new(name);
  endfunction

  brt_usb_link_service_sequencer up_sequencer; 

  virtual task body();
    brt_usb_link_service lserv_req;
    brt_usb_link_service lserv_rsp;

    forever begin
      up_sequencer.get(lserv_req);

      `brt_info(get_name(), $psprintf("Packet translate execute new request %s", lserv_req.sprint()), UVM_LOW)
      //if (lserv_req.service_type == brt_usb_link_service::LINK_COMMAND) begin
      //  if (lserv_req.link_20_command_type == brt_usb_link_service::USB_20_SET_PORT_SUSPEND) begin
      //    up_sequencer.link.enable_suspend_timer = 1;
      //    end
      //  if (lserv_req.link_20_command_type == brt_usb_link_service::USB_20_CLEAR_PORT_SUSPEND) begin
      //    `brt_info(get_name(), $psprintf("tell driver to do resume"), UVM_LOW)
      //    -> up_sequencer.link.execute_resume_e;
      //    end
      //  end
      //else if (lserv_req.service_type == brt_usb_link_service::LINK_20_PORT_COMMAND) begin
      //  if (lserv_req.link_20_command_type == brt_usb_link_service::USB_20_PORT_RESET) begin
      //    -> up_sequencer.link.do_bus_reset_e;
      //    @ (up_sequencer.link.do_bus_reset_done_e);
      //    end
      //  else if (lserv_req.link_20_command_type == brt_usb_link_service::USB_20_CLEAR_PORT_SUSPEND) begin
      //    `brt_info(get_name(), $psprintf("tell driver to do resume"), UVM_LOW)
      //    -> up_sequencer.link.execute_resume_e;
      //    end
      //  else if (lserv_req.link_20_command_type == brt_usb_link_service::USB_20_PORT_TEST_MODE_TEST_PACKET) begin
      //    -> wait_tmode_pkt_e;
      //    end
      //  end

      if (lserv_req.service_type == brt_usb_link_service::LINK_20_PORT_COMMAND) begin
        if (lserv_req.link_20_command_type == brt_usb_link_service::USB_20_PORT_RESET) begin
          -> up_sequencer.link.do_bus_reset_e;
          @ (up_sequencer.link.do_bus_reset_done_e);
          end
        else if (lserv_req.link_20_command_type == brt_usb_link_service::USB_20_SET_PORT_SUSPEND) begin
          up_sequencer.link.enable_suspend_timer = 1;
        end
        else if (lserv_req.link_20_command_type == brt_usb_link_service::USB_20_CLEAR_PORT_SUSPEND) begin
          `brt_info(get_name(), $psprintf("tell driver to do resume"), UVM_LOW)
          -> up_sequencer.link.execute_resume_e;
        end
        else if (lserv_req.link_20_command_type == brt_usb_link_service::USB_20_PORT_TEST_MODE_TEST_PACKET) begin
          -> wait_tmode_pkt_e;
        end
      end

      $cast(lserv_rsp, lserv_req.clone());
      lserv_rsp.set_id_info(lserv_req);
      up_sequencer.put(lserv_rsp);
      end
  endtask

endclass

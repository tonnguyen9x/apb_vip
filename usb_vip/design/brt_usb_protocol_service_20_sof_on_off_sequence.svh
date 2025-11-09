class brt_usb_protocol_service_20_sof_on_off_sequence extends brt_sequence#(brt_usb_protocol_service);
  rand bit   sof_on;
  brt_usb_config cfg;

  `brt_object_utils(brt_usb_protocol_service_20_sof_on_off_sequence)

  function new(string name="brt_usb_protocol_service_20_sof_on_off_sequence");
    super.new(name);
  endfunction

  virtual task body();
    brt_usb_protocol_service req_serv;
    brt_usb_protocol_service rsp_serv;

    `brt_info(get_name(), $psprintf("body: ", this.sprint()), UVM_LOW)
    req_serv = brt_usb_protocol_service::type_id::create("req_serv");
    start_item(req_serv);
    req_serv.service_type 					= brt_usb_protocol_service::SOF;
    if (sof_on) begin
        req_serv.protocol_20_command_type 	= brt_usb_protocol_service::USB_20_SOF_ON;
    end
    else begin
        req_serv.protocol_20_command_type 	= brt_usb_protocol_service::USB_20_SOF_OFF;
    end
    finish_item(req_serv);
    get_response(rsp_serv);
  endtask

endclass:

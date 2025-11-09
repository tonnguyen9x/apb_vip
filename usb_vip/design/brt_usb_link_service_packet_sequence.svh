class brt_usb_link_service_packet_sequence extends brt_sequence#(brt_usb_link_service);
  brt_usb_config cfg;
  `brt_object_utils(brt_usb_link_service_packet_sequence)

  function new(string name="brt_usb_link_service_packet_sequence");
    super.new(name);
  endfunction

  virtual task body();
    brt_usb_link_service req_serv;
    brt_usb_link_service rsp_serv;

    `brt_info(get_name(), $psprintf("body: ", this.sprint()), UVM_LOW)
    req_serv = brt_usb_link_service::type_id::create("req_serv");
    start_item(req_serv);
    req_serv.service_type 				= brt_usb_link_service::LINK_20_PORT_COMMAND;
    req_serv.link_20_command_type 	= brt_usb_link_service::USB_20_PORT_TEST_MODE_TEST_PACKET;
    finish_item(req_serv);
    get_response(rsp_serv);
  endtask
endclass

class brt_usb_link_service_reset_sequence extends brt_sequence#(brt_usb_link_service);
  brt_usb_config cfg;
  `brt_object_utils(brt_usb_link_service_reset_sequence)

  function new(string name="brt_usb_link_service_reset_sequence");
    super.new(name);
  endfunction

  virtual task body();
    brt_usb_link_service req_serv;
    brt_usb_link_service rsp_serv;

    `brt_info(get_name(), $psprintf("body: ", this.sprint()), UVM_LOW)
    req_serv = brt_usb_link_service::type_id::create("req_serv");
    start_item(req_serv);
    req_serv.service_type 				= brt_usb_link_service::LINK_20_PORT_COMMAND;
    req_serv.link_20_command_type 	= brt_usb_link_service::USB_20_PORT_RESET;
    finish_item(req_serv);
    get_response(rsp_serv);
  endtask
endclass

class brt_usb_link_service_suspend_sequence extends brt_sequence#(brt_usb_link_service);

  brt_usb_config cfg;

  `brt_object_utils(brt_usb_link_service_suspend_sequence)

  function new(string name="brt_usb_link_service_suspend_sequence");
    super.new(name);
  endfunction

  virtual task body();
    brt_usb_link_service req_serv;
    brt_usb_link_service rsp_serv;

    `brt_info(get_name(), $psprintf("body: ", this.sprint()), UVM_LOW)
    req_serv = brt_usb_link_service::type_id::create("req_serv");
    start_item(req_serv);
    req_serv.service_type 				= brt_usb_link_service::LINK_20_PORT_COMMAND;
    req_serv.link_20_command_type 	= brt_usb_link_service::USB_20_SET_PORT_SUSPEND;
    finish_item(req_serv);
    get_response(rsp_serv);
  endtask

endclass

class brt_usb_link_service_clear_suspend_sequence extends brt_sequence#(brt_usb_link_service);

  brt_usb_config cfg;

  `brt_object_utils(brt_usb_link_service_clear_suspend_sequence)

  function new(string name="brt_usb_link_service_clear_suspend_sequence");
    super.new(name);
  endfunction

  virtual task body();
    brt_usb_link_service req_serv;
    brt_usb_link_service rsp_serv;

    `brt_info(get_name(), $psprintf("body: ", this.sprint()), UVM_LOW)
    req_serv = brt_usb_link_service::type_id::create("req_serv");
    start_item(req_serv);
    req_serv.service_type 				= brt_usb_link_service::LINK_20_PORT_COMMAND;
    req_serv.link_20_command_type 	= brt_usb_link_service::USB_20_CLEAR_PORT_SUSPEND;
    finish_item(req_serv);
    get_response(rsp_serv);
  endtask

endclass

class brt_usb_link_service_device_remote_wakeup_sequence extends brt_usb_link_service_clear_suspend_sequence;
  `brt_object_utils(brt_usb_link_service_device_remote_wakeup_sequence)

  function new(string name="brt_usb_link_service_device_remote_wakeup_sequence");
    super.new(name);
  endfunction
endclass

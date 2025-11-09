class in_token_packet_sequence extends brt_usb_packet_base_sequence;
  rand bit[10:0] 	frame_num=0;
  brt_usb_config cfg;
  brt_usb_agent 					l_agent;
  brt_sequencer_base 		seqr_base;
  brt_usb_packet_sequencer		seqr;

  `brt_object_utils(in_token_packet_sequence)

  function new(string name="sof_packet_sequence");
    super.new(name);
  endfunction

  virtual task wait_enabled();
    string scope_name;
    `brt_info("body",$sformatf("Running Sequence: %s", this.sprint()), UVM_HIGH);
    seqr_base = get_sequencer();
    if (!$cast(seqr, seqr_base)) begin `brt_fatal("body", "cast failed") end
    else if (!$cast(l_agent, seqr.find_first_agent(this)) || (l_agent == null)) begin
      `brt_fatal("body","Agent handle is null")
      end
    `brt_info("body", $sformatf("link status %s",l_agent.shared_status.sprint()), UVM_LOW)
    wait (l_agent.shared_status.link_usb_20_state == brt_usb_types::ENABLED);

    if (scope_name == "") begin  scope_name = get_sequencer().get_full_name(); end
    if (!uvm_config_db#(brt_usb_config)::get(null, scope_name, "seq_cfg", cfg )) begin
      `brt_error("body", "can not get configuration");
      end
  endtask

  virtual task body();
    brt_usb_packet req_pkt, rsp_pkt;
    wait_enabled();
    req_pkt = brt_usb_packet::type_id::create();                                                                     
    start_item(req_pkt); 
    req_pkt.cfg = this.cfg;
    req_pkt.need_rsp = 1;
    if (!req_pkt.randomize() with {pid_name == brt_usb_packet::IN; endp == 3; func_address == cfg.remote_device_cfg[0].device_address;})
      `brt_fatal(get_name(), "randomize error")

    finish_item(req_pkt); 
    get_response(rsp_pkt);
    `brt_info(get_name(), $psprintf("Done sending In Token and received response packet %s", rsp_pkt.sprint_trace()), UVM_LOW)
  endtask
endclass

class sof_packet_sequence extends brt_usb_packet_base_sequence;
  rand bit[10:0] 	frame_num=0;
  brt_usb_config cfg;

  `brt_object_utils(sof_packet_sequence)

  function new(string name="sof_packet_sequence");
    super.new(name);
  endfunction

  //function void pre_randomize();
  //endfunction

  virtual task body();
    brt_usb_packet req_pkt, rsp_pkt;
    bit[10:0] 	frame_number;
    frame_number = this.frame_num;
    req_pkt = brt_usb_packet::type_id::create();                                                                     
    start_item(req_pkt); 
    if (!req_pkt.randomize() with {pid_name == brt_usb_packet::SOF; frame_num == frame_number;})
      `brt_fatal(get_name(), "randomize error")
    finish_item(req_pkt); 
    get_response(rsp_pkt);
    `brt_info(get_name(), $psprintf("Done sending SOF "), UVM_LOW)
  endtask

endclass



typedef class brt_usb_protocol_callbacks;

class brt_usb_protocol extends brt_component;
  brt_usb_packet    pkt_q[$];  // Received packet is stored here

  // Packet from driver
  brt_blocking_put_imp  #(brt_usb_packet, brt_usb_protocol)     p_brt_usb_pkt_imp;

  // Transfer from ulayer
  brt_blocking_peek_port #(brt_usb_transfer)                    transfer_out_port;

  // Packet from monitor
  brt_analysis_imp #(brt_usb_packet, brt_usb_protocol)          ap_packet_imp;

  `uvm_register_cb(brt_usb_protocol, brt_usb_protocol_callbacks)
  brt_usb_config cfg;

  `brt_component_utils(brt_usb_protocol)

  function new(string name, brt_component parent);
    super.new(name, parent);
    transfer_out_port = new("transfer_out_port", this);
    p_brt_usb_pkt_imp = new("p_brt_usb_pkt_imp", this);
    ap_packet_imp     = new("ap_packet_imp", this);
  endfunction

  function void build_phase (brt_phase phase);
    super.build_phase(phase);
  endfunction

  task put (brt_usb_packet rsp_pkt);
    `brt_info (get_name(),"protocol get a packet and put to queue",UVM_HIGH)
    pkt_q.push_back(rsp_pkt);
  endtask

  function void write(brt_usb_packet t);
      packet_monitor (t);
  endfunction

  virtual function void pre_transfer_out_port_put (int chan_id , brt_usb_transfer t , ref bit drop);
    `uvm_do_callbacks(brt_usb_protocol, brt_usb_protocol_callbacks, pre_transfer_out_port_put(this, chan_id, t, drop))
  endfunction

  virtual function void transfer_begin(brt_usb_transfer t);
    `uvm_do_callbacks(brt_usb_protocol, brt_usb_protocol_callbacks, transfer_begin(this, t))
  endfunction

  virtual function void transfer_monitor(brt_usb_transfer t);
    `uvm_do_callbacks(brt_usb_protocol, brt_usb_protocol_callbacks, transfer_monitor(this, t))
  endfunction

  virtual function void transfer_ended(brt_usb_transfer t);
    `uvm_do_callbacks(brt_usb_protocol, brt_usb_protocol_callbacks, transfer_ended(this, t))
  endfunction

  virtual function void packet_trace(brt_usb_transfer t, brt_usb_packet p);
    `uvm_do_callbacks(brt_usb_protocol, brt_usb_protocol_callbacks, packet_trace(this, t, p))
  endfunction

  virtual function void pre_handshake(brt_usb_packet p, ref bit mod);
    `uvm_do_callbacks(brt_usb_protocol, brt_usb_protocol_callbacks, pre_handshake(this, p, mod))
  endfunction

  virtual function void pre_data_ready(brt_usb_packet p, ref bit ready, ref bit stall);
    `uvm_do_callbacks(brt_usb_protocol, brt_usb_protocol_callbacks, pre_data_ready(this, p, ready, stall))
  endfunction

  virtual function void post_brt_usb_20_packet_in_port_get(int chan_id, brt_usb_packet p, ref bit drop);
    `uvm_do_callbacks(brt_usb_protocol, brt_usb_protocol_callbacks, post_brt_usb_20_packet_in_port_get(this, chan_id, p, drop))
  endfunction

  virtual function void pre_brt_usb_20_packet_out_port_put(brt_usb_transfer t, brt_usb_packet p, ref bit drop);
    `uvm_do_callbacks(brt_usb_protocol, brt_usb_protocol_callbacks, pre_brt_usb_20_packet_out_port_put(this, t, p, drop))
  endfunction

  virtual function void packet_monitor(brt_usb_packet p);
    `uvm_do_callbacks(brt_usb_protocol, brt_usb_protocol_callbacks, packet_monitor(this, p))
  endfunction

endclass

class brt_usb_link extends brt_component;

  brt_usb_config cfg;
  brt_usb_status shared_status;

  bit enable_suspend_timer = 0;
  event do_bus_reset_e;
  event do_bus_reset_done_e;
  event execute_resume_e;
  event execute_resume_done_e;

  brt_blocking_put_imp  #(brt_usb_data, brt_usb_link)   imp_brt_usb_data_port;
  brt_blocking_put_port #(brt_usb_packet)               out_brt_usb_pkt_port;

  `brt_component_utils(brt_usb_link)

  function new(string name, brt_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase (brt_phase phase);
    super.build_phase(phase);
    imp_brt_usb_data_port = new("imp_brt_usb_data_port", this);
    out_brt_usb_pkt_port  = new("out_brt_usb_pkt_port", this); 
  endfunction

  virtual task put (brt_usb_data rsp_data);
    static bit          ext_pkt;
    brt_usb_packet      rsp_pkt;

    rsp_pkt = brt_usb_packet::type_id::create("rsp_pkt");
    // LPM
    if (ext_pkt == 1'b1) begin
        rsp_pkt.is_lpm = 1'b1;
        ext_pkt = 1'b0;
    end
    // unpack
    if (rsp_data.nrzi_data_q.size()) begin
      rsp_data.do_data_decoding();
      void'(rsp_pkt.unpack(rsp_data.data));
    end
    // EXT packet
    if (rsp_pkt.pid_name == brt_usb_packet::EXT) begin
        ext_pkt = 1;
    end

    `brt_info(get_name(), $psprintf("received packet from driver %s", rsp_pkt.sprint()), UVM_HIGH)

    // SOF EOP is special case. It is 40 symbols without a transition, so ignore the bit stuff error for now (TBD check during decoding).
    if (rsp_data.bit_stuff_err && rsp_pkt.pid_name != brt_usb_packet::SOF) begin
      `brt_error(get_name, "bit stuffing error")
      rsp_pkt.pkt_err = 1;
      rsp_pkt.bit_stuff_err = 1;
    end
    out_brt_usb_pkt_port.put (rsp_pkt); 
  endtask

endclass

class brt_usb_physical extends brt_component;

  brt_usb_config cfg;
  `brt_component_utils(brt_usb_physical)

  function new(string name, brt_component parent);
    super.new(name, parent);
  endfunction

endclass

class brt_usb_data_sequencer extends brt_sequencer #(brt_usb_data);

  brt_usb_agent     agt;
  brt_usb_config    cfg;
  brt_usb_physical  phys;

  `brt_component_utils(brt_usb_data_sequencer)

  function new(string name, brt_component parent);
    super.new(name, parent);
  endfunction

  virtual function void get_cfg(output brt_usb_config cfg);
    cfg = this.cfg;
  endfunction

endclass

class brt_usb_packet_sequencer extends brt_sequencer #(brt_usb_packet);

  brt_usb_agent  	agt;
  brt_usb_config cfg;
  brt_usb_link link;
  brt_usb_protocol prot;

  `brt_component_utils(brt_usb_packet_sequencer)

  function new(string name, brt_component parent);
    super.new(name, parent);
  endfunction

  virtual function void get_cfg(output brt_usb_config cfg);
    cfg = this.cfg;
  endfunction

  virtual function brt_usb_agent find_first_agent(brt_object c);
    return agt;
  endfunction

endclass

class brt_usb_transfer_sequencer extends brt_sequencer #(brt_usb_transfer);

  brt_usb_protocol prot;
  brt_usb_config 	cfg;
  brt_usb_agent  	agt;
  brt_usb_status  	shared_status;
  brt_blocking_peek_imp #(brt_usb_transfer, brt_usb_transfer_sequencer) out;
  `brt_sequencer_utils(brt_usb_transfer_sequencer)

  event peek_available_e;
  brt_usb_transfer tr;
  bit user_peeking=0;

  function new(string name, brt_component parent);
    super.new(name, parent);
    out = new("out", this);
  endfunction

  virtual task transfer_ready(brt_usb_transfer t, output bit mod /*1: user maybe modify the transfer*/);
    tr = t;
    user_peeking = 0;
    -> peek_available_e;
    if (user_peeking) begin
      mod = 1;
      `brt_info(get_name(), $psprintf("somebody is peeking the transfer!!!"), UVM_HIGH)
      end
    user_peeking = 0;
  endtask

  virtual task peek(output brt_usb_transfer t);
    @peek_available_e;
    t = tr;
    `brt_info(get_name(), $psprintf("peeking the transfer %s", t.sprint_trace()), UVM_HIGH)
    user_peeking = 1;
  endtask

  virtual function void get_cfg(output brt_usb_config cfg);
    cfg = this.cfg;
  endfunction

  virtual function brt_usb_agent find_first_agent(brt_object c);
    return agt;
  endfunction

endclass

class brt_usb_physical_service_sequencer extends brt_sequencer #(brt_usb_physical_service);

  brt_usb_config cfg;
  `brt_component_utils(brt_usb_physical_service_sequencer)

  function new(string name, brt_component parent);
    super.new(name, parent);
  endfunction

  virtual function void get_cfg(output brt_usb_config cfg);
    cfg = this.cfg;
  endfunction

endclass

class brt_usb_link_service_sequencer extends brt_sequencer #(brt_usb_link_service);

  brt_usb_agent  	agt;
  brt_usb_config 	cfg;
  brt_usb_link 		link;
  `brt_component_utils(brt_usb_link_service_sequencer)

  function new(string name, brt_component parent);
    super.new(name, parent);
  endfunction

  virtual function void get_cfg(output brt_usb_config cfg);
    cfg = this.cfg;
  endfunction

  virtual function brt_usb_agent find_first_agent(brt_object c);
    return agt;
  endfunction

endclass

class brt_usb_protocol_service_sequencer extends brt_sequencer #(brt_usb_protocol_service);

  brt_usb_agent  agt;
  brt_usb_config cfg;
  brt_usb_status shared_status;
  `brt_component_utils(brt_usb_protocol_service_sequencer)

  function new(string name, brt_component parent);
    super.new(name, parent);
  endfunction

  virtual function void get_cfg(output brt_usb_config cfg);
    cfg = this.cfg;
  endfunction

  virtual function brt_usb_agent find_first_agent(brt_object c);
    return agt;
  endfunction

endclass

class brt_usb_virtual_sequencer extends brt_sequencer #(brt_usb_base_sequence_item);

  brt_usb_config 								cfg;
  brt_usb_agent  								agt;
  brt_usb_transfer_sequencer 				xfer_sequencer;
  brt_usb_packet_sequencer      			brt_usb_20_pkt_sequencer;
  brt_usb_data_sequencer  					brt_usb_20_data_sequencer;

  brt_usb_link_service_sequencer  		link_service_sequencer;
  brt_usb_protocol_service_sequencer 	prot_service_sequencer;
  brt_usb_physical_service_sequencer  	brt_usb_20_phys_service_sequencer;
  brt_usb_status                        shared_status;

  `brt_component_utils(brt_usb_virtual_sequencer)

  function new(string name, brt_component parent);
    super.new(name, parent);
  endfunction

  virtual function void get_cfg(output brt_usb_config cfg);
    cfg = this.cfg;
  endfunction

  virtual function void display_msg();
    $display("Test....\n\n");
  endfunction

  virtual function brt_usb_agent find_first_agent(brt_object c);
    return agt;
  endfunction

endclass

class brt_usb_system_virtual_sequencer extends brt_sequencer #(brt_usb_base_sequence_item);

  brt_usb_config cfg;
  brt_usb_virtual_sequencer 	host_virt_sequncer;
  //brt_usb_virtual_sequencer 	dev_virt_sequncer;

  `brt_component_utils(brt_usb_system_virtual_sequencer)

  function new(string name, brt_component parent);
    super.new(name, parent);
  endfunction

  virtual function void get_cfg(output brt_usb_config cfg);
    cfg = this.cfg;
  endfunction

endclass

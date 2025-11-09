// translate brt_usb packet to brt_usb data
class brt_usb_packet2data_sequence extends brt_sequence #(brt_usb_data);
  byte unsigned         bytestream[];
  bit                   bitstream[];
  brt_usb_data          req_data;
  brt_usb_data          rsp_data;
  `brt_object_utils(brt_usb_packet2data_sequence)
  
  function new(string name="");
    super.new(name);
  endfunction

  //brt_sequencer #(brt_usb_packet) up_sequencer; 
  brt_usb_packet_sequencer up_sequencer; 

  virtual task translate_and_send(brt_usb_packet p, brt_usb_packet rspp);
    // Inser bit stuff error
    if (p.bit_stuff_err) begin
        if (p.data.size() == 0) begin
            p.data = new[1];
            p.data[0] = 'hfe;
            p.gen_data_crc16;
        end
        else begin
            foreach (p.data[i]) begin
                p.data[i] = 'h00;
            end
            p.data[p.bit_stuff_pos] = 'hfe;
            p.gen_data_crc16;
        end
    end
    void'(p.pack(bitstream));
    req_data = brt_usb_data::type_id::create();
    // Start
    start_item(req_data);
    if (!req_data.randomize())  // eop_length ??
      `brt_fatal(get_name(), "randomize error")
    req_data.data          = bitstream;
    req_data.need_rsp      = p.need_rsp;
    req_data.need_timeout  = p.need_timeout;
    req_data.num_kj        = p.num_kj;
    req_data.eop_length    = p.eop_length;
    req_data.bit_stuff_err = p.bit_stuff_err;
    req_data.is_sof        = p.pid_name == brt_usb_packet::SOF;
    req_data.drop          = p.drop;
    //`brt_info("USER_TRACE", $psprintf("%s", p.sprint_trace(2)), UVM_LOW)
    `brt_info("host send", $psprintf("%s", p.sprint_trace(2)), UVM_LOW)
    // NRZI
    req_data.do_data_encoding();
    // Send
    finish_item(req_data);
    get_response(rsp_data);
    
    rspp.is_timeout =  rsp_data.is_timeout;
    if (rsp_data.nrzi_data_q.size()) begin
      rsp_data.do_data_decoding();
      void'(rspp.unpack(rsp_data.data));
      end

    
    `brt_info(get_name(), "Packet translate data get response", UVM_HIGH)
    if (rsp_data.bit_stuff_err) begin
      `brt_fatal(get_name, "bit stuffing error")
      rspp.pkt_err = 1;
      end
  endtask

  virtual task ask_driver(brt_usb_packet p, brt_usb_packet pr);
    req_data = brt_usb_data::type_id::create();
    start_item(req_data);

    req_data.tellme = 1; 
    //req_data.need_rsp     = p.need_rsp;
    //req_data.need_timeout = p.need_timeout;

    finish_item(req_data);
    get_response(rsp_data);

    if (rsp_data.nrzi_data_q.size()) begin
      rsp_data.do_data_decoding();
      void'(pr.unpack(rsp_data.data));
      end

    `brt_info(get_name(), $psprintf("received packet from driver %s", pr.sprint()), UVM_HIGH)
    if (rsp_data.bit_stuff_err) begin
      `brt_fatal(get_name, "bit stuffing error")
      end

  endtask

  virtual task body();
    bit                 drop;
    brt_usb_packet     req_tpkt;
    brt_usb_packet     rsp_tpkt;

    forever begin
      up_sequencer.get(req_tpkt);
      `brt_info(get_name(), "Packet translate execute new request", UVM_HIGH)

      $cast(rsp_tpkt, req_tpkt.clone());
      rsp_tpkt.set_id_info(req_tpkt);
      rsp_tpkt.data.delete();

      if (!req_tpkt.tellme) begin  // Active mode, host
        translate_and_send(req_tpkt, rsp_tpkt);
      end
      else begin  // Passive mode, dev
        ask_driver(req_tpkt, rsp_tpkt);
      end
        
      //DD Callback when receiving a packet
      if (req_tpkt.tellme || req_tpkt.need_rsp && !req_tpkt.need_timeout) begin
        up_sequencer.prot.post_brt_usb_20_packet_in_port_get(0, rsp_tpkt, drop);
      end

      `brt_info(get_name(), "Packet translate put response", UVM_HIGH)
      up_sequencer.put(rsp_tpkt);
      end
  endtask

endclass:brt_usb_packet2data_sequence


/*

                     USB UVM Layering
         PROTOCOL                          LINK            

  +----------------+                 +------------------+
  | packet2xfer    |                 | data2packet      |              
  |   monitor      |O-------<------[]|   monitor        |O-------------------+
  |                |                 |                  |                    |
  +----------------+                 +------------------+                    |
                                                                             |
                                                                             |
                                                                             A
                                                                             |
                                                                             |
  +----------------+                 +------------------+                    |
  | xfer_sequencer |                 | packet sequencer |                    |
  |                |--> prot2link -->|                  |--> link2phys       |
  |                |    translate    |                  |    translate       |
  +----------------+    seq          +------------------+    seq             |
                                                             |               |  
                                                             |               |
                                       +---------------------+               |
                                       |                                     |
           + ---------------------------------+                              |
           |        USB PHYS agent     |      |                              |
           |                           V      |                              |
           |                      Sequencer   |                              |
           |                                  |                              |
           |   Driver             Monitor     |[]----------------------------+
           +----------------------------------+
                    |      |      |
            UTMI IF / USB2 Ser IF / USB3 Ser IF


// 
*/

typedef class brt_usb_packet2data_sequence;
typedef class brt_usb_xfer2packet_sequence;
typedef class brt_usb_layering;


typedef struct packed unsigned {
  bit[7:0]  bmRequestType;
  bit[7:0]  bRequest;
  bit[7:0]  wValue_low;
  bit[7:0]  wValue_high;
  bit[7:0]  wIndex_low;
  bit[7:0]  wIndex_high;
  bit[7:0]  wLength_low;
  bit[7:0]  wLength_high;
  } setup_data_s;

typedef union packed {
  setup_data_s sd_data;
  bit[63:0] 	sd_bytes;
  } setup_data_i;


class brt_usb_dev_packet2data_sequence extends brt_usb_packet2data_sequence;
  `brt_object_utils(brt_usb_dev_packet2data_sequence)
  
  function new(string name="");
    super.new(name);
  endfunction

  virtual task body();
    bit 				drop;
    brt_usb_packet 	req_tpkt;
    brt_usb_packet 	rsp_tpkt;

   
    forever begin
      up_sequencer.get(req_tpkt);
      drop = 0;

      $cast(rsp_tpkt, req_tpkt.clone());
      rsp_tpkt.set_id_info(req_tpkt); rsp_tpkt.data.delete();
      if (req_tpkt.tellme) begin
        ask_driver(req_tpkt, rsp_tpkt);
        //up_sequencer.prot.post_brt_usb_20_packet_in_port_get(0, rsp_tpkt, drop);
      end
      else begin
        translate_and_send(req_tpkt, rsp_tpkt);
      end 

      up_sequencer.put(rsp_tpkt);
      end
  endtask

  virtual task ask_driver(brt_usb_packet p, brt_usb_packet pr);
    req_data = brt_usb_data::type_id::create();
    start_item(req_data);
    req_data.tellme = 1; 
    finish_item(req_data);
    get_response(rsp_data);

    if (rsp_data.nrzi_data_q.size()) begin
      rsp_data.do_data_decoding();
      void'(pr.unpack(rsp_data.data));
      end

    `brt_info(get_name(), $psprintf("received packet from driver %s", pr.sprint()), UVM_HIGH)

    // SOF EOP is special case. It is 40 symbols without a transition, so ignore the bit stuff error for now (TBD check during decoding).
    if (rsp_data.bit_stuff_err && pr.pid_name != brt_usb_packet::SOF) begin
      `brt_fatal(get_name, "bit stuffing error")
      end

  endtask

endclass

class brt_usb_dev_xfer2packet_sequence extends brt_usb_xfer2packet_sequence;
    typedef enum {
        CHK_TOKEN = 0, INIT_XFER = 1, RUN_XFER
    } xfer_phase_e;

    // queue of packet
    brt_usb_packet              pkt_q[$];
    brt_usb_endpoint_config     ep_cfg;
    event                       abort_xfer;

    `brt_object_utils(brt_usb_dev_xfer2packet_sequence)

    function new(string name="");
      super.new(name);
    endfunction

    virtual task body();
      // gen data8
      gen_data_patten();
      forever begin
        `FORK_GUARD_BEGIN
            fork
                new_get_next_transfer();
                @abort_xfer;
            join_any
            disable fork;
        `FORK_GUARD_END
      end
    endtask

    virtual task new_get_next_transfer();
        xfer_phase_e                    xfer_phase;
        brt_usb_types::packet_phase_e       pkt_phase;
        brt_usb_packet                         req_pkt, rsp_pkt;
        brt_usb_transfer                    t;
        brt_usb_config                      agt_cfg;
        brt_usb_endpoint_config             ep_cfg;

        bit                 xfer_done;
        bit                 is_accepted;

        agt_cfg = up_sequencer.cfg;
        // transfer phase
        xfer_phase = CHK_TOKEN;
        do begin
        case (xfer_phase)
            CHK_TOKEN: begin
                // ask driver to listen to host
                `uvm_info("USB_DEV", "wait for next packet", UVM_LOW)
                new_listen_for_packet(req_pkt, rsp_pkt, t);
                if (rsp_pkt.pkt_err) begin
                    continue;
                end
                if (rsp_pkt.pid_name == brt_usb_packet::OUT && rsp_pkt.endp != 0) begin
                    xfer_phase = INIT_XFER;
                end
                else if (rsp_pkt.pid_name == brt_usb_packet::IN && rsp_pkt.endp != 0) begin
                    xfer_phase = INIT_XFER;
                end
                else if (rsp_pkt.pid_name == brt_usb_packet::SETUP) begin
                    xfer_phase = INIT_XFER;
                end
                else if (rsp_pkt.pid_name == brt_usb_packet::EXT) begin
                    xfer_phase = INIT_XFER;
                end
                else if (rsp_pkt.pid_name == brt_usb_packet::SOF) begin
                    xfer_phase = CHK_TOKEN;
                end
                else begin
                    `uvm_fatal ("DEV_CHK_TOKEN",$psprintf ("Not expected packet %s PID in TOKEN phase",rsp_pkt.pid_name.name()));
                end
            end
            INIT_XFER: begin
                // Check device address and find EP number
                if (rsp_pkt.func_address != agt_cfg.local_device_cfg[0].device_address) begin
                    `uvm_error (get_name(),$psprintf ("Packet address is not correct. pkt: %d, dev: %d",rsp_pkt.func_address,agt_cfg.local_device_cfg[0].device_address ))
                    xfer_phase = CHK_TOKEN;
                    continue;
                end
                // Find EP
                foreach(agt_cfg.local_device_cfg[0].endpoint_cfg[i]) begin
                    ep_cfg = this.up_sequencer.cfg.local_device_cfg[0].endpoint_cfg[i];
                    if (ep_cfg != null && ep_cfg.ep_number == rsp_pkt.endp) begin
                        if ((ep_cfg.direction == brt_usb_types::IN  && rsp_pkt.pid_name == brt_usb_packet::IN ) ||
                            (ep_cfg.direction == brt_usb_types::OUT && rsp_pkt.pid_name == brt_usb_packet::OUT) ||
                            (ep_cfg.ep_number == 0) ||
                            rsp_pkt.pid_name == brt_usb_packet::EXT
                            ) begin
                            t = brt_usb_transfer::type_id::create();
                            t.cfg = up_sequencer.cfg;
                            t.ep_cfg = ep_cfg;
                            t.device_address  = rsp_pkt.func_address;
                            t.endpoint_number = rsp_pkt.endp;
                            break;
                        end
                    end
                end   
                if (t == null) begin
                    `uvm_error (get_name(),$psprintf ("Packet endpoint is not correct. ep: %d, dir: %s",rsp_pkt.endp,rsp_pkt.pid_name.name() ))
                    xfer_phase = CHK_TOKEN;
                    continue;
                end

                xfer_phase = RUN_XFER;
            end
            RUN_XFER: begin
                if (t.ep_cfg.ep_type == brt_usb_types::BULK && t.ep_cfg.direction == brt_usb_types::IN) begin
                    get_bulk_in_transfer(rsp_pkt, t, is_accepted);
                end
                else if (t.ep_cfg.ep_type == brt_usb_types::BULK && t.ep_cfg.direction == brt_usb_types::OUT) begin
                    get_bulk_out_transfer(rsp_pkt, t, is_accepted);
                end
                else if (t.ep_cfg.ep_type == brt_usb_types::INTERRUPT && t.ep_cfg.direction == brt_usb_types::IN) begin
                    get_interrupt_in_transfer(rsp_pkt, t, is_accepted);
                end
                else if (t.ep_cfg.ep_type == brt_usb_types::INTERRUPT && t.ep_cfg.direction == brt_usb_types::OUT) begin
                    get_interrupt_out_transfer (rsp_pkt, t, is_accepted);
                end
                else if (t.ep_cfg.ep_type == brt_usb_types::ISOCHRONOUS && t.ep_cfg.direction == brt_usb_types::IN) begin
                    get_isochronous_in_transfer(rsp_pkt, t, is_accepted);
                end
                else if (t.ep_cfg.ep_type == brt_usb_types::ISOCHRONOUS && t.ep_cfg.direction == brt_usb_types::OUT) begin
                    get_isochronous_out_transfer(rsp_pkt, t, is_accepted);
                end
                else if (t.ep_cfg.ep_type == brt_usb_types::CONTROL) begin
                    if (rsp_pkt.pid_name == brt_usb_packet::EXT) begin
                        get_lpm_transfer(rsp_pkt, t, is_accepted);
                    end
                    else begin
                        get_control_transfer(rsp_pkt, t, is_accepted);
                    end
                end
                else begin
                    `uvm_fatal (get_name(), $psprintf ("Do not support this kind of transfer: %s %s",t.ep_cfg.ep_type.name(),t.ep_cfg.direction.name()))
                end

                xfer_phase = CHK_TOKEN;
                xfer_done = 1;
            end
            default: begin
                `uvm_fatal (get_name(),"Not expected transfer phase");
            end
        endcase
        end while (!xfer_done);
        // End transfer status
        if (is_accepted) begin
            t.tfer_status = brt_usb_types::ACCEPT;
        end
        else begin
            t.tfer_status = brt_usb_types::ABORTED;
        end

        if (t.payload.rxdata.size() > 0 ||
            (t.ep_cfg.ep_number != 0 && t.payload_intended_byte_count == 0)
           ) begin
            t.payload.data = new [t.payload.rxdata.size()];
            foreach ( t.payload.data[i]) begin
                 t.payload.data[i] =  t.payload.rxdata[i];
            end
        end
        `brt_info("USB_DEV", "call transfer ended", UVM_LOW)
        up_sequencer.prot.transfer_ended(t);
    endtask: new_get_next_transfer

  virtual task generate_tr_payload(int payload_size, brt_usb_transfer t);
    time cur_time;
    bit mod;
    bit drop;
    cur_time = $time;
    t.payload.data = new[payload_size];
    foreach (t.payload.data[i]) begin
       //t.payload.data[i] = data8[i%data8.size()];
       t.payload.data[i] = $urandom_range(0,255);
    end
    up_sequencer.transfer_ready(t, mod);
    up_sequencer.prot.pre_transfer_out_port_put(0, t, drop);
    if (mod) begin
      `uvm_info(get_name(), $psprintf("user modified payload"), UVM_HIGH)
    end
    assert (cur_time == $time) else `uvm_fatal(get_name(), "callback should not consume time")
  endtask

  virtual task new_do_send_iso_data(brt_usb_transfer t, brt_usb_packet p = null, output bit accepted);
        bit                     xfer_done;
        int                     total_byte_size, rem_size, payload_size;
        int                     mps;
        int                     num_pkt;
        bit                     need_zero_len;
        bit                     first_flag;
        brt_usb_packet::pid_name_e  pkt_pid, pkt_pid_q[$];
        brt_usb_packet              req_pkt, rsp_pkt;
        // endpoint status
        brt_usb_endpoint_status     ep_status;

        total_byte_size     = t.payload.data.size();

        accepted = 1;
        // Find EP cfg
        t.find_ep_cfg (up_sequencer.agt.cfg);
        mps = t.ep_cfg.max_packet_size;
        // Check transfer type
        t.chk_xfer_type();
        // Check number of packet
        if (t.cfg.speed == brt_usb_types::FS) begin
            if (total_byte_size > mps) begin
                `uvm_fatal (get_name(), $psprintf("Over payload size %d",total_byte_size))
            end
            pkt_pid_q.push_back(brt_usb_packet::DATA0);
        end
        else if (t.cfg.speed == brt_usb_types::HS) begin
            if ((mps < 513 && total_byte_size >   mps)||
                (mps < 683 && total_byte_size > 2*mps)||
                (total_byte_size > 3*mps)
                ) begin
                `uvm_fatal (get_name(), $psprintf("Over payload size %d, mps: %d",total_byte_size, mps))
            end

            if (total_byte_size > 0) begin
                num_pkt = (total_byte_size + mps - 1)/mps;  // round up
            end
            else begin
                num_pkt = 1;
            end

            for (int i = num_pkt - 1; i >= 0; i--) begin
                if (i == 0) pkt_pid_q.push_back(brt_usb_packet::DATA0);
                if (i == 1) pkt_pid_q.push_back(brt_usb_packet::DATA1);
                if (i == 2) pkt_pid_q.push_back(brt_usb_packet::DATA2);
            end
        end
        else begin
            `uvm_fatal (get_name(), $psprintf("Not support speed %s",t.cfg.speed.name()))
        end

        // Start
        `uvm_info(get_name(), $psprintf("ISO IN total_byte_size %0d, ", total_byte_size), UVM_LOW)

        pkt_phase     =  brt_usb_types::TOKEN_PHASE;
        pre_pkt_phase =  brt_usb_types::TOKEN_PHASE;

        if (p != null) begin
            rsp_pkt = p;
        end 
        else begin
            first_flag = 1;  // get packet
        end

        do begin 
            case (pkt_phase)
                brt_usb_types::TOKEN_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter TOKEN_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    if (first_flag) begin
                        new_listen_for_packet (req_pkt, rsp_pkt, t);
                        if (rsp_pkt.pkt_err) begin
                            continue;
                        end
                    end
                    first_flag = 1;
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    if (rsp_pkt.pid_name == brt_usb_packet::IN) begin
                        // Check destination
                        if ((rsp_pkt.func_address == t.cfg.local_device_cfg[0].device_address) ||
                            (rsp_pkt.endp         == t.ep_cfg.ep_number)
                            ) begin
                            pkt_phase = brt_usb_types::DATA_PHASE;
                        end
                    end
                    else if (rsp_pkt.pid_name == brt_usb_packet::SOF) begin
                        pkt_phase = brt_usb_types::TOKEN_PHASE;
                    end
                    else begin
                        // Other
                    end
                end
                brt_usb_types::DATA_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter DATA_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    // data0/data1
                    pkt_pid = pkt_pid_q.pop_front();
                    // data payload
                    if (total_byte_size - t.data_pos > mps) begin
                        payload_size = mps;
                    end
                    else begin
                        payload_size = total_byte_size - t.data_pos;
                    end
                    // Create packet
                    req_pkt = brt_usb_packet::type_id::create();
                    req_pkt.speed = t.cfg.speed;
                    start_item(req_pkt);
                    if (!req_pkt.randomize() with {pid_name == pkt_pid; data_size == payload_size; func_address == t.device_address; endp == t.endpoint_number;})
                      `uvm_fatal(get_name(), "randomize error")
                    // Assign data payload
                    foreach(req_pkt.data[i]) req_pkt.data[i] = t.payload.data[t.data_pos+i];

                    //req_pkt.need_rsp=1;
                    req_pkt.gen_data_crc16();
                    // Send
                    finish_packet(req_pkt, t);
                    get_response_packet(rsp_pkt, t); 
                    t.data_pos += payload_size;
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    pkt_phase = brt_usb_types::TOKEN_PHASE;
                    // transfer done
                    if (pkt_pid_q.size() == 0) begin
                        xfer_done = 1;
                    end
                end
                brt_usb_types::TIMEOUT_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter TIMEOUT_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    get_response_packet(rsp_pkt, t);
                    if (!rsp_pkt.is_timeout) begin
                        `uvm_fatal(get_name(),"Req packet is error but response packet did not timeout");
                    end
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    pkt_phase = brt_usb_types::TOKEN_PHASE;
                end
            endcase
        end while (!xfer_done);
  endtask

    virtual task do_send_data(brt_usb_transfer t, brt_usb_packet p = null, output bit accepted);
        bit                     xfer_done;
        int                     total_byte_size, rem_size, payload_size;
        int                     mps;
        bit                     need_zero_len;
        bit                     first_flag;
        brt_usb_packet::pid_name_e  pkt_pid;
        brt_usb_packet              req_pkt, rsp_pkt;
        // endpoint status
        brt_usb_endpoint_status     ep_status;

        total_byte_size     = t.payload.data.size();

        accepted = 1;
        // Find EP cfg
        t.find_ep_cfg (up_sequencer.agt.cfg);
        mps = t.ep_cfg.max_packet_size;
        // Find ep_status
        ep_status = up_sequencer.agt.shared_status.remote_device_status[0].endpoint_status[2*t.ep_cfg.ep_number + 1];
        if (ep_status == null) begin
            foreach (up_sequencer.agt.shared_status.remote_device_status[0].endpoint_status[i]) begin
                if (up_sequencer.agt.shared_status.remote_device_status[0].endpoint_status[i] != null) begin
                    `uvm_info (get_name(), $psprintf ("Available EP index: %d", i), UVM_LOW)
                end
            end
            `uvm_info (get_name(), $psprintf ("epnum: %d, dir: IN", t.ep_cfg.ep_number), UVM_LOW)
            `uvm_fatal (get_name(), "Can't get endpoint status")
        end      
        // Check transfer type
        t.chk_xfer_type();
        // Start
        `uvm_info(get_name(), $psprintf("%s total_byte_size %0d, ", t.xfer_type, total_byte_size), UVM_LOW)

        pkt_phase     =  brt_usb_types::TOKEN_PHASE;
        pre_pkt_phase =  brt_usb_types::TOKEN_PHASE;

        if (p != null) begin
            rsp_pkt = p;
        end 
        else begin
            first_flag = 1;  // get packet
        end

        do begin 
            case (pkt_phase)
                brt_usb_types::TOKEN_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter TOKEN_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    if (first_flag) begin
                        new_listen_for_packet (req_pkt, rsp_pkt, t);
                        if (rsp_pkt.pkt_err) begin
                            continue;
                        end
                    end
                    first_flag = 1;
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    if (rsp_pkt.pid_name == brt_usb_packet::IN) begin
                        // Check destination
                        if ((rsp_pkt.func_address == t.cfg.local_device_cfg[0].device_address) ||
                            (rsp_pkt.endp         == t.ep_cfg.ep_number)
                            ) begin
                            pkt_phase = brt_usb_types::DATA_PHASE;
                        end
                    end
                    else if (rsp_pkt.pid_name == brt_usb_packet::SOF) begin
                        pkt_phase = brt_usb_types::TOKEN_PHASE;
                    end
                    else begin
                        // Other
                    end
                end
                brt_usb_types::DATA_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter DATA_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    // data0/data1
                    pkt_pid = ep_status.dt_toggle? brt_usb_packet::DATA1:brt_usb_packet::DATA0;

                    // data payload
                    if (total_byte_size - t.data_pos > mps) begin
                        payload_size = mps;
                    end
                    else begin
                        payload_size = total_byte_size - t.data_pos;
                        if (total_byte_size - t.data_pos - mps == 0 &&
                            t.ep_cfg.allow_aligned_transfer_without_zero_length == 0
                            ) begin
                                need_zero_len = 1;
                        end 
                        else begin
                            need_zero_len = 0;
                        end
                    end
                    // Create packet
                    req_pkt = brt_usb_packet::type_id::create();
                    req_pkt.speed = t.cfg.speed;
                    start_item(req_pkt);
                    if (!req_pkt.randomize() with {pid_name == pkt_pid; data_size == payload_size; func_address == t.device_address; endp == t.endpoint_number;})
                      `uvm_fatal(get_name(), "randomize error")
                    // Assign data payload
                    foreach(req_pkt.data[i]) req_pkt.data[i] = t.payload.data[t.data_pos+i];

                    req_pkt.need_rsp=1;
                    req_pkt.gen_data_crc16();
                    // Send
                    finish_packet(req_pkt, t);
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    if (req_pkt.pkt_err) begin
                        if (req_pkt.need_timeout)
                            pkt_phase = brt_usb_types::TIMEOUT_PHASE;
                        else
                            pkt_phase = brt_usb_types::RSP_PHASE;   // For case wrong data toggle
                    end
                    else if (req_pkt.pid_format[3:0] == 4'ha) begin  // NAK
                        get_response_packet(rsp_pkt, t);
                        pkt_phase = brt_usb_types::TOKEN_PHASE;
                    end
                    else if (req_pkt.pid_format[3:0] == 4'he) begin  // STALL
                        get_response_packet(rsp_pkt, t);
                        pkt_phase = brt_usb_types::TOKEN_PHASE;
                    end
                    else begin
                        pkt_phase = brt_usb_types::RSP_PHASE;
                    end
                end
                brt_usb_types::RSP_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter RSP_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    get_response_packet(rsp_pkt, t);
                    // Check response packet
                    if (pre_pkt_phase == brt_usb_types::DATA_PHASE) begin
                        // Change phase
                        pre_pkt_phase = pkt_phase;
                        if (req_pkt.need_rsp     == 0 || 
                            req_pkt.need_timeout == 1 ||
                            req_pkt.pkt_err      == 1 ||
                            rsp_pkt.pkt_err      == 1
                           ) begin
                            pkt_phase = brt_usb_types::TOKEN_PHASE;
                            continue;
                        end

                        case (rsp_pkt.pid_name)
                            brt_usb_packet::ACK: begin
                                ep_status.dt_toggle = ~ep_status.dt_toggle;
                                t.data_pos = t.data_pos + payload_size;
                                pkt_phase = brt_usb_types::TOKEN_PHASE;
                                // check tfer done
                                if (t.data_pos == total_byte_size && need_zero_len == 0 ) begin
                                    xfer_done  = 1;
                                end
                            end
                            default: begin 
                                `uvm_fatal("DEV_IN_RSP", $psprintf("received unsupported handshake %s", rsp_pkt.pid_name.name())) 
                                pkt_phase = brt_usb_types::TOKEN_PHASE;
                            end
                        endcase
                    end
                    else begin
                        `uvm_fatal (get_name(),"Not support this transition of packet phase")
                    end


                end
                brt_usb_types::TIMEOUT_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter TIMEOUT_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    get_response_packet(rsp_pkt, t);
                    if (!rsp_pkt.is_timeout) begin
                        `uvm_fatal(get_name(),"Req packet is error but response packet did not timeout");
                    end
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    pkt_phase = brt_usb_types::TOKEN_PHASE;
                end
            endcase
        end while (!xfer_done);
    endtask:do_send_data

  virtual task get_lpm_transfer(brt_usb_packet p, brt_usb_transfer t, output bit accepted);
    brt_usb_packet req_pkt, rsp_pkt;
    bit         drop;
    bit[3:0]    hird;
    brt_usb_endpoint_status ep_status;

    `brt_info("USB_DEV", "LPM transfer starts ...", UVM_LOW)
    if (!t.randomize() with {
      xfer_type             == brt_usb_transfer::LPM_TRANSFER;
      endpoint_number       == p.endp;
      payload.data.size()   == 0; // dummy
      dir                   == brt_usb_types::OUT;
      }) begin
      `uvm_fatal(get_name(), "randomize error")
    end
    do begin
        new_listen_for_packet(req_pkt, rsp_pkt, t, 1'b1);

        `brt_info("USB_DEV", "Get a LPM packet ...", UVM_LOW)
        assert (rsp_pkt.pid_name == `SUBLPM) else begin
          `uvm_fatal(get_name(), "protocol error. Received packet is not LPM as expected")
        end
    end while (rsp_pkt.pkt_err || rsp_pkt.pid_name != `SUBLPM);
    hird = rsp_pkt.lpm_hird;
    // Create packet
    req_pkt = brt_usb_packet::type_id::create();
    req_pkt.speed = t.cfg.speed;
    start_item(req_pkt);
    if (!req_pkt.randomize() with {pid_name == brt_usb_packet::ACK;})
      `uvm_fatal(get_name(), "randomize error")
    // Send
    finish_packet(req_pkt, t);
    get_response(rsp_pkt);  // only wait done 
    if (req_pkt.pid_name == brt_usb_packet::ACK && !req_pkt.pkt_err && !req_pkt.drop) begin
        accepted = 1;
        // Enable LPM
        up_sequencer.cfg.lpm_enable = 1'b1;
        up_sequencer.cfg.tl1hird = hird_to_time (hird);
    end
  endtask

  virtual function setup_data_s get_setup_data(brt_usb_packet p);
    setup_data_i sdi;
    assert (p.data.size() == 8) else begin
      `uvm_fatal(get_name(), "protocol error")
      end

    sdi.sd_bytes = {p.data[0], p.data[1], p.data[2], p.data[3], p.data[4], p.data[5], p.data[6], p.data[7]}; 
    return sdi.sd_data;
  endfunction

  virtual task get_control_transfer(brt_usb_packet p, brt_usb_transfer t, output bit accepted);
    int mps;
    setup_data_s sd;
    brt_usb_packet req_pkt, rsp_pkt;
    bit drop;
    byte rx_data_q[$];
    brt_usb_transfer        t_status;
    brt_usb_endpoint_status ep_status;

    accepted = 1;
    rx_data_q.delete();

    // Find ep_status
    ep_status = up_sequencer.agt.shared_status.remote_device_status[0].endpoint_status[2*t.ep_cfg.ep_number + 1];

    // expect 8-byte data after SETUP
    t.control_xfer_state = brt_usb_transfer::SETUP_STATE;
    do begin
        new_listen_for_packet(req_pkt, rsp_pkt, t);

        assert (rsp_pkt.pid_name == brt_usb_packet::DATA0) else begin
          `uvm_fatal(get_name(), "protocol error. Received packet is not DATA0 as expected")
        end
    end while (rsp_pkt.pkt_err || rsp_pkt.pid_name != brt_usb_packet::DATA0);
    sd = get_setup_data(rsp_pkt); 
    `uvm_info(get_name(), $psprintf("bmRequest %h", sd.bmRequestType),                    UVM_HIGH)
    `uvm_info(get_name(), $psprintf("bmRequest %h", sd.bRequest),                         UVM_HIGH)
    `uvm_info(get_name(), $psprintf("wValue    %h", {sd.wValue_high, sd.wValue_low}),     UVM_HIGH)
    `uvm_info(get_name(), $psprintf("wIndex    %h", {sd.wIndex_high, sd.wIndex_low}),     UVM_HIGH)
    `uvm_info(get_name(), $psprintf("wLength   %h", {sd.wLength_high, sd.wLength_low}),   UVM_HIGH)

    if (!t.randomize() with {xfer_type == brt_usb_transfer::CONTROL_TRANSFER;
                            device_address               == p.func_address;
                            endpoint_number              == p.endp;
                            setup_data_bmrequesttype     == sd.bmRequestType;
                            setup_data_brequest          == sd.bRequest;
                            setup_data_w_value           == {sd.wValue_high,  sd.wValue_low};
                            setup_data_w_index           == {sd.wIndex_high,  sd.wIndex_low};
                            setup_data_w_length          == {sd.wLength_high, sd.wLength_low};
                            payload_intended_byte_count  == setup_data_w_length;
        }) begin
        `uvm_fatal(get_name(), "randomize error")
    end
    
    // Randomize for status stage
    t_status = new();
    t_status.cfg = t.cfg;
    if (!t_status.randomize() with {xfer_type       == brt_usb_transfer::CONTROL_TRANSFER;
                                    device_address  == p.func_address;
                                    endpoint_number == p.endp;
                                    payload_intended_byte_count   == 0;
        }) begin
        `uvm_fatal(get_name(), "randomize error")
    end
    t.payload_intended_byte_count = t.setup_data_w_length;

    up_sequencer.prot.transfer_begin(t);
    up_sequencer.prot.pre_transfer_out_port_put(0, t, drop);
    up_sequencer.prot.transfer_monitor(t);

    //do_send_handshake(t,, dummy_pid);
    setup_handshake (t, rsp_pkt);

    t.control_xfer_state = brt_usb_transfer::DATA_STATE;
    t_status.control_xfer_state = brt_usb_transfer::STATUS_STATE;
    if (t.setup_data_w_length > 0) begin  // 3 stage
        if (t.setup_data_bmrequesttype_dir == brt_usb_types::DEVICE_TO_HOST) begin
          //generate_tr_payload(t.payload_intended_byte_count, t);
          do_send_data(t, null ,accepted);
          // Status Stage
          ep_status.dt_toggle = 1;
          receive_data(t_status, null ,accepted);
        end
        else begin // HOST TO DEVICE
          //generate_tr_payload(t.payload_intended_byte_count, t);
          receive_data(t, null ,accepted);
          // Status Stage
          ep_status.dt_toggle = 1;
          do_send_data(t_status, null ,accepted);
        end
    end
    else begin  // 2 statge
          // Status Stage
          do_send_data(t_status, null ,accepted);
    end

  endtask

    virtual task setup_handshake (brt_usb_transfer t , brt_usb_packet p);
        bit                     xfer_done;
        int                     total_byte_size, rem_size, payload_size = -1;
        int                     mps;
        int                     need_zero_len;
        brt_usb_packet::pid_name_e  pkt_pid;
        brt_usb_packet              req_pkt, rsp_pkt, pre_data_pkt;
        // endpoint status
        brt_usb_endpoint_status     ep_status;

        total_byte_size     = t.payload_intended_byte_count;

        // Find EP cfg
        t.find_ep_cfg (up_sequencer.agt.cfg);
        mps = t.ep_cfg.max_packet_size;
        // Find ep_status
        ep_status = up_sequencer.agt.shared_status.remote_device_status[0].endpoint_status[2*t.ep_cfg.ep_number + (1 & (t.ep_cfg.ep_number == 0))];
        
        // Check transfer type
        t.chk_xfer_type();
        // Start
        `uvm_info(get_name(), $psprintf("Device receives SETUP packet"), UVM_HIGH)

        pkt_phase     =  brt_usb_types::RSP_PHASE;
        pre_pkt_phase =  brt_usb_types::RSP_PHASE;

        pre_data_pkt = p;
        do begin 
            case (pkt_phase)
                brt_usb_types::TOKEN_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter TOKEN PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    new_listen_for_packet (req_pkt, rsp_pkt, t);
                    if (rsp_pkt.pkt_err) begin
                        continue;
                    end
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    if (rsp_pkt.pid_name == brt_usb_packet::SETUP) begin
                        // Check destination
                        if ((rsp_pkt.func_address == t.cfg.local_device_cfg[0].device_address) ||
                            (rsp_pkt.endp         == t.ep_cfg.ep_number)
                            ) begin
                            pkt_phase = brt_usb_types::DATA_PHASE;
                        end
                    end
                    else if (rsp_pkt.pid_name == brt_usb_packet::SOF) begin
                        pkt_phase = brt_usb_types::TOKEN_PHASE;
                    end
                    else begin
                        // Other
                    end
                end
                brt_usb_types::DATA_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter DATA PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    new_listen_for_packet (req_pkt, rsp_pkt, t);
                    if (rsp_pkt.pkt_err) begin
                        continue;
                    end
                    // data0/data1
                    pkt_pid = ep_status.dt_toggle? brt_usb_packet::DATA1:brt_usb_packet::DATA0;

                    // Check response packet
                    if (pre_pkt_phase == brt_usb_types::TOKEN_PHASE) begin
                        // Change phase
                        pre_pkt_phase = pkt_phase;
                        case (rsp_pkt.pid_name)
                            brt_usb_packet::DATA0,brt_usb_packet::DATA1: begin
                                if (rsp_pkt.pid_name != pkt_pid) begin
                                    `brt_fatal(get_name(), $psprintf("received wrong data0/1 PID %s", rsp_pkt.pid_name.name())) 
                                end
                                // get data
                                pre_data_pkt = rsp_pkt;
                                pkt_phase           = brt_usb_types::RSP_PHASE;
                            end
                            default: begin 
                                `uvm_fatal(get_name(), $psprintf("received unsupported handshake %s", rsp_pkt.pid_name.name())) 
                            end
                        endcase
                    end
                    else begin
                        `uvm_fatal (get_name(),"Not support this transition of packet phase")
                    end
                end
                brt_usb_types::RSP_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter RSP PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    // Create packet
                    req_pkt = brt_usb_packet::type_id::create();
                    req_pkt.speed = t.cfg.speed;
                    start_item(req_pkt);
                    if (!req_pkt.randomize() with {pid_name == brt_usb_packet::ACK;})
                      `uvm_fatal(get_name(), "randomize error")
                    // Send
                    finish_packet(req_pkt, t);
                    get_response(rsp_pkt);  // only wait done 

                    // Assign payload
                    if (!req_pkt.pkt_err && (req_pkt.pid_name == brt_usb_packet::ACK)) begin
                        // get data
                        if (pre_data_pkt.data.size() != 8) begin
                            `uvm_fatal (get_name(), $psprintf ("Setup data is not 8, real: %d",pre_data_pkt.data.size()))
                            // Change phase
                            pre_pkt_phase = pkt_phase;
                            pkt_phase     = brt_usb_types::TOKEN_PHASE;
                        end 
                        else begin
                            t.setup_data_bmrequesttype  = pre_data_pkt.data[0];
                            t.setup_data_brequest       = pre_data_pkt.data[1];
                            t.setup_data_w_value        = {pre_data_pkt.data[3],pre_data_pkt.data[2]};
                            t.setup_data_w_index        = {pre_data_pkt.data[5],pre_data_pkt.data[4]};
                            t.setup_data_w_length       = {pre_data_pkt.data[7],pre_data_pkt.data[6]};

                            // update data toggle and position
                            ep_status.dt_toggle = ~ep_status.dt_toggle;
                            // Change phase
                            pre_pkt_phase = pkt_phase;
                            pkt_phase     = brt_usb_types::TOKEN_PHASE;
                            xfer_done = 1;                            
                        end
                    end
                    else begin
                        // Change phase
                        pre_pkt_phase = pkt_phase;
                        pkt_phase     = brt_usb_types::TOKEN_PHASE;
                    end
                    //// check transfer done
                    //if (!req_pkt.pkt_err) begin
                    //    xfer_done = 1;                            
                    //end
                end
                brt_usb_types::TIMEOUT_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter TIMEOUT PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    `uvm_fatal(get_name(),"Not enter this case");
                end
            endcase
        end while (!xfer_done);
    endtask: setup_handshake

  virtual task get_bulk_out_transfer(brt_usb_packet p, brt_usb_transfer t, output bit accepted);
    int mps, payload_size;
    byte rx_data_q[$];
    bit drop;
    brt_usb_packet req_pkt, rsp_pkt;

    rx_data_q.delete();
    accepted = 1;

    rsp_pkt = p;
    if (!t.randomize() with {xfer_type == brt_usb_transfer::BULK_OUT_TRANSFER;
      endpoint_number == p.endp;
      payload_intended_byte_count inside {[7000:10000]}; // dummy
      }) begin
      `uvm_fatal(get_name(), "randomize error")
      end
    up_sequencer.prot.transfer_begin(t);
    up_sequencer.prot.pre_transfer_out_port_put(0, t, drop);
    up_sequencer.prot.transfer_monitor(t);

    receive_data(t, rsp_pkt, accepted);

    // Collect data
    //t.payload.data = new[rx_data_q.size()];
    //foreach(t.payload.data[i]) t.payload.data[i] = rx_data_q.pop_front();

  endtask

  virtual task get_interrupt_out_transfer(brt_usb_packet p, brt_usb_transfer t, output bit accepted);
    int payload_size;
    byte rx_data_q[$];
    bit drop;
    brt_usb_packet req_pkt, rsp_pkt;

    rx_data_q.delete();
    accepted = 1;

    rsp_pkt = p;
    if (!t.randomize() with {xfer_type == brt_usb_transfer::INTERRUPT_OUT_TRANSFER;
      endpoint_number == p.endp;
      payload_intended_byte_count inside {[7000:10000]}; // dummy
      }) begin
      `uvm_fatal(get_name(), "randomize error")
      end
    up_sequencer.prot.transfer_begin(t);
    up_sequencer.prot.pre_transfer_out_port_put(0, t, drop);
    up_sequencer.prot.transfer_monitor(t);

    receive_data(t, rsp_pkt, accepted);

  endtask

  virtual task get_isochronous_out_transfer(brt_usb_packet p, brt_usb_transfer t, output bit accepted);
    int  payload_size;
    byte rx_data_q[$];
    bit drop;
    brt_usb_packet req_pkt, rsp_pkt;

    rx_data_q.delete();
    accepted = 1;

    rsp_pkt = p;
    if (!t.randomize() with {xfer_type == brt_usb_transfer::ISOCHRONOUS_OUT_TRANSFER;
      endpoint_number == p.endp;
      payload.data.size() == 1; // dummy
      }) begin
      `uvm_fatal(get_name(), "randomize error")
      end
    up_sequencer.prot.transfer_begin(t);
    up_sequencer.prot.pre_transfer_out_port_put(0, t, drop);
    up_sequencer.prot.transfer_monitor(t);

    new_receive_iso_data(t, rsp_pkt, accepted);

    t.payload.data = new[rx_data_q.size()];
    foreach(t.payload.data[i]) t.payload.data[i] = rx_data_q.pop_front();
  endtask
 
  virtual task get_bulk_in_transfer(brt_usb_packet p, brt_usb_transfer t, output bit accepted);
    bit drop;
    brt_usb_packet req_pkt, rsp_pkt;

    rsp_pkt  = p;
    accepted = 1;
    //if (!this.randomize()) `uvm_fatal(get_name(), "randomize error")

    if (!t.randomize() with {xfer_type          == brt_usb_transfer::BULK_IN_TRANSFER;
                             endpoint_number    == p.endp;
                             device_address     == p.func_address;
                             payload_intended_byte_count inside {[100:10000]};
      }) begin
      `uvm_fatal(get_name(), "randomize error")
      end
    up_sequencer.prot.transfer_begin(t);
    up_sequencer.prot.pre_transfer_out_port_put(0, t, drop);
    up_sequencer.prot.transfer_monitor(t);

    //generate_tr_payload(t.payload_intended_byte_count, t);
    do_send_data(t, rsp_pkt, accepted);
  endtask

  virtual task get_interrupt_in_transfer(brt_usb_packet p, brt_usb_transfer t, output bit accepted);
    bit drop;
    brt_usb_packet req_pkt, rsp_pkt;

    rsp_pkt = p;
    accepted = 1;
    //if (!this.randomize()) `uvm_fatal(get_name(), "randomize error")
    //payload_size = this.bulk_in_size;

    if (!t.randomize() with {xfer_type == brt_usb_transfer::INTERRUPT_IN_TRANSFER;
                             endpoint_number == p.endp;
                             device_address     == p.func_address;
                             payload_intended_byte_count inside {[100:10000]};
      }) begin
      `uvm_fatal(get_name(), "randomize error")
      end
    up_sequencer.prot.transfer_begin(t);
    up_sequencer.prot.pre_transfer_out_port_put(0, t, drop);
    up_sequencer.prot.transfer_monitor(t);

    //generate_tr_payload(t.payload_intended_byte_count, t);
    do_send_data(t, rsp_pkt, accepted);
  endtask

  virtual task get_isochronous_in_transfer(brt_usb_packet p, brt_usb_transfer t, output bit accepted);
    bit drop;
    brt_usb_packet req_pkt, rsp_pkt;

    rsp_pkt = p;
    accepted = 1;

    if (!t.randomize() with {xfer_type == brt_usb_transfer::ISOCHRONOUS_IN_TRANSFER;
      device_address  == rsp_pkt.func_address;
      endpoint_number == rsp_pkt.endp;
      payload_intended_byte_count inside {[1:(t.ep_cfg.max_burst_size+1)*t.ep_cfg.max_packet_size]};
      }) begin
        `uvm_fatal(get_name(), "randomize error")
    end
    up_sequencer.prot.transfer_begin(t);
    up_sequencer.prot.pre_transfer_out_port_put(0, t, drop);
    up_sequencer.prot.transfer_monitor(t);

    //generate_tr_payload(t.payload_intended_byte_count, t);
    new_do_send_iso_data(t, rsp_pkt, accepted);
  endtask

  virtual task new_receive_iso_data(brt_usb_transfer t, brt_usb_packet p = null, output bit accepted);
        bit                     xfer_done;
        int                     total_byte_size, rem_size, payload_size = -1;
        int                     mps;
        int                     need_zero_len;
        int                     num_mdata;
        bit                     first_flag;
        brt_usb_packet::pid_name_e  pkt_pid;
        brt_usb_packet::pid_name_e  pkt_pid_1;
        brt_usb_packet              req_pkt, rsp_pkt;
        // endpoint status
        brt_usb_endpoint_status     ep_status;

        total_byte_size     = t.payload_intended_byte_count;

        accepted = 1;
        // Find EP cfg
        t.find_ep_cfg (up_sequencer.agt.cfg);
        mps = t.ep_cfg.max_packet_size;
        // Find ep_status
        ep_status = up_sequencer.agt.shared_status.remote_device_status[0].endpoint_status[2*t.ep_cfg.ep_number + (1 & (t.ep_cfg.ep_number == 0))];
        
        // Check transfer type
        t.chk_xfer_type();
        // Start
        `uvm_info(get_name(), $psprintf("Device receives ISO OUT total_byte_size %0d, ", total_byte_size), UVM_LOW)

        pkt_phase     =  brt_usb_types::TOKEN_PHASE;
        pre_pkt_phase =  brt_usb_types::TOKEN_PHASE;

        if (p != null) begin
            rsp_pkt = p;
        end
        else begin
            first_flag = 1;
        end

        pkt_pid   = brt_usb_packet::DATA0;
        pkt_pid_1 = brt_usb_packet::MDATA;

        do begin 
            case (pkt_phase)
                brt_usb_types::TOKEN_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter TOKEN_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    if (first_flag) begin
                        new_listen_for_packet (req_pkt, rsp_pkt, t);
                        if (rsp_pkt.pkt_err) begin
                            continue;
                        end
                    end
                    first_flag = 1;
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    if (rsp_pkt.pid_name == brt_usb_packet::OUT) begin
                        // Check destination
                        if ((rsp_pkt.func_address == t.cfg.local_device_cfg[0].device_address) ||
                            (rsp_pkt.endp         == t.ep_cfg.ep_number)
                            ) begin
                            pkt_phase = brt_usb_types::DATA_PHASE;
                        end
                    end
                    else if (rsp_pkt.pid_name == brt_usb_packet::SOF) begin
                        pkt_phase = brt_usb_types::TOKEN_PHASE;
                    end
                    else begin
                        // Other
                    end
                end
                brt_usb_types::DATA_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter DATA_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    new_listen_for_packet (req_pkt, rsp_pkt, t);
                    if (rsp_pkt.pkt_err) begin
                        continue;
                    end
                    // data0/data1
                    // Not implement yet
                    // pkt_pid = ep_status.dt_toggle? brt_usb_packet::DATA1:brt_usb_packet::DATA0;

                    // Check response packet
                    if (pre_pkt_phase == brt_usb_types::TOKEN_PHASE) begin
                        // Change phase
                        pre_pkt_phase = pkt_phase;
                        case (rsp_pkt.pid_name)
                            brt_usb_packet::MDATA: begin
                                if (!((rsp_pkt.pid_name == pkt_pid)|| (rsp_pkt.pid_name == pkt_pid_1))) begin
                                    `uvm_fatal(get_name(), $psprintf("received wrong data0/1/2/M PID %s", rsp_pkt.pid_name.name())) 
                                end
                                num_mdata++;
                                if (num_mdata == 1) begin
                                    pkt_pid   = brt_usb_packet::DATA1;
                                    pkt_pid_1 = brt_usb_packet::MDATA;
                                end if (num_mdata == 2) begin
                                    pkt_pid   = brt_usb_packet::DATA2;
                                    pkt_pid_1 = brt_usb_packet::DATA2;
                                end

                            end
                            brt_usb_packet::DATA0,brt_usb_packet::DATA1,brt_usb_packet::DATA2: begin
                                if (!((rsp_pkt.pid_name == pkt_pid)|| (rsp_pkt.pid_name == pkt_pid_1))) begin
                                    `uvm_fatal(get_name(), $psprintf("received wrong data0/1/2/M PID %s", rsp_pkt.pid_name.name())) 
                                end

                                xfer_done = 1;
                                accepted  = 1;
                            end
                            default: begin 
                                `uvm_fatal(get_name(), $psprintf("received unsupported handshake %s", rsp_pkt.pid_name.name())) 
                            end
                        endcase
                        // get data
                        foreach(rsp_pkt.data[i]) t.payload.rxdata.push_back(rsp_pkt.data[i]);
                        // update data toggle and position
                        //ep_status.dt_toggle = ~ep_status.dt_toggle;
                        payload_size        = rsp_pkt.data.size();
                        t.data_pos          = t.data_pos + payload_size;
                        pkt_phase           = brt_usb_types::TOKEN_PHASE;

                        // check transfer done
                        if (t.data_pos > t.payload_intended_byte_count) begin
                            `brt_error(get_name(),$psprintf ("Transfer IN babble, received: %d, expected: %d",t.data_pos, t.payload_intended_byte_count));
                        end
                    end
                    else begin
                        `uvm_fatal (get_name(),"Not support this transition of packet phase")
                    end
                end
            endcase
        end while (!xfer_done);
  endtask

  virtual task receive_data(brt_usb_transfer t, brt_usb_packet p = null, output bit accepted);
        bit                     xfer_done;
        int                     total_byte_size, rem_size, payload_size = -1;
        int                     mps;
        int                     need_zero_len;
        bit                     first_flag;
        brt_usb_packet::pid_name_e  pkt_pid;
        brt_usb_packet              req_pkt, rsp_pkt, pre_data_pkt;
        // endpoint status
        brt_usb_endpoint_status     ep_status;

        total_byte_size     = t.payload_intended_byte_count;

        accepted = 1;
        // Find EP cfg
        t.find_ep_cfg (up_sequencer.agt.cfg);
        mps = t.ep_cfg.max_packet_size;
        // Find ep_status
        ep_status = up_sequencer.agt.shared_status.remote_device_status[0].endpoint_status[2*t.ep_cfg.ep_number + (1 & (t.ep_cfg.ep_number == 0))];
        
        // Check transfer type
        t.chk_xfer_type();
        // Start
        `uvm_info(get_name(), $psprintf("Device receives Bulk OUT total_byte_size %0d, ", total_byte_size), UVM_LOW)

        pkt_phase     =  brt_usb_types::TOKEN_PHASE;
        pre_pkt_phase =  brt_usb_types::TOKEN_PHASE;

        if (p != null) begin
            rsp_pkt = p;
        end
        else begin
            first_flag = 1;
        end
        do begin 
            case (pkt_phase)
                brt_usb_types::TOKEN_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter TOKEN_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    if (first_flag) begin
                        new_listen_for_packet (req_pkt, rsp_pkt, t);
                        if (rsp_pkt.pkt_err) begin
                            continue;
                        end
                    end
                    first_flag = 1;
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    if (rsp_pkt.pid_name == brt_usb_packet::OUT) begin
                        // Check destination
                        if ((rsp_pkt.func_address == t.cfg.local_device_cfg[0].device_address) ||
                            (rsp_pkt.endp         == t.ep_cfg.ep_number)
                            ) begin
                            pkt_phase = brt_usb_types::DATA_PHASE;
                        end
                    end
                    else if (rsp_pkt.pid_name == brt_usb_packet::SOF) begin
                        //pkt_phase = brt_usb_types::TOKEN_PHASE;
                    end
                    else begin
                        // Other
                    end
                end
                brt_usb_types::PING_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter PING_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    new_listen_for_packet (req_pkt, rsp_pkt, t);
                    if (rsp_pkt.pkt_err) begin
                        continue;
                    end

                    if (rsp_pkt.pid_name == brt_usb_packet::PING) begin
                        // Check destination
                        if ((rsp_pkt.func_address == t.cfg.local_device_cfg[0].device_address) ||
                            (rsp_pkt.endp         == t.ep_cfg.ep_number)
                            ) begin
                            // Change phase
                            pre_pkt_phase = pkt_phase;
                            pkt_phase = brt_usb_types::RSP_PHASE;
                        end
                    end
                    else if (rsp_pkt.pid_name == brt_usb_packet::OUT) begin
                        // Check destination
                        if ((rsp_pkt.func_address == t.cfg.local_device_cfg[0].device_address) ||
                            (rsp_pkt.endp         == t.ep_cfg.ep_number)
                            ) begin
                            pre_pkt_phase = brt_usb_types::TOKEN_PHASE;
                            pkt_phase = brt_usb_types::DATA_PHASE;
                        end
                    end
                    else if (rsp_pkt.pid_name == brt_usb_packet::SOF) begin
                        //pkt_phase = brt_usb_types::TOKEN_PHASE;
                    end
                    else begin
                        // Other
                    end
                end
                brt_usb_types::DATA_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter DATA_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    new_listen_for_packet (req_pkt, rsp_pkt, t);
                    if (rsp_pkt.pkt_err) begin
                        pkt_phase = brt_usb_types::TOKEN_PHASE;
                        continue;
                    end
                    // data0/data1
                    pkt_pid = ep_status.dt_toggle? brt_usb_packet::DATA1:brt_usb_packet::DATA0;

                    // Check response packet
                    if (pre_pkt_phase == brt_usb_types::TOKEN_PHASE) begin
                        // Change phase
                        pre_pkt_phase = pkt_phase;
                        case (rsp_pkt.pid_name)
                            brt_usb_packet::DATA0,brt_usb_packet::DATA1: begin
                                if (rsp_pkt.pid_name != pkt_pid) begin
                                    `uvm_fatal(get_name(), $psprintf("received wrong data0/1 PID %s", rsp_pkt.pid_name.name())) 
                                    pkt_phase = brt_usb_types::TOKEN_PHASE;
                                    continue;
                                end
                                
                                // Check packet babble
                                if (rsp_pkt.data.size() > mps) begin
                                    `uvm_fatal(get_name(), $psprintf("received data packet babble %d", rsp_pkt.data.size())) 
                                    pkt_phase = brt_usb_types::TOKEN_PHASE;
                                    continue;
                                end

                                // Check zero len of last packet
                                if (need_zero_len == 1) begin
                                    if (rsp_pkt.data.size() > 0) begin
                                        `uvm_fatal(get_name(), $psprintf("Expected a zero len data")) 
                                    end
                                end
                                // get data
                                pre_data_pkt = rsp_pkt;
                                pkt_phase           = brt_usb_types::RSP_PHASE;
                            end
                            default: begin 
                                `uvm_fatal(get_name(), $psprintf("received unsupported handshake %s", rsp_pkt.pid_name.name())) 
                                pkt_phase = brt_usb_types::TOKEN_PHASE;
                                continue;
                            end
                        endcase
                    end
                    else begin
                        `uvm_fatal (get_name(),"Not support this transition of packet phase")
                    end
                end
                brt_usb_types::RSP_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter RSP_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    // Create packet
                    req_pkt = brt_usb_packet::type_id::create();
                    req_pkt.speed = t.cfg.speed;
                    start_item(req_pkt);
                    if (!req_pkt.randomize() with {pid_name == brt_usb_packet::ACK;})
                      `uvm_fatal(get_name(), "randomize error")
                    // Send
                    finish_packet(req_pkt, t);
                    get_response(rsp_pkt);  // only wait done 

                    // Assign payload
                    if (!req_pkt.pkt_err && 
                        (req_pkt.pid_name == brt_usb_packet::ACK || req_pkt.pid_name == brt_usb_packet::NYET) && 
                        pre_pkt_phase    != brt_usb_types::PING_PHASE
                       ) begin
                        // get data
                        foreach(pre_data_pkt.data[i]) t.payload.rxdata.push_back(pre_data_pkt.data[i]);
                        // update data toggle and position
                        ep_status.dt_toggle = ~ep_status.dt_toggle;
                        payload_size        = pre_data_pkt.data.size();
                        t.data_pos          = t.data_pos + payload_size;
                        if (need_zero_len == 1)
                            need_zero_len++;
                    end
                    // Change phase
                    if (!req_pkt.pkt_err && req_pkt.pid_name == brt_usb_packet::NYET) begin
                        pre_pkt_phase = pkt_phase;
                        pkt_phase     = brt_usb_types::PING_PHASE;
                    end 
                    else begin
                        pre_pkt_phase = pkt_phase;
                        pkt_phase     = brt_usb_types::TOKEN_PHASE;
                    end
                    // check transfer done
                    if (!req_pkt.pkt_err && req_pkt.pid_name == brt_usb_packet::ACK) begin
                        if (t.data_pos > t.payload_intended_byte_count) begin
                            `uvm_error(get_name(),$psprintf ("Transfer OUT babble: receive: %d , expected: %d",t.data_pos,t.payload_intended_byte_count));
                        end
                        else if (t.data_pos == t.payload_intended_byte_count) begin
                            `uvm_info(get_name(),"Transfer done .............", UVM_LOW);
                            if ( payload_size == mps && t.ep_cfg.allow_aligned_transfer_without_zero_length == 0 && need_zero_len == 0) begin
                                need_zero_len = 1;
                            end
                            else begin
                                xfer_done = 1;
                            end
                        end
                        // Short packet
                        if (payload_size >=0 && payload_size < mps) begin
                            xfer_done = 1;                            
                        end
                    end
                end
                brt_usb_types::TIMEOUT_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter TIMEOUT_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    `uvm_fatal(get_name(),"Not enter this case");
                end
            endcase
        end while (!xfer_done);
  endtask: receive_data

  virtual task finish_packet(inout brt_usb_packet p, brt_usb_transfer t);
    bit drop;
    up_sequencer.prot.pre_brt_usb_20_packet_out_port_put(t, p, drop);
    //if (drop) return;

    p.drop = drop;
    if (p.pid_name == brt_usb_packet::NAK ||
        p.pid_name == brt_usb_packet::STALL) p.need_rsp = 0;
    req_delay(p);
    finish_item(p);
    p.dir = brt_usb_types::TO_HOST;
    p.pkt_err = p.chk_err(this.up_sequencer.cfg.ignore_mon_dev_err);
    if (p.drop) begin
        p.pkt_err = p.drop;  // Retry
    end
    up_sequencer.prot.packet_trace(t, p);
  endtask

  virtual function void device_check_packet_valid(inout brt_usb_packet p);
    if (p.pid_name == brt_usb_packet::IN || p.pid_name == brt_usb_packet::OUT || p.pid_name == brt_usb_packet::SETUP) begin
      assert (p.func_address == this.up_sequencer.cfg.local_device_cfg[0].device_address) else
        `uvm_error(get_name(), "token packet address error")
      end
  endfunction

  virtual task get_response_packet(inout brt_usb_packet p, brt_usb_transfer t);
    get_response(p);
    p.dir = brt_usb_types::TO_DEVICE;
    if (p.need_rsp) begin
      //check_packet_valid(p);
      p.pkt_err = p.chk_err(this.up_sequencer.cfg.ignore_mon_dev_err);
      up_sequencer.prot.packet_trace(t, p);
      end
    else if (p.tellme) begin
      //check_packet_valid(p);
      p.pkt_err = p.chk_err(this.up_sequencer.cfg.ignore_mon_dev_err);
      if (!p.pkt_err) begin
        device_check_packet_valid(p);
      end
      up_sequencer.prot.packet_trace(t, p);
    end
  endtask

  virtual task new_listen_for_packet(output brt_usb_packet req_pkt, output brt_usb_packet rsp_pkt, input brt_usb_transfer t, bit is_lpm = 0);
    wait (pkt_q.size() > 0);
    rsp_pkt = pkt_q.pop_front();
    rsp_pkt.is_lpm = is_lpm;
      //check_packet_valid;
      rsp_pkt.pkt_err = rsp_pkt.chk_err(this.up_sequencer.cfg.ignore_mon_dev_err);
      if (!rsp_pkt.pkt_err) begin
            //
      end
      up_sequencer.prot.packet_trace(t, rsp_pkt);
  endtask

  virtual function void check_packet_target(brt_usb_packet p, output brt_usb_types::ep_type_e ep_type, output int ep_num, output bit valid);
    bit is_token;
    brt_usb_types::ep_dir_e dir;
    brt_usb_endpoint_config ep_cfg;

    ep_num     = p.endp;
    valid     = 0;
    is_token = (p.pid_name == brt_usb_packet::IN || p.pid_name == brt_usb_packet::OUT || p.pid_name == brt_usb_packet::SETUP);

    if (p.pid_name == brt_usb_packet::IN)    dir = brt_usb_types::IN;
    else if (p.pid_name == brt_usb_packet::OUT) dir = brt_usb_types::OUT;
    else if (p.pid_name == brt_usb_packet::PING) begin
      `uvm_warning(get_name(), "currently not supported")
      end
    else if (p.pid_name == brt_usb_packet::SETUP) begin
      assert (ep_num == 0) begin
        valid = 1;
        end else begin
        `uvm_fatal(get_name(), "wrong target endpoint")
        end
      end
    else if (p.pid_name == brt_usb_packet::DATA0 || p.pid_name == brt_usb_packet::DATA1) begin
      end
    else if (p.pid_name == brt_usb_packet::SOF) begin
      valid = 1;
      end
    else begin
      `uvm_fatal(get_name(), "currently not supported")
      end


    if (is_token && ep_num) foreach(this.up_sequencer.cfg.local_device_cfg[0].endpoint_cfg[i]) begin
      ep_cfg = this.up_sequencer.cfg.local_device_cfg[0].endpoint_cfg[i];
      if (ep_cfg != null && ep_cfg.ep_number == ep_num) begin
        ep_type     = ep_cfg.ep_type;
        valid         = 1;
        assert (ep_cfg.direction == dir) else begin
          valid = 0;
          `uvm_fatal(get_name(), "wrong target endpoint")
          end
        break;
        end
      end   

  endfunction

  virtual task get_sof(brt_usb_packet p);
    `uvm_info("USB_DEV", $psprintf("received SOF: Frame Number: 0x%h", p.frame_num), UVM_LOW)
  endtask

endclass : brt_usb_dev_xfer2packet_sequence

class brt_usb_dev_packet_router_sequence extends brt_sequence #(brt_usb_packet);
    brt_usb_layering    ulayer;    
    int             active_chan;

    `brt_object_utils(brt_usb_dev_packet_router_sequence)
    `brt_declare_p_sequencer(brt_usb_packet_sequencer)

    function new (string name="brt_usb_dev_packet_router_sequence");
        super.new(name);
    endfunction:new

    virtual task body ();
        forever begin
            get_packet_loop();
        end
    endtask:body

    virtual task get_packet_loop ();
        brt_usb_packet              rsp_pkt;
        brt_usb_types::ep_dir_e  	dir;
        // Get packet from driver
        wait (p_sequencer.agt.prot.pkt_q.size() > 0);
        rsp_pkt = p_sequencer.agt.prot.pkt_q.pop_front();
        // Check packet
        if (rsp_pkt.chk_err(p_sequencer.agt.cfg.ignore_mon_dev_err)) begin
            // T.B.D
            //return;
        end
        else begin
            if (
                    rsp_pkt.pid_format[3:0] == 4'h1 ||            // pid_name == OUT     
                    rsp_pkt.pid_format[3:0] == 4'h9 ||            // pid_name == IN      
                    //rsp_pkt.pid_format[3:0] == 4'h5 ||            // pid_name == SOF     
                    rsp_pkt.pid_format[3:0] == 4'hd ||            // pid_name == SETUP   
                    rsp_pkt.pid_format[3:0] == 4'h4               // pid_name == PING    
            ) begin
                if (
                    rsp_pkt.pid_format[3:0] == 4'h9               // pid_name == IN      
                )begin
                    dir = brt_usb_types::IN;
                end
                else if (
                            rsp_pkt.pid_format[3:0] == 4'h4 ||    // pid_name == PING    
                            rsp_pkt.pid_format[3:0] == 4'h1 ||    // pid_name == OUT     
                            rsp_pkt.pid_format[3:0] == 4'hd       // pid_name == SETUP   
                )begin
                    dir = brt_usb_types::OUT;
                end
                // Select chan
                active_chan = 0;  // default
                foreach (ulayer.d_x2p_seq[i]) begin
                    if (ulayer.d_x2p_seq[i].ep_cfg           != null         &&
                        ulayer.d_x2p_seq[i].ep_cfg.ep_number == rsp_pkt.endp &&
                        ulayer.d_x2p_seq[i].ep_cfg.direction == dir
                    ) begin
                        active_chan = i;
                        break;
                    end
                end
            end  // if whole
        end  // if chk_err

        // Route packer
        `brt_info (get_name(),$psprintf ("Put a packet to channel %d",active_chan),UVM_HIGH)
        ulayer.d_x2p_seq[active_chan].pkt_q.push_back (rsp_pkt);
    endtask: get_packet_loop
endclass : brt_usb_dev_packet_router_sequence
////////////////////////////////////////////////////

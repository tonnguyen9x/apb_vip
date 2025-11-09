// translate brt_usb transfer to brt_usb packet
class brt_usb_xfer2packet_sequence extends brt_sequence #(brt_usb_packet);
  brt_usb_endpoint_config   ep_cfg;
  brt_usb_transfer          xfer_q[$];

  bit                       is_host;
  int                       idx;
  // data payload generation
  bit[7:0]                  data8[];

  bit                       xfer_terminated = 0;
  // Phase when transfering packet
  brt_usb_types::packet_phase_e        pkt_phase;
  brt_usb_types::packet_phase_e        pre_pkt_phase;
  //brt_sequencer #(brt_usb_transfer) up_sequencer; 
  brt_usb_transfer_sequencer up_sequencer; 

  `brt_object_utils(brt_usb_xfer2packet_sequence)
  `brt_declare_p_sequencer (brt_usb_packet_sequencer)
  
  function new(string name="");
    super.new(name);
  endfunction

  virtual task get_next_transfer();
    bit              is_accepted;
    brt_usb_transfer     xfer;
    brt_usb_transfer     rsp_xfer;

//    up_sequencer.get(xfer);

    wait (xfer_q.size() > 0);
    xfer = xfer_q[0];
    xfer.cfg = up_sequencer.agt.cfg;
    //if (!xfer.cfg.randomize()) `brt_fatal(get_name(), "randomize error")

    //DD Call the callback of protocol
    up_sequencer.prot.transfer_begin(xfer);
    up_sequencer.prot.transfer_monitor(xfer);

    is_accepted = 0;
    xfer_terminated = 0;
    `brt_info(get_full_name(), $psprintf("executing new transfer %s", xfer.sprint()), UVM_HIGH)
    case (xfer.xfer_type)
      brt_usb_transfer::CONTROL_TRANSFER:
        do_control_transfer(xfer, is_accepted);
      brt_usb_transfer::INTERRUPT_OUT_TRANSFER, brt_usb_transfer::INTERRUPT_IN_TRANSFER:             
        do_interrupt_transfer(xfer, is_accepted);
      brt_usb_transfer::BULK_OUT_TRANSFER, brt_usb_transfer::BULK_IN_TRANSFER:             
        do_bulk_transfer(xfer, is_accepted);
      brt_usb_transfer::ISOCHRONOUS_OUT_TRANSFER, brt_usb_transfer::ISOCHRONOUS_IN_TRANSFER:    
        do_isochronous_transfer(xfer, is_accepted);
      brt_usb_transfer::LPM_TRANSFER:
        do_lpm_transfer(xfer, is_accepted);
      default:
        `brt_fatal(get_name(), "unsupported transfer")
    endcase
    `brt_info(get_full_name(), $psprintf("Done transfer %s", xfer.sprint()), UVM_HIGH)

    if (is_accepted) xfer.tfer_status = brt_usb_types::ACCEPT;
    else xfer.tfer_status = brt_usb_types::ABORTED;

    //up_sequencer.item_done();
    if (xfer.xfer_type == brt_usb_transfer::INTERRUPT_IN_TRANSFER ||
        xfer.xfer_type == brt_usb_transfer::BULK_IN_TRANSFER ||
        xfer.xfer_type == brt_usb_transfer::ISOCHRONOUS_IN_TRANSFER ||
        xfer.payload.rxdata.size() > 0
    ) begin
        xfer.payload.data = new [xfer.payload.rxdata.size()];
        foreach ( xfer.payload.data[i]) begin
             xfer.payload.data[i] =  xfer.payload.rxdata[i];
        end
    end
    $cast(rsp_xfer, xfer.clone());
    rsp_xfer.set_id_info(xfer);
    rsp_xfer.find_ep_cfg (rsp_xfer.cfg);
    //DD Call the callback of protocol
    up_sequencer.prot.transfer_ended(rsp_xfer);
    //DD Put response transfer to upper sequencer
    up_sequencer.put(rsp_xfer);
    
    // Delete queue after completing
    xfer_q.delete(0);
  endtask

  virtual task body();
      forever begin
        get_next_transfer();
      end
  endtask

    virtual task wait_for_start ();
        if (ep_cfg.ep_type == brt_usb_types::ISOCHRONOUS ||
            ep_cfg.ep_type == brt_usb_types::INTERRUPT     
        ) begin
            wait (up_sequencer.shared_status.local_host_status.periodic_ep_run[idx] == 1);
        end 
        else begin
            wait (up_sequencer.shared_status.local_host_status.periodic_ep_run == 0 &&
                  up_sequencer.shared_status.local_host_status.nonperiodic_ep_run == 1
            );
        end
    endtask : wait_for_start

    virtual function bit chk_for_start ();
        if (ep_cfg.ep_type == brt_usb_types::ISOCHRONOUS ||
            ep_cfg.ep_type == brt_usb_types::INTERRUPT     
        ) begin
            return (up_sequencer.shared_status.local_host_status.periodic_ep_run[idx] == 1);
        end 
        else begin
            return (up_sequencer.shared_status.local_host_status.periodic_ep_run == 0 &&
                  up_sequencer.shared_status.local_host_status.nonperiodic_ep_run == 1
            );
        end
    endfunction : chk_for_start

    virtual task clear_run_status ();
        if (ep_cfg.ep_type == brt_usb_types::ISOCHRONOUS ||
            ep_cfg.ep_type == brt_usb_types::INTERRUPT     
        ) begin
            up_sequencer.shared_status.local_host_status.periodic_ep_run[idx] = 0;
        end 
        else begin
        end
    endtask : clear_run_status

    virtual function gen_data_patten (bit[7:0] indata[] = {});
        if (indata.size() == 0) begin
            data8 = new [`DATA8_SIZE];
            for (int i=0; i < `DATA8_SIZE/2; i++) begin
                data8[2*i]   = i/256;
                data8[2*i+1] = i%256;
            end
        end
        else begin
            data8 = new[indata.size()];
            foreach (indata[i]) begin
                data8[i] = indata[i];
            end
        end
    endfunction:gen_data_patten

  virtual task req_delay(brt_usb_packet p);
    int bit_time;
    if      (p.speed == brt_usb_types::HS) bit_time = 2083;
    else if (p.speed == brt_usb_types::FS) bit_time = 83320;
    else if (p.speed == brt_usb_types::LS) bit_time = 666666;
    #(p.inter_pkt_dly - bit_time);
    `brt_info (get_name(), $psprintf ("Inter packet delay: %t", p.inter_pkt_dly), UVM_LOW)
  endtask

  virtual function void check_packet_valid(brt_usb_packet p);
    `brt_info(get_name(), $psprintf("CHECK Packet %s", p.sprint()), UVM_HIGH)
    if (p.pid_name == brt_usb_packet::DATA0 || p.pid_name == brt_usb_packet::DATA1 || p.pid_name == brt_usb_packet::DATA2 || p.pid_name == brt_usb_packet::MDATA) begin
      assert (p.data_crc16 == p.calculate_data_crc16()) else begin
        `brt_error(get_name(), $psprintf("data crc16 error calc %h vs rx %h", p.calculate_data_crc16(), p.data_crc16))
        end
      end
  endfunction

  virtual task do_bulk_transfer(brt_usb_transfer t, output bit accepted);
    accepted = 1;
    case (t.xfer_type)
      brt_usb_transfer::BULK_OUT_TRANSFER: do_bulk_write(t, accepted);
      brt_usb_transfer::BULK_IN_TRANSFER:  do_bulk_read(t, accepted);
      default: `brt_fatal(get_name(), "unsupported transfer")
    endcase
  endtask

  virtual task do_isochronous_transfer(brt_usb_transfer t, output bit accepted);
    `brt_info(get_name(), $psprintf("Do Isochronous transfer... "), UVM_LOW)
    accepted = 1;
    case (t.xfer_type)
      brt_usb_transfer::ISOCHRONOUS_OUT_TRANSFER:     do_isochronous_write(t, accepted);
      brt_usb_transfer::ISOCHRONOUS_IN_TRANSFER:     do_isochronous_read(t, accepted);
      default: `brt_fatal(get_name(), "unsupported transfer")
    endcase
    `brt_info(get_name(), $psprintf("Done Isochronous transfer... "), UVM_LOW)
  endtask

  virtual task do_interrupt_transfer(brt_usb_transfer t, output bit accepted);
    accepted = 1;
    case (t.xfer_type)
      brt_usb_transfer::INTERRUPT_OUT_TRANSFER:     do_interrupt_write(t, accepted);
      brt_usb_transfer::INTERRUPT_IN_TRANSFER:     do_interrupt_read(t, accepted);
      default: `brt_fatal(get_name(), "unsupported transfer")
    endcase
  endtask

  virtual task do_control_transfer(brt_usb_transfer t, output bit accepted);
    accepted = 1;
    case (t.setup_data_bmrequesttype_dir)
      brt_usb_types::HOST_TO_DEVICE: do_control_write(t, accepted);
      brt_usb_types::DEVICE_TO_HOST: do_control_read(t, accepted);
      default: `brt_fatal(get_name(), "unsupported transfer")
    endcase
  endtask

  virtual task do_interrupt_read(brt_usb_transfer t, output bit accepted);
    // USB2.0 Sec 8.5.4 ... behaves the same as the bulk transaction
    do_bulk_in_transaction_loop(t, accepted);
  endtask

  virtual task do_interrupt_write(brt_usb_transfer t, output bit accepted);
    // USB2.0 Sec 8.5.4 ... behaves the same as the bulk transaction
    do_bulk_out_transaction_loop(t, accepted);
  endtask

  virtual task do_bulk_read(brt_usb_transfer t, output bit accepted);
    // USB2.0 Sec 8.5.2 The host always initializes the first transaction of a bus transfer to the Data0 PID with a configurationevent.
    // The second transaction uses a Data1 PID and successive data transfers alternate for the remainder of the bulk transfer.
    do_bulk_in_transaction_loop(t, accepted);
  endtask

  virtual task do_bulk_write(brt_usb_transfer t, output bit accepted);
    do_bulk_out_transaction_loop(t, accepted);
  endtask

  virtual task do_isochronous_read(brt_usb_transfer t, output bit accepted);
    //do_isochronous_in_transaction_loop(t, mps, 0, accepted);
    do_isochronous_in_transaction_loop(t, accepted);
  endtask

  virtual task do_isochronous_write(brt_usb_transfer t, output bit accepted);
    //do_isochronous_out_transaction_loop(t, mps, 0, accepted);
    do_isochronous_out_transaction_loop(t, accepted);
  endtask

  virtual task do_isochronous_out_transaction_loop(brt_usb_transfer t, output bit accepted);
        bit                     xfer_done;
        int                     total_byte_size, rem_size, payload_size;
        int                     mps;
        bit                     need_zero_len;
        int                     num_pkt;
        brt_usb_packet::pid_name_e  pkt_pid;
        brt_usb_packet::pid_name_e  pkt_pid_q[$];
        brt_usb_packet              req_pkt, rsp_pkt;
        // endpoint status
        brt_usb_endpoint_status     ep_status;

        total_byte_size     = t.payload.data.size();

        // Find EP cfg
        t.find_ep_cfg (up_sequencer.agt.cfg);
        mps = t.ep_cfg.max_packet_size;
        // Find ep_status
        ep_status = up_sequencer.agt.shared_status.remote_device_status[0].endpoint_status[2*t.ep_cfg.ep_number + (1 & (t.ep_cfg.ep_number == 0))];
        
        // Check number of packet
        if (total_byte_size > (t.ep_cfg.max_burst_size+1)*mps) begin
            `brt_fatal (get_name(), $psprintf("Over payload size total_byte_size: %d, ESITPayload: %d",total_byte_size, (t.ep_cfg.max_burst_size+1)*mps))
        end

        if (t.cfg.speed == brt_usb_types::FS) begin
            if (total_byte_size > mps) begin
                `brt_fatal (get_name(), $psprintf("Over payload size %d",total_byte_size))
            end
            pkt_pid_q.push_back(brt_usb_packet::DATA0);
        end
        else if (t.cfg.speed == brt_usb_types::HS) begin
            if ((mps < 513 && total_byte_size >   mps)||
                (mps < 683 && total_byte_size > 2*mps)||
                (total_byte_size > 3*mps)
                ) begin
                `brt_fatal (get_name(), $psprintf("Over payload size %d, mps: %d",total_byte_size, mps))
            end

            if (total_byte_size > 0) begin
                num_pkt = (total_byte_size + mps - 1)/mps;  // round up
            end
            else begin
                num_pkt = 1;
            end

            if (num_pkt == 1) begin
                pkt_pid_q.push_back(brt_usb_packet::DATA0);
            end
            else if (num_pkt == 2) begin
                pkt_pid_q.push_back(brt_usb_packet::MDATA);
                pkt_pid_q.push_back(brt_usb_packet::DATA1);
            end
            else if (num_pkt == 3) begin
                pkt_pid_q.push_back(brt_usb_packet::MDATA);
                pkt_pid_q.push_back(brt_usb_packet::MDATA);
                pkt_pid_q.push_back(brt_usb_packet::DATA2);
            end

            //for (int i = num_pkt - 1; i >= 0; i--) begin
            //    if (i == 0) pkt_pid_q.push_back(brt_usb_packet::DATA0);
            //    if (i == 1) pkt_pid_q.push_back(brt_usb_packet::DATA1);
            //    if (i == 2) pkt_pid_q.push_back(brt_usb_packet::DATA2);
            //end
        end
        else begin
            `brt_fatal (get_name(), $psprintf("Not support speed %s",t.cfg.speed.name()))
        end

        // Check transfer type
        t.chk_xfer_type();
        // Start
        `brt_info(get_name(), $psprintf("ISO Out total_byte_size %0d, ", total_byte_size), UVM_LOW)

        pkt_phase     =  brt_usb_types::TOKEN_PHASE;
        pre_pkt_phase =  brt_usb_types::TOKEN_PHASE;
        // wait
        wait_for_start();
        // get key
        up_sequencer.shared_status.local_host_status.xfer_key.get();
        do begin 
            case (pkt_phase)
                brt_usb_types::TOKEN_PHASE: begin
                    req_pkt = brt_usb_packet::type_id::create();
                    req_pkt.speed = t.cfg.speed;  // For randomize inter packet delay
                    req_pkt.rx_to_tx = 0;         // For randomize inter packet delay
                    start_item(req_pkt);
                    if (!req_pkt.randomize() with {pid_name == brt_usb_packet::OUT; func_address == t.device_address; endp == t.endpoint_number;})
                      `brt_fatal(get_name(), "randomize error")

                    finish_packet(req_pkt, t);
                    get_response_packet(rsp_pkt, t); 
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    pkt_phase = brt_usb_types::DATA_PHASE;
                end
                brt_usb_types::DATA_PHASE: begin
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
                    req_pkt.speed = t.cfg.speed;  // For randomize inter packet delay
                    req_pkt.rx_to_tx = 0;         // For randomize inter packet delay
                    start_item(req_pkt);
                    if (!req_pkt.randomize() with {pid_name == pkt_pid; data_size == payload_size; func_address == t.device_address; endp == t.endpoint_number;})
                      `brt_fatal(get_name(), "randomize error")
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
                    // trasnfer done
                    if (pkt_pid_q.size() == 0) begin
                        xfer_done = 1;
                        accepted  = 1;
                    end
                end
            endcase
        end while (!xfer_done);
        // clear run if iso endpoint
        clear_run_status();
        // return key
        up_sequencer.shared_status.local_host_status.xfer_key.put();
  endtask : do_isochronous_out_transaction_loop

  virtual task do_isochronous_in_transaction_loop(brt_usb_transfer t, output bit accepted);
        bit                     xfer_done;
        int                     total_byte_size, rem_size, payload_size = -1;
        int                     mps;
        int                     need_zero_len;
        int                     num_pkt;
        brt_usb_packet::pid_name_e  pkt_pid, pkt_pid_q[$];
        brt_usb_packet              req_pkt, rsp_pkt, pre_data_pkt;
        // endpoint status
        brt_usb_endpoint_status     ep_status;

        total_byte_size     = t.payload_intended_byte_count;

        // Find EP cfg
        t.find_ep_cfg (up_sequencer.agt.cfg);
        mps = t.ep_cfg.max_packet_size;
        // Find ep_status
        ep_status = up_sequencer.agt.shared_status.remote_device_status[0].endpoint_status[2*t.ep_cfg.ep_number + 1];
        
        // Check transfer type
        t.chk_xfer_type();

        // Check number of packet
        if (total_byte_size > (t.ep_cfg.max_burst_size+1)*mps) begin
            `brt_fatal (get_name(), $psprintf("Over payload size total_byte_size: %d, ESITPayload: %d",total_byte_size, (t.ep_cfg.max_burst_size+1)*mps))
        end

        if (t.cfg.speed == brt_usb_types::FS) begin
            if (total_byte_size > mps) begin
                `brt_fatal (get_name(), $psprintf("Over payload size %d",total_byte_size))
            end
            pkt_pid_q.push_back(brt_usb_packet::DATA0);
        end
        else if (t.cfg.speed == brt_usb_types::HS) begin
            if ((mps < 513 && total_byte_size >   mps)||
                (mps < 683 && total_byte_size > 2*mps)||
                (total_byte_size > 3*mps)
                ) begin
                `brt_fatal (get_name(), $psprintf("Over payload size %d, mps: %d",total_byte_size, mps))
            end
            num_pkt = (total_byte_size + mps - 1)/mps;  // round up

            //for (int i = num_pkt - 1; i >= 0; i--) begin
            //    if (i == 0) pkt_pid_q.push_back(brt_usb_packet::DATA0);
            //    if (i == 1) pkt_pid_q.push_back(brt_usb_packet::DATA1);
            //    if (i == 2) pkt_pid_q.push_back(brt_usb_packet::DATA2);
            //end
        end
        else begin
            `brt_fatal (get_name(), $psprintf("Not support speed %s",t.cfg.speed.name()))
        end

        // Start
        `brt_info(get_name(), $psprintf("%s total_byte_size %0d, ", t.xfer_type, total_byte_size), UVM_LOW)

        pkt_phase     =  brt_usb_types::TOKEN_PHASE;
        pre_pkt_phase =  brt_usb_types::TOKEN_PHASE;
        pkt_pid       =  brt_usb_packet::IN;
        // wait
        wait_for_start();
        // get key
        up_sequencer.shared_status.local_host_status.xfer_key.get();
        do begin 
            case (pkt_phase)
                brt_usb_types::TOKEN_PHASE: begin
                    req_pkt = brt_usb_packet::type_id::create();
                    req_pkt.speed = t.cfg.speed;  // For randomize inter packet delay
                    req_pkt.rx_to_tx = 0;         // For randomize inter packet delay
                    start_item(req_pkt);
                    if (!req_pkt.randomize() with {pid_name == brt_usb_packet::IN; func_address == t.device_address; endp == t.endpoint_number;})
                      `brt_fatal(get_name(), "randomize error")
                    
                    req_pkt.need_rsp = 1;  // Need data response
                    finish_packet(req_pkt, t);
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    if (req_pkt.need_timeout) begin
                        pkt_phase = brt_usb_types::TIMEOUT_PHASE;
                    end
                    else begin
                        pkt_phase = brt_usb_types::DATA_PHASE;
                    end
                end
                brt_usb_types::DATA_PHASE: begin
                    get_response_packet(rsp_pkt, t); 

                    // Check response packet
                    if (pre_pkt_phase == brt_usb_types::TOKEN_PHASE) begin
                        // Change phase
                        pre_pkt_phase = pkt_phase;
                        if (rsp_pkt.pid_name != pkt_pid && pkt_pid != brt_usb_packet::IN) begin
                            `brt_fatal(get_name(), $psprintf("received wrong data0/1/2 PID %s", rsp_pkt.pid_name.name())) 
                        end
                        case (rsp_pkt.pid_name)
                            brt_usb_packet::DATA0: begin
                                xfer_done = 1;
                                accepted  = 1;
                            end
                            brt_usb_packet::DATA1: begin
                                pkt_pid = brt_usb_packet::DATA0;
                            end
                            brt_usb_packet::DATA2: begin
                                pkt_pid = brt_usb_packet::DATA1;
                            end
                            default: begin 
                                `brt_fatal(get_name(), $psprintf("received unsupported handshake %s", rsp_pkt.pid_name.name())) 
                            end
                        endcase
                        // get data
                        foreach(rsp_pkt.data[i]) t.payload.rxdata.push_back(rsp_pkt.data[i]);
                        // update data toggle and position
                        ep_status.dt_toggle = ~ep_status.dt_toggle;
                        payload_size        = rsp_pkt.data.size();
                        t.data_pos          = t.data_pos + payload_size;
                        pkt_phase           = brt_usb_types::TOKEN_PHASE;

                        // check transfer done
                        if (t.data_pos > t.payload_intended_byte_count) begin
                            `brt_error(get_name(),$psprintf ("Transfer IN babble, received: %d, expected: %d",t.data_pos, t.payload_intended_byte_count));
                            xfer_done = 1;
                        end
                    end
                    else begin
                        `brt_fatal (get_name(),"Not support this transition of packet phase")
                    end
                end
                brt_usb_types::TIMEOUT_PHASE: begin
                    get_response_packet(rsp_pkt, t);
                    if (!rsp_pkt.is_timeout) begin
                        `brt_fatal(get_name(),"Req packet is error but response packet did not timeout");
                    end
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    pkt_phase = brt_usb_types::TOKEN_PHASE;
                    xfer_done = 1;
                    accepted  = 0;
                end
            endcase
        end while (!xfer_done);
        // clear run if iso endpoint
        clear_run_status();
        // return key
        up_sequencer.shared_status.local_host_status.xfer_key.put();
  endtask : do_isochronous_in_transaction_loop

    virtual task do_bulk_in_transaction_loop(brt_usb_transfer t, output bit accepted);
        bit                     xfer_done;
        int                     total_byte_size, rem_size, payload_size = -1;
        int                     mps;
        int                     need_zero_len;
        int                     num_pkt_si;
        bit                     ignore_pkt;
        int                     num_nak;
        brt_usb_packet::pid_name_e  pkt_pid;
        brt_usb_packet              req_pkt, rsp_pkt, pre_data_pkt;
        // endpoint status
        brt_usb_endpoint_status     ep_status;

        total_byte_size     = t.payload_intended_byte_count;

        // Find EP cfg
        t.find_ep_cfg (up_sequencer.agt.cfg);
        mps = t.ep_cfg.max_packet_size;
        // Find ep_status
        ep_status = up_sequencer.agt.shared_status.remote_device_status[0].endpoint_status[2*t.ep_cfg.ep_number + 1];
        
        // Check transfer type
        t.chk_xfer_type();
        // Start
        `brt_info(get_name(), $psprintf("%s total_byte_size %0d, ", t.xfer_type, total_byte_size), UVM_LOW)

        if (ep_status.ep_state == brt_usb_types::EP_HALT) begin
            `brt_error("EP_HALT","Endpoint is halt, skip trasnfer")
            return;
        end

        num_nak = 0;
        pkt_phase     =  brt_usb_types::TOKEN_PHASE;
        pre_pkt_phase =  brt_usb_types::TOKEN_PHASE;
        do begin 
            case (pkt_phase)
                brt_usb_types::TOKEN_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter TOKEN_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    // wait
                    if (chk_for_start()) begin
                        // Start
                    end
                    else begin
                        if (num_pkt_si > 0) begin
                            up_sequencer.shared_status.local_host_status.xfer_key.put();
                            num_pkt_si = 0;
                        end
                        wait_for_start();
                    end
                    // Check number of NAK
                    if (num_nak >= t.ep_cfg.max_num_nak_per_transfer) begin
                        `brt_error (get_name(), $sformatf("Number of NAK per transfer is too large: %d. Transfer is teminated", num_nak))
                        xfer_done = 1;
                        continue;
                    end
                    if (xfer_terminated == 1) begin
                        `brt_error (get_name(), $sformatf("Transfer is teminated by user"))
                        xfer_done = 1;
                        continue;
                    end
                    // get key
                    if (num_pkt_si <= 0) begin
                        up_sequencer.shared_status.local_host_status.xfer_key.get();
                        num_pkt_si = t.ep_cfg.max_burst_size + 1;
                    end
                    req_pkt = brt_usb_packet::type_id::create();
                    req_pkt.speed = t.cfg.speed;  // For randomize inter packet delay
                    req_pkt.rx_to_tx = 0;         // For randomize inter packet delay
                    start_item(req_pkt);
                    if (!req_pkt.randomize() with {pid_name == brt_usb_packet::IN; func_address == t.device_address; endp == t.endpoint_number;})
                      `brt_fatal(get_name(), "randomize error")
                    
                    req_pkt.need_rsp = 1;  // Need data response
                    finish_packet(req_pkt, t);
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    if (req_pkt.need_timeout) begin
                        pkt_phase = brt_usb_types::TIMEOUT_PHASE;
                    end
                    else begin
                        pkt_phase = brt_usb_types::DATA_PHASE;
                    end
                end
                brt_usb_types::DATA_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter DATA_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    ignore_pkt = 0;
                    get_response_packet(rsp_pkt, t); 
                    
                    if (rsp_pkt.pkt_err) begin
                        if (t.cfg.speed == brt_usb_types::HS) begin 
                            #up_sequencer.cfg.hspktrsp;
                        end
                        else if (t.cfg.speed == brt_usb_types::FS) begin
                            #up_sequencer.cfg.fspktrsp;
                        end
                        else begin
                            #up_sequencer.cfg.lspktrsp;
                        end
                        pkt_phase    = brt_usb_types::TOKEN_PHASE;
                        // return key
                        num_pkt_si--;
                        if (num_pkt_si <= 0) begin
                            up_sequencer.shared_status.local_host_status.xfer_key.put();
                            // clear run if interrupt endpoint
                            clear_run_status();
                        end
                        continue;
                    end
                    // data0/data1
                    pkt_pid = ep_status.dt_toggle? brt_usb_packet::DATA1:brt_usb_packet::DATA0;

                    // Check response packet
                    if (pre_pkt_phase == brt_usb_types::TOKEN_PHASE) begin
                        // Change phase
                        pre_pkt_phase = pkt_phase;
                        case (rsp_pkt.pid_name)
                            brt_usb_packet::NAK: begin
                                num_nak++;
                                pkt_phase = brt_usb_types::TOKEN_PHASE;
                                // return key
                                num_pkt_si--;
                                if (num_pkt_si <= 0) begin
                                    up_sequencer.shared_status.local_host_status.xfer_key.put();
                                    // clear run if interrupt endpoint
                                    clear_run_status();
                                end
                            end
                            brt_usb_packet::STALL: begin
                                // terminate transfer
                                xfer_done  = 1;
                                // Update ep status
                                ep_status.ep_state = brt_usb_types::EP_HALT;
                                // return key
                                up_sequencer.shared_status.local_host_status.xfer_key.put();
                                // clear run if interrupt endpoint
                                clear_run_status();
                            end
                            brt_usb_packet::DATA0,brt_usb_packet::DATA1: begin
                                if (rsp_pkt.pid_name != pkt_pid) begin
                                    `brt_fatal(get_name(), $psprintf("received wrong data0/1 PID %s", rsp_pkt.pid_name.name())) 
                                    ignore_pkt = 1;
                                end

                                // Check zero len of last packet
                                if (need_zero_len == 1) begin
                                    if (rsp_pkt.data.size() > 0) begin
                                        `brt_fatal(get_name(), $psprintf("Expected a zero len data")) 
                                    end
                                end
                                `brt_info(get_name(), "received Data", UVM_HIGH)
                                // get data
                                pre_data_pkt = rsp_pkt;
                                pkt_phase    = brt_usb_types::RSP_PHASE;
                            end
                            default: begin 
                                `brt_error(get_name(), $psprintf("received unsupported handshake %s", rsp_pkt.pid_name.name())) 
                                pkt_phase    = brt_usb_types::TOKEN_PHASE;
                                // return key
                                num_pkt_si--;
                                if (num_pkt_si <= 0) begin
                                    up_sequencer.shared_status.local_host_status.xfer_key.put();
                                    // clear run if interrupt endpoint
                                    clear_run_status();
                                end
                            end
                        endcase
                    end
                    else begin
                        `brt_fatal (get_name(),"Not support this transition of packet phase")
                    end
                end
                brt_usb_types::RSP_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter RSP_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    // Create packet
                    req_pkt = brt_usb_packet::type_id::create();
                    req_pkt.speed = t.cfg.speed;  // For randomize inter packet delay
                    req_pkt.rx_to_tx = 1;         // For randomize inter packet delay
                    start_item(req_pkt);
                    if (!req_pkt.randomize() with {pid_name == brt_usb_packet::ACK;})
                      `brt_fatal(get_name(), "randomize error")
                    // Send
                    finish_packet(req_pkt, t);
                    get_response(rsp_pkt);  // only wait done 
                    #166666ps; //80*2083ps;
                    // Only get data when host send correct ACK
                    if (!req_pkt.pkt_err && !ignore_pkt) begin
                        if (req_pkt.pid_name ==  brt_usb_packet::ACK) begin
                            foreach(pre_data_pkt.data[i]) t.payload.rxdata.push_back(pre_data_pkt.data[i]);
                            // update data toggle and position
                            ep_status.dt_toggle = ~ep_status.dt_toggle;
                            payload_size        = pre_data_pkt.data.size();
                            t.data_pos          = t.data_pos + payload_size;
                            // Clear zero len
                            if (need_zero_len == 1)
                                need_zero_len++;
                            // check transfer done
                            if (t.data_pos > t.payload_intended_byte_count) begin
                                `brt_fatal(get_name(),$psprintf ("Transfer IN babble, received: %d, expected: %d",t.data_pos, t.payload_intended_byte_count));
                                xfer_done = 1;
                            end
                            else if (t.data_pos == t.payload_intended_byte_count) begin
                                `brt_info(get_name(),"Transfer done .............", UVM_LOW);
                                if ( payload_size == mps && t.ep_cfg.allow_aligned_transfer_without_zero_length == 0 && need_zero_len == 0) begin
                                    need_zero_len = 1;
                                end
                                else begin
                                    xfer_done = 1;
                                    accepted  = 1;
                                end
                            end
                            else begin   // not enough data
                                if (payload_size >=0 && payload_size < mps) begin
                                    `brt_info(get_name(),"Transfer done with short packet .............", UVM_LOW);
                                    xfer_done = 1;                            
                                    accepted  = 1;
                                end
                            end
                        end
                    end
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    pkt_phase     = brt_usb_types::TOKEN_PHASE;
                    // return key
                    num_pkt_si--;
                    if (num_pkt_si <= 0 || xfer_done) begin
                        up_sequencer.shared_status.local_host_status.xfer_key.put();
                        // clear run if interrupt endpoint
                        clear_run_status();
                    end
                end
                brt_usb_types::TIMEOUT_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter TIMEOUT_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    get_response_packet(rsp_pkt, t);
                    if (!rsp_pkt.is_timeout) begin
                        `brt_fatal(get_name(),"Req packet is error but response packet did not timeout");
                    end
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    pkt_phase = brt_usb_types::TOKEN_PHASE;
                    // return key
                    num_pkt_si--;
                    if (num_pkt_si <= 0) begin
                        up_sequencer.shared_status.local_host_status.xfer_key.put();
                        // clear run if interrupt endpoint
                        clear_run_status();
                    end
                end
            endcase
        end while (!xfer_done);
        // clear run if interrupt endpoint
        clear_run_status();
    endtask : do_bulk_in_transaction_loop

    virtual task do_bulk_out_transaction_loop(brt_usb_transfer t, output bit accepted);
        bit                     xfer_done;
        int                     total_byte_size, rem_size, payload_size;
        int                     mps;
        bit                     need_zero_len;
        int                     num_pkt_si;
        brt_usb_packet::pid_name_e  pkt_pid;
        brt_usb_packet              req_pkt, rsp_pkt;
        bit                     last_ping;
        bit                     zero_length_after_ping_done;
        int                     num_nak;

        // endpoint status
        brt_usb_endpoint_status     ep_status;

        total_byte_size     = t.payload.data.size();

        // Find EP cfg
        t.find_ep_cfg (up_sequencer.agt.cfg);
        mps = t.ep_cfg.max_packet_size;
        // Find ep_status
        ep_status = up_sequencer.agt.shared_status.remote_device_status[0].endpoint_status[2*t.ep_cfg.ep_number + (1 & (t.ep_cfg.ep_number == 0))];
        
        // Check transfer type
        t.chk_xfer_type();
        // Start
        `brt_info(get_name(), $psprintf("%s total_byte_size %0d, ", t.xfer_type, total_byte_size), UVM_LOW)

        if (ep_status.ep_state == brt_usb_types::EP_HALT) begin
            `brt_error("EP_HALT","Endpoint is halt, skip trasnfer")
            return;
        end

        zero_length_after_ping_done = 0;
        num_nak = 0;
        pkt_phase     =  brt_usb_types::TOKEN_PHASE;
        pre_pkt_phase =  brt_usb_types::TOKEN_PHASE;
        do begin 
            case (pkt_phase)
                brt_usb_types::TOKEN_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter TOKEN_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    // wait
                    if (chk_for_start()) begin
                        // Start
                    end
                    else begin
                        if (num_pkt_si > 0) begin
                            up_sequencer.shared_status.local_host_status.xfer_key.put();
                            num_pkt_si = 0;
                        end
                        wait_for_start();
                    end
                    // Check number of NAK
                    if (num_nak >= t.ep_cfg.max_num_nak_per_transfer) begin
                        `brt_error (get_name(), $sformatf("Number of NAK per transfer is too large: %d. Transfer is teminated", num_nak))
                        xfer_done = 1;
                        continue;
                    end
                    if (xfer_terminated == 1) begin
                        `brt_error (get_name(), $sformatf("Transfer is teminated by user"))
                        xfer_done = 1;
                        continue;
                    end
                    // get key
                    if (num_pkt_si <= 0) begin
                        up_sequencer.shared_status.local_host_status.xfer_key.get();
                        // burst
                        num_pkt_si = t.ep_cfg.max_burst_size + 1;
                    end
                    // create
                    req_pkt = brt_usb_packet::type_id::create();
                    req_pkt.speed = t.cfg.speed;  // For randomize inter packet delay
                    req_pkt.rx_to_tx = 0;         // For randomize inter packet delay
                    start_item(req_pkt);
                    if (!req_pkt.randomize() with {pid_name == brt_usb_packet::OUT; func_address == t.device_address; endp == t.endpoint_number;})
                      `brt_fatal(get_name(), "randomize error")

                    finish_packet(req_pkt, t);
                    get_response_packet(rsp_pkt, t); 
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    pkt_phase = brt_usb_types::DATA_PHASE;
                end
                brt_usb_types::PING_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter PING_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    // get key
                    if (num_pkt_si <= 0) begin
                        up_sequencer.shared_status.local_host_status.xfer_key.get();
                        // burst
                        num_pkt_si = t.ep_cfg.max_burst_size + 1;
                    end
                    req_pkt = brt_usb_packet::type_id::create();
                    req_pkt.speed = t.cfg.speed;  // For randomize inter packet delay
                    req_pkt.rx_to_tx = 0;         // For randomize inter packet delay
                    start_item(req_pkt);
                    if (!req_pkt.randomize() with {pid_name == brt_usb_packet::PING; data_size == 0; func_address == t.device_address; endp == t.endpoint_number;})
                      `brt_fatal(get_name(), "randomize error")

                    req_pkt.need_rsp=1;
                    finish_packet(req_pkt, t);
                    //get_response_packet(rsp_pkt, t); 
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    pkt_phase = brt_usb_types::RSP_PHASE;
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
                        if (payload_size - mps == 0 &&
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
                    req_pkt.speed = t.cfg.speed;  // For randomize inter packet delay
                    req_pkt.rx_to_tx = 0;         // For randomize inter packet delay
                    start_item(req_pkt);
                    if (!req_pkt.randomize() with {pid_name == pkt_pid; data_size == payload_size; func_address == t.device_address; endp == t.endpoint_number;})
                      `brt_fatal(get_name(), "randomize error")
                    // Assign data payload
                    foreach(req_pkt.data[i]) req_pkt.data[i] = t.payload.data[t.data_pos+i];

                    req_pkt.need_rsp=1;
                    req_pkt.gen_data_crc16();
                    // Send
                    finish_packet(req_pkt, t);
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    if (req_pkt.need_timeout) begin
                        pkt_phase = brt_usb_types::TIMEOUT_PHASE;
                    end
                    else begin
                        pkt_phase = brt_usb_types::RSP_PHASE;
                    end
                end
                brt_usb_types::RSP_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter RSP_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    get_response_packet(rsp_pkt, t);
                    if (rsp_pkt.pkt_err || rsp_pkt.drop) begin
                        pkt_phase    = brt_usb_types::TOKEN_PHASE;
                        // return key
                        num_pkt_si--;
                        if (num_pkt_si <= 0) begin
                            up_sequencer.shared_status.local_host_status.xfer_key.put();
                            // clear run if interrupt endpoint
                            clear_run_status();
                        end
                        continue;
                    end
                    // Check response packet
                    if (pre_pkt_phase == brt_usb_types::DATA_PHASE) begin
                        // Change phase
                        pre_pkt_phase = pkt_phase;
                        case (rsp_pkt.pid_name)
                            brt_usb_packet::NAK: begin
                                num_nak++;
                                pkt_phase = brt_usb_types::TOKEN_PHASE;
                            end
                            brt_usb_packet::ACK: begin
                                ep_status.dt_toggle = ~ep_status.dt_toggle;
                                t.data_pos = t.data_pos + payload_size;
                                pkt_phase = brt_usb_types::TOKEN_PHASE;
                                // check tfer done
                                if (t.data_pos == total_byte_size && need_zero_len == 0 ) begin
                                    xfer_done  = 1;
                                    accepted   = 1;
                                end
                            end
                            brt_usb_packet::STALL: begin
                                // terminate transfer
                                xfer_done  = 1;
                                // Update ep status
                                ep_status.ep_state = brt_usb_types::EP_HALT;
                            end
                            brt_usb_packet::NYET: begin 
                                ep_status.dt_toggle = ~ep_status.dt_toggle;
                                t.data_pos = t.data_pos + payload_size;
                                // Status phase not support NYET
                                if ( t.xfer_type          == brt_usb_transfer::CONTROL_TRANSFER &&
                                    (t.control_xfer_state == brt_usb_transfer::STATUS_STATE || t.control_xfer_state == brt_usb_transfer::SETUP_STATE)
                                   ) begin
                                    `brt_fatal (get_name(),$sformatf ("Receive NYET in %s",t.control_xfer_state))
                                end
                                // Check data size
                                if (req_pkt.data.size() == mps) begin
                                    if (p_sequencer.agt.cfg.ping_support == 1) begin
                                        pkt_phase = brt_usb_types::PING_PHASE;
                                        if (t.data_pos == total_byte_size) begin
                                            if (!up_sequencer.agt.cfg.need_last_ping) begin
                                                xfer_done = 1;
                                            end
                                            else begin
                                                if (t.ep_cfg.allow_zero_length_after_ping == 0) begin
                                                    last_ping = 1;
                                                end
                                                else begin
                                                    zero_length_after_ping_done = 1;
                                                end
                                            end
                                            accepted  = 1;
                                        end
                                    end
                                    else begin
                                        pkt_phase = brt_usb_types::TOKEN_PHASE;
                                    end
                                end
                                else if (req_pkt.data.size() == 0) begin
                                    `brt_warning ("NYET_ZERO_PKT", "Receive NYET for zero packet")
                                    pkt_phase = brt_usb_types::PING_PHASE;
                                    if (!up_sequencer.agt.cfg.need_last_ping) begin
                                        xfer_done = 1;
                                    end
                                    else begin
                                        if (zero_length_after_ping_done == 1) begin
                                            xfer_done = 1;
                                        end
                                        else begin
                                            last_ping = 1;
                                        end
                                    end
                                    accepted  = 1;
                                end
                                else begin
                                    pkt_phase = brt_usb_types::PING_PHASE;
                                    if (!up_sequencer.agt.cfg.need_last_ping) begin
                                        xfer_done = 1;
                                    end
                                    else begin
                                        if (t.ep_cfg.allow_zero_length_after_ping == 0) begin
                                            last_ping = 1;
                                        end
                                        else begin
                                            zero_length_after_ping_done = 1;
                                        end
                                    end
                                    accepted  = 1;
                                end
                                // not bulk-out and not control-write
                                if (t.xfer_type != brt_usb_transfer::BULK_OUT_TRANSFER &&
                                    !(t.xfer_type == brt_usb_transfer::CONTROL_TRANSFER && t.setup_data_bmrequesttype_dir == brt_usb_types::HOST_TO_DEVICE)
                                    ) begin
                                     `brt_fatal(get_name(), "received NYET in non-bulk out transfer")
                                end
                                if (t.cfg.speed == brt_usb_types::HS) begin 
                                     `brt_info(get_name(), "received NYET in HS speed", UVM_LOW)
                                end
                                else begin
                                     `brt_fatal(get_name(), "received NYET in LS/FS speed")
                                end
                            end // NYET
                            default: begin 
                                `brt_error(get_name(), $psprintf("received unsupported handshake %s", rsp_pkt.pid_name.name())) 
                                pkt_phase = brt_usb_types::TOKEN_PHASE;
                            end
                        endcase
                    end
                    else if (pre_pkt_phase == brt_usb_types::PING_PHASE) begin
                        // Change phase
                        pre_pkt_phase = pkt_phase;
                        if (req_pkt.pid_format[3:0] == brt_usb_packet::PING) begin
                            case (rsp_pkt.pid_name)
                                brt_usb_packet::NAK: begin
                                    num_nak++;
                                    pkt_phase = brt_usb_types::PING_PHASE;
                                end
                                brt_usb_packet::ACK: begin
                                    xfer_done = last_ping;
                                    pkt_phase = brt_usb_types::TOKEN_PHASE;
                                end
                                brt_usb_packet::STALL: begin
                                    // terminate transfer
                                    xfer_done  = 1;
                                    // Update ep status
                                    ep_status.ep_state = brt_usb_types::EP_HALT;
                                end
                                default: begin 
                                    `brt_error(get_name(), $psprintf("received unsupported handshake %s", rsp_pkt.pid_name.name())) 
                                    pkt_phase = brt_usb_types::PING_PHASE;
                                end
                            endcase
                        end
                        else begin
                            pkt_phase = brt_usb_types::PING_PHASE;
                        end
                    end
                    else begin
                        `brt_fatal (get_name(),"Not support this transition of packet phase")
                    end

                    // return key
                    num_pkt_si--;
                    if (num_pkt_si <= 0 || xfer_done) begin
                        up_sequencer.shared_status.local_host_status.xfer_key.put();
                        // clear run if interrupt endpoint
                        clear_run_status();
                    end
                end
                brt_usb_types::TIMEOUT_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter TIMEOUT_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    get_response_packet(rsp_pkt, t);
                    if (!rsp_pkt.is_timeout) begin
                        `brt_fatal(get_name(),"Req packet is error but response packet did not timeout");
                    end

                    if (pre_pkt_phase == brt_usb_types::PING_PHASE) begin
                        pkt_phase = brt_usb_types::PING_PHASE;
                    end
                    else begin
                        pkt_phase = brt_usb_types::TOKEN_PHASE;
                    end
                    // Change phase
                    pre_pkt_phase = brt_usb_types::TIMEOUT_PHASE;
                    // return key
                    num_pkt_si--;
                    if (num_pkt_si <= 0) begin
                        up_sequencer.shared_status.local_host_status.xfer_key.put();
                        // clear run if interrupt endpoint
                        clear_run_status();
                    end
                end
            endcase
        end while (!xfer_done);
        // clear run if interrupt endpoint
        clear_run_status();
    endtask : do_bulk_out_transaction_loop

    virtual task do_control_setup_stage(brt_usb_transfer t);
    // Setup Stage: setup token + 8bytes data0
    // . USB2.0 Sec 8.4.6.4 Upon receiving a SETUP token, a function must accept the data. 
    // A function may not respond to a SETUP token with either STALL or NAK, and 
    // the receiving function must accept the data packet that follows the SETUP token.
        bit                     xfer_done;
        int                     total_byte_size, rem_size, payload_size;
        brt_usb_packet::pid_name_e  pkt_pid;
        brt_usb_packet              req_pkt, rsp_pkt;
        // endpoint status
        brt_usb_endpoint_status     ep_status;

        total_byte_size     = 8;

        // Find EP cfg
        t.find_ep_cfg (up_sequencer.agt.cfg);
        // Find ep_status
        ep_status = up_sequencer.agt.shared_status.remote_device_status[0].endpoint_status[2*t.ep_cfg.ep_number + (1 & (t.ep_cfg.ep_number == 0))];
        ep_status.dt_toggle = 0;
        
        // Check transfer type
        t.chk_xfer_type();
        // Start
        `brt_info(get_name(), $psprintf("Host enters SETUP state"), UVM_HIGH)

        if (ep_status.ep_state == brt_usb_types::EP_HALT) begin
            `brt_error("EP_HALT","Endpoint is halt, skip trasnfer")
            return;
        end

        pkt_phase     =  brt_usb_types::TOKEN_PHASE;
        pre_pkt_phase =  brt_usb_types::TOKEN_PHASE;
        do begin 
            case (pkt_phase)
                brt_usb_types::TOKEN_PHASE: begin
                    // wait
                    wait_for_start();
                    // get key
                    up_sequencer.shared_status.local_host_status.xfer_key.get();
                    req_pkt = brt_usb_packet::type_id::create();
                    req_pkt.speed = t.cfg.speed;  // For randomize inter packet delay
                    req_pkt.rx_to_tx = 0;         // For randomize inter packet delay
                    start_item(req_pkt);
                    if (!req_pkt.randomize() with {pid_name == brt_usb_packet::SETUP; func_address == t.device_address; endp == t.endpoint_number;})
                      `brt_fatal(get_name(), "randomize error")

                    finish_packet(req_pkt, t);
                    get_response_packet(rsp_pkt, t); 
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    pkt_phase = brt_usb_types::DATA_PHASE;
                end
                brt_usb_types::DATA_PHASE: begin
                    // data0/data1
                    pkt_pid = ep_status.dt_toggle? brt_usb_packet::DATA1:brt_usb_packet::DATA0;

                    // data payload
                    payload_size = 8;
                    // Create packet
                    req_pkt = brt_usb_packet::type_id::create();
                    req_pkt.speed = t.cfg.speed;  // For randomize inter packet delay
                    req_pkt.rx_to_tx = 0;         // For randomize inter packet delay
                    start_item(req_pkt);
                    if (!req_pkt.randomize() with {pid_name == pkt_pid; data_size == payload_size; func_address == t.device_address; endp == t.endpoint_number;})
                      `brt_fatal(get_name(), "randomize error")
                    // Assign data payload
                    req_pkt.data[0] = t.setup_data_bmrequesttype;
                    req_pkt.data[1] = t.setup_data_brequest;
                    req_pkt.data[2] = t.setup_data_w_value[7:0];
                    req_pkt.data[3] = t.setup_data_w_value[15:8];
                    req_pkt.data[4] = t.setup_data_w_index[7:0];
                    req_pkt.data[5] = t.setup_data_w_index[15:8];
                    req_pkt.data[6] = t.setup_data_w_length[7:0];
                    req_pkt.data[7] = t.setup_data_w_length[15:8];

                    req_pkt.need_rsp=1;
                    req_pkt.gen_data_crc16();
                    // Send
                    finish_packet(req_pkt, t);
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    if (req_pkt.need_timeout) begin
                        pkt_phase = brt_usb_types::TIMEOUT_PHASE;
                    end
                    else begin
                        pkt_phase = brt_usb_types::RSP_PHASE;
                    end
                end
                brt_usb_types::RSP_PHASE: begin
                    get_response_packet(rsp_pkt, t);
                    // Check response packet
                    if (pre_pkt_phase == brt_usb_types::DATA_PHASE) begin
                        // Change phase
                        pre_pkt_phase = pkt_phase;
                        case (rsp_pkt.pid_name)
                            brt_usb_packet::NAK: begin
                                `brt_error ("RCV_NAK", "Not expeceted to receive NAK in setup phase")
                                pkt_phase = brt_usb_types::TOKEN_PHASE;
                            end
                            brt_usb_packet::ACK: begin
                                if (!rsp_pkt.pkt_err) begin
                                    ep_status.dt_toggle = ~ep_status.dt_toggle;
                                    xfer_done  = 1;
                                end
                                pkt_phase = brt_usb_types::TOKEN_PHASE;
                            end
                            brt_usb_packet::STALL: begin
                                // terminate transfer
                                xfer_done  = 1;
                                // Update ep status
                                ep_status.ep_state = brt_usb_types::EP_HALT;
                                `brt_error ("RCV_STALL", "Not expeceted to receive STALL in setup phase")
                            end
                            default: begin 
                                `brt_error(get_name(), $psprintf("received unsupported handshake %s", rsp_pkt.pid_name.name())) 
                                pkt_phase = brt_usb_types::TOKEN_PHASE;
                            end
                        endcase
                    end
                    else begin
                        `brt_fatal (get_name(),"Not support this transition of packet phase")
                    end
                    // return key
                    up_sequencer.shared_status.local_host_status.xfer_key.put();
                end
                brt_usb_types::TIMEOUT_PHASE: begin
                    get_response_packet(rsp_pkt, t);
                    if (!rsp_pkt.is_timeout) begin
                        `brt_fatal(get_name(),"Req packet is error but response packet did not timeout");
                    end
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    pkt_phase = brt_usb_types::TOKEN_PHASE;
                    // return key
                    up_sequencer.shared_status.local_host_status.xfer_key.put();
                end
            endcase
        end while (!xfer_done);
  endtask: do_control_setup_stage

  virtual function void check_retry_count(inout int nak_count);
    nak_count++;
    if (nak_count > 1000) begin
      `brt_fatal(get_name(), "retried packet more than 1000 times")
      end
  endfunction

    virtual task do_control_status_stage(brt_usb_transfer t, bit is_read, ref bit accepted);
        brt_usb_transfer    t_status;
        // endpoint status
        brt_usb_endpoint_status     ep_status;

        // Find ep_status
        ep_status = up_sequencer.agt.shared_status.remote_device_status[0].endpoint_status[2*t.ep_cfg.ep_number + 1];
        ep_status.dt_toggle = 1;  // Default for control status

        t_status = new();
        t_status.cfg = t.cfg;
        t_status.randomize() with {
                                    xfer_type inside {brt_usb_transfer::CONTROL_TRANSFER};
                                    payload_intended_byte_count == 0;
                                    device_address == t.device_address;
                                    endpoint_number == t.endpoint_number;
                                };

        t_status.control_xfer_state = brt_usb_transfer::STATUS_STATE;
        accepted = 0;
        if (is_read) begin
            do_bulk_out_transaction_loop(t_status,accepted);
        end
        else begin
            do_bulk_in_transaction_loop(t_status,accepted);
        end
    endtask:do_control_status_stage

  virtual task finish_packet(inout brt_usb_packet p, brt_usb_transfer t);
    bit drop;  

    up_sequencer.prot.pre_brt_usb_20_packet_out_port_put(t,p,drop);

    //if (drop) return;
    
    p.drop = drop;
    req_delay(p);  // need to change to inter packet delay
    finish_item(p);
    p.dir = brt_usb_types::TO_DEVICE;
    //p.pkt_err = p.chk_err();
    void'(p.chk_err());
    if (p.drop) begin
        p.pkt_err = p.drop;  // Retry
    end
    // Accept packet eventhough it has error
    if (p.accept_pkt) begin
        p.pkt_err = 0;
    end
    up_sequencer.prot.packet_trace(t,p);
  endtask

  virtual task get_response_packet(inout brt_usb_packet p, brt_usb_transfer t);
    bit drop;
    get_response(p);
    p.dir = brt_usb_types::TO_HOST;
    if (p.need_rsp) begin
      // check_packet_valid(p);
      // Validate packet
      if (!p.need_timeout && !p.drop) begin
        p.pkt_err = p.chk_err(this.up_sequencer.cfg.ignore_mon_host_err);
      end
      up_sequencer.prot.packet_trace(t,p);
      end
  endtask

  virtual task do_control_read(brt_usb_transfer t, output bit accepted);
    // Control Write: setup+data0 -> out(data1) -> out(data0) -> ... out(data0/1) -> in(data1)
    // Setup Stage: setup token + 8bytes data0
    t.control_xfer_state = brt_usb_transfer::SETUP_STATE;
    do_control_setup_stage(t);

    // TODO: Delay for FW to process the setup packet
    //#2us;

    // Data Stage: out(data1) -> out(data0) -> ...
    // . The Data stage, if present, of a control transfer consits of one or more IN or OUT transactions
    // and follows the same protocol rules as bulk transfers.
    t.control_xfer_state = brt_usb_transfer::DATA_STATE;
    do_bulk_in_transaction_loop(t, accepted);

    // Status Stage: out(data1)
    t.control_xfer_state = brt_usb_transfer::STATUS_STATE;
    do_control_status_stage(t, 1, accepted);
    
    `brt_info(get_name(), "CONTROL READ DONE", UVM_HIGH)
  endtask

  virtual task do_control_write(brt_usb_transfer t, output bit accepted);
    // Control Write: setup+data0 -> out(data1) -> out(data0) -> ... out(data0/1) -> in(data1)
    // Setup Stage: setup token + 8bytes data0
    t.control_xfer_state = brt_usb_transfer::SETUP_STATE;
    do_control_setup_stage(t);

    // Data Stage: out(data1) -> out(data0) -> ...
    // . The Data stage, if present, of a control transfer consits of one or more IN or OUT transactions
    // and follows the same protocol rules as bulk transfers.
    //if (t.byte_size) begin
    if (t.payload_intended_byte_count) begin
      t.control_xfer_state = brt_usb_transfer::DATA_STATE;
      do_bulk_out_transaction_loop(t, accepted);
    end
    else accepted = 1;

    // Status Stage: in(data1)
    t.control_xfer_state = brt_usb_transfer::STATUS_STATE;
    do_control_status_stage(t, 0, accepted);
    
    `brt_info(get_name(), "CONTROL WRITE DONE", UVM_HIGH)
  endtask

// LPM
    virtual task do_lpm_transfer(brt_usb_transfer t, output bit accepted);
      accepted = 1;
      do_lpm_transaction_loop(t, accepted);
    endtask

    virtual task do_lpm_transaction_loop(brt_usb_transfer t, output bit accepted);
        bit                     xfer_done;
        int                     total_byte_size, rem_size, payload_size;
        int                     mps;
        bit                     need_zero_len;
        int                     num_pkt_si;
        brt_usb_packet::pid_name_e  pkt_pid;
        brt_usb_packet              req_pkt, rsp_pkt;

        // endpoint status
        brt_usb_endpoint_status     ep_status;

        total_byte_size     = t.payload.data.size();

        // Find EP cfg
        t.find_ep_cfg (up_sequencer.agt.cfg);
        mps = t.ep_cfg.max_packet_size;
        // Find ep_status
        ep_status = up_sequencer.agt.shared_status.remote_device_status[0].endpoint_status[2*t.ep_cfg.ep_number + (1 & (t.ep_cfg.ep_number == 0))];
        
        // Check transfer type
        //t.chk_xfer_type();
        // Start
        `brt_info(get_name(), $psprintf("LPM transfer starts ..."), UVM_LOW)

        pkt_phase     =  brt_usb_types::TOKEN_PHASE;
        pre_pkt_phase =  brt_usb_types::TOKEN_PHASE;
        do begin 
            case (pkt_phase)
                brt_usb_types::TOKEN_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter TOKEN_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    // wait
                    if (chk_for_start()) begin
                        // Start
                    end
                    else begin
                        if (num_pkt_si > 0) begin
                            up_sequencer.shared_status.local_host_status.xfer_key.put();
                            num_pkt_si = 0;
                        end
                        wait_for_start();
                    end
                    // get key
                    if (num_pkt_si <= 0) begin
                        up_sequencer.shared_status.local_host_status.xfer_key.get();
                        // burst
                        num_pkt_si = t.ep_cfg.max_burst_size + 1;
                    end
                    // create
                    req_pkt = brt_usb_packet::type_id::create();
                    req_pkt.speed = t.cfg.speed;  // For randomize inter packet delay
                    req_pkt.rx_to_tx = 1;         // For randomize inter packet delay
                    start_item(req_pkt);
                    if (!req_pkt.randomize() with {pid_name == brt_usb_packet::EXT; func_address == t.device_address; endp == 0;data_size == 0;})
                      `brt_fatal(get_name(), "randomize error")

                    finish_packet(req_pkt, t);
                    get_response_packet(rsp_pkt, t); 
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    pkt_phase = brt_usb_types::DATA_PHASE;
                end
                brt_usb_types::DATA_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter DATA_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    // Create packet
                    req_pkt = brt_usb_packet::type_id::create();
                    req_pkt.speed = t.cfg.speed;  // For randomize inter packet delay
                    req_pkt.rx_to_tx = 0;         // For randomize inter packet delay
                    start_item(req_pkt);
                    // LPM (DATA0)
                    if (!req_pkt.randomize() with {pid_name == `SUBLPM; lpm_remote_wake == t.lpm_remote_wake; lpm_hird == t.lpm_hird;
                                                                        lpm_link_state == t.lpm_link_state;data_size == 0;
                                                                        func_address == t.device_address; endp == 0;})
                      `brt_fatal(get_name(), "randomize error")
                    // LPM
                    req_pkt.is_lpm = 1;

                    req_pkt.need_rsp=1;
                    req_pkt.gen_token_crc5();
                    // Send
                    finish_packet(req_pkt, t);
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    if (req_pkt.need_timeout) begin
                        pkt_phase = brt_usb_types::TIMEOUT_PHASE;
                    end
                    else begin
                        pkt_phase = brt_usb_types::RSP_PHASE;
                    end
                end
                brt_usb_types::RSP_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter RSP_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    get_response_packet(rsp_pkt, t);
                    if (rsp_pkt.pkt_err || rsp_pkt.drop) begin
                        pkt_phase    = brt_usb_types::TOKEN_PHASE;
                        // return key
                        num_pkt_si--;
                        if (num_pkt_si <= 0) begin
                            up_sequencer.shared_status.local_host_status.xfer_key.put();
                            // clear run if interrupt endpoint
                            clear_run_status();
                        end
                        continue;
                    end
                    // Check response packet
                    if (pre_pkt_phase == brt_usb_types::DATA_PHASE) begin
                        // Change phase
                        pre_pkt_phase = pkt_phase;
                        case (rsp_pkt.pid_name)
                            brt_usb_packet::ACK: begin
                                pkt_phase = brt_usb_types::TOKEN_PHASE;
                                // check tfer done
                                xfer_done  = 1;
                                accepted   = 1;
                                // Enable LPM
                                up_sequencer.agt.cfg.lpm_enable = 1;
                                up_sequencer.agt.cfg.tl1besl = besl_to_time (t.lpm_hird);
                            end
                            brt_usb_packet::STALL: begin
                                // terminate transfer
                                xfer_done  = 1;
                                // Update status
                            end
                            brt_usb_packet::NYET: begin 
                                pkt_phase = brt_usb_types::TOKEN_PHASE;
                            end // NYET
                            default: begin 
                                `brt_fatal(get_name(), $psprintf("received unsupported handshake %s", rsp_pkt.pid_name.name())) 
                                pkt_phase = brt_usb_types::TOKEN_PHASE;
                            end
                        endcase
                    end
                    else begin
                        `brt_fatal (get_name(),"Not support this transition of packet phase")
                    end

                    // return key
                    num_pkt_si--;
                    if (num_pkt_si <= 0 || xfer_done) begin
                        up_sequencer.shared_status.local_host_status.xfer_key.put();
                        // clear run if interrupt endpoint
                        clear_run_status();
                    end
                end
                brt_usb_types::TIMEOUT_PHASE: begin
                    `uvm_info("PKT_PHASE", $psprintf("Enter TIMEOUT_PHASE, add: %d, ep: %d, tfer: %s",t.device_address, t.endpoint_number, t.xfer_type), UVM_HIGH)
                    get_response_packet(rsp_pkt, t);
                    if (!rsp_pkt.is_timeout) begin
                        `brt_fatal(get_name(),"Req packet is error but response packet did not timeout");
                    end
                    // Change phase
                    pre_pkt_phase = pkt_phase;
                    pkt_phase = brt_usb_types::TOKEN_PHASE;
                    // return key
                    num_pkt_si--;
                    if (num_pkt_si <= 0) begin
                        up_sequencer.shared_status.local_host_status.xfer_key.put();
                        // clear run if interrupt endpoint
                        clear_run_status();
                    end
                end
            endcase
        end while (!xfer_done);
        // clear run if interrupt endpoint
        clear_run_status();
    endtask : do_lpm_transaction_loop

    virtual function time hird_to_time (bit[3:0] hird);
        case (hird)
            0:  hird_to_time = 75us;
            1:  hird_to_time = 100us;
            2:  hird_to_time = 150us;
            3:  hird_to_time = 250us;
            4:  hird_to_time = 350us;
            5:  hird_to_time = 450us;
            6:  hird_to_time = 950us;
            7:  hird_to_time = 1950us;
            8:  hird_to_time = 2950us;
            9:  hird_to_time = 3950us;
            10: hird_to_time = 4950us;
            11: hird_to_time = 5950us;
            12: hird_to_time = 6950us;
            13: hird_to_time = 7950us;
            14: hird_to_time = 8950us;
            15: hird_to_time = 9950us;
        endcase
    endfunction: hird_to_time

    virtual function time besl_to_time (bit[3:0] besl);
        besl_to_time = hird_to_time (besl) + 50us;
    endfunction: besl_to_time
endclass:brt_usb_xfer2packet_sequence

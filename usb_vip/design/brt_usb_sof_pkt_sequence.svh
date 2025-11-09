// translate brt_usb transfer to brt_usb packet
class brt_usb_sof_pkt_sequence extends brt_sequence #(brt_usb_packet);
  brt_usb_transfer_sequencer up_sequencer; 

  `brt_object_utils(brt_usb_sof_pkt_sequence)
  `brt_declare_p_sequencer (brt_usb_packet_sequencer)

  function new(string name="");
    super.new(name);
  endfunction

  virtual task finish_packet(inout brt_usb_packet p, brt_usb_transfer t);
    bit drop;  

    up_sequencer.prot.pre_brt_usb_20_packet_out_port_put(t,p,drop);
    if (drop) return;
    #p.inter_pkt_dly;
    finish_item(p);
    p.dir = brt_usb_types::TO_DEVICE;
    p.pkt_err = p.chk_err();
    up_sequencer.prot.packet_trace(t,p);
  endtask

  virtual task transmit_sof(ref bit enable_sof);
    bit[10:0]           frame_id;
    bit[4:0]            microframe_cnt;
    int                 remained_time;
    int                 remained_payload;
    real                bit_time;
    real                rsp_time;

    event               new_sof;

    brt_usb_packet          sof_pkt;
    brt_usb_transfer        t;
    frame_id = 0;
    microframe_cnt = 0;
    t = brt_usb_transfer::type_id::create("sof_tranfer"); // Dummy transfer
    t.cfg = up_sequencer.agt.cfg;

    fork
        forever begin
          wait(enable_sof);
          // Delay 125us or 1ms
          if (up_sequencer.agt.cfg.speed == brt_usb_types::HS) #125us;
          else #1ms;

          if (enable_sof) begin
            -> new_sof;  // event
          end
        end  // forever
        // Control reamained bytes before SOF
        forever begin
            @(new_sof);
            up_sequencer.shared_status.local_host_status.xfer_key.get();  // get key
            sof_pkt = brt_usb_packet::type_id::create("sof_pkt");
            sof_pkt.speed = up_sequencer.agt.cfg.speed;  // For randomize inter packet delay
            start_item (sof_pkt);
            if (!sof_pkt.randomize() with {pid_name == brt_usb_packet::SOF;frame_num == frame_id;data_size == 0; func_address == t.device_address; endp == t.endpoint_number;})
              `brt_fatal(get_name(), "randomize error")
            sof_pkt.rx_to_tx = 0;         // For randomize inter packet delay
            sof_pkt.need_rsp = 0;  // Need data response
            finish_packet(sof_pkt, t);
            get_response(sof_pkt);

            if (up_sequencer.agt.cfg.speed == brt_usb_types::HS) begin
              microframe_cnt++;
              if (microframe_cnt == 8) begin
                frame_id++;
                microframe_cnt=0;
              end
              // wait
              #166667ps;
            end
            else begin  // FS
              frame_id++;
            end

            // inform start
            -> up_sequencer.shared_status.local_host_status.sof_start;
            up_sequencer.shared_status.local_host_status.xfer_key.put();  // return key
        end  // forever
        forever begin
            @(new_sof);
            if (up_sequencer.agt.cfg.speed == brt_usb_types::HS) begin
                remained_time = 125000; //ns
                bit_time      = 2.0833333;
                rsp_time      = 466;
            end
            else begin
                remained_time = 1000000; //ns
                bit_time      = 83.333333;
                rsp_time      = 7563;
            end
            // Calculate remained data payload each 100ns
            do begin
                #100ns;
                remained_time -= 100;
                remained_payload = (remained_time - rsp_time)/bit_time/8;
                up_sequencer.shared_status.local_host_status.remained_payload = remained_payload;
                `brt_info ("SOF", $psprintf ("remained_payload: %d, remained_time: %d",remained_payload,remained_time ), UVM_DEBUG)

                // Inform end of SOF
                if (remained_payload <=0) begin
                    -> up_sequencer.shared_status.local_host_status.sof_end;
                end
            end while (remained_time > 100);
        end  // forever
    join
  endtask

  virtual task body();
      transmit_sof(up_sequencer.shared_status.local_host_status.enable_tx_sof);
  endtask

endclass:brt_usb_sof_pkt_sequence

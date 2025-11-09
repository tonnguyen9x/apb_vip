class brt_usb_base_sequence_item extends brt_sequence_item;

  bit                need_rsp=0;   // wait for response packet
  bit                tellme=0;     // listen a packet
  bit                dummy=0;
  brt_usb_config     cfg;

  `brt_object_utils_begin(brt_usb_base_sequence_item)
    `brt_field_int     (need_rsp,     UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int     (tellme,     UVM_ALL_ON|UVM_NOPACK)
    `brt_field_object(cfg,           UVM_ALL_ON|UVM_NOPACK);
  `brt_object_utils_end

  function new(string name="brt_usb_base_sequence_item");
    super.new(name);
  endfunction

endclass

class brt_usb_payload extends brt_usb_base_sequence_item;

  rand bit[7:0]         data[];
  rand bit[7:0]         rxdata[$];
  rand int unsigned     byte_count;
  int                     TWO_SEED_BASED_ALGORITHM_wt;
  int                     USER_DEFINED_ALGORITHM_wt;
  
  `brt_object_utils_begin(brt_usb_payload)
    `brt_field_int             (byte_count,                         UVM_ALL_ON|UVM_NOPACK)
    `brt_field_array_int     (data,                                 UVM_ALL_ON|UVM_NOPACK)
    `brt_field_queue_int     (rxdata,                            UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int             (TWO_SEED_BASED_ALGORITHM_wt,    UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int             (USER_DEFINED_ALGORITHM_wt,     UVM_ALL_ON|UVM_NOPACK)
  `brt_object_utils_end

  constraint data_constr {
    data.size() == byte_count;
  }

  function new(string name="brt_usb_payload");
    super.new(name);
  endfunction

endclass

class brt_usb_endpoint_status extends brt_object;
  brt_usb_types::ep_state_e     ep_state;
  bit                       dt_toggle;

  `brt_object_utils_begin(brt_usb_endpoint_status)
    `brt_field_enum            (brt_usb_types::ep_state_e, ep_state, UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (dt_toggle,                            UVM_ALL_ON|UVM_NOPACK);
  `brt_object_utils_end
  function new(string name="brt_usb_endpoint_status");
    super.new(name);
  endfunction
endclass

class brt_usb_device_status extends brt_object;
  int                    device_address=0;
  brt_usb_endpoint_status    endpoint_status[bit[4:0]];  // Index is: 2*endpont number + dir, Exception of EP0 -> index =1
  `brt_object_utils_begin(brt_usb_device_status)
    `brt_field_int            (device_address,                        UVM_ALL_ON|UVM_NOPACK);
    `brt_field_sarray_object(endpoint_status,                        UVM_ALL_ON|UVM_NOPACK);
  `brt_object_utils_end
  function new(string name="brt_usb_device_status");
    super.new(name);
  endfunction
endclass

class brt_usb_host_status extends brt_object;
    // For SOF
    bit         enable_tx_sof;
    event       sof_start;
    event       sof_end;
    int         remained_payload;
    semaphore   xfer_key;
    bit[31:0]   periodic_ep_run;
    bit         nonperiodic_ep_run;

    `brt_object_utils_begin(brt_usb_host_status)
        `brt_field_int            (remained_payload,                        UVM_ALL_ON|UVM_NOPACK);
    `brt_object_utils_end
    function new(string name="brt_usb_host_status");
      super.new(name);
      xfer_key = new(1);
      nonperiodic_ep_run = 1;
    endfunction
endclass

class brt_usb_status extends brt_object;
  brt_usb_types::ltssm_state_e      ltssm_state;
  brt_usb_types::link20sm_state_e   link_usb_20_state;
  brt_usb_types::linestate_value_e  physical_usb_20_linestate;
  brt_usb_device_status             remote_device_status[bit[6:0]];
  brt_usb_host_status               local_host_status;

  `brt_object_utils_begin(brt_usb_status)
    `brt_field_enum            (brt_usb_types::ltssm_state_e,        ltssm_state,                       UVM_ALL_ON|UVM_NOPACK);
    `brt_field_enum            (brt_usb_types::link20sm_state_e,     link_usb_20_state,                 UVM_ALL_ON|UVM_NOPACK);
    `brt_field_enum            (brt_usb_types::linestate_value_e,    physical_usb_20_linestate,         UVM_ALL_ON|UVM_NOPACK);
    `brt_field_sarray_object(remote_device_status,                                                      UVM_ALL_ON|UVM_NOPACK);
    `brt_field_object        (local_host_status,                                                        UVM_ALL_ON|UVM_NOPACK);
  `brt_object_utils_end
  function new(string name="brt_usb_types");
    brt_usb_device_status dst;
    super.new(name);
    remote_device_status.delete();
    dst = brt_usb_device_status::type_id::create("remote_device_status[0]");
    remote_device_status[0] = dst;
    local_host_status = brt_usb_host_status::type_id::create("local_host_status");
  endfunction
endclass

// TODO: For USB3
class brt_usb_symbol_set extends brt_usb_base_sequence_item;

  `brt_object_utils(brt_usb_symbol_set)

  function new(string name="brt_usb_data");
    super.new(name);
  endfunction
endclass

// low level abstraction of USB sequence item
class brt_usb_data extends brt_usb_base_sequence_item;


  // DM     DP        Description
  // 0    0        0: Se0
  // 0     1        1: J State
  // 1     0        2: K State
  // 1    1        3: Se1
  typedef enum {
    DRIVE_J, DRIVE_K, DRIVE_OFF, 
    DRIVE_SE0, DRIVE_SE1
  } non_data_e;

  non_data_e        hs_sync_pat[32];
  non_data_e        lfs_sync_pat[8];
  non_data_e        lfs_eop_pat[];

  bit               data[];
  bit               bit_stuff_data_q[$];
  bit               nrzi_data_q[$];
  bit               bit_stuff_err=0;

  bit               need_timeout;  // Need to check timeout
  bit               is_timeout;    // is timeout occurred?
  int               num_kj;
  rand int          eop_length;
  bit               is_sof;
  bit               ignore_tx_err;
  bit               drop;
  time              pkt_start_t;

  `brt_object_utils_begin(brt_usb_data)
    `brt_field_int (need_timeout,               UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (is_timeout,                 UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (num_kj,                     UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (eop_length,                 UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (is_sof,                     UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (ignore_tx_err,              UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (drop,                       UVM_ALL_ON|UVM_NOPACK)
    `brt_field_real(pkt_start_t,                UVM_ALL_ON|UVM_NOPACK)
  `brt_object_utils_end


  constraint eop_length_constr {
    eop_length < 10; // TODO
    eop_length > 2;
  }

  virtual function void do_data_encoding();
    do_bit_stuffing();
    nrzi_encode();
  endfunction

  virtual function void do_data_decoding();
    bit_stuff_err=0;
    nrzi_decode();
    do_bit_unstuffing();
  endfunction

  virtual function void do_bit_unstuffing();
    int count;
    bit databit;
    bit bit_unstuff_q[$];

    count = 0;
    bit_unstuff_q.delete();
    while(bit_stuff_data_q.size()) begin
      databit = bit_stuff_data_q.pop_front();
      if (databit) count++;
      else count=0;

      bit_unstuff_q.push_back(databit);
      // USB2.0 Sec 7.1.9 ... A zero is inserted after every six consecutive
      // ones in the data stream before the data is NRZI encoded ... The "one"
      // that ends the Sync Pattern is counted as the first one in a sequence.
      if (count == 6 && bit_stuff_data_q.size()) begin
        `brt_info(get_name(), "BIT STUFFING detected ... ", UVM_HIGH)
        count = 0;
        //assert (bit_stuff_data_q.pop_front() == 0) else begin
        if (bit_stuff_data_q.pop_front() == 0) begin end else begin
          // don't finish it here, just flag the error
          bit_stuff_err=1;
          bit_stuff_data_q.push_front(1'b1); // keep the bit for decoding later, because it may be an SOF
          `brt_info(get_name, "bit stuffing error", UVM_HIGH)
          end
        end
      end
 
    this.data = new[bit_unstuff_q.size()];
    foreach (this.data[i]) begin
      this.data[i] = bit_unstuff_q.pop_front();
      end

  endfunction

  virtual function void do_bit_stuffing();
    bit bit_stuff_err_flag;
    int count;
    bit_stuff_data_q.delete();

    // USB2.0 Sec 7.1.9 ... A zero is inserted after every six consecutive
    // ones in the data stream before the data is NRZI encoded ... The "one"
    // that ends the Sync Pattern is counted as the first one in a sequence.

    count=1; // last "one" in Sync pattern is counted
    foreach(data[i]) begin
      if (data[i]) count++;
      else count = 0;
      bit_stuff_data_q.push_back(data[i]);

      if (count==6) begin
        `brt_info(get_name(), "BIT STUFFING ... ", UVM_HIGH)
        if (bit_stuff_err && !bit_stuff_err_flag) begin
            `brt_info(get_name(), "skip inserting BIT STUFFING ... ", UVM_NONE)
            bit_stuff_err_flag = 1;  // Disable
        end
        else begin
            bit_stuff_data_q.push_back(1'b0);
        end
        count = 0;
        end
      end
  endfunction

  virtual function void remove_sync_pattern();
    bit nrzi_bit;
    foreach(hs_sync_pat[i]) begin
      nrzi_bit = nrzi_data_q.pop_front();
      if (hs_sync_pat[i] == DRIVE_K) begin
        assert (nrzi_bit == 0) else `brt_fatal(get_name, "SYNC Pattern failed")
        end
      else begin
        assert (nrzi_bit == 1) else `brt_fatal(get_name, "SYNC Pattern failed")
        end
      end
  endfunction

  virtual function void add_sync_pattern();
    nrzi_data_q.delete();
    foreach(hs_sync_pat[i]) begin
      if (hs_sync_pat[i] == DRIVE_K)
        nrzi_data_q.push_back(1'b0);
      else
        nrzi_data_q.push_back(1'b1);
      end
  endfunction

  virtual function void nrzi_encode();
    bit databit, prev_nrzibit;
    int k;

    //add_sync_pattern();

    // USB2.0 Sec 7.1.8 In NRZI encoding, a "1" is represented by no change in
    // level and a "0" is represented by a change in level
    prev_nrzibit = 0; k = 0;
    while(bit_stuff_data_q.size()) begin
      databit = bit_stuff_data_q.pop_front();
      if (databit) begin // no change in level
        nrzi_data_q.push_back(prev_nrzibit);
        end
      else begin
        nrzi_data_q.push_back(~prev_nrzibit);
        prev_nrzibit = ~prev_nrzibit;
        end
      k++;
      end
  endfunction

  virtual function void nrzi_decode();
    bit prev_nrzibit, nrzibit;
    // sync pattern are not sampled, it is used as clock recovery
    //remove_sync_pattern();
    bit_stuff_data_q.delete();

    prev_nrzibit = 0; // last SYNC is 0
    while (nrzi_data_q.size()) begin
      nrzibit = nrzi_data_q.pop_front();

      if (nrzibit == prev_nrzibit) begin
        bit_stuff_data_q.push_back(1'b1);
        end
      else begin
        bit_stuff_data_q.push_back(1'b0);
        prev_nrzibit = nrzibit;
        end
      end
    
  endfunction

  function void do_unpack(brt_packer packer);
    int total_bit_size;
    super.do_unpack(packer);
    packer.big_endian = 0;
    packer.use_metadata = 1;
    nrzi_data_q.delete();

    total_bit_size = packer.get_packed_size();
    repeat(total_bit_size)
      nrzi_data_q.push_back(packer.unpack_field_int(1));

  endfunction

  function void do_pack(brt_packer packer);
    super.do_pack(packer);
    packer.big_endian = 0;
    packer.use_metadata = 1;

    foreach (nrzi_data_q[i]) begin
      packer.pack_field_int(nrzi_data_q[i], 1);
      end

  endfunction

  function void set_eop();
    lfs_eop_pat = new[eop_length];  
    foreach(lfs_eop_pat[i]) lfs_eop_pat[i] = DRIVE_SE0;
  endfunction

  function new(string name="brt_usb_data");
    super.new(name);
    lfs_sync_pat[0] = DRIVE_K; lfs_sync_pat[1] = DRIVE_J;
    lfs_sync_pat[1] = DRIVE_K; lfs_sync_pat[2] = DRIVE_J;
    lfs_sync_pat[2] = DRIVE_K; lfs_sync_pat[3] = DRIVE_J;
    lfs_sync_pat[4] = DRIVE_K; lfs_sync_pat[5] = DRIVE_K;

    // sync pattern is 15KJ pairs followed by 2K
    hs_sync_pat[0]     = DRIVE_K; hs_sync_pat[1]     = DRIVE_J;
    hs_sync_pat[1]     = DRIVE_K; hs_sync_pat[2]     = DRIVE_J;
    hs_sync_pat[2]     = DRIVE_K; hs_sync_pat[3]     = DRIVE_J;
    hs_sync_pat[3]     = DRIVE_K; hs_sync_pat[4]     = DRIVE_J;
    hs_sync_pat[4]     = DRIVE_K; hs_sync_pat[5]     = DRIVE_J;
    hs_sync_pat[5]     = DRIVE_K; hs_sync_pat[6]     = DRIVE_J;
    hs_sync_pat[6]     = DRIVE_K; hs_sync_pat[7]     = DRIVE_J;
    hs_sync_pat[7]     = DRIVE_K; hs_sync_pat[8]     = DRIVE_J;
    hs_sync_pat[8]     = DRIVE_K; hs_sync_pat[9]     = DRIVE_J;
    hs_sync_pat[9]     = DRIVE_K; hs_sync_pat[10] = DRIVE_J;
    hs_sync_pat[10]     = DRIVE_K; hs_sync_pat[11] = DRIVE_J;
    hs_sync_pat[11]     = DRIVE_K; hs_sync_pat[12] = DRIVE_J;
    hs_sync_pat[12]     = DRIVE_K; hs_sync_pat[13] = DRIVE_J;
    hs_sync_pat[13]     = DRIVE_K; hs_sync_pat[14] = DRIVE_J;
    hs_sync_pat[14]     = DRIVE_K; hs_sync_pat[15] = DRIVE_J;
    hs_sync_pat[15]     = DRIVE_K; hs_sync_pat[16] = DRIVE_K;
  endfunction

endclass:brt_usb_data


class brt_usb_packet extends brt_usb_base_sequence_item;

  typedef enum int {
    LINK_MANAGEMENT_PACKET,
    TRANSACTION_PACKET,
    DATA_PACKET,
    ISOCHRONOUS_TIMESTAMP_PACKET
  } packet_type_e;

  typedef enum bit[3:0] {
    TOKEN, DATA, HANDSHAKE, SPECIAL
  } pid_type_e;  

  typedef enum bit[3:0] {
    OUT         = 4'h1, IN         = 4'h9, SOF     = 4'h5, SETUP         = 4'hd,
    DATA0     = 4'h3, DATA1     = 4'hb, DATA2     = 4'h7, MDATA         = 4'hf,
    ACK         = 4'h2, NAK     = 4'ha, STALL     = 4'he, NYET         = 4'h6,
    PRE_ERR = 4'hc, SPLIT     = 4'h8, PING     = 4'h4, EXT     = 4'h0
  } pid_name_e;  

  rand pid_type_e            pid_type;
  rand pid_name_e            pid_name;
  //rand packet_type_e         pkt_type;

  // LPM bmAttributes
  bit[1:0]                   lpm_reserved;
  rand bit                   lpm_remote_wake;
  rand bit[3:0]              lpm_hird;
  rand bit[3:0]              lpm_link_state;
  // for packing
  bit                        is_lpm;

  rand bit[7:0]              pid_format;
  rand bit[6:0]              func_address;
  rand bit[3:0]              endp;
  rand bit[4:0]              token_crc5;
  rand bit[15:0]             data_crc16;

  rand bit[10:0]             frame_num;
  rand byte                  data[];
  rand int                   data_size;
  bit                        data_babble;

//  brt_usb_payload            payload;
  brt_usb_types::pkt_dir_e   dir;

  rand int unsigned          inter_pkt_dly;
  bit                        rx_to_tx;
  brt_usb_types::speed_e     speed = brt_usb_types::SS;
  int                        num_kj     = -1;
  int                        eop_length = -1;
  
  time                       pkt_start_t;
  // Indicate that this packet is error
  bit               pkt_err;
  bit               pid_err;
  bit               crc5_err;
  bit               crc16_err;
  bit               bit_stuff_err;
  int               bit_stuff_pos;
  bit               need_timeout;  // Need to check timeout
  bit               is_timeout;    // is timeout occurred?

  bit               ignore_chk_err;
  bit               drop;
  bit               accept_pkt;    // Accept this packet eventhough it has error

  `brt_object_utils_begin(brt_usb_packet)
    `brt_field_enum(pid_type_e, pid_type,           UVM_ALL_ON|UVM_NOPACK);
    `brt_field_enum(pid_name_e, pid_name,           UVM_ALL_ON|UVM_NOPACK);
    //`brt_field_enum(packet_type_e, pkt_type,        UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int (lpm_reserved,                   UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (lpm_remote_wake,                UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (lpm_hird,                       UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (lpm_link_state,                 UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (pid_format,                     UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (func_address,                   UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (endp,                           UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (token_crc5,                     UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (data_crc16,                     UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (frame_num,                      UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (data_size,                      UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (data_babble,                    UVM_ALL_ON|UVM_NOPACK)
    `brt_field_array_int (data,                     UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (pkt_err,                        UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (pid_err,                        UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (crc5_err,                       UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (crc16_err,                      UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (bit_stuff_err,                  UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (bit_stuff_pos,                  UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (need_timeout,                   UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (is_timeout,                     UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (ignore_chk_err,                 UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (drop,                           UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (accept_pkt,                     UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (inter_pkt_dly,                  UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (num_kj,                         UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (eop_length,                     UVM_ALL_ON|UVM_NOPACK)
    `brt_field_int (rx_to_tx,                       UVM_ALL_ON|UVM_NOPACK)
    `brt_field_enum(brt_usb_types::speed_e, speed,  UVM_ALL_ON|UVM_NOPACK);
    `brt_field_real(pkt_start_t,                    UVM_ALL_ON|UVM_NOPACK)
  `brt_object_utils_end

  // USB2.0 Sec 8.4.4
  constraint data_constr {
    data_size         >= 0;
    data_size     <= 1024;
    data.size()    == data_size;

    pid_name == SETUP          -> data_size == 0;
    pid_name == IN            -> data_size == 0;
    pid_name == OUT            -> data_size == 0;

    /*cfg.speed == LOW_SPEED     -> data_size <= 8;
    cfg.speed == FULL_SPEED     -> data_size <= 1023;
    cfg.speed == HIGH_SPEED     -> data_size <= 1023;*/
  }

  constraint pid_format_constr {

    pid_format[3:0] == ~pid_format[7:4];

    pid_name == OUT        -> pid_format[3:0] == 4'h1;
    pid_name == IN         -> pid_format[3:0] == 4'h9;
    pid_name == SOF        -> pid_format[3:0] == 4'h5;
    pid_name == SETUP      -> pid_format[3:0] == 4'hd;
    pid_name == DATA0      -> pid_format[3:0] == 4'h3;
    pid_name == DATA1      -> pid_format[3:0] == 4'hb;
    pid_name == DATA2      -> pid_format[3:0] == 4'h7;
    pid_name == MDATA      -> pid_format[3:0] == 4'hf;
    pid_name == ACK        -> pid_format[3:0] == 4'h2;
    pid_name == NAK        -> pid_format[3:0] == 4'ha;
    pid_name == STALL      -> pid_format[3:0] == 4'he;
    pid_name == NYET       -> pid_format[3:0] == 4'h6;
    pid_name == PRE_ERR    -> pid_format[3:0] == 4'hc;
    pid_name == SPLIT      -> pid_format[3:0] == 4'h8;
    pid_name == PING       -> pid_format[3:0] == 4'h4;
    pid_name == EXT        -> pid_format[3:0] == 4'h0;
  }

  constraint pid_types_constr {
    pid_type == TOKEN         -> pid_name inside {OUT,IN,SOF,SETUP};
    pid_type == DATA         -> pid_name inside {DATA0,DATA1,DATA2,MDATA};
    pid_type == HANDSHAKE     -> pid_name inside {ACK,NAK,STALL,NYET};
    pid_type == SPECIAL     -> pid_name inside {PRE_ERR,SPLIT,PING,EXT};

    pid_type == HANDSHAKE -> data_size == 0 && func_address == 0 && endp == 0;
  }

    constraint inter_pkt_dly_constr {
        // FS 2-6.5 FS bit times (166.666ns -> 542ns)
        // HS 8-192 HS bits times (16.6ns -> 400ns), back to back min 32bits times (66.6ns)
        // this is the range that support for both FS and HS: 166.6ns -> 400ns
        if (speed == brt_usb_types::HS) {
            if (rx_to_tx)   inter_pkt_dly inside {[16666:400000]};
            else            inter_pkt_dly inside {[66666:400000]};
        }
        else if (speed == brt_usb_types::FS) {
            inter_pkt_dly inside {[166666:542000]};
        }
        else if (speed == brt_usb_types::LS) {
            inter_pkt_dly inside {[2*666666:6*666666]};
        }
        else {
            inter_pkt_dly inside {[166666:400000]};
        }
    }
  virtual function string sprint_trace(bit[2:0] sw=0);
    string s, data_str;
    s = ""; data_str = "";
    s = $psprintf("Time %10t: %10s Dev address 0x%2h: Ep Number %2d: Payload Size %6d [%s]", $time, pid_name.name(), func_address, endp, data.size(), dir.name());
    if (sw >= 1) begin
      s = $psprintf("PID         : %0s \nDev address : 0x%0h \nEp Number   : %0d \nPayload Size: %0d", pid_name.name(), func_address, endp, data.size());
      end
    if (sw > 1 && data.size()) begin
      foreach(data[i]) data_str = $psprintf("%s%h", data_str, data[i]);
      s = $psprintf("\n%sData        : %0s ", s, data_str);
      end
    return s;
  endfunction

  function new(string name="brt_usb_packet");
    super.new(name);
    //this.payload        = new();
  endfunction

  //virtual function void update_data();
  //  this.payload.data = new[this.data.size()];
  //  foreach(payload.data[i]) payload.data[i] = this.data[i];
  //  //this.payload.data = this.data; // Can not work in VCS
  //endfunction

  function void post_randomize();
    gen_token_crc5();
    gen_data_crc16();
    if (speed == brt_usb_types::SS) begin
        `brt_fatal (get_name(), "speed variable of packet should be set as HS/FS/LS for timing randomization")
    end
  endfunction

    virtual function bit chk_err(bit ignore_err = 0);
        chk_err = 0;
        ignore_err |= ignore_chk_err;

        if (pid_format[3:0] != ~pid_format[7:4]) begin  // Error PID
            chk_err = 1;
            pid_err = 1;
            if (!ignore_err) `brt_error(get_name(),$psprintf ("PID checksum is not correct %b", pid_format))
        end
        //else if (pid_format[3:0] == 0) begin
        //    chk_err = 1;
        //    if (!ignore_err) `brt_fatal(get_name(),$psprintf ("PID checksum is zero %b", pid_format))
        //end

        // CRC5, CRC16
        if (
                    pid_format[3:0] == 4'h1 ||            // pid_name == OUT     
                    pid_format[3:0] == 4'h9 ||            // pid_name == IN      
                    pid_format[3:0] == 4'h5 ||            // pid_name == SOF     
                    pid_format[3:0] == 4'hd ||            // pid_name == SETUP   
                    pid_format[3:0] == 4'h4 ||            // pid_name == PING    
                    pid_format[3:0] == 4'h0 ||            // pid_name == EXT     
                    (pid_format[3:0] == `SUBLPM && is_lpm)// pid_name == LPM     
                ) begin
            if (chk_token_crc5()) begin
                chk_err = 1;
                crc5_err = 1;
                if (!ignore_err) `brt_error(get_name(),$psprintf ("CRC5 checksum is not correct"))
            end
        end
        else if (
                    pid_format[3:0] == 4'h3 ||            // pid_name == DATA0   
                    pid_format[3:0] == 4'hb ||            // pid_name == DATA1   
                    pid_format[3:0] == 4'h7 ||            // pid_name == DATA2   
                    pid_format[3:0] == 4'hf               // pid_name == MDATA   
                ) begin
            if (chk_crc16()) begin
                chk_err = 1;
                crc16_err = 1;
                if (!ignore_err) `brt_error(get_name(),$psprintf ("CRC16 checksum is not correct"))
            end
        end
        else if (
                    pid_format[3:0] == 4'h2 ||            // pid_name == ACK     
                    pid_format[3:0] == 4'ha ||            // pid_name == NAK     
                    pid_format[3:0] == 4'he ||            // pid_name == STALL   
                    pid_format[3:0] == 4'h6 ||            // pid_name == NYET    
                    pid_format[3:0] == 4'h0               // pid_name == EXT    
                    //pid_format[3:0] == 4'hc ||            // pid_name == PRE_ERR 
                    //pid_format[3:0] == 4'h8               // pid_name == SPLIT   
                ) begin
        end
        else begin
            chk_err = 1;
            if (!ignore_err) `brt_fatal(get_name(),$psprintf ("PID is not expected %b", pid_format))
        end
        
        chk_err |= pkt_err;
    endfunction: chk_err

  virtual function void gen_token_crc5();
    bit[10:0] token_data;
    bit[4:0] crc5;

    if (pid_name == SOF) begin
        token_data     = frame_num;
    end
    else if (pid_name == `SUBLPM) begin  //LPM
        token_data     = {2'b0, lpm_remote_wake, lpm_hird, lpm_link_state};
    end
    else begin
        token_data     = {endp, func_address};
    end
    crc5         = ~calc_crc5({<<{token_data}},11);  // << swap position
    token_crc5 = {<<{crc5}};
  endfunction

  virtual function bit[4:0] calc_crc5 (input bit[10:0] data, input int size);
    int             i;
    bit [4:0]     hold;
    logic[4:0] polynom = 5'b00101;

    hold   = 5'h1f;

    for (i = size-1; i >= 0; i--) begin
      if (data[i] == hold[4]) begin
        hold    = hold << 1;
        hold[0] = 1'b0;
      end
      else begin
        hold    = hold << 1;
        hold[0] = 1'b0;
        hold    = hold ^ polynom;
      end
    end
    calc_crc5 = hold;
  endfunction

  virtual function bit chk_token_crc5();
    bit[4:0] crc5;
    bit[4:0] crc5_bk;

    crc5_bk = token_crc5;
    gen_token_crc5();
    crc5 = token_crc5;
    token_crc5 = crc5_bk;
    
    // return error if different  
    return (crc5 != token_crc5);
  endfunction

  virtual function void gen_data_crc16();
    data_crc16 = calculate_data_crc16();
  endfunction

  virtual function bit[15:0] calculate_data_crc16();
    bit[9*1024 -1:0] pkt_data;     //> 1024B for injecting babble
    bit[9*1024 -1:0] rev_pkt_data;
    bit[4:0] crc5;
    bit[15:0] crc16, res;
    int bitsize, size;
    pkt_data = 0; rev_pkt_data = 0;
    bitsize = 8*this.data.size();
    size    = this.data.size();
    if (bitsize) begin
      for (int i=size-1; i>= 0; i--) begin
        pkt_data = pkt_data << 8;
        pkt_data[7:0] = this.data[i];
        end

      for (int i=0; i<bitsize; i++) rev_pkt_data[bitsize-1-i] = pkt_data[i];

      crc16 = ~calc_crc16(rev_pkt_data, bitsize);
      for (int i=0; i<16; i++) res[15-i] = crc16[i];
      end
    else res = 0;

    //`brt_info(get_name(), $psprintf("size %0d bitsize %0d crc16 %h", size, bitsize, res), UVM_HIGH)
    return res;

  endfunction

  virtual function bit chk_crc16();
      bit[15:0] crc16;
      crc16 = calculate_data_crc16();
      return (crc16 != data_crc16);
  endfunction: chk_crc16

  virtual function [15:0] calc_crc16 ( input [8192-1:0] data, input int size);
    int i;
    bit [15:0] hold;
    logic [15:0] polynom = 16'b1000000000000101;

    hold   = 16'hffff;
    for (i = size-1; i >= 0; i--) begin
      if (data[i] == hold[15]) begin
        hold    = hold << 1;
        hold[0] = 1'b0;
      end
      else begin
        hold    = hold << 1;
        hold[0] = 1'b0;
        hold    = hold ^ polynom;
      end

    end

    calc_crc16 = hold;
  endfunction

  virtual function bit[15:0] compute_crc16 (input[15:0] cur_crc, input logic[15:0] in_data);
    logic [15:0] d16; 
    logic c;
    logic [16:0] x;
    logic [15:0] p = 16'h8005; // polynomial x^16 + x^15 + x^2 + 1

    d16 = in_data;    
    x = cur_crc;      

    repeat (16) begin
      x = x << 1;
      c = x[16] ^ d16[0];
      for (int i=0; i<16; i++) begin
        if (p[i] && i==0) x[i] = c;
        else if (p[i])    x[i] = c ^ x[i];
        end
      d16 = d16 >> 1;
      end
    return x[15:0];
  endfunction

  virtual function pid_type_e get_pid_type(pid_name_e pn);
    case (pid_name)
      OUT,IN,SOF,SETUP:             return TOKEN;
      DATA0,DATA1,DATA2,MDATA:     return DATA;
      ACK,NAK,STALL,NYET:             return HANDSHAKE;
      default:                         return SPECIAL;
    endcase
  endfunction

  function void do_unpack(brt_packer packer);
    byte temp_buf_q[$];
    bit[31:0]  bit_size, byte_size;
    int junk;
    super.do_unpack(packer);
    packer.big_endian = 0;
    packer.use_metadata = 1;
    temp_buf_q.delete(); 
    bit_size         = packer.get_packed_size();
    if (bit_size[2:0]) `brt_fatal(get_name(), "must be byte aligned")
    byte_size = bit_size/8;

    pid_format = packer.unpack_field_int(8);
    pid_name   = pid_name_e'(pid_format[3:0]);
    pid_type   = get_pid_type(pid_name);
    byte_size  = byte_size-1;
    bit_size   = bit_size-8;

    case (pid_name)
      PING,OUT,IN,SETUP,EXT: begin
               func_address    = packer.unpack_field_int(7);
               endp            = packer.unpack_field_int(4);
               token_crc5      = packer.unpack_field_int(5);
               end
      SOF: begin
               frame_num       = packer.unpack_field_int(11);
               token_crc5      = packer.unpack_field_int(5);
               // Need to unpack remaining bits, otherwise it will corrupt the next packet decoding
               bit_size = bit_size - 11 - 5;
               junk = packer.unpack_field_int(bit_size);
               end
      DATA0,DATA1,DATA2,MDATA: begin
               if (is_lpm) begin
                 lpm_link_state  = packer.unpack_field_int(4);
                 lpm_hird        = packer.unpack_field_int(4);
                 lpm_remote_wake = packer.unpack_field_int(1);
                 lpm_reserved    = packer.unpack_field_int(2);
                 token_crc5      = packer.unpack_field_int(5);
               end
               else begin
                 assert(byte_size>=2) else `brt_fatal(get_name(), $sformatf("Not include CRC16. data size is: %d", byte_size))
                 while(byte_size>0) begin 
                   temp_buf_q.push_back(packer.unpack_field_int(8));
                   byte_size--;
                   end
                 data = new[temp_buf_q.size()-2];
                 foreach(data[i]) data[i] = temp_buf_q.pop_front();
                 data_crc16[7:0]  = temp_buf_q.pop_front();
                 data_crc16[15:8] = temp_buf_q.pop_front();
               end
               end
      ACK,NAK,STALL,NYET: begin
               end
      default: `brt_fatal(get_name(), "unsupported/unknown pid name")
    endcase

  endfunction

  function void do_pack(brt_packer packer);
    super.do_pack(packer);
    packer.big_endian = 0;
    packer.use_metadata = 1;
    packer.pack_field_int(pid_format, 8);

    case (pid_name) 
      PING, OUT,IN,SETUP, EXT: begin
               packer.pack_field_int(func_address, 7);
               packer.pack_field_int(endp, 4);
               packer.pack_field_int(token_crc5, 5);
               end
      SOF: begin
               packer.pack_field_int(frame_num, 11);
               packer.pack_field_int(token_crc5, 5);
               end
      DATA0,DATA1,DATA2,MDATA: begin
                 if (is_lpm) begin
                   packer.pack_field_int(lpm_link_state, 4);
                   packer.pack_field_int(lpm_hird, 4);
                   packer.pack_field_int(lpm_remote_wake, 1);
                   packer.pack_field_int(lpm_reserved, 2);
                   packer.pack_field_int(token_crc5, 5);
                 end
                 else begin
                   foreach(data[i]) begin
                     packer.pack_field_int(data[i], 8);
                     end
                   packer.pack_field_int(data_crc16, 16);
                 end
               end

      ACK,NAK,STALL,NYET: begin
               end
      default: `brt_fatal(get_name(), $psprintf ("unsupported/unknown pid name %s", pid_name.name()))
    endcase

  endfunction

endclass : brt_usb_packet

class brt_usb_transfer extends brt_usb_base_sequence_item;

  typedef enum bit[3:0] {
    CONTROL_TRANSFER = 0, BULK_IN_TRANSFER = 1, 
    BULK_OUT_TRANSFER = 2, INTERRUPT_IN_TRANSFER = 3,
    INTERRUPT_OUT_TRANSFER = 4, ISOCHRONOUS_IN_TRANSFER = 5,
    ISOCHRONOUS_OUT_TRANSFER = 6, LPM_TRANSFER = 7, RESERVED = 8
  } transfer_type_e;

  typedef enum bit[1:0] {
    SETUP_STATE = 0, DATA_STATE = 1, 
    STATUS_STATE = 2, RESERVED_STATE = 3
  } control_state_e;

  // Endpoint config
  brt_usb_endpoint_config                                     ep_cfg;

  rand transfer_type_e                                        xfer_type;

  // control transfer
  rand brt_usb_types::setup_data_bmrequesttype_dir_e          setup_data_bmrequesttype_dir;
  rand brt_usb_types::setup_data_bmrequesttype_type_e         setup_data_bmrequesttype_type;
  rand brt_usb_types::setup_data_bmrequesttype_recipient_e    setup_data_bmrequesttype_recipient;
  rand brt_usb_types::setup_data_brequest_e                   brequest;
  // set up data
  rand bit[7:0]                        setup_data_bmrequesttype;
  rand bit[7:0]                        setup_data_brequest;
  rand bit[15:0]                       setup_data_w_value;
  rand bit[15:0]                       setup_data_w_index;
  rand bit[15:0]                       setup_data_w_length;
  
  // Control stage
  control_state_e                      control_xfer_state = RESERVED_STATE;

  // LPM bmAttributes
  rand bit                             lpm_remote_wake;
  rand bit[3:0]                        lpm_hird;
  rand bit[3:0]                        lpm_link_state;

  rand int                             payload_intended_byte_count;

  rand brt_usb_payload                 payload;
  rand bit[6:0]                        device_address;
  rand bit[3:0]                        endpoint_number;
  rand brt_usb_types::ep_dir_e         dir;
  bit                                  aligned_transfer_ends_with_zero_length;
  brt_usb_types::tfer_status_e         tfer_status;
  brt_usb_types::descriptor_e          descriptor;

  bit[3:0]                             bulk_out_epn_q[$];
  bit[3:0]                             bulk_in_epn_q[$];
  bit[3:0]                             intr_out_epn_q[$];
  bit[3:0]                             intr_in_epn_q[$];
  bit[3:0]                             isoc_out_epn_q[$];
  bit[3:0]                             isoc_in_epn_q[$];
  local int max_size = 16384;
  int mps[bit[3:0]];

  // data has been transfered
  int                                  data_pos;  // position of data for next transfer
  bit                                  xfer_done; // Indicate that this transfer has been done

  `brt_object_utils_begin(brt_usb_transfer)
    `brt_field_object      (ep_cfg,                                  UVM_ALL_ON)
    `brt_field_int         (device_address,                          UVM_ALL_ON)
    `brt_field_int         (endpoint_number,                         UVM_ALL_ON)
    `brt_field_int         (aligned_transfer_ends_with_zero_length,  UVM_ALL_ON)
    `brt_field_int         (payload_intended_byte_count,             UVM_ALL_ON|UVM_DEC)
    `brt_field_object      (payload,                                 UVM_ALL_ON)
    `brt_field_int         (setup_data_w_length,                     UVM_ALL_ON)
    `brt_field_int         (setup_data_w_index,                      UVM_ALL_ON)
    `brt_field_int         (setup_data_w_value,                      UVM_ALL_ON)
    `brt_field_int         (setup_data_bmrequesttype,                UVM_ALL_ON)
    `brt_field_int         (setup_data_brequest,                     UVM_ALL_ON)
    `brt_field_int         (lpm_link_state,                          UVM_ALL_ON)
    `brt_field_int         (lpm_hird,                                UVM_ALL_ON)
    `brt_field_int         (lpm_link_state,                          UVM_ALL_ON)

    `brt_field_enum        (brt_usb_transfer::control_state_e,                   control_xfer_state,                 UVM_ALL_ON);
    `brt_field_enum        (brt_usb_types::setup_data_brequest_e,                brequest,                           UVM_ALL_ON);
    `brt_field_enum        (brt_usb_types::setup_data_bmrequesttype_recipient_e, setup_data_bmrequesttype_recipient, UVM_ALL_ON);
    `brt_field_enum        (brt_usb_types::setup_data_bmrequesttype_type_e,      setup_data_bmrequesttype_type,      UVM_ALL_ON);
    `brt_field_enum        (brt_usb_types::setup_data_bmrequesttype_dir_e,       setup_data_bmrequesttype_dir,       UVM_ALL_ON);
    `brt_field_enum        (transfer_type_e,                                     xfer_type,                          UVM_ALL_ON);
    `brt_field_enum        (brt_usb_types::ep_dir_e,                             dir,                                UVM_ALL_ON);
    `brt_field_enum        (brt_usb_types::tfer_status_e,                        tfer_status,                        UVM_ALL_ON);

    `brt_field_queue_int(bulk_out_epn_q,    UVM_ALL_ON);
    `brt_field_queue_int(bulk_in_epn_q,     UVM_ALL_ON);
    `brt_field_queue_int(intr_out_epn_q,    UVM_ALL_ON);
    `brt_field_queue_int(intr_in_epn_q,     UVM_ALL_ON);
    `brt_field_queue_int(isoc_out_epn_q,    UVM_ALL_ON);
    `brt_field_queue_int(isoc_in_epn_q,     UVM_ALL_ON);
    `brt_field_int      (data_pos,          UVM_ALL_ON);
    `brt_field_int      (xfer_done,         UVM_ALL_ON);

  `brt_object_utils_end


  constraint addr_constr {
    this.cfg.component_type == brt_usb_types::HOST   -> device_address == this.cfg.remote_device_cfg[0].device_address;
    this.cfg.component_type == brt_usb_types::DEVICE -> device_address == this.cfg.local_device_cfg[0].device_address;
  }

  constraint lpm_xfer {
      lpm_link_state inside {0,2};
  }

  constraint brequest_constr {
    setup_data_brequest == brequest;
  }

  constraint xfer_constr {
    xfer_type == LPM_TRANSFER     -> endpoint_number == 0;
    xfer_type == CONTROL_TRANSFER -> endpoint_number == 0;
    xfer_type == CONTROL_TRANSFER && setup_data_bmrequesttype_dir == brt_usb_types::DEVICE_TO_HOST -> payload_intended_byte_count > 0;

    xfer_type == ISOCHRONOUS_OUT_TRANSFER -> dir == brt_usb_types::OUT;
    xfer_type == BULK_OUT_TRANSFER        -> dir == brt_usb_types::OUT;
    xfer_type == INTERRUPT_OUT_TRANSFER   -> dir == brt_usb_types::OUT;
    xfer_type == ISOCHRONOUS_IN_TRANSFER  -> dir == brt_usb_types::IN;
    xfer_type == BULK_IN_TRANSFER         -> dir == brt_usb_types::IN;
    xfer_type == INTERRUPT_IN_TRANSFER    -> dir == brt_usb_types::IN;
    xfer_type == CONTROL_TRANSFER && setup_data_bmrequesttype_dir == brt_usb_types::DEVICE_TO_HOST -> dir == brt_usb_types::IN;
    xfer_type == CONTROL_TRANSFER && setup_data_bmrequesttype_dir == brt_usb_types::HOST_TO_DEVICE -> dir == brt_usb_types::OUT;
    }

  constraint payload_constr {
    payload.byte_count  == payload_intended_byte_count;
    if ((dir == brt_usb_types::OUT &&  this.cfg.component_type == brt_usb_types::HOST) ||
        (dir == brt_usb_types::IN  &&  this.cfg.component_type == brt_usb_types::DEVICE)){
        payload.data.size() == payload.byte_count;
    }
  }

  constraint bmrequest_type_constr {
    setup_data_bmrequesttype_dir        == brt_usb_types::HOST_TO_DEVICE  -> setup_data_bmrequesttype[7] == 0;
    setup_data_bmrequesttype_dir        == brt_usb_types::DEVICE_TO_HOST  -> setup_data_bmrequesttype[7] == 1;

    setup_data_bmrequesttype_type       == brt_usb_types::STANDARD        -> setup_data_bmrequesttype[6:5] == 0;
    setup_data_bmrequesttype_type       == brt_usb_types::CLASS           -> setup_data_bmrequesttype[6:5] == 1;
    setup_data_bmrequesttype_type       == brt_usb_types::VENDOR          -> setup_data_bmrequesttype[6:5] == 2;
    setup_data_bmrequesttype_type       == brt_usb_types::RESERVED        -> setup_data_bmrequesttype[6:5] == 3;

    setup_data_bmrequesttype_recipient  == brt_usb_types::BMREQ_DEVICE    -> setup_data_bmrequesttype[4:0] == 0;
    setup_data_bmrequesttype_recipient  == brt_usb_types::BMREQ_INTERFACE -> setup_data_bmrequesttype[4:0] == 1;
    setup_data_bmrequesttype_recipient  == brt_usb_types::BMREQ_ENDPOINT  -> setup_data_bmrequesttype[4:0] == 2;
    setup_data_bmrequesttype_recipient  == brt_usb_types::BMREQ_OTHER     -> setup_data_bmrequesttype[4:0] == 3;
  }

  constraint standard_device_request_constr {
    brequest == brt_usb_types::CLEAR_FEATURE -> {
      setup_data_bmrequesttype inside {8'h00, 8'h01, 8'h02};
      //setup_data_w_value                     == 0;
      }

    brequest == brt_usb_types::GET_CONFIGURATION -> {
      setup_data_bmrequesttype        == 8'b10000000 &&
      setup_data_w_length             == 1 &&
      setup_data_w_value              == 0;
      }

    brequest == brt_usb_types::GET_DESCRIPTOR -> {
      setup_data_bmrequesttype     == 8'b10000000; 
      }

    brequest == brt_usb_types::GET_INTERFACE -> {
      setup_data_bmrequesttype        == 8'b10000001 &&
      setup_data_w_length             == 1 &&
      setup_data_w_value              == 0;
      }

    brequest == brt_usb_types::GET_STATUS -> {
      setup_data_bmrequesttype inside {8'h80, 8'h81, 8'h82} &&
      setup_data_w_length             == 2 &&
      setup_data_w_value              == 0;
      }

    brequest == brt_usb_types::SET_ADDRESS -> {
      setup_data_bmrequesttype        == 0 &&
      setup_data_w_length             == 0 &&
      setup_data_w_index              == 0;
      }

    brequest == brt_usb_types::SET_CONFIGURATION -> {
      setup_data_bmrequesttype        == 0 &&
      setup_data_w_length             == 0 &&
      setup_data_w_index              == 0;
      }

    brequest == brt_usb_types::SET_FEATURE -> {
      setup_data_bmrequesttype inside {8'h00, 8'h01, 8'h02} &&
      setup_data_w_length                     == 0;
      }

    brequest == brt_usb_types::SET_INTERFACE -> {
      setup_data_bmrequesttype             == 8'h01 &&
      setup_data_w_length                  == 0;
      }

    brequest == brt_usb_types::SYNCH_FRAME -> {
      setup_data_bmrequesttype             == 8'h82 &&
      setup_data_w_value                   == 0;
      setup_data_w_length                  == 2;
      }
  }

  constraint endpoint_number_constr {
    solve xfer_type before endpoint_number;
    xfer_type == BULK_OUT_TRANSFER && bulk_out_epn_q.size() > 0  -> endpoint_number inside {bulk_out_epn_q};
    xfer_type == BULK_OUT_TRANSFER && bulk_out_epn_q.size() == 0 -> endpoint_number == 0;
   
    xfer_type == BULK_IN_TRANSFER &&  bulk_in_epn_q.size() > 0   -> endpoint_number inside {bulk_in_epn_q};
    xfer_type == BULK_IN_TRANSFER &&  bulk_in_epn_q.size() == 0  -> endpoint_number == 0;

    xfer_type == INTERRUPT_OUT_TRANSFER && intr_out_epn_q.size() > 0  -> endpoint_number inside {intr_out_epn_q};
    xfer_type == INTERRUPT_OUT_TRANSFER && intr_out_epn_q.size() == 0 -> endpoint_number == 0;
   
    xfer_type == INTERRUPT_IN_TRANSFER &&  intr_in_epn_q.size() > 0   -> endpoint_number inside {intr_in_epn_q};
    xfer_type == INTERRUPT_IN_TRANSFER &&  intr_in_epn_q.size() == 0  -> endpoint_number == 0;

    xfer_type == ISOCHRONOUS_OUT_TRANSFER && isoc_out_epn_q.size() > 0  -> endpoint_number inside {isoc_out_epn_q};
    xfer_type == ISOCHRONOUS_OUT_TRANSFER && isoc_out_epn_q.size() == 0 -> endpoint_number == 0;
   
    xfer_type == ISOCHRONOUS_IN_TRANSFER &&  isoc_in_epn_q.size() > 0   -> endpoint_number inside {isoc_in_epn_q};
    xfer_type == ISOCHRONOUS_IN_TRANSFER &&  isoc_in_epn_q.size() == 0  -> endpoint_number == 0;
  }

  // set endpoint number to the any random matched one in configuration
  function void pre_randomize();
    brt_usb_endpoint_config local_ep_cfg;
    bulk_out_epn_q.delete();
    bulk_in_epn_q.delete();
    intr_out_epn_q.delete();
    intr_in_epn_q.delete();
    isoc_out_epn_q.delete();
    isoc_in_epn_q.delete();


    //$display("HEREEEE %s", this.cfg.sprint());

    if (this.cfg.component_type == brt_usb_types::HOST) 
        foreach(this.cfg.remote_device_cfg[0].endpoint_cfg[i]) begin
            local_ep_cfg = this.cfg.remote_device_cfg[0].endpoint_cfg[i];

            if (local_ep_cfg != null) begin
              $display("TRANSFER EP NUM: %0d (%s)", local_ep_cfg.ep_number, local_ep_cfg.ep_type);
              if (local_ep_cfg.direction == brt_usb_types::OUT && local_ep_cfg.ep_type == brt_usb_types::INTERRUPT) begin
                intr_out_epn_q.push_back(local_ep_cfg.ep_number);
                mps[local_ep_cfg.ep_number] = local_ep_cfg.max_packet_size;
                end

              if (local_ep_cfg.direction == brt_usb_types::IN && local_ep_cfg.ep_type == brt_usb_types::INTERRUPT) begin
                intr_in_epn_q.push_back(local_ep_cfg.ep_number);
                mps[local_ep_cfg.ep_number] = local_ep_cfg.max_packet_size;
                end

              if (local_ep_cfg.direction == brt_usb_types::OUT && local_ep_cfg.ep_type == brt_usb_types::ISOCHRONOUS) begin
                isoc_out_epn_q.push_back(local_ep_cfg.ep_number);
                mps[local_ep_cfg.ep_number] = local_ep_cfg.max_packet_size;
                end

              if (local_ep_cfg.direction == brt_usb_types::IN && local_ep_cfg.ep_type == brt_usb_types::ISOCHRONOUS) begin
                isoc_in_epn_q.push_back(local_ep_cfg.ep_number);
                mps[local_ep_cfg.ep_number] = local_ep_cfg.max_packet_size;
                end

              if (local_ep_cfg.direction == brt_usb_types::IN && local_ep_cfg.ep_type == brt_usb_types::BULK) begin
                bulk_in_epn_q.push_back(local_ep_cfg.ep_number);
                mps[local_ep_cfg.ep_number] = local_ep_cfg.max_packet_size;
                $display("BULK IN EP NUM: %0d", local_ep_cfg.ep_number);
                end

              if (local_ep_cfg.direction == brt_usb_types::OUT && local_ep_cfg.ep_type == brt_usb_types::BULK) begin
                bulk_out_epn_q.push_back(local_ep_cfg.ep_number);
                mps[local_ep_cfg.ep_number] = local_ep_cfg.max_packet_size;
                end
            end
        end
    else if (this.cfg.component_type == brt_usb_types::DEVICE) foreach(this.cfg.local_device_cfg[0].endpoint_cfg[i]) begin
      local_ep_cfg = this.cfg.local_device_cfg[0].endpoint_cfg[i];

      if (local_ep_cfg != null) begin
        if (local_ep_cfg.direction == brt_usb_types::OUT && local_ep_cfg.ep_type == brt_usb_types::INTERRUPT)
          intr_out_epn_q.push_back(local_ep_cfg.ep_number);

        if (local_ep_cfg.direction == brt_usb_types::IN && local_ep_cfg.ep_type == brt_usb_types::INTERRUPT)
          intr_in_epn_q.push_back(local_ep_cfg.ep_number);

        if (local_ep_cfg.direction == brt_usb_types::OUT && local_ep_cfg.ep_type == brt_usb_types::ISOCHRONOUS)
          isoc_out_epn_q.push_back(local_ep_cfg.ep_number);

        if (local_ep_cfg.direction == brt_usb_types::IN && local_ep_cfg.ep_type == brt_usb_types::ISOCHRONOUS)
          isoc_in_epn_q.push_back(local_ep_cfg.ep_number);

        if (local_ep_cfg.direction == brt_usb_types::IN && local_ep_cfg.ep_type == brt_usb_types::BULK)
          bulk_in_epn_q.push_back(local_ep_cfg.ep_number);

        if (local_ep_cfg.direction == brt_usb_types::OUT && local_ep_cfg.ep_type == brt_usb_types::BULK) 
          bulk_out_epn_q.push_back(local_ep_cfg.ep_number);
        end
      end

  endfunction: pre_randomize

  function new(string name="brt_usb_transfer");
    super.new(name);
    this.payload         = new();
    this.tfer_status     = brt_usb_types::INITIAL;
    this.descriptor     = brt_usb_types::UNKNOWN_DESC;
    for (bit[4:0] epno=0; epno <= 15; epno++) mps[epno[3:0]] = 16384;
  endfunction

  virtual function void fix_anchors(int dev_id, int ep_id, int tr_id);
    `brt_fatal(get_name, "unsupported function")
  endfunction

  virtual function void check_descriptor();
    if (this.payload.data.size() >= 2) begin
      if (!$cast(this.descriptor, this.payload.data[1])) begin
        this.descriptor = brt_usb_types::UNKNOWN_DESC;
        end
      end
  endfunction

  virtual function string sprint_trace();
    string s;
    string sub;
    string sub2;
    s     = "";
    sub     = "...";
    sub2 = "...";
    if (xfer_type == brt_usb_transfer::CONTROL_TRANSFER) begin
      sub     = brequest.name();
      if (brequest == brt_usb_types::GET_DESCRIPTOR) begin
        check_descriptor();
        sub2 = descriptor.name();
        end
      end
    //s = $psprintf("Time %10t: %27s - %20s [%3s] Dev address 0x%2h: Ep Number %2d: Payload Size %6d: Status [%s]", $time, xfer_type.name(), sub, dir.name(), device_address, endpoint_number, payload.data.size(), this.status.name());
    s = $psprintf("Time %10t: %27s - %20s %20s [%3s] Dev address 0x%2h: Ep Number %2d: Payload Size %6d: Status [%s]", $time, xfer_type.name(), sub, sub2, dir.name(), device_address, endpoint_number, payload.data.size(), this.tfer_status.name());
    return s;
  endfunction

  virtual function bit[6:0] get_device_address_val();
    return this.device_address;
  endfunction

  virtual function bit[15:0] get_setup_data_w_index_val();
    return this.setup_data_w_index;
  endfunction

  virtual function bit[15:0] get_setup_data_w_length_val();
    return this.setup_data_w_length;
  endfunction

  virtual function bit[15:0] get_setup_data_w_value_val();
    return this.setup_data_w_value;
  endfunction

  virtual function brt_usb_types::setup_data_brequest_e get_setup_data_brequest_val();
    return this.brequest;
  endfunction

  virtual function transfer_type_e get_xfer_type_val();
    return this.xfer_type;
  endfunction

    virtual function void find_ep_cfg (brt_usb_config agt_cfg = this.cfg, int pos=0);
        brt_usb_types::ep_dir_e     dir;
        bit                         is_exist;

        if (xfer_type%2 == 1) begin // IN
            dir = brt_usb_types::IN;
        end
        else begin
            dir = brt_usb_types::OUT;
        end

        if (agt_cfg.component_type == brt_usb_types::HOST) begin
            foreach (agt_cfg.remote_device_cfg[pos].endpoint_cfg[i]) begin
                
                if ( agt_cfg.remote_device_cfg[pos].endpoint_cfg[i].ep_number == endpoint_number  &&
                    (agt_cfg.remote_device_cfg[pos].endpoint_cfg[i].direction == dir || endpoint_number ==0)
                    ) begin
                    ep_cfg = agt_cfg.remote_device_cfg[pos].endpoint_cfg[i];
                    is_exist = 1;
                    break;
                end
            end  
        end
        else begin
            foreach (agt_cfg.local_device_cfg[pos].endpoint_cfg[i]) begin
                
                if ( agt_cfg.local_device_cfg[pos].endpoint_cfg[i].ep_number == endpoint_number  &&
                    (agt_cfg.local_device_cfg[pos].endpoint_cfg[i].direction == dir || endpoint_number ==0)
                    ) begin
                    ep_cfg = agt_cfg.local_device_cfg[pos].endpoint_cfg[i];
                    is_exist = 1;
                    break;
                end
            end  
        end

        if (!is_exist) begin
            `uvm_fatal (get_name(), "Can't find endpoint config")
        end
    endfunction:find_ep_cfg

    virtual function void chk_xfer_type ();
        case (xfer_type)
            CONTROL_TRANSFER: begin 
                if (ep_cfg.ep_type != brt_usb_types::CONTROL )
                    `brt_fatal(get_name(), $psprintf ("Trasfer type is %s, but endpoint type (ep %d) is %s",xfer_type.name(),ep_cfg.ep_number,ep_cfg.ep_type.name())) 
            end
            BULK_OUT_TRANSFER: begin 
                if (ep_cfg.ep_type   != brt_usb_types::BULK ||
                    ep_cfg.direction != brt_usb_types::OUT )
                    `brt_fatal(get_name(), $psprintf ("Trasfer type is %s, but endpoint type (ep %d) is %s %s",
                                                       xfer_type.name(),ep_cfg.ep_number, ep_cfg.ep_type.name(), ep_cfg.direction.name())) 
            end
            BULK_IN_TRANSFER: begin 
                if (ep_cfg.ep_type   != brt_usb_types::BULK ||
                    ep_cfg.direction != brt_usb_types::IN )
                    `brt_fatal(get_name(), $psprintf ("Trasfer type is %s, but endpoint type (ep %d) is %s %s",
                                                       xfer_type.name(),ep_cfg.ep_number, ep_cfg.ep_type.name(), ep_cfg.direction.name())) 
            end
            INTERRUPT_OUT_TRANSFER: begin 
                if (ep_cfg.ep_type   != brt_usb_types::INTERRUPT ||
                    ep_cfg.direction != brt_usb_types::OUT )
                    `brt_fatal(get_name(), $psprintf ("Trasfer type is %s, but endpoint type (ep %d) is %s %s",
                                                       xfer_type.name(),ep_cfg.ep_number, ep_cfg.ep_type.name(), ep_cfg.direction.name())) 
            end
            INTERRUPT_IN_TRANSFER: begin 
                if (ep_cfg.ep_type   != brt_usb_types::INTERRUPT ||
                    ep_cfg.direction != brt_usb_types::IN )
                    `brt_fatal(get_name(), $psprintf ("Trasfer type is %s, but endpoint type (ep %d) is %s %s",
                                                       xfer_type.name(),ep_cfg.ep_number, ep_cfg.ep_type.name(), ep_cfg.direction.name())) 
            end
            ISOCHRONOUS_OUT_TRANSFER: begin 
                if (ep_cfg.ep_type   != brt_usb_types::ISOCHRONOUS ||
                    ep_cfg.direction != brt_usb_types::OUT )
                    `brt_fatal(get_name(), $psprintf ("Trasfer type is %s, but endpoint type (ep %d) is %s %s",
                                                       xfer_type.name(),ep_cfg.ep_number, ep_cfg.ep_type.name(), ep_cfg.direction.name())) 
            end
            ISOCHRONOUS_IN_TRANSFER: begin 
                if (ep_cfg.ep_type   != brt_usb_types::ISOCHRONOUS ||
                    ep_cfg.direction != brt_usb_types::IN )
                    `brt_fatal(get_name(), $psprintf ("Trasfer type is %s, but endpoint type (ep %d) is %s %s",
                                                       xfer_type.name(),ep_cfg.ep_number, ep_cfg.ep_type.name(), ep_cfg.direction.name())) 
            end
            default: begin
                    `brt_fatal(get_name(), $psprintf ("Trasfer type is not defined, but endpoint type (ep %d) is %s %s",
                                                       ep_cfg.ep_number, ep_cfg.ep_type.name(), ep_cfg.direction.name())) 
            end
        endcase
    endfunction:chk_xfer_type
endclass : brt_usb_transfer

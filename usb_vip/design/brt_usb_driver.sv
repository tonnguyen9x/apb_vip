class brt_usb_driver extends brt_driver #(brt_usb_data);

  brt_usb_status                shared_status;
  brt_usb_config                cfg;

  brt_usb_protocol              prot;        // not use
  brt_usb_link                  link;    
  brt_usb_physical              phys;        // not use
  virtual brt_usb_if            ser_vif;
  virtual brt_usb_20_serial_if  vif20;

  bit                           is_host;
  bit                           vip_enable = 1;

  bit                           is_tx;

  brt_blocking_put_port #(brt_usb_data)     out_brt_usb_data_port;  // to data layer

  `brt_component_utils_begin(brt_usb_driver)
  `brt_component_utils_end

  function new(string name, brt_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase (brt_phase phase);
    bit status;
    super.build_phase(phase);
    `brt_info("build_phase", $psprintf("entered %s",get_full_name()), UVM_HIGH)
    status = uvm_config_db#(brt_usb_config)::get(this, "", "cfg", cfg);
    if (!status) 
      `brt_fatal(get_full_name(), "no cfg")

    status = uvm_config_db#(virtual brt_usb_if)::get(null, get_full_name(), "brt_usb_20_if", ser_vif);
    if (!status)
      `brt_fatal(get_full_name(), "no interface")
    if (ser_vif == null) 
      `brt_fatal(get_full_name(), "Configuration Error : Interface is not connected.");
    vif20 = ser_vif.brt_usb_20_serial_if;

    status = uvm_config_db#(bit)::get(null, get_full_name(), "vip_enable", vip_enable);
    //if (!status)
    //  `brt_fatal(get_full_name(), "not set vip_enable variable yet")
    // out port
    //if (cfg.component_type == brt_usb_types::DEVICE) begin
        out_brt_usb_data_port = new ("out_brt_usb_data_port", this);
    //end
  endfunction

  virtual task run_phase (brt_phase phase);

    // Disable driver
    if (!vip_enable) return;

    //uvm_default_packer.use_metadata = 1;
    //uvm_default_packer.big_endian = 0;
    //Check host or device
    is_host = this.cfg.component_type == brt_usb_types::HOST;
    `brt_info(get_name(), $psprintf("Component Type: %s", is_host ? "Host":"Device" ), UVM_LOW)
    
    fork
      forever begin
        @(posedge vif20.config_update);
        vif20.ls_fs_eop_se0_2_j_margin = cfg.ls_fs_eop_se0_2_j_margin;
        if (cfg.ls_fs_eop_se0_2_j_margin > 0.0025)
          `brt_error(get_full_name(), "Wrong configuration : Clock margin in case of EoP - SE0 to J is set to bigger than maximum value : 0.25%")
      end
      begin
        if (is_host) begin
          fork
            case (cfg.usb_20_signal_interface)
              brt_usb_config::USB_20_SERIAL_IF    : sm_run_host_usb20_serial();
              brt_usb_config::UTMI_IF                : run_host_utmi();
              default:
                `brt_fatal(get_full_name(), "unsupported interface")
            endcase
            get_in_pkt();
            update_linestate_status();
            monitor_link_status();
          join
        end
        else begin
          fork
            case (cfg.usb_20_signal_interface)
              brt_usb_config::USB_20_SERIAL_IF    : sm_run_dev_brt_usb20_serial();
              brt_usb_config::UTMI_IF                : run_dev_utmi();
              default:
                `brt_fatal(get_full_name(), "unsupported interface")
            endcase
            get_in_pkt();
            update_linestate_status();
            monitor_link_status();
          join
        end
      end
    join
  endtask

  virtual task get_in_pkt ();
    bit         received_pkt;
    brt_usb_data    udata;

    do begin
        received_pkt = 0;
        `FORK_GUARD_BEGIN
        fork
            begin
                wait (!is_tx);  // Not  transmit
                @(vif20.rx_data_e);
                udata = brt_usb_data::type_id::create("udata");
                receive(udata);
                received_pkt = 1; // Done
            end
            begin
                @(posedge is_tx);
            end
        join_any
        disable fork;
        `FORK_GUARD_END

        if (received_pkt) begin
            `brt_info(get_name(),"driver gets a packet and put to upper layer", UVM_LOW)
            out_brt_usb_data_port.put (udata);
        end
    end while (1);
  endtask: get_in_pkt  

  virtual function bit is_idle();
    return (vif20.dp === 1'b0 && vif20.dm === 1'b0);
  endfunction

  virtual function bit is_j();
    if (vif20.speed == brt_usb_types::LS)
        return (vif20.dp === 1'b0 && vif20.dm === 1'b1);
    else
        return (vif20.dp === 1'b1 && vif20.dm === 1'b0);
  endfunction

  virtual function bit is_valid_data();
    return (vif20.dp != vif20.dm && vif20.dp !== 1'bz && vif20.dp !== 1'bx);
  endfunction

  virtual function bit get_nrzi_rxdata();
    if (vif20.dp==0 && vif20.dm==1) 
      get_nrzi_rxdata = 0;
    else if (vif20.dp==1 && vif20.dm==0) 
      get_nrzi_rxdata = 1;
    else `brt_fatal (get_name(), "Invalid data value of DP/DM signal")
    // Reverse for LS
    if (vif20.speed == brt_usb_types::LS)
      get_nrzi_rxdata = !get_nrzi_rxdata;
  endfunction

  virtual function void drive_0();     drive_k(); endfunction
  virtual function void drive_1();     drive_j(); endfunction
  virtual function void drive_se0();   vif20.dp_pu=0;vif20.se0_en=1'b1; vif20.tx_en=0;vif20.tx_dp=1'b0; vif20.tx_dm=1'b0; endfunction
  virtual function void drive_se1();   vif20.dp_pu=0;vif20.se0_en=1'b1; vif20.tx_en=0;vif20.tx_dp=1'b1; vif20.tx_dm=1'b1; endfunction
  virtual function void drive_reset(); vif20.dp_pu=0;vif20.se0_en=1'b1; vif20.tx_en=0;vif20.tx_dp=1'b0; vif20.tx_dm=1'b0; endfunction
  virtual function void drive_j();
    vif20.dp_pu=0;vif20.se0_en=1'b0; vif20.tx_en=1;
    if (vif20.speed == brt_usb_types::LS) begin    
        vif20.tx_dp=1'b0;
        vif20.tx_dm=1'b1;
    end
    else begin
        vif20.tx_dp=1'b1;
        vif20.tx_dm=1'b0;
    end
  endfunction: drive_j
  virtual function void drive_k();
    vif20.dp_pu=0;vif20.se0_en=1'b0; vif20.tx_en=1;
    if (vif20.speed == brt_usb_types::LS) begin    
        vif20.tx_dp=1'b1;
        vif20.tx_dm=1'b0;
    end
    else begin
        vif20.tx_dp=1'b0;
        vif20.tx_dm=1'b1;
    end
  endfunction: drive_k
  virtual function void drive_idle_ls_fs();     
    if (is_host) begin
      vif20.dp_pu=1;
      vif20.dm_pu=1;
      vif20.se0_en=1'b0;
      vif20.tx_en=0;
      vif20.tx_dp=1'b0;
      vif20.tx_dm=1'b0;
    end
    else begin
      drive_j();
      vif20.dp_pu=1;
      vif20.dm_pu=1;
      vif20.se0_en=1'b0;
      vif20.tx_en=0;
      //vif20.tx_dp=1'b1;
      //vif20.tx_dm=1'b0;
    end
  endfunction

  virtual function void drive_idle_hs();     
    if (is_host) begin
      vif20.dp_pu=1;
      vif20.dm_pu=1;
      vif20.se0_en=1'b0;
      vif20.tx_en=0;
      vif20.tx_dp=1'b0;
      vif20.tx_dm=1'b0;
    end
    else begin
      vif20.dp_pu=1;
      vif20.dm_pu=1;
      vif20.se0_en=1'b0;
      vif20.tx_en=0;
      vif20.tx_dp=1'b0;
      vif20.tx_dm=1'b0;
    end
  endfunction

  virtual function void drive_idle();     
    if (vif20.speed == brt_usb_types::HS) begin  // HS
        drive_idle_hs();
    end
    else begin
        drive_idle_ls_fs();
    end
  endfunction

  virtual function void drive_eop(bit prior_nrz_bit);
    if (prior_nrz_bit) 
      drive_k(); 
    else 
      drive_j();
  endfunction

  virtual function void drive_vbus();
    vif20.vbus = 1'b1;
  endfunction

  virtual task wait_se0();    
    do begin
        wait (vif20.dp===1'b0 && vif20.dm===1'b0);
        #1ps;
    end while (!(vif20.dp===1'b0 && vif20.dm===1'b0));
  endtask

  virtual task wait_vbus();
    wait (vif20.vbus === 1'b1);
  endtask

  virtual task wait_activity();
    @(!vif20.dp or !vif20.dm); 
  endtask

  virtual function brt_usb_types::linestate_value_e get_linestate();
    case({vif20.dp, vif20.dm})
      2'b00: return brt_usb_types::LINESTATE_SE0;
      2'b01: return vif20.speed == brt_usb_types::LS?brt_usb_types::LINESTATE_J:brt_usb_types::LINESTATE_K;
      2'b10: return vif20.speed == brt_usb_types::LS?brt_usb_types::LINESTATE_K:brt_usb_types::LINESTATE_J;
      2'b11: return brt_usb_types::LINESTATE_SE1;
      default return brt_usb_types::LINESTATE_UNKNOWN;
    endcase
  endfunction

  virtual task update_linestate_status();
    forever begin
      #5ns shared_status.physical_usb_20_linestate = get_linestate();
      `brt_info(get_name(), $psprintf("Current linestate %s", shared_status.physical_usb_20_linestate.name()), UVM_DEBUG);
      @(!vif20.dp or !vif20.dm);
      end
  endtask

  virtual task monitor_link_status();
    brt_usb_types::link20sm_state_e prev_link_20_state;
    forever begin
      prev_link_20_state = shared_status.link_usb_20_state;
      `brt_info(get_name(), $psprintf("current brt_usb20 link state %s", prev_link_20_state.name()), UVM_HIGH);
      wait (shared_status.link_usb_20_state != prev_link_20_state);
      end
  endtask

  // USB2.0 Sec 7.1.7.5
  virtual task hs_detection_handshake(output brt_usb_types::speed_e hndsk_speed, input brt_usb_types::speed_e max_speed=brt_usb_types::HS, input bit pwon = 1, input bit sus2rst = 1'b0);
    bit reset_timeout;
    bit dppu_det;
    bit is_high_speed;

    reset_timeout = 0; 

    `FORK_GUARD_BEGIN
    fork : BLK_RESET_SIGNALLING
      begin 
        //#cfg.tdrst; reset_timeout=1; // 3ms 
        #cfg.trst_total; reset_timeout=1; // 20ms 
      end
      begin
        drive_reset();
        if (max_speed == brt_usb_types::HS && vif20.speed != brt_usb_types::LS ) begin
           detect_chirp_k(is_high_speed, (pwon || sus2rst));
        end
        else begin
            is_high_speed = 0;
        end

        if (is_high_speed) wait_se0(); 

        #cfg.twtdch;  // 100us

        if (is_high_speed) begin
            drive_alternating_chirp_kj();
        end
        else begin
            -> vif20.debug1;
            //#1ms;
            #cfg.tfs_rst;  // 2.5us
            -> vif20.debug2;
        end
        
        // Host idle
        if (is_high_speed) begin
            drive_idle_hs();
            hndsk_speed = brt_usb_types::HS;
        end
        else begin
            #cfg.tdrst;  // Reset
            drive_idle_ls_fs();
            #1ps;
            if (vif20.dp == 1'b1 && vif20.dm == 1'b0) begin
                vif20.speed = brt_usb_types::FS;
                hndsk_speed = brt_usb_types::FS;
            end
            else if (vif20.dp == 1'b0 && vif20.dm == 1'b1) begin
                vif20.speed = brt_usb_types::LS;
                hndsk_speed = brt_usb_types::LS;
            end
            else begin
                `brt_fatal (get_name(), "Not expected value in serial signal")
            end
        end
      end
    join_any
    disable fork;
    `FORK_GUARD_END
    assert(!reset_timeout) else `brt_fatal(get_full_name(), "reset timeout")
    -> vif20.debug3;
    `brt_info(get_name(), $sformatf("Done BLK_RESET"), UVM_LOW);

    //if (is_high_speed)
    //  #14us;
  endtask

  virtual task drive_alternating_chirp_kj();
    bit stop_chirping, chirp_done;
    stop_chirping=0; chirp_done=0;
    `FORK_GUARD_BEGIN
      fork
        forever begin
          chirp_done=0;
          drive_k; #cfg.tdchbit;
          drive_j; #cfg.tdchbit;
          chirp_done=1;
          wait(!stop_chirping);
          end
        begin #cfg.twtfs; stop_chirping = 1; end
        join_any
      while(!chirp_done) begin wait(chirp_done); #0; end
      disable fork;
    `FORK_GUARD_END
    `brt_info(get_name(), $sformatf("Done alternating chirp KJ"), UVM_LOW);
  endtask

  virtual task chk_k();
    if (vif20.speed == brt_usb_types::LS) begin
        if (!(vif20.dp===1'b1 && vif20.dm===1'b0)) begin
            `brt_fatal ("CHK_K", "LS, Line state is not K")
        end
    end
    else begin
        if (!(vif20.dp===1'b0 && vif20.dm===1'b1)) begin
            `brt_fatal ("CHK_K", "HS/FS Line state is not K")
        end
    end
  endtask

  virtual task chk_j();
    if (vif20.speed == brt_usb_types::LS) begin
        if (!(vif20.dp===1'b0 && vif20.dm===1'b1)) begin
            `brt_fatal ("CHK_J", "LS Line state is not J")
        end
    end
    else begin
        if (!(vif20.dp===1'b1 && vif20.dm===1'b0)) begin
            `brt_fatal ("CHK_J", "HS/FS Line state is not J")
        end
    end
  endtask

  virtual task wait_k();
    if (vif20.speed == brt_usb_types::LS)
        do begin
            wait (vif20.dp===1'b1 && vif20.dm===1'b0);
            #1ps;
        end while (!(vif20.dp===1'b1 && vif20.dm===1'b0));
    else
        do begin
            wait (vif20.dp===1'b0 && vif20.dm===1'b1);
            #1ps;
        end while (!(vif20.dp===1'b0 && vif20.dm===1'b1));
  endtask

  virtual task wait_j();
    if (vif20.speed == brt_usb_types::LS)
        do begin
            wait (vif20.dp===1'b0 && vif20.dm===1'b1);
            #1ps;
        end while (!(vif20.dp===1'b0 && vif20.dm===1'b1));
    else
        do begin
            wait (vif20.dp===1'b1 && vif20.dm===1'b0);
            #1ps;
        end while (!(vif20.dp===1'b1 && vif20.dm===1'b0));
  endtask

  virtual task detect_chirp_k(output bit is_high_speed, input bit pwon = 1);
    bit     detected;
    bit     fail;
    time    chirpk_t;
    time    start_t;

    detected  = 0;
    is_high_speed   = 0;
    chirpk_t  = $time;
    start_t   = $time;

    while(!detected) begin
      `FORK_GUARD_BEGIN
        fork
            begin
                wait_k();
                if (!pwon) chirpk_t = $time;
            end
            begin
                #cfg.tdrst;
                #cfg.trst_detect;
            end
        join_any
        
        if (chirpk_t != start_t && (chirpk_t - start_t < cfg.tdrst)) `brt_fatal (get_name(), "Device sends chirp K sooner than expected")
        if (vif20.dp != 0 || vif20.dm != 1) fail=1;  // Not K
        disable fork;
      `FORK_GUARD_END

      if (fail) begin
          break;  // not K
      end
      else begin
        `FORK_GUARD_BEGIN
          fork
            begin #cfg.tuch detected=1; end
            @(vif20.dp);
            @(vif20.dm);
            join_any
          disable fork;
        `FORK_GUARD_END
        if (!detected) `brt_fatal(get_name(), $psprintf("No chirp K, fail %h", fail))
        else is_high_speed = 1;
      end
    end  // while (!detected)
    if (detected) begin
      `brt_info(get_name(), $sformatf("Detected chirp K"), UVM_LOW);
    end
   
    // TODO: check with speed capability
    if (is_high_speed) -> vif20.debug0;
  endtask

  virtual task transmit_sync_pattern(int num_kj = -1);
    int     hs_num_kj;
    int     ls_fs_num_kj;
    // HS sync pattern is 15KJ pairs followed by 2K
    // FS/LS sync pattern is 3KJ pairs followed by 2K
    hs_num_kj = 15;
    ls_fs_num_kj = 3;
    if (vif20.speed == brt_usb_types::HS) begin
      @(posedge vif20.tx_clk);
      if (num_kj >= 0) begin
          hs_num_kj = num_kj;
          `brt_info (get_name(), $psprintf ("Change number of KJ to %d",num_kj), UVM_HIGH )
      end
      repeat(hs_num_kj) begin
        drive_k(); @(posedge vif20.tx_clk);
        drive_j(); @(posedge vif20.tx_clk);
        end
      drive_k(); @(posedge vif20.tx_clk);
      drive_k(); @(posedge vif20.tx_clk);
      end
    else begin
      @(posedge vif20.tx_clk);
      if (num_kj > 0) begin
          ls_fs_num_kj = num_kj;
          `brt_info (get_name(), $psprintf ("Change number of KJ to %d",num_kj), UVM_HIGH )
      end
      repeat(ls_fs_num_kj) begin
        drive_k(); @(posedge vif20.tx_clk);
        drive_j(); @(posedge vif20.tx_clk);
        end
      drive_k(); @(posedge vif20.tx_clk);
      drive_k(); @(posedge vif20.tx_clk);
      end
  endtask

  //virtual task send_eop(bit last_encoded, int hs_num_eop = 8, int fs_num_eop = 2);
  //  if (vif20.speed == brt_usb_types::HS) begin
  //    repeat(hs_num_eop) begin  // HS
  //      drive_eop(last_encoded);
  //      @(posedge vif20.tx_clk);
  //      end
  //    end
  //  else begin  // LS/FS
  //    if (fs_num_eop == 2) begin
  //      repeat (fs_num_eop) begin
  //        drive_se0();
  //        @(posedge vif20.tx_clk);
  //      end
  //    end
  //    else begin
  //      // Make wrong eop
  //      repeat (fs_num_eop) begin
  //          @(posedge vif20.tx_clk);
  //      end
  //      repeat (2) begin
  //        drive_se0();
  //        @(posedge vif20.tx_clk);
  //      end
  //    end
  //  end
  //endtask

  virtual task send_eop(bit last_encoded, int hs_num_eop = 8, int fs_num_eop = 2);
    if (vif20.speed == brt_usb_types::HS) begin
      if (hs_num_eop != 8 && hs_num_eop != 40) begin
        for (int i = 0; i < hs_num_eop; i ++ ) begin  // HS
            if (i%2 ^ last_encoded) drive_k ();
            else     drive_j ();
            @(posedge vif20.tx_clk);
        end
        repeat(8) begin  // HS
          drive_eop(last_encoded);
          @(posedge vif20.tx_clk);
        end
      end
      else begin
        repeat(hs_num_eop) begin  // HS
          drive_eop(last_encoded);
          @(posedge vif20.tx_clk);
        end
      end
    end
    else begin  // LS/FS
      if (fs_num_eop == 2) begin
        repeat (fs_num_eop) begin
          drive_se0();
          @(posedge vif20.tx_clk);
        end
      end
      else begin
        // Make wrong eop
        for (int i = 0; i < fs_num_eop; i ++ ) begin  // FS
            if (i%2 ^ last_encoded) drive_k ();
            else     drive_j ();
            @(posedge vif20.tx_clk);
        end
        repeat (2) begin
          drive_se0();
          @(posedge vif20.tx_clk);
        end
      end
    end
  endtask

  virtual task transmit(brt_usb_data udata);
    bit tx_encoded_data;
    -> vif20.gen_tx_clk_e;
    transmit_sync_pattern(udata.num_kj);
    while(udata.nrzi_data_q.size()) begin
      tx_encoded_data = udata.nrzi_data_q.pop_front();
      //$display("DRIVE: %b, @%0t", tx_encoded_data, $time);
      case (tx_encoded_data)
        1'b0: drive_0();
        1'b1: drive_1();
      endcase
      @(posedge vif20.tx_clk);
      end

    // Number of eop
    if (udata.eop_length >= 0) begin
        send_eop(tx_encoded_data, udata.eop_length, udata.eop_length);
    end
    else if (udata.is_sof) begin
        send_eop(tx_encoded_data, 40);  // 5 NRZI
    end 
    else begin
        send_eop(tx_encoded_data);
    end
    drive_idle();
    @(posedge vif20.tx_clk);
    -> vif20.kill_tx_clk_e;
  endtask

  virtual task receive(brt_usb_data udata);
    bit data_q[$];
    bit detect_idle;
    bit eop, prev_eop;
    realtime idle_start_time, j_start_time, glitch_start_time, eop_se0_interval_min, eop_se0_interval_max, eop_se0_interval;
    bit hs_eop_chk = 0;

    detect_idle = 0;

    fork
      do begin
        @(negedge vif20.rx_clk_fdpd);
        if (this.is_valid_data()) 
          data_q.push_back(get_nrzi_rxdata());
        else if (this.is_idle())
          detect_idle=1;
        else `brt_fatal(get_full_name(), "invalid data")
      end while (!detect_idle);
      begin
        do begin
          wait (vif20.dp == 0 && vif20.dm == 0);
          idle_start_time = $time;
          #0;
        end while (!this.is_idle);
      end
    join

    // Check EOP
    `FORK_GUARD_BEGIN
      fork
        begin
          @(negedge vif20.rx_clk_fdpd);
          if (!this.is_idle()) begin
            `brt_fatal(get_name(), "EOP pattern SE0 is not correct")
          end
          @(negedge vif20.rx_clk_fdpd);
          if (vif20.speed == brt_usb_types::HS) begin
            if (!this.is_idle()) begin
              `brt_fatal(get_name(), "EOP pattern SE0 is not correct")
            end
          end
          else begin
            if (!this.is_j()) begin
              `brt_fatal(get_name(), "EOP pattern idle is not correct")
            end
          end
          hs_eop_chk = 1;
        end
        begin
          if ((vif20.speed == brt_usb_types::FS) || (vif20.speed == brt_usb_types::LS)) begin
            do begin
              @(vif20.dp or vif20.dm);
              if (!this.is_j()) begin
                glitch_start_time = $time;
                fork
                  @(vif20.dp or vif20.dm);
                  #1ns;
                join_any
              end
              if (this.is_j()) j_start_time = $time;
            end
            while (!this.is_j());
            if (!this.is_j()) `brt_fatal(get_name(), "EOP pattern is not correct, should be 2 SE0 -> J")
            if (vif20.speed == brt_usb_types::FS) begin
              eop_se0_interval_min = 160ns;
              eop_se0_interval_max = 175ns;
            end else
            if (vif20.speed == brt_usb_types::LS) begin
              eop_se0_interval_min = 1.25us;
              eop_se0_interval_max = 1.50us;
            end
            eop_se0_interval = j_start_time - idle_start_time;
            if (eop_se0_interval < eop_se0_interval_min) `brt_error(get_name(), $sformatf("T_se0 in EOP pattern is not correct, should be longer than %t : %t"  , eop_se0_interval , eop_se0_interval_min))
            if (eop_se0_interval > eop_se0_interval_max) `brt_error(get_name(), $sformatf("T_se0 in EOP pattern is not correct, should be shorter than %t : %t" , eop_se0_interval , eop_se0_interval_max))
          end else begin
            @(posedge hs_eop_chk);
          end
        end
      join_any
    disable fork;
    `FORK_GUARD_END

    // strip off EOP
    if (vif20.speed == brt_usb_types::HS) begin
      prev_eop = data_q.pop_back();
      repeat (7) begin
        if (prev_eop != data_q.pop_back())
          `brt_fatal(get_full_name(), "invalid eop")
      end
    end
    
    while(data_q.size())
      udata.nrzi_data_q.push_back(data_q.pop_front());
  endtask

  virtual function void set_link_up(brt_usb_types::speed_e speed);
    string msg="";
    //$cast(vif20.speed,speed);
    vif20.speed = speed;
    vif20.speed_handshake_done=1;

    `brt_info(get_name(), $psprintf("Set Link as %s", speed), UVM_LOW);

    if (is_host) begin
      if (speed == brt_usb_types::HS) begin
        cfg.remote_device_cfg[0].connected_bus_speed         = brt_usb_types::HS;
        cfg.speed                                            = brt_usb_types::HS;
      end
      else if (speed == brt_usb_types::FS) begin
        cfg.remote_device_cfg[0].connected_bus_speed         = brt_usb_types::FS;
        cfg.speed                                            = brt_usb_types::FS;
      end
      else begin
        cfg.remote_device_cfg[0].connected_bus_speed         = brt_usb_types::LS;
        cfg.speed                                            = brt_usb_types::LS;
      end
    end
    else begin
      if (speed == brt_usb_types::HS) begin
        cfg.local_device_cfg[0].connected_bus_speed          = brt_usb_types::HS;
        cfg.speed                                            = brt_usb_types::HS;
      end
      else if (speed == brt_usb_types::FS) begin
        cfg.local_device_cfg[0].connected_bus_speed          = brt_usb_types::FS;
        cfg.speed                                            = brt_usb_types::FS;
      end
      else begin
        cfg.local_device_cfg[0].connected_bus_speed          = brt_usb_types::LS;
        cfg.speed                                            = brt_usb_types::LS;
      end
    end
  endfunction

    virtual task sm_run_host_usb20_serial();
        bit             no_trns;
        brt_usb_data    req_item;
        brt_usb_data    rsp_item;
        brt_usb_types::speed_e sel_speed; // 0: LS, 1: FS, 2: HS
        bit             rcv_pkt;
        bit             pwon;
        bit             sus2rst;    // Resume to reset
        bit             is_suspend;    

        `brt_info("Trace", $sformatf("%m"), UVM_LOW);
        //uvm_default_packer.use_metadata = 1;
        enter_link_state(brt_usb_types::DISCONNECTED);

        // run checking link command state
        fork 
            forever begin
                `FORK_GUARD_BEGIN
                    fork
                    change_link_state();
                    @shared_status.link_usb_20_state;
                    join_any
                    disable fork;
                `FORK_GUARD_END
            end
        join_none
        // turn vbus on
        #100ns;
        wait (this.cfg.run);
        drive_vbus();
        forever begin
            `FORK_GUARD_BEGIN
            fork
                case (shared_status.link_usb_20_state)
                    // DISCONNECTED
                    brt_usb_types::DISCONNECTED: begin
                        // detect connected of device
                        forever begin
                            `brt_info ("host_drv_sm","host is disconnected.......",UVM_LOW);
                            no_trns = 1;
                            drive_idle_ls_fs();  // Host idle

                            wait ((vif20.dp === 0 && vif20.dm === 1) || (vif20.dp === 1 && vif20.dm === 0));
                            if (vif20.dp === 0 && vif20.dm === 1) begin
                                vif20.speed = brt_usb_types::LS;
                            end
                            else begin
                                vif20.speed = brt_usb_types::FS;
                            end

                            // Check no transition
                            `FORK_GUARD_BEGIN
                            fork
                                begin
                                    if (vif20.speed == brt_usb_types::LS) begin
                                        wait (!(vif20.dp == 0 && vif20.dm == 1));
                                    end
                                    else begin
                                        wait (!(vif20.dp == 1 && vif20.dm == 0));
                                    end
                                    no_trns = 0;
                                end
                                #1us;
                            join_any
                            disable fork;
                            `FORK_GUARD_END
                            
                            if (no_trns) begin
                                enter_link_state(brt_usb_types::DEVICE_ATTACHED);
                                break;
                            end
                        end
                    end
                    // DEVICE_ATTACHED
                    brt_usb_types::DEVICE_ATTACHED: begin
                        `brt_info ("host_drv_sm","device is attached.......",UVM_LOW);
                        pwon = 1;
                        // Wait for reset command
                        // enter_link_state(brt_usb_types::RESETTING);
                        forever begin
                            #1us;
                            if (!((vif20.dp == 1 && vif20.dm == 0) || (vif20.dp == 0 && vif20.dm == 1))) begin
                                `brt_info ("host_drv_sm","device is de-attached.......",UVM_LOW);
                                enter_link_state(brt_usb_types::DISCONNECTED);
                                pwon = 0;
                            end
                        end
                    end
                    // RESETTING
                    brt_usb_types::RESETTING: begin
                        `brt_info ("host_drv_sm","host resets device.......",UVM_LOW);
                        cfg.lpm_enable = 1'b0;
                        sus2rst = is_suspend;
                        vif20.speed_handshake_done = 0;
                        `brt_info ("host_drv_sm",$sformatf("host resets device sus2rst: %d.......", sus2rst),UVM_LOW);
                        hs_detection_handshake(sel_speed, this.cfg.max_speed, pwon, sus2rst);
                        pwon = 1'b0;
                        sus2rst = 1'b0;
                        is_suspend = 1'b0;
                        // Reassign speed of host and device side
                        if      (sel_speed == brt_usb_types::LS) #`LS_EXT_RST_IDLE;
                        else if (sel_speed == brt_usb_types::FS) #`FS_EXT_RST_IDLE;
                        else if (sel_speed == brt_usb_types::HS) #`HS_EXT_RST_IDLE;
                        set_link_up(sel_speed);
                        
                        enter_link_state(brt_usb_types::ENABLED);
                        -> link.do_bus_reset_done_e;  // inform to sequenvce
                    end
                    // ENABLED
                    brt_usb_types::ENABLED: begin
                        `brt_info ("host_drv_sm","host enters enable.......",UVM_LOW);
                        forever begin
                            `brt_info(get_full_name(), "get next item", UVM_HIGH)
                            seq_item_port.get(req_item);
                            //wait (shared_status.link_usb_20_state == brt_usb_types::ENABLED);

                            `brt_info(get_full_name(), {"\n", req_item.sprint()}, UVM_DEBUG);

                            $cast(rsp_item, req_item.clone());
                            rsp_item.set_id_info(req_item);

                            if (!req_item.drop) begin
                                if (!req_item.tellme) begin
                                    is_tx  = 1;
                                    transmit(req_item);
                                    if (rsp_item.need_rsp) begin
                                        rcv_pkt = 0;   // Not received packet
                                        `FORK_GUARD_BEGIN
                                        fork
                                            begin : blk_timeout
                                                if (vif20.speed == brt_usb_types::HS)
                                                    #this.cfg.hspktrsp;
                                                else if (vif20.speed == brt_usb_types::FS)
                                                    #this.cfg.fspktrsp;
                                                else
                                                    #this.cfg.lspktrsp;
                                                // Check need response
                                                if (rsp_item.need_timeout) begin
                                                    if (rcv_pkt == 0)
                                                        rsp_item.is_timeout = 1'b1;
                                                    else 
                                                        wait (rcv_pkt == 0);
                                                end
                                                else begin
                                                    if (rcv_pkt == 0) begin
                                                        `brt_error(get_full_name(), "wait for response")
                                                        rsp_item.is_timeout = 1'b1;
                                                    end
                                                    else begin
                                                        wait (rcv_pkt == 0);
                                                    end
                                                end
                                            end
                                            begin
                                                @(vif20.rx_data_e);
                                                //disable blk_timeout;
                                                rcv_pkt = 1;  // Received
                                                receive(rsp_item);
                                                rcv_pkt = 0;  // Received
                                            end
                                        join_any
                                        disable fork;
                                        `FORK_GUARD_END
                                        // Check timeout condtion
                                        if (rsp_item.need_timeout) begin
                                            if (rsp_item.is_timeout) begin
                                                `brt_info (get_name(), "Packet timeout is expected", UVM_LOW);
                                            end
                                            else begin
                                                `brt_error (get_name(), "Packet timeout is not expected");
                                            end
                                        end
                                        else begin
                                            // No need
                                        end
                                    end
                                end
                                else if (req_item.tellme) begin
                                    `brt_info(get_full_name(), "listening", UVM_LOW)
                                    wait_receive_pkt();
                                    receive(rsp_item);
                                end
                            end  // !drop
                            else begin
                                if (rsp_item.need_rsp) begin
                                    rcv_pkt = 0;   // Not received packet
                                    `FORK_GUARD_BEGIN
                                    fork
                                        begin
                                            if (vif20.speed == brt_usb_types::HS)
                                                #this.cfg.hspktrsp;
                                            else if (vif20.speed == brt_usb_types::FS)
                                                #this.cfg.fspktrsp;
                                            else
                                                #this.cfg.lspktrsp;
                                            // Check need response
                                            if (rsp_item.need_timeout) begin
                                                if (rcv_pkt == 0)
                                                    rsp_item.is_timeout = 1'b1;
                                                else 
                                                    wait (rcv_pkt == 0);
                                            end
                                            else begin
                                                if (rcv_pkt == 0)
                                                    `brt_fatal(get_full_name(), "wait for response")
                                                else
                                                    wait (rcv_pkt == 0);
                                            end
                                        end
                                        begin
                                            @(vif20.rx_data_e);
                                            rcv_pkt = 1;  // Received
                                            receive(rsp_item);
                                            rcv_pkt = 0;  // Received
                                        end
                                    join_any
                                    disable fork;
                                    `FORK_GUARD_END
                                    // Check timeout condtion
                                    if (rsp_item.need_timeout) begin
                                        if (rsp_item.is_timeout) begin
                                            `brt_info (get_name(), "Packet timeout is expected", UVM_LOW);
                                        end
                                        else begin
                                            `brt_error (get_name(), "Packet timeout is not expected");
                                        end
                                    end
                                    else begin
                                        // No need
                                    end
                                end
                            end  // drop
     
                            `brt_info(get_full_name(), "put response", UVM_HIGH)
                            //$display("SEQ ID %h %h", req_item.get_sequence_id(), rsp_item.get_sequence_id());
                            seq_item_port.put(rsp_item);
                            is_tx  = 0;
                        end // forever
                    end
                    brt_usb_types::SUSPENDED: begin
                        `brt_info ("host_drv_sm","host enters suspend.......",UVM_LOW);
                        is_suspend = 1'b1;
                        wait_j();
                        wait_k();
                        #1us;
                        wait_k();
                        `brt_info ("host_drv_sm","host enters resume due to device wakes up.......",UVM_LOW);
                        enter_link_state(brt_usb_types::RESUME);
                    end
                    brt_usb_types::RESUME: begin
                        `brt_info ("host_drv_sm","host is resuming.......",UVM_LOW);
                        is_suspend = 1'b0;
                        drive_k();
                        if (cfg.lpm_enable) begin
                            #cfg.tl1besl;  // 125us ~ 10000us
                        end
                        else begin
                            #cfg.tdrsmdn;  // 20ms
                        end
                        drive_se0();
                        #1.3us;
                        drive_idle_hs();  // pull down
                        cfg.lpm_enable = 1'b0;
                        enter_link_state(brt_usb_types::ENABLED);
                    end
                endcase  // link state
                // jump to next state when status change
                @shared_status.link_usb_20_state;
            join_any
            disable fork; // kill all thread, terminate all transaction
            `FORK_GUARD_END
        end  // forever
    endtask

    // For host
    virtual task change_link_state();
        fork
            begin
                wait (shared_status.link_usb_20_state != brt_usb_types::DISCONNECTED)
                detect_link_state();  // Check changing state of dev
            end
            begin
                wait (shared_status.link_usb_20_state != brt_usb_types::DISCONNECTED)
                detect_lpm_suspend(); // LPM suspend
            end

            forever begin
                @link.do_bus_reset_e;
                enter_link_state(brt_usb_types::RESETTING);
            end
            forever begin
                @link.execute_resume_e;
                enter_link_state(brt_usb_types::RESUME);
            end
            forever begin
                wait(link.enable_suspend_timer);
                enter_link_state(brt_usb_types::SUSPENDED);
                link.enable_suspend_timer = 0;
            end
        join
    endtask: change_link_state

  virtual task check_idle(time delay, output bit ok);
   
    fork
      begin ok=0; #delay; ok=1; end
      @(!vif20.dm);
    join_any
    disable fork;
  endtask

  virtual task detect_alternating_jk(output bit ok);
    ok = 0;
    `FORK_GUARD_BEGIN
    fork
      forever begin
        @(!vif20.dm);
        assert (vif20.dm != vif20.dp);
      end
      begin
        @(!vif20.dm);
        while (vif20.dp != 0 || vif20.dm!=0) begin
          wait (vif20.dp == 0 && vif20.dm == 0); #5ns;
          end
        check_idle(8us, ok); 
        end
      join_any
    disable fork;
    `FORK_GUARD_END
  endtask

  virtual function void enter_link_state(brt_usb_types::link20sm_state_e lstate);
    shared_status.link_usb_20_state = lstate;

    case (lstate)
      brt_usb_types::ENABLED:   vif20.is_suspended=0;
      //brt_usb_types::SUSPENDED: vif20.is_suspended=1;
      default: vif20.is_suspended=1;
    endcase

    `brt_info("USER_TRACE", $psprintf("Entered %s state.", shared_status.link_usb_20_state.name()), UVM_LOW);
  endfunction

  virtual task wait_link_state(brt_usb_types::link20sm_state_e lstate);
    wait (shared_status.link_usb_20_state == lstate);
  endtask

  virtual task wait_receive_pkt();
    fork
      @(vif20.rx_data_e);
      begin
        #100us;
        `brt_fatal(get_name(), "not received any packet")
      end
    join_any
    disable fork;
  endtask

  virtual task dev_pu();
    wait (vif20.vbus == 1);
    vif20.dp_pu = 1;  //Start is always FS
    forever begin
      @(posedge vif20.vbus)
      vif20.dp_pu = 1;
      end
  endtask

    virtual task sm_run_dev_brt_usb20_serial(); 
        bit         no_trns;
        bit         sel_speed; // 0: FS, 1: HS
        bit         ok;
        bit         rcv_pkt;
        time        hird;
        brt_usb_data req_item;
        brt_usb_data rsp_item;
        `brt_info(get_name(), $psprintf("run device"), UVM_LOW);
        //uvm_default_packer.use_metadata = 1;
        enter_link_state(brt_usb_types::DISCONNECTED);

        // Turn off device at start up
        vif20.is_host = 0;
        //vif20.dp_pd     = 0;
        //vif20.dm_pd     = 0;
        vif20.dp_pu     = 0;
        vif20.dm_pu     = 0;

        #1ns;
        wait (this.cfg.run);
        // run checking link command state
        fork 
            //dev_pu();  // pull up when vbus is on
            forever begin
                `FORK_GUARD_BEGIN
                    fork
                        begin
                            wait (shared_status.link_usb_20_state != brt_usb_types::DISCONNECTED)
                            detect_link_state();  // Check changing state of dev
                        end
                        begin
                            wait (shared_status.link_usb_20_state != brt_usb_types::DISCONNECTED)
                            detect_lpm_suspend(); // LPM suspend
                        end
                        @shared_status.link_usb_20_state;
                    join_any
                    disable fork;
                `FORK_GUARD_END
            end
        join_none
        // turn vbus on
        forever begin
            `FORK_GUARD_BEGIN
            fork
                case (shared_status.link_usb_20_state)
                    // DISCONNECTED
                    brt_usb_types::DISCONNECTED: begin
                        // detect connected of host
                        forever begin
                            if (this.cfg.max_speed == brt_usb_types::LS) begin
                                vif20.speed = brt_usb_types::LS;
                            end
                            else begin
                                vif20.speed = brt_usb_types::FS;
                            end
                            if (vif20.vbus !== 1'b1) begin
                                vif20.dp_pu     = 0;
                                vif20.dm_pu     = 0;
                            end 
                            wait (vif20.vbus === 1'b1);
                            drive_idle_ls_fs();
                            `brt_info ("dev_drv_sm","device is disconnected.......",UVM_LOW);
                            `brt_info ("dev_drv_sm",$sformatf("Current speed %d", vif20.speed), UVM_LOW);
                            no_trns = 1;
                            if (vif20.speed == brt_usb_types::LS) begin
                                wait (vif20.dp == 0 && vif20.dm == 1);
                            end
                            else begin
                                wait (vif20.dp == 1 && vif20.dm == 0);
                            end

                            // Check no transition
                            `FORK_GUARD_BEGIN
                            fork
                                begin
                                    if (vif20.speed == brt_usb_types::LS) begin
                                        wait (!(vif20.dp == 0 && vif20.dm == 1));
                                    end
                                    else begin
                                        wait (!(vif20.dp == 1 && vif20.dm == 0));
                                    end
                                    no_trns = 0;
                                end
                                #100ns;
                            join_any
                            disable fork;
                            `FORK_GUARD_END
                            
                            if (no_trns) begin
                                enter_link_state(brt_usb_types::DEVICE_ATTACHED);
                                break;
                            end
                        end
                    end
                    // DEVICE_ATTACHED
                    brt_usb_types::DEVICE_ATTACHED: begin
                        `brt_info ("dev_drv_sm","device attaches to host side.......",UVM_LOW);
                        wait_se0();
                        #1us;
                        wait_se0();
                        enter_link_state(brt_usb_types::RESETTING);
                    end
                    // RESETTING
                    brt_usb_types::RESETTING: begin
                        `brt_info ("dev_drv_sm","device start reset handshake.......",UVM_LOW);
                        cfg.lpm_enable = 1'b0;
                        vif20.speed_handshake_done = 0;
                        drive_idle_ls_fs();
                        //vif20.dp_pu = 1;
                        #1ns;
                        wait (vif20.dp == 0 && vif20.dm==0);
                        if (this.cfg.speed == brt_usb_types::HS) begin
                          vif20.dp_pu = 0;
                          //vif20.dp_pd = 1;
                          #this.cfg.tsendk;
                          drive_k();
                          #this.cfg.tuch;
                          drive_idle_hs();
                          wait (vif20.dp == 0 && vif20.dm==0);
                          #10us;
                          detect_alternating_jk(ok);
                          // ready to run
                          //#1us;
                          set_link_up(brt_usb_types::HS);
                          end
                        else begin
                          //#1ms;
                          #this.cfg.tfs_rst;
                          if (vif20.speed == brt_usb_types::LS) begin
                            set_link_up(brt_usb_types::LS);
                          end
                          else begin
                            set_link_up(brt_usb_types::FS);
                          end
                          wait_j();
                        end

                        enter_link_state(brt_usb_types::ENABLED);
                    end
                    // ENABLED
                    brt_usb_types::ENABLED: begin
                        `brt_info ("dev_drv_sm","device enters enable.......",UVM_LOW);
                        forever begin
                            seq_item_port.get(req_item);
                            $cast(rsp_item, req_item.clone());
                            rsp_item.set_id_info(req_item);

                            if (!req_item.drop) begin
                                if (req_item.tellme) begin
                                  //`brt_info(get_full_name(), "listening", UVM_HIGH)
                                  //@(vif20.rx_data_e);
                                  //receive(rsp_item);
                                  `brt_fatal (get_name(), "Not use tellme anymore, use uvm_*_put_port instead")
                                end
                                else begin  // Transmit
                                  is_tx  = 1;
                                  transmit(req_item);
                                  if (rsp_item.need_rsp) begin
                                        rcv_pkt = 0;   // Not received packet
                                        `FORK_GUARD_BEGIN
                                        fork
                                            begin : blk_timeout
                                                if (vif20.speed == brt_usb_types::HS)
                                                    #this.cfg.hspktrsp;
                                                else if (vif20.speed == brt_usb_types::FS)
                                                    #this.cfg.fspktrsp;
                                                else
                                                    #this.cfg.lspktrsp;
                                                // Check need response
                                                if (rsp_item.need_timeout) begin
                                                    rsp_item.is_timeout = 1'b1;
                                                end
                                                else begin
                                                    if (!rcv_pkt)
                                                        `brt_fatal(get_full_name(), "wait for response")
                                                    else
                                                        wait (rcv_pkt == 0);
                                                end
                                            end
                                            begin
                                                @(vif20.rx_data_e);
                                                //disable blk_timeout;
                                                rcv_pkt = 1;  // Received
                                                receive(rsp_item);
                                                rcv_pkt = 0;  // Received
                                            end
                                        join_any
                                        disable fork;
                                        `FORK_GUARD_END
                                        // Check timeout condtion
                                        if (rsp_item.need_timeout) begin
                                            if (rsp_item.is_timeout) begin
                                                `brt_info (get_name(), "Packet timeout is expected", UVM_LOW);
                                            end
                                            else begin
                                                `brt_error (get_name(), "Packet timeout is not expected");
                                            end
                                        end
                                        else begin
                                            // No need
                                        end
                                  end
                                  is_tx = 0;
                                end
                            end

                            //$display("SEQ ID %h %h", req_item.get_sequence_id(), rsp_item.get_sequence_id());
                            `brt_info(get_full_name(), "put response", UVM_HIGH)
                            seq_item_port.put(rsp_item);
                        end  // forever
                    end
                    brt_usb_types::SUSPENDED: begin
                        `brt_info ("dev_drv_sm","device enters suspend.......",UVM_LOW);
                        wait_j();
                        wait_k();
                        // check K line state
                        repeat (1) begin
                            #1us;
                            chk_k();
                        end
                        enter_link_state(brt_usb_types::RESUMING);
                    end
                    brt_usb_types::RESUME: begin
                        `brt_info ("dev_drv_sm","device enters resume.......",UVM_LOW);
                        drive_k();
                        if (this.cfg.lpm_enable) begin
                            #this.cfg.tl1hubreflect;
                        end
                        else begin
                            #this.cfg.tdev_wup_rsm;
                        end
                        drive_idle_ls_fs();
                        #1ps;
                        chk_k();
                        enter_link_state(brt_usb_types::RESUMING);
                    end
                    brt_usb_types::RESUMING: begin
                        `brt_info ("dev_drv_sm","device is resuming.......",UVM_LOW);
                        chk_k();
                        if (this.cfg.lpm_enable) begin
                            hird = this.cfg.tl1hird;
                        end
                        else begin
                            hird = this.cfg.tdrsmdn * 0.9;
                        end
                        #hird;
                        chk_k();
                        wait_se0();
                        #1us;
                        wait_se0();
                        if (this.cfg.speed == brt_usb_types::HS) begin
                            drive_idle_hs();
                        end
                        else begin
                            drive_idle_ls_fs();
                        end
                        // clear LPM
                        this.cfg.lpm_enable = 1'b0;
                        enter_link_state(brt_usb_types::ENABLED);
                    end
                endcase  // link state
                // jump to next state when status change
                @shared_status.link_usb_20_state;
            join_any
            disable fork; // kill all thread, terminate all transaction
            `FORK_GUARD_END
        end  // forever
    endtask:sm_run_dev_brt_usb20_serial

    // For device
    virtual task detect_lpm_suspend();
        int         count_se0;
        int         count_j;
        int         count_k;
        bit         not_se0;
        bit         not_j;  // for fs
        bit         not_k;  // for fs
        bit         is_res;
        bit         is_sus;

        if (this.cfg.speed == brt_usb_types::HS) begin
            fork
                forever begin
                    not_se0 = 0;
                    `FORK_GUARD_BEGIN
                    fork
                        begin
                            wait (!(vif20.dp == 0 && vif20.dm == 0));
                            not_se0 = 1;
                        end
                        #1us;
                    join_any
                    disable fork;
                    `FORK_GUARD_END

                    // Check se0
                    if (!not_se0 && shared_status.link_usb_20_state != brt_usb_types::RESETTING) begin
                        count_se0++;  // increase after 1us
                    end
                    else begin
                        count_se0 = 0;  // reset counter of se0
                        #1us;
                    end
                end
                // Detect suspend
                forever begin
                    @count_se0;
                    if (this.cfg.lpm_enable && (count_se0 * 1us == this.cfg.tl1devinit)) begin  // 10 us
                        `brt_info (get_name(),$psprintf("LPM count_se0 = %d -> FS pull up", count_se0), UVM_LOW)
                        if (!is_host) begin  // Dev
                            drive_idle_ls_fs();
                            #1ps;
                        end
                        else begin  // Host
                            #1us;
                        end
                        chk_j();
                        enter_link_state(brt_usb_types::SUSPENDED);
                    end
                end
            join
        end // HS
        else begin // FS/LS
            // suspend //
            fork
                forever begin
                    not_j = 0;
                    `FORK_GUARD_BEGIN
                    fork
                        begin
                            if (vif20.speed == brt_usb_types::FS) begin
                                wait (!(vif20.dp == 1 && vif20.dm == 0));
                            end
                            else begin  // LS
                                wait (!(vif20.dp == 0 && vif20.dm == 1));
                            end

                            not_j = 1;
                        end
                        #1us;
                    join_any
                    disable fork;
                    `FORK_GUARD_END

                    // Check j
                    if (!not_j && shared_status.link_usb_20_state != brt_usb_types::SUSPENDED) begin
                        count_j++;  // increase after 1us
                    end
                    else begin
                        count_j = 0;  // reset counter of se0
                        #1us;
                    end
                end
                // Detect suspend
                forever begin
                    @count_j;
                    if (this.cfg.lpm_enable && (count_j * 1us >= this.cfg.tl1devinit)) begin  // 10us
                        `brt_info (get_name(),$psprintf("LPM count_j = %d us -> FS suspend detected", count_j), UVM_LOW)
                        enter_link_state(brt_usb_types::SUSPENDED);
                    end
                end
            join
        end // FS/LS
    endtask

    // For host/device
    virtual task detect_link_state();
        int         count_se0;
        int         count_j;
        int         count_k;
        bit         not_se0;
        bit         not_j;  // for fs
        bit         not_k;  // for fs
        bit         is_res;
        bit         is_sus;

        if (this.cfg.speed == brt_usb_types::HS) begin
            fork
                forever begin
                    not_se0 = 0;
                    `FORK_GUARD_BEGIN
                    fork
                        begin
                            wait (!(vif20.dp == 0 && vif20.dm == 0));
                            not_se0 = 1;
                        end
                        #1us;
                    join_any
                    disable fork;
                    `FORK_GUARD_END

                    // Check se0
                    if (!not_se0 && shared_status.link_usb_20_state != brt_usb_types::RESETTING) begin
                        count_se0++;  // increase after 1us
                    end
                    else begin
                        count_se0 = 0;  // reset counter of se0
                        #1us;
                    end
                end
                // Resume //
                // Active
                forever begin
                    @link.execute_resume_e;
                    enter_link_state(brt_usb_types::RESUME);
                end
                // Detect reset/suspend
                forever begin
                    @count_se0;
                    //if (count_se0 == 3000) begin  // 3000 us
                    if (count_se0 * 1us == this.cfg.tdrst) begin  // 3000 us
                        `brt_info (get_name(),$psprintf("count_se0 = %d -> FS pull up", count_se0), UVM_LOW)
                        if (!is_host) begin
                            #10us;
                            drive_idle_ls_fs();
                        end
                        is_sus = 0;
                        fork
                            begin
                                #(cfg.trst_detect);
                                if (vif20.dp == 1 && vif20.dm == 0) begin  // J
                                    enter_link_state(brt_usb_types::SUSPENDED);
                                end
                                disable fork;
                            end
                            begin
                                //wait (count_se0 >= 3300);
                                wait (count_se0 * 1us >= this.cfg.tdrst * 1.06);
                                disable fork;
                            end
                        join_none
                    end

                    //if (count_se0 >= 3300) begin
                    if (count_se0 * 1us >= this.cfg.tdrst * 1.06) begin
                        if (!is_host && shared_status.link_usb_20_state != brt_usb_types::RESETTING) begin
                            `brt_info (get_name(),$psprintf("count_se0 = %d us -> HS resetting", count_se0), UVM_LOW)
                            enter_link_state(brt_usb_types::RESETTING);
                        end
                        count_se0 = 0;
                    end
                end
            join
        end
        else begin  // FS/LS
            fork
                forever begin
                    not_se0 = 0;
                    `FORK_GUARD_BEGIN
                    fork
                        begin
                            wait (!(vif20.dp == 0 && vif20.dm == 0));
                            not_se0 = 1;
                        end
                        #1us;
                    join_any
                    disable fork;
                    `FORK_GUARD_END

                    // Check se0
                    if (!not_se0 && shared_status.link_usb_20_state != brt_usb_types::RESETTING) begin
                        count_se0++;  // increase after 1us
                    end
                    else begin
                        count_se0 = 0;  // reset counter of se0
                        #1us;
                    end
                end
                // Detect reset
                forever begin
                    @count_se0;
                    //if (count_se0 == 3000) begin  // 3 ms
                    if (count_se0 * 1us >= this.cfg.fsrst) begin  // 3 ms
                        if (!is_host && shared_status.link_usb_20_state != brt_usb_types::RESETTING) begin
                            `brt_info (get_name(),$psprintf("count_se0 = %d us -> FS reset detected", count_se0), UVM_LOW)
                            enter_link_state(brt_usb_types::RESETTING);
                        end
                    end
                end
                // suspend //
                forever begin
                    not_j = 0;
                    `FORK_GUARD_BEGIN
                    fork
                        begin
                            if (vif20.speed == brt_usb_types::FS) begin
                                wait (!(vif20.dp == 1 && vif20.dm == 0));
                            end
                            else begin
                                wait (!(vif20.dp == 0 && vif20.dm == 1));
                            end

                            not_j = 1;
                        end
                        #1us;
                    join_any
                    disable fork;
                    `FORK_GUARD_END

                    // Check se0
                    if (!not_j && shared_status.link_usb_20_state != brt_usb_types::SUSPENDED) begin
                        count_j++;  // increase after 1us
                    end
                    else begin
                        count_j = 0;  // reset counter of se0
                        #1us;
                    end
                end
                // Detect suspend
                forever begin
                    @count_j;
                    //if (count_j == 3000) begin  // 3 ms
                    if (count_j * 1us == this.cfg.fstdsus) begin  // 3 ms
                        `brt_info (get_name(),$psprintf("count_j = %d us -> FS suspend detected", count_j), UVM_LOW)
                        enter_link_state(brt_usb_types::SUSPENDED);
                    end
                end
                // Resume //
                // Active
                forever begin
                    @link.execute_resume_e;
                    enter_link_state(brt_usb_types::RESUME);
                end
                // Passive
                //forever begin
                //    not_k = 0;
                //    `FORK_GUARD_BEGIN
                //    fork
                //        begin
                //            if (vif20.speed == brt_usb_types::FS) begin
                //                wait (!(vif20.dp == 0 && vif20.dm == 1));
                //            end
                //            else begin
                //                wait (!(vif20.dp == 1 && vif20.dm == 0));
                //            end

                //            not_k = 1;
                //        end
                //        #1us;
                //    join_any
                //    disable fork;
                //    `FORK_GUARD_END

                //    // Check se0
                //    if (!not_k) begin
                //        count_k++;  // increase after 1us
                //    end
                //    else begin
                //        count_k = 0;  // reset counter of se0
                //        #1us;
                //    end
                //end
                // Detect resume
                //forever begin
                //    @count_k;
                //    if (count_k == 20000) begin  // 20 ms
                //        `FORK_GUARD_BEGIN
                //        fork
                //            begin
                //                wait_se0();
                //                is_res = 1;
                //            end
                //            #10ms;
                //        join_any
                //        `FORK_GUARD_END
                //        if (is_res) begin
                //            `brt_info (get_name(),$psprintf("count_se0 = %d -> FS resume detected", count_se0), UVM_LOW)
                //            enter_link_state(brt_usb_types::ENABLED);
                //        end
                //        else begin
                //            `brt_fatal (get_name(),$psprintf("count_se0 = %d -> FS resume not detected", count_se0))
                //        end
                //    end
                //end
            join
        end  // FS/LS
    endtask:detect_link_state

  virtual task run_dev_utmi();
  endtask
  
  virtual task run_host_utmi();
  endtask

endclass

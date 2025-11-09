typedef class brt_usb_driver;
class brt_usb_monitor extends brt_usb_driver;
  //virtual               brt_usb_if 	ser_vif;
  //virtual               brt_usb_20_serial_if vif20;
  virtual brt_usb_20_utmi_if        vifutmi;
  brt_usb_agent_config 	            agt_cfg;
  brt_analysis_port #(brt_usb_data) ap;
  event                             pkt_evt;
  event                             utmi_chk_k_evt;
  event                             utmi_chk_k_not_exist_evt;

  `brt_component_utils_begin(brt_usb_monitor)
  `brt_component_utils_end

  function new(string name, brt_component parent);
    super.new(name, parent);
  endfunction

  virtual function void drive_0();          endfunction
  virtual function void drive_1();          endfunction
  virtual function void drive_se0();        endfunction
  virtual function void drive_se1();        endfunction
  virtual function void drive_reset();      endfunction
  virtual function void drive_j();          endfunction         
  virtual function void drive_k();          endfunction         
  virtual function void drive_idle_ls_fs(); endfunction                       
  virtual function void drive_idle_hs();    endfunction                    
  virtual function void drive_idle();       endfunction                 

  function void build_phase (brt_phase phase);
    bit status;
    //super.build_phase(phase);
    shared_status = brt_usb_status::type_id::create("mon_usb_status", this);
    ap 		= new("ap", this);
    status 	= uvm_config_db#(brt_usb_agent_config)::get(null, get_full_name(), "cfg", agt_cfg);
    if (!status)
      `brt_fatal(get_full_name(), "no cfg")

    $cast(cfg,agt_cfg); // upper class cfg

    status 	= uvm_config_db#(virtual brt_usb_if)::get(null, get_full_name(), "brt_usb_20_if", ser_vif);
    if (!status)
      `brt_fatal(get_full_name(), "no interface")

    vif20 = ser_vif.brt_usb_20_serial_if;
    vifutmi = ser_vif.brt_usb_20_utmi_if;
  endfunction

  function void connect_phase (brt_phase phase);
    super.connect_phase(phase);
  endfunction

  virtual task run_phase (brt_phase phase);
    brt_usb_data 			udata, udata_clone;
    bit                     rst;
    `brt_info("Trace", $sformatf("%m"), UVM_MEDIUM);
    forever begin
        rst = 0;
        fork
            forever begin
                if (agt_cfg.mon_enable) get_in_pkt ();
                else wait (agt_cfg.mon_enable);
            end
            forever begin
                if (agt_cfg.mon_enable) get_out_pkt ();
                else wait (agt_cfg.mon_enable);
            end
            // Run when agt monitor only
            if (agt_cfg.vip_enable) begin
                sm_run_dev_brt_usb20_serial_mon();
            end
            else begin
                sm_run_dev_brt_usb20_serial();
            end

            begin
                @ (agt_cfg.mon_enable);
                rst = 1;
            end

            begin
                @ (agt_cfg.vip_enable);
                rst = 1;
            end
            chk_utmi_if();
        join_none
        wait (rst);
        disable fork;
    end
  endtask

  virtual task get_in_pkt ();
    bit             received_pkt;
    brt_usb_data    udata;
    bit             eop_err;
    time            sync_t;
    //do begin
        received_pkt = 0;
        `FORK_GUARD_BEGIN
        fork
            begin
                @(vif20.rx_data_e);
                udata = brt_usb_data::type_id::create("udata");
                if   (vif20.speed    == brt_usb_types::HS) sync_t = 32 * 2083;
                else if (vif20.speed == brt_usb_types::FS) sync_t = 7.5 * 83333;
                else if (vif20.speed == brt_usb_types::LS) sync_t = 7.5 * 666666;
                udata.pkt_start_t = $time - sync_t;
                `brt_info ("MON", $sformatf ("Start_time: %t", udata.pkt_start_t), UVM_DEBUG)
                get_receive(udata, eop_err);
                if (!eop_err) received_pkt = 1; // Done
            end
        join_any
        `FORK_GUARD_END

        if (received_pkt) begin
            `brt_info(get_name(),"monitor gets an IN packet and put to upper layer", UVM_MEDIUM)
            ap.write (udata);
        end
    //end while (1);
  endtask: get_in_pkt  

  virtual task get_out_pkt ();
    bit         received_pkt;
    brt_usb_data    udata;
    bit             eop_err;

    //do begin
        received_pkt = 0;
        `FORK_GUARD_BEGIN
        fork
            begin
                @ vif20.gen_tx_clk_e;
                udata = brt_usb_data::type_id::create("udata");
                udata.pkt_start_t = $time;
                `brt_info ("MON", $sformatf ("Start_time: %t", udata.pkt_start_t), UVM_DEBUG)
                get_transmit(udata, eop_err);
                udata.ignore_tx_err = 1;  // Ignore TX error
                if (!eop_err) received_pkt = 1; // Done
            end
        join_any
        `FORK_GUARD_END

        if (received_pkt) begin
            `brt_info(get_name(),"monitor gets an OUT packet and put to upper layer", UVM_MEDIUM)
            ap.write (udata);
        end
    //end while (1);
  endtask: get_out_pkt  

  virtual task get_receive(brt_usb_data udata, output bit eop_err);
    bit data_q[$];
    bit detect_idle;
    bit eop, prev_eop;

    detect_idle = 0;
    eop_err     = 0;
    do begin
      @(negedge vif20.rx_clk_fdpd);
      if (this.is_valid_data()) 
        data_q.push_back(get_nrzi_rxdata());
      else if (this.is_idle())
        detect_idle=1;
      else `brt_fatal(get_full_name(), "invalid data")
      end while (!detect_idle);

    // strip off EOP
    if (vif20.speed == brt_usb_types::HS) begin
      prev_eop = data_q.pop_back();
      repeat (7) begin
        if (prev_eop != data_q.pop_back()) begin
          `brt_fatal(get_full_name(), "invalid eop")
          eop_err     = 1;          
        end
      end
    end
    
    while(data_q.size())
      udata.nrzi_data_q.push_back(data_q.pop_front());

    -> pkt_evt;
  endtask

  virtual task get_transmit(brt_usb_data udata, output bit eop_err);
    bit strip_sync;
    int num_k;
    bit data_q[$];
    bit detect_idle;
    bit prev_eop;

    detect_idle = 0;
    eop_err     = 0;
    //@ vif20.gen_tx_clk_e;
    // transmit_sync_pattern(udata.num_kj);
    // wait for SYNC complete
    @ (negedge vif20.tx_clk);

    do begin
        @ (negedge vif20.tx_clk);
        if ((vif20.dm == 1 && vif20.speed != brt_usb_types::LS) ||
            (vif20.dm == 0 && vif20.speed == brt_usb_types::LS))
            num_k ++;
        else
            num_k = 0;

        strip_sync = (num_k == 2);
    end while (!strip_sync);

    `brt_info (get_name(), $sformatf ("Detect strip SYNC"), UVM_MEDIUM)
    // Get data
    do begin
      @(negedge vif20.tx_clk);
      if (this.is_valid_data()) 
        data_q.push_back(get_nrzi_rxdata());
      else if (this.is_idle())
        detect_idle=1;
      else `brt_fatal(get_full_name(), "invalid data")
      end while (!detect_idle);

    // strip off EOP
    if (vif20.speed == brt_usb_types::HS) begin
      prev_eop = data_q.pop_back();
      repeat (7) begin
        if (prev_eop != data_q.pop_back()) begin
          `brt_fatal(get_full_name(), "invalid eop")
          eop_err = 1;
        end
      end
    end
    
    while(data_q.size())
      udata.nrzi_data_q.push_back(data_q.pop_front());

    -> pkt_evt;
  endtask

    // Re-writre this task to use for monitor
    virtual task sm_run_dev_brt_usb20_serial(); 
        bit         no_trns;
        bit         sel_speed; // 0: FS, 1: HS
        bit         exist_k;
        bit         exist_kj;
        bit         dev_cnnt;
        `brt_info(get_name(), $psprintf("run monitor"), UVM_LOW);
        enter_link_state(brt_usb_types::DISCONNECTED);

        // Turn off device at start up
        vif20.is_host = 0;
        vif20.dp_pu     = 0;
        vif20.dm_pu     = 0;

        // run checking link command state
        fork 
            forever begin
                `FORK_GUARD_BEGIN
                    fork
                        begin
                            wait (dev_cnnt);
                            detect_link_state();  // Check changing state of dev
                        end
                        @shared_status.link_usb_20_state;
                        @dev_cnnt;
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
                            dev_cnnt = 0;
                            if (this.cfg.max_speed == brt_usb_types::LS) begin
                                vif20.speed = brt_usb_types::LS;
                            end
                            else begin
                                vif20.speed = brt_usb_types::FS;
                            end
                            `brt_info ("mon_drv_sm","device is disconnected.......",UVM_LOW);
                            `brt_info ("mon_drv_sm",$sformatf("Current speed %d", vif20.speed), UVM_LOW);
                            no_trns = 1;
                            wait_j();

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
                        `brt_info ("mon_drv_sm","device attaches to host side.......",UVM_LOW);
                        dev_cnnt = 1;
                        wait_se0();
                        enter_link_state(brt_usb_types::RESETTING);
                    end
                    // RESETTING
                    brt_usb_types::RESETTING: begin
                        `brt_info ("mon_drv_sm","device start reset handshake.......",UVM_LOW);
                        vif20.speed_handshake_done = 0;
                        //drive_idle_ls_fs();
                        #1us;
                        wait_se0();
                        if (this.cfg.speed == brt_usb_types::FS ||
                            this.cfg.speed == brt_usb_types::HS    
                        ) begin
                            // wait host send chirp K
                            exist_k = 0;
                            `FORK_GUARD_BEGIN
                                fork
                                    begin
                                        wait_k();
                                        exist_k = 1;
                                    end
                                    begin
                                        #this.cfg.tdrst;  // 3ms
                                    end
                                    begin
                                        wait_j();
                                    end
                                join_any
                                disable fork;
                            `FORK_GUARD_END
                            `brt_info ("mon_drv_sm",$sformatf("Current speed: %s exist_k: %d", this.cfg.speed, exist_k), UVM_MEDIUM);
                            if (exist_k) begin  // check chirp KJ sequense
                                -> utmi_chk_k_evt;
                                exist_kj = 0;  // for checking chirp KJ
                                `FORK_GUARD_BEGIN
                                    fork
                                        begin
                                            wait_se0();
                                            repeat (3) begin
                                                wait_k();
                                                wait_j();
                                            end
                                            exist_kj = 1;
                                        end
                                        begin
                                            wait_se0();
                                            repeat (10) begin
                                                #this.cfg.tdchbit;  // ~40us;
                                            end
                                        end
                                    join_any
                                    disable fork;
                                `FORK_GUARD_END
                                if (exist_kj) begin
                                    this.cfg.speed = brt_usb_types::HS;
                                end
                                else begin
                                    this.cfg.speed = brt_usb_types::FS;
                                end
                            end
                            else begin  // FS
                                -> utmi_chk_k_not_exist_evt;
                                this.cfg.speed = brt_usb_types::FS;
                            end
                            $cast(vif20.speed, this.cfg.speed);
                        end

                        if (vif20.speed == brt_usb_types::HS) begin
                            wait_se0();
                        end
                        else begin
                            wait_j();
                        end

                        set_link_up(this.cfg.speed);
                        vif20.speed_handshake_done = 1;
                        enter_link_state(brt_usb_types::ENABLED);
                    end
                    // ENABLED
                    brt_usb_types::ENABLED: begin
                        `brt_info ("mon_drv_sm","device enters enable.......",UVM_LOW);
                        `brt_info ("mon_drv_sm",$sformatf("Current speed %s", this.cfg.speed), UVM_LOW);
                        wait (0);
                    end
                    brt_usb_types::SUSPENDED: begin
                        `brt_info ("mon_drv_sm","device enters suspend.......",UVM_LOW);
                        wait_j();
                        wait_k();
                        #1us;
                        wait_k();
                        enter_link_state(brt_usb_types::RESUMING);
                    end
                    brt_usb_types::RESUME: begin
                        `brt_info ("mon_drv_sm","device enters resume.......",UVM_LOW);
                        wait_k();
                        wait_j();
                        enter_link_state(brt_usb_types::RESUMING);
                    end
                    brt_usb_types::RESUMING: begin
                        `brt_info ("mon_drv_sm","device is resuming.......",UVM_LOW);
                        wait_se0();
                        #1us;
                        wait_se0();
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

    virtual task sm_run_dev_brt_usb20_serial_mon(); 
        bit         no_trns;
        bit         sel_speed; // 0: FS, 1: HS
        bit         exist_k;
        bit         exist_kj;
        bit         dev_cnnt;
        `brt_info(get_name(), $psprintf("run monitor"), UVM_LOW);
        enter_link_state(brt_usb_types::DISCONNECTED);

        // run checking link command state
        fork 
            forever begin
                `FORK_GUARD_BEGIN
                    fork
                        begin
                            wait (dev_cnnt);
                            detect_link_state();  // Check changing state of dev
                        end
                        @shared_status.link_usb_20_state;
                        @dev_cnnt;
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
                        #1ps;
                        // detect connected of host
                        forever begin
                            dev_cnnt = 0;
                            `brt_info ("mon_drv_sm","device is disconnected.......",UVM_LOW);
                            `brt_info ("mon_drv_sm",$sformatf("Current speed %d", vif20.speed), UVM_LOW);
                            no_trns = 1;
                            wait_j();

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
                        `brt_info ("mon_drv_sm","device attaches to host side.......",UVM_LOW);
                        dev_cnnt = 1;
                        wait_se0();
                        enter_link_state(brt_usb_types::RESETTING);
                    end
                    // RESETTING
                    brt_usb_types::RESETTING: begin
                        `brt_info ("mon_drv_sm","device start reset handshake.......",UVM_LOW);
                        //drive_idle_ls_fs();
                        #1us;
                        wait_se0();
                        if (this.cfg.speed == brt_usb_types::FS ||
                            this.cfg.speed == brt_usb_types::HS    
                        ) begin
                            // wait host send chirp K
                            exist_k = 0;
                            `FORK_GUARD_BEGIN
                                fork
                                    begin
                                        wait_k();
                                        exist_k = 1;
                                    end
                                    begin
                                        #this.cfg.tdrst;  // 3ms
                                    end
                                    begin
                                        wait_j();
                                    end
                                join_any
                                disable fork;
                            `FORK_GUARD_END
                            `brt_info ("mon_drv_sm",$sformatf("Current speed: %s exist_k: %d", this.cfg.speed, exist_k), UVM_MEDIUM);
                            if (exist_k) begin  // check chirp KJ sequense
                                -> utmi_chk_k_evt;
                                exist_kj = 0;  // for checking chirp KJ
                                `FORK_GUARD_BEGIN
                                    fork
                                        begin
                                            wait_se0();
                                            repeat (3) begin
                                                wait_k();
                                                wait_j();
                                            end
                                            exist_kj = 1;
                                        end
                                        begin
                                            wait_se0();
                                            repeat (10) begin
                                                #this.cfg.tdchbit;  // ~40us;
                                            end
                                        end
                                    join_any
                                    disable fork;
                                `FORK_GUARD_END
                                if (exist_kj) begin // HS
                                    wait_se0();
                                end
                                else begin // FS
                                    wait_j();
                                end
                            end
                            else begin  // FS
                                -> utmi_chk_k_not_exist_evt;
                                wait_j();
                            end
                        end

                        enter_link_state(brt_usb_types::ENABLED);
                    end
                    // ENABLED
                    brt_usb_types::ENABLED: begin
                        `brt_info ("mon_drv_sm","device enters enable.......",UVM_LOW);
                        `brt_info ("mon_drv_sm",$sformatf("Current speed %s", this.cfg.speed), UVM_LOW);
                        wait (0);
                    end
                    brt_usb_types::SUSPENDED: begin
                        `brt_info ("mon_drv_sm","device enters suspend.......",UVM_LOW);
                        wait_j();
                        wait_k();
                        #1us;
                        wait_k();
                        enter_link_state(brt_usb_types::RESUMING);
                    end
                    brt_usb_types::RESUME: begin
                        `brt_info ("mon_drv_sm","device enters resume.......",UVM_LOW);
                        wait_k();
                        //wait_j();
                        enter_link_state(brt_usb_types::RESUMING);
                    end
                    brt_usb_types::RESUMING: begin
                        `brt_info ("mon_drv_sm","device is resuming.......",UVM_LOW);
                        wait_se0();
                        #1us;
                        wait_se0();
                        enter_link_state(brt_usb_types::ENABLED);
                    end
                endcase  // link state
                // jump to next state when status change
                @shared_status.link_usb_20_state;
            join_any
            disable fork; // kill all thread, terminate all transaction
            `FORK_GUARD_END
        end  // forever
    endtask:sm_run_dev_brt_usb20_serial_mon

    virtual task chk_utmi_if();
        int     utmi_mode;
        fork
            // Always check when receive/transmit packet
            forever begin
                wait (this.cfg.utmi_connect);
                @pkt_evt;
                // Check UTMI mode
                if (this.cfg.utmi_connect) begin  // enable UTMI checker
                    if (vifutmi.utmiopmode != `UTMI_NORMAL) begin
                        `brt_fatal (get_name(), $sformatf("UTMI mode is not normal mode. Real: %d", vifutmi.utmiopmode))
                    end
                    else begin
                        `brt_info  (get_name(), $sformatf("UTMI mode is normal mode. Real: %d", vifutmi.utmiopmode), UVM_MEDIUM)
                    end
                    // Speed
                    if (this.cfg.speed == brt_usb_types::HS) begin
                        if (vifutmi.utmixcvrselect != 0 || 
                            vifutmi.utmitermselect != 0    
                        ) begin
                            `brt_fatal (get_name(), $sformatf("Device speed %s , UTMI signal, utmixcvrselect: %d, utmitermselect: %d", 
                                                               this.cfg.speed, vifutmi.utmixcvrselect, vifutmi.utmitermselect))
                        end
                        else begin
                            `brt_info  (get_name(), $sformatf("Device speed %s , UTMI signal, utmixcvrselect: %d, utmitermselect: %d",
                                                               this.cfg.speed, vifutmi.utmixcvrselect, vifutmi.utmitermselect), UVM_MEDIUM)
                        end
                    end
                    else if (this.cfg.speed == brt_usb_types::HS) begin
                        if (vifutmi.utmixcvrselect != 1 || 
                            vifutmi.utmitermselect != 1    
                        ) begin
                            `brt_fatal (get_name(), $sformatf("Device speed %s , UTMI signal, utmixcvrselect: %d, utmitermselect: %d", 
                                                               this.cfg.speed, vifutmi.utmixcvrselect, vifutmi.utmitermselect))
                        end
                        else begin
                            `brt_info  (get_name(), $sformatf("Device speed %s , UTMI signal, utmixcvrselect: %d, utmitermselect: %d",
                                                               this.cfg.speed, vifutmi.utmixcvrselect, vifutmi.utmitermselect), UVM_MEDIUM)
                        end
                    end
                    else begin
                    end

                end
            end
            // Check when enable by user
            forever begin
                wait (this.cfg.utmi_connect);
                wait (this.cfg.utmi_chk_mod_en);
                #this.cfg.utmi_chk_period;
                // Check UTMI mode
                if (this.cfg.utmi_chk_mod_en &&  this.cfg.utmi_mode >= 0) begin  // enable UTMI checker
                    if (vifutmi.utmiopmode != this.cfg.utmi_mode) begin
                        `brt_fatal (get_name(), $sformatf("UTMI mode is not as expected mode. Expected: %d, Real: %d", this.cfg.utmi_mode, vifutmi.utmiopmode))
                    end
                    else begin
                        `brt_info  (get_name(), $sformatf("UTMI mode is as expected mode. Expected: %d, Real: %d", this.cfg.utmi_mode, vifutmi.utmiopmode), UVM_MEDIUM)
                    end
                end
                // Check test mode
                if (this.cfg.utmi_chk_mod_en) begin  // enable UTMI checker
                    case (this.cfg.utmi_testmode)
                        `TESTMODE_NAK: begin
                            utmi_mode = `UTMI_NORMAL;
                            if (vifutmi.utmiopmode != utmi_mode) begin
                                `brt_fatal (get_name(), $sformatf("UTMI mode of testmode is not as expected mode. Expected: %d, Real: %d", utmi_mode, vifutmi.utmiopmode))
                            end
                            else begin
                                `brt_info  (get_name(), $sformatf("UTMI mode of testmode is as expected mode. Expected: %d, Real: %d", utmi_mode, vifutmi.utmiopmode), UVM_MEDIUM)
                            end
                        end
                        `TESTMODE_J: begin
                            utmi_mode = `UTMI_DISENCODE;
                            if (vifutmi.utmiopmode != utmi_mode) begin
                                `brt_fatal (get_name(), $sformatf("UTMI mode of testmode is not as expected mode. Expected: %d, Real: %d", utmi_mode, vifutmi.utmiopmode))
                            end
                            else begin
                                `brt_info  (get_name(), $sformatf("UTMI mode of testmode is as expected mode. Expected: %d, Real: %d", utmi_mode, vifutmi.utmiopmode), UVM_MEDIUM)
                            end
                            // valid and data
                            if (vifutmi.utmitxvalid != 1 || vifutmi.utmidatao != 'hFF) begin
                                `brt_fatal (get_name(), $sformatf("UTMI valid/data of testmode is not as expected"))
                            end
                            else begin
                                `brt_info  (get_name(), $sformatf("UTMI valid/data of testmode is as expected"), UVM_MEDIUM)
                            end
                        end
                        `TESTMODE_K: begin
                            utmi_mode = `UTMI_DISENCODE;
                            if (vifutmi.utmiopmode != utmi_mode) begin
                                `brt_fatal (get_name(), $sformatf("UTMI mode of testmode is not as expected mode. Expected: %d, Real: %d", utmi_mode, vifutmi.utmiopmode))
                            end
                            else begin
                                `brt_info  (get_name(), $sformatf("UTMI mode of testmode is as expected mode. Expected: %d, Real: %d", utmi_mode, vifutmi.utmiopmode), UVM_MEDIUM)
                            end
                            // valid and data
                            if (vifutmi.utmitxvalid != 1 || vifutmi.utmidatao != 'h00) begin
                                `brt_fatal (get_name(), $sformatf("UTMI valid/data of testmode is not as expected"))
                            end
                            else begin
                                `brt_info  (get_name(), $sformatf("UTMI valid/data of testmode is as expected"), UVM_MEDIUM)
                            end
                        end
                        `TESTMODE_DATA: begin
                            utmi_mode = `UTMI_NORMAL;
                            if (vifutmi.utmiopmode != utmi_mode) begin
                                `brt_fatal (get_name(), $sformatf("UTMI mode of testmode is not as expected mode. Expected: %d, Real: %d", utmi_mode, vifutmi.utmiopmode))
                            end
                            else begin
                                `brt_info  (get_name(), $sformatf("UTMI mode of testmode is as expected mode. Expected: %d, Real: %d", utmi_mode, vifutmi.utmiopmode), UVM_MEDIUM)
                            end
                        end
                    endcase
                end
            end

            // Check chirp K event
            forever begin
                wait (this.cfg.utmi_connect);
                wait (this.cfg.utmi_chk_k_en);
                @utmi_chk_k_evt;
                // Check UTMI mode
                if (!this.cfg.utmi_chk_k_en) begin  // enable UTMI checker
                    continue;
                end
                // Check opmode
                if (vifutmi.utmiopmode != `UTMI_DISENCODE) begin
                    `brt_fatal (get_name(), $sformatf("UTMI mode (chirp K) is not as expected mode. Expected: %d, Real: %d", `UTMI_DISENCODE, vifutmi.utmiopmode))
                end
                else begin
                    `brt_info  (get_name(), $sformatf("UTMI mode (chirp K) is as expected mode. Expected: %d, Real: %d", `UTMI_DISENCODE, vifutmi.utmiopmode), UVM_MEDIUM)
                end
                // Check txvalid & data
                if (vifutmi.utmitxvalid != 1'b1 || vifutmi.utmidatao != 0) begin
                    `brt_fatal (get_name(), $sformatf("UTMI mode (chirp K) is not correct. utmitxvalid: %d, utmidatao: %d", vifutmi.utmitxvalid, vifutmi.utmidatao))
                end
                else begin
                    `brt_info  (get_name(), $sformatf("UTMI mode (chirp K) is correct. utmitxvalid: %d, utmidatao: %d", vifutmi.utmitxvalid, vifutmi.utmidatao), UVM_MEDIUM)
                end

                // check utmixcvrselect & utmitermselect
                if (vifutmi.utmixcvrselect != 0 || 
                    vifutmi.utmitermselect != 1    
                ) begin
                    `brt_fatal (get_name(), $sformatf("Device speed %s , UTMI signal, utmixcvrselect: %d, utmitermselect: %d", 
                                                       this.cfg.speed, vifutmi.utmixcvrselect, vifutmi.utmitermselect))
                end
                else begin
                    `brt_info  (get_name(), $sformatf("Device speed %s , UTMI signal, utmixcvrselect: %d, utmitermselect: %d",
                                                       this.cfg.speed, vifutmi.utmixcvrselect, vifutmi.utmitermselect), UVM_MEDIUM)
                end
            end
            // Check chirp K not exist in FS mode
            forever begin
                wait (this.cfg.utmi_connect);
                wait (this.cfg.utmi_chk_k_en);
                @utmi_chk_k_not_exist_evt;
                // Check UTMI mode
                if (!this.cfg.utmi_chk_k_en) begin  // enable UTMI checker
                    continue;
                end
                //if (this.cfg.utmi_chk_k_en) begin  // enable UTMI checker
                //    if (vifutmi.utmiopmode != `UTMI_NORMAL) begin
                //        `brt_fatal (get_name(), $sformatf("UTMI mode (not chirp K) is not as expected mode. Expected: %d, Real: %d", `UTMI_DISENCODE, vifutmi.utmiopmode))
                //    end
                //    else begin
                //        `brt_info  (get_name(), $sformatf("UTMI mode (not chirp K) is as expected mode. Expected: %d, Real: %d", `UTMI_DISENCODE, vifutmi.utmiopmode), UVM_MEDIUM)
                //    end
                //end
                // check utmixcvrselect & utmitermselect
                if (vifutmi.utmixcvrselect != 1 || 
                    vifutmi.utmitermselect != 1    
                ) begin
                    `brt_fatal (get_name(), $sformatf("Device speed %s , UTMI signal, utmixcvrselect: %d, utmitermselect: %d", 
                                                       this.cfg.speed, vifutmi.utmixcvrselect, vifutmi.utmitermselect))
                end
                else begin
                    `brt_info  (get_name(), $sformatf("Device speed %s , UTMI signal, utmixcvrselect: %d, utmitermselect: %d",
                                                       this.cfg.speed, vifutmi.utmixcvrselect, vifutmi.utmitermselect), UVM_MEDIUM)
                end
            end
        join
    endtask

endclass

class brt_usb_data2packet_monitor extends brt_subscriber #(brt_usb_data);
  `brt_component_utils_begin(brt_usb_data2packet_monitor)
  `brt_component_utils_end

  brt_usb_config    cfg;
  brt_analysis_imp #(brt_usb_data,brt_usb_data2packet_monitor)   ap_imp;
  brt_analysis_port#(brt_usb_packet) ap;
  brt_usb_packet pkt_out;
  int pkt_count=0;
  bit ext_pkt;

  function new(string name, brt_component parent);
    super.new(name, parent);
    ap = new("ap", this);
    ap_imp = new("ap_imp", this);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
  endfunction

  function void write(brt_usb_data t);
    bit         is_host;
    bit         ignore_err;

    pkt_out = brt_usb_packet::type_id::create($psprintf("packet%0d", ++pkt_count));
    t.do_data_decoding();

    // LPM
    if (ext_pkt == 1'b1) begin
        pkt_out.is_lpm = 1'b1;
        ext_pkt = 1'b0;
    end
    void'(pkt_out.unpack(t.data));

    // Start time
    pkt_out.pkt_start_t = t.pkt_start_t;
    `brt_info (get_name(), $sformatf ("Packet monitor gets a packet %s", pkt_out.pid_name.name()), UVM_MEDIUM)
    is_host = this.cfg.component_type == brt_usb_types::HOST;
    ignore_err  = is_host? cfg.ignore_mon_host_err:cfg.ignore_mon_dev_err;
    ignore_err |= (cfg.ignore_mon_tx_err && t.ignore_tx_err);

    // SOF EOP is special case. It is 40 symbols without a transition, so ignore the bit stuff error for now (TBD check during decoding).
    if (t.bit_stuff_err && pkt_out.pid_name != brt_usb_packet::SOF) begin
      if (!ignore_err) `brt_error(get_name, "bit stuffing error")
      pkt_out.pkt_err = 1;
      pkt_out.bit_stuff_err = 1;
    end
    // EXT packet
    if (pkt_out.pid_name == brt_usb_packet::EXT) begin
        ext_pkt = 1;
    end

    pkt_out.chk_err(ignore_err);
    ap.write(pkt_out);
  endfunction

endclass

class brt_usb_packet2xfer_monitor extends brt_subscriber #(brt_usb_packet);
  `brt_component_utils_begin(brt_usb_packet2xfer_monitor)
  `brt_component_utils_end

  brt_analysis_port#(brt_usb_transfer) ap;
  brt_usb_transfer xfer_out;
  int xfer_count=0;

  function new(string name, brt_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
  endfunction

  function void write(brt_usb_packet t);
    // ...
    xfer_out = brt_usb_transfer::type_id::create($psprintf("transfer%0d", ++xfer_count));
  endfunction

endclass

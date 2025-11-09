class brt_usb_base_test extends brt_test;
  `brt_component_utils(brt_usb_base_test)
  brt_usb_env_config         cfg;
  brt_usb_env                env;
  string                     dev_speed;
  // user callback
  brt_usb_dev_util_callback  dev_util_cb;
  brt_usb_host_util_callback host_util_cb;

  function new(string name = "brt_usb_base_test", brt_component parent=null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);

    cfg = brt_usb_env_config::type_id::create("cfg",this);
    env = brt_usb_env::type_id::create("env", this);
    
    // Default config
    dev_cfg(); 
    cfg.dev_cfg.local_device_cfg[0].endpoint_cfg[1].allow_aligned_transfer_without_zero_length = 0;
    uvm_config_db#(brt_usb_env_config)       ::set(this, "env", "cfg", this.cfg);
    // Dev callback
    dev_util_cb   = brt_usb_dev_util_callback::type_id::create("dev_util_cb");
    uvm_config_db#(brt_usb_dev_util_callback)::set(this,"","dev_util_cb",dev_util_cb);
    // Host callback
    host_util_cb   = brt_usb_host_util_callback::type_id::create("host_util_cb");
    uvm_config_db#(brt_usb_host_util_callback)::set(this,"","host_util_cb",host_util_cb);
  endfunction

    // User can overide this function to make there own config
    virtual function dev_cfg ();
        $value$plusargs("brt_usb_dev_speed=%s", dev_speed);
        `brt_info(get_name(), $psprintf("dev_speed %s", dev_speed), UVM_LOW);

        if (dev_speed == "hs" || dev_speed == "HS") begin 
          cfg.setup_brt_usb_20_defaults(brt_usb_types::HS, brt_usb_types::HS);
          cfg.host_cfg.max_speed = brt_usb_types::HS;
          cfg.dev_cfg.max_speed = brt_usb_types::HS;
        end
        else if (dev_speed == "fs" || dev_speed == "FS") begin
          cfg.setup_brt_usb_20_defaults(brt_usb_types::FS, brt_usb_types::FS);
          cfg.host_cfg.max_speed = brt_usb_types::FS;
        end
        else begin 
          cfg.setup_brt_usb_20_defaults(brt_usb_types::LS, brt_usb_types::LS);
          //cfg.host_cfg.max_speed = brt_usb_types::LS;
          cfg.dev_cfg.max_speed = brt_usb_types::LS;
        end
    endfunction:dev_cfg

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Connect scoreboard
        // host
        env.host_xfer_cb.aport_xfer_exp.connect(env.mult_sb.aport_exp_host);
        env.host_xfer_cb.aport_xfer_act.connect(env.mult_sb.aport_act_host);
        // dev
        env.dev_xfer_cb.aport_xfer_exp.connect(env.mult_sb.aport_exp_dev);
        env.dev_xfer_cb.aport_xfer_act.connect(env.mult_sb.aport_act_dev);

        // User callback
        uvm_callbacks#(brt_usb_protocol)::add(env.dev_agent.prot, dev_util_cb);
        uvm_callbacks#(brt_usb_protocol)::add(env.host_agent.prot, host_util_cb);
    endfunction

  virtual function void final_phase(brt_phase phase) ;
    brt_report_server svr;
    `brt_info("final_phase", "Entered...", UVM_HIGH)
    super.final_phase(phase);
    // Report callback
    if (host_util_cb.added_chk_pnt != 0) begin
        `brt_error ("PKT_CHECKER", $sformatf ("A packet checker has been created but not added to callback. Remained: %d", host_util_cb.added_chk_pnt))
    end
    if (host_util_cb.injected_err != 0) begin
        `brt_error ("PKT_CHECKER", $sformatf ("A packet error injection has not done. Remained: %d", host_util_cb.injected_err))
    end
    host_util_cb.report_chk_pkt();
    // Report ERROR
    svr = brt_report_server::get_server();
    if (svr.get_severity_count(UVM_FATAL) +
        svr.get_severity_count(UVM_ERROR) /*+
        svr.get_severity_count(UVM_WARNING) > 0*/)  begin
      `brt_info("final_phase", "\nSvtTestEpilog: Failed\n", UVM_LOW)
      $display(" #### Status: TEST FAILED ####");
      end
    else begin
      `brt_info("final_phase", "\nSvtTestEpilog: Passed\n", UVM_LOW)
      $display(" #### Status: TEST PASSED ####");
      end
    `brt_info("final_phase", "Exiting...", UVM_HIGH)
  endfunction

  virtual task run_phase(brt_phase phase) ;
    super.run_phase(phase);
    #100ms;
    `brt_error("","TIMEOUT");
    phase.drop_objection(this);
  endtask
endclass
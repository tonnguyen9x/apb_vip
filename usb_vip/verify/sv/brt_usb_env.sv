class brt_usb_host_env extends brt_env;

  brt_usb_agent                     host_agent;
  virtual brt_usb_if                host_brt_usb_if;

  brt_usb_env_config                cfg;
  brt_usb_enumeration_callback      enum_cb;
  brt_usb_xfer_trace_callback       host_xfer_cb;
  xfer_summary_callback            host_xfer_sum;
  bit                               enum_config_run;

  `brt_component_utils(brt_usb_host_env)

  function new(string name, brt_component parent);
    super.new(name, parent);
    enum_config_run=0;
  endfunction

  virtual function void build_phase(brt_phase phase);
    bit status;
    super.build_phase(phase);
    if (!uvm_config_db#(virtual brt_usb_if)::get(null,get_full_name(), "host_brt_usb_if", host_brt_usb_if)) begin
      `brt_fatal("build_phase", "could not find brt_usb interface")
      end
    if (!uvm_config_db#(brt_usb_env_config)::get(get_parent(), get_name(), "cfg", cfg)) begin
      `brt_fatal("build_phase", "could not find brt_usb environment config")
      end

    if (cfg.host_cfg.usb_20_signal_interface != brt_usb_config::NO_20_IF) begin
      uvm_config_db#(virtual brt_usb_if)::set(this, "host_agent", "brt_usb_20_if", this.host_brt_usb_if);
      end

    host_agent    = brt_usb_agent::type_id::create("host_agent", this);
    enum_cb       = new("enum_cb");
    host_xfer_cb  = new("host_xfer_cb", 1);
    host_xfer_sum  = new("host_xfer_sum", 1);

    uvm_config_db#(brt_usb_agent_config)::set(this, "host_agent",  "cfg",                 cfg.host_cfg);
    // enable monitor
    cfg.host_cfg.mon_enable = 1'b1;
    cfg.host_cfg.tuch       = 999us;
    // enable coverage
    cfg.host_cfg.cov_enable = 1'b1;
  endfunction

  task enumeration_auto_update();
    brt_usb_config get_cfg, post_cfg, pre_cfg;
    `brt_info(get_name(),$sformatf("called "), UVM_HIGH);
    if (enum_config_run) `brt_fatal("body", "non re-entrant task")
    enum_config_run = 1;
    while(enum_config_run) begin
      host_agent.virt_sequencer.xfer_sequencer.get_cfg(get_cfg);
      if (!$cast(pre_cfg, get_cfg)) begin
        `brt_fatal("body", "Unable to cast");
        end
      `brt_info(get_name(),$sformatf("Current Configuration: %s", pre_cfg.sprint()), UVM_LOW);
      uvm_config_db#(brt_usb_config)::set(this, "host_agent*", "seq_cfg", pre_cfg);
      enum_cb.cfg = pre_cfg;
      if (!$cast(enum_cb.updated_cfg,enum_cb.cfg.clone())) begin
        `brt_fatal("body", "enum_cb.cfg unable to cast");
        end
      @(enum_cb.set_address_e);
      `brt_info(get_name(),$sformatf("Host sent set_address command"), UVM_HIGH);
      #1ns; // small delay
      if ($cast(post_cfg, enum_cb.updated_cfg.clone())) begin
        `brt_info(get_name(),$sformatf("Env: Host about to reconfigure cfg:"), UVM_HIGH);
        host_agent.reconfigure(post_cfg);
        `brt_info(get_name(),$sformatf("Env: Host Post Enumeration Reconfigured cfg - remote_device_cfg[0].device_address %h ", post_cfg.remote_device_cfg[0].device_address), UVM_HIGH);
        post_cfg.print();
        end
      else begin
        `brt_fatal("body", "Unable to $cast pre_cfg to  post_cfg")
        end
      end
  endtask

  task check_link_status();
    brt_usb_types::link20sm_state_e prev_lstate;
    forever begin
      prev_lstate = host_agent.shared_status.link_usb_20_state;
      `brt_info(get_name(), $psprintf("Current link state: %s ", prev_lstate.name()), UVM_HIGH)
      #1;
      wait (prev_lstate != host_agent.shared_status.link_usb_20_state);
      end
  endtask

  virtual function void connect_phase(brt_phase phase);
    super.connect_phase(phase);
    uvm_callbacks#(brt_usb_protocol)::add(host_agent.prot, enum_cb);
    uvm_callbacks#(brt_usb_protocol)::add(host_agent.prot, host_xfer_cb);
    uvm_callbacks#(brt_usb_protocol)::add(host_agent.prot, host_xfer_sum);
  endfunction

  virtual function void start_of_simulation_phase(brt_phase phase);
    super.start_of_simulation_phase(phase);
  endfunction: start_of_simulation_phase

  virtual function void report_phase(brt_phase phase);
    super.report_phase(phase);
  endfunction

  task main_phase(brt_phase phase) ;
    uvm_objection objection;
    super.main_phase(phase);
    fork
      enumeration_auto_update();
      check_link_status();
      join_none
  endtask
endclass:brt_usb_host_env

class brt_usb_env extends brt_usb_host_env;

  virtual brt_usb_if                    dev_brt_usb_if;
  virtual brt_usb_if                    mon_brt_usb_if;

  brt_usb_agent                         dev_agent;
  brt_usb_mult_sb_wrapper               mult_sb;

  brt_usb_agent                         mon_agent;
  brt_usb_env_config                    mon_cfg;
  // Trasnfer trace and sb
  brt_usb_xfer_trace_callback           dev_xfer_cb;

  `brt_component_utils(brt_usb_env)
  function new(string name, brt_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual brt_usb_if)::get(null,get_full_name(), "dev_brt_usb_if", dev_brt_usb_if)) begin
      `brt_fatal("build_phase", "could not find brt_usb interface")
    end
    if (!uvm_config_db#(virtual brt_usb_if)::get(null,get_full_name(), "mon_brt_usb_if", mon_brt_usb_if)) begin
      `brt_fatal("build_phase", "could not find brt_usb interface")
    end

    uvm_config_db#(brt_usb_agent_config)::set(this, "dev_agent", "cfg",                 cfg.dev_cfg);

    if (cfg.host_cfg.usb_20_signal_interface != brt_usb_config::NO_20_IF) begin
      uvm_config_db#(virtual brt_usb_if)::set(this, "dev_agent", "brt_usb_20_if", this.dev_brt_usb_if);
      end

    // dev agt
    dev_agent    = brt_usb_agent::type_id::create("dev_agent", this);
    uvm_config_db#(brt_usb_agent)::set(this,"","dev_agent",dev_agent);
    // mon agt
    mon_agent    = brt_usb_agent::type_id::create("mon_agent", this);
    mon_cfg = brt_usb_env_config ::type_id::create("mon_cfg_test");
    mon_cfg.setup_brt_usb_20_defaults();
    mon_cfg.dev_cfg.vip_enable = 1'b0;
    mon_cfg.dev_cfg.mon_enable = 1'b0;

    uvm_config_db#(brt_usb_agent)::set(this,"","mon_agent",mon_agent);
    uvm_config_db#(brt_usb_agent_config)::set(this, "mon_agent", "cfg", mon_cfg.dev_cfg);
    uvm_config_db#(virtual brt_usb_if)::set(this, "mon_agent", "brt_usb_20_if", this.mon_brt_usb_if);
    // Scoreboard
    mult_sb      = brt_usb_mult_sb_wrapper::type_id::create("mult_sb", this);
    uvm_config_db#(brt_usb_mult_sb_wrapper)::set(this,"","mult_sb",mult_sb);
    dev_xfer_cb  = new("dev_xfer_cb", 0);
    // enable monitor
    cfg.dev_cfg.mon_enable = 1'b1;
    // enable coverage
    cfg.dev_cfg.cov_enable = 1'b1;

  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    uvm_callbacks#(brt_usb_protocol)::add(dev_agent.prot, dev_xfer_cb);
  endfunction

endclass:brt_usb_env

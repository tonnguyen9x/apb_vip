class brt_usb_agent extends brt_agent;

  virtual brt_usb_if ser_vif;

  brt_usb_virtual_sequencer             virt_sequencer;
  brt_usb_transfer_sequencer            xfer_sequencer;
  brt_usb_packet_sequencer              brt_usb_20_pkt_sequencer;
  brt_usb_data_sequencer                brt_usb_20_data_sequencer;
  brt_usb_link_service_sequencer        link_service_sequencer;
  brt_usb_protocol_service_sequencer    prot_service_sequencer;
  brt_usb_physical_service_sequencer    brt_usb_20_phys_service_sequencer;

  brt_usb_monitor                       mon;
  brt_usb_protocol                      prot;
  brt_usb_link                          link;
  brt_usb_physical                      phys;
  brt_usb_driver                        udriver;
  brt_usb_layering                      ulayer;
  brt_usb_agent_config                  cfg;

  brt_usb_fcov_callback                 fcov_cb;
  brt_usb_timing_callback               timing_cb;
  brt_usb_perf_callback                 perf_cb;
  xfer_summary_callback                 xfer_sum_cb;
  xfer_feature_callback                 xfer_feat_cb;
  //xfer_port_callback                    xfer_port_cb;
  brt_usb_status                        shared_status;

  bit                                   is_host;
  `brt_component_utils(brt_usb_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(brt_phase phase);
    bit status;
    super.build_phase(phase);

    // configuration
    status = uvm_config_db#(brt_usb_agent_config)::get(null, get_full_name(), "cfg", cfg);
    if (!status)
      `brt_fatal(get_full_name(), "can not get configuration file")

    // set configuration for child layer
    uvm_config_db#(brt_usb_config)::set(this, "brt_usb_driver",  "cfg", cfg);
    if (cfg.mon_enable) begin
        uvm_config_db#(brt_usb_agent_config)::set(this, "brt_usb_monitor", "cfg", cfg);
        // Select individual config or VIP config
        //uvm_config_db#(bit)::set(this, "brt_usb_monitor", "vip_enable", cfg.vip_enable);
    end
    // virtual interface
    status = uvm_config_db#(virtual brt_usb_if)::get(null, get_full_name(), "brt_usb_20_if", ser_vif);
    if (!status)
      `brt_fatal(get_full_name(), "can not get interface")
    uvm_config_db#(virtual brt_usb_if)::set(this, "brt_usb_driver",  "brt_usb_20_if", ser_vif);
    uvm_config_db#(bit)::set(this, "brt_usb_driver", "vip_enable", cfg.vip_enable);

    if (cfg.mon_enable) begin
        uvm_config_db#(virtual brt_usb_if)::set(this,       "brt_usb_monitor",  "brt_usb_20_if", ser_vif);
    end

    virt_sequencer     = brt_usb_virtual_sequencer  ::type_id::create("brt_usb_virtual_sequencer", this);
    if (cfg.mon_enable) begin
        mon            = brt_usb_monitor            ::type_id::create("brt_usb_monitor", this);
    end
    prot               = brt_usb_protocol           ::type_id::create("brt_usb_protocol", this);
    link               = brt_usb_link               ::type_id::create("brt_usb_link", this);
    phys               = brt_usb_physical           ::type_id::create("brt_usb_physical", this);
    udriver            = brt_usb_driver             ::type_id::create("brt_usb_driver", this);
    ulayer             = brt_usb_layering           ::type_id::create("brt_usb_layering", this);
    shared_status      = brt_usb_status             ::type_id::create("brt_usb_status", this);

    if (this.cfg.component_type == brt_usb_types::HOST) begin
        this.is_host=1;
    end

    if (cfg.cov_enable) begin
        fcov_cb             = new("fcov_cb", is_host);
        timing_cb           = new("timing_cb", cfg);
    end
    perf_cb                 = new("perf_cb", cfg);
    xfer_sum_cb             = new("xfer_sum_cb", is_host);
    xfer_feat_cb            = new("xfer_feat_cb");
    //xfer_port_cb            = new("xfer_port_cb");
  endfunction

  virtual function void connect_phase(brt_phase phase);
    super.connect_phase(phase);

    if (!this.cfg.randomize()) begin
      `brt_fatal(get_full_name(), "randomize error")
      end

    virt_sequencer.xfer_sequencer               = ulayer.xfer_sequencer;
    virt_sequencer.brt_usb_20_pkt_sequencer     = ulayer.brt_usb_20_pkt_sequencer;
    virt_sequencer.brt_usb_20_data_sequencer    = ulayer.brt_usb_20_data_sequencer;
    virt_sequencer.link_service_sequencer       = ulayer.link_service_sequencer;
    virt_sequencer.prot_service_sequencer       = ulayer.prot_service_sequencer;
    virt_sequencer.shared_status                = this.shared_status;
    virt_sequencer.agt                          = this;

    this.prot.cfg                               = this.cfg;

    this.xfer_sequencer                         = virt_sequencer.xfer_sequencer;
    this.xfer_sequencer.agt                     = this;
    this.xfer_sequencer.prot                    = prot;
    this.xfer_sequencer.cfg                     = this.cfg;
    this.xfer_sequencer.shared_status           = this.shared_status;

    this.brt_usb_20_pkt_sequencer               = virt_sequencer.brt_usb_20_pkt_sequencer;
    this.brt_usb_20_pkt_sequencer.agt           = this;
    this.brt_usb_20_pkt_sequencer.link          = link;
    this.brt_usb_20_pkt_sequencer.prot          = prot;
    this.brt_usb_20_pkt_sequencer.cfg           = this.cfg;

    this.brt_usb_20_data_sequencer              = virt_sequencer.brt_usb_20_data_sequencer;
    this.brt_usb_20_data_sequencer.agt          = this;
    this.brt_usb_20_data_sequencer.phys         = phys;
    this.brt_usb_20_data_sequencer.cfg          = this.cfg;

    this.link_service_sequencer                 = virt_sequencer.link_service_sequencer;
    this.link_service_sequencer.agt             = this;
    this.link_service_sequencer.link            = link;
    this.link_service_sequencer.cfg             = this.cfg;

    this.prot_service_sequencer                 = virt_sequencer.prot_service_sequencer;
    this.prot_service_sequencer.agt             = this;
    this.prot_service_sequencer.cfg             = this.cfg;
    this.prot_service_sequencer.shared_status   = this.shared_status;

    udriver.cfg                                 = this.cfg;
    udriver.shared_status                       = this.shared_status;
    udriver.prot                                = prot;
    udriver.link                                = link;
    udriver.phys                                = phys;
    udriver.seq_item_port.connect(this.brt_usb_20_data_sequencer.seq_item_export);

    if (cfg.mon_enable) begin
        mon.link                                    = link;
    end

    ulayer.cfg                                  = this.cfg;
    xfer_feat_cb.shared_status                  = this.shared_status;

    // connect port to export
    prot.transfer_out_port.connect(ulayer.out);  // Usb transfer packet
    if (cfg.mon_enable) begin
        mon.ap.connect(ulayer.link_mon.ap_imp);      // brt_usb packet analysis port
    end
    ulayer.link_mon.ap.connect (prot.ap_packet_imp);
    // Connect device
    //if (this.cfg.component_type == brt_usb_types::DEVICE) begin
        udriver.out_brt_usb_data_port.connect(link.imp_brt_usb_data_port);
        link.out_brt_usb_pkt_port.connect(prot.p_brt_usb_pkt_imp);
    //end

    uvm_callbacks#(brt_usb_protocol)::add(this.prot,perf_cb);
    // Add buld-in callback
    if (cfg.cov_enable) begin
        uvm_callbacks#(brt_usb_protocol)::add(this.prot,fcov_cb);
        uvm_callbacks#(brt_usb_protocol)::add(this.prot,timing_cb);
    end
    if (cfg.vip_enable) begin
        create_brt_usb_status();
    
        if (cfg.enable_prot_tracing)            uvm_callbacks#(brt_usb_protocol)::add(this.prot,xfer_sum_cb);
        if (!is_host && cfg.enable_feature_cb)  uvm_callbacks#(brt_usb_protocol)::add(this.prot,xfer_feat_cb);
        //uvm_callbacks#(brt_usb_protocol)::add(this.prot,xfer_port_cb);
        `brt_info(get_full_name(), $sformatf("%m"), UVM_HIGH);
    end
  endfunction:connect_phase

  virtual function void create_brt_usb_status(int pos = 0);
    brt_usb_device_status   dev_status;
    brt_usb_endpoint_status est;
    bit[3:0]            epnum;
    bit                 dir;

    // Instant fist dev as default
    dev_status = new ("dev_status");
    this.shared_status.remote_device_status[pos] = dev_status;

    if (this.cfg.component_type == brt_usb_types::HOST) begin
      foreach(this.cfg.remote_device_cfg[pos].endpoint_cfg[i]) begin
          if (this.cfg.remote_device_cfg[pos].endpoint_cfg[i] == null) begin
              continue;
          end
          epnum = this.cfg.remote_device_cfg[pos].endpoint_cfg[i].ep_number;
          $cast (dir,this.cfg.remote_device_cfg[pos].endpoint_cfg[i].direction);
          
          if (epnum==0) dir = 1;  // calib for EP0

          est = brt_usb_endpoint_status::type_id::create($psprintf("endpoint_status[%0d]", 2*epnum + dir));
          est.ep_state = brt_usb_types::EP_ENABLE;
          est.dt_toggle = 0; //default
          this.shared_status.remote_device_status[pos].endpoint_status[2*epnum + dir]= est;
          `brt_info (get_name(), $psprintf ("Initiate status for endpoint %d, direction %d", epnum, dir),UVM_LOW);
      end
    end 
    else begin
      foreach(this.cfg.local_device_cfg[pos].endpoint_cfg[i]) begin
          if (this.cfg.local_device_cfg[pos].endpoint_cfg[i] == null) begin
              continue;
          end
          epnum = this.cfg.local_device_cfg[pos].endpoint_cfg[i].ep_number;
          $cast (dir,this.cfg.local_device_cfg[pos].endpoint_cfg[i].direction);
          
          if (epnum==0) dir = 1;  // calib for EP0

          est = brt_usb_endpoint_status::type_id::create($psprintf("endpoint_status[%0d]", 2*epnum + dir));
          est.ep_state = brt_usb_types::EP_ENABLE;
          est.dt_toggle = 0; //default
          this.shared_status.remote_device_status[pos].endpoint_status[2*epnum + dir]= est;
          `brt_info (get_name(), $psprintf ("Initiate status for endpoint %d, direction %d", epnum, dir),UVM_LOW);
      end
    end
  endfunction

  virtual function void clear_ep_toggle (bit[3:0] epnum, bit dir, int pos = 0);
    this.shared_status.remote_device_status[pos].endpoint_status[2*epnum + dir].dt_toggle = 0;
    `brt_info (get_name(), $psprintf ("Clear data toggle for endpoint %d, direction %d", epnum, dir),UVM_LOW);
  endfunction

  // Device mode only
  virtual task abort_transfer (bit[3:0] epnum, bit dir);
    int idx;
    if (is_host) begin
        `brt_fatal (get_name(),"This function is not for host mode")
    end

    foreach (ulayer.d_x2p_seq[i]) begin
        if (ulayer.d_x2p_seq[i].ep_cfg.ep_number == epnum &&
            ulayer.d_x2p_seq[i].ep_cfg.direction == dir
        ) begin
            idx = i;
            break;
        end
    end

    ulayer.abort_transfer (idx);
    `brt_info (get_name(), $psprintf ("Abort transfer: endpoint %d, direction %d", epnum, dir),UVM_LOW);
  endtask

  virtual function void start_of_simulation_phase(brt_phase phase);
    super.start_of_simulation_phase(phase);
    `brt_info(get_full_name(), $sformatf("%m"), UVM_HIGH);
  endfunction: start_of_simulation_phase

  virtual function void clear_halt_status(int epnum, bit dir);
    brt_usb_endpoint_status ep_status;
    
    if (epnum == 0) dir = 1'b1;  // Calib for EP0 index

    foreach(shared_status.remote_device_status[0].endpoint_status[i]) begin
      ep_status = shared_status.remote_device_status[0].endpoint_status[i];
      if ((epnum*2 + dir) == i) begin
          ep_status.ep_state = brt_usb_types::EP_ENABLE;
      end
    end
  endfunction

  virtual function void reconfigure(brt_usb_config cfg);

    this.cfg.remote_device_cfg[0].device_address = cfg.remote_device_cfg[0].device_address;
    this.cfg.remote_device_cfg[0].remote_wakeup_capable = cfg.remote_device_cfg[0].remote_wakeup_capable;

    `brt_info(get_full_name(), $sformatf("Reconfigure %s", this.cfg.sprint()), UVM_HIGH);

  endfunction

  virtual function void report_phase(brt_phase phase);
    string s;
    super.report_phase(phase);
    if (cfg.enable_prot_tracing) begin
        s = udriver.cfg.component_type.name();
        $display("*** %s Transfer SUMMARY ***\n", s);
        while (xfer_sum_cb.packet_sum_q.size()) begin
          $display("%s", xfer_sum_cb.packet_sum_q.pop_front());
          end
        $display("\n\n");
        while (xfer_sum_cb.summary_q.size()) begin
          $display("%s", xfer_sum_cb.summary_q.pop_front());
          end
        $display("\n\n\n");
    end
    //Performance checking
    if (cfg.perf_chk_en) begin
        perf_cb.cal_perf();
        $display ("=============Performance============");
        $display ("Average speed: %d (B/s)", perf_cb.perf_speed);
        $display ("====================================");
        if (cfg.perf_min_chk != -1 && cfg.perf_min_chk > perf_cb.perf_speed) begin
            `brt_error ("PERF_CHK", $sformatf("Performance is too low. Min speed: %d, Real speed: %d",cfg.perf_min_chk, perf_cb.perf_speed))
        end
        if (cfg.perf_max_chk != -1 && cfg.perf_max_chk < perf_cb.perf_speed) begin
            `brt_error ("PERF_CHK", $sformatf("Performance is too high. Max speed: %d, Real speed: %d",cfg.perf_max_chk, perf_cb.perf_speed))
        end
    end
  endfunction

  virtual function void display_msg();
    $display("Test agent .... \n\n\n");
  endfunction

endclass

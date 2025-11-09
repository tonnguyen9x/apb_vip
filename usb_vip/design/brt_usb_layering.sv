// brt_usb protocol abstraction layering
class brt_usb_layering extends brt_subscriber #(brt_usb_data);

    `brt_component_utils(brt_usb_layering)

    brt_analysis_port #(brt_usb_transfer) ap;
    brt_blocking_peek_export #(brt_usb_transfer) out;

    brt_usb_transfer_sequencer             xfer_sequencer;
    brt_usb_packet_sequencer               brt_usb_20_pkt_sequencer;
    brt_usb_data_sequencer                 brt_usb_20_data_sequencer;
    brt_usb_link_service_sequencer         link_service_sequencer;
    brt_usb_protocol_service_sequencer     prot_service_sequencer;

    brt_usb_data2packet_monitor            link_mon;
    brt_usb_packet2xfer_monitor            prot_mon;

    brt_usb_config                         cfg;
    bit                                    is_host;

    brt_usb_xfer2packet_sequence           x2p_seq[];
    brt_usb_packet2data_sequence           p2d_seq;
    brt_usb_linkservice_sequence           lserv_seq;
    brt_usb_protservice_sequence           pserv_seq;

    // transfer router for host
    brt_usb_xfer_router_sequence           xfer_router_seq;
    // SOF
    brt_usb_sof_pkt_sequence               sof_pkt_seq;  

    // for Device Agent
    brt_usb_dev_xfer2packet_sequence       d_x2p_seq[];
    brt_usb_dev_packet2data_sequence       d_p2d_seq;
    brt_usb_dev_packet_router_sequence     d_pkt_rtr_seq;

  function new(string name, brt_component parent=null);
    super.new(name, parent);
    ap = new("ap", this);
    out = new("out", this);
  endfunction

  virtual function void write(brt_usb_data t);
    link_mon.write(t);
  endfunction

  virtual function void connect_phase(brt_phase phase);
    link_mon.ap.connect(prot_mon.analysis_export);
    prot_mon.ap.connect(ap);
    out.connect(xfer_sequencer.out);
  endfunction

  virtual function void build_phase(brt_phase phase);
    super.build_phase(phase);
    xfer_sequencer             = brt_usb_transfer_sequencer            ::type_id::create("xfer_sequencer", this);
    brt_usb_20_pkt_sequencer   = brt_usb_packet_sequencer              ::type_id::create("brt_usb_packet_sequencer", this);
    brt_usb_20_data_sequencer  = brt_usb_data_sequencer                ::type_id::create("brt_usb_data_sequencer", this);
    link_service_sequencer     = brt_usb_link_service_sequencer        ::type_id::create("link_service_sequencer", this);
    prot_service_sequencer     = brt_usb_protocol_service_sequencer    ::type_id::create("prot_service_sequencer", this);
    link_mon                   = brt_usb_data2packet_monitor           ::type_id::create("link_mon", this);
    prot_mon                   = brt_usb_packet2xfer_monitor           ::type_id::create("prot_mon", this);


    x2p_seq                        = new [`NUM_EP];
    foreach (x2p_seq[i]) x2p_seq[i]= brt_usb_xfer2packet_sequence::type_id::create($psprintf("x2p_seq%0d",i));
    p2d_seq                        = brt_usb_packet2data_sequence::type_id::create("p2d_seq");

    lserv_seq                      = brt_usb_linkservice_sequence::type_id::create("lserv_seq");
    pserv_seq                      = brt_usb_protservice_sequence::type_id::create("pserv_seq");

    // router
    xfer_router_seq                = brt_usb_xfer_router_sequence::type_id::create("xfer_router_seq");
    sof_pkt_seq                    = brt_usb_sof_pkt_sequence::type_id::create("sof_pkt_seq");

    // For device
    d_x2p_seq           = new[`NUM_EP];
    foreach (d_x2p_seq[i]) begin
        d_x2p_seq[i] = brt_usb_dev_xfer2packet_sequence::type_id::create($psprintf("d_x2p_seq%0d",i));
    end
    d_p2d_seq           = brt_usb_dev_packet2data_sequence::type_id::create("d_p2d_seq");
    d_pkt_rtr_seq       = brt_usb_dev_packet_router_sequence::type_id::create("d_pkt_rtr_seq");
  endfunction

  virtual task run_phase(brt_phase phase);

    link_mon.cfg = this.cfg;

    is_host = this.cfg.component_type == brt_usb_types::HOST;

    pserv_seq.is_host        = is_host;
    if (is_host) begin
        foreach (x2p_seq[i]) begin
            x2p_seq[i].is_host = is_host;
            x2p_seq[i].ep_cfg  = cfg.remote_device_cfg[0].endpoint_cfg[i];
        end
    end

    // connect translation sequence to their upstream sequencers
    foreach (x2p_seq[i]) x2p_seq[i].up_sequencer = this.xfer_sequencer;
    if (!is_host) begin
        foreach (d_x2p_seq[i]) begin
            d_x2p_seq[i].up_sequencer      = this.xfer_sequencer;
            d_x2p_seq[i].is_host           = this.is_host;
            d_x2p_seq[i].ep_cfg            = cfg.local_device_cfg[0].endpoint_cfg[i];
        end
    end
    p2d_seq.up_sequencer        = this.brt_usb_20_pkt_sequencer;
    d_p2d_seq.up_sequencer      = this.brt_usb_20_pkt_sequencer;
    d_pkt_rtr_seq.ulayer        = this;

    lserv_seq.up_sequencer      = this.link_service_sequencer;
    pserv_seq.up_sequencer      = this.prot_service_sequencer;

    sof_pkt_seq.up_sequencer    = this.xfer_sequencer;
    xfer_router_seq.up_sequencer = this.xfer_sequencer;
    `brt_info(get_name(), $psprintf("Component Type: %s", is_host ? "Host":"Device" ), UVM_LOW)

    // start translation sequences
    fork
      //forever begin
      //  testmode_packet_sequence tseq;
      //  @(lserv_seq.wait_tmode_pkt_e);
      //  `brt_info(get_name(), $psprintf("Ready to expect TESTMODE Packet"), UVM_LOW)
      //  tseq = testmode_packet_sequence::type_id::create();
      //  if (is_host) tseq.start(brt_usb_20_pkt_sequencer,,100);   // Test mode sequence
      //end
      // Host
      if (is_host) foreach (x2p_seq[i]) begin
        automatic int k;
        k = i;
        fork
            x2p_seq[k].start(brt_usb_20_pkt_sequencer);       // Transfer to packet sequence
            x2p_seq[k].idx = k;
        join_none
      end
      if (is_host) p2d_seq.start(brt_usb_20_data_sequencer);      // Packet to data sequence

      if (is_host) xfer_router_seq.start(brt_usb_20_pkt_sequencer);
      // Enable SOF
      if (is_host) sof_pkt_seq.start(brt_usb_20_pkt_sequencer,,100);
      //if (is_host) begin 
      //    transmit_sof(pserv_seq.enable_tx_sof);
      //end
      // Device
      if (!is_host) foreach (d_x2p_seq[i]) begin
        automatic int k;
        k = i;
        fork
            d_x2p_seq[k].start(brt_usb_20_pkt_sequencer);
        join_none
      end
      if (!is_host) d_pkt_rtr_seq.start(brt_usb_20_pkt_sequencer);
      if (!is_host) d_p2d_seq.start    (brt_usb_20_data_sequencer);
      // Service
      lserv_seq.start(link_service_sequencer);
      pserv_seq.start(prot_service_sequencer);
    join_none

  endtask

  virtual task abort_transfer (int idx);
    -> d_x2p_seq[idx].abort_xfer;
  endtask
endclass
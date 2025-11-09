class brt_usb_lpm_xfer_sequence extends brt_usb_xfer_base_sequence;
    // LPM bmAttributes
    rand bit                     seq_remote_wake;
    rand bit[3:0]                seq_hird;
    rand bit[3:0]                seq_link_state;
    brt_usb_agent                l_agent;
    brt_usb_config               pre_cfg;
    brt_usb_config               cfg;
    brt_sequencer_base           seqr_base;
    brt_usb_transfer_sequencer   seqr;
    string                       scope_name;

    `brt_object_utils(brt_usb_lpm_xfer_sequence)
    
    function new(string name="brt_usb_lpm_xfer_sequence");
      super.new(name);
    endfunction

    task body();
        `brt_info("body",$sformatf("Running Sequence: %s", this.sprint()), UVM_HIGH);
        seqr_base = get_sequencer();

        if (!$cast(seqr, seqr_base)) begin
            `brt_fatal("body", "cast failed")
        end
        else if (!$cast(l_agent, seqr.find_first_agent(this)) || (l_agent == null)) begin
            `brt_fatal("body","Agent handle is null")
        end

        if (l_agent.shared_status.link_usb_20_state != brt_usb_types::ENABLED) begin
            `brt_warning ("body", "A transfer is queued while link is not ENABLE")
            wait (l_agent.shared_status.link_usb_20_state == brt_usb_types::ENABLED);
        end

        if (scope_name == "") begin
            scope_name = get_sequencer().get_full_name();
        end
        if (!uvm_config_db#(brt_usb_config)::get(null, scope_name, "seq_cfg", cfg )) begin
          `brt_error("body", "can not get configuration");
        end

        if (!$cast(pre_cfg, cfg))
            `brt_fatal("body", "Unable to cast");

        `brt_create(req)
        start_item(req);
        req.cfg = pre_cfg;
        //req.payload.USER_DEFINED_ALGORITHM_wt = 1;
        //req.payload.TWO_SEED_BASED_ALGORITHM_wt = 0;
        if (!req.randomize() with {
                                    endpoint_number             == 0;
                                    xfer_type                   == brt_usb_transfer::LPM_TRANSFER; 
                                    // payload  size
                                    payload_intended_byte_count == 0;
                                    // LPM
                                    lpm_remote_wake             == seq_remote_wake;
                                    lpm_hird                    == seq_hird;
                                    lpm_link_state              == seq_link_state;
                                    dir                         == brt_usb_types::OUT;
        }) begin
            `brt_fatal("body", "randomize error");   // Default
        end
        finish_item(req);
        get_response(rsp);
        `brt_info("body", $sformatf("Transfer %s is done", req.xfer_type.name()), UVM_LOW)
    endtask
endclass

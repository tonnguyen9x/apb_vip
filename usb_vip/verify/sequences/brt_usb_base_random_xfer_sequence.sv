class brt_usb_base_random_xfer_sequence extends brt_usb_xfer_base_sequence;
    string                       scope_name = "";
    brt_usb_config               upd_cfg;
    brt_usb_base_config          get_cfg;
    brt_usb_config               pre_cfg;
    brt_usb_config               post_cfg;
    brt_usb_config               cfg;
    brt_usb_agent                l_agent;
    brt_sequencer_base           seqr_base;
    brt_usb_transfer_sequencer   seqr;
    // LPM bmAttributes
    rand bit                     seq_remote_wake;
    rand bit[3:0]                seq_hird;
    rand bit[3:0]                seq_link_state;

    bit                          randomize_checker=0;

    rand brt_usb_transfer::transfer_type_e     ttype;
    rand int                                   payload_size;
    rand bit                                   rand_data_en;
    rand int                                   ep_num;

    constraint type_constr {
      ttype inside {brt_usb_transfer::BULK_IN_TRANSFER, brt_usb_transfer::BULK_OUT_TRANSFER,
                    brt_usb_transfer::INTERRUPT_IN_TRANSFER, brt_usb_transfer::INTERRUPT_OUT_TRANSFER,
                    brt_usb_transfer::ISOCHRONOUS_IN_TRANSFER, brt_usb_transfer::ISOCHRONOUS_OUT_TRANSFER,
                    brt_usb_transfer::LPM_TRANSFER};
        }

    constraint length_constr {
      soft payload_size == -1;
        }
    // Deafault data payload is 16bit pattern
    constraint default_cnstr {
        soft rand_data_en == 0;
        soft ep_num       == -1;
    }

    `brt_object_utils_begin(brt_usb_base_random_xfer_sequence)
    `brt_object_utils_end

  function new(string name="brt_usb_base_random_xfer_sequence");
    super.new(name);
  endfunction : new

  virtual function void create_request();
    `brt_info("body",$sformatf("create request payload_size %0d", payload_size), UVM_HIGH);
    if (!req.randomize() with {
                                if (ep_num >=0) {
                                    endpoint_number           == ep_num;
                                }
                                xfer_type                     == ttype; 
                                // payload  size
                                if (payload_size >= 0) {
                                    payload_intended_byte_count   == payload_size;
                                }
                                else {
                                    payload_intended_byte_count   inside {[0:10*1024]};
                                }
                                if (ttype ==  brt_usb_transfer::BULK_OUT_TRANSFER && !rand_data_en) {
                                    foreach (payload.data[i]){
                                        payload.data[i] == data8[i%data8.size()];
                                    }
                                }
                                // LPM
                                if (ttype == brt_usb_transfer::LPM_TRANSFER) {
                                    lpm_remote_wake == seq_remote_wake;
                                    lpm_hird        == seq_hird;
                                    lpm_link_state  == seq_link_state;
                                    dir             == brt_usb_types::OUT;
                                }
      }) begin
        
      if (!randomize_checker) begin
        `brt_fatal("body", "randomize error");   // Default
      end
      else begin
        `brt_warning("body", "randomize checker: constraint does not hold");
      end

      req.find_ep_cfg();
    end
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

    `brt_info("body", $sformatf("link status %s",l_agent.shared_status.sprint()), UVM_HIGH)

    if (scope_name == "") begin
      scope_name = get_sequencer().get_full_name();
      end
    if (!uvm_config_db#(brt_usb_config)::get(null, scope_name, "seq_cfg", cfg )) begin
      `brt_error("body", "can not get configuration");
      end

    if (l_agent.shared_status.link_usb_20_state != brt_usb_types::ENABLED) begin
        `brt_warning ("body", "A transfer is queued while link is not ENABLE")
        wait (l_agent.shared_status.link_usb_20_state == brt_usb_types::ENABLED);
    end

    get_cfg = cfg;
    if (!$cast(pre_cfg, get_cfg))
        `brt_fatal("body", "Unable to cast");

    `brt_info("body",$sformatf("CFG = %s", pre_cfg.sprint()), UVM_LOW);

    `brt_create(req)
    start_item(req);
    req.cfg = pre_cfg;
    //req.payload.USER_DEFINED_ALGORITHM_wt = 1;
    //req.payload.TWO_SEED_BASED_ALGORITHM_wt = 0;

    create_request();   // randomize transfer
    finish_item(req);
    get_response(rsp);
    `brt_info("body", $sformatf("Transfer %s is done", ttype.name()), UVM_LOW)
  endtask
endclass : brt_usb_base_random_xfer_sequence 

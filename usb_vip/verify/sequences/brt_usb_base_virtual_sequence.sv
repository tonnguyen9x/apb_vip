class brt_usb_base_virtual_sequence extends brt_usb_virtual_sequence;
    brt_usb_dev_util_callback       dev_util_cb;
    brt_usb_host_util_callback      host_util_cb;
    brt_usb_check_packet            chk_pkt;
    brt_usb_agent_config            host_cfg;
    brt_usb_agent                   dev_agt;
    brt_usb_agent                   host_agt;
    // scoreboard
    brt_usb_mult_sb_wrapper         mult_sb;
    bit [6:0]                       dev_addr;
    bit [3:0]                       ep_num;
    bit                             dir;

    `brt_object_utils_begin(brt_usb_base_virtual_sequence)
    `brt_object_utils_end

    function new(string name="brt_usb_base_virtual_sequence");
        super.new(name);
    endfunction

    virtual task body();
        init_callback();
        host_agt = p_sequencer.agt;
        //dev_agt
        uvm_config_db#(brt_usb_agent)::get(null,"uvm_test_top.env","dev_agent",dev_agt);
        host_cfg = p_sequencer.agt.cfg;
        uvm_config_db#(brt_usb_mult_sb_wrapper)::get(null,"uvm_test_top.env","mult_sb",mult_sb);
    endtask

    virtual task init_callback();
        uvm_config_db #(brt_usb_dev_util_callback)::get (null,"uvm_test_top","dev_util_cb",dev_util_cb);
        uvm_config_db #(brt_usb_host_util_callback)::get (null,"uvm_test_top","host_util_cb",host_util_cb);
    endtask
    // DISCONNECTED, DEVICE_ATTACHED, RESETTING, ENABLED, SUSPENDED, RESUMING
    extern virtual task reset_dev(brt_usb_types::link20sm_state_e link20sm_state = brt_usb_types::DEVICE_ATTACHED);
    extern virtual task automatic bulk_in_xfer (int set_ep_num = -1, int set_payload_size = -1, int set_dev_payload_size = -1);
    extern virtual task automatic bulk_out_xfer (int set_ep_num = -1, int set_payload_size = -1, int set_dev_payload_size = -1);
    extern virtual task automatic interrupt_in_xfer (int set_ep_num = -1, int set_payload_size = -1, int set_dev_payload_size = -1);
    extern virtual task automatic interrupt_out_xfer (int set_ep_num = -1, int set_payload_size = -1, int set_dev_payload_size = -1);
    extern virtual task automatic isochronous_in_xfer (int set_ep_num = -1, int set_payload_size = -1, int set_dev_payload_size = -1);
    extern virtual task automatic isochronous_out_xfer (int set_ep_num = -1, int set_payload_size = -1, int set_dev_payload_size = -1);
    extern virtual task automatic ctrl_xfer (int set_dir = -1, int set_payload_size = -1, int set_dev_payload_size = -1);
endclass

task brt_usb_base_virtual_sequence::reset_dev(brt_usb_types::link20sm_state_e link20sm_state = brt_usb_types::DEVICE_ATTACHED);
    brt_usb_link_service_reset_sequence 			reset_seq;

    // Start
    `brt_info("RESET", $sformatf("Wait for Link enters %s state to reset device", link20sm_state.name()), UVM_LOW)
    wait (p_sequencer.link_service_sequencer.agt.shared_status.link_usb_20_state == link20sm_state);
    // Reset device
    `brt_do_on(reset_seq, p_sequencer.link_service_sequencer) 

    wait (p_sequencer.link_service_sequencer.agt.shared_status.link_usb_20_state == brt_usb_types::ENABLED);
    `brt_info("RESET", $sformatf("Reset completes. Link is ENABLE state"), UVM_LOW)
endtask:reset_dev

task brt_usb_base_virtual_sequence::bulk_in_xfer (int set_ep_num = -1, int set_payload_size = -1, int set_dev_payload_size = -1);
    brt_usb_base_bulk_in_xfer_sequence  bulk_in_seq;
    bit                                 random_done;
    fork
        begin
            bulk_in_seq = new ();
            bulk_in_seq.randomize() with {ep_num       == set_ep_num;
                                          payload_size == set_payload_size;
                                         };
            random_done = 1;
            bulk_in_seq.start (p_sequencer.xfer_sequencer);
            `brt_info(get_name(), $sformatf("Done %s transfer, EP: %d, payload_size: %d", bulk_in_seq.req.xfer_type.name(), bulk_in_seq.req.endpoint_number, bulk_in_seq.req.payload_intended_byte_count), UVM_LOW)
            // Set payload for dev
        end
        begin
            wait (random_done == 1);
            #1;
            `brt_info(get_name(), $sformatf("Run %s transfer, EP: %d, payload_size: %d", bulk_in_seq.req.xfer_type.name(), bulk_in_seq.req.endpoint_number, bulk_in_seq.req.payload_intended_byte_count), UVM_LOW)
            dev_util_cb.set_payload ( .addr      (bulk_in_seq.req.device_address)
                                     ,.epnum     (bulk_in_seq.req.endpoint_number)
                                     ,.dir       (bulk_in_seq.req.dir)
                                     ,.xfer_size (set_dev_payload_size == -1? bulk_in_seq.req.payload_intended_byte_count:set_dev_payload_size)
                                     ,.rand_en   ()    // default is random
                                     ,.indata    ());  // Use when rand_en = 0
        end
    join
endtask:bulk_in_xfer

task brt_usb_base_virtual_sequence::bulk_out_xfer (int set_ep_num = -1, int set_payload_size = -1, int set_dev_payload_size = -1);
    brt_usb_base_bulk_out_xfer_sequence  bulk_out_seq;
    bit                                  random_done;
    fork
        begin
            bulk_out_seq = new ();
            bulk_out_seq.randomize() with {ep_num       == set_ep_num;
                                           payload_size == set_payload_size;
                                         };
            random_done = 1;
            bulk_out_seq.start (p_sequencer.xfer_sequencer);
            `brt_info(get_name(), $sformatf("Done %s transfer, EP: %d, payload_size: %d", bulk_out_seq.req.xfer_type.name(), bulk_out_seq.req.endpoint_number, bulk_out_seq.req.payload_intended_byte_count), UVM_LOW)
            // Set payload for dev
        end
        begin
            wait (random_done == 1);
            #1;
            `brt_info(get_name(), $sformatf("Run %s transfer, EP: %d, payload_size: %d", bulk_out_seq.req.xfer_type.name(), bulk_out_seq.req.endpoint_number, bulk_out_seq.req.payload_intended_byte_count), UVM_LOW)
            dev_util_cb.set_payload ( .addr      (bulk_out_seq.req.device_address)
                                     ,.epnum     (bulk_out_seq.req.endpoint_number)
                                     ,.dir       (bulk_out_seq.req.dir)
                                     ,.xfer_size (bulk_out_seq.req.payload_intended_byte_count)
                                     ,.rand_en   ()    // default is random
                                     ,.indata    ());  // Use when rand_en = 0
        end
    join
endtask:bulk_out_xfer

task brt_usb_base_virtual_sequence::interrupt_in_xfer (int set_ep_num = -1, int set_payload_size = -1, int set_dev_payload_size = -1);
    brt_usb_base_interrupt_in_xfer_sequence  interrupt_in_seq;
    bit                                 random_done;
    fork
        begin
            interrupt_in_seq = new ();
            interrupt_in_seq.randomize() with {ep_num       == set_ep_num;
                                          payload_size == set_payload_size;
                                         };
            random_done = 1;
            interrupt_in_seq.start (p_sequencer.xfer_sequencer);
            `brt_info(get_name(), $sformatf("Done %s transfer, EP: %d, payload_size: %d", interrupt_in_seq.req.xfer_type.name(), interrupt_in_seq.req.endpoint_number, interrupt_in_seq.req.payload_intended_byte_count), UVM_LOW)
            // Set payload for dev
        end
        begin
            wait (random_done == 1);
            #1;
            `brt_info(get_name(), $sformatf("Run %s transfer, EP: %d, payload_size: %d", interrupt_in_seq.req.xfer_type.name(), interrupt_in_seq.req.endpoint_number, interrupt_in_seq.req.payload_intended_byte_count), UVM_LOW)
            dev_util_cb.set_payload ( .addr      (interrupt_in_seq.req.device_address)
                                     ,.epnum     (interrupt_in_seq.req.endpoint_number)
                                     ,.dir       (interrupt_in_seq.req.dir)
                                     ,.xfer_size (set_dev_payload_size == -1? interrupt_in_seq.req.payload_intended_byte_count:set_dev_payload_size)
                                     ,.rand_en   ()    // default is random
                                     ,.indata    ());  // Use when rand_en = 0
        end
    join
endtask:interrupt_in_xfer

task brt_usb_base_virtual_sequence::interrupt_out_xfer (int set_ep_num = -1, int set_payload_size = -1, int set_dev_payload_size = -1);
    brt_usb_base_interrupt_out_xfer_sequence  interrupt_out_seq;
    bit                                  random_done;
    fork
        begin
            interrupt_out_seq = new ();
            interrupt_out_seq.randomize() with {ep_num       == set_ep_num;
                                           payload_size == set_payload_size;
                                         };
            random_done = 1;
            interrupt_out_seq.start (p_sequencer.xfer_sequencer);
            `brt_info(get_name(), $sformatf("Done %s transfer, EP: %d, payload_size: %d", interrupt_out_seq.req.xfer_type.name(), interrupt_out_seq.req.endpoint_number, interrupt_out_seq.req.payload_intended_byte_count), UVM_LOW)
            // Set payload for dev
        end
        begin
            wait (random_done == 1);
            #1;
            `brt_info(get_name(), $sformatf("Run %s transfer, EP: %d, payload_size: %d", interrupt_out_seq.req.xfer_type.name(), interrupt_out_seq.req.endpoint_number, interrupt_out_seq.req.payload_intended_byte_count), UVM_LOW)
            dev_util_cb.set_payload ( .addr      (interrupt_out_seq.req.device_address)
                                     ,.epnum     (interrupt_out_seq.req.endpoint_number)
                                     ,.dir       (interrupt_out_seq.req.dir)
                                     ,.xfer_size (interrupt_out_seq.req.payload_intended_byte_count)
                                     ,.rand_en   ()    // default is random
                                     ,.indata    ());  // Use when rand_en = 0
        end
    join
endtask:interrupt_out_xfer

task brt_usb_base_virtual_sequence::isochronous_in_xfer (int set_ep_num = -1, int set_payload_size = -1, int set_dev_payload_size = -1);
    brt_usb_base_isochronous_in_xfer_sequence  isochronous_in_seq;
    bit                                 random_done;
    fork
        begin
            isochronous_in_seq = new ();
            isochronous_in_seq.randomize() with {ep_num       == set_ep_num;
                                          payload_size == set_payload_size;
                                         };
            random_done = 1;
            isochronous_in_seq.start (p_sequencer.xfer_sequencer);
            `brt_info(get_name(), $sformatf("Done %s transfer, EP: %d, payload_size: %d", isochronous_in_seq.req.xfer_type.name(), isochronous_in_seq.req.endpoint_number, isochronous_in_seq.req.payload_intended_byte_count), UVM_LOW)
            // Set payload for dev
        end
        begin
            wait (random_done == 1);
            #1;
            `brt_info(get_name(), $sformatf("Run %s transfer, EP: %d, payload_size: %d", isochronous_in_seq.req.xfer_type.name(), isochronous_in_seq.req.endpoint_number, isochronous_in_seq.req.payload_intended_byte_count), UVM_LOW)
            dev_util_cb.set_payload ( .addr      (isochronous_in_seq.req.device_address)
                                     ,.epnum     (isochronous_in_seq.req.endpoint_number)
                                     ,.dir       (isochronous_in_seq.req.dir)
                                     ,.xfer_size (set_dev_payload_size == -1? isochronous_in_seq.req.payload_intended_byte_count:set_dev_payload_size)
                                     ,.rand_en   ()    // default is random
                                     ,.indata    ());  // Use when rand_en = 0
        end
    join
endtask:isochronous_in_xfer

task brt_usb_base_virtual_sequence::isochronous_out_xfer (int set_ep_num = -1, int set_payload_size = -1, int set_dev_payload_size = -1);
    brt_usb_base_isochronous_out_xfer_sequence  isochronous_out_seq;
    bit                                  random_done;
    fork
        begin
            isochronous_out_seq = new ();
            isochronous_out_seq.randomize() with {ep_num       == set_ep_num;
                                           payload_size == set_payload_size;
                                         };
            random_done = 1;
            isochronous_out_seq.start (p_sequencer.xfer_sequencer);
            `brt_info(get_name(), $sformatf("Done %s transfer, EP: %d, payload_size: %d", isochronous_out_seq.req.xfer_type.name(), isochronous_out_seq.req.endpoint_number, isochronous_out_seq.req.payload_intended_byte_count), UVM_LOW)
            // Set payload for dev
        end
        begin
            wait (random_done == 1);
            #1;
            `brt_info(get_name(), $sformatf("Run %s transfer, EP: %d, payload_size: %d", isochronous_out_seq.req.xfer_type.name(), isochronous_out_seq.req.endpoint_number, isochronous_out_seq.req.payload_intended_byte_count), UVM_LOW)
            dev_util_cb.set_payload ( .addr      (isochronous_out_seq.req.device_address)
                                     ,.epnum     (isochronous_out_seq.req.endpoint_number)
                                     ,.dir       (isochronous_out_seq.req.dir)
                                     ,.xfer_size (isochronous_out_seq.req.payload_intended_byte_count)
                                     ,.rand_en   ()    // default is random
                                     ,.indata    ());  // Use when rand_en = 0
        end
    join
endtask:isochronous_out_xfer

task brt_usb_base_virtual_sequence::ctrl_xfer (int set_dir = -1, int set_payload_size = -1, int set_dev_payload_size = -1);
    brt_usb_base_control_xfer_sequence  ctrl_seq;
    bit                                 random_done;
    fork
        begin
            ctrl_seq = new ();
            ctrl_seq.randomize() with { 
                                        if (set_dir >=0 ) { 
                                             xfer_dir == set_dir;
                                        }
                                        if (set_payload_size >= 0) {
                                             w_length == set_payload_size;
                                        }
                                        req_type == brt_usb_types::USER_DEFINE;  // No constrain
                                      };
            random_done = 1;
            ctrl_seq.start (p_sequencer.xfer_sequencer);
            `brt_info(get_name(), $sformatf("Done %s transfer, EP: %d, payload_size: %d", ctrl_seq.req.xfer_type.name(), ctrl_seq.req.endpoint_number, ctrl_seq.req.payload_intended_byte_count), UVM_LOW)
            // Set payload for dev
        end
        begin
            wait (random_done == 1);
            #1;
            `brt_info(get_name(), $sformatf("Run %s transfer, EP: %d, payload_size: %d", ctrl_seq.req.xfer_type.name(), ctrl_seq.req.endpoint_number, ctrl_seq.req.payload_intended_byte_count), UVM_LOW)
            dev_util_cb.set_payload ( .addr      (ctrl_seq.req.device_address)
                                     ,.epnum     (ctrl_seq.req.endpoint_number)
                                     ,.dir       (0)
                                     ,.xfer_size (set_dev_payload_size == -1? ctrl_seq.req.payload_intended_byte_count:set_dev_payload_size)
                                     ,.rand_en   ()    // default is random
                                     ,.indata    ());  // Use when rand_en = 0
        end
    join
endtask:ctrl_xfer

//            // Checker
//            chk_pkt = brt_usb_check_packet::type_id::create("chk_pkt", host_util_cb);
//            chk_pkt.add_chk_pnt (
//                                  .addr          (                          ) // = 'hff
//                                 ,.epnum         (                          ) // = 'h1f
//                                 ,.dir           (                          ) // = 'b11
//                                 ,.pid           (                          ) // = brt_usb_packet::EXT
//                                 ,.data_size     (                          ) // = -1
//                                 ,.pkt_err       (                          ) // = 'b00
//                                 ,.pid_err       (                          ) // = 'b11
//                                 ,.crc5_err      (                          ) // = 'b11
//                                 ,.crc16_err     (                          ) // = 'b11
//                                 ,.bit_stuff_err (                          ) // = 'b11
//                                 );
//            host_util_cb.add_inject_err (
//                                          .addr          (  127                     ) // = 'hff
//                                         ,.epnum         (  0                       ) // = 'h1f
//                                         ,.dir           (  0                       ) // = 'b11
//                                         ,.pid           (  brt_usb_packet::DATA0   ) // = brt_usb_packet::EXT
//                                         ,.new_addr      (  17                      ) // = 'hff
//                                         ,.new_epnum     (  4                       ) // = 'h1f
//                                         ,.new_pid       (                          ) // = brt_usb_packet::EXT
//                                         ,.data_size     (                          ) // = -1
//                                         ,.pkt_err       (                          ) // = 'b00
//                                         ,.pid_err       (                          ) // = 'b11
//                                         ,.crc5_err      (                          ) // = 'b11
//                                         ,.crc16_err     (                          ) // = 'b11
//                                         ,.bit_stuff_err (                          ) // = 'b11
//                                         ,.need_timeout  (  1                       ) // = 'b11
//                                         ,.pkt_idx       (                          ) // = 'b11
//                                         );
//

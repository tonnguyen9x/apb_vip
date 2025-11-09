class brt_usb_xfer_router_sequence extends brt_sequence #(brt_usb_packet);
    brt_usb_transfer_sequencer      up_sequencer;
    brt_usb_transfer                xfer;
    bit                             xfer_exist;

    `brt_object_utils(brt_usb_xfer_router_sequence)
    `brt_declare_p_sequencer (brt_usb_packet_sequencer)

    function new (string name = "brt_usb_xfer_router_sequence");
        super.new(name);
    endfunction:new
    
    task xfer_router ();
        up_sequencer.get(xfer);
        // Find EP cfg
        xfer.find_ep_cfg (up_sequencer.agt.cfg);
        // Find sequence
        xfer_exist = 0;
        foreach (up_sequencer.agt.ulayer.x2p_seq[i]) begin
            if (up_sequencer.agt.ulayer.x2p_seq[i].ep_cfg.ep_number       == xfer.ep_cfg.ep_number &&
                up_sequencer.agt.ulayer.x2p_seq[i].ep_cfg.direction       == xfer.ep_cfg.direction
               ) begin
                up_sequencer.agt.ulayer.x2p_seq[i].xfer_q.push_back(xfer);
                xfer_exist = 1;
                break;
            end
        end

        if (!xfer_exist) begin
            `brt_fatal (get_name(),$psprintf ("Can't find destination for transfer ep: %d, d: %d",xfer.ep_cfg.ep_number,xfer.ep_cfg.direction.name() ))
        end
    endtask: xfer_router

    task host_scheduler ();
         // Wait for sof start
         @up_sequencer.shared_status.local_host_status.sof_start;
         // Check periodic transfer
         foreach (up_sequencer.agt.ulayer.x2p_seq[i]) begin
            if (up_sequencer.agt.ulayer.x2p_seq[i].xfer_q.size() > 0) begin
                if (up_sequencer.agt.ulayer.x2p_seq[i].xfer_q[0].xfer_type == brt_usb_transfer::INTERRUPT_IN_TRANSFER    ||
                    up_sequencer.agt.ulayer.x2p_seq[i].xfer_q[0].xfer_type == brt_usb_transfer::INTERRUPT_OUT_TRANSFER   ||
                    up_sequencer.agt.ulayer.x2p_seq[i].xfer_q[0].xfer_type == brt_usb_transfer::ISOCHRONOUS_IN_TRANSFER  ||
                    up_sequencer.agt.ulayer.x2p_seq[i].xfer_q[0].xfer_type == brt_usb_transfer::ISOCHRONOUS_OUT_TRANSFER 
                ) begin
                    up_sequencer.shared_status.local_host_status.periodic_ep_run[i] = 1;
                end
            end
         end

         // Enable non-periodic EP
         up_sequencer.shared_status.local_host_status.nonperiodic_ep_run = 1;         
         // End of SOF
         @up_sequencer.shared_status.local_host_status.sof_end;
         if (up_sequencer.shared_status.local_host_status.periodic_ep_run > 0) begin
            `brt_error ("EP_BW",$psprintf("Bandwidth overrun, can't service for all periodic endpoints: %b", up_sequencer.shared_status.local_host_status.periodic_ep_run))
         end
         // Disable  EP
         up_sequencer.shared_status.local_host_status.periodic_ep_run    = 32'b0;
         up_sequencer.shared_status.local_host_status.nonperiodic_ep_run = 0;         
         
         if (!up_sequencer.shared_status.local_host_status.enable_tx_sof) begin
            up_sequencer.shared_status.local_host_status.nonperiodic_ep_run = 1;         
         end
    
    endtask

    virtual task host_non_periodic ();
        @(negedge up_sequencer.shared_status.local_host_status.enable_tx_sof);
        up_sequencer.shared_status.local_host_status.nonperiodic_ep_run = 1;         
    endtask

    virtual task body ();
        fork
            forever begin
                xfer_router();
            end
            forever begin
                host_scheduler();
            end
            forever begin
                host_non_periodic();
            end
        join
    endtask

endclass: brt_usb_xfer_router_sequence


virtual class brt_usb_physical_callbacks extends uvm_callback;

  virtual function void pre_brt_usb_ss_physical_data_out_port_put(brt_usb_physical component, int chan_id, brt_usb_data data, ref bit drop);
  endfunction

  virtual function void post_brt_usb_ss_physical_data_in_port_get(brt_usb_physical component, int chan_id, brt_usb_data data, ref bit drop);
  endfunction

  function new (string name="", bit is_host=0);
  endfunction

endclass

virtual class brt_usb_link_callbacks extends uvm_callback;

  function new (string name="", bit is_host=0);
  endfunction

  virtual function void brt_usb_ss_symbol_set_out_ended(brt_usb_link component, brt_usb_symbol_set symbol_set);
  endfunction

  virtual function void pre_brt_usb_ss_tx_skp_set_transform(brt_usb_link component, brt_usb_symbol_set skp_set, ref bit drop);
  endfunction

  virtual function void pre_brt_usb_ss_rx_symbol_set_detected(brt_usb_link component, int chan_id, brt_usb_symbol_set symbol_set, ref bit drop);
  endfunction

  virtual function void pre_brt_usb_ss_tx_training_set_transform(brt_usb_link component, brt_usb_symbol_set training_set, ref bit drop);
  endfunction

  virtual function void post_brt_usb_ss_packet_in_port_get(brt_usb_link component, int chan_id, brt_usb_packet packet, ref bit drop);
  endfunction

endclass

virtual class brt_usb_protocol_callbacks extends uvm_callback;
  virtual function void pre_transfer_out_port_put (brt_usb_protocol component, int chan_id , ref brt_usb_transfer transfer , ref bit drop  );
  endfunction
  virtual function void transfer_begin(brt_usb_protocol component, brt_usb_transfer transfer);
  endfunction
  virtual function void transfer_monitor(brt_usb_protocol component, brt_usb_transfer transfer);
  endfunction
  virtual function void transfer_ended(brt_usb_protocol component, brt_usb_transfer transfer);
  endfunction
  virtual function void pre_handshake(brt_usb_protocol component, brt_usb_packet packet, ref bit mod);
  endfunction
  virtual function void pre_data_ready(brt_usb_protocol component, brt_usb_packet packet, ref bit ready, ref bit stall);
  endfunction
  virtual function void packet_trace(brt_usb_protocol component, brt_usb_transfer transfer, brt_usb_packet packet);
  endfunction
  virtual function void post_brt_usb_20_packet_in_port_get(brt_usb_protocol component, int chan_id, brt_usb_packet packet, ref bit drop);
  endfunction
  virtual function void pre_brt_usb_20_packet_out_port_put(brt_usb_protocol component, brt_usb_transfer transfer, brt_usb_packet packet, ref bit drop);
  endfunction
  virtual function void packet_monitor(brt_usb_protocol component, brt_usb_packet packet);
  endfunction

  function new (string name="", bit is_host=0);
    super.new(name);
  endfunction

endclass

// brt_usb_enumeration_callback is to keep track the brt_usb environent status and
// automatically update environment configuration when enumeration is
// happening.
class brt_usb_enumeration_callback extends brt_usb_protocol_callbacks;

  brt_usb_config cfg;
  brt_usb_config updated_cfg;
  event set_address_e;
  bit [31:0] address;

  function new(string name="brt_usb_enumeration_callback");
    super.new(name);
  endfunction

  function void enum_update(brt_usb_transfer transfer);
    brt_usb_types::setup_data_brequest_e t;

    if (transfer.get_xfer_type_val() != brt_usb_transfer::CONTROL_TRANSFER) begin
      end
    else if (!$cast(t, transfer.setup_data_brequest)) begin
      `brt_warning(get_name(), "standard device request cast failed")
      end
    else if (transfer.setup_data_brequest == brt_usb_types::SET_ADDRESS) begin
      updated_cfg.remote_device_cfg[0].device_address = transfer.get_setup_data_w_value_val();
      address = transfer.get_setup_data_w_value_val();
      `brt_info(get_name(), $sformatf("new device address %h is being assigned", updated_cfg.remote_device_cfg[0].device_address), UVM_LOW)
      ->set_address_e;
  		end
  endfunction:enum_update

  virtual function void transfer_ended(brt_usb_protocol component, brt_usb_transfer transfer);
    if (cfg != null) enum_update(transfer);
  endfunction

endclass

class brt_usb_xfer_trace_callback extends brt_usb_protocol_callbacks;
  bit is_host;

  local bit is_interface;
  local bit is_endpoint;
  UVM_FILE track_h;
  //uvm_analysis_port #(brt_usb_transfer) host_ctrl_xfer_tx_port;
  //uvm_analysis_port #(brt_usb_transfer) host_ctrl_xfer_rx_port;
  uvm_analysis_port #(brt_usb_transfer) aport_xfer_exp;
  uvm_analysis_port #(brt_usb_transfer) aport_xfer_act;

  function new(string name = "brt_usb_xfer_trace_callback", bit is_host = 0);
    super.new(name);
    this.is_host = is_host;
    if (is_host) begin
        track_h = $fopen("host_transfer_trace.trace","w");
    end
    else begin
        track_h = $fopen("device_transfer_trace.trace","w");
    end
    `uvm_info(get_name(), $sformatf("created transfer callback "), UVM_HIGH)
    aport_xfer_exp = new ($sformatf ("aport_xfer_exp%b", is_host), null);
    aport_xfer_act = new ($sformatf ("aport_xfer_act%b", is_host), null);
  endfunction

  virtual function void transfer_monitor(brt_usb_protocol component, brt_usb_transfer transfer);
    int     xfer_type;
    bit     dir;

    $cast (xfer_type, transfer.xfer_type);
    dir = xfer_type%2;

    if (xfer_type == 0) begin   // Control
        dir = transfer.setup_data_bmrequesttype[7];
    end

    if (is_host) begin
        if (!dir) begin  // OUT
            aport_xfer_exp.write (transfer);
        end
    end
    else begin  // Device
        if (dir) begin  // IN
            aport_xfer_exp.write (transfer);
        end
    end
  endfunction

  virtual function void transfer_ended(brt_usb_protocol component, brt_usb_transfer transfer);
    brt_usb_types::setup_data_brequest_e brequest_type;
    string pld;
    string s;
    bit [15:0] wvalue;
    // put to scoreboard
    int     xfer_type;
    bit     dir;

    $cast (xfer_type, transfer.xfer_type);
    dir = xfer_type%2;

    if (xfer_type == 0) begin   // Control
        dir = transfer.setup_data_bmrequesttype[7];
    end

    if (is_host) begin
        if (dir) begin  // IN
            aport_xfer_act.write (transfer);
        end
    end
    else begin  // Device
        if (!dir) begin  // OUT
            aport_xfer_act.write (transfer);
        end
    end

    // Transfer trace
    `uvm_info(get_name(), $sformatf("Transfer Ended %s %s", is_host ? "HOST":"DEVICE", transfer.sprint()), UVM_HIGH)
    //check_type(transfer);
    s = "\n";
    pld = "";
    $sformat(s, "%s  %t  Transfer Type              %s\n", s, $time, transfer.xfer_type.name());
    if (transfer.xfer_type == brt_usb_transfer::CONTROL_TRANSFER) begin
      $sformat(s, "%s    Transfer Device Address    %h\n", s, transfer.get_device_address_val());
      $sformat(s, "%s    Transfer Direction         %s\n", s, transfer.setup_data_bmrequesttype_dir.name());
      $sformat(s, "%s    Transfer Type              %s\n", s, transfer.setup_data_bmrequesttype_type.name());
      $sformat(s, "%s    Transfer Recipient         %s\n", s, transfer.setup_data_bmrequesttype_recipient.name());
      $sformat(s, "%s    Transfer wValue            %h\n", s, transfer.get_setup_data_w_value_val());
      $sformat(s, "%s    Transfer wLength           %h\n", s, transfer.get_setup_data_w_length_val());
      if (!$cast(brequest_type, transfer.get_setup_data_brequest_val())) begin
        `uvm_warning("CAST_FAILED", $sformatf("unknown brequest type"))
        end
      else
        $sformat(s, "%s    Transfer Request           %s\n", s, brequest_type.name());

      wvalue = transfer.get_setup_data_w_value_val();
      case (brequest_type)
        `include "brt_usb_control_xfer_trace.svh"
      endcase
    end  // Print information of CONTROL transfer

    foreach (transfer.payload.data[i]) begin
        if (i!=0 && i%16 == 0) begin
            $sformat(pld, "%s\n                               %h", pld, transfer.payload.data[i]);
        end
        else if (i!=0 && i%4 == 0) begin
            $sformat(pld, "%s %h", pld, transfer.payload.data[i]);
        end
        else begin
            $sformat(pld, "%s%h", pld, transfer.payload.data[i]);
        end
        // Break if payload > 100B
        if (i> 102 &&  transfer.payload.data.size() > 200) begin
            $sformat(pld, "%s ........ ", pld);
            // Print last 4B
            for (int j=4; j > 0;j--) begin
                $sformat(pld, "%s%h", pld, transfer.payload.data[transfer.payload.data.size()-j]);
            end
            break;
        end 
    end
    if (transfer.payload.data.size() == 0) begin
        pld = "None";
    end
    $sformat(s, "%s    . (payload) %5d bytes    %s\n", s, transfer.payload.data.size(), pld);
    $fdisplay(track_h, "%s", s);
    `uvm_info("TRANSFER_TRACE", $sformatf("%s ", s ), UVM_LOW)
   endfunction

endclass

class xfer_port_callback extends brt_usb_protocol_callbacks();
  bit is_host=0;
  brt_analysis_port #(brt_usb_transfer) host_xfer_port;
  function new(string name="xfer_port_callback");
    super.new(name);
  endfunction
  virtual function void transfer_ended(brt_usb_protocol component, brt_usb_transfer transfer);
    if (host_xfer_port != null) host_xfer_port.write(transfer);
  endfunction
endclass

class xfer_summary_callback extends brt_usb_protocol_callbacks();
  bit       is_host=0;
  string    summary_q[$];
  string    packet_sum_q[$];
  UVM_FILE  trace_prot;

  function new(string name="xfer_summary_callback", bit is_host);
    string  s;
    super.new(name);
    this.is_host = is_host;
    if (is_host) begin
        trace_prot = $fopen ("host_protocol_trace.trace","w");
    end
    else begin
        trace_prot = $fopen ("device_protocol_trace.trace","w");
    end
    // Header
    s = $psprintf ("|%15s|%3s|%2s|%25s|%7s|%4s|%20s|%10s|", 
                    "Time", "Add",  "Ep", "Transfer_type",  "PID",  "Size", "Packet error", "Pkt dir");
    $fdisplay (trace_prot,"%s",s);
    packet_sum_q.push_back(s);
  endfunction

  virtual function void packet_trace(brt_usb_protocol component, brt_usb_transfer transfer, brt_usb_packet packet);
    string  s;
    string  dt_s, err_s;
    string  tfer_type;

    //packet_sum_q.push_back(packet.sprint_trace());
    // Use for printing all packets to a file;
    if (transfer == null) begin
        tfer_type = "#NA";
    end
    else begin
        tfer_type = transfer.xfer_type.name();
        if (packet.pid_format[3:0] == 4'h5) begin  // SOF
            tfer_type = $sformatf("FRAME: %0d",packet.frame_num);
        end
    end

    //if (packet.pkt_err) begin
        if (packet.pid_err  )       $sformat (err_s,"%s PID_ERR",err_s);
        if (packet.crc5_err )       $sformat (err_s,"%s CRC5_ERR",err_s);
        if (packet.crc16_err)       $sformat (err_s,"%s crc16_err",err_s);
        if (packet.bit_stuff_err)   $sformat (err_s,"%s bitstuff",err_s);
        if (packet.eop_length >= 0) $sformat (err_s,"%s eop%0d",err_s, packet.eop_length);
    //end
    //else begin
    if (!packet.pkt_err) begin
        $sformat (err_s,"%s OK",err_s);
    end

    if (packet.drop) begin
        $sformat (err_s,"%s drop",err_s);
    end

    if (packet.is_timeout) begin
        err_s = "Request timeout";
    end
    if (packet.num_kj > 0) begin
        $sformat (err_s,"%s KJ:%0d",err_s,packet.num_kj);
    end
    if (packet.data_babble > 0) begin
        $sformat (err_s,"%s babble",err_s);
    end
    //           Time,Devaddr,epnum,tferType,PID,datasize,error CRC
    s = $psprintf ("|%15t|%3d|%2d|%25s|%7s|%4d|%20s|%10s|", 
                    $time, packet.func_address,  packet.endp, tfer_type,  packet.is_lpm?"LPM":packet.pid_name.name(),  packet.data.size(), err_s, packet.dir.name());

    $fdisplay (trace_prot,"%s",s);
    packet_sum_q.push_back(s);

    // Addition for data payload
    if ( 
        packet.pid_name == brt_usb_packet::DATA0 ||
        packet.pid_name == brt_usb_packet::DATA1 ||
        packet.pid_name == brt_usb_packet::DATA2 ||
        packet.pid_name == brt_usb_packet::MDATA &&
        packet.data.size() > 0
    ) begin
        s = "";
        foreach (packet.data[i]) begin
            if (i%32==0) begin
                $sformat (s,"%s\ndata %4d: ",s,i);
            end
            $sformat (s,"%s%h ",s,packet.data[i]);
        end
        $fdisplay (trace_prot,"%s",s);
    end

  endfunction

  virtual function void transfer_ended(brt_usb_protocol component, brt_usb_transfer transfer);
    summary_q.push_back(transfer.sprint_trace());
  endfunction
endclass

class xfer_feature_callback extends brt_usb_protocol_callbacks();
  brt_usb_status								shared_status;

  function new(string name="xfer_feature_callback");
    super.new(name);
  endfunction
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

  virtual function void set_halt_status(int epnum, bit dir);
    brt_usb_endpoint_status ep_status;
    
    if (epnum == 0) dir = 1'b1;  // Calib for EP0 index

    foreach(shared_status.remote_device_status[0].endpoint_status[i]) begin
      ep_status = shared_status.remote_device_status[0].endpoint_status[i];
      if ((epnum*2 + dir) == i) begin
          ep_status.ep_state = brt_usb_types::EP_HALT;
      end
    end
  endfunction

  virtual function void transfer_ended(brt_usb_protocol component, brt_usb_transfer transfer);
    brt_usb_transfer t; 
    int target_epnum;
    bit dir;
    t = transfer;
    target_epnum = t.setup_data_w_index[6:0];
    dir          = t.setup_data_w_index[7];

    if (t.xfer_type == brt_usb_transfer::CONTROL_TRANSFER && t.brequest == brt_usb_types::SET_FEATURE) begin
      if (t.setup_data_w_value[7:0] == 0) begin
        set_halt_status(target_epnum,dir); 
        `brt_info(get_name(), $psprintf("Endpoint Halt Feature (ep_num %0d) is being enabled", target_epnum ), UVM_LOW)
        end
      else if (t.setup_data_w_value[7:0] == 1) begin
        `brt_info(get_name(), "Remote Wakeup Feature is being enabled", UVM_LOW)
        end
      else if (t.setup_data_w_value[7:0] == 2) begin
        `brt_info(get_name(), "Testmode Feature is being enabled", UVM_LOW)
        end
      end
    if (t.xfer_type == brt_usb_transfer::CONTROL_TRANSFER && t.brequest == brt_usb_types::CLEAR_FEATURE) begin
      if (t.setup_data_w_value[7:0] == 0) begin
        clear_halt_status(target_epnum,dir); 
        `brt_info(get_name(), $psprintf("Endpoint Halt Feature (ep_num %0d) is being disabled", target_epnum ), UVM_LOW)
        end
      else if (t.setup_data_w_value[7:0] == 1) begin
        `brt_info(get_name(), "Remote Wakeup Feature is being disabled", UVM_LOW)
        end
      else if (t.setup_data_w_value[7:0] == 2) begin
        `brt_info(get_name(), "Testmode Feature is being disabled", UVM_LOW)
        end
      end
  endfunction
  
endclass

class brt_usb_fcov_callback extends brt_usb_protocol_callbacks;
    bit is_host;
    brt_usb_cov_wrapper       func_cov;
    // For getting coverage
    bit cov_pid_err     [bit[7+4+1-1:0]];
    bit cov_crc5_err    [bit[7+4+1-1:0]];
    bit cov_crc16_err   [bit[7+4+1-1:0]];
    bit cov_timeout_err [bit[7+4+1-1:0]];
    bit cov_nak         [bit[7+4+1-1:0]];
    bit cov_nyet        [bit[7+4+1-1:0]];
    bit cov_stall       [bit[7+4+1-1:0]];

    function new(string name = "brt_usb_fcov_callback", bit is_host = 0);
        super.new(name);
        func_cov = brt_usb_cov_wrapper::type_id::create("func_cov");
        if (is_host) begin
            func_cov.CVG_HS_VIP_U20.option.name = "CVG_HS_VIP_U20_HOST";
        end
        else begin
            func_cov.CVG_HS_VIP_U20.option.name = "CVG_HS_VIP_U20_DEV";
        end
        this.is_host = is_host;
    endfunction

    virtual function void transfer_monitor(brt_usb_protocol component, brt_usb_transfer transfer);
    endfunction

    virtual function void transfer_begin(brt_usb_protocol component, brt_usb_transfer transfer);
        bit [7+4+1-1:0]     local_idx;

        `uvm_info (get_name(),$sformatf("Host utility callback transfer is active"), UVM_LOW) 
        // Reset index
        local_idx = {transfer.device_address[6:0], transfer.endpoint_number[3:0],
                     transfer.dir == (transfer.xfer_type == brt_usb_transfer::CONTROL_TRANSFER)? 1'b0 : brt_usb_types::IN? 1'b1: 1'b0};
        cov_pid_err    [local_idx] = 'b0; 
        cov_crc5_err   [local_idx] = 'b0; 
        cov_crc16_err  [local_idx] = 'b0; 
        cov_timeout_err[local_idx] = 'b0; 
        cov_nak        [local_idx] = 'b0;
        cov_nyet       [local_idx] = 'b0;
        cov_stall      [local_idx] = 'b0;
    endfunction

    virtual function void transfer_ended(brt_usb_protocol component, brt_usb_transfer transfer);
        bit [7+4+1-1:0]     local_idx;
        logic               pkt_err = 'hz;
        logic               pid_err = 'hz;
        logic               crc5_err = 'hz;
        logic               crc16_err = 'hz;
        logic               timeout_err = 'hz;
        brt_usb_packet::pid_name_e pkt_pid_e = brt_usb_packet::EXT;
        //brt_usb_types::packet_err_e pkt_err_e = brt_usb_types::RESERVE_ERR;
        brt_usb_types::packet_err_e pkt_err_e[$];

        // Get coverage
        local_idx = {transfer.device_address[6:0], transfer.endpoint_number[3:0],
                     transfer.dir == (transfer.xfer_type == brt_usb_transfer::CONTROL_TRANSFER)? 1'b0 : brt_usb_types::IN? 1'b1: 1'b0};
        pid_err     = cov_pid_err    [local_idx];
        crc5_err    = cov_crc5_err   [local_idx];
        crc16_err   = cov_crc16_err  [local_idx];
        timeout_err = cov_timeout_err[local_idx];

        if (pid_err)                pkt_err_e.push_back(brt_usb_types::PID_ERR);
        if (crc5_err)               pkt_err_e.push_back(brt_usb_types::CRC5_ERR);
        if (timeout_err)            pkt_err_e.push_back(brt_usb_types::TIMEOUT_ERR);
        if (crc16_err)              pkt_err_e.push_back(brt_usb_types::CRC16_ERR);
        if (pkt_err_e.size() == 0)  pkt_err_e.push_back(brt_usb_types::RESERVE_ERR);

        foreach (pkt_err_e[i]) begin
            `brt_info ("VIPCOV", $sformatf("pkt_err %s", pkt_err_e[i]), UVM_LOW)
            if (cov_stall[local_idx] === 1'b1 && (!is_host || transfer.tfer_status == brt_usb_types::ABORTED)) begin
                func_cov.u20_cov_sample (
                             .dev_addr    ( transfer.device_address         )                         
                            ,.dev_speed_e ( component.cfg.speed             )                            
                            ,.max_pkt_size( transfer.ep_cfg.max_packet_size )                             
                            ,.xfer_type_e ( transfer.xfer_type              )                            
                            ,.xfer_size   ( transfer.payload.data.size()    )                          
                            ,.burst_size  ( transfer.ep_cfg.max_burst_size  )                           
                            ,.pkt_size    (              )                         
                            ,.pkt_pid_e   ( brt_usb_packet::STALL           )                          
                            ,.pkt_err_e   ( pkt_err_e[i]              )                        
                            );
            end

            if  (cov_nyet[local_idx] === 1'b1 && transfer.tfer_status == brt_usb_types::ACCEPT) begin
                func_cov.u20_cov_sample (
                             .dev_addr    ( transfer.device_address         )                         
                            ,.dev_speed_e ( component.cfg.speed             )                            
                            ,.max_pkt_size( transfer.ep_cfg.max_packet_size )                             
                            ,.xfer_type_e ( transfer.xfer_type              )                            
                            ,.xfer_size   ( transfer.payload.data.size()    )                          
                            ,.burst_size  ( transfer.ep_cfg.max_burst_size  )                           
                            ,.pkt_size    (              )                         
                            ,.pkt_pid_e   ( brt_usb_packet::NYET            )                          
                            ,.pkt_err_e   ( pkt_err_e[i]                      )                        
                            );
            end

            if  (cov_nak[local_idx] === 1'b1  && transfer.tfer_status == brt_usb_types::ACCEPT) begin
                func_cov.u20_cov_sample (
                             .dev_addr    ( transfer.device_address         )                         
                            ,.dev_speed_e ( component.cfg.speed             )                            
                            ,.max_pkt_size( transfer.ep_cfg.max_packet_size )                             
                            ,.xfer_type_e ( transfer.xfer_type              )                            
                            ,.xfer_size   ( transfer.payload.data.size()    )                          
                            ,.burst_size  ( transfer.ep_cfg.max_burst_size  )                           
                            ,.pkt_size    (              )                         
                            ,.pkt_pid_e   ( brt_usb_packet::NAK             )                          
                            ,.pkt_err_e   ( pkt_err_e[i]              )                        
                            );
            end

            if (cov_stall[local_idx] !== 1'b1 &&
                cov_nyet[local_idx]  !== 1'b1 &&
                cov_nak[local_idx]   !== 1'b1 &&
                transfer.tfer_status == brt_usb_types::ACCEPT) begin
                func_cov.u20_cov_sample (
                             .dev_addr    ( transfer.device_address         )                         
                            ,.dev_speed_e ( component.cfg.speed             )                            
                            ,.max_pkt_size( transfer.ep_cfg.max_packet_size )                             
                            ,.xfer_type_e ( transfer.xfer_type              )                            
                            ,.xfer_size   ( transfer.payload.data.size()    )                          
                            ,.burst_size  ( transfer.ep_cfg.max_burst_size  )                           
                            ,.pkt_size    (              )                         
                            ,.pkt_pid_e   ( pkt_pid_e               )                          
                            ,.pkt_err_e   ( pkt_err_e[i]              )                        
                            );
            end
            // Iso error injection
            if (transfer.xfer_type == brt_usb_transfer::ISOCHRONOUS_IN_TRANSFER) begin
                func_cov.u20_cov_sample (
                             .dev_addr    ( transfer.device_address         )                         
                            ,.dev_speed_e ( component.cfg.speed             )                            
                            ,.max_pkt_size(  )                             
                            ,.xfer_type_e ( transfer.xfer_type              )                            
                            ,.xfer_size   (                                 )                          
                            ,.burst_size  (                                 )                           
                            ,.pkt_size    (              )                         
                            ,.pkt_pid_e   ( pkt_pid_e               )                          
                            ,.pkt_err_e   ( pkt_err_e[i]              )                        
                            );
            end

        end // foreach

    endfunction

    virtual function void packet_trace(brt_usb_protocol component, brt_usb_transfer transfer, brt_usb_packet packet);
        bit [7+4+1-1:0]     local_idx;
        brt_usb_packet packet_clone;

        $cast (packet_clone, packet.clone());
        packet_clone.pkt_err = packet_clone.chk_err (.ignore_err(1));
        // Get coverage
        if (transfer == null || packet_clone.is_timeout ||
            (transfer.xfer_type == brt_usb_transfer::CONTROL_TRANSFER && transfer.control_xfer_state == brt_usb_transfer::SETUP_STATE) ||
            (transfer.xfer_type == brt_usb_transfer::CONTROL_TRANSFER && transfer.control_xfer_state == brt_usb_transfer::STATUS_STATE) 
        ) begin
            return;
        end
        local_idx = {transfer.device_address[6:0], transfer.endpoint_number[3:0], 
                     transfer.dir == (transfer.xfer_type == brt_usb_transfer::CONTROL_TRANSFER)? 1'b0 : brt_usb_types::IN? 1'b1: 1'b0};
        cov_pid_err    [local_idx] |= packet_clone.pid_err;
        if (packet_clone.pid_err) `brt_info ("PID_ERR", $sformatf ("idx: %b", local_idx), UVM_LOW)
        if (packet_clone.pid_name == brt_usb_packet::OUT ||
            packet_clone.pid_name == brt_usb_packet::IN ||
            packet_clone.pid_name == brt_usb_packet::PING ||
            packet_clone.pid_name == brt_usb_packet::SETUP   
        ) begin
            cov_crc5_err   [local_idx] |= packet_clone.crc5_err;
        end

        if (packet_clone.pid_name == brt_usb_packet::DATA0 ||
            packet_clone.pid_name == brt_usb_packet::DATA1 ||
            packet_clone.pid_name == brt_usb_packet::DATA2 ||
            packet_clone.pid_name == brt_usb_packet::MDATA   
           ) begin
            cov_crc16_err  [local_idx] |= packet_clone.crc16_err;
        end

        if (
            packet_clone.pid_name == brt_usb_packet::DATA0 ||
            packet_clone.pid_name == brt_usb_packet::DATA1   
        ) begin
            cov_timeout_err[local_idx] |= packet_clone.drop;
        end
        else if (packet_clone.pid_name == brt_usb_packet::ACK) begin
            cov_timeout_err[local_idx] |= packet_clone.drop;
        end

        if (!packet_clone.pkt_err) begin
            cov_nak  [local_idx] |= packet_clone.pid_name == brt_usb_packet::NAK;
            cov_nyet [local_idx] |= packet_clone.pid_name == brt_usb_packet::NYET;
            cov_stall[local_idx] |= packet_clone.pid_name == brt_usb_packet::STALL;
        end

        // Sample for data packet
        if (packet_clone.pid_name == brt_usb_packet::DATA0 ||
            packet_clone.pid_name == brt_usb_packet::DATA1 ||
            packet_clone.pid_name == brt_usb_packet::DATA2 ||
            packet_clone.pid_name == brt_usb_packet::MDATA   
           ) begin
            if (transfer.xfer_type != brt_usb_transfer::CONTROL_TRANSFER ||
               (transfer.xfer_type == brt_usb_transfer::CONTROL_TRANSFER && transfer.control_xfer_state == brt_usb_transfer::DATA_STATE)
               ) begin
                `brt_info ("PKT_COV", $sformatf ("pkt_size: %d %s",  packet_clone.data.size(), transfer.control_xfer_state), UVM_LOW)
                func_cov.u20_cov_sample (
                             .dev_addr    (          )                         
                            ,.dev_speed_e ( component.cfg.speed             )                            
                            ,.max_pkt_size(  )                             
                            ,.xfer_type_e ( transfer.xfer_type              )                            
                            ,.xfer_size   (     )                          
                            ,.burst_size  (   )                           
                            ,.pkt_size    ( packet_clone.data.size()        )                         
                            ,.pkt_pid_e   (                                 )
                            ,.pkt_err_e   (                                 )
                            );
            end
        end
    endfunction

endclass

class brt_usb_perf_callback extends brt_usb_protocol_callbacks();
    typedef enum {START, DATA, ACK, NEXT} perf_state;

    brt_usb_config          cfg;
    perf_state              perf_state_e;
    time                    start_t;
    time                    stop_t;
    int                     total_data_size;
    int                     last_data_size;
    real                    perf_speed;

    function new(string name="brt_usb_perf_callback", brt_usb_config cfg);
      super.new(name);
      this.cfg = cfg;
      perf_state_e = START;
    endfunction
    
    virtual function void packet_monitor(brt_usb_protocol component, brt_usb_packet packet);
        if (!cfg.perf_chk_en) begin
            return;
        end

        case (perf_state_e)
            START: begin
                if (packet.pid_format[3:0] == brt_usb_packet::IN ||
                    packet.pid_format[3:0] == brt_usb_packet::OUT ) begin
                    if (packet.endp > 0) begin
                        start_t = $time;
                        perf_state_e = DATA;
                        last_data_size = 0;
                    end
                end
            end
            DATA: begin
                if (packet.pid_format[3:0] == brt_usb_packet::DATA0 ||
                    packet.pid_format[3:0] == brt_usb_packet::DATA1 ||
                    packet.pid_format[3:0] == brt_usb_packet::DATA2 ||
                    packet.pid_format[3:0] == brt_usb_packet::MDATA
                    ) begin
                    last_data_size = packet.data.size();
                    if (cfg.perf_ignore_ack) begin
                        perf_state_e = NEXT;
                        stop_t = $time;
                        total_data_size += last_data_size;
                        `brt_info ("PERF_CHK", $sformatf("Start: %t, stop: %t, data size: %t", start_t, stop_t, total_data_size), UVM_HIGH)
                    end
                    else begin
                        perf_state_e = ACK;
                    end
                end
                else begin
                    perf_state_e = NEXT;
                end
            end
            ACK: begin
                if (packet.pid_format[3:0] == brt_usb_packet::IN ||
                    packet.pid_format[3:0] == brt_usb_packet::OUT ) begin
                    if (packet.endp > 0) begin
                        perf_state_e = DATA;
                        last_data_size = 0;
                    end
                end
                // ACK
                else if (packet.pid_format[3:0] == brt_usb_packet::ACK ||
                         packet.pid_format[3:0] == brt_usb_packet::NYET) begin
                    perf_state_e = NEXT;
                    stop_t = $time;
                    total_data_size += last_data_size;
                    `brt_info ("PERF_CHK", $sformatf("Start: %t, stop: %t, data size: %t", start_t, stop_t, total_data_size), UVM_HIGH)
                end
                else begin
                    perf_state_e = NEXT;
                end
            end
            NEXT: begin
                if (packet.pid_format[3:0] == brt_usb_packet::IN ||
                    packet.pid_format[3:0] == brt_usb_packet::OUT ) begin
                    if (packet.endp > 0) begin
                        perf_state_e = DATA;
                        last_data_size = 0;
                    end
                end
            end
            default: begin
                `brt_fatal ("PERF_CHK","Performance checking. Not enter this state")
            end
        endcase
    endfunction
    
    virtual function cal_perf();
        perf_speed = total_data_size * 1s / (stop_t - start_t);
    endfunction

endclass

class brt_usb_timing_callback extends brt_usb_protocol_callbacks();
    typedef enum {TOKEN, DATAIN, DATAOUT, ACKIN, ACKOUT} trans_state;

    brt_usb_cov_wrapper     func_cov;
    brt_usb_config          cfg;
    trans_state             trans_state_e;
    time                    in_tkn_t;
    time                    in_data_start_t;
    time                    in_data_end_t;
    time                    in_ack_t;
    time                    out_tkn_t;
    time                    out_data_t;
    time                    out_data_start_t;
    time                    out_data_end_t;
    time                    out_ack_t;
    
    time                    eop_t;
    function new(string name="brt_usb_timing_callback", brt_usb_config cfg);
        super.new(name);
        this.cfg = cfg;
        trans_state_e = TOKEN;
        func_cov = brt_usb_cov_wrapper::type_id::create("func_cov");
    endfunction
    
    virtual function void packet_monitor(brt_usb_protocol component, brt_usb_packet packet);
        if      (cfg.speed == brt_usb_types::HS) eop_t = 0;
        else if (cfg.speed == brt_usb_types::FS) eop_t = 1.5 * 83333;
        else if (cfg.speed == brt_usb_types::LS) eop_t = 1.4 * 666666;

        case (trans_state_e)
            TOKEN: begin
                if (packet.pid_format[3:0] == brt_usb_packet::IN) begin
                    in_tkn_t = $time + eop_t;
                    trans_state_e = DATAIN;
                end
                else if(packet.pid_format[3:0] == brt_usb_packet::OUT ||
                        packet.pid_format[3:0] == brt_usb_packet::SETUP
                       ) begin
                    out_tkn_t = $time + eop_t;
                    trans_state_e = DATAOUT;
                end
            end
            DATAIN: begin
                if (packet.pid_format[3:0] == brt_usb_packet::DATA0 ||
                    packet.pid_format[3:0] == brt_usb_packet::DATA1 ||
                    packet.pid_format[3:0] == brt_usb_packet::DATA2 ||
                    packet.pid_format[3:0] == brt_usb_packet::MDATA
                    ) begin
                    in_data_start_t = packet.pkt_start_t;
                    in_data_end_t  = $time + eop_t;
                    get_cov(
                             .in_tkn_to_data ( in_data_start_t - in_tkn_t)
                            ,.in_data_to_ack (              )
                            ,.out_tkn_to_data(              )
                            ,.out_data_to_ack(              )
                            ,.speed          ( cfg.speed    )
                            );
                    trans_state_e = ACKIN;
                end
                else begin
                    trans_state_e = TOKEN;
                end
            end
            DATAOUT: begin
                if (packet.pid_format[3:0] == brt_usb_packet::DATA0 ||
                    packet.pid_format[3:0] == brt_usb_packet::DATA1 ||
                    packet.pid_format[3:0] == brt_usb_packet::DATA2 ||
                    packet.pid_format[3:0] == brt_usb_packet::MDATA
                    ) begin
                    out_data_start_t = packet.pkt_start_t;
                    out_data_end_t = $time + eop_t;
                    get_cov(
                             .in_tkn_to_data (              )
                            ,.in_data_to_ack (              )
                            ,.out_tkn_to_data( out_data_start_t - out_tkn_t )
                            ,.out_data_to_ack(              )
                            ,.speed          ( cfg.speed    )
                            );
                    trans_state_e = ACKOUT;
                end
                else begin
                    trans_state_e = TOKEN;
                end
            end
            ACKIN: begin
                if (packet.pid_format[3:0] == brt_usb_packet::IN) begin
                    in_tkn_t = $time + eop_t;
                    trans_state_e = DATAIN;
                end
                else if(packet.pid_format[3:0] == brt_usb_packet::OUT ||
                        packet.pid_format[3:0] == brt_usb_packet::SETUP
                       ) begin
                    out_tkn_t = $time + eop_t;
                    trans_state_e = DATAOUT;
                end
                // ACK
                else if (packet.pid_format[3:0] == brt_usb_packet::ACK ||
                         packet.pid_format[3:0] == brt_usb_packet::NYET ||
                         packet.pid_format[3:0] == brt_usb_packet::NAK
                     ) begin
                    in_ack_t = packet.pkt_start_t;
                    get_cov(
                             .in_tkn_to_data (              )
                            ,.in_data_to_ack ( in_ack_t - in_data_end_t )
                            ,.out_tkn_to_data(              )
                            ,.out_data_to_ack(              )
                            ,.speed          ( cfg.speed    )
                            );
                    trans_state_e = TOKEN;
                end
                else begin
                    trans_state_e = TOKEN;
                end
            end
            ACKOUT: begin
                if (packet.pid_format[3:0] == brt_usb_packet::IN) begin
                    in_tkn_t = $time + eop_t;
                    trans_state_e = DATAIN;
                end
                else if(packet.pid_format[3:0] == brt_usb_packet::OUT ||
                        packet.pid_format[3:0] == brt_usb_packet::SETUP
                       ) begin
                    out_tkn_t = $time + eop_t;
                    trans_state_e = DATAOUT;
                end
                // ACK
                else if (packet.pid_format[3:0] == brt_usb_packet::ACK ||
                         packet.pid_format[3:0] == brt_usb_packet::NYET ||
                         packet.pid_format[3:0] == brt_usb_packet::NAK
                     ) begin
                    out_ack_t = packet.pkt_start_t;
                    get_cov(
                             .in_tkn_to_data (              )
                            ,.in_data_to_ack (              )
                            ,.out_tkn_to_data(              )
                            ,.out_data_to_ack( out_ack_t - out_data_end_t)
                            ,.speed          ( cfg.speed    )
                            );
                    trans_state_e = TOKEN;
                end
                else begin
                    trans_state_e = TOKEN;
                end
            end
            default: begin
                `brt_fatal ("TIMING_COV","Timing coverage. Not enter this state")
            end
        endcase
    endfunction
   
    virtual function get_cov(
                             int in_tkn_to_data = -1
                            ,int in_data_to_ack = -1
                            ,int out_tkn_to_data = -1
                            ,int out_data_to_ack = -1
                            ,brt_usb_types::speed_e speed
                            );

        if (in_tkn_to_data  != -1) begin   
            in_tkn_to_data = in_tkn_to_data/1ns;
            `brt_info ("TIMING_COV", $sformatf("in_tkn_to_data: %t ns", in_tkn_to_data), UVM_HIGH)
        end

        if (in_data_to_ack   != -1) begin   
            in_data_to_ack = in_data_to_ack/1ns;
            `brt_info ("TIMING_COV", $sformatf("in_data_to_ack: %t ns", in_data_to_ack), UVM_HIGH)
        end
   
        if (out_tkn_to_data  != -1) begin   
            out_tkn_to_data = out_tkn_to_data/1ns;
            `brt_info ("TIMING_COV", $sformatf("out_tkn_to_data: %t ns", out_tkn_to_data), UVM_HIGH)
        end
 
        if (out_data_to_ack  != -1) begin   
            out_data_to_ack = out_data_to_ack/1ns;
            `brt_info ("TIMING_COV", $sformatf("out_data_to_ack: %t ns", out_data_to_ack), UVM_HIGH)
        end

        if (speed == brt_usb_types::HS) begin
            func_cov.u20_cov_timing_sample (
                                             .hs_in_tkn_to_data (in_tkn_to_data )
                                            ,.hs_in_data_to_ack (in_data_to_ack )
                                            ,.hs_out_tkn_to_data(out_tkn_to_data)
                                            ,.hs_out_data_to_ack(out_data_to_ack)
                        );
        end
        else if (speed == brt_usb_types::FS) begin
            func_cov.u20_cov_timing_sample (
                                             .fs_in_tkn_to_data (in_tkn_to_data )
                                            ,.fs_in_data_to_ack (in_data_to_ack )
                                            ,.fs_out_tkn_to_data(out_tkn_to_data)
                                            ,.fs_out_data_to_ack(out_data_to_ack)
                        );
        end
        else if (speed == brt_usb_types::LS) begin
            func_cov.u20_cov_timing_sample (
                                             .ls_in_tkn_to_data (in_tkn_to_data )
                                            ,.ls_in_data_to_ack (in_data_to_ack )
                                            ,.ls_out_tkn_to_data(out_tkn_to_data)
                                            ,.ls_out_data_to_ack(out_data_to_ack)
                        );
        end
        else begin
            `brt_fatal ("TIMING_COV","Timing coverage. Not enter this state")
        end
    endfunction
endclass
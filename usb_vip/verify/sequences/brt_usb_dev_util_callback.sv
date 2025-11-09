class brt_usb_dev_util_callback extends brt_usb_protocol_callbacks;

    `uvm_object_utils (brt_usb_dev_util_callback)

    typedef struct {
        int      payload_size;
        bit[7:0] payload_data[];
    } ep_payload_st;

    ep_payload_st ep_payload[bit[7+4+1-1:0]][$];
    bit[7:0]     data8[];

    brt_usb_check_packet        chk_pkt_array[$];
    brt_usb_check_point         inject_err_array[$];
    int                         added_chk_pnt;
    int                         injected_err;
    int                         pkt_idx[bit [7+4+1-1:0]];
    bit [7+4+1-1:0]             idx;
    bit [6:0]                   cur_addr;
    bit [3:0]                   cur_epnum;
    bit                         cur_dir;

    function new(string name = "usr_dev_callback");
        super.new(name);
    endfunction

    virtual function void transfer_begin(brt_usb_protocol component, brt_usb_transfer transfer);
        bit[7+4+1-1:0]  idx;
        bit [6:0]       addr;
        bit [3:0]       epnum;
        bit             dir;
        ep_payload_st   ep_payload_xfer;
        bit             need_data_payload;

        $cast(dir,transfer.ep_cfg.direction);
        epnum = transfer.endpoint_number;
        addr   = transfer.device_address;
        // idx
        idx = {addr,epnum,dir};        
        
        `uvm_info (get_name(),$sformatf("Device starts new transfer with addr: %d, epnum: %d, dir: %d, idx: %b", addr, epnum, dir, idx), UVM_HIGH) 
        if (ep_payload[idx].size() > 0) begin
            ep_payload_xfer = ep_payload[idx].pop_front();
            transfer.payload_intended_byte_count = ep_payload_xfer.payload_size;
            transfer.payload.byte_count          = ep_payload_xfer.payload_size;
            if (transfer.endpoint_number == 0) begin
                need_data_payload = transfer.setup_data_bmrequesttype[7]; // read
            end
            else begin
                need_data_payload = dir; //IN
            end

            if (need_data_payload) begin
                transfer.payload.data = new[ep_payload_xfer.payload_size];
                foreach (transfer.payload.data[i]) begin
                    transfer.payload.data[i] = ep_payload_xfer.payload_data[i];
                end
            end
            `uvm_info (get_name(),$sformatf("User changes addr: %d, epnum: %d, dir: %d, idx: %b with payload: %d", addr, epnum, dir, idx, ep_payload_xfer.payload_size), UVM_LOW) 
        end
    endfunction

    function set_payload ( bit [6:0] addr
                          ,bit [3:0] epnum
                          ,bit       dir 
                          ,int       xfer_size
                          ,bit       rand_en = 1
                          ,bit[7:0]  indata[] = {});
        ep_payload_st   tmp;

        bit[7+4+1-1:0]  idx;
        idx = {addr,epnum,dir};

        tmp.payload_size = xfer_size;
        if (xfer_size >0) begin
            gen_data_patten();  // gen data8
            tmp.payload_data = new[xfer_size];
            if (rand_en) begin
                foreach (tmp.payload_data[i]) begin
                    tmp.payload_data[i] = $urandom_range (0,255);
                end
            end
            else begin
                if (indata.size > 0) begin
                    foreach (tmp.payload_data[i]) begin
                        tmp.payload_data[i] = indata[i];
                    end
                end
                else begin
                    foreach (tmp.payload_data[i]) begin
                        tmp.payload_data[i] = data8[i%tmp.payload_data.size()];
                    end
                end
            end
        end
        ep_payload[idx].push_back(tmp);
    endfunction

    virtual function gen_data_patten ();
        static bit  done;
        if (!done) begin
            data8 = new [`DATA8_SIZE];
            for (int i=0; i < `DATA8_SIZE/2; i++) begin
                data8[2*i]   = i/256;
                data8[2*i+1] = i%256;
            end
            done = 1;
        end
    endfunction:gen_data_patten

    // Get index from monitor
    virtual function void packet_monitor (brt_usb_protocol component, brt_usb_packet packet);
        brt_usb_check_packet    chk_pkt;
        brt_usb_check_point     chk_pnt;
        brt_usb_packet          pkt_clone;
        bit                     mtch_des;  // match destination
        bit                     pass;

        // Get address base on TOKEN
        if (!packet.pkt_err &&
             (packet.pid_format[3:0] == brt_usb_packet::IN ||
             packet.pid_format[3:0] == brt_usb_packet::OUT ||
             packet.pid_format[3:0] == brt_usb_packet::PING ||
             packet.pid_format[3:0] == brt_usb_packet::SETUP ||
             packet.pid_format[3:0] == brt_usb_packet::EXT)
           ) begin
            cur_addr = packet.func_address;
            cur_epnum = packet.endp;
            if (cur_epnum == 0) begin
                cur_dir = 0;
            end 
            else begin
                cur_dir = (packet.pid_format[3:0] == brt_usb_packet::IN);
            end
            idx = {cur_addr, cur_epnum, cur_dir};
            pkt_idx[idx] ++;
        end

        $cast (pkt_clone, packet.clone());
        `uvm_info (get_name(),$sformatf("Device utility callback packet is active"), UVM_LOW) 

        foreach (chk_pkt_array[i]) begin
            chk_pkt = chk_pkt_array[i];
            pass = 1;
            if (chk_pkt.chk_pnt_array.size() > 0) begin
                chk_pnt = chk_pkt.chk_pnt_array[0];
                mtch_des = 1;
                //mtch_des = mtch_des && (chk_pnt.addr == 'hff || chk_pnt.addr == pkt_clone.func_address);
                //mtch_des = mtch_des && (chk_pnt.epnum == 'h1f || chk_pnt.epnum == pkt_clone.endp);
                mtch_des = mtch_des && (chk_pnt.addr  == 'hff || chk_pnt.addr  == cur_addr);
                mtch_des = mtch_des && (chk_pnt.epnum == 'h1f || chk_pnt.epnum == cur_epnum);
                mtch_des = mtch_des && (chk_pnt.dir   == 'h3  || chk_pnt.dir   == cur_dir);
                mtch_des = mtch_des && (chk_pnt.pid   == brt_usb_packet::EXT || chk_pnt.pid == pkt_clone.pid_format[3:0]);

                if (!mtch_des) continue;
                // PID
                //if (chk_pnt.pid != brt_usb_packet::EXT) begin
                //    $cast (pkt_clone.pid_name, pkt_clone.pid_format[3:0]);
                //    if (chk_pnt.pid == pkt_clone.pid_name) begin
                //        `brt_error ("PKT_CHEKER",$sformatf ("packet ID is not correct. Exp: %s, real: %s",chk_pnt.pid.name(),pkt_clone.pid_name.name()))
                //    end
                //end
                // Data size
                if (chk_pnt.data_size != -1) begin
                    if (chk_pnt.data_size != pkt_clone.data.size()) begin
                        pass = 0;
                        `brt_error ("PKT_CHEKER",$sformatf ("data sieze is not correct. Exp: %d, real: %d",chk_pnt.data_size, pkt_clone.data.size()))
                    end
                end
                // pkt_err
                if (chk_pnt.pkt_err != 'b11) begin
                    if (chk_pnt.pkt_err != pkt_clone.pkt_err) begin
                        pass = 0;
                        `brt_error ("PKT_CHEKER",$sformatf ("pkt_err is not correct. Exp: %d, real: %d",chk_pnt.pkt_err, pkt_clone.pkt_err))
                    end
                end
                // pid_err
                if (chk_pnt.pid_err != 'b11) begin
                    if (chk_pnt.pid_err != pkt_clone.pid_err) begin
                        pass = 0;
                        `brt_error ("PKT_CHEKER",$sformatf ("pid_err is not correct. Exp: %d, real: %d",chk_pnt.pid_err, pkt_clone.pid_err))
                    end
                end
                // crc5_err
                if (chk_pnt.crc5_err != 'b11) begin
                    if (chk_pnt.crc5_err != pkt_clone.crc5_err) begin
                        pass = 0;
                        `brt_error ("PKT_CHEKER",$sformatf ("crc5_err is not correct. Exp: %d, real: %d",chk_pnt.crc5_err, pkt_clone.crc5_err))
                    end
                end
                // crc16_err
                if (chk_pnt.crc16_err != 'b11) begin
                    if (chk_pnt.crc16_err != pkt_clone.crc16_err) begin
                        pass = 0;
                        `brt_error ("PKT_CHEKER",$sformatf ("crc16_err is not correct. Exp: %d, real: %d",chk_pnt.crc16_err, pkt_clone.crc16_err))
                    end
                end
                // bit_stuff_err
                if (chk_pnt.bit_stuff_err != 'b11) begin
                    if (chk_pnt.bit_stuff_err != pkt_clone.bit_stuff_err) begin
                        pass = 0;
                        `brt_error ("PKT_CHEKER",$sformatf ("bit_stuff_err is not correct. Exp: %d, real: %d",chk_pnt.bit_stuff_err, pkt_clone.bit_stuff_err))
                    end
                end

                if (pass)
                    `brt_info  ("PKT_CHEKER",$sformatf ("Packet has passed the checker"), UVM_LOW)
                else
                    `brt_error ("PKT_CHEKER",$sformatf ("Packet has not passed the checker"))
                // packet info
                chk_pnt.print();
                chk_pkt.chk_pnt_array.delete(0);
            end  // Check point
        end  // foeach chk_pkt
    endfunction


    // Error injection
    virtual function void pre_brt_usb_20_packet_out_port_put(brt_usb_protocol component, brt_usb_transfer transfer, brt_usb_packet packet, ref bit drop);
        brt_usb_check_point     chk_pnt;
        bit                     mtch_des;  // match destination
        int                     need_del[$];

        `brt_info ("DEBUG", $sformatf ("Receive a packet \n%s", packet.sprint()), UVM_HIGH)
        
        foreach (inject_err_array[i]) begin
            chk_pnt = inject_err_array[i];
            mtch_des = 1;
            //mtch_des = mtch_des && (chk_pnt.addr == 'hff || chk_pnt.addr == pkt_clone.func_address);
            //mtch_des = mtch_des && (chk_pnt.epnum == 'h1f || chk_pnt.epnum == pkt_clone.endp);
            `brt_info ("",$sformatf ("cur_addr: %d, cur_epnum: %d, cur_dir: %d", cur_addr, cur_epnum, cur_dir), UVM_HIGH)
            mtch_des = mtch_des && (chk_pnt.addr  == 'hff || chk_pnt.addr  == cur_addr);
            mtch_des = mtch_des && (chk_pnt.epnum == 'h1f || chk_pnt.epnum == cur_epnum);
            mtch_des = mtch_des && (chk_pnt.dir   == 'h3  || chk_pnt.dir   == cur_dir);
            mtch_des = mtch_des && (chk_pnt.pid   == brt_usb_packet::EXT || chk_pnt.pid == packet.pid_format[3:0]);
            mtch_des = mtch_des && (chk_pnt.pkt_idx == -1 || chk_pnt.pkt_idx == pkt_idx[idx]);
            // LPM
            mtch_des = mtch_des && (chk_pnt.ext_pkt == 'h3  || 
                                    chk_pnt.ext_pkt == 'h1 && packet.pid_format[3:0] == brt_usb_packet::EXT && transfer.xfer_type == brt_usb_transfer::LPM_TRANSFER);
            mtch_des = mtch_des && (chk_pnt.lpm_pkt == 'h3  || 
                                    chk_pnt.lpm_pkt == 'h1 && packet.pid_format[3:0] == `SUBLPM && transfer.xfer_type == brt_usb_transfer::LPM_TRANSFER);
            mtch_des = mtch_des && (chk_pnt.ack_pkt == 'h3  || 
                                    chk_pnt.ack_pkt == 'h1 && packet.pid_format[3:0] == brt_usb_packet::ACK && transfer.xfer_type == brt_usb_transfer::LPM_TRANSFER);

            if (!mtch_des) continue;
            // PID
            //if (chk_pnt.pid != brt_usb_packet::EXT) begin
            //    $cast (pkt_clone.pid_name, pkt_clone.pid_format[3:0]);
            //    if (chk_pnt.pid == pkt_clone.pid_name) begin
            //        `brt_error ("PKT_CHEKER",$sformatf ("packet ID is not correct. Exp: %s, real: %s",chk_pnt.pid.name(),pkt_clone.pid_name.name()))
            //    end
            //end
            // Change destination
            if (chk_pnt.new_pid != brt_usb_packet::EXT) begin
                `brt_info ("INJEC_ERR", $sformatf ("New PID has changed. Old: %s, new: %s",packet.pid_name.name(), chk_pnt.new_pid.name()), UVM_LOW)
                packet.pid_name = chk_pnt.new_pid;
                $cast (packet.pid_format[3:0],chk_pnt.new_pid);
                packet.pid_format[7:4] = ~ packet.pid_format[3:0];
                packet.gen_token_crc5();
                //packet.need_rsp = 0;
            end
            if (chk_pnt.new_addr != 'hff) begin
                `brt_info ("INJEC_ERR", $sformatf ("New address has changed. Old: %d, new: %d",packet.func_address, chk_pnt.new_addr), UVM_LOW)
                packet.func_address = chk_pnt.new_addr;
                packet.gen_token_crc5();
            end
            if (chk_pnt.new_epnum != 'h1f) begin
                `brt_info ("INJEC_ERR", $sformatf ("New endpoint has changed. Old: %d, new: %d",packet.endp, chk_pnt.new_epnum), UVM_LOW)
                packet.endp = chk_pnt.new_epnum;
                packet.gen_token_crc5();
            end

            // Data size
            if (chk_pnt.data_size >= 0) begin
                `brt_info ("INJEC_ERR", $sformatf ("data has changed. Old: %d, new: %d",packet.data.size(), chk_pnt.data_size), UVM_LOW)
                packet.data = new[chk_pnt.data_size];
                foreach (packet.data[i]) begin
                    packet.data[i] = $urandom_range (0,255);
                end
                packet.gen_data_crc16();
                //packet.need_rsp = 0;
            end
            //// pkt_err
            //if (chk_pnt.pkt_err != 'b11) begin
            //    if (chk_pnt.pkt_err != pkt_clone.pkt_err) begin
            //        pass = 0;
            //        `brt_error ("PKT_CHEKER",$sformatf ("pkt_err is not correct. Exp: %d, real: %d",chk_pnt.pkt_err, pkt_clone.pkt_err))
            //    end
            //end
            // pid_err
            if (chk_pnt.pid_err == 'b1) begin
                `brt_info ("INJEC_ERR", $sformatf ("PID[7:4] has injected error. addr: %d, ep: %d, dir: %d, pid: %s, idx: %d", 
                                                                                 cur_addr, cur_epnum, cur_dir, packet.pid_name.name(), pkt_idx[idx]), UVM_LOW)
                packet.pid_format[7:4] += $urandom_range(1,15);                
                packet.pkt_err = 1;
                //packet.need_rsp = 0;
            end
            // crc5_err
            if (chk_pnt.crc5_err == 'b1) begin
                `brt_info ("INJEC_ERR", $sformatf ("CRC5 has injected error. addr: %d, ep: %d, dir: %d, pid: %s, idx: %d", 
                                                                                 cur_addr, cur_epnum, cur_dir, packet.pid_name.name(), pkt_idx[idx]), UVM_LOW)
                packet.token_crc5 += $urandom_range(1,2**5-1);
                packet.pkt_err = 1;
            end
            // crc16_err
            if (chk_pnt.crc16_err != 'b11) begin
                `brt_info ("INJEC_ERR", $sformatf ("CRC16 has injected error. addr: %d, ep: %d, dir: %d, pid: %s, idx: %d", 
                                                                                 cur_addr, cur_epnum, cur_dir, packet.pid_name.name(), pkt_idx[idx]), UVM_LOW)
                packet.data_crc16 += $urandom_range(1,2**16-1);
                packet.pkt_err = 1;
                //packet.need_rsp = 0;
            end
            // bit_stuff_err
            if (chk_pnt.bit_stuff_err == 'b1) begin
                `brt_info ("INJEC_ERR", $sformatf ("bitstuff has injected error. addr: %d, ep: %d, dir: %d, pid: %s, idx: %d", 
                                                                                 cur_addr, cur_epnum, cur_dir, packet.pid_name.name(), pkt_idx[idx]), UVM_LOW)
                packet.bit_stuff_err = 'b1;
                packet.pkt_err = 1;
                //packet.need_rsp = 0;
            end
            // bit_stuff_err
            if (chk_pnt.eop_length >= 0) begin
                `brt_info ("INJEC_ERR", $sformatf ("eop_length (%d) has injected error. addr: %d, ep: %d, dir: %d, pid: %s, idx: %d", 
                                                                                chk_pnt.eop_length, cur_addr, cur_epnum, cur_dir, packet.pid_name.name(), pkt_idx[idx]), UVM_LOW)
                packet.eop_length = chk_pnt.eop_length;
                packet.pkt_err = 1;
                //packet.need_rsp = 0;
            end
            // need_timeout
            if (chk_pnt.need_timeout == 'b1) begin
                `brt_info ("INJEC_ERR", $sformatf ("need_timeout has injected error. addr: %d, ep: %d, dir: %d, pid: %s, idx: %d", 
                                                                                 cur_addr, cur_epnum, cur_dir, packet.pid_name.name(), pkt_idx[idx]), UVM_LOW)
                packet.need_timeout = 'b1;
                packet.need_rsp = 1;
            end
            // inter packet delay
            if (chk_pnt.pkt_dly >= 0) begin
                `brt_info ("INJEC_ERR", $sformatf ("Inter packet delay has changed. Old: %d, new: %d",packet.inter_pkt_dly, chk_pnt.pkt_dly), UVM_LOW)
                packet.inter_pkt_dly = chk_pnt.pkt_dly;
            end
            // rty
            if (chk_pnt.rty == 'b1) begin
                `brt_info ("INJEC_ERR", $sformatf ("rty(pkt_err) has injected error. addr: %d, ep: %d, dir: %d, pid: %s, idx: %d", 
                                                                                 cur_addr, cur_epnum, cur_dir, packet.pid_name.name(), pkt_idx[idx]), UVM_LOW)
                packet.pkt_err = 'b1;
            end

            // drop
            if (chk_pnt.drop == 'b1) begin
                `brt_info ("INJEC_ERR", $sformatf ("drop has injected error. addr: %d, ep: %d, dir: %d, pid: %s, idx: %d", 
                                                                                 cur_addr, cur_epnum, cur_dir, packet.pid_name.name(), pkt_idx[idx]), UVM_LOW)
                drop = chk_pnt.drop;
            end

            // packet info
            `brt_info ("INJEC_ERR", $sformatf ("error inection has been injected with below info:\n%s", chk_pnt.sprint()), UVM_LOW);
            need_del.push_front(i);
            injected_err --;
        end

        foreach (need_del[i]) begin
            inject_err_array.delete(need_del[i]);
        end
    endfunction


    virtual function void add_inject_err (
                                           bit [7:0]                   addr            = 'hff
                                          ,bit [4:0]                   epnum           = 'h1f
                                          ,bit [1:0]                   dir             = 'b11
                                          ,bit [1:0]                   ext_pkt         = 'b11
                                          ,bit [1:0]                   lpm_pkt         = 'b11
                                          ,bit [1:0]                   ack_pkt         = 'b11
                                          ,brt_usb_packet::pid_name_e  pid             = brt_usb_packet::EXT
                                          ,bit [7:0]                   new_addr        = 'hff
                                          ,bit [4:0]                   new_epnum       = 'h1f
                                          ,brt_usb_packet::pid_name_e  new_pid         = brt_usb_packet::EXT
                                          ,int                         data_size       = -1
                                          ,bit [1:0]                   pkt_err         = 'b11
                                          ,bit [1:0]                   pid_err         = 'b11
                                          ,bit [1:0]                   crc5_err        = 'b11
                                          ,bit [1:0]                   crc16_err       = 'b11
                                          ,bit [1:0]                   bit_stuff_err   = 'b11
                                          ,int                         eop_length      = -1
                                          ,int                         pkt_dly         = -1
                                          ,bit [1:0]                   need_timeout    = 'b11
                                          ,bit [1:0]                   rty             = 'b11
                                          ,bit [1:0]                   drop            = 'b11
                                          ,int                         pkt_idx         = -1
                                        );
        brt_usb_check_point         chk_pnt_tmp;

        chk_pnt_tmp                 = brt_usb_check_point::type_id::create();
        chk_pnt_tmp.addr            = addr           ; 
        chk_pnt_tmp.epnum           = epnum          ; 
        chk_pnt_tmp.dir             = dir            ; 
        chk_pnt_tmp.ext_pkt         = ext_pkt        ; 
        chk_pnt_tmp.lpm_pkt         = lpm_pkt        ; 
        chk_pnt_tmp.ack_pkt         = ack_pkt        ; 
        chk_pnt_tmp.pid             = pid            ; 
        chk_pnt_tmp.new_addr        = new_addr       ; 
        chk_pnt_tmp.new_epnum       = new_epnum      ; 
        chk_pnt_tmp.new_pid         = new_pid        ; 
        chk_pnt_tmp.data_size       = data_size      ; 
        chk_pnt_tmp.pkt_err         = pkt_err        ; 
        chk_pnt_tmp.pid_err         = pid_err        ; 
        chk_pnt_tmp.crc5_err        = crc5_err       ; 
        chk_pnt_tmp.crc16_err       = crc16_err      ; 
        chk_pnt_tmp.bit_stuff_err   = bit_stuff_err  ; 
        chk_pnt_tmp.eop_length      = eop_length  ; 
        chk_pnt_tmp.pkt_dly         = pkt_dly  ; 
        chk_pnt_tmp.need_timeout    = need_timeout  ; 
        chk_pnt_tmp.rty             = rty  ; 
        chk_pnt_tmp.drop            = drop ; 
        chk_pnt_tmp.pkt_idx         = pkt_idx  ; 

        inject_err_array.push_back(chk_pnt_tmp);
        injected_err++;
        `brt_info (get_name(), $sformatf("Number of device error injection: %d", injected_err), UVM_HIGH)
    endfunction

    // Add check point
    virtual function void add_chk_pkt (brt_usb_check_packet chk_pkt, string name = "");
        if (chk_pkt == null) begin
            `uvm_error (get_name(), "chk_pkt is null, should create before using")
        end
        else begin
            if (name != "") begin
                chk_pkt.set_name(name);
            end
            chk_pkt_array.push_back(chk_pkt);
        end
        // Decrease
        added_chk_pnt--;
    endfunction

    virtual function void del_chk_pkt (brt_usb_check_packet chk_pkt, string name = "");
        foreach (chk_pkt_array[i]) begin
            if (chk_pkt_array[i] == chk_pkt) begin
                chk_pkt_array.delete(i);
                `brt_info (get_name(), $sformatf ("Delete check_pkt_array of object %d", chk_pkt_array[i]), UVM_HIGH) 
            end
            else if (chk_pkt_array[i].get_name() == name) begin
                chk_pkt_array.delete(i);
                `brt_info (get_name(), $sformatf ("Delete check_pkt_array by name %s", name), UVM_HIGH) 
            end
        end
    endfunction

    virtual function void report_chk_pkt ();
        foreach (chk_pkt_array[i]) begin
            if (chk_pkt_array[i].chk_pnt_array.size() > 0) begin
                `brt_error (get_name(), $sformatf ("chk_pkt_array[%d] was not passed", i))
                foreach (chk_pkt_array[i].chk_pnt_array[j]) begin
                    chk_pkt_array[i].chk_pnt_array[j].print();
                end 
            end
        end
    endfunction

    virtual function reset_index (
                                bit [6:0] addr
                               ,bit [3:0] epnum
                               ,bit       dir
                             );
        idx = {addr, epnum, dir};
        pkt_idx[idx] = 0;
    endfunction
endclass
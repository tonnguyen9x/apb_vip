typedef class brt_usb_check_packet;
typedef class brt_usb_check_point;

class brt_usb_host_util_callback extends brt_usb_protocol_callbacks;
    `uvm_object_utils (brt_usb_host_util_callback)

    brt_usb_check_packet        chk_pkt_array[$];
    brt_usb_check_point         inject_err_array[$];
    int                         added_chk_pnt;
    int                         injected_err;
    bit [7+4+1-1:0]             idx;
    bit [6:0]                   cur_addr;
    bit [3:0]                   cur_epnum;
    bit                         cur_dir;
    int                         pkt_idx[bit [7+4+1-1:0]];

    function new(string name = "brt_usb_host_util_callback");
        super.new(name);
    endfunction

    virtual function void transfer_begin(brt_usb_protocol component, brt_usb_transfer transfer);
        `uvm_info (get_name(),$sformatf("Host utility callback transfer is active"), UVM_LOW) 
    endfunction

    // Error injection
    virtual function void pre_brt_usb_20_packet_out_port_put(brt_usb_protocol component, brt_usb_transfer transfer, brt_usb_packet packet, ref bit drop);
        brt_usb_check_point     chk_pnt;
        bit                     mtch_des;  // match destination
        int                     need_del[$];
        //static bit [7+4+1-1:0]  idx;
        //static bit [6:0]        cur_addr;
        //static bit [3:0]        cur_epnum;
        //static bit              cur_dir;

        // Get address base on TOKEN
        if (!packet.pkt_err && 
             (packet.pid_format[3:0] == brt_usb_packet::IN ||
             packet.pid_format[3:0] == brt_usb_packet::OUT ||
             packet.pid_format[3:0] == brt_usb_packet::PING ||
             packet.pid_format[3:0] == brt_usb_packet::SETUP ||
             packet.pid_format[3:0] == brt_usb_packet::EXT )
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
        `brt_info ("DEBUG", $sformatf ("Receive a packet \n%s", packet.sprint()), UVM_DEBUG)
        packet.print();
        foreach (inject_err_array[i]) begin
            chk_pnt = inject_err_array[i];
            mtch_des = 1;
            //mtch_des = mtch_des && (chk_pnt.addr == 'hff || chk_pnt.addr == pkt_clone.func_address);
            //mtch_des = mtch_des && (chk_pnt.epnum == 'h1f || chk_pnt.epnum == pkt_clone.endp);
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
                `brt_info ("INJEC_ERR", $sformatf ("New PID has changed. Old: %d, new: %d",packet.pid_name.name(), chk_pnt.new_pid.name()), UVM_LOW)
                packet.pid_name = chk_pnt.new_pid;
                $cast (packet.pid_format[3:0],chk_pnt.new_pid);
                packet.pid_format[7:4] = ~ packet.pid_format[3:0];
                packet.gen_token_crc5();
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
                packet.ignore_chk_err = 1;
            end
            // crc5_err
            if (chk_pnt.crc5_err == 'b1) begin
                `brt_info ("INJEC_ERR", $sformatf ("CRC5 has injected error. addr: %d, ep: %d, dir: %d, pid: %s, idx: %d", 
                                                                                 cur_addr, cur_epnum, cur_dir, packet.pid_name.name(), pkt_idx[idx]), UVM_LOW)
                packet.token_crc5 += $urandom_range(1,2**5-1);
                packet.pkt_err = 1;
                packet.ignore_chk_err = 1;
            end
            // crc16_err
            if (chk_pnt.crc16_err != 'b11) begin
                `brt_info ("INJEC_ERR", $sformatf ("CRC16 has injected error. addr: %d, ep: %d, dir: %d, pid: %s, idx: %d", 
                                                                                 cur_addr, cur_epnum, cur_dir, packet.pid_name.name(), pkt_idx[idx]), UVM_LOW)
                packet.data_crc16 += $urandom_range(1,2**16-1);
                packet.pkt_err = 1;
                packet.ignore_chk_err = 1;
            end
            // bit_stuff_err
            if (chk_pnt.bit_stuff_err == 'b1) begin
                `brt_info ("INJEC_ERR", $sformatf ("bitstuff has injected error. addr: %d, ep: %d, dir: %d, pid: %s, idx: %d", 
                                                                                 cur_addr, cur_epnum, cur_dir, packet.pid_name.name(), pkt_idx[idx]), UVM_LOW)
                packet.bit_stuff_err = 'b1;
                packet.pkt_err = 1;
                packet.ignore_chk_err = 1;
            end
            // eop_length
            if (chk_pnt.eop_length >= 0) begin
                `brt_info ("INJEC_ERR", $sformatf ("eop_length (%d) has injected error. addr: %d, ep: %d, dir: %d, pid: %s, idx: %d", 
                                                                                chk_pnt.eop_length, cur_addr, cur_epnum, cur_dir, packet.pid_name.name(), pkt_idx[idx]), UVM_LOW)
                packet.eop_length = chk_pnt.eop_length;
                packet.pkt_err = 1;
                packet.ignore_chk_err = 1;
            end
            // need_timeout
            if (chk_pnt.need_timeout == 'b1) begin
                `brt_info ("INJEC_ERR", $sformatf ("need_timeout has injected error. addr: %d, ep: %d, dir: %d, pid: %s, idx: %d", 
                                                                                 cur_addr, cur_epnum, cur_dir, packet.pid_name.name(), pkt_idx[idx]), UVM_LOW)
                packet.need_timeout = 'b1;
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

    virtual function void packet_monitor (brt_usb_protocol component, brt_usb_packet packet);
        brt_usb_check_packet    chk_pkt;
        brt_usb_check_point     chk_pnt;
        brt_usb_packet          pkt_clone;
        bit                     mtch_des;  // match destination
        bit                     pass;
        //static bit [7+4+1-1:0]  idx;
        bit [6:0]        cur_addr;
        bit [3:0]        cur_epnum;
        bit              cur_dir;

        // Get address base on TOKEN
        if (!packet.pkt_err &&
             packet.pid_format[3:0] == brt_usb_packet::IN ||
             packet.pid_format[3:0] == brt_usb_packet::OUT ||
             packet.pid_format[3:0] == brt_usb_packet::PING ||
             packet.pid_format[3:0] == brt_usb_packet::SETUP ||
             packet.pid_format[3:0] == brt_usb_packet::EXT
           ) begin
            cur_addr  = packet.func_address;
            cur_epnum = packet.endp;
            if (cur_epnum == 0) begin
                cur_dir = 0;
            end 
            else begin
                cur_dir = (packet.pid_format[3:0] == brt_usb_packet::IN);
            end
            //idx = {cur_addr, cur_epnum, cur_dir};
            //pkt_idx[idx] ++;
        end
        else begin
            cur_addr  = this.cur_addr ;
            cur_epnum = this.cur_epnum;
            cur_dir   = this.cur_dir  ;
        end

        $cast (pkt_clone, packet.clone());
        `uvm_info (get_name(),$sformatf("Host utility packet monitor callback is active, number of checkpoint : %d", chk_pkt_array), UVM_LOW) 

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
                mtch_des = mtch_des && (chk_pnt.pkt_idx == -1 || chk_pnt.pkt_idx == pkt_idx[idx]);

                // Data size
                if (chk_pnt.data_size != -1) begin
                    if (chk_pnt.data_size != pkt_clone.data.size()) begin
                        //pass = 0;
                        //`brt_error ("PKT_CHEKER",$sformatf ("data sieze is not correct. Exp: %d, real: %d",chk_pnt.data_size, pkt_clone.data.size()))
                        mtch_des = 0;
                    end
                end
                // pkt_err
                if (chk_pnt.pkt_err != 'b11) begin
                    if (chk_pnt.pkt_err != pkt_clone.pkt_err) begin
                        //pass = 0;
                        //`brt_error ("PKT_CHEKER",$sformatf ("pkt_err is not correct. Exp: %d, real: %d",chk_pnt.pkt_err, pkt_clone.pkt_err))
                        mtch_des = 0;
                    end
                end
                // pid_err
                if (chk_pnt.pid_err != 'b11) begin
                    if (chk_pnt.pid_err != pkt_clone.pid_err) begin
                        //pass = 0;
                        //`brt_error ("PKT_CHEKER",$sformatf ("pid_err is not correct. Exp: %d, real: %d",chk_pnt.pid_err, pkt_clone.pid_err))
                        mtch_des = 0;
                    end
                end
                // crc5_err
                if (chk_pnt.crc5_err != 'b11) begin
                    if (chk_pnt.crc5_err != pkt_clone.crc5_err) begin
                        //pass = 0;
                        //`brt_error ("PKT_CHEKER",$sformatf ("crc5_err is not correct. Exp: %d, real: %d",chk_pnt.crc5_err, pkt_clone.crc5_err))
                        mtch_des = 0;
                    end
                end
                // crc16_err
                if (chk_pnt.crc16_err != 'b11) begin
                    if (chk_pnt.crc16_err != pkt_clone.crc16_err) begin
                        //pass = 0;
                        //`brt_error ("PKT_CHEKER",$sformatf ("crc16_err is not correct. Exp: %d, real: %d",chk_pnt.crc16_err, pkt_clone.crc16_err))
                        mtch_des = 0;
                    end
                end
                // bit_stuff_err
                if (chk_pnt.bit_stuff_err != 'b11) begin
                    if (chk_pnt.bit_stuff_err != pkt_clone.bit_stuff_err) begin
                        //pass = 0;
                        //`brt_error ("PKT_CHEKER",$sformatf ("bit_stuff_err is not correct. Exp: %d, real: %d",chk_pnt.bit_stuff_err, pkt_clone.bit_stuff_err))
                        mtch_des = 0;
                    end
                end

                if (!mtch_des) continue;

                //if (pass)
                    `brt_info  ("PKT_CHEKER",$sformatf ("Packet has passed the checker"), UVM_LOW)
                //else
                //    `brt_error ("PKT_CHEKER",$sformatf ("Packet has not passed the checker"))
                // packet info
                chk_pnt.print();
                chk_pkt.chk_pnt_array.delete(0);
            end  // Check point
        end  // foeach chk_pkt
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
endclass: brt_usb_host_util_callback

class brt_usb_check_point extends brt_object;
    bit [7:0]                   addr;
    bit [4:0]                   epnum;
    bit [1:0]                   dir;
    bit [1:0]                   ext_pkt;
    bit [1:0]                   lpm_pkt;
    bit [1:0]                   ack_pkt;
    brt_usb_packet::pid_name_e  pid;
    bit [7:0]                   new_addr;
    bit [4:0]                   new_epnum;
    brt_usb_packet::pid_name_e  new_pid;
    int                         data_size;
    bit [1:0]                   pkt_err;
    bit [1:0]                   pid_err;
    bit [1:0]                   crc5_err;
    bit [1:0]                   crc16_err;
    bit [1:0]                   bit_stuff_err;
    int                         eop_length;
    int                         pkt_dly;
    bit [1:0]                   need_timeout;
    bit [1:0]                   rty;
    bit [1:0]                   drop;
    int                         pkt_idx;
    
    `brt_object_utils_begin(brt_usb_check_point)
        `brt_field_int  (addr                             , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_int  (epnum                            , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_int  (dir                              , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_int  (ext_pkt                          , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_int  (lpm_pkt                          , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_int  (ack_pkt                          , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_enum (brt_usb_packet::pid_name_e, pid  , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_int  (new_addr                         , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_int  (new_epnum                        , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_enum (brt_usb_packet::pid_name_e, new_pid  , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_int  (data_size                        , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_int  (pkt_err                          , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_int  (pid_err                          , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_int  (crc5_err                         , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_int  (crc16_err                        , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_int  (bit_stuff_err                    , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_int  (eop_length                       , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_int  (pkt_dly                          , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_int  (need_timeout                     , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_int  (rty                              , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_int  (drop                             , UVM_ALL_ON|UVM_NOPACK)
        `brt_field_int  (pkt_idx                          , UVM_ALL_ON|UVM_NOPACK)
    `brt_object_utils_end

endclass: brt_usb_check_point

class brt_usb_check_packet extends brt_object;
    brt_usb_check_point             chk_pnt_array[$];
    brt_usb_host_util_callback      host_util_cb;

    function new(string name = "get_pkt", brt_usb_host_util_callback host_util_cb);
        super.new(name);
        this.host_util_cb = host_util_cb;
        // Increase check point
        host_util_cb.added_chk_pnt++;
    endfunction

    virtual function void add_chk_pnt (
                                         bit [7:0]                   addr            = 'hff
                                        ,bit [4:0]                   epnum           = 'h1f
                                        ,bit [1:0]                   dir             = 'b11
                                        ,brt_usb_packet::pid_name_e  pid             = brt_usb_packet::EXT
                                        ,int                         data_size       = -1
                                        ,bit [1:0]                   pkt_err         = 'b11
                                        ,bit [1:0]                   pid_err         = 'b11
                                        ,bit [1:0]                   crc5_err        = 'b11
                                        ,bit [1:0]                   crc16_err       = 'b11
                                        ,bit [1:0]                   bit_stuff_err   = 'b11
                                        ,int                         pkt_idx         = -1
                                      );
        brt_usb_check_point         chk_pnt_tmp;

        chk_pnt_tmp                 = brt_usb_check_point::type_id::create();
        chk_pnt_tmp.addr            = addr           ; 
        chk_pnt_tmp.epnum           = epnum          ; 
        chk_pnt_tmp.dir             = dir            ; 
        chk_pnt_tmp.pid             = pid            ; 
        chk_pnt_tmp.data_size       = data_size      ; 
        chk_pnt_tmp.pkt_err         = pkt_err        ; 
        chk_pnt_tmp.pid_err         = pid_err        ; 
        chk_pnt_tmp.crc5_err        = crc5_err       ; 
        chk_pnt_tmp.crc16_err       = crc16_err      ; 
        chk_pnt_tmp.bit_stuff_err   = bit_stuff_err  ; 
        chk_pnt_tmp.pkt_idx         = pkt_idx        ; 

        chk_pnt_array.push_back(chk_pnt_tmp);
    endfunction: add_chk_pnt

    virtual function void do_print(uvm_printer printer);
        super.do_print(printer);
        foreach (chk_pnt_array[i]) begin
            chk_pnt_array[i].print();
        end
    endfunction
endclass: brt_usb_check_packet


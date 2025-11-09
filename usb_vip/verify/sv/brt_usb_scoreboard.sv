`uvm_analysis_imp_decl( _exp )
`uvm_analysis_imp_decl( _act )

class brt_usb_scoreboard extends uvm_scoreboard;
    bit     is_run;
    int     idx;
    int VECT_CNT, PASS_CNT, ERROR_CNT;
    `uvm_component_utils(brt_usb_scoreboard)
    brt_usb_transfer        expfifo[$];
    brt_usb_transfer        actfifo[$];

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    virtual task run_phase (uvm_phase phase);
        brt_usb_transfer exp_tr, act_tr;
        bit     cmp_fail;

        super.run_phase (phase);
        forever begin
            `uvm_info("scoreboard run task","WAITING for expected & actual output", UVM_DEBUG)
            wait (expfifo.size() && actfifo.size());
            exp_tr = expfifo.pop_front();
            //`uvm_info("scoreboard run task","WAITING for actual output", UVM_DEBUG)
            //wait (actfifo.size());
            act_tr = actfifo.pop_front();

            cmp_fail = 0;
            if (idx == 0) begin  // control transfer
                cmp_fail = cmp_ctrl_xfer(exp_tr, act_tr);
            end
            else if (idx%2 == 1) begin  // IN
                cmp_fail = cmp_in_xfer(exp_tr, act_tr);
            end
            else begin  // OUT
                cmp_fail = cmp_out_xfer(exp_tr, act_tr);
            end

            if (!cmp_fail) begin
                PASS();
                `uvm_info ("CMP_PASS ", $sformatf("Actual=%s Expected=%s \n", "T.B.D", "T.B.D"), UVM_HIGH)
            end
            else begin
                ERROR();
                `uvm_error("CMP_FAIL", $sformatf("Actual=%s Expected=%s \n", "T.B.D", "T.B.D"))
            end
        end
    endtask

    function bit cmp_ctrl_xfer (brt_usb_transfer exp_tr, brt_usb_transfer act_tr);
        bit fail; 

        // Check dev address
        chk_int (exp_tr.device_address, act_tr.device_address, "Dev address", fail);
        // Check setup packet
        chk_int (exp_tr.setup_data_bmrequesttype, act_tr.setup_data_bmrequesttype, "setup_data_bmrequesttype", fail);
        chk_int (exp_tr.setup_data_brequest, act_tr.setup_data_brequest, "setup_data_brequest", fail);
        chk_int (exp_tr.setup_data_w_value, act_tr.setup_data_w_value, "setup_data_w_value", fail);
        chk_int (exp_tr.setup_data_w_index, act_tr.setup_data_w_index, "setup_data_w_index", fail);
        chk_int (exp_tr.setup_data_w_length, act_tr.setup_data_w_length, "setup_data_w_length", fail);
        
        // Check data
        if (exp_tr.setup_data_w_length > 0) begin
            chk_int (exp_tr.payload.data.size(), act_tr.payload.data.size(), "data size", fail);
           
            foreach (exp_tr.payload.data[i]) begin
                chk_int (exp_tr.payload.data[i], act_tr.payload.data[i], $sformatf("data[%0d]",i), fail);
            end 
        end
        
        return fail;
    endfunction

    function bit cmp_in_xfer (brt_usb_transfer exp_tr, brt_usb_transfer act_tr);
        bit fail; 

        chk_int (exp_tr.payload.data.size(), act_tr.payload.data.size(), "data size", fail);
        
        foreach (exp_tr.payload.data[i]) begin
            chk_int (exp_tr.payload.data[i], act_tr.payload.data[i], $sformatf("data[%0d]",i), fail);
        end 
        return fail;
    endfunction

    function bit cmp_out_xfer (brt_usb_transfer exp_tr, brt_usb_transfer act_tr);
        bit fail; 

        chk_int (exp_tr.payload.data.size(), act_tr.payload.data.size(), "data size", fail);
        
        foreach (exp_tr.payload.data[i]) begin
            chk_int (exp_tr.payload.data[i], act_tr.payload.data[i], $sformatf("data[%0d]",i), fail);
        end 
        return fail;
    endfunction

    function chk_int (bit [31:0] a, bit[31:0] b, string str, output bit fail);
        if (a == b ) begin
            `uvm_info ("SB", $sformatf ("%s = %2h: OK", str, a), UVM_HIGH)
        end
        else begin
            fail = 1;
            `uvm_error ("SB", $sformatf ("%s: exp = %2h <> act = %2h", str, a, b))
        end
    endfunction

    virtual function void report_phase (uvm_phase phase);
        super.report_phase (phase);

        if (is_run) begin
            if (!ERROR_CNT && expfifo.size() == 0 && actfifo.size() == 0)
                `uvm_info("SB_OK", $sformatf("\n*** OK - %0d vectors ran, %0d vectors passed ***\n\n", VECT_CNT, PASS_CNT), UVM_LOW)
            else
                `uvm_error("SB_NG", $sformatf("\n*** NG - %0d vectors ran, %0d vectors passed, %0d vectors failed, remained expfifo: %0d, remained actfifo: %0d  ***\n\n",
                                                          VECT_CNT, PASS_CNT, ERROR_CNT, expfifo.size(), actfifo.size()))
        end
    endfunction

    function void PASS();
        VECT_CNT++;
        PASS_CNT++;
    endfunction

    function void ERROR();
        VECT_CNT++;
        ERROR_CNT++;
    endfunction

endclass

class brt_usb_mult_sb_wrapper extends uvm_component;
    brt_usb_scoreboard  usb_sb[bit[4+1 - 1:0]];
    bit                 dis_sb[bit[4+1 - 1:0]];
    bit                 dis_all;

    uvm_analysis_imp_exp #(brt_usb_transfer, brt_usb_mult_sb_wrapper) aport_exp_host;
    uvm_analysis_imp_exp #(brt_usb_transfer, brt_usb_mult_sb_wrapper) aport_exp_dev;
    uvm_analysis_imp_act #(brt_usb_transfer, brt_usb_mult_sb_wrapper) aport_act_host;
    uvm_analysis_imp_act #(brt_usb_transfer, brt_usb_mult_sb_wrapper) aport_act_dev;

    `uvm_component_utils (brt_usb_mult_sb_wrapper)

    function new (string name = "brt_usb_mult_sb_wrapper", uvm_component parent);
        super.new (name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        aport_exp_host = new("aport_exp_host", this);
        aport_exp_dev  = new("aport_exp_dev", this);
        aport_act_host = new("aport_act_host", this);
        aport_act_dev  = new("aport_act_dev", this);

        for (int i = 0; i < 32; i++) begin
             usb_sb[i] = new($sformatf ("usb_sb[%d]",i), this);
             usb_sb[i].idx = i;
        end
    endfunction

    function void write_exp(brt_usb_transfer tr);
        bit [4+1-1:0] idx;

        get_add (tr,idx);
        //if (usb_sb[idx] == null) begin
        //    `uvm_info("USBSB", $sformatf ("Create new scoreboard. idx: %b",idx), UVM_HIGH)
        //    usb_sb[idx] = new($sformatf ("usb_sb[%d]",idx), this);
        //    fork
        //        usb_sb[idx].chk_data();
        //    join_none
        //end
        if (dis_all || dis_sb[idx] == 1 || tr.xfer_type == brt_usb_transfer::LPM_TRANSFER) begin
            `uvm_info("Disable write_exp", $sformatf ("T.B.D %b", idx), UVM_LOW)
            return;
        end
        usb_sb[idx].is_run = 1;
        `uvm_info("write_exp STIM", $sformatf ("T.B.D %b", idx), UVM_LOW)
        usb_sb[idx].expfifo.push_back(tr);
    endfunction

    function void write_act(brt_usb_transfer tr);
        bit [4+1-1:0] idx;

        get_add (tr,idx);
        //if (usb_sb[idx] == null) begin
        //    `uvm_info("USBSB", $sformatf ("Create new scoreboard. idx: %b",idx), UVM_HIGH)
        //    usb_sb[idx] = new($sformatf ("usb_sb[%d]",idx), this);
        //    fork
        //        usb_sb[idx].chk_data();
        //    join_none
        //end
        if (dis_all || dis_sb[idx] == 1 || tr.xfer_type == brt_usb_transfer::LPM_TRANSFER) begin
            `uvm_info("Disable write_act", $sformatf ("T.B.D %b", idx), UVM_LOW)
            return;
        end
        usb_sb[idx].is_run = 1;
        `uvm_info("write_act STIM", $sformatf ("T.B.D %b", idx), UVM_LOW)
        usb_sb[idx].actfifo.push_back(tr);
    endfunction

    function void get_add (brt_usb_transfer tr, output bit [4+1-1:0] idx);
        bit [6:0] addr;
        bit [3:0] epnum;
        bit       dir;
        int xfer_type;
        addr  = tr.device_address;
        epnum = tr.endpoint_number;
        $cast (xfer_type,tr.xfer_type);
        dir   = xfer_type%2;
        idx = {epnum,dir};
    endfunction
    
    function void disable_sb(bit[3:0] epnum, bit dir);
        bit [4+1-1:0] idx;
        idx = {epnum,dir};
        
        dis_sb[idx] = 1;
    endfunction

    function void enable_sb(bit[3:0] epnum, bit dir);
        bit [4+1-1:0] idx;
        idx = {epnum,dir};
        
        dis_sb[idx] = 0;
    endfunction
endclass
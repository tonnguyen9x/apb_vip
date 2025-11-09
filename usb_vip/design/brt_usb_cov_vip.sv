    logic [6:0] dev_addr = 'hz;
    brt_usb_types::speed_e dev_speed_e = brt_usb_types::SS;
    logic [10:0] max_pkt_size = 'hz;
    brt_usb_transfer::transfer_type_e xfer_type_e = brt_usb_transfer::RESERVED;
    logic [15:0] xfer_size = 'hz;
    logic [2:0] burst_size = 'hz;
    logic [10:0] pkt_size = 'hz;
    brt_usb_packet::pid_name_e pkt_pid_e = brt_usb_packet::EXT;
    brt_usb_types::packet_err_e pkt_err_e = brt_usb_types::RESERVE_ERR;

    // Timing measurement
    int ls_in_tkn_to_data = -1;
    int ls_in_data_to_ack = -1;
    int ls_out_tkn_to_data = -1;
    int ls_out_data_to_ack = -1;
    int fs_in_tkn_to_data = -1;
    int fs_in_data_to_ack = -1;
    int fs_out_tkn_to_data = -1;
    int fs_out_data_to_ack = -1;
    int hs_in_tkn_to_data = -1;
    int hs_in_data_to_ack = -1;
    int hs_out_tkn_to_data = -1;
    int hs_out_data_to_ack = -1;

function u20_cov_timing_reset();
    ls_in_tkn_to_data = -1;
    ls_in_data_to_ack = -1;
    ls_out_tkn_to_data = -1;
    ls_out_data_to_ack = -1;
    fs_in_tkn_to_data = -1;
    fs_in_data_to_ack = -1;
    fs_out_tkn_to_data = -1;
    fs_out_data_to_ack = -1;
    hs_in_tkn_to_data = -1;
    hs_in_data_to_ack = -1;
    hs_out_tkn_to_data = -1;
    hs_out_data_to_ack = -1;
endfunction    

function u20_cov_reset ();
    dev_addr = 'hz;
    dev_speed_e = brt_usb_types::SS;
    max_pkt_size = 'hz;
    xfer_type_e = brt_usb_transfer::RESERVED;
    xfer_size = 'hz;
    burst_size = 'hz;
    pkt_size = 'hz;
    pkt_pid_e = brt_usb_packet::EXT;
    pkt_err_e = brt_usb_types::RESERVE_ERR;
endfunction

function u20_cov_timing_sample (
                           int ls_in_tkn_to_data = -1
                          ,int ls_in_data_to_ack = -1
                          ,int ls_out_tkn_to_data = -1
                          ,int ls_out_data_to_ack = -1
                          ,int fs_in_tkn_to_data = -1
                          ,int fs_in_data_to_ack = -1
                          ,int fs_out_tkn_to_data = -1
                          ,int fs_out_data_to_ack = -1
                          ,int hs_in_tkn_to_data = -1
                          ,int hs_in_data_to_ack = -1
                          ,int hs_out_tkn_to_data = -1
                          ,int hs_out_data_to_ack = -1
                        );
    this.ls_in_tkn_to_data  = ls_in_tkn_to_data ;
    this.ls_in_data_to_ack  = ls_in_data_to_ack ;
    this.ls_out_tkn_to_data = ls_out_tkn_to_data;
    this.ls_out_data_to_ack = ls_out_data_to_ack;
    this.fs_in_tkn_to_data  = fs_in_tkn_to_data ;
    this.fs_in_data_to_ack  = fs_in_data_to_ack ;
    this.fs_out_tkn_to_data = fs_out_tkn_to_data;
    this.fs_out_data_to_ack = fs_out_data_to_ack;
    this.hs_in_tkn_to_data  = hs_in_tkn_to_data ;
    this.hs_in_data_to_ack  = hs_in_data_to_ack ;
    this.hs_out_tkn_to_data = hs_out_tkn_to_data;
    this.hs_out_data_to_ack = hs_out_data_to_ack;
    CVG_TIMING_VIP_U20.sample();
    u20_cov_timing_reset();
endfunction

function u20_cov_sample (
                         logic [6:0] dev_addr = 'hz
                        ,brt_usb_types::speed_e dev_speed_e = brt_usb_types::SS
                        ,logic [10:0] max_pkt_size = 'hz
                        ,brt_usb_transfer::transfer_type_e xfer_type_e = brt_usb_transfer::RESERVED
                        ,logic [15:0] xfer_size = 'hz
                        ,logic [2:0] burst_size = 'hz
                        ,logic [10:0] pkt_size = 'hz
                        ,brt_usb_packet::pid_name_e pkt_pid_e = brt_usb_packet::EXT
                        ,brt_usb_types::packet_err_e pkt_err_e = brt_usb_types::RESERVE_ERR
                        );
    this.dev_addr     = dev_addr    ;
    this.dev_speed_e  = dev_speed_e ;
    this.max_pkt_size = max_pkt_size;
    this.xfer_type_e  = xfer_type_e ;
    this.xfer_size    = xfer_size   ;
    this.burst_size   = burst_size  ;
    // pkt_size
    if (pkt_size     === 'hz &&
        xfer_size    !== 'hz &&
        max_pkt_size !== 'hz
    ) begin
        pkt_size = xfer_size % max_pkt_size;
    end
    else begin
        this.pkt_size     = pkt_size    ;
    end

    this.pkt_pid_e    = pkt_pid_e   ;
    this.pkt_err_e    = pkt_err_e   ;

    CVG_HS_VIP_U20.sample();
    CVG_FS_VIP_U20.sample();
    CVG_LS_VIP_U20.sample();
    CVG_LPM_VIP_U20.sample();
    u20_cov_reset();
endfunction

covergroup CVG_HS_VIP_U20;
    CVP_ADDR : coverpoint dev_addr {
        bins VTR_ADDR_0 = {0};
        bins VTR_ADDR_1_126 = {[1:126]};
        bins VTR_ADDR_127 = {127};
    }
    CVP_SPEED : coverpoint dev_speed_e {
        bins VTR_SPEED_HS = {brt_usb_types::HS};
    }
    CVP_MPS : coverpoint max_pkt_size {
        bins VTR_MPS_8 = {8};
        bins VTR_MPS_16_256 = {[16:256]};
        bins VTR_MPS_512 = {512};
        bins VTR_MPS_1024 = {1024};
    }
    CVP_XFER : coverpoint xfer_type_e {
        bins VTR_XFER_CTRL = {brt_usb_transfer::CONTROL_TRANSFER};
        bins VTR_XFER_BULK_IN = {brt_usb_transfer::BULK_IN_TRANSFER};
        bins VTR_XFER_BULK_OUT = {brt_usb_transfer::BULK_OUT_TRANSFER};
        bins VTR_XFER_INT_IN = {brt_usb_transfer::INTERRUPT_IN_TRANSFER};
        bins VTR_XFER_INT_OUT = {brt_usb_transfer::INTERRUPT_OUT_TRANSFER};
        bins VTR_XFER_ISO_IN = {brt_usb_transfer::ISOCHRONOUS_IN_TRANSFER};
        bins VTR_XFER_ISO_OUT = {brt_usb_transfer::ISOCHRONOUS_OUT_TRANSFER};
    }
    CVP_XFER_SIZE : coverpoint xfer_size {
        bins VTR_XFER_SIZE_0 = {0};
        bins VTR_XFER_SIZE_1_1024 = {[1:1024]};
        bins VTR_XFER_SIZE_1025_2048 = {[1025:2048]};
        bins VTR_XFER_SIZE_2049_END = {[2049:$]};
    }
    CVP_BURST_SIZE : coverpoint burst_size {
        bins VTR_BURST_SIZE_0 = {0};
        bins VTR_BURST_SIZE_1 = {1};
        bins VTR_BURST_SIZE_2 = {2};
    }
    CVP_PKT_SIZE : coverpoint pkt_size {
        bins VTR_PKT_SIZE_0 = {0};
        bins VTR_PKT_SIZE_1_511 = {[1:511]};
        bins VTR_PKT_SIZE_512 = {512};
        bins VTR_PKT_SIZE_513_1023 = {[513:1023]};
        bins VTR_PKT_SIZE_1024 = {1024};
    }
    CVP_PKT_TYPE : coverpoint pkt_pid_e {
        bins VTR_PKT_TYPE_NAK = {brt_usb_packet::NAK};
        bins VTR_PKT_TYPE_NYET = {brt_usb_packet::NYET};
        bins VTR_PKT_TYPE_STALL = {brt_usb_packet::STALL};
    }
    CVP_PKT_ERR : coverpoint pkt_err_e {
        bins VTR_PID_ERR = {brt_usb_types::PID_ERR};
        bins VTR_CRC5_ERR = {brt_usb_types::CRC5_ERR};
        bins VTR_CRC16_ERR = {brt_usb_types::CRC16_ERR};
        bins VTR_TIMEOUT_ERR = {brt_usb_types::TIMEOUT_ERR};
    }

    CRS_HS_CONTROL_NORMAL : cross CVP_SPEED, CVP_MPS, CVP_XFER, CVP_XFER_SIZE {
        ignore_bins CRS_HS_CONTROL_NORMAL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_MPS) intersect {[16:256]} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::CONTROL_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {0, [1:1024]} ;
    }

    CRS_HS_CONTROL_SHORT_PKT : cross CVP_SPEED, CVP_XFER, CVP_PKT_SIZE {
        ignore_bins CRS_HS_CONTROL_SHORT_PKT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::CONTROL_TRANSFER} ||
            !binsof (CVP_PKT_SIZE) intersect {0, [1:511]} ;
    }

    CRS_HS_CONTROL_DATA_STAGE_ERR_INJECT : cross CVP_SPEED, CVP_XFER, CVP_PKT_ERR {
        ignore_bins CRS_HS_CONTROL_DATA_STAGE_ERR_INJECT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::CONTROL_TRANSFER} ||
            !binsof (CVP_PKT_ERR) intersect {brt_usb_types::PID_ERR, brt_usb_types::CRC5_ERR, brt_usb_types::CRC16_ERR, brt_usb_types::TIMEOUT_ERR} ;
    }

    CRS_HS_CONTROL_DATA_STAGE_NAK_NYET_STALL : cross CVP_SPEED, CVP_XFER, CVP_PKT_TYPE {
        ignore_bins CRS_HS_CONTROL_DATA_STAGE_NAK_NYET_STALL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::CONTROL_TRANSFER} ||
            !binsof (CVP_PKT_TYPE) intersect {brt_usb_packet::NAK, brt_usb_packet::NYET, brt_usb_packet::STALL} ;
    }

    CRS_HS_BULK_IN_NORMAL : cross CVP_SPEED, CVP_MPS, CVP_XFER, CVP_XFER_SIZE {
        ignore_bins CRS_HS_BULK_IN_NORMAL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_MPS) intersect {512} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::BULK_IN_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {0, [2049:$]} ;
    }

    CRS_HS_BULK_IN_SHORT_PKT : cross CVP_SPEED, CVP_XFER, CVP_PKT_SIZE {
        ignore_bins CRS_HS_BULK_IN_SHORT_PKT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::BULK_IN_TRANSFER} ||
            !binsof (CVP_PKT_SIZE) intersect {0, [1:511]} ;
    }

    CRS_HS_BULK_IN_ERR_INJECT : cross CVP_SPEED, CVP_XFER, CVP_XFER_SIZE, CVP_PKT_ERR {
        ignore_bins CRS_HS_BULK_IN_ERR_INJECT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::BULK_IN_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {0, [2049:$]} ||
            !binsof (CVP_PKT_ERR) intersect {brt_usb_types::PID_ERR, brt_usb_types::CRC5_ERR, brt_usb_types::TIMEOUT_ERR} ;
    }

    CRS_HS_BULK_IN_NAK_STALL : cross CVP_SPEED, CVP_XFER, CVP_PKT_TYPE {
        ignore_bins CRS_HS_BULK_IN_NAK_STALL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::BULK_IN_TRANSFER} ||
            !binsof (CVP_PKT_TYPE) intersect {brt_usb_packet::NAK, brt_usb_packet::STALL} ;
    }

    CRS_HS_BULK_OUT_NORMAL : cross CVP_SPEED, CVP_MPS, CVP_XFER, CVP_XFER_SIZE {
        ignore_bins CRS_HS_BULK_OUT_NORMAL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_MPS) intersect {512} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::BULK_OUT_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {0, [2049:$]} ;
    }

    CRS_HS_BULK_OUT_SHORT_PKT : cross CVP_SPEED, CVP_XFER, CVP_PKT_SIZE {
        ignore_bins CRS_HS_BULK_OUT_SHORT_PKT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::BULK_OUT_TRANSFER} ||
            !binsof (CVP_PKT_SIZE) intersect {0, [1:511]} ;
    }

    CRS_HS_BULK_OUT_ERR_INJECT : cross CVP_SPEED, CVP_XFER, CVP_XFER_SIZE, CVP_PKT_ERR {
        ignore_bins CRS_HS_BULK_OUT_ERR_INJECT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::BULK_OUT_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {0, [2049:$]} ||
            !binsof (CVP_PKT_ERR) intersect {brt_usb_types::PID_ERR, brt_usb_types::CRC5_ERR, brt_usb_types::CRC16_ERR, brt_usb_types::TIMEOUT_ERR} ;
    }

    CRS_HS_BULK_OUT_NAK_NYET_STALL : cross CVP_SPEED, CVP_XFER, CVP_PKT_TYPE {
        ignore_bins CRS_HS_BULK_OUT_NAK_NYET_STALL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::BULK_OUT_TRANSFER} ||
            !binsof (CVP_PKT_TYPE) intersect {brt_usb_packet::NAK, brt_usb_packet::NYET, brt_usb_packet::STALL} ;
    }

    CRS_HS_INTERRUPT_IN_NORMAL : cross CVP_SPEED, CVP_MPS, CVP_XFER {
        ignore_bins CRS_HS_INTERRUPT_IN_NORMAL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_MPS) intersect {8, [16:256], 512, 1024} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_IN_TRANSFER} ;
    }

    CRS_HS_INTERRUPT_IN_SHORT_PKT : cross CVP_SPEED, CVP_XFER, CVP_PKT_SIZE {
        ignore_bins CRS_HS_INTERRUPT_IN_SHORT_PKT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_IN_TRANSFER} ||
            !binsof (CVP_PKT_SIZE) intersect {0, [1:511], 512, [513:1023], 1024} ;
    }

    CRS_HS_INTERRUPT_IN_BURST : cross CVP_SPEED, CVP_MPS, CVP_XFER, CVP_XFER_SIZE, CVP_BURST_SIZE {
        ignore_bins CRS_HS_INTERRUPT_IN_BURST =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_MPS) intersect {1024} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_IN_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {[2049:$]} ||
            !binsof (CVP_BURST_SIZE) intersect {0, 1, 2} ;
    }

    CRS_HS_INTERRUPT_IN_ERR_INJECT : cross CVP_SPEED, CVP_XFER, CVP_XFER_SIZE, CVP_PKT_ERR {
        ignore_bins CRS_HS_INTERRUPT_IN_ERR_INJECT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_IN_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {0, [2049:$]} ||
            !binsof (CVP_PKT_ERR) intersect {brt_usb_types::PID_ERR, brt_usb_types::CRC5_ERR, brt_usb_types::TIMEOUT_ERR} ;
    }

    CRS_HS_INTERRUPT_IN_NAK_STALL : cross CVP_SPEED, CVP_XFER, CVP_PKT_TYPE {
        ignore_bins CRS_HS_INTERRUPT_IN_NAK_STALL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_IN_TRANSFER} ||
            !binsof (CVP_PKT_TYPE) intersect {brt_usb_packet::NAK, brt_usb_packet::STALL} ;
    }

    CRS_HS_INTERRUPT_OUT_NORMAL : cross CVP_SPEED, CVP_MPS, CVP_XFER {
        ignore_bins CRS_HS_INTERRUPT_OUT_NORMAL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_MPS) intersect {8, [16:256], 512, 1024} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_OUT_TRANSFER} ;
    }

    CRS_HS_INTERRUPT_OUT_SHORT_PKT : cross CVP_SPEED, CVP_XFER, CVP_PKT_SIZE {
        ignore_bins CRS_HS_INTERRUPT_OUT_SHORT_PKT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_OUT_TRANSFER} ||
            !binsof (CVP_PKT_SIZE) intersect {0, [1:511], 512, [513:1023], 1024} ;
    }

    CRS_HS_INTERRUPT_OUT_BURST : cross CVP_SPEED, CVP_MPS, CVP_XFER, CVP_XFER_SIZE, CVP_BURST_SIZE {
        ignore_bins CRS_HS_INTERRUPT_OUT_BURST =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_MPS) intersect {1024} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_OUT_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {[2049:$]} ||
            !binsof (CVP_BURST_SIZE) intersect {0, 1, 2} ;
    }

    CRS_HS_INTERRUPT_OUT_ERR_INJECT : cross CVP_SPEED, CVP_XFER, CVP_XFER_SIZE, CVP_PKT_ERR {
        ignore_bins CRS_HS_INTERRUPT_OUT_ERR_INJECT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_OUT_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {0, [2049:$]} ||
            !binsof (CVP_PKT_ERR) intersect {brt_usb_types::PID_ERR, brt_usb_types::CRC5_ERR, brt_usb_types::CRC16_ERR, brt_usb_types::TIMEOUT_ERR} ;
    }

    CRS_HS_INTERRUPT_OUT_NAK_STALL : cross CVP_SPEED, CVP_XFER, CVP_PKT_TYPE {
        ignore_bins CRS_HS_INTERRUPT_OUT_NAK_STALL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_OUT_TRANSFER} ||
            !binsof (CVP_PKT_TYPE) intersect {brt_usb_packet::NAK, brt_usb_packet::STALL} ;
    }

    CRS_HS_ISOCHRONOUS_IN_NORMAL : cross CVP_SPEED, CVP_MPS, CVP_XFER {
        ignore_bins CRS_HS_ISOCHRONOUS_IN_NORMAL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_MPS) intersect {8, [16:256], 512, 1024} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::ISOCHRONOUS_IN_TRANSFER} ;
    }

    CRS_HS_ISOCHRONOUS_IN_BURST0 : cross CVP_SPEED, CVP_MPS, CVP_XFER, CVP_XFER_SIZE, CVP_BURST_SIZE {
        ignore_bins CRS_HS_ISOCHRONOUS_IN_BURST0 =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_MPS) intersect {1024} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::ISOCHRONOUS_IN_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {[1:1024]} ||
            !binsof (CVP_BURST_SIZE) intersect {0} ;
    }

    CRS_HS_ISOCHRONOUS_IN_BURST1 : cross CVP_SPEED, CVP_MPS, CVP_XFER, CVP_XFER_SIZE, CVP_BURST_SIZE {
        ignore_bins CRS_HS_ISOCHRONOUS_IN_BURST1 =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_MPS) intersect {1024} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::ISOCHRONOUS_IN_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {[1:1024], [1025:2048]} ||
            !binsof (CVP_BURST_SIZE) intersect {1} ;
    }

    CRS_HS_ISOCHRONOUS_IN_BURST2 : cross CVP_SPEED, CVP_MPS, CVP_XFER, CVP_XFER_SIZE, CVP_BURST_SIZE {
        ignore_bins CRS_HS_ISOCHRONOUS_IN_BURST2 =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_MPS) intersect {1024} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::ISOCHRONOUS_IN_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {[1:1024], [1025:2048], [2049:$]} ||
            !binsof (CVP_BURST_SIZE) intersect {2} ;
    }

    CRS_HS_ISOCHRONOUS_IN_ERR_INJECT : cross CVP_SPEED, CVP_XFER, CVP_PKT_ERR {
        ignore_bins CRS_HS_ISOCHRONOUS_IN_ERR_INJECT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::ISOCHRONOUS_IN_TRANSFER} ||
            !binsof (CVP_PKT_ERR) intersect {brt_usb_types::PID_ERR, brt_usb_types::CRC5_ERR} ;
    }

    CRS_HS_ISOCHRONOUS_OUT_NORMAL : cross CVP_SPEED, CVP_MPS, CVP_XFER {
        ignore_bins CRS_HS_ISOCHRONOUS_OUT_NORMAL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_MPS) intersect {8, [16:256], 512, 1024} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::ISOCHRONOUS_OUT_TRANSFER} ;
    }

    CRS_HS_ISOCHRONOUS_OUT_BURST0 : cross CVP_SPEED, CVP_MPS, CVP_XFER, CVP_XFER_SIZE, CVP_BURST_SIZE {
        ignore_bins CRS_HS_ISOCHRONOUS_OUT_BURST0 =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_MPS) intersect {1024} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::ISOCHRONOUS_OUT_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {[1:1024]} ||
            !binsof (CVP_BURST_SIZE) intersect {0} ;
    }

    CRS_HS_ISOCHRONOUS_OUT_BURST1 : cross CVP_SPEED, CVP_MPS, CVP_XFER, CVP_XFER_SIZE, CVP_BURST_SIZE {
        ignore_bins CRS_HS_ISOCHRONOUS_OUT_BURST1 =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_MPS) intersect {1024} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::ISOCHRONOUS_OUT_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {[1:1024], [1025:2048]} ||
            !binsof (CVP_BURST_SIZE) intersect {1} ;
    }

    CRS_HS_ISOCHRONOUS_OUT_BURST2 : cross CVP_SPEED, CVP_MPS, CVP_XFER, CVP_XFER_SIZE, CVP_BURST_SIZE {
        ignore_bins CRS_HS_ISOCHRONOUS_OUT_BURST2 =
            !binsof (CVP_SPEED) intersect {brt_usb_types::HS} ||
            !binsof (CVP_MPS) intersect {1024} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::ISOCHRONOUS_OUT_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {[1:1024], [1025:2048], [2049:$]} ||
            !binsof (CVP_BURST_SIZE) intersect {2} ;
    }


endgroup

covergroup CVG_FS_VIP_U20;
    CVP_ADDR : coverpoint dev_addr {
        bins VTR_ADDR_0 = {0};
        bins VTR_ADDR_1_126 = {[1:126]};
        bins VTR_ADDR_127 = {127};
    }
    CVP_SPEED : coverpoint dev_speed_e {
        bins VTR_SPEED_FS = {brt_usb_types::FS};
    }
    CVP_MPS : coverpoint max_pkt_size {
        bins VTR_MPS_8 = {8};
        bins VTR_MPS_16_256 = {[16:256]};
        bins VTR_MPS_512 = {512};
    }
    CVP_XFER : coverpoint xfer_type_e {
        bins VTR_XFER_CTRL = {brt_usb_transfer::CONTROL_TRANSFER};
        bins VTR_XFER_BULK_IN = {brt_usb_transfer::BULK_IN_TRANSFER};
        bins VTR_XFER_BULK_OUT = {brt_usb_transfer::BULK_OUT_TRANSFER};
        bins VTR_XFER_INT_IN = {brt_usb_transfer::INTERRUPT_IN_TRANSFER};
        bins VTR_XFER_INT_OUT = {brt_usb_transfer::INTERRUPT_OUT_TRANSFER};
        bins VTR_XFER_ISO_IN = {brt_usb_transfer::ISOCHRONOUS_IN_TRANSFER};
        bins VTR_XFER_ISO_OUT = {brt_usb_transfer::ISOCHRONOUS_OUT_TRANSFER};
    }
    CVP_XFER_SIZE : coverpoint xfer_size {
        bins VTR_XFER_SIZE_0 = {0};
        bins VTR_XFER_SIZE_1_1024 = {[1:1024]};
        bins VTR_XFER_SIZE_1025_2048 = {[1025:2048]};
        bins VTR_XFER_SIZE_2049_END = {[2049:$]};
    }
    CVP_PKT_SIZE : coverpoint pkt_size {
        bins VTR_PKT_SIZE_0 = {0};
        bins VTR_PKT_SIZE_1_511 = {[1:511]};
        bins VTR_PKT_SIZE_512 = {512};
        bins VTR_PKT_SIZE_513_1023 = {[513:1023]};
    }
    CVP_PKT_TYPE : coverpoint pkt_pid_e {
        bins VTR_PKT_TYPE_NAK = {brt_usb_packet::NAK};
        bins VTR_PKT_TYPE_STALL = {brt_usb_packet::STALL};
    }
    CVP_PKT_ERR : coverpoint pkt_err_e {
        bins VTR_PID_ERR = {brt_usb_types::PID_ERR};
        bins VTR_CRC5_ERR = {brt_usb_types::CRC5_ERR};
        bins VTR_CRC16_ERR = {brt_usb_types::CRC16_ERR};
        bins VTR_TIMEOUT_ERR = {brt_usb_types::TIMEOUT_ERR};
    }

    CRS_FS_CONTROL_NORMAL : cross CVP_SPEED, CVP_MPS, CVP_XFER, CVP_XFER_SIZE {
        ignore_bins CRS_FS_CONTROL_NORMAL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_MPS) intersect {8, [16:256]} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::CONTROL_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {0, [1:1024]} ;
    }

    CRS_FS_CONTROL_SHORT_PKT : cross CVP_SPEED, CVP_XFER, CVP_PKT_SIZE {
        ignore_bins CRS_FS_CONTROL_SHORT_PKT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::CONTROL_TRANSFER} ||
            !binsof (CVP_PKT_SIZE) intersect {0, [1:511]} ;
    }

    CRS_FS_CONTROL_DATA_STAGE_ERR_INJECT : cross CVP_SPEED, CVP_XFER, CVP_PKT_ERR {
        ignore_bins CRS_FS_CONTROL_DATA_STAGE_ERR_INJECT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::CONTROL_TRANSFER} ||
            !binsof (CVP_PKT_ERR) intersect {brt_usb_types::PID_ERR, brt_usb_types::CRC5_ERR, brt_usb_types::CRC16_ERR, brt_usb_types::TIMEOUT_ERR} ;
    }

    CRS_FS_CONTROL_DATA_STAGE_NAK_NYET_STALL : cross CVP_SPEED, CVP_XFER, CVP_PKT_TYPE {
        ignore_bins CRS_FS_CONTROL_DATA_STAGE_NAK_NYET_STALL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::CONTROL_TRANSFER} ||
            !binsof (CVP_PKT_TYPE) intersect {brt_usb_packet::NAK, brt_usb_packet::STALL} ;
    }

    CRS_FS_BULK_IN_NORMAL : cross CVP_SPEED, CVP_MPS, CVP_XFER, CVP_XFER_SIZE {
        ignore_bins CRS_FS_BULK_IN_NORMAL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_MPS) intersect {[16:256]} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::BULK_IN_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {0, [1:1024]} ;
    }

    CRS_FS_BULK_IN_SHORT_PKT : cross CVP_SPEED, CVP_XFER, CVP_PKT_SIZE {
        ignore_bins CRS_FS_BULK_IN_SHORT_PKT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::BULK_IN_TRANSFER} ||
            !binsof (CVP_PKT_SIZE) intersect {0, [1:511]} ;
    }

    CRS_FS_BULK_IN_ERR_INJECT : cross CVP_SPEED, CVP_XFER, CVP_XFER_SIZE, CVP_PKT_ERR {
        ignore_bins CRS_FS_BULK_IN_ERR_INJECT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::BULK_IN_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {0, [1:1024]} ||
            !binsof (CVP_PKT_ERR) intersect {brt_usb_types::PID_ERR, brt_usb_types::CRC5_ERR, brt_usb_types::TIMEOUT_ERR} ;
    }

    CRS_FS_BULK_IN_NAK_STALL : cross CVP_SPEED, CVP_XFER, CVP_PKT_TYPE {
        ignore_bins CRS_FS_BULK_IN_NAK_STALL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::BULK_IN_TRANSFER} ||
            !binsof (CVP_PKT_TYPE) intersect {brt_usb_packet::NAK, brt_usb_packet::STALL} ;
    }

    CRS_FS_BULK_OUT_NORMAL : cross CVP_SPEED, CVP_MPS, CVP_XFER, CVP_XFER_SIZE {
        ignore_bins CRS_FS_BULK_OUT_NORMAL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_MPS) intersect {[16:256]} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::BULK_OUT_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {0, [1:1024]} ;
    }

    CRS_FS_BULK_OUT_SHORT_PKT : cross CVP_SPEED, CVP_XFER, CVP_PKT_SIZE {
        ignore_bins CRS_FS_BULK_OUT_SHORT_PKT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::BULK_OUT_TRANSFER} ||
            !binsof (CVP_PKT_SIZE) intersect {0, [1:511]} ;
    }

    CRS_FS_BULK_OUT_ERR_INJECT : cross CVP_SPEED, CVP_XFER, CVP_XFER_SIZE, CVP_PKT_ERR {
        ignore_bins CRS_FS_BULK_OUT_ERR_INJECT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::BULK_OUT_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {0, [1:1024]} ||
            !binsof (CVP_PKT_ERR) intersect {brt_usb_types::PID_ERR, brt_usb_types::CRC5_ERR, brt_usb_types::CRC16_ERR, brt_usb_types::TIMEOUT_ERR} ;
    }

    CRS_FS_BULK_OUT_NAK_NYET_STALL : cross CVP_SPEED, CVP_XFER, CVP_PKT_TYPE {
        ignore_bins CRS_FS_BULK_OUT_NAK_NYET_STALL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::BULK_OUT_TRANSFER} ||
            !binsof (CVP_PKT_TYPE) intersect {brt_usb_packet::NAK, brt_usb_packet::STALL} ;
    }

    CRS_FS_INTERRUPT_IN_NORMAL : cross CVP_SPEED, CVP_MPS, CVP_XFER {
        ignore_bins CRS_FS_INTERRUPT_IN_NORMAL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_MPS) intersect {8, [16:256]} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_IN_TRANSFER} ;
    }

    CRS_FS_INTERRUPT_IN_SHORT_PKT : cross CVP_SPEED, CVP_XFER, CVP_PKT_SIZE {
        ignore_bins CRS_FS_INTERRUPT_IN_SHORT_PKT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_IN_TRANSFER} ||
            !binsof (CVP_PKT_SIZE) intersect {0, [1:511]} ;
    }

    CRS_FS_INTERRUPT_IN_ERR_INJECT : cross CVP_SPEED, CVP_XFER, CVP_XFER_SIZE, CVP_PKT_ERR {
        ignore_bins CRS_FS_INTERRUPT_IN_ERR_INJECT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_IN_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {0, [1:1024]} ||
            !binsof (CVP_PKT_ERR) intersect {brt_usb_types::PID_ERR, brt_usb_types::CRC5_ERR, brt_usb_types::TIMEOUT_ERR} ;
    }

    CRS_FS_INTERRUPT_IN_NAK_STALL : cross CVP_SPEED, CVP_XFER, CVP_PKT_TYPE {
        ignore_bins CRS_FS_INTERRUPT_IN_NAK_STALL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_IN_TRANSFER} ||
            !binsof (CVP_PKT_TYPE) intersect {brt_usb_packet::NAK, brt_usb_packet::STALL} ;
    }

    CRS_FS_INTERRUPT_OUT_NORMAL : cross CVP_SPEED, CVP_MPS, CVP_XFER {
        ignore_bins CRS_FS_INTERRUPT_OUT_NORMAL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_MPS) intersect {8, [16:256]} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_OUT_TRANSFER} ;
    }

    CRS_FS_INTERRUPT_OUT_SHORT_PKT : cross CVP_SPEED, CVP_XFER, CVP_PKT_SIZE {
        ignore_bins CRS_FS_INTERRUPT_OUT_SHORT_PKT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_OUT_TRANSFER} ||
            !binsof (CVP_PKT_SIZE) intersect {0, [1:511]} ;
    }

    CRS_FS_INTERRUPT_OUT_ERR_INJECT : cross CVP_SPEED, CVP_XFER, CVP_XFER_SIZE, CVP_PKT_ERR {
        ignore_bins CRS_FS_INTERRUPT_OUT_ERR_INJECT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_OUT_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {0, [1:1024]} ||
            !binsof (CVP_PKT_ERR) intersect {brt_usb_types::PID_ERR, brt_usb_types::CRC5_ERR, brt_usb_types::CRC16_ERR, brt_usb_types::TIMEOUT_ERR} ;
    }

    CRS_FS_INTERRUPT_OUT_NAK_STALL : cross CVP_SPEED, CVP_XFER, CVP_PKT_TYPE {
        ignore_bins CRS_FS_INTERRUPT_OUT_NAK_STALL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_OUT_TRANSFER} ||
            !binsof (CVP_PKT_TYPE) intersect {brt_usb_packet::NAK, brt_usb_packet::STALL} ;
    }

    CRS_FS_ISOCHRONOUS_IN_NORMAL : cross CVP_SPEED, CVP_MPS, CVP_XFER {
        ignore_bins CRS_FS_ISOCHRONOUS_IN_NORMAL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_MPS) intersect {8, [16:256], 512} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::ISOCHRONOUS_IN_TRANSFER} ;
    }

    CRS_FS_ISOCHRONOUS_IN_ERR_INJECT : cross CVP_SPEED, CVP_XFER, CVP_PKT_ERR {
        ignore_bins CRS_FS_ISOCHRONOUS_IN_ERR_INJECT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::ISOCHRONOUS_IN_TRANSFER} ||
            !binsof (CVP_PKT_ERR) intersect {brt_usb_types::PID_ERR, brt_usb_types::CRC5_ERR} ;
    }

    CRS_FS_ISOCHRONOUS_OUT_NORMAL : cross CVP_SPEED, CVP_MPS, CVP_XFER {
        ignore_bins CRS_FS_ISOCHRONOUS_OUT_NORMAL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::FS} ||
            !binsof (CVP_MPS) intersect {8, [16:256], 512} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::ISOCHRONOUS_OUT_TRANSFER} ;
    }


endgroup

covergroup CVG_LS_VIP_U20;
    CVP_ADDR : coverpoint dev_addr {
        bins VTR_ADDR_0 = {0};
        bins VTR_ADDR_1_126 = {[1:126]};
        bins VTR_ADDR_127 = {127};
    }
    CVP_SPEED : coverpoint dev_speed_e {
        bins VTR_SPEED_LS = {brt_usb_types::LS};
    }
    CVP_MPS : coverpoint max_pkt_size {
        bins VTR_MPS_8 = {8};
    }
    CVP_XFER : coverpoint xfer_type_e {
        bins VTR_XFER_CTRL = {brt_usb_transfer::CONTROL_TRANSFER};
        bins VTR_XFER_INT_IN = {brt_usb_transfer::INTERRUPT_IN_TRANSFER};
        bins VTR_XFER_INT_OUT = {brt_usb_transfer::INTERRUPT_OUT_TRANSFER};
    }
    CVP_XFER_SIZE : coverpoint xfer_size {
        bins VTR_XFER_SIZE_0 = {0};
        bins VTR_XFER_SIZE_1_1024 = {[1:1024]};
    }
    CVP_PKT_SIZE : coverpoint pkt_size {
        bins VTR_PKT_SIZE_0 = {0};
        bins VTR_PKT_SIZE_1_511 = {[1:511]};
    }
    CVP_PKT_TYPE : coverpoint pkt_pid_e {
        bins VTR_PKT_TYPE_NAK = {brt_usb_packet::NAK};
        bins VTR_PKT_TYPE_STALL = {brt_usb_packet::STALL};
    }
    CVP_PKT_ERR : coverpoint pkt_err_e {
        bins VTR_PID_ERR = {brt_usb_types::PID_ERR};
        bins VTR_CRC5_ERR = {brt_usb_types::CRC5_ERR};
        bins VTR_CRC16_ERR = {brt_usb_types::CRC16_ERR};
        bins VTR_TIMEOUT_ERR = {brt_usb_types::TIMEOUT_ERR};
    }

    CRS_LS_CONTROL_NORMAL : cross CVP_SPEED, CVP_MPS, CVP_XFER, CVP_XFER_SIZE {
        ignore_bins CRS_LS_CONTROL_NORMAL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::LS} ||
            !binsof (CVP_MPS) intersect {8} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::CONTROL_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {0, [1:1024]} ;
    }

    CRS_LS_CONTROL_SHORT_PKT : cross CVP_SPEED, CVP_XFER, CVP_PKT_SIZE {
        ignore_bins CRS_LS_CONTROL_SHORT_PKT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::LS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::CONTROL_TRANSFER} ||
            !binsof (CVP_PKT_SIZE) intersect {0, [1:511]} ;
    }

    CRS_LS_CONTROL_DATA_STAGE_ERR_INJECT : cross CVP_SPEED, CVP_XFER, CVP_PKT_ERR {
        ignore_bins CRS_LS_CONTROL_DATA_STAGE_ERR_INJECT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::LS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::CONTROL_TRANSFER} ||
            !binsof (CVP_PKT_ERR) intersect {brt_usb_types::PID_ERR, brt_usb_types::CRC5_ERR, brt_usb_types::CRC16_ERR, brt_usb_types::TIMEOUT_ERR} ;
    }

    CRS_LS_CONTROL_DATA_STAGE_NAK_NYET_STALL : cross CVP_SPEED, CVP_XFER, CVP_PKT_TYPE {
        ignore_bins CRS_LS_CONTROL_DATA_STAGE_NAK_NYET_STALL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::LS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::CONTROL_TRANSFER} ||
            !binsof (CVP_PKT_TYPE) intersect {brt_usb_packet::NAK, brt_usb_packet::STALL} ;
    }

    CRS_LS_INTERRUPT_IN_NORMAL : cross CVP_SPEED, CVP_MPS, CVP_XFER {
        ignore_bins CRS_LS_INTERRUPT_IN_NORMAL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::LS} ||
            !binsof (CVP_MPS) intersect {8} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_IN_TRANSFER} ;
    }

    CRS_LS_INTERRUPT_IN_SHORT_PKT : cross CVP_SPEED, CVP_XFER, CVP_PKT_SIZE {
        ignore_bins CRS_LS_INTERRUPT_IN_SHORT_PKT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::LS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_IN_TRANSFER} ||
            !binsof (CVP_PKT_SIZE) intersect {0, [1:511]} ;
    }

    CRS_LS_INTERRUPT_IN_ERR_INJECT : cross CVP_SPEED, CVP_XFER, CVP_XFER_SIZE, CVP_PKT_ERR {
        ignore_bins CRS_LS_INTERRUPT_IN_ERR_INJECT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::LS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_IN_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {0, [1:1024]} ||
            !binsof (CVP_PKT_ERR) intersect {brt_usb_types::PID_ERR, brt_usb_types::CRC5_ERR, brt_usb_types::TIMEOUT_ERR} ;
    }

    CRS_LS_INTERRUPT_IN_NAK_STALL : cross CVP_SPEED, CVP_XFER, CVP_PKT_TYPE {
        ignore_bins CRS_LS_INTERRUPT_IN_NAK_STALL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::LS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_IN_TRANSFER} ||
            !binsof (CVP_PKT_TYPE) intersect {brt_usb_packet::NAK, brt_usb_packet::STALL} ;
    }

    CRS_LS_INTERRUPT_OUT_NORMAL : cross CVP_SPEED, CVP_MPS, CVP_XFER {
        ignore_bins CRS_LS_INTERRUPT_OUT_NORMAL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::LS} ||
            !binsof (CVP_MPS) intersect {8} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_OUT_TRANSFER} ;
    }

    CRS_LS_INTERRUPT_OUT_SHORT_PKT : cross CVP_SPEED, CVP_XFER, CVP_PKT_SIZE {
        ignore_bins CRS_LS_INTERRUPT_OUT_SHORT_PKT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::LS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_OUT_TRANSFER} ||
            !binsof (CVP_PKT_SIZE) intersect {0, [1:511]} ;
    }

    CRS_LS_INTERRUPT_OUT_ERR_INJECT : cross CVP_SPEED, CVP_XFER, CVP_XFER_SIZE, CVP_PKT_ERR {
        ignore_bins CRS_LS_INTERRUPT_OUT_ERR_INJECT =
            !binsof (CVP_SPEED) intersect {brt_usb_types::LS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_OUT_TRANSFER} ||
            !binsof (CVP_XFER_SIZE) intersect {0, [1:1024]} ||
            !binsof (CVP_PKT_ERR) intersect {brt_usb_types::PID_ERR, brt_usb_types::CRC5_ERR, brt_usb_types::CRC16_ERR, brt_usb_types::TIMEOUT_ERR} ;
    }

    CRS_LS_INTERRUPT_OUT_NAK_STALL : cross CVP_SPEED, CVP_XFER, CVP_PKT_TYPE {
        ignore_bins CRS_LS_INTERRUPT_OUT_NAK_STALL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::LS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::INTERRUPT_OUT_TRANSFER} ||
            !binsof (CVP_PKT_TYPE) intersect {brt_usb_packet::NAK, brt_usb_packet::STALL} ;
    }


endgroup

// LPM
covergroup CVG_LPM_VIP_U20;
    CVP_SPEED : coverpoint dev_speed_e {
        bins VTR_SPEED_LS = {brt_usb_types::LS};
        bins VTR_SPEED_FS = {brt_usb_types::FS};
        bins VTR_SPEED_HS = {brt_usb_types::HS};
    }
    CVP_XFER : coverpoint xfer_type_e {
        bins VTR_XFER_LPM = {brt_usb_transfer::LPM_TRANSFER};
    }

    CRS_LPM_NORMAL : cross CVP_SPEED, CVP_XFER {
        ignore_bins CRS_LPM_NORMAL =
            !binsof (CVP_SPEED) intersect {brt_usb_types::LS, brt_usb_types::FS, brt_usb_types::HS} ||
            !binsof (CVP_XFER) intersect {brt_usb_transfer::LPM_TRANSFER} ;
    }


endgroup

covergroup CVG_TIMING_VIP_U20;
    CVP_LS_INTKNDATA : coverpoint ls_in_tkn_to_data {
        bins VTR_LS_INTKNDATA_0_1332 = {[0:1332]};
        bins VTR_LS_INTKNDATA_1333_1932 = {[1333:1932]};
        bins VTR_LS_INTKNDATA_1933_2532 = {[1933:2532]};
        bins VTR_LS_INTKNDATA_2533_3132 = {[2533:3132]};
        bins VTR_LS_INTKNDATA_3133_3732 = {[3133:3732]};
        bins VTR_LS_INTKNDATA_3733_4332 = {[3733:4332]};
        bins VTR_LS_INTKNDATA_4333_4932 = {[4333:4932]};
        bins VTR_LS_INTKNDATA_4933_5532 = {[4933:5532]};
        bins VTR_LS_INTKNDATA_5533_END = {[5533:$]};
    }
    CVP_LS_INDATAACK : coverpoint ls_in_data_to_ack {
        bins VTR_LS_INDATAACK_0_1332 = {[0:1332]};
        bins VTR_LS_INDATAACK_1333_1932 = {[1333:1932]};
        bins VTR_LS_INDATAACK_1933_2532 = {[1933:2532]};
        bins VTR_LS_INDATAACK_2533_3132 = {[2533:3132]};
        bins VTR_LS_INDATAACK_3133_3732 = {[3133:3732]};
        bins VTR_LS_INDATAACK_3733_4332 = {[3733:4332]};
        bins VTR_LS_INDATAACK_4333_4932 = {[4333:4932]};
        bins VTR_LS_INDATAACK_4933_5532 = {[4933:5532]};
        bins VTR_LS_INDATAACK_5533_END = {[5533:$]};
    }
    CVP_LS_OUTTKNDATA : coverpoint ls_out_tkn_to_data {
        bins VTR_LS_OUTTKNDATA_0_1332 = {[0:1332]};
        bins VTR_LS_OUTTKNDATA_1333_1932 = {[1333:1932]};
        bins VTR_LS_OUTTKNDATA_1933_2532 = {[1933:2532]};
        bins VTR_LS_OUTTKNDATA_2533_3132 = {[2533:3132]};
        bins VTR_LS_OUTTKNDATA_3133_3732 = {[3133:3732]};
        bins VTR_LS_OUTTKNDATA_3733_4332 = {[3733:4332]};
        bins VTR_LS_OUTTKNDATA_4333_4932 = {[4333:4932]};
        bins VTR_LS_OUTTKNDATA_4933_5532 = {[4933:5532]};
        bins VTR_LS_OUTTKNDATA_5533_END = {[5533:$]};
    }
    CVP_LS_OUTDATAACK : coverpoint ls_out_data_to_ack {
        bins VTR_LS_OUTDATAACK_0_1332 = {[0:1332]};
        bins VTR_LS_OUTDATAACK_1333_1932 = {[1333:1932]};
        bins VTR_LS_OUTDATAACK_1933_2532 = {[1933:2532]};
        bins VTR_LS_OUTDATAACK_2533_3132 = {[2533:3132]};
        bins VTR_LS_OUTDATAACK_3133_3732 = {[3133:3732]};
        bins VTR_LS_OUTDATAACK_3733_4332 = {[3733:4332]};
        bins VTR_LS_OUTDATAACK_4333_4932 = {[4333:4932]};
        bins VTR_LS_OUTDATAACK_4933_5532 = {[4933:5532]};
        bins VTR_LS_OUTDATAACK_5533_END = {[5533:$]};
    }
    CVP_FS_INTKNDATA : coverpoint fs_in_tkn_to_data {
        bins VTR_FS_INTKNDATA_0_165 = {[0:165]};
        bins VTR_FS_INTKNDATA_166_228 = {[166:228]};
        bins VTR_FS_INTKNDATA_229_291 = {[229:291]};
        bins VTR_FS_INTKNDATA_292_354 = {[292:354]};
        bins VTR_FS_INTKNDATA_355_417 = {[355:417]};
        bins VTR_FS_INTKNDATA_418_480 = {[418:480]};
        bins VTR_FS_INTKNDATA_481_543 = {[481:543]};
        bins VTR_FS_INTKNDATA_544_606 = {[544:606]};
        bins VTR_FS_INTKNDATA_607_END = {[607:$]};
    }
    CVP_FS_INDATAACK : coverpoint fs_in_data_to_ack {
        bins VTR_FS_INDATAACK_0_165 = {[0:165]};
        bins VTR_FS_INDATAACK_166_228 = {[166:228]};
        bins VTR_FS_INDATAACK_229_291 = {[229:291]};
        bins VTR_FS_INDATAACK_292_354 = {[292:354]};
        bins VTR_FS_INDATAACK_355_417 = {[355:417]};
        bins VTR_FS_INDATAACK_418_480 = {[418:480]};
        bins VTR_FS_INDATAACK_481_543 = {[481:543]};
        bins VTR_FS_INDATAACK_544_606 = {[544:606]};
        bins VTR_FS_INDATAACK_607_END = {[607:$]};
    }
    CVP_FS_OUTTKNDATA : coverpoint fs_out_tkn_to_data {
        bins VTR_FS_OUTTKNDATA_0_165 = {[0:165]};
        bins VTR_FS_OUTTKNDATA_166_228 = {[166:228]};
        bins VTR_FS_OUTTKNDATA_229_291 = {[229:291]};
        bins VTR_FS_OUTTKNDATA_292_354 = {[292:354]};
        bins VTR_FS_OUTTKNDATA_355_417 = {[355:417]};
        bins VTR_FS_OUTTKNDATA_418_480 = {[418:480]};
        bins VTR_FS_OUTTKNDATA_481_543 = {[481:543]};
        bins VTR_FS_OUTTKNDATA_544_606 = {[544:606]};
        bins VTR_FS_OUTTKNDATA_607_END = {[607:$]};
    }
    CVP_FS_OUTDATAACK : coverpoint fs_out_data_to_ack {
        bins VTR_FS_OUTDATAACK_0_165 = {[0:165]};
        bins VTR_FS_OUTDATAACK_166_228 = {[166:228]};
        bins VTR_FS_OUTDATAACK_229_291 = {[229:291]};
        bins VTR_FS_OUTDATAACK_292_354 = {[292:354]};
        bins VTR_FS_OUTDATAACK_355_417 = {[355:417]};
        bins VTR_FS_OUTDATAACK_418_480 = {[418:480]};
        bins VTR_FS_OUTDATAACK_481_543 = {[481:543]};
        bins VTR_FS_OUTDATAACK_544_606 = {[544:606]};
        bins VTR_FS_OUTDATAACK_607_END = {[607:$]};
    }
    CVP_HS_INTKNDATA : coverpoint hs_in_tkn_to_data {
        bins VTR_HS_INTKNDATA_0_15 = {[0:15]};
        bins VTR_HS_INTKNDATA_16_79 = {[16:79]};
        bins VTR_HS_INTKNDATA_80_143 = {[80:143]};
        bins VTR_HS_INTKNDATA_144_207 = {[144:207]};
        bins VTR_HS_INTKNDATA_208_271 = {[208:271]};
        bins VTR_HS_INTKNDATA_272_335 = {[272:335]};
        bins VTR_HS_INTKNDATA_336_399 = {[336:399]};
        bins VTR_HS_INTKNDATA_400_463 = {[400:463]};
        bins VTR_HS_INTKNDATA_464_END = {[464:$]};
    }
    CVP_HS_INDATAACK : coverpoint hs_in_data_to_ack {
        bins VTR_HS_INDATAACK_0_15 = {[0:15]};
        bins VTR_HS_INDATAACK_16_79 = {[16:79]};
        bins VTR_HS_INDATAACK_80_143 = {[80:143]};
        bins VTR_HS_INDATAACK_144_207 = {[144:207]};
        bins VTR_HS_INDATAACK_208_271 = {[208:271]};
        bins VTR_HS_INDATAACK_272_335 = {[272:335]};
        bins VTR_HS_INDATAACK_336_399 = {[336:399]};
        bins VTR_HS_INDATAACK_400_463 = {[400:463]};
        bins VTR_HS_INDATAACK_464_END = {[464:$]};
    }
    CVP_HS_OUTTKNDATA : coverpoint hs_out_tkn_to_data {
        bins VTR_HS_OUTTKNDATA_0_15 = {[0:15]};
        bins VTR_HS_OUTTKNDATA_16_79 = {[16:79]};
        bins VTR_HS_OUTTKNDATA_80_143 = {[80:143]};
        bins VTR_HS_OUTTKNDATA_144_207 = {[144:207]};
        bins VTR_HS_OUTTKNDATA_208_271 = {[208:271]};
        bins VTR_HS_OUTTKNDATA_272_335 = {[272:335]};
        bins VTR_HS_OUTTKNDATA_336_399 = {[336:399]};
        bins VTR_HS_OUTTKNDATA_400_463 = {[400:463]};
        bins VTR_HS_OUTTKNDATA_464_END = {[464:$]};
    }
    CVP_HS_OUTDATAACK : coverpoint hs_out_data_to_ack {
        bins VTR_HS_OUTDATAACK_0_15 = {[0:15]};
        bins VTR_HS_OUTDATAACK_16_79 = {[16:79]};
        bins VTR_HS_OUTDATAACK_80_143 = {[80:143]};
        bins VTR_HS_OUTDATAACK_144_207 = {[144:207]};
        bins VTR_HS_OUTDATAACK_208_271 = {[208:271]};
        bins VTR_HS_OUTDATAACK_272_335 = {[272:335]};
        bins VTR_HS_OUTDATAACK_336_399 = {[336:399]};
        bins VTR_HS_OUTDATAACK_400_463 = {[400:463]};
        bins VTR_HS_OUTDATAACK_464_END = {[464:$]};
    }


endgroup
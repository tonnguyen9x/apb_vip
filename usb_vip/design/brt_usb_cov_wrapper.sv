class brt_usb_cov_wrapper extends brt_object;
    `brt_object_utils(brt_usb_cov_wrapper)
    //`brt_object_utils_begin
    //`brt_object_utils_end

    function new (string name = "brt_usb_cov_wrapper");
        CVG_HS_VIP_U20      = new();
        CVG_FS_VIP_U20      = new();
        CVG_LS_VIP_U20      = new();
        CVG_LPM_VIP_U20     = new();
        CVG_TIMING_VIP_U20  = new();
    endfunction
    `include "brt_usb_cov_vip.sv";
endclass

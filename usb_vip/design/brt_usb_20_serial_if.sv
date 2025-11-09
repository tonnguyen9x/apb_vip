`ifndef FORK_GUARD_BEGIN
  `define FORK_GUARD_BEGIN fork begin
  `define FORK_GUARD_END   end join
`endif


interface brt_usb_20_serial_if();
  `include "brt_usb_timescale.sv"
  import  brt_usb_pkg::*;
  wor     dp, dm;
  logic     clk;
  wire     vbus;
  logic     dut_hs_termination, vip_hs_termination;
  logic     tx_dp, tx_dm, rx_dp, rx_dm;
  
  bit   dp_pu, dm_pu;
  bit   se0_en;
  bit   tx_en; 
  bit   hs_enable;
  bit   is_suspended=1;
  bit   prev_is_suspended=1;
  event debug0, debug1, debug2, debug3, debug4;
  event debug5, debug6, debug7, debug8, debug9;

  logic  is_host                 = 1;
  //bit [2:0]  speed               = 1;     // 0: LS, 1: FS, 2: HS 
  brt_usb_types::speed_e        speed = brt_usb_types::FS;
  logic  speed_handshake_done    = 0;     

  bit    config_update = 0;
  real   ls_fs_eop_se0_2_j_margin = 0.0025;

  assign rx_dp                     = dp;
  assign rx_dm                     = dm;
  
  // Host
  assign (`BRT_USB_HOST_DRIVE_STRENGTH_PU_0    , `BRT_USB_HOST_DRIVE_STRENGTH_PU_1   ) dp = is_host?  (dm_pu ? tx_dp:1'bz): 1'bz;  // Pull down host side
  assign (`BRT_USB_HOST_DRIVE_STRENGTH_SE0_0   , `BRT_USB_HOST_DRIVE_STRENGTH_SE0_1  ) dp = is_host?  (se0_en? tx_dp:1'bz): 1'bz;
  assign (`BRT_USB_HOST_DRIVE_STRENGTH_TX_0    , `BRT_USB_HOST_DRIVE_STRENGTH_TX_1   ) dp = is_host?  (tx_en ? tx_dp:1'bz): 1'bz;
  assign (`BRT_USB_HOST_DRIVE_STRENGTH_PU_0    , `BRT_USB_HOST_DRIVE_STRENGTH_PU_1   ) dm = is_host?  (dm_pu ? tx_dm:1'bz): 1'bz;  // Pull down host side
  assign (`BRT_USB_HOST_DRIVE_STRENGTH_SE0_0   , `BRT_USB_HOST_DRIVE_STRENGTH_SE0_1  ) dm = is_host?  (se0_en? tx_dm:1'bz): 1'bz;  // Use
  assign (`BRT_USB_HOST_DRIVE_STRENGTH_TX_0    , `BRT_USB_HOST_DRIVE_STRENGTH_TX_1   ) dm = is_host?  (tx_en ? tx_dm:1'bz): 1'bz;
  // Device
  assign (`BRT_USB_DEVICE_DRIVE_STRENGTH_PU_0  , `BRT_USB_DEVICE_DRIVE_STRENGTH_PU_1 ) dp = !is_host? (dp_pu ? tx_dp:1'bz): 1'bz;
  assign (`BRT_USB_DEVICE_DRIVE_STRENGTH_SE0_0 , `BRT_USB_DEVICE_DRIVE_STRENGTH_SE0_1) dp = !is_host? (se0_en? tx_dp:1'bz): 1'bz;
  assign (`BRT_USB_DEVICE_DRIVE_STRENGTH_TX_0  , `BRT_USB_DEVICE_DRIVE_STRENGTH_TX_1 ) dp = !is_host? (tx_en ? tx_dp:1'bz): 1'bz;
  assign (`BRT_USB_DEVICE_DRIVE_STRENGTH_PU_0  , `BRT_USB_DEVICE_DRIVE_STRENGTH_PU_1 ) dm = !is_host? (dm_pu ? tx_dm:1'bz): 1'bz;
  assign (`BRT_USB_DEVICE_DRIVE_STRENGTH_SE0_0 , `BRT_USB_DEVICE_DRIVE_STRENGTH_SE0_1) dm = !is_host? (se0_en? tx_dm:1'bz): 1'bz;
  assign (`BRT_USB_DEVICE_DRIVE_STRENGTH_TX_0  , `BRT_USB_DEVICE_DRIVE_STRENGTH_TX_1 ) dm = !is_host? (tx_en ? tx_dm:1'bz): 1'bz;
  
  /* Connect and Disconnect Signalling
  Spec 7.1.7.3
  When no function is attached to the downstream facing port of a host or hub in
  low-/full-speed, the pull-down
  resistors present there will cause both D+ and D- to be pulled below the
  single-ended low threshold of the host
  or hub transceiver when that port is not being driven by the hub.
  */
  logic connected=0;
  
  // A disconnect condition is indicated if the host or hub is not driving
  // the data lines and an SE0 persists on a downstream facing port for more than TDDIS
  // A disconnect condition is indicated if the host or hub is not driving the data
  // lines and an SE0 persists on a downstream facing port for more than TDDIS
  time tddis;
  time tdcnn;
  
  ///////////// BEGIN TX CLOCK               ///////////////////
  event gen_tx_clk_e, kill_tx_clk_e;
  logic tx_clk                  = 0;
  logic do_tx                   = 0;
  bit[63:0] clk_txperiod        =2083;
  bit[63:0] clk_txhalfperiod    =1041;
  bit[63:0] clk_txhighperiod, clk_txlowperiod;

  task wait_tx_high_delay();

    /*if (clk_txperiod[0]) #1ps; 
    #(clk_txhalfperiod*1ps);*/
    #(clk_txhighperiod*1ps);
  endtask

  task wait_tx_low_delay();
    //#(clk_txhalfperiod*1ps);
    #(clk_txlowperiod*1ps);
  endtask

  initial forever begin
    if (speed == brt_usb_types::LS) begin 
      // LS 1.5Mhz
      clk_txperiod     = 666667;  // ps
      clk_txhalfperiod = 333333;

      clk_txhighperiod = 333334;
      clk_txlowperiod  = 333333;
      end
    else if (speed == brt_usb_types::FS) begin 
      // FS
      clk_txperiod     = 83320;
      clk_txhalfperiod = 41660;

      clk_txhighperiod = 41660;
      clk_txlowperiod  = 41660;
      end
    else begin
      // HS
      clk_txperiod     = 2083;
      clk_txhalfperiod = 1041;

      clk_txhighperiod = 1042;
      clk_txlowperiod  = 1041;

      end
    @speed;
    end
  // driver cotrol to tx data
  initial forever begin 
    @gen_tx_clk_e; 
    do_tx = 1;
    `FORK_GUARD_BEGIN
      fork
        begin
            @kill_tx_clk_e; 
            do_tx = 0; 
        end
        forever begin : BLK_TX_CLK_GEN
          tx_clk = 1;
          wait_tx_high_delay();
          tx_clk = 0;
          wait_tx_low_delay();
        end : BLK_TX_CLK_GEN
      join_any
      tx_clk = 0;
      disable fork;
    `FORK_GUARD_END
    end
  ///////////// END   TX CLOCK               ///////////////////

  ///////////// BEGIN RX CLOCK DATA RECOVERY ///////////////////

  event pos_jitter, neg_jitter;
  event gen_clk_e, kill_clk_e;
  event rx_data_e;

  logic rx_clk_fd        = 0;    // clock recovery after frequency detection
  logic rx_clk_fdpd      = 0;    // clock recovery after frequency detection and phase detection
  
  time total_time, t1, t2; 
  bit[63:0] clk_period, clk_halfperiod;
  bit[63:0] clk_highperiod, clk_lowperiod;

  task wait_dm_logic_change();

    if (dm==1) @(negedge dm);
    else @(posedge dm);

  endtask

  task wait_dp_logic_change();

    if (dp==1) @(negedge dp);
    else @(posedge dp);

  endtask
 
  function void display_fatal();
    $display("Fatal Error %s", is_host ? "HOST" : "DEVICE");
  endfunction

  task wait_ls_dpdm_idle();
    time starttime, endtime, duration;

    // in LS, idle is dm HIGH, dp LOW (J)
    if (prev_is_suspended) begin
      wait (dp == 0 && dm == 1);  // Wait J ???
      end
    else begin
      do begin
        #1ps; 
        wait (dp == 0 && dm == 0);
        starttime=$time; #0;
        `FORK_GUARD_BEGIN
          fork
            //#175ns;
            `ifdef OLD_CODE
            @(!dp); // added inv to filter out drive strength
            @(!dm);
            `else
            // filter-out small glitch in analog phy model
            do begin @(!dp); #1ns; end while (dp == 0);
            do begin @(!dm); #1ns; end while (dm == 0);
            `endif
            join_any
          endtime=$time;
          duration = endtime - starttime;
          if (duration < 1250ns) begin
//            #10ns;
//            display_fatal(); 
//            $fatal; 
            $display("ERROR %s : EoP SE0 interval < 1.25 us", is_host ? "HOST" : "DEVICE");
          end
          #0;
          disable fork;
        `FORK_GUARD_END
        end while (dp != 0 || dm != 1);
        end
  endtask

  task wait_fs_dpdm_idle();
    time starttime, endtime, duration;

    // in FS, idle is dp HIGH, dm LOW (J)
    config_update = 1;
    if (prev_is_suspended) begin
      wait (dp == 1 && dm == 0);  // Wait J ???
      end
    else begin
      do begin
        #1ps; 
        wait (dp == 0 && dm == 0);
        starttime=$time; #0;
        `FORK_GUARD_BEGIN
          fork
            //#175ns;
            `ifdef OLD_CODE
            @(!dp); // added inv to filter out drive strength
            @(!dm);
            `else
            // Issue 1 : filter-out small glitch in analog phy model
            // Issue 2 : SE0 from source ranging from 160ns to 175ns
            //           wait for 175ns - clk_period before capture J state
//            do begin @(!dp); #1ns; end while (dp == 0);
//            do begin @(!dm); #1ns; end while (dm == 0);
            do begin @(!dp); #(((175 - clk_period*2/1000) + ls_fs_eop_se0_2_j_margin*clk_period*2/1000)*1ns); end while (dp == 0);
            do begin @(!dm); #(((175 - clk_period*2/1000) + ls_fs_eop_se0_2_j_margin*clk_period*2/1000)*1ns); end while (dm == 0);
            `endif
            join_any
          endtime=$time;
          duration = endtime - starttime;
          if (duration < 160ns) begin
//            #10ns;
//            display_fatal(); 
//            $fatal; 
            $display("ERROR %s : EoP SE0 interval < 160 ns", is_host ? "HOST" : "DEVICE");
          end
          #0;
          disable fork;
        `FORK_GUARD_END
        end while (dp != 1 || dm != 0);
        end
    config_update = 0;
  endtask

  task wait_hs_dpdm_idle();
    do begin
      wait (dp === 1'b0 && dm === 1'b0);
      //#1ps;
      repeat (2) begin
        wait_high_delay();
        wait_low_delay();
      end
    end while (dp !== 1'b0 || dm !== 1'b0);
  endtask

  // wait for sync pattern and calculate bit period
  task calculate_ls_fs_sync_freq();
    time    period;
    //-> debug1;
    wait_dm_logic_change();
    total_time = 0;
    t1 = $time;
    repeat (6) begin
      wait_dm_logic_change();
      t2 = $time;
      period = (t2-t1);
      if (period > clk_txperiod*1.005 || period < clk_txperiod*0.995) begin
          total_time = 0;
          return;
      end
      total_time += period;
      t1 = $time;
      end
    total_time = total_time/6;
    clk_period = total_time;
    clk_halfperiod = clk_period >> 1;

    clk_highperiod = clk_halfperiod+clk_period[0];
    clk_lowperiod = clk_halfperiod;
  endtask

  // wait for sync pattern and calculate bit period
  task calculate_hs_sync_freq();
    time    period;

    wait_dm_logic_change();
    total_time = 0;
    t1 = $time;
    repeat (30) begin
      wait_dm_logic_change();
      t2 = $time;
      period = (t2-t1);
      if (period > clk_txperiod*1.005 || period < clk_txperiod*0.995) begin
          total_time = 0;
          return;
      end
      total_time += period;
      t1 = $time;
      end
    total_time = total_time/30;
    clk_period = total_time;
    clk_halfperiod = clk_period >> 1;

    clk_highperiod = clk_halfperiod+clk_period[0];
    clk_lowperiod = clk_halfperiod;
  endtask

  task freq_detect();
    wait (speed_handshake_done);
    // Check SE0 state
    if (speed == brt_usb_types::HS)  // HS
      wait_hs_dpdm_idle();
    else if (speed == brt_usb_types::FS)
      wait_fs_dpdm_idle();
    else
      wait_ls_dpdm_idle();
    -> kill_clk_e;

    -> debug2;
    if (speed == brt_usb_types::HS)  // HS
      calculate_hs_sync_freq();
    else 
      calculate_ls_fs_sync_freq();

    -> debug3;
    if (total_time) begin
      if (!do_tx) -> gen_clk_e;
      end
  endtask

  initial forever begin 
    -> debug0;
    wait (!is_suspended);
    -> debug1;
    `FORK_GUARD_BEGIN
        fork
          wait(is_suspended);  // When suspended
          freq_detect();
          @speed;
        join_any
        prev_is_suspended = is_suspended;
        disable fork;
    `FORK_GUARD_END
  end

  // USB2 Highspeed is 480Mbps ~ 2083ps
  // so generate clock with high period 1042, low period 1041
  task wait_high_delay();
    /*if (clk_period[0]) #1ps; 
    #(clk_halfperiod*1ps);*/
    #(clk_highperiod*1ps);
  endtask

  task wait_low_delay();
    #(clk_halfperiod*1ps);
  endtask

  task positive_jitter_detect();
    bit restart;
    restart = 0;
    `FORK_GUARD_BEGIN
      fork
        wait_high_delay();
        begin 
            @(dm);
            restart = 1; 
        end
        join_any
      disable fork;
    `FORK_GUARD_END
    if (restart) begin
      wait_high_delay();
      end
  endtask

  task negative_jitter_detect();
    `FORK_GUARD_BEGIN
        fork
            wait_low_delay();
            @(dm); 
        join_any
        disable fork;
    `FORK_GUARD_END
  endtask

  initial forever begin : blk_clock_recovery
    rx_clk_fdpd = rx_clk_fd;  // 0
    @gen_clk_e;

    `FORK_GUARD_BEGIN
      fork
        begin
          @kill_clk_e; 
        end
        forever begin : BLK_PHASE_CLK_GEN
          rx_clk_fdpd = 1;
          positive_jitter_detect();
          rx_clk_fdpd = 0;
          negative_jitter_detect();
        end : BLK_PHASE_CLK_GEN
      join_any
      wait (rx_clk_fdpd == 0);
      disable fork;
    `FORK_GUARD_END
  end

  initial forever begin : blk_gen_clk_fd
    `FORK_GUARD_BEGIN
        fork 
          begin : BLK_FREQ_CLK_GEN
            @gen_clk_e;
            #0;
            forever begin
              rx_clk_fd = ~rx_clk_fd; 
              wait_high_delay();
              rx_clk_fd = ~rx_clk_fd; 
              wait_low_delay();
              end
            end : BLK_FREQ_CLK_GEN
          begin @kill_clk_e; end
          join_any
        wait (rx_clk_fd == 0);
        disable fork;
    `FORK_GUARD_END
    end

  // Receive, inform rx data is availble  
  initial forever begin
    @gen_clk_e;
    repeat(2) @(negedge rx_clk_fdpd);
    -> rx_data_e;
    -> debug4;
  end

  ///////////// END: RX CLOCK DATA RECOVERY ///////////////////


endinterface

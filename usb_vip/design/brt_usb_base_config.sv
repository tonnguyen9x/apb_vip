class brt_usb_base_config extends brt_object;

  `brt_object_utils(brt_usb_base_config)

  function new(string name="brt_usb_base_config");
    super.new(name);
  endfunction
endclass

class brt_usb_endpoint_config extends brt_usb_base_config;

  int                         ep_number=0;
  int                         interval=1;
  int                         max_burst_size=0;
  int                         max_packet_size=1;
  int                         max_num_nak_per_transfer=`NUM_NAK_XFER;
  bit                         supports_ustreams=0;
  bit                         allow_aligned_transfer_without_zero_length=0;
  bit                         allow_zero_length_after_ping=0;
  bit                         allow_spurious_erdy_after_polling=0;
  brt_usb_types::ep_dir_e     direction;
  brt_usb_types::ep_type_e    ep_type;
 
  `brt_object_utils_begin(brt_usb_endpoint_config)
    `brt_field_int            (ep_number,                                   UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (interval,                                    UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (max_burst_size,                              UVM_ALL_ON|UVM_NOPACK|UVM_DEC);
    `brt_field_int            (max_packet_size,                             UVM_ALL_ON|UVM_NOPACK|UVM_DEC);
    `brt_field_int            (max_num_nak_per_transfer,                    UVM_ALL_ON|UVM_NOPACK|UVM_DEC);
    `brt_field_int            (supports_ustreams,                           UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (allow_aligned_transfer_without_zero_length,  UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (allow_zero_length_after_ping,                UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (allow_spurious_erdy_after_polling,           UVM_ALL_ON|UVM_NOPACK);
    `brt_field_enum           (brt_usb_types::ep_dir_e, direction,         UVM_ALL_ON|UVM_NOPACK);
    `brt_field_enum           (brt_usb_types::ep_type_e, ep_type,          UVM_ALL_ON|UVM_NOPACK);
  `brt_object_utils_end

  function new(string name="brt_usb_endpoint_config");
    super.new(name);
  endfunction
endclass

class brt_usb_device_config extends brt_usb_base_config;

  bit[6:0]                    device_address;
  bit[6:0]                    connected_hub_device_address;
  brt_usb_types::speed_e      connected_bus_speed;
  brt_usb_types::speed_e      functionality_support;
  int                         num_endpoints;
  brt_usb_endpoint_config     endpoint_cfg[];
  bit                         remote_wakeup_capable;
 
  `brt_object_utils_begin(brt_usb_device_config)
    `brt_field_int           (device_address,                                UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int           (connected_hub_device_address,                  UVM_ALL_ON|UVM_NOPACK);
    `brt_field_enum          (brt_usb_types::speed_e, connected_bus_speed,   UVM_ALL_ON|UVM_NOPACK);
    `brt_field_enum          (brt_usb_types::speed_e, functionality_support, UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int           (num_endpoints,                                 UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int           (remote_wakeup_capable,                         UVM_ALL_ON|UVM_NOPACK);
    `brt_field_array_object  (endpoint_cfg,                                  UVM_ALL_ON|UVM_NOPACK);
  `brt_object_utils_end

  function new(string name="brt_usb_device_config");
    super.new(name);
    endpoint_cfg = new[`NUM_EP];
  endfunction
endclass

class brt_usb_host_config extends brt_usb_base_config;
 
  `brt_object_utils(brt_usb_host_config)

  function new(string name="brt_usb_host_config");
    super.new(name);
  endfunction
endclass

class brt_usb_config extends brt_usb_base_config;

  typedef enum int {
    NOMINAL_HALF_FULL, NOMINAL_EMPTY
  } rx_buffer_mode_e;

  typedef enum bit[1:0] {
    PLAIN = 1, OTG = 2
  } brt_usb_capabilities_e;

  typedef enum bit[7:0] {
    USB_20_SERIAL_IF, UTMI_IF, NO_20_IF
  } brt_usb_20_signal_interface_e;

  typedef enum bit[7:0] {
    USB_SS_SERIAL_IF, PIPE3_IF, NO_SS_IF
  } brt_usb_ss_signal_interface_e;

  typedef enum bit[2:0] {
    USB_SS_CAPABLE, USB_SS_ONLY, USB_20_ONLY
  } brt_usb_capability_e;
 
  virtual brt_usb_if  ser_vif;

  brt_usb_types::component_type_e               component_type;
  // local/remote host config
  brt_usb_host_config                           local_host_cfg;
  brt_usb_host_config                           remote_host_cfg;
  // local/remote dev config
  int                                           local_device_cfg_size;
  brt_usb_device_config                         local_device_cfg[$];
  int                                           remote_device_cfg_size;
  brt_usb_device_config                         remote_device_cfg[$];

  brt_usb_capabilities_e                        capability;
  brt_usb_capability_e                          usb_capability;
  brt_usb_types::speed_e                        speed;
  brt_usb_20_signal_interface_e                 usb_20_signal_interface;
  brt_usb_ss_signal_interface_e                 usb_ss_signal_interface;
  // USB3
  brt_usb_types::ltssm_state_e                  usb_ss_initial_ltssm_state=brt_usb_types::U0;
  rx_buffer_mode_e                              usb_ss_rx_buffer_mode;
  bit                                           u1_enable;
  bit                                           u1_entry_enabled;
  bit[7:0]                                      u1_timeout;
  bit                                           u2_enable;
  bit                                           u2_entry_enabled;
  int                                           brt_usb_ss_rx_buffer_latency=0;
  // USB2 timing parameter
  time                                          tinactivity   =3ms;         // The time the bus must be in idle for the host/device to enter enter the suspend state while operating in NON-HS mode.
  time                                          tresume_signal=1ms;         //Time from detecting downstream resume to rebroadcast
  time                                          tfs_rst       =2.5us;         // Time a high-speed capable device operating in non-suspended fullspeed must wait after start of SE0 before beginning the high-speed detection handshake
  time                                          bit_time;
  time                                          tdrst         =3ms;     // Duration of driving reset to a downstream facing port
  time                                          fsrst         =2.5us;   // Device detect reset in FS/LS mode
  time                                          trst_detect   =875us;   // Period to check reset or suspend after host assert SE0 in tdrst
  time                                          twtdch        =100us;   // Time after end of device Chirp K by which host must start driving first Chirp K in the host chirp sequence
  time                                          tdchbit       =40us;    // 40-60us. Time for which each individual Chirp J or Chirp K in the chirp sequence is driven downstream by hub during reset
  time                                          twtfs         =1ms;     // 1-2.5ms. Device turn to FS if not detect KJ in this period
  time                                          tuch          =1000us;  // Device sends chirp K period(min)
  time                                          tsendk        =100us;   // Device wait for sending chirp K (min)
  time                                          tdchse0       =100us;   // Time before end of reset by which a hub must end its downstream chirp sequence  
  time                                          tattdb        =100us;   // 100ms. Debounce interval provided by USB system software after attach
  time                                          tdrsmdn       =20ms;    // Duration of driving resume to a downstream port
  time                                          tdrsmup       =2ms;     // 1ms-15ms Duration of driving resume upstream
  time                                          twtrsm_min    =5ms;     // Period of idle bus before device can initiate resume
  time                                          trst_total    =10ms;    // Time from reset to idle
  //rand int                                      thsipdod_bit_times;     //inter-packet delay when transmitting after receiving 
  //rand int                                      thsipdsd_bit_times;     //inter-packet delay when transmitting two packets in a row
  time                                          tdev_wup_rsm  =1ms;     // Device drive K duration when waking up
  // LPM
  bit                                           lpm_enable;
  time                                          tl1devinit    =9us;     // Device initiated L1 state after sending ACK
  time                                          tl1hird       =75us;    // 
  time                                          tl1besl       =125us;   // 
  time                                          tl1hubreflect =48us;    // 

  brt_usb_types::speed_e                        max_speed = brt_usb_types::HS;

  bit                                           ping_support  = 1;
  bit                                           need_last_ping = 0;

  // Checker for reset handshake
  time                                          fstdsus       =3ms;     // Duration of suspend detection

  // packet response time
  time                                          hspktrsp      = 400ns + 100ns;  // 192 HS bit times + 100ns
  time                                          fspktrsp      = 541ns + 750ns;  // 6.5 FS bit times + 100ns
  time                                          lspktrsp      = 7*667ns + 25us;  // 6.5 LS bit times + 25us

  // Ignore error cheker of host/device monitor
  bit                                           ignore_mon_host_err = `IGNORE_HOST_ERR;
  bit                                           ignore_mon_dev_err  = `IGNORE_DEV_ERR;
  bit                                           ignore_mon_tx_err   = `IGNORE_MON_TX_ERR;

  // UTMI signal checkpoint
  bit                                           utmi_connect;
  bit                                           utmi_chk_mod_en;
  bit                                           utmi_chk_k_en;
  time                                          utmi_chk_period = 10us;
  int                                           utmi_mode = -1;
  int                                           utmi_testmode = -1;

  // Performance checking
  bit                                           perf_chk_en = 1;
  int                                           perf_min_chk = -1;  // B/s
  int                                           perf_max_chk = 60000000;  // 60MB/s
  bit                                           perf_ignore_ack = 0;

  bit                                           run = 1;

  real                                          ls_fs_eop_se0_2_j_margin = 0.0025;

  `brt_object_utils_begin(brt_usb_config)
    `brt_field_enum         (brt_usb_types::component_type_e, component_type,               UVM_ALL_ON|UVM_NOPACK);
    `brt_field_object       (local_host_cfg,                                                UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (local_device_cfg_size,                                         UVM_ALL_ON|UVM_NOPACK);
    `brt_field_queue_object (local_device_cfg,                                              UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (remote_device_cfg_size,                                        UVM_ALL_ON|UVM_NOPACK);
    `brt_field_queue_object (remote_device_cfg,                                             UVM_ALL_ON|UVM_NOPACK);
    `brt_field_object       (remote_host_cfg,                                               UVM_ALL_ON|UVM_NOPACK);
    `brt_field_enum         (brt_usb_capabilities_e, capability,                            UVM_ALL_ON|UVM_NOPACK);
    `brt_field_enum         (brt_usb_types::speed_e, speed,                                 UVM_ALL_ON|UVM_NOPACK);
    `brt_field_enum         (brt_usb_20_signal_interface_e, usb_20_signal_interface,    UVM_ALL_ON|UVM_NOPACK);
    `brt_field_enum         (brt_usb_ss_signal_interface_e, usb_ss_signal_interface,    UVM_ALL_ON|UVM_NOPACK);
    `brt_field_enum         (brt_usb_capability_e, usb_capability,                      UVM_ALL_ON|UVM_NOPACK);
    `brt_field_enum         (brt_usb_types::ltssm_state_e, usb_ss_initial_ltssm_state,  UVM_ALL_ON|UVM_NOPACK);
    `brt_field_enum         (rx_buffer_mode_e, usb_ss_rx_buffer_mode,                   UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (brt_usb_ss_rx_buffer_latency,                                  UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (u1_enable,                                                     UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (u1_entry_enabled,                                              UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (u1_timeout,                                                    UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (u2_enable,                                                     UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (u2_entry_enabled,                                              UVM_ALL_ON|UVM_NOPACK);
    `brt_field_real         (tinactivity,                                                   UVM_ALL_ON|UVM_NOPACK);
    `brt_field_real         (tresume_signal,                                                UVM_ALL_ON|UVM_NOPACK);
    `brt_field_real         (tdrst,                                                         UVM_ALL_ON|UVM_NOPACK);
    `brt_field_real         (twtdch,                                                        UVM_ALL_ON|UVM_NOPACK);
    `brt_field_real         (tdchbit,                                                       UVM_ALL_ON|UVM_NOPACK);
    `brt_field_real         (tuch,                                                          UVM_ALL_ON|UVM_NOPACK);
    `brt_field_real         (tdchse0,                                                       UVM_ALL_ON|UVM_NOPACK);
    `brt_field_real         (tattdb,                                                        UVM_ALL_ON|UVM_NOPACK);
    `brt_field_real         (tdrsmdn,                                                       UVM_ALL_ON|UVM_NOPACK);
    `brt_field_real         (tdrsmup,                                                       UVM_ALL_ON|UVM_NOPACK);
    `brt_field_real         (twtrsm_min,                                                    UVM_ALL_ON|UVM_NOPACK);
    `brt_field_real         (trst_total,                                                    UVM_ALL_ON|UVM_NOPACK);
    `brt_field_real         (twtfs,                                                         UVM_ALL_ON|UVM_NOPACK);
    //`brt_field_int          (thsipdod_bit_times,                                            UVM_ALL_ON|UVM_NOPACK);
    //`brt_field_int          (thsipdsd_bit_times,                                            UVM_ALL_ON|UVM_NOPACK);
    `brt_field_enum         (brt_usb_types::speed_e, max_speed,                             UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (ping_support,                                                  UVM_ALL_ON|UVM_NOPACK);
    `brt_field_real         (fstdsus,                                                       UVM_ALL_ON|UVM_NOPACK);
    `brt_field_real         (hspktrsp,                                                      UVM_ALL_ON|UVM_NOPACK);
    `brt_field_real         (fspktrsp,                                                      UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (utmi_connect,                                                  UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (utmi_chk_mod_en,                                               UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (utmi_chk_k_en,                                                 UVM_ALL_ON|UVM_NOPACK);
    `brt_field_real         (utmi_chk_period,                                               UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (utmi_mode,                                                     UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (utmi_connect,                                                  UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (utmi_chk_mod_en,                                               UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (utmi_chk_k_en,                                                 UVM_ALL_ON|UVM_NOPACK);
    `brt_field_real         (utmi_chk_period,                                               UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (utmi_mode,                                                     UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (utmi_testmode,                                                 UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (perf_chk_en,                                                   UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (perf_min_chk,                                                  UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (perf_max_chk,                                                  UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (perf_ignore_ack,                                               UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int          (run,                                                           UVM_ALL_ON|UVM_NOPACK);
  `brt_object_utils_end                                          

  function void post_randomize();
    if (speed == brt_usb_types::HS) bit_time = 2083ps;
    else bit_time = 83320ps;
  endfunction

  function new(string name="brt_usb_config");
    super.new(name);
  endfunction

  virtual function bit is_valid();
    // TODO
    return 1;
  endfunction
endclass:brt_usb_config

class brt_usb_agent_config extends brt_usb_config;

  bit enable_prot_chk;
  bit enable_prot_reporting;
  bit enable_prot_tracing;          // Protocol summary callback
  bit enable_link_chk;
  bit enable_link_reporting;
  bit enable_link_tracing;
  bit enable_phys_chk;
  bit enable_phys_reporting;
  bit enable_phys_tracing;
  bit enable_prot_cov;
  bit enable_link_cov;
  int enable_prot_xml_gen;
  int enable_link_xml_gen;
  int enable_phys_xml_gen;

  // Instance USB VIP mode
  bit agent_enable;
  bit vip_enable;
  bit mon_enable;
  bit cov_enable;
  //bit is_host_enable = 1'b1;
  bit enable_feature_cb;

  `brt_object_utils_begin(brt_usb_agent_config)
    `brt_field_int            (enable_prot_chk,             UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (enable_prot_reporting,       UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (enable_prot_tracing,         UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (enable_link_chk,             UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (enable_link_reporting,       UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (enable_link_tracing,         UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (enable_phys_chk,             UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (enable_phys_reporting,       UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (enable_phys_tracing,         UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (enable_prot_xml_gen,         UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (enable_link_xml_gen,         UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (enable_phys_xml_gen,         UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (enable_prot_cov,             UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (enable_link_cov,             UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (agent_enable,                UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (vip_enable,                  UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (mon_enable,                  UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (cov_enable,                  UVM_ALL_ON|UVM_NOPACK);
    `brt_field_int            (enable_feature_cb,           UVM_ALL_ON|UVM_NOPACK);
  `brt_object_utils_end

  function new(string name="brt_usb_agent_config");
    super.new(name);
    agent_enable = 1'b1;
    vip_enable   = 1'b1;
    mon_enable   = 1'b0;
  endfunction
endclass

// brt_usb_env_config defines the brt_usb environment configuration which include VIP
// Host and DUT Device or vice versa
class brt_usb_env_config extends brt_object ;

  real timeout = 10ms;

  brt_usb_agent_config         host_cfg;
  brt_usb_agent_config         dev_cfg;
  int                         max_brt_usb_20_endpoints = `NUM_EP;
  //int                         max_brt_usb_20_endpoints = 4;
  int                         max_brt_usb_ss_endpoints = 4;

  `brt_object_utils_begin(brt_usb_env_config)
    `brt_field_object      (host_cfg,      UVM_ALL_ON|UVM_DEEP)
    `brt_field_object      (dev_cfg,       UVM_ALL_ON|UVM_DEEP)
    `brt_field_real        (timeout,      UVM_ALL_ON)
    `brt_field_int         (max_brt_usb_20_endpoints,     UVM_ALL_ON)
    `brt_field_int         (max_brt_usb_ss_endpoints,     UVM_ALL_ON)
  `brt_object_utils_end

  function new(string name = "brt_usb_shared_cfg_inst");
    super.new(name);
    // Host
    host_cfg                           = new();
    host_cfg.component_type            = brt_usb_types::HOST;
    host_cfg.local_host_cfg            = new();
    host_cfg.local_device_cfg_size     = 0;
    // Device
    dev_cfg                            = new();
    dev_cfg.component_type             = brt_usb_types::DEVICE;
    dev_cfg.local_device_cfg_size      = 1;
    dev_cfg.local_device_cfg[0]        = new();
    dev_cfg.local_host_cfg             = null;
    dev_cfg.remote_host_cfg            = host_cfg.local_host_cfg;
    dev_cfg.remote_device_cfg_size     = host_cfg.local_device_cfg_size;
    // Remote dev
    host_cfg.remote_device_cfg_size    = dev_cfg.local_device_cfg_size;
    host_cfg.remote_device_cfg         = dev_cfg.local_device_cfg;
    host_cfg.remote_host_cfg           = dev_cfg.local_host_cfg;

  endfunction

  function void setup_brt_usb_ss_defaults();
    host_cfg.capability                                            = brt_usb_config::PLAIN;
    dev_cfg.capability                                             = brt_usb_config::PLAIN;
    host_cfg.speed                                                 = brt_usb_types::SS;
    dev_cfg.speed                                                  = brt_usb_types::SS;
    host_cfg.usb_ss_signal_interface                               = brt_usb_config::USB_SS_SERIAL_IF;
    dev_cfg.usb_ss_signal_interface                                = brt_usb_config::USB_SS_SERIAL_IF;
    dev_cfg.local_device_cfg[0].device_address                     = 0;
    dev_cfg.local_device_cfg[0].connected_bus_speed                = brt_usb_types::SS;
    dev_cfg.local_device_cfg[0].connected_hub_device_address       = 0;
    dev_cfg.local_device_cfg[0].functionality_support              = brt_usb_types::SS;
    dev_cfg.local_device_cfg[0].num_endpoints                      = max_brt_usb_ss_endpoints;
    host_cfg.usb_capability                                        = brt_usb_config::USB_SS_ONLY;
    dev_cfg.usb_capability                                         = brt_usb_config::USB_SS_ONLY;
    host_cfg.usb_ss_initial_ltssm_state                            = brt_usb_types::U0;
    dev_cfg.usb_ss_initial_ltssm_state                             = brt_usb_types::U0;
    host_cfg.usb_20_signal_interface                               = brt_usb_config::NO_20_IF;
    dev_cfg.usb_20_signal_interface                                = brt_usb_config::NO_20_IF;
    host_cfg.usb_ss_rx_buffer_mode                                 = brt_usb_config::NOMINAL_EMPTY;
    dev_cfg.usb_ss_rx_buffer_mode                                  = brt_usb_config::NOMINAL_EMPTY;
    host_cfg.brt_usb_ss_rx_buffer_latency                          = 0;
    dev_cfg.brt_usb_ss_rx_buffer_latency                           = 0;

    if (max_brt_usb_ss_endpoints <= 0) begin
      `brt_fatal("setup_brt_usb_ss_defaults", $sformatf("The max_brt_usb_ss_endpoints property is set to %0d. This property must be set to a value >=1. Unable to continue",
      max_brt_usb_ss_endpoints))
      end

    for (int ep_num = 0; ep_num < max_brt_usb_ss_endpoints; ep_num++) begin
      dev_cfg.local_device_cfg[0].endpoint_cfg[ep_num] = new();
      end

    if (max_brt_usb_ss_endpoints >= 1) begin
      dev_cfg.local_device_cfg[0].endpoint_cfg[0].ep_number                              = 0;
      dev_cfg.local_device_cfg[0].endpoint_cfg[0].direction                              = brt_usb_types::IN;
      dev_cfg.local_device_cfg[0].endpoint_cfg[0].ep_type                                = brt_usb_types::CONTROL;
      dev_cfg.local_device_cfg[0].endpoint_cfg[0].allow_spurious_erdy_after_polling      = 1;
      dev_cfg.local_device_cfg[0].endpoint_cfg[0].max_burst_size                         = 0;
      dev_cfg.local_device_cfg[0].endpoint_cfg[0].max_packet_size                        = 512;
      dev_cfg.local_device_cfg[0].endpoint_cfg[0].supports_ustreams                      = 1'b0;
      end

    if (max_brt_usb_ss_endpoints >= 2) begin
      dev_cfg.local_device_cfg[0].endpoint_cfg[1].ep_number                                  = 1;
      dev_cfg.local_device_cfg[0].endpoint_cfg[1].direction                                  = brt_usb_types::IN;
      dev_cfg.local_device_cfg[0].endpoint_cfg[1].ep_type                                    = brt_usb_types::BULK;
      dev_cfg.local_device_cfg[0].endpoint_cfg[1].allow_aligned_transfer_without_zero_length = 1;
      dev_cfg.local_device_cfg[0].endpoint_cfg[1].allow_spurious_erdy_after_polling          = 1;
      dev_cfg.local_device_cfg[0].endpoint_cfg[1].max_burst_size                             = 15;
      dev_cfg.local_device_cfg[0].endpoint_cfg[1].max_packet_size                            = 1024;
      dev_cfg.local_device_cfg[0].endpoint_cfg[1].supports_ustreams                          = 1'b0;
      end

    if (max_brt_usb_ss_endpoints >= 3) begin
      dev_cfg.local_device_cfg[0].endpoint_cfg[2].ep_number                                  = 2;
      dev_cfg.local_device_cfg[0].endpoint_cfg[2].direction                                  = brt_usb_types::OUT;
      dev_cfg.local_device_cfg[0].endpoint_cfg[2].ep_type                                    = brt_usb_types::BULK;
      dev_cfg.local_device_cfg[0].endpoint_cfg[2].allow_aligned_transfer_without_zero_length = 0;
      dev_cfg.local_device_cfg[0].endpoint_cfg[2].allow_spurious_erdy_after_polling          = 1;
      dev_cfg.local_device_cfg[0].endpoint_cfg[2].max_burst_size                             = 15;
      dev_cfg.local_device_cfg[0].endpoint_cfg[2].max_packet_size                            = 1024;
      dev_cfg.local_device_cfg[0].endpoint_cfg[2].supports_ustreams                          = 1'b0;
      end

    if (max_brt_usb_ss_endpoints >= 4) begin
      dev_cfg.local_device_cfg[0].endpoint_cfg[3].ep_number                                  = 3;
      dev_cfg.local_device_cfg[0].endpoint_cfg[3].direction                                  = brt_usb_types::IN;
      dev_cfg.local_device_cfg[0].endpoint_cfg[3].ep_type                                    = brt_usb_types::ISOCHRONOUS;
      dev_cfg.local_device_cfg[0].endpoint_cfg[3].allow_aligned_transfer_without_zero_length = 0;
      dev_cfg.local_device_cfg[0].endpoint_cfg[3].allow_spurious_erdy_after_polling          = 1;
      dev_cfg.local_device_cfg[0].endpoint_cfg[3].interval                                   = 1;
      dev_cfg.local_device_cfg[0].endpoint_cfg[3].max_burst_size                             = 15;
      dev_cfg.local_device_cfg[0].endpoint_cfg[3].max_packet_size                            = 1024;
      dev_cfg.local_device_cfg[0].endpoint_cfg[3].supports_ustreams                          = 1'b0;
      end

    if (max_brt_usb_ss_endpoints >= 5) begin
      dev_cfg.local_device_cfg[0].endpoint_cfg[4].ep_number                                  = 4;
      dev_cfg.local_device_cfg[0].endpoint_cfg[4].direction                                  = brt_usb_types::OUT;
      dev_cfg.local_device_cfg[0].endpoint_cfg[4].ep_type                                    = brt_usb_types::ISOCHRONOUS;
      dev_cfg.local_device_cfg[0].endpoint_cfg[4].allow_aligned_transfer_without_zero_length = 0;
      dev_cfg.local_device_cfg[0].endpoint_cfg[4].interval                                   = 1;
      dev_cfg.local_device_cfg[0].endpoint_cfg[4].max_burst_size                             = 15;
      dev_cfg.local_device_cfg[0].endpoint_cfg[4].max_packet_size                            = 1024;
      dev_cfg.local_device_cfg[0].endpoint_cfg[4].supports_ustreams                          = 1'b0;
      end

    if (max_brt_usb_ss_endpoints >= 6) begin
      dev_cfg.local_device_cfg[0].endpoint_cfg[5].ep_number                                  = 5;
      dev_cfg.local_device_cfg[0].endpoint_cfg[5].direction                                  = brt_usb_types::IN;
      dev_cfg.local_device_cfg[0].endpoint_cfg[5].ep_type                                    = brt_usb_types::INTERRUPT;
      dev_cfg.local_device_cfg[0].endpoint_cfg[5].allow_aligned_transfer_without_zero_length = 0;
      dev_cfg.local_device_cfg[0].endpoint_cfg[5].interval                                   = 1;
      dev_cfg.local_device_cfg[0].endpoint_cfg[5].max_burst_size                             = 2;
      dev_cfg.local_device_cfg[0].endpoint_cfg[5].max_packet_size                            = 1024;
      dev_cfg.local_device_cfg[0].endpoint_cfg[5].supports_ustreams                          = 1'b0;
      end

    if (max_brt_usb_ss_endpoints >= 7) begin
      dev_cfg.local_device_cfg[0].endpoint_cfg[6].ep_number                                  = 6;
      dev_cfg.local_device_cfg[0].endpoint_cfg[6].direction                                  = brt_usb_types::OUT;
      dev_cfg.local_device_cfg[0].endpoint_cfg[6].ep_type                                    = brt_usb_types::INTERRUPT;
      dev_cfg.local_device_cfg[0].endpoint_cfg[6].allow_aligned_transfer_without_zero_length = 0;
      dev_cfg.local_device_cfg[0].endpoint_cfg[6].interval                                   = 1;
      dev_cfg.local_device_cfg[0].endpoint_cfg[6].max_burst_size                             = 2;
      dev_cfg.local_device_cfg[0].endpoint_cfg[6].max_packet_size                            = 1024;
      dev_cfg.local_device_cfg[0].endpoint_cfg[6].supports_ustreams                          = 1'b0;
      end

    if (max_brt_usb_ss_endpoints >= 8) begin
      `brt_warning("setup_brt_usb_ss_defaults", $sformatf("The max_brt_usb_ss_endpoints property is set to %0d. Configured 7 endpoints . Other endpoints must be configured in the testcase.",
      max_brt_usb_ss_endpoints));
      end
  endfunction

  function void setup_brt_usb_20_defaults(brt_usb_types::speed_e host_speed = brt_usb_types::HS,brt_usb_types::speed_e dev_speed = brt_usb_types::HS);
    host_cfg.capability                              = brt_usb_config::PLAIN;
    dev_cfg.capability                               = brt_usb_config::PLAIN;
    host_cfg.speed                                   = (host_speed == brt_usb_types::HS) ? brt_usb_types::HS : (host_speed == brt_usb_types::FS) ? brt_usb_types::FS : brt_usb_types::LS;
    dev_cfg.speed                                    = (dev_speed == brt_usb_types::HS) ? brt_usb_types::HS : (dev_speed == brt_usb_types::FS) ? brt_usb_types::FS : brt_usb_types::LS;;
    host_cfg.usb_20_signal_interface                 = brt_usb_config::USB_20_SERIAL_IF;
    dev_cfg.usb_20_signal_interface                  = brt_usb_config::USB_20_SERIAL_IF;
    host_cfg.usb_ss_signal_interface                 = brt_usb_config::NO_SS_IF;
    dev_cfg.usb_ss_signal_interface                  = brt_usb_config::NO_SS_IF;
    host_cfg.usb_capability                          = brt_usb_config::USB_20_ONLY;
    dev_cfg.usb_capability                           = brt_usb_config::USB_20_ONLY;

    if (max_brt_usb_20_endpoints <= 0) begin
      `brt_fatal("setup_brt_usb_20_defaults", $sformatf("The max_brt_usb_20_endpoints property is set to %0d. This property must be set to a value >=1. Unable to continue",
      max_brt_usb_20_endpoints))
      end

    for (int ep_num = 0; ep_num < max_brt_usb_20_endpoints; ep_num++) begin
        dev_cfg.local_device_cfg[0].endpoint_cfg[ep_num] = new();
        // Default is CONTROL
        dev_cfg.local_device_cfg[0].endpoint_cfg[ep_num].ep_type = brt_usb_types::CONTROL;
    end


    dev_cfg.local_device_cfg[0].device_address                 = 0;
    dev_cfg.local_device_cfg[0].connected_bus_speed            = (dev_speed == brt_usb_types::HS) ? brt_usb_types::HS : (dev_speed == brt_usb_types::FS) ? brt_usb_types::FS : brt_usb_types::LS;
    dev_cfg.local_device_cfg[0].connected_hub_device_address   = 0;
    dev_cfg.local_device_cfg[0].functionality_support          = (dev_speed == brt_usb_types::HS) ? brt_usb_types::HS : (dev_speed == brt_usb_types::FS) ? brt_usb_types::FS : brt_usb_types::LS;
    dev_cfg.local_device_cfg[0].num_endpoints                  = max_brt_usb_20_endpoints;

    if (max_brt_usb_20_endpoints >= 1) begin
      dev_cfg.local_device_cfg[0].endpoint_cfg[0].ep_number          = 0;
      dev_cfg.local_device_cfg[0].endpoint_cfg[0].direction          = brt_usb_types::OUT;
      dev_cfg.local_device_cfg[0].endpoint_cfg[0].ep_type            = brt_usb_types::CONTROL;
      dev_cfg.local_device_cfg[0].endpoint_cfg[0].interval           = 1;
      dev_cfg.local_device_cfg[0].endpoint_cfg[0].max_burst_size     = 0;
      dev_cfg.local_device_cfg[0].endpoint_cfg[0].max_packet_size    = (dev_speed == brt_usb_types::HS) ? 64 : (dev_speed == brt_usb_types::FS) ? 64 : 8;
      end

    if (max_brt_usb_20_endpoints >= 2) begin
      dev_cfg.local_device_cfg[0].endpoint_cfg[1].ep_number                                          = 1;
      dev_cfg.local_device_cfg[0].endpoint_cfg[1].direction                                          = brt_usb_types::IN;
      dev_cfg.local_device_cfg[0].endpoint_cfg[1].ep_type                                            = brt_usb_types::BULK;
      dev_cfg.local_device_cfg[0].endpoint_cfg[1].allow_aligned_transfer_without_zero_length = 0;
      dev_cfg.local_device_cfg[0].endpoint_cfg[1].interval                                           = 1;
      dev_cfg.local_device_cfg[0].endpoint_cfg[1].max_packet_size                                    = (dev_speed == brt_usb_types::HS) ? 512:64;
      end

    if (max_brt_usb_20_endpoints >= 3) begin
      dev_cfg.local_device_cfg[0].endpoint_cfg[2].ep_number                                          = 2;
      dev_cfg.local_device_cfg[0].endpoint_cfg[2].direction                                          = brt_usb_types::OUT;
      dev_cfg.local_device_cfg[0].endpoint_cfg[2].ep_type                                            = brt_usb_types::BULK;
      dev_cfg.local_device_cfg[0].endpoint_cfg[2].allow_aligned_transfer_without_zero_length = 0;
      dev_cfg.local_device_cfg[0].endpoint_cfg[2].interval                                           = 0;
      dev_cfg.local_device_cfg[0].endpoint_cfg[2].max_packet_size                                    = (dev_speed == brt_usb_types::HS) ? 512:64;
      end

    if (max_brt_usb_20_endpoints >= 4) begin
      dev_cfg.local_device_cfg[0].endpoint_cfg[3].ep_number                                          = 3;
      dev_cfg.local_device_cfg[0].endpoint_cfg[3].direction                                          = brt_usb_types::IN;
      dev_cfg.local_device_cfg[0].endpoint_cfg[3].ep_type                                            = brt_usb_types::ISOCHRONOUS;
      dev_cfg.local_device_cfg[0].endpoint_cfg[3].allow_aligned_transfer_without_zero_length = 0;
      dev_cfg.local_device_cfg[0].endpoint_cfg[3].interval                                           = 1;
      dev_cfg.local_device_cfg[0].endpoint_cfg[3].max_packet_size                                    = (dev_speed == brt_usb_types::HS) ? 1024:512;
      end

    if (max_brt_usb_20_endpoints >= 5) begin
      dev_cfg.local_device_cfg[0].endpoint_cfg[4].ep_number                                          = 4;
      dev_cfg.local_device_cfg[0].endpoint_cfg[4].direction                                          = brt_usb_types::OUT;
      dev_cfg.local_device_cfg[0].endpoint_cfg[4].ep_type                                            = brt_usb_types::ISOCHRONOUS;
      dev_cfg.local_device_cfg[0].endpoint_cfg[4].allow_aligned_transfer_without_zero_length = 0;
      dev_cfg.local_device_cfg[0].endpoint_cfg[4].interval                                           = 1;
      dev_cfg.local_device_cfg[0].endpoint_cfg[4].max_packet_size                                    = (dev_speed == brt_usb_types::HS) ? 1024:512;
      end

    if (max_brt_usb_20_endpoints >= 6) begin
      dev_cfg.local_device_cfg[0].endpoint_cfg[5].ep_number                                          = 5;
      dev_cfg.local_device_cfg[0].endpoint_cfg[5].direction                                          = brt_usb_types::IN;
      dev_cfg.local_device_cfg[0].endpoint_cfg[5].ep_type                                            = brt_usb_types::INTERRUPT;
      dev_cfg.local_device_cfg[0].endpoint_cfg[5].allow_aligned_transfer_without_zero_length = 0;
      dev_cfg.local_device_cfg[0].endpoint_cfg[5].interval                                           = 1;
      dev_cfg.local_device_cfg[0].endpoint_cfg[5].max_packet_size                                    = (dev_speed == brt_usb_types::HS) ? 1024 : (dev_speed == brt_usb_types::FS) ? 64 : 8;
      end

    if (max_brt_usb_20_endpoints >= 7) begin
      dev_cfg.local_device_cfg[0].endpoint_cfg[6].ep_number                                          = 6;
      dev_cfg.local_device_cfg[0].endpoint_cfg[6].direction                                          = brt_usb_types::OUT;
      dev_cfg.local_device_cfg[0].endpoint_cfg[6].ep_type                                            = brt_usb_types::INTERRUPT;
      dev_cfg.local_device_cfg[0].endpoint_cfg[6].allow_aligned_transfer_without_zero_length = 0;
      dev_cfg.local_device_cfg[0].endpoint_cfg[6].interval                                           = 1;
      dev_cfg.local_device_cfg[0].endpoint_cfg[6].max_packet_size                                    = (dev_speed == brt_usb_types::HS) ? 1024 : (dev_speed == brt_usb_types::FS) ? 64 : 8;
      end

    if (max_brt_usb_20_endpoints >= 8) begin
      `brt_warning("setup_brt_usb_20_defaults", $sformatf("The max_brt_usb_20_endpoints property is set to %0d. Configured 7 endpoints. Other endpoints must be configured in the testcase.",
      max_brt_usb_20_endpoints));
      end

    `brt_info(get_name(), $psprintf("Device Configuration setup %s", dev_cfg.sprint()),UVM_LOW)
  endfunction

  virtual function string get_class_name();
    get_class_name = "brt_usb_shared_cfg";
  endfunction

  virtual function bit is_valid(bit silent = 1, int kind = -1);
    is_valid = 1;

    if (!host_cfg.is_valid()) begin
      if (!silent) begin
        `brt_info("is_valid", $sformatf("Invalid Host configuration. Contents:\n%s", host_cfg.sprint()), UVM_HIGH)
        end
      is_valid = 0;
      end
    else if (!dev_cfg.is_valid()) begin
      if (!silent) begin
        `brt_info("is_valid", $sformatf("Invalid Device configuration. Contents:\n%s", dev_cfg.sprint()), UVM_HIGH);
        end
      is_valid = 0;
    end
  endfunction

endclass:brt_usb_env_config

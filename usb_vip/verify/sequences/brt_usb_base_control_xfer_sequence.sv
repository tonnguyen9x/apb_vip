class brt_usb_random_brt_usb_base_control_xfer_sequence extends brt_usb_xfer_base_sequence;
    string                     scope_name = "";
    brt_usb_config             upd_cfg;
    brt_usb_base_config        get_cfg;
    brt_usb_config             pre_cfg;
    brt_usb_config             post_cfg;
    brt_usb_config             cfg;
    brt_usb_agent              l_agent;
    brt_sequencer_base         seqr_base;
    brt_usb_transfer_sequencer seqr;
    bit                        randomize_checker=1;

    rand bit[15:0]             dev_addr;
    rand bit[15:0]             interface_num;
    rand bit[15:0]             alt_setting;
    rand bit[7:0]              feature_selector;
    rand bit[7:0]              test_selector;
    rand bit[7:0]              feature_target;
    rand bit[2:0]              target;   // 0,1,2: device, interface, endpoint
    rand bit                   xfer_dir; // 0 : Host-to-Device
    rand bit[15:0]             w_value;
    rand bit[15:0]             w_index;
    rand bit[15:0]             w_length;
    rand bit[6:0]              endpoint_num;
    rand bit                   endpoint_dir; // 0 : out, 1: in
    rand bit[15:0]             configuration_val;
    rand brt_usb_types::setup_data_brequest_e req_type;
    rand bit [7:0] descriptor_type;

    bit [15:0] total_length=1;

    constraint length_constr {
      w_length < 12800;
        }

    `brt_object_utils_begin(brt_usb_random_brt_usb_base_control_xfer_sequence)
       `brt_field_int(dev_addr, UVM_ALL_ON)
       `brt_field_int(interface_num, UVM_ALL_ON)
       `brt_field_int(alt_setting, UVM_ALL_ON)
       `brt_field_int(feature_selector, UVM_ALL_ON)
       `brt_field_int(test_selector, UVM_ALL_ON)
       `brt_field_int(feature_target, UVM_ALL_ON)
       `brt_field_int(target, UVM_ALL_ON)
       `brt_field_int(xfer_dir, UVM_ALL_ON)
       `brt_field_int(w_value, UVM_ALL_ON)
       `brt_field_int(w_index, UVM_ALL_ON)
       `brt_field_int(w_length, UVM_ALL_ON)
       `brt_field_int(endpoint_num, UVM_ALL_ON)
       `brt_field_int(endpoint_dir, UVM_ALL_ON)
       `brt_field_int(configuration_val, UVM_ALL_ON)
       `brt_field_int(descriptor_type, UVM_ALL_ON)
        `brt_field_enum(brt_usb_types::setup_data_brequest_e, req_type, UVM_ALL_ON)
    `brt_object_utils_end

  function new(string name="brt_usb_random_brt_usb_base_control_xfer_sequence");
    super.new(name);
    dev_addr = 127;
  endfunction : new

  function void get_updated_cfg();
    if (!uvm_config_db#(brt_usb_config)::get(null, scope_name, "seq_cfg", cfg )) begin
      `brt_error("body", "can not get configuration");
      end
    get_cfg = cfg;
    if (!$cast(upd_cfg, get_cfg)) begin
      `brt_fatal("body", "Unable to cast");
      end
  endfunction

  // Use below variable to control
  // xfer_dir: 0, 1
  // target: 0, 1, 2
  // req_type: 
  //           brt_usb_types::CLEAR_FEATURE -> {
  //           brt_usb_types::GET_CONFIGURATION -> {
  //           brt_usb_types::GET_DESCRIPTOR -> {
  //           brt_usb_types::GET_INTERFACE -> {
  //           brt_usb_types::GET_STATUS -> {
  //           brt_usb_types::SET_ADDRESS -> {
  //           brt_usb_types::SET_CONFIGURATION -> {
  //           brt_usb_types::SET_FEATURE -> {
  //           brt_usb_types::SET_INTERFACE -> {
  //           brt_usb_types::SYNCH_FRAME -> {
  // SET_SEL, SET_ISOCH_DELAY, USER_DEFINE >>>>> Not constrain
  function void create_request();
    if (!req.randomize() with {
      xfer_type                                                 == CONTROL_TRANSFER; 
      // dir
      xfer_dir == 0 -> setup_data_bmrequesttype_dir             == brt_usb_types::HOST_TO_DEVICE; 
      xfer_dir == 1 -> setup_data_bmrequesttype_dir             == brt_usb_types::DEVICE_TO_HOST; 
      // type
      setup_data_bmrequesttype_type                             == brt_usb_types::STANDARD;
      // recipient
      target == 0 -> setup_data_bmrequesttype_recipient         == brt_usb_types::BMREQ_DEVICE;
      target == 1 -> setup_data_bmrequesttype_recipient         == brt_usb_types::BMREQ_INTERFACE;
      target == 2 -> setup_data_bmrequesttype_recipient         == brt_usb_types::BMREQ_ENDPOINT;
      // brequest
      setup_data_brequest                                       == req_type; 
      setup_data_w_index                                        == w_index; 
      setup_data_w_value                                        == w_value;
      setup_data_w_length                                       == w_length; 

      // payload in data stage
      payload_intended_byte_count                               == w_length;
    }) begin
        
      if (!randomize_checker) begin
        `brt_fatal("body", "randomize error");
      end
      else begin
        `brt_warning("body", "randomize checker: constraint does not hold");
      end
   end
  endfunction

  function void update(brt_usb_random_brt_usb_base_control_xfer_sequence source);
    this.dev_addr             = source.dev_addr;
    this.interface_num        = source.interface_num;
    this.alt_setting          = source.alt_setting;
    this.feature_selector     = source.feature_selector;
    this.test_selector        = source.test_selector;
    this.feature_target       = source.feature_target;
    this.target               = source.target;
    this.xfer_dir             = source.xfer_dir;
    this.w_value              = source.w_value;
    this.w_index              = source.w_index;
    this.w_length             = source.w_length;
    this.endpoint_num         = source.endpoint_num;
    this.endpoint_dir         = source.endpoint_dir;
    this.configuration_val    = source.configuration_val;
    this.req_type             = source.req_type;
    this.descriptor_type      = source.descriptor_type;
    this.total_length         = source.total_length;
  endfunction

  task body();
    `brt_info("body",$sformatf("Running Sequence: %s", this.sprint()), UVM_HIGH);
    seqr_base = get_sequencer();
    if (!$cast(seqr, seqr_base)) begin
      `brt_fatal("body", "cast failed")
      end
    else if (!$cast(l_agent, seqr.find_first_agent(this)) || (l_agent == null)) begin
      `brt_fatal("body","Agent handle is null")
      end

    `brt_info("body", $sformatf("link status %s",l_agent.shared_status.sprint()), UVM_HIGH)

    wait (l_agent.shared_status.link_usb_20_state == brt_usb_types::ENABLED);

    if (scope_name == "") begin
      scope_name = get_sequencer().get_full_name();
      end
    if (!uvm_config_db#(brt_usb_config)::get(null, scope_name, "seq_cfg", cfg )) begin
      `brt_error("body", "can not get configuration");
      end

    get_cfg = cfg;
    if (!$cast(pre_cfg, get_cfg))
        `brt_fatal("body", "Unable to cast");

    `brt_info("body",$sformatf("CFG = %s", pre_cfg.sprint()), UVM_HIGH);

    `brt_create(req)
    start_item(req);
    req.cfg = pre_cfg;
    //req.payload.USER_DEFINED_ALGORITHM_wt = 1;
    //req.payload.TWO_SEED_BASED_ALGORITHM_wt = 0;

    create_request();
    finish_item(req);
    get_response(rsp);
    if (descriptor_type == `CONFIGURATION_DESCRIPTOR && rsp.payload.data.size() >= 4) begin
      total_length = {rsp.payload.data[3], rsp.payload.data[2]};
      `brt_info("body",$psprintf("CONFIGURATION DESCRIPTOR: total length %h payload %h", total_length, rsp.payload.data.size()), UVM_LOW)
      end
    #10ns;
    get_updated_cfg();
    `brt_info("body","Exiting...", UVM_HIGH)
  endtask
endclass : brt_usb_random_brt_usb_base_control_xfer_sequence 

class brt_usb_base_control_xfer_sequence extends brt_usb_random_brt_usb_base_control_xfer_sequence;

  function new(string name="brt_usb_base_control_xfer_sequence");
    super.new(name);
  endfunction

  `brt_object_utils_begin(brt_usb_base_control_xfer_sequence)
  `brt_object_utils_end

  constraint desc_length_constr {
    (req_type == brt_usb_types::GET_DESCRIPTOR && descriptor_type == `DEVICE_DESCRIPTOR)             -> w_length == 18;
    (req_type == brt_usb_types::GET_DESCRIPTOR && descriptor_type == `CONFIGURATION_DESCRIPTOR)      -> w_length == 9;
    (req_type == brt_usb_types::GET_DESCRIPTOR && descriptor_type == `INTERFACE_DESCRIPTOR)          -> w_length == 9;
    (req_type == brt_usb_types::GET_DESCRIPTOR && descriptor_type == `ENDPOINT_DESCRIPTOR)           -> w_length == 7;
    (req_type == brt_usb_types::GET_DESCRIPTOR && descriptor_type == `DEVICE_QUALIFIER_DESCRIPTOR)   -> w_length == 10;
    (req_type == brt_usb_types::GET_DESCRIPTOR && descriptor_type == `OTHER_SPEED_DESCRIPTOR)        -> w_length == 9;
    (req_type == brt_usb_types::SET_DESCRIPTOR && descriptor_type == `DEVICE_DESCRIPTOR)             -> w_length == 18;
    (req_type == brt_usb_types::SET_DESCRIPTOR && descriptor_type == `CONFIGURATION_DESCRIPTOR)      -> w_length == 9;
    (req_type == brt_usb_types::SET_DESCRIPTOR && descriptor_type == `INTERFACE_DESCRIPTOR)          -> w_length == 9;
    (req_type == brt_usb_types::SET_DESCRIPTOR && descriptor_type == `ENDPOINT_DESCRIPTOR)           -> w_length == 7;
    (req_type == brt_usb_types::SET_DESCRIPTOR && descriptor_type == `DEVICE_QUALIFIER_DESCRIPTOR)   -> w_length == 10;
    (req_type == brt_usb_types::SET_DESCRIPTOR && descriptor_type == `OTHER_SPEED_DESCRIPTOR)        -> w_length == 9;
    }

  constraint standard_dev_request_constr {
    req_type == brt_usb_types::GET_STATUS ->
         xfer_dir             == 1                 
      && w_value              == 0
      && w_length             == 2;
    (req_type == brt_usb_types::GET_STATUS && target == 0) -> w_index              == 0;
    (req_type == brt_usb_types::GET_STATUS && target == 1) -> w_index              == interface_num && interface_num==0;
    (req_type == brt_usb_types::GET_STATUS && target == 2) -> w_index              == {8'h0, endpoint_dir, endpoint_num};

    req_type == brt_usb_types::GET_INTERFACE ->
         xfer_dir             == 1                 
      && target               == 1
      && w_value              == 0
      && w_index              == interface_num
      && w_length             == 1;

    req_type == brt_usb_types::GET_DESCRIPTOR ->
         xfer_dir             == 1                 
      && target               == 0
      && w_value              == {descriptor_type,8'h0}
      && w_length              <  128;
    (req_type == brt_usb_types::GET_DESCRIPTOR && descriptor_type != `STRING_DESCRIPTOR) -> w_index == 0;

    req_type == brt_usb_types::GET_CONFIGURATION ->
         xfer_dir             == 1                 
      && target               == 0
      && w_value              == 0
      && w_index              == 0
      && w_length             == 1;

    req_type == brt_usb_types::SYNCH_FRAME ->
         xfer_dir             == 1                 
      && target               == 2
      && w_value              == 0
      && w_index              == {8'h0, endpoint_dir, endpoint_num}
      && w_length             == 2;

    req_type == brt_usb_types::SET_FEATURE ->
         xfer_dir == 0                 
      && test_selector        inside {0,1,2,3,4,5} 
      && feature_selector     inside {0,1,2} // 0: ep halt , 1: dev rmwakeup, 2: dev testmode
      && w_value              == {8'h0, feature_selector} 
      && w_index              == {test_selector, feature_target} 
      && w_length             == 0;
    (req_type == brt_usb_types::SET_FEATURE && feature_selector == 2) -> 
      test_selector           inside {1,2,3,4} 
      &&    target            == 0 
      &&    feature_target    == 0;

    (req_type == brt_usb_types::SET_FEATURE && feature_selector == 1) -> 
      test_selector           == 0 
      && target               == 0 
      && feature_target       == 0;
    (req_type == brt_usb_types::SET_FEATURE && feature_selector == 0) -> 
      test_selector           == 0 
      && target               == 2 
      && feature_target       == {endpoint_dir, endpoint_num};

    req_type == brt_usb_types::CLEAR_FEATURE ->
      xfer_dir                == 0                 
      && feature_selector     inside {0,1,2} // 0: ep halt , 1: dev rmwakeup, 2: dev testmode
      && w_value              == {8'h0, feature_selector} 
      && w_index              == {8'h0, feature_target} 
      && w_length             == 0;
    (req_type == brt_usb_types::CLEAR_FEATURE && feature_selector == 2) -> 
      test_selector           inside {1,2,3,4} 
      &&    target            == 0 
      &&    feature_target    == 0;

    (req_type == brt_usb_types::CLEAR_FEATURE && feature_selector == 1) -> 
      test_selector           == 0 
      && target               == 0 
      && feature_target       == 0;
    (req_type == brt_usb_types::CLEAR_FEATURE && feature_selector == 0) -> 
      test_selector           == 0 
      && target               == 2 
      && feature_target       == {endpoint_dir, endpoint_num};
    
    req_type == brt_usb_types::SET_ADDRESS ->
         xfer_dir             == 0                 
      && target               == 0
      && w_value              == dev_addr
      && w_index              == 0
      && w_length             == 0;

    req_type == brt_usb_types::SET_CONFIGURATION ->
         xfer_dir             == 0                 
      && target               == 0
      && w_value              == configuration_val
      && w_index              == 0
      && w_length             == 0;

    req_type == brt_usb_types::SET_INTERFACE ->
        xfer_dir              == 0                 
      && target               == 1
      && w_value              == alt_setting
      && w_index              == interface_num
      && w_length             == 0;

    req_type == brt_usb_types::SET_DESCRIPTOR ->
         xfer_dir             == 0                 
      && target               == 0
      && w_value              == {descriptor_type,8'h0}
      && w_length              <  128;

    (req_type == brt_usb_types::SET_DESCRIPTOR && descriptor_type != `STRING_DESCRIPTOR) -> w_index == 0;
  }

  constraint desc_constr {
    descriptor_type == `DEVICE_DESCRIPTOR ||
    descriptor_type == `CONFIGURATION_DESCRIPTOR ||
    descriptor_type == `STRING_DESCRIPTOR ||
    descriptor_type == `INTERFACE_DESCRIPTOR ||
    descriptor_type == `ENDPOINT_DESCRIPTOR ||
    descriptor_type == `DEVICE_QUALIFIER_DESCRIPTOR ||
    descriptor_type == `OTHER_SPEED_DESCRIPTOR ||
    descriptor_type == `INTERFACE_POWER_DESCRIPTOR ;
  }

  constraint device_address_constr {
    dev_addr > 0 && dev_addr <= 127;
  }

  constraint target_constr {
    target inside {0,1,2}; // device, interface, endpoint
  }

  constraint endpoint_constr {
    endpoint_num inside {[0:15]}; 
  }
    
endclass

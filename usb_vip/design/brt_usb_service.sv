
class brt_usb_protocol_service extends brt_usb_base_sequence_item;
  typedef enum int {
    LMP, LPM, SOF, ITP, TP, TEST_MODE, CMD
  } service_type_e;

  typedef enum int {
    USB_CLEAR_EP_HALT
  } protocol_command_type_e;

  typedef enum int {
    USB_20_SOF_ON, 
    USB_20_SOF_OFF, 
    USB_20_TEST_MODE_TEST_PACKET, 
    USB_20_TEST_MODE_TEST_SE0_NAK, 
    USB_20_TEST_MODE_TEST_J, 
    USB_20_TEST_MODE_TEST_K, 
    USB_20_TEST_MODE_EXIT 
  } protocol_20_command_type_e;

  rand brt_usb_types::ep_dir_e 				direction;
  rand bit[6:0] 								device_address;
  rand bit[3:0]								endpoint_number;
  rand service_type_e 						service_type;
  rand protocol_20_command_type_e 		protocol_20_command_type;
  rand protocol_command_type_e 			protocol_command_type;


  `brt_object_utils(brt_usb_protocol_service)

  function new(string name="brt_usb_protocol_service");
    super.new(name);
  endfunction

endclass

class brt_usb_link_service extends brt_usb_base_sequence_item;

  brt_usb_config cfg;

  typedef enum int {
    LINK_COMMAND, PACKET_ABORT, 
    LINK_20_PORT_COMMAND, LINK_SS_PORT_COMMAND,
    START_BEHAVIOR, STOP_BEHAVIOR
  } service_type_e;

  typedef enum int {
    USB_SS_POWER_ON_RESET, USB_SS_HOT_RESET, USB_SS_WARM_RESET,
    USB_SS_STATE_CHANGE, USB_SS_LOOPBACK_VIA_RX_DETECT,
    USB_SS_LOOPBACK_VIA_RECOVERY, USB_SS_U2_TIMEOUT,
    USB_SS_ATTEMPT_U1_ENTRY,
    USB_SS_ATTEMPT_U2_ENTRY,
    USB_SS_ATTEMPT_U3_ENTRY,
    USB_SS_CANCEL_LP_ENTRY_ATTEMPT,
    USB_SS_FORCE_LINKPM, USB_SS_SET_TRANSMIT_RESET,
    USB_SS_SET_TRANSMIT_LOOPBACK, USB_SS_SET_TRANSMIT_DIS_SCRAM,
    USB_SS_TRANSMIT_LFPS_EXIT, USB_SS_DISABLE_PACKETS, 
    USB_SS_ENABLE_PACKETS, USB_SS_RESTART_BERT, USB_SS_REQUEST_BERC,
    USB_SS_MONITOR_INACTIVITY, USB_SS_OTG_ROLE_SWAP_STATUS, USB_SS_INACTIVE,
    USB_SSIC_USP_DISCONNECT, USB_SSIC_RECONNECT, USB_SSIC_DPS_DISCONNECT,
    USB_SSIC_EXIT_LOW_POWER_STATE, USB_SSIC_LINE_RESET
  } link_ss_command_type_e;

  typedef enum int {
    USB_20_PORT_RESET, 				// Driving Se0
    USB_20_SET_PORT_SUSPEND, 		// host into suspend
    USB_20_CLEAR_PORT_SUSPEND, 	// host to drive resume
    USB_20_PORT_START_LPM, 		// request link to L1
    USB_20_PORT_INITIATE_SRP,
    USB_20_PORT_TEST_MODE_TEST_J,
    USB_20_PORT_TEST_MODE_TEST_K,
    USB_20_PORT_TEST_MODE_TEST_SE0_NAK,
    USB_20_PORT_TEST_MODE_TEST_PACKET,
    USB_20_PORT_TEST_MODE_EXIT,
    USB_20_PORT_UTMI_PIN_RESET
  } link_20_command_type_e;

  service_type_e 				service_type;
  link_ss_command_type_e 	link_ss_command_type;
  link_20_command_type_e 	link_20_command_type;
  brt_usb_types::ltssm_state_e prereq_ltssm_state;

  `brt_object_utils_begin(brt_usb_link_service)
    `brt_field_enum(service_type_e, 				service_type, 				UVM_ALL_ON|UVM_NOPACK);
    `brt_field_enum(link_ss_command_type_e, 		link_ss_command_type, 	UVM_ALL_ON|UVM_NOPACK);
    `brt_field_enum(link_20_command_type_e, 		link_20_command_type, 	UVM_ALL_ON|UVM_NOPACK);
    `brt_field_enum(brt_usb_types::ltssm_state_e,	prereq_ltssm_state, 		UVM_ALL_ON|UVM_NOPACK);
  `brt_object_utils_end

  function new(string name="brt_usb_link_service");
    super.new(name);
  endfunction

endclass

class brt_usb_physical_service extends brt_usb_base_sequence_item;
  `brt_object_utils(brt_usb_physical_service)

  function new(string name="brt_usb_physical_service");
    super.new(name);
  endfunction

endclass


class brt_usb_transaction extends brt_usb_base_sequence_item;
  `brt_object_utils(brt_usb_transaction)

  function new(string name="brt_usb_transaction");
    super.new(name);
  endfunction

endclass

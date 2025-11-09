// File name:
// Author: DucDinh
// Date: 28 Oct 2016

class brt_usb_types extends brt_object;
  `brt_object_utils(brt_usb_types)

  typedef enum int {
    DEVICE_DESC                  = `DEVICE_DESCRIPTOR,
    CONFIGURATION_DESC           = `CONFIGURATION_DESCRIPTOR,
    STRING_DESC                  = `STRING_DESCRIPTOR,
    INTERFACE_DESC               = `INTERFACE_DESCRIPTOR,
    ENDPOINT_DESC                = `ENDPOINT_DESCRIPTOR,
    DEVICE_QFR_DESC              = `DEVICE_QUALIFIER_DESCRIPTOR,
    OTHER_SPEED_DESC             = `OTHER_SPEED_DESCRIPTOR,
    INT_POWER_DESC               = `INTERFACE_POWER_DESCRIPTOR,
    OTG_DESC                     = `OTG_DESCRIPTOR,
    DEBUG_DESC                   = `DEBUG_DESCRIPTOR,
    INT_ASC_DESC                 = `INTERFACE_ASSOCIATION_DESCRIPTOR,
    BOS_DESC                     = `BOS_DESCRIPTOR,
    DEVICE_CAP_DESC              = `DEVICE_CAPABILITY_DESCRIPTOR,
    SS_USB_ENDPCOMP_DESC         = `SUPERSPEED_USB_ENDPOINT_COMPANION,
    UNKNOWN_DESC
  } descriptor_e; 

  typedef enum int {
    NO_STATE, POWERED_OFF, DISCONNECTED,
    DEVICE_ATTACHED, RESETTING, ENABLED,
    TRANSMIT, TRANSMIT_R, SUSPENDED, 
    RESUMING, SEND_EOR, RESTART_S, RESTART_E,
    BUS_RESET, RECEIVING_IS, RECEIVING_HJ, RECEIVING_HK,
    RECEIVING_J, SUSPEND, RECEIVING_K, RESUME, 
    RECEIVING_SE0, INACTIVE, ACTIVE, REPEATING_SE0, SEND_J,
    GEOPTU, S_RESUME, WLPM, L1SUSPENDED, L1RESUMING, 
    RESTART_L1S, L1SUSPEND, L1RESUME, L1TIMINGSE0,
    L1RECEIVING_SE0, L1S_RESUME, A_WAIT_VRISE, A_WAIT_VFALL,
    TESTING, DRIVE_TEST_MODE_DATA, RESET_OR_RESTART_S,
    WAIT_CHIRP, DEV_CHIRP, HST_CHIRP_END, AEOF,
    SOF, RESUME_END, RESUME_DONE, TEST_PKT, 
    PRE_ENABLE, SOF_END, TEST, HST_CHIRP_DONE,
    HST_CHIRP_SWITCH_OPMODE
  } link20sm_state_e;

  typedef enum bit[1:0] {
    LS=0, FS=1, HS=2, SS=3
  } speed_e;

  typedef enum bit[3:0] {
    LINESTATE_SE0,
    LINESTATE_K,
    LINESTATE_J,
    LINESTATE_SE1,
    LINESTATE_Z,
    LINESTATE_UNKNOWN
  } linestate_value_e;


  typedef enum bit {
    HOST = 0, DEVICE = 1
  } component_type_e;

  typedef enum bit[1:0] {
    OUT = 0, IN = 1, UNDEFDIR = 2
  } ep_dir_e;

  typedef enum bit {
    TO_DEVICE = 0, TO_HOST = 1
  } pkt_dir_e;

  typedef enum bit[1:0] {
    CONTROL = 2'b00, ISOCHRONOUS = 2'b01, BULK = 2'b10, INTERRUPT = 2'b11
  } ep_type_e;

  typedef enum bit {
    HOST_TO_DEVICE = 0, DEVICE_TO_HOST = 1
  } setup_data_bmrequesttype_dir_e;

  typedef enum bit[4:0] {
    BMREQ_DEVICE = 0, BMREQ_INTERFACE = 1, BMREQ_ENDPOINT = 2,
    BMREQ_OTHER = 3
  } setup_data_bmrequesttype_recipient_e;

  typedef enum bit[1:0] {
    STANDARD = 0, CLASS = 1, VENDOR = 2, RESERVED = 3
  } setup_data_bmrequesttype_type_e;

  typedef enum bit[7:0] {
    GET_STATUS = 0, CLEAR_FEATURE = 1, SET_FEATURE = 3, SET_ADDRESS = 5,
    GET_DESCRIPTOR = 6, SET_DESCRIPTOR = 7, GET_CONFIGURATION = 8,
    SET_CONFIGURATION = 9, GET_INTERFACE = 10, SET_INTERFACE = 11,
    SYNCH_FRAME = 12, SET_SEL, SET_ISOCH_DELAY, USER_DEFINE
  } setup_data_brequest_e;

  typedef enum bit[4:0] {
    INITIAL = 0, RETRY = 1, RUNNING = 2,
    PARTIAL_ACCEPT = 3, ACCEPT = 4,
    DISABLED = 5, CANCELLED = 6,
    ABORTED = 7
  } tfer_status_e;

  typedef enum int {
    SS_INACTIVE, RX_DETECT, POLLING,
    SS_DISABLED, COMPLIANCE_MODE, 
    LOOPBACK, HOT_RESET, RECOVERY,
    U0, U1, U2, U3, MPHY_TEST
  } ltssm_state_e;

  typedef enum bit[1:0] {
    EP_DISABLE = 0, EP_ENABLE = 1,
    EP_HALT = 2
  } ep_state_e;

  typedef enum {
      TOKEN_PHASE = 0, DATA_PHASE = 1, RSP_PHASE = 2,
      PING_PHASE  = 3, TIMEOUT_PHASE = 4
  } packet_phase_e;

  typedef enum {
      PID_ERR = 0, CRC5_ERR = 1, CRC16_ERR = 2,
      TIMEOUT_ERR  = 3, RESERVE_ERR = 10
  } packet_err_e;

  function new(string name="brt_usb_types");
    super.new(name);
  endfunction

endclass

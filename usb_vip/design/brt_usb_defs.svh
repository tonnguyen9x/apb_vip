`ifndef DATA8_SIZE                                                                                                       
    `define DATA8_SIZE  9*1024
`endif
     
`ifndef NUM_EP
    `define NUM_EP  16  
`endif

`ifndef NUM_NAK_XFER
    `define NUM_NAK_XFER  1000
`endif

// for debugging
`define IGNORE_HOST_ERR   0
`define IGNORE_DEV_ERR    1
`define IGNORE_MON_TX_ERR   1

// FS power on reset
`ifndef FS_EXT_RST_IDLE
    `define FS_EXT_RST_IDLE 1ms
`endif
`ifndef LS_EXT_RST_IDLE
    `define LS_EXT_RST_IDLE 10us
`endif
`ifndef HS_EXT_RST_IDLE
    `define HS_EXT_RST_IDLE 10us
`endif



`define VIP_BASE_ENV
`define DEVICE_DESCRIPTOR 1
`define CONFIGURATION_DESCRIPTOR 2
`define STRING_DESCRIPTOR 3
`define INTERFACE_DESCRIPTOR 4
`define ENDPOINT_DESCRIPTOR 5
`define DEVICE_QUALIFIER_DESCRIPTOR 6
`define OTHER_SPEED_DESCRIPTOR 7
`define INTERFACE_POWER_DESCRIPTOR 8
`define OTG_DESCRIPTOR 9
`define DEBUG_DESCRIPTOR 10
`define INTERFACE_ASSOCIATION_DESCRIPTOR 11
`define BOS_DESCRIPTOR 15
`define DEVICE_CAPABILITY_DESCRIPTOR 16
`define SUPERSPEED_USB_ENDPOINT_COMPANION 48

// UTMI mode
`define UTMI_NORMAL    0
`define UTMI_NONDRV    1
`define UTMI_DISENCODE 2
`define UTMI_RESERVE   3

`define TESTMODE_NAK   0
`define TESTMODE_J     1
`define TESTMODE_K     2
`define TESTMODE_DATA  3


`define FORK_GUARD_BEGIN fork begin
`define FORK_GUARD_END   end join

`define SUBLPM         4'h3


// HOST drive strength
`ifndef BRT_USB_HOST_DRIVE_STRENGTH_PU_0
  `define BRT_USB_HOST_DRIVE_STRENGTH_PU_0 weak0
`endif
`ifndef BRT_USB_HOST_DRIVE_STRENGTH_PU_1
  `define BRT_USB_HOST_DRIVE_STRENGTH_PU_1 weak1
`endif

`ifndef BRT_USB_HOST_DRIVE_STRENGTH_SE0_0
  `define BRT_USB_HOST_DRIVE_STRENGTH_SE0_0 pull0
`endif
`ifndef BRT_USB_HOST_DRIVE_STRENGTH_SE0_1
  `define BRT_USB_HOST_DRIVE_STRENGTH_SE0_1 pull1
`endif

`ifndef BRT_USB_HOST_DRIVE_STRENGTH_TX_0
  `define BRT_USB_HOST_DRIVE_STRENGTH_TX_0 strong0
`endif
`ifndef BRT_USB_HOST_DRIVE_STRENGTH_TX_1
  `define BRT_USB_HOST_DRIVE_STRENGTH_TX_1 strong1
`endif

// DEVICE drive strength
`ifndef BRT_USB_DEVICE_DRIVE_STRENGTH_PU_0
  `define BRT_USB_DEVICE_DRIVE_STRENGTH_PU_0 weak0
`endif
`ifndef BRT_USB_DEVICE_DRIVE_STRENGTH_PU_1
  `define BRT_USB_DEVICE_DRIVE_STRENGTH_PU_1 weak1
`endif

`ifndef BRT_USB_DEVICE_DRIVE_STRENGTH_SE0_0
  `define BRT_USB_DEVICE_DRIVE_STRENGTH_SE0_0 strong0
`endif
`ifndef BRT_USB_DEVICE_DRIVE_STRENGTH_SE0_1
  `define BRT_USB_DEVICE_DRIVE_STRENGTH_SE0_1 strong1
`endif

`ifndef BRT_USB_DEVICE_DRIVE_STRENGTH_TX_0
  `define BRT_USB_DEVICE_DRIVE_STRENGTH_TX_0 strong0
`endif
`ifndef BRT_USB_DEVICE_DRIVE_STRENGTH_TX_1
  `define BRT_USB_DEVICE_DRIVE_STRENGTH_TX_1 strong1
`endif


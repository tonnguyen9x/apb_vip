interface brt_usb_20_utmi_if();
  logic [15:0]   utmidatao;
  logic [1:0]    utmiopmode;
  logic          utmixcvrselect;
  logic          utmitermselect;
  logic          utmisuspendm;
  logic          utmitxvalid;
  logic [7:0]    utmidatai;
  logic [1:0]    utmilinestate;
  logic          utmitxready;
  logic          utmirxvalid;
  logic          utmirxactive;
  logic          utmirxerror;
  logic          clk_utmi;
endinterface

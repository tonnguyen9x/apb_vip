class brt_usb_bad_packet extends brt_usb_packet;

  `brt_object_utils(brt_usb_bad_packet)
  
  function new(string name="brt_usb_bad_packet");
    super.new(name);
  endfunction

  virtual function void gen_data_crc16();
    data_crc16 = ~calculate_data_crc16();
  endfunction
  
endclass

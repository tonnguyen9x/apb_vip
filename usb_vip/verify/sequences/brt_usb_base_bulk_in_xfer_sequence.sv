class brt_usb_base_bulk_in_xfer_sequence extends brt_usb_base_random_xfer_sequence;
	`brt_object_utils_begin(brt_usb_base_bulk_in_xfer_sequence)
	`brt_object_utils_end

  constraint bulk_constr {
    ttype == brt_usb_transfer::BULK_IN_TRANSFER;
    }

  function new(string name="brt_usb_base_bulk_in_xfer_sequence");
    super.new(name);
  endfunction : new
  
endclass

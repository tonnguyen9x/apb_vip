class brt_usb_base_isochronous_out_xfer_sequence extends brt_usb_base_random_isochronous_xfer_sequence;

	`brt_object_utils_begin(brt_usb_base_isochronous_out_xfer_sequence)
	`brt_object_utils_end

  constraint isochronous_constr {
    ttype == brt_usb_transfer::ISOCHRONOUS_OUT_TRANSFER;
    }

  function new(string name="brt_usb_base_isochronous_out_xfer_sequence");
    super.new(name);
  endfunction : new
  
endclass

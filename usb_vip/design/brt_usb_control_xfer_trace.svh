			brt_usb_types::CLEAR_FEATURE: begin
				$sformat(s, "%s    . feature select           %h\n", s, wvalue);
				end
			brt_usb_types::GET_CONFIGURATION: begin
				$sformat(s, "%s    . config value             %h\n", s, transfer.payload.data[0]);
				end
			brt_usb_types::GET_INTERFACE: begin
				$sformat(s, "%s    . alt setting              %h\n", s, transfer.payload.data[0]);
				end
			brt_usb_types::GET_STATUS: begin
				$sformat(s, "%s    . D/I/EP status            %h\n", s, {transfer.payload.data[1], transfer.payload.data[0]});
				end
			brt_usb_types::SET_ADDRESS: begin
				$sformat(s, "%s    . Device Address           %h\n", s, wvalue);
				end
			brt_usb_types::SET_CONFIGURATION: begin
				$sformat(s, "%s    . Config Value             %h\n", s, wvalue);
				end
			brt_usb_types::SET_FEATURE: begin
				$sformat(s, "%s    . feature select           %h\n", s, wvalue);
				end
			brt_usb_types::SET_INTERFACE: begin
				$sformat(s, "%s    . Alt setting              %h\n", s, wvalue);
				end
			brt_usb_types::SET_ISOCH_DELAY: begin
				$sformat(s, "%s    . delay in ns              %h\n", s, wvalue);
				end
			brt_usb_types::SYNCH_FRAME: begin
				$sformat(s, "%s    . frame number             %h\n", s, {transfer.payload.data[1], transfer.payload.data[0]});
				end
			brt_usb_types::SET_SEL: begin
				$sformat(s, "%s    . exit latency             %h\n", s, {transfer.payload.data[5],transfer.payload.data[4],transfer.payload.data[3],transfer.payload.data[2],transfer.payload.data[1],transfer.payload.data[0]});
				end
			brt_usb_types::SET_DESCRIPTOR: begin
				$sformat(s, "%s    . descriptor type          %s\n", s, "Unknown");
				end
			brt_usb_types::GET_DESCRIPTOR : begin
          	bit [7:0] descriptor_type;
          	bit [7:0] descriptor_idx;
				int length;
				int prev_length;
				length = 0;
				prev_length = 0;
				{descriptor_type, descriptor_idx} =  wvalue;
				$sformat(s, "%s    . descriptor type %h\n", s, descriptor_type);
				case (descriptor_type)
					`DEVICE_DESCRIPTOR: begin
							$sformat(s, "%s    . descriptor type          %s\n", s, "DEVICE_DESCRIPTOR");
							for (int i = 0; i<transfer.payload.data.size(); i++) begin
								case(i)
									0: begin : bLength
											$sformat(s, "%s    . bLength                 d%0d bytes (act d%0d)\n", s, transfer.payload.data[i], transfer.payload.data.size());
											end
									1: begin : bDescriptorType
											$sformat(s, "%s    . bDescriptorType          %h\n", s, transfer.payload.data[i]);
											end
									2: begin : bcdUSB
											$sformat(s, "%s    . bcdUSB                   %h\n", s, {transfer.payload.data[i+1], transfer.payload.data[i]});
											i++; //2bytes
											end
									4: begin : bDeviceClass
											$sformat(s, "%s    . bDeviceClass             %h\n", s, transfer.payload.data[i]);
											end
									5: begin : bDeviceSubClass
											$sformat(s, "%s    . bDeviceSubClass          %h\n", s, transfer.payload.data[i]);
											end
									6: begin : bDeviceProtocol
											$sformat(s, "%s    . bDeviceProtocol          %h\n", s, transfer.payload.data[i]);
											end
									7: begin : bMaxPacketSize0
											$sformat(s, "%s    . bMaxPacketSize0          %h\n", s, transfer.payload.data[i]);
											end
									8: begin : idVendor
											$sformat(s, "%s    . idVendor                 %h\n", s, {transfer.payload.data[i+1], transfer.payload.data[i]});
											i++; //2bytes
											end
									10: begin : idProduct
											$sformat(s, "%s    . idProduct                %h\n", s, {transfer.payload.data[i+1], transfer.payload.data[i]});
											i++; //2bytes
											end
									12: begin : bcdDevice
											$sformat(s, "%s    . bcdDevice                %h\n", s, {transfer.payload.data[i+1], transfer.payload.data[i]});
											i++; //2bytes
											end
									14: begin : iManufacturer
											$sformat(s, "%s    . iManufacturer            %h\n", s, transfer.payload.data[i]);
											end
									15: begin : iProduct
											$sformat(s, "%s    . iProduct                 %h\n", s, transfer.payload.data[i]);
											end
									16: begin : iSerialNumber
											$sformat(s, "%s    . iSerialNumber            %h\n", s, transfer.payload.data[i]);
											end
									17: begin : bNumConfigurations
											$sformat(s, "%s    . bNumConfiguration        %h\n", s, transfer.payload.data[i]);
											end
								endcase
								end
							end
 					`CONFIGURATION_DESCRIPTOR: begin
							$sformat(s, "%s    . descriptor type          %s\n", s, "CONFIGURATION_DESCRIPTOR");
							for (int i = 0; i<transfer.payload.data.size(); i++) begin
								case(i)
									0: begin : bLength
											$sformat(s, "%s    . bLength                 d%0d bytes (act d%0d)\n", s, transfer.payload.data[i], transfer.payload.data.size());
											end
									1: begin : bDescriptorType
											$sformat(s, "%s    . bDescriptorType          %h\n", s, transfer.payload.data[i]);
											end
									2: begin : wTotalLength
											$sformat(s, "%s    . wTotalLength             %h\n", s, {transfer.payload.data[i+1], transfer.payload.data[i]});
											i++; //2bytes
											end
									4: begin : bNumInterfaces
											$sformat(s, "%s    . bNumInterfaces           %h\n", s, transfer.payload.data[i]);
											end
									5: begin : bConfigurationValue
											$sformat(s, "%s    . bConfigurationValue      %h\n", s, transfer.payload.data[i]);
											end
									6: begin : iConfiguration
											$sformat(s, "%s    . iConfiguration           %h\n", s, transfer.payload.data[i]);
											end
									7: begin : bmAttributes
											$sformat(s, "%s    . bmAttributes             %h\n", s, transfer.payload.data[i]);
											end
									8: begin : bMaxPower
											$sformat(s, "%s    . bMaxPower                %h\n", s, transfer.payload.data[i]);
											end

									default: begin
											string prefix;
											string temp_str;
											int offset;
											bit incr;
											prefix = "--- ";
											if (i-9-length == 0) begin
												prev_length = length;
												length = prev_length + transfer.payload.data[i];
												end
											offset = i-9-prev_length;
											if (offset == 0) begin
												$sformat(s, "%s    %s. bLength                 d%0d bytes (act d%0d)\n", s, prefix, transfer.payload.data[i], transfer.payload.data.size());
												end
											else begin
											   //temp_str = display_field(offset, prefix, transfer.payload.data[i], transfer.payload.data[i+1], incr); 
												$sformat(s, "%s%s", s, temp_str);
												if (incr) i++;
												end
											end
								endcase
								end
							end
					`STRING_DESCRIPTOR:
							$sformat(s, "%s    . descriptor type          %s\n", s, "STRING_DESCRIPTOR");
					`INTERFACE_DESCRIPTOR: begin
							$sformat(s, "%s    . descriptor type          %s\n", s, "INTERFACE_DESCRIPTOR");
							for (int i = 0; i<transfer.payload.data.size(); i++) begin
								case(i)
									0: begin : bLength
											$sformat(s, "%s    . bLength                 d%0d bytes (act d%0d)\n", s, transfer.payload.data[i], transfer.payload.data.size());
											end
									1: begin : bDescriptorType
											$sformat(s, "%s    . bDescriptorType          %h\n", s, transfer.payload.data[i]);
											end
									2: begin : bInterfaceNumber
											$sformat(s, "%s    . bInterfaceNumber         %h\n", s, transfer.payload.data[i]);
											end
									3: begin : bAlternateSetting
											$sformat(s, "%s    . bAlternateSetting        %h\n", s, transfer.payload.data[i]);
											end
									4: begin : bNumEndpoints
											$sformat(s, "%s    . bNumEndpoint             %h\n", s, transfer.payload.data[i]);
											end
									5: begin : bInterfaceClass
											$sformat(s, "%s    . bInterfaceClass          %h\n", s, transfer.payload.data[i]);
											end
									6: begin : bInterfaceSubClass
											$sformat(s, "%s    . bInterfaceSubClass       %h\n", s, transfer.payload.data[i]);
											end
									7: begin : bInterfaceProtocol
											$sformat(s, "%s    . bInterfaceProtocol       %h\n", s, transfer.payload.data[i]);
											end
									8: begin : iInterface
											$sformat(s, "%s    . iInterface               %h\n", s, transfer.payload.data[i]);
											end
								endcase
								end
							end
					`ENDPOINT_DESCRIPTOR: begin
							$sformat(s, "%s    . descriptor type          %s\n", s, "ENDPOINT_DESCRIPTOR");
							for (int i = 0; i<transfer.payload.data.size(); i++) begin
								case(i)
									0: begin : bLength
											$sformat(s, "%s    . bLength                 d%0d bytes (act d%0d)\n", s, transfer.payload.data[i], transfer.payload.data.size());
											end
									1: begin : bDescriptorType
											$sformat(s, "%s    . bDescriptorType          %h\n", s, transfer.payload.data[i]);
											end
									2: begin : bEndpointAddress
											$sformat(s, "%s    . bEndpointAddress         %h\n", s, transfer.payload.data[i]);
											end
									3: begin : bmAttributes
											$sformat(s, "%s    . bmAttributes             %h\n", s, transfer.payload.data[i]);
											end
									4: begin : wMaxPacketSize
											$sformat(s, "%s    . wMaxPacketSize           %h\n", s, {transfer.payload.data[i+1], transfer.payload.data[i]});
											i++; //2bytes
											end
									6: begin : bInterval
											$sformat(s, "%s    . bInterval                %h\n", s, transfer.payload.data[i]);
											end
								endcase
								end
							end
					`DEVICE_QUALIFIER_DESCRIPTOR:
							$sformat(s, "%s    . descriptor type          %s\n", s, "DEVICE_QUALIFIER_DESCRIPTOR");
					`OTHER_SPEED_DESCRIPTOR: begin
							$sformat(s, "%s    . descriptor type          %s\n", s, "OTHER_SPEED_DESCRIPTOR");
							for (int i = 0; i<transfer.payload.data.size(); i++) begin
								case(i)
									0: begin : bLength
											$sformat(s, "%s    . bLength                 d%0d bytes (act d%0d)\n", s, transfer.payload.data[i], transfer.payload.data.size());
											end
									1: begin : bDescriptorType
											$sformat(s, "%s    . bDescriptorType          %h\n", s, transfer.payload.data[i]);
											end
									2: begin : wTotalLength
											$sformat(s, "%s    . wTotalLength             %h\n", s, {transfer.payload.data[i+1], transfer.payload.data[i]});
											i++; //2bytes
											end
									4: begin : bNumInterfaces
											$sformat(s, "%s    . bNumInterfaces           %h\n", s, transfer.payload.data[i]);
											end
									5: begin : bConfigurationValue
											$sformat(s, "%s    . bConfigurationValue      %h\n", s, transfer.payload.data[i]);
											end
									6: begin : iConfiguration
											$sformat(s, "%s    . iConfiguration           %h\n", s, transfer.payload.data[i]);
											end
									7: begin : bmAttributes
											$sformat(s, "%s    . bmAttributes             %h\n", s, transfer.payload.data[i]);
											end
									8: begin : bMaxPower
											$sformat(s, "%s    . bMaxPower                %h\n", s, transfer.payload.data[i]);
											end
								endcase
								end
							end
					`INTERFACE_POWER_DESCRIPTOR:
							$sformat(s, "%s    . descriptor type          %s\n", s, "INTERFACE_POWER_DESCRIPTOR");
				endcase
				end
			default : begin
				$sformat(s, "%s    . Type          %s\n", s, "Unknown Request");
				end

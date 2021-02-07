class LIRCHandler < EM::Connection
  include MyOperations

  def initialize(common)
    @common = common
  end

  def ir_send(device = "HKHD7325", button)
    EM.add_timer(0.1) do
      puts "SEND_ONCE #{device} #{button}"
      @common.lirc.send_data "SEND_ONCE #{device} #{button}\n"
    end
  end

  def receive_data data
    case data
#    when "00002a4c0a4182c9 00 SRC_DNP_INTERNET_RADIO Denon_RC-1163\n"
#      @common.denon.on_network_function :internet_radio
#    when "00002a4c0a4582cd 00 SRC_DNP_ONLINE_MUSIC Denon_RC-1163\n"
#      @common.denon.on_network_function :online_music
#    when "00002a4c0a4982c1 00 SRC_DNP_MUSIC_SERVER Denon_RC-1163\n"
#      @common.denon.on_network_function :music_server
#    when "00002a4c0a4d82c5 00 SRC_DNP_USB Denon_RC-1163\n"
#      @common.denon.on_network_function :network_usb
    when "00002a4c0aefd237 00 KEY_ADD Denon_RC-1163\n"
       @common.denon.on_button(:add)
    when "00002a4c0ae7d23f 00 KEY_CALL Denon_RC-1163\n"
      @common.denon.on_button(:call)
    when "00002a4c0ae652be 00 KEY_NETWORK_SETUP Denon_RC-1163\n"
      @common.denon.on_button(:network_setup)
    end
  end
end

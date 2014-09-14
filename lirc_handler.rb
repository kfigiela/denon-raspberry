class LIRCHandler < EM::Connection
  include MyOperations
    
  def initialize(common)
    @common = common
  end
  
  def receive_data data
    case data
    when "00002a4c0aefd237 00 KEY_ADD Denon_RC-1163\n"
      puts "add"
      tty_send " "
    when "00002a4c0ae7d23f 00 KEY_CALL Denon_RC-1163\n"
      "puts del"
      tty_send "\e[3~"
    when "00002a4c0ae652be 00 KEY_NETWORK_SETUP Denon_RC-1163\n"
      nil
    end
  end
end

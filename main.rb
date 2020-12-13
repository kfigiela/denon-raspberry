#!/usr/bin/env ruby

require 'bundler/setup'

require 'eventmachine'
require 'pp'

require_relative 'lcd'
require_relative 'denon'
require_relative 'my_denon'
require_relative 'mpd_idle'
require_relative 'cec'
require_relative 'web_ui'
require_relative 'udp'
require_relative 'common'
require_relative 'preload'

I18n.enforce_available_locales = false
$stdout.sync = true

EventMachine.run do
  common = Common.new

  sp       = SerialPort.open("/dev/ttyUSB0", 115200, 8, 1, SerialPort::NONE)
  lcd      = LCD.new common
  webui    = WebSocketUI.new common
  udpui    = EventMachine.open_datagram_socket '0.0.0.0', 8080, UdpUI, common
  denon    = EventMachine.attach sp, MyDenon, common
  mpd_idle = EventMachine.connect '127.0.0.1', 6600, MPDIdle, common
  cec      = EventMachine.popen "cec-client -t p", CEC, common
  preload  = Preload.new common

  common.denon = denon
  # common.events.mpd_status.subscribe { puts "MPD Status: #{common.mpd_status}" }
  # common.events.denon_status.subscribe { |status| puts "Denon Status: #{status}" }

  Signal.trap("INT")  do
    lcd.puts_sync "Goodbye!          ", 0
    lcd.puts_sync "                 I", 1
    EventMachine.stop
  end
  Signal.trap("TERM") do
    lcd.puts_sync "Goodbye!          ", 0
    lcd.puts_sync "                 T", 1
    EventMachine.stop
  end
  Signal.trap("USR1") do
    pp denon.status
  end
end

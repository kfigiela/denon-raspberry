#!/usr/bin/env ruby


require 'bundler/setup' 

require 'eventmachine'
require 'pp'

require_relative 'lcd'
require_relative 'denon'
require_relative 'my_denon'
require_relative 'mpd_idle'
require_relative 'web_ui'
require_relative 'common'
require_relative 'preload'

I18n.enforce_available_locales = false

EventMachine.run do
  common = Common.new
  
  sp       = SerialPort.open("/dev/ttyAMA0", 115200, 8, 1, SerialPort::NONE)
  lcd      = LCD.new common
  webui    = WebSocketUI.new common
  denon    = EventMachine.attach sp, MyDenon, common
  mpd_idle = EventMachine.connect '127.0.0.1', 6600, MPDIdle, common
  preload  = Preload.new common

  common.events.mpd_status.subscribe { puts "MPD Status: #{common.mpd_status}" }
  common.events.denon_status.subscribe { |status| puts "Denon Status: #{status}" }

  Signal.trap("INT")  do 
    lcd.puts_sync "SIGINT             ", 1
    EventMachine.stop
  end
  Signal.trap("TERM") do
    lcd.puts_sync "SIGTERM             ", 1    
    EventMachine.stop 
  end
  Signal.trap("USR1") do
    p @denon.status
  end
end

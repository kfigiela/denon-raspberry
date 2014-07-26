#!/usr/bin/env ruby


require 'bundler/setup' 

require 'eventmachine'
require 'pp'

require_relative 'lcd'
require_relative 'denon'
require_relative 'my_denon'
require_relative 'mpd_idle'
require_relative 'web_ui'

I18n.enforce_available_locales = false

class KeyboardHandler < EM::Connection
  def initialize(denon)
    @denon = denon
  end

  def receive_data(data)
    pp @denon.status
  end
end

EventMachine.run do
  
  mpd = MPD.new
  mpd.connect
  puts "Connected to MPD"
  mpd.async_idle
    
  sp = SerialPort.open("/dev/ttyAMA0", 115200, 8, 1, SerialPort::NONE)
  lcd = EventMachine.connect '127.0.0.1', 13666, LCD
  ui = WebSocketUI.new(mpd)
  denon = EventMachine.attach sp, MyDenon, mpd, lcd, ui
  EventMachine.connect '127.0.0.1', 6600, MPDIdle, mpd, lcd, denon, ui
  EventMachine.open_keyboard(KeyboardHandler, denon)
end

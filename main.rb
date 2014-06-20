require 'bundler/setup' 

require 'eventmachine'
require 'em/pure_ruby'
require_relative 'lcd'
require_relative 'denon'
require_relative 'my_denon'
require_relative 'mpd_idle'

EventMachine.run do
  
  mpd = MPD.new
  mpd.connect
  puts "Connected to MPD"
  mpd.async_idle
    
  lcd = EventMachine.connect '127.0.0.1', 13666, LCD
  denon = EventMachine.open_serial '/dev/ttyAMA0', 115200, 8, 1, 0, MyDenon do |c|
    c.lcd = lcd
    c.mpd = mpd
  end
  EventMachine.connect '127.0.0.1', 6600, MPDIdle, mpd, lcd

end

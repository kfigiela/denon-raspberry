#!/usr/bin/env ruby

require 'bundler/setup'

require 'pp'
require 'eventmachine'
require_relative 'denon'


class DemoDenon < Denon
  def on_network_button(id)
    super
    puts "Button #{id} pressed and the source is Network"
  end

  def on_cd_button(id)
    super
    puts "Button #{id} pressed and the source is CD"
  end

  def on_analog1_button(id)
    super
    puts "Button #{id} pressed and the source is Analog 1"
  end
  
  def on_analog2_button(id)
    super
    puts "Button #{id} pressed and the source is Analog 2"
  end

  def on_digital_button(id)
    super
    puts "Button #{id} pressed and the source is Digital"
  end

  def on_display_brightness(brightness)
    super
    puts "Display brightness set to #{brightness}"
  end

  def on_cd_function(function)
    super
    puts "Set CD function to #{function}"
  end

  def on_network_function(function)
    super
    puts "Set Network function to #{function}"
  end

  def on_volume(vol)
    super
    puts "Volume is #{vol}"
  end

  def on_mute(status)
    super
    puts "Mute status is #{status}"
  end

  def on_sleep_timer(time)
    super
    puts "Sleep timer set to #{time}"
  end

  def on_source(source)
    super
    puts "Source set to #{source}"
  end

  def on_amp_on
    super
    puts "Amp is on"
  end

  def on_amp_off
    super
    puts "Amp is off"
  end

  def on_radio(what)
    puts "Radio operation #{what} happened, see @status"
  end

end

class KeyboardHandler < EM::Connection # this is for demo only
  include EM::Protocols::LineText2
  
  def initialize(denon)
    @denon = denon
    @a = 0
  end

  def receive_line(data)
    @denon.send_command "PWSTANDBY"
    # pp @denon.status
  end
end

EventMachine.run do
  sp = SerialPort.open("/dev/ttyUSB0", 115200, 8, 1, SerialPort::NONE)
  denon = EventMachine.attach sp, DemoDenon
  EventMachine.open_keyboard KeyboardHandler, denon
  puts "Press enter to see receiver status"
end

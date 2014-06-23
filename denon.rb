# encoding: ASCII-8BIT
require 'serialport'
require 'ruby-mpd'
require 'ostruct'
require_relative 'mpd'

class Denon < EventMachine::Connection
  
  attr_reader :status

  Station = Struct.new(:name, :frequency)
  Alarm = Struct.new(:on, :off, :status, :function, :preset)
  def initialize
    @status = Struct.new(:source, :cd_function, :network_function, :display_brightness, :radio, :audio, :alarm, :power, :sleep).new 
    @status.radio = Struct.new(:presets, :band, :stereo, :current_preset, :current_frequency).new
    @status.radio.band = :fm
    @status.radio.presets = Hash.new { |h,k| h[k] = Station.new }
    @status.audio = Struct.new(:volume, :mute, :bass, :treble, :balance, :sdb, :sdirect).new
    @status.alarm = Struct.new(:once, :every).new
    @status.alarm.once  = Alarm.new
    @status.alarm.every = Alarm.new
  end
  
  def post_init
    @buffer = "".force_encoding("ASCII-8BIT")
  end
  
  def receive_data data
    @buffer += data      
    have_packet = false
    begin
      have_packet = false
      if start = @buffer.index("\x00\xff\x55".force_encoding("ASCII-8BIT")) and (@buffer.length > start + 3)
        payload_length = 2 + @buffer.unpack('C*')[start+3]
        packet_length = 3 + 3 + payload_length
        if @buffer.length > start+packet_length
          #puts "Have full packet of #{packet_length} bytes, payload #{payload_length}"
          packet = @buffer[start+6...(start+packet_length)]
          # display_buffer packet
          got_packet packet
          @buffer = (@buffer[start+packet_length+1..-1] or "".force_encoding("ASCII-8BIT"))
          have_packet = true
        end
      end
    end while have_packet
  end
  
  def display_buffer(str)
    bytes = str.unpack("C*")
    puts ("%-40s" % bytes.map{|b|"%02x " % [b]}.join) + bytes.map{|b| b.chr}.join.scan(/[[:print:]]/).join
  end

  def on_network_button(id)
  end
  
  def on_cd_button(id)
  end
  
  def on_display_brightness(brightness)
    @status.display_brightness = brightness
  end
  
  def on_cd_function(function)
    @status.cd_function = function
  end

  def on_network_function(function)
    @status.network_function = function
  end
  
  def on_volume(vol)
    @status.audio.volume = vol
  end
  
  def on_mute(status)
    @status.audio.mute = status
  end
  
  def on_sleep_timer(time)
    @status.sleep = Time.now + time.to_i*60
  end
  
  def on_source(source)
    @status.source = source
  end
  
  def on_amp_on
    @status.power = :on
  end
  
  def on_amp_off
    @status.power = :off
  end

  def on_radio
  end
  
  def got_packet(data)
    buttons = {
      0x33 => :stop,
      0x34 => :play,      
      0x44 => :next,
      0x45 => :previous,
      0x46 => :forward,
      0x47 => :rewind,
      0x48 => :up,
      0x49 => :down,
      0x4a => :left,
      0x4b => :right,
      0x4c => :enter,
      0x4d => :search,
      0x4e => :mode,
      0x32 => :play_pause,
      0x4f => :num1,
      0x50 => :num2,
      0x51 => :num3,
      0x52 => :num4,
      0x53 => :num5,
      0x54 => :num6,
      0x55 => :num7,
      0x56 => :num8,
      0x57 => :num9,
      0x58 => :num0,
      0x59 => :num10,
      0x5a => :clear,
      0x5e => :info,
      0x5b => :program,
      0x5c => :random,
      0x5d => :repeat,
    }
    
    network_buttons = Hash[buttons.map { |k,v| [k.chr+"\x26\x00", v] }] 
    cd_buttons      = Hash[buttons.map { |k,v| [k.chr+"\x25\x00", v] }]

    if network_buttons.include? data
      on_network_button network_buttons[data]
    elsif cd_buttons.include? data
      on_cd_button cd_buttons[data]
    else 
      case data
      when "\x43\x00\x00" # Dimmer - bright
        on_display_brightness :bright
      when "\x43\x00\x01" # Dimmer - dim
        on_display_brightness :dim
      when "\x43\x00\x02" # Dimmer - dark
        on_display_brightness :dark
      when "\x43\x00\x03" # Dimmer - off
        on_display_brightness :off
        
      when "\x02\x01\x00" # Amp off, (rendundant, also provided by ASCII protocol)

      ## Inputs (rendundant, also provided by ASCII protocol)
      when "\x33\x00\x9b", "\x01\x03\x00" # Network
      when "\x33\x14\x00", "\x01\x04\x00" # CD
      when "\x33\x15\x00", "\x01\x05\x00" # Analog1
      when "\x33\x16\x00", "\x01\x06\x00" # Analog2
      when "\x33\x17\x00", "\x01\x07\x00" # Digital2
      when "\x33\x08\x00", "\x01\x08\x00" # Tuner
    
      ## Functions
      when "\x5f\x00\x00" # CD
        on_cd_function :cd
      when "\x60\x00\x00" # CD - ipod
        on_cd_function :cd_usb
      when "\x61\x00\x00"
        on_network_function :internet_radio
      when "\x63\x00\x00"
        on_network_function :online_music
      when "\x62\x00\x00" 
        on_network_function :music_server
      when "\x64\x00\x00"
        on_network_function :network_usb
        
        
      when "\x84\x00\x00" # Open system settings
        nil

      when /\x80\x00(.{2,25})\x0d$/n # ASCII protocol
        command = $1
        case command
        when /MV(\d\d)/
          on_volume $1.to_i
        when "MUON"
          on_mute true
        when "MUOFF"
          on_mute false
        when "SLPOFF"
          on_sleep_timer nil
        when /SLP(\d\d\d)/
          on_sleep_timer $1.to_i
        when /PSBAS (\d\d)/
          @status.audio.bass = $1.to_i - 10
          puts "Bass set to #{$1.to_i - 10} dB"
        when /PSTRE (\d\d)/
          @status.audio.treble = $1.to_i - 10
          puts "Treble set to #{$1.to_i - 10} dB"
        when /PSBAL (\d\d)/
          @status.audio.balance = $1.to_i - 6
          puts "Balance set to #{$1} (where 6 is center)"
        when /PSSDB (ON|OFF)/
          @status.audio.sdb = $1.downcase.to_sym
          puts "SDB tone #{$1}"
        when /PSSDI (ON|OFF)/
          @status.audio.sdirect = $1.downcase.to_sym
          puts "s.direct #{$1}"
          
        when "SINETWORK"
          on_source :network
        when "SICD"
          on_source :cd
        when "SITUNER"
          on_source :tuner
        when "SIAUX1"
          on_source :aux1
        when "SIAUX2"
          on_source :aux2 
        when "SIDIGITAL_IN"
          on_source :digital
          
        when "TMANFM" # Tuner tuned
          @status.radio.band = :fm
          on_radio :band
        when "TMANMANUAL"
          @status.radio.stereo = :mono
          on_radio :stereo
        when "TMANAUTO"
          @status.radio.stereo = :auto
          on_radio :stereo
        when /TPAN(\d\d)/ # Tuner tuned
          @status.radio.current_preset = $1.to_i
          on_radio :tune_preset
        when "TPANOFF" 
          @status.radio.current_preset = nil
          on_radio :tune_preset
        when /TFAN(\d{6})/ # Tuner tuned
          @status.radio.current_frequency = frequency
          on_radio :tune_frequency
        when /SSTPN(\d\d)(.{9})(\d{8})/ 
          index = $1.to_i
          name  = $2
          freq  = $3.to_i/100.0
          if freq != 0.0
            preset           = @status.radio.presets[index]
            preset.name      = name
            preset.frequency = freq
          else
            @status.radio.presets.delete[index]
          end
          on_radio :store_preset
        when "PWSTANDBY"
          on_amp_off
        when "PWON"
          on_amp_on
        when /TS(ONCE|EVERY) 2(\d\d)(\d\d)-2(\d\d)(\d\d) (..)(\d\d)/
          type  = $1
          h_on  = $2.to_i
          m_on  = $3.to_i
          h_off = $4.to_i
          m_off = $5.to_i
          function = {"NW" => "Internet Radio", "NU" => "iPad/USB (Network)", "CD" => "CD", "CU" => "iPad/USB (CD)", "TU" => "Tuner", "A1" => "Analog 1", "A2" => "Analog 2", "DI" => "Digital"}[$6]
          preset = $7.to_i
          
          alarm = if type == 'ONCE' then @status.alarm.once else @status.alarm.every end
          
          alarm.on  = [h_on, m_on]
          alarm.off = [h_off, m_off]
          alarm.function = function
          alarm.preset = preset
          
    
          puts "Set #{$1} alarm from #{h_on}:#{m_on} to #{h_off}:#{m_off} using #{function} at preset #{preset}"
        when /TO(ON|OFF) (ON|OFF)/
          @status.alarm.once.status = $1.downcase.to_sym
          @status.alarm.every.status = $1.downcase.to_sym
          puts "Alarm ONCE: #{$1}, EVERY: #{$2}"
        else
          puts "Unknown string command #{command}"
        end
      else 
        p data
        bytes = data.unpack("C*")
        puts "Unknown packet " +  ("%-40s" % bytes.map{|b|"%02x " % [b]}.join) + bytes.map{|b| b.chr}.join.scan(/[[:print:]]/).join
      end
    end
  end
end

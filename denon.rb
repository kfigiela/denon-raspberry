# encoding: ASCII-8BIT
require 'serialport'
require 'ruby-mpd'
require 'ostruct'
require_relative 'mpd'

class Denon < EventMachine::Connection
  
  attr_reader :status

  class Status < Struct.new(:source, :cd_function, :network_function, :display_brightness, :radio, :audio, :alarm, :power, :sleep)
    def initialize
      super
      self.radio = Radio.new
      self.radio.band = :fm
      self.radio.presets = Hash.new
      self.audio = Audio.new
      self.alarm = Alarms.new
      self.alarm.once  = Alarm.new
      self.alarm.every = Alarm.new
    end
  end
  Station = Struct.new(:name, :frequency)
  Alarm = Struct.new(:on, :off, :status, :function, :preset)
  Radio = Struct.new(:presets, :band, :stereo, :current_preset, :current_frequency)
  Audio = Struct.new(:volume, :mute, :bass, :treble, :balance, :sdb, :sdirect)
  Alarms = Struct.new(:once, :every)
  
  DAB_FREQS = {"5A" => 174.928, "5B" => 176.640, "5C" => 178.352, "5D" => 180.064, "6A" => 181.936, "6B" => 183.648, "6C" => 185.360, "6D" => 187.072, "7A" => 188.928, "7B" => 190.640, "7C" => 192.352, "7D" => 194.064, "8A" => 195.936, "8B" => 197.648, "8C" => 199.360, "8D" => 201.072, "9A" => 202.928, "9B" => 204.640, "9C" => 206.352, "9D" => 208.064, "10A" => 209.936, "10B" => 211.648, "10C" => 213.360, "10D" => 215.072, "10N" => 210.096, "11A" => 216.928, "11B" => 218.640, "11C" => 220.352, "11D" => 222.064, "11N" => 217.088, "12A" => 223.936, "12B" => 225.648, "12C" => 227.360, "12D" => 229.072, "12N" => 224.096, "13A" => 230.784, "13B" => 232.496, "13C" => 234.208, "13D" => 235.776, "13E" => 237.488, "13F" => 239.200}
  
  DENON_VOLUME_MAX = 60
  
  
  def initialize
    @status = Status.new
  end
  
  def post_init
    prepare_regexps
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
        if @buffer.length >= start+packet_length
          # puts "Have full packet of #{packet_length} bytes, payload #{payload_length}"
          packet = @buffer[start...(start+packet_length)]
          
          bytes = packet.unpack("C*")
          checksum = bytes[0..-1].reduce(&:+) & 0xff
          # puts "Junk: #{start}"
          # display_buffer @buffer[0...start]
          # puts "Packet checksum #{checksum.to_s(16)}
          display_buffer @buffer[start...(start+packet_length)]

          got_packet packet[6..-1] if bytes[4] == 0 
#          if checksum == bytes[-1]
 #           got_packet packet[6...-1] # packet without header and checksum
  #        else
   #         puts "Invalid checksum #{bytes[-1]} expected #{checksum}"
    #        display_buffer packet
     #     end
          @buffer = (@buffer[start+packet_length..-1] or "".force_encoding("ASCII-8BIT"))
          have_packet = true
        end
      end
    end while have_packet
  end
  
  def display_buffer(str)
    bytes = str.unpack("C*")
    if bytes[4] == 0 
      print "  "
    else
      print "\n> "
    end
    puts ("%-40s" % bytes.map{|b|"%02x " % [b]}.join) + bytes.map{|b| b.chr}.join.scan(/[[:print:]]/).join.inspect
  end
  
  def send_command(command)
    packet = []
    len = command.length - 2
    packet += [0xff, 0x55, len, 0x01,0x00]
    packet += command
    checksum = packet.reduce(&:+) & 0xff
    packet << checksum
    data = packet.pack("C*")
    puts "Sending"
    display_buffer data
    @io.ioctl(0x5427) # turn break on
    Kernel.sleep(0.01)
    @io.ioctl(0x5428) # turn break off
    # @io.break(@time) # this one uses TCSBRK ioctl
    send_data(data)
    Kernel.sleep(0.1)
  end

  def on_status(what)
  end
  
  def on_network_button(id)
  end
  
  def on_cd_button(id)
  end

  def on_analog1_button(id)
  end
  
  def on_analog2_button(id)
  end

  def on_digital_button(id)
  end
  
  def on_display_brightness(brightness)
    @status.display_brightness = brightness
    on_status :display_brightness
  end
  
  def on_cd_function(function)
    @status.cd_function = function
    on_status :cd_function
  end

  def on_network_function(function)
    @status.network_function = function
    on_status :network_function
  end
  
  def on_volume(vol)
    @status.audio.volume = vol
    on_status :volume
  end
  
  def on_mute(status)
    @status.audio.mute = status
    on_status :mute
  end
  
  def on_sleep_timer(time)
    @status.sleep = if time
      Time.now + time.to_i*60
    else
      nil
    end
    on_status :sleep_timer
  end
  
  def on_source(source)
    @status.source = source
    on_status :source
  end
  
  def on_amp_on
    @status.power = :on
    on_status :power
  end
  
  def on_amp_off
    @status.power = :off
    on_status :power
  end

  def on_radio(what)
    on_status :radio
  end
  
  def prepare_regexps
    buttons = {
      0x33 => :stop,
      0x34 => :play,      
      0x37 => :play,      
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
  
    @analog1_buttons = Hash[buttons.map { |k,v| [k.chr+"\x23\x00", v] }]
    @analog2_buttons = Hash[buttons.map { |k,v| [k.chr+"\x24\x00", v] }]
    @network_buttons = Hash[buttons.map { |k,v| [k.chr+"\x26\x00", v] }] 
    @cd_buttons      = Hash[buttons.map { |k,v| [k.chr+"\x25\x00", v] }]
    @digital_buttons = Hash[buttons.map { |k,v| [k.chr+"\x27\x00", v] }]
  end
  
  def got_packet(data)
    if @network_buttons.include? data
      on_network_button @network_buttons[data]
    elsif @cd_buttons.include? data
      on_cd_button @cd_buttons[data]
    elsif @analog1_buttons.include? data
      on_analog1_button @analog1_buttons[data]
    elsif @analog2_buttons.include? data
      on_analog2_button @analog2_buttons[data]
    elsif @digital_buttons.include? data
      on_digital_button @digital_buttons[data]
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
        # on_source :network
      when "\x33\x14\x00", "\x01\x04\x00" # CD
        # on_source :cd
      when "\x33\x08\x00", "\x01\x08\x00" # Tuner
        # on_source :tuner
      when "\x33\x15\x00", "\x01\x05\x00" # Analog1
        # on_source :aux1
      when "\x33\x16\x00", "\x01\x06\x00" # Analog2
        # on_source :aux2
      when "\x33\x17\x00", "\x01\x07\x00" # Digital
        # on_source :digital
    
      ## Functions
      when "\x5f\x00\x00", "\x37\x00\x00" # CD
        on_cd_function :cd
      when "\x60\x00\x00", "\x38\x00\x00" # CD - ipod
        on_cd_function :cd_usb
      when "\x61\x00\x00", "\x35\x00\x00"
        on_network_function :internet_radio
      when "\x63\x00\x00"
        on_network_function :online_music
      when "\x62\x00\x00" 
        on_network_function :music_server
      when "\x64\x00\x00", "\x36\x00\x00"
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
          
        when "TMANFM"
          @status.radio.band = :fm
          on_radio :band
        when "TMDA"
          @status.radio.band = :dab
          on_radio :band
          
        when "TMANMANUAL"
          @status.radio.stereo = :mono
          on_radio :stereo
        when "TMANAUTO"
          @status.radio.stereo = :auto
          on_radio :stereo
        when /TPAN(\d\d)/
          @status.radio.current_preset = $1.to_i
          on_radio :tune_preset
        when "TPANOFF" 
          @status.radio.current_preset = nil
          on_radio :tune_preset
        when /TFAN(\d{6})/
          @status.radio.current_frequency = $1.to_i/100.0
          on_radio :tune_frequency
        when /TFDA(\d{1,2}[A-Z])/
          @status.radio.current_frequency = DAB_FREQS[$1]
          on_radio :tune_frequency
        when /SSTPN(\d\d)(.{9})(\d{8})/ 
          index = $1.to_i
          name  = $2
          freq  = $3.to_i/100.0
          if freq != 0.0
            @status.radio.presets[index] ||= Station.new
            preset           = @status.radio.presets[index]
            preset.name      = name
            preset.frequency = freq
          else
            @status.radio.presets.delete(index)
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
  
  def source 
    @status.source
  end  
  
  def source=(source)
    case source
    when :aux1
        send_command([0x25,0x00,0x00])
    when :aux2
        send_command([0x26,0x00,0x00])
    when :digital
        send_command([0x27,0x00,0x00])
    when :network
        send_command([0x24,0x00,0x00])
    when :internet_radio
      on_network_function :internet_radio
      send_command([0x24,0x00,0x00])
    when :online_music
      on_network_function :online_music
      send_command([0x24,0x00,0x00])
    when :music_server
      on_network_function :music_server
      send_command([0x24,0x00,0x00])
    when :network_usb
      on_network_function :network_usb
      send_command([0x24,0x00,0x00])
    when :cd
        send_command([0x23,0x00,0x00])
    when :tuner
        send_command([0x20,0x00,0x00])
    when :tuner_dab
        send_command([0x20,0x00,0x00])
    else
      puts "Try to set invalid source #{source}"
    end
  end
    
  def volume
    @status.audio.volume or 5 # 5 is not silence, but not too loud
  end
  
  def volume=(vol)
    if vol.is_a? Symbol
      case vol
      when :up
        self.volume_up
      when :down
        self.volume_down
      end
    else
      raise ArgumentError, "Negative volume" if vol < 0

      if vol <= DENON_VOLUME_MAX
        send_command([0x40,0x00,vol])
      else
        send_command([0x40,0x00,DENON_VOLUME_MAX])
      end
    end
  end
  
  def volume_up
    unless @status.audio.volume.nil?
      self.volume = self.volume + 1
    else
      self.volume = 1
    end
  end
 
  def volume_down
    unless @status.audio.volume.nil?
      self.volume = self.volume - 1
    else
      self.volume = 0
    end
  end
  
  def tuner_preset_forward
    send_command([0x68,0x30,0x00])
  end
 
  def tuner_preset_backward
    send_command([0x68,0x30,0x01])
  end

  def mute
    @status.audio.mute
  end
  
  def mute=(new_mute)
    if new_mute
      send_command([0x41,0x00,0x01])
    else
      send_command([0x41,0x00,0x00])
    end
  end
  
  def mute!
    self.mute = !self.mute
  end
  

  def display_brightness
    @status.display_brightness
  end

  def display_brightness=(brightness)
    case brightness
    when :bright
      send_command([0x43,0x00,0x00])
    when :dim
      send_command([0x43,0x00,0x01])
    when :dark
      send_command([0x43,0x00,0x02])
    when :off
      send_command([0x43,0x00,0x03])
    end
    on_display_brightness brightness
  end
  
  def display_brightness!
    self.display_brightness = case @status.display_brightness
    when :bright
      :dim
    when :dim
      :dark
    when :dark
      :off
    when :off
      :bright
    else
      :bright
    end
  end
  
  def power
    @status.power == :on
  end
  
  def power=(val)
    if val
      send_command([0x01, 0x02, 0x00])
    else
      send_command([0x02, 0x01, 0x00])
    end
  end

  def power!
    self.power = !self.power
  end
  
  def sleep=(time)
    send_command([0x7b,0x00,time&0xff])
  end
  
  def send_number(number)
    keys = [0x58, 0x4f, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57]
    send_command([0x59, 0x00, 0x00]) if number > 9
    EM.next_tick do
      send_command([keys[number % 10],00,00]) 
    end
  end
end

def send_command(command)
  packet = []
  len = command.length - 2
  packet += [0xff, 0x55, len, 0x01,0x00]
  packet += command
  checksum = packet.reduce(&:+) & 0xff
  packet << checksum
  data = packet.pack("C*")
  @sp.ioctl(0x5427)
  Kernel.sleep(@time)
  @sp.ioctl(0x5428)
  # @sp.break(@time)
  @sp.write(data)
  @sp.flush_output
  display_buffer data
end
def display_buffer(str)
  bytes = str.unpack("C*")
  puts ("%-40s" % bytes.map{|b|"%02x " % [b]}.join) + bytes.map{|b| b.chr}.join.scan(/[[:print:]]/).join.inspect
end
@time=0.02
require 'serialport'
@sp =  SerialPort.open("/dev/ttyUSB0", 115200, 8, 1, SerialPort::NONE)

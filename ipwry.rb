#!/usr/bin/env ruby
# coding: utf-8
# jianglibo(jianglibo@gmail.com)
# website: http://www.g0574.com
# =KK= 修改
#

require 'iconv'
require 'do_as_rb19.rb'

(File.exist?'QQWry.Dat' )? fQQwry='QQWry.Dat' : fQQwry='/media/other/LINUX学习/www/study/QQWry.Dat'

class IpLocationSeeker
  def initialize(data_filename = fQQwry)
    data_filename = File.join(File.dirname(__FILE__),fQQwry) if FileTest::exist?(fQQwry)
    #@datafile = File.open(fQQwry,"r:utf-8")
    @datafile = File.open(fQQwry,"rb")
    @first_index_pos,@last_index_pos  = @datafile.read(8).unpack('L2')
    @index_num = (@last_index_pos - @first_index_pos)/7 + 1
  end

  def renamed_eump(number=100)
    last_index_pos = number * 7
    last_index_pos = @last_index_pos if last_index_pos > @last_index_pos
    current_num = 0
    error_num = 0
    @first_index_pos.step(last_index_pos,7) do |a_pos|
        begin
          current_num +=1
          @datafile.seek(a_pos)
          ip_int = @datafile.read(4).unpack('L1')
          @ip_record_pos = three_bytes_long_int(@datafile.read(3).unpack('C3'))
          puts ip_int.to_s + "***"+get_country_string + '***' + get_area_string
        rescue
          puts $!
          puts "error at " + current_num.to_s
          error_num += 1
        end
      end
    return "total num:%s,error_num:%s  " %[current_num,error_num]
  end

  def seek(ip_str) #查询IP
    @ip_str = ip_str
    @ip_record_pos = get_ip_record_pos
    begin #错误处理
      tmp = get_country_string + get_area_string
      puts tmp
      return tmp
    rescue Interrupt
      return ip_str
    rescue Exception => detail
      p $!
      p $@
      return ip_str
    #~ retry
    end
  end

  def half_find(ip_want_int,index_lowest,index_highest) #二分
     if index_highest - index_lowest == 1
          index_lowest
     else
        index_middle = (index_lowest + index_highest)/2
        file_offset = @first_index_pos + index_middle * 7
        @datafile.seek(file_offset)
        ip_middle_int = @datafile.read(4).unpack("L")[0]
        if ip_want_int == ip_middle_int
           index_lowest
        elsif ip_want_int > ip_middle_int
           index_lowest = index_middle
           half_find(ip_want_int,index_lowest,index_highest)
        else
           index_highest = index_middle
           half_find(ip_want_int,index_lowest,index_highest)
        end
     end
  end

  def three_bytes_long_int(three_byte)
    (three_byte[2] << 16) + (three_byte[1]<<8) + three_byte[0]
  end

  def get_ip_record_pos()
    ip_record_pos_pos = @first_index_pos + half_find(my_inet_aton(@ip_str),0,@index_num-1)*7 + 4
    @datafile.seek(ip_record_pos_pos)
    three_byte = @datafile.read(3).unpack('C3')
    three_bytes_long_int(three_byte)
  end

  #读取直到字符串结尾
  def read_zero_end_string(file_pos)
    @datafile.seek(file_pos)
    str = ""
    count = 0
    while c = @datafile.getc
      break if count>100
      break if c.to_s.ord < 0x32 rescue p c
      str << c
      count += 1
    end
    if count > 70
      puts 'ipwry count:' + count.to_s
      str = "2 unknown string."
      @get_country_string_error = true
    end
    @after_read_country_pos = @datafile.pos
    return Iconv.conv("UTF-8//IGNORE","GB18030//IGNORE",str) rescue ''
  end

  #private

  def get_country_string()
    @get_country_string_error = false
    begin
      @datafile.seek(@ip_record_pos + 4)
      @mode_flag,  = @datafile.read(1).unpack("C1")
      if @mode_flag == 1 #the next three bytes are another pointer
        @ip_record_level_two_pos = three_bytes_long_int(@datafile.read(3).unpack('C3'))
        @datafile.seek(@ip_record_level_two_pos)
        @level_two_mode_flag, = @datafile.read(1).unpack("C1")
        if @level_two_mode_flag == 2
          @ip_record_level_three_pos = three_bytes_long_int(@datafile.read(3).unpack('C3'))
          @level_three_mode_flag, = @datafile.read(1).unpack("C1")
          read_zero_end_string(@ip_record_level_three_pos)
        else
          @level_two_mode_flag = 0
          read_zero_end_string(@ip_record_level_two_pos)
        end
      elsif @mode_flag == 2
        @ip_record_level_two_pos = three_bytes_long_int(@datafile.read(3).unpack('C3'))
        read_zero_end_string(@ip_record_level_two_pos)
      else
        @mode_flag = 0
        read_zero_end_string(@ip_record_pos + 4)
      end
    rescue
      p $!
      p $@
      @get_country_string_error = true
      "3 unknown country!"
    end
  end

  def get_area_string()
    @get_area_string_error = false
    if @get_country_string_error
      @get_area_string_error = true
      return "4 unknown area!"
    end
    begin
      if @mode_flag == 0
        read_zero_end_string(@after_read_country_pos)
      elsif @mode_flag == 1
        if @level_two_mode_flag == 2
          #p @level_three_mode_flag
          if @level_three_mode_flag == 1 || @level_three_mode_flag == 2
            @datafile.seek(@ip_record_level_two_pos + 5)
            @ip_record_area_string_pos = three_bytes_long_int(@datafile.read(3).unpack('C3'))
            read_zero_end_string @ip_record_area_string_pos
          else
            read_zero_end_string(@ip_record_level_two_pos + 4)
          end
        else
          read_zero_end_string(@after_read_country_pos)
        end
      else
        read_zero_end_string(@ip_record_pos+8)
      end
    rescue
      p $!
      @get_area_string_error = true
      "1 unknown area!"
    end
  end

  def my_inet_aton(ip_str)
    ip_str.split(".").collect{|x|x.to_i}.inject(0){|ip_int,ip_field|
      ip_int = (ip_int << 8) + ip_field
    }
  end
end

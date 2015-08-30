#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# sevkme@gmail.com

require 'logger'
require 'fileutils'
include FileUtils

unless defined? $log_dir
  $log_dir = nil
end
$logDir = $log_dir # $logDir如果是nil就赋值一下
$logDir ||= File.join(Dir.pwd , 'log')
mkdir_p $logDir

unless defined? Myname
  Myname = File.basename($0, ".rb")
end
puts File.join($logDir,Myname + '.log')
$zip_log ||= false

def zip_log
   return unless $zip_log
   s_log = "#$logDir/#{Myname}.log"
   if File.exist? s_log
      d_now = "#$logDir/#{Myname}.log.7z"
      s_now = "#$logDir/#{Myname}1.log"
      FileUtils.cp(s_log,s_now)
      system("start /min cmd /c 7z a #{d_now} #{s_now}")
   end

   yd = (Time.now-86400).strftime("%Y%m%d")
   s = "#$logDir/#{Myname}.log.#{yd}"
   if File.exist? s
      d1 = "#$logDir\\#{yd}_#{Myname}.log.7z"
      unless File.exist? d1
         system("start /min cmd /c 7z a #{d1} #{s}")
      else
         FileUtils.rm s
      end
      p ' 7z cab log ok '
   end
end

def log_init
  $log_init.exit if defined? $log_init
  $log_init = Thread.new{
     Thread.current[:name] = 'Log file to cab '
     loop do
        sleep 60
        zip_log rescue(p $!.message,$@)
        sleep 1740
     end
  }
end
log_init

# log => 写入 $!.message
# log "aa" => 写入 "aa" 到log文件
# log '' => 不写入log文件, 只打印
def log(s=nil ,*a)
  log_init
  
  if a.size != 0
    p ' log(a,b) not support '
  end
    
  if $!
    puts "#{$!.message} \n#{$@.select{|x|
      x !~/\/lib\/ruby\//i 
    }[0,8].join("\n").gsub(/\.rb/i,'.cc') }"
  end
  return if s == ''

  if ! s
    if $!
      s = "#{$!.message} \n#{$@.select{|x|
        x !~/\/lib\/ruby\//i 
      }[0,8].join("\n").gsub(/\.rb/i,'.cc') }"
    end
  end
  return if ! s

  if s.class != String
    s= "#{s.inspect}"
  end

  p s[0,510]

   if $!
      f= Myname + '-err.log'
      le = Logger.new(File.join($logDir,f) ,shift_age=24,shift_size = 1000000)
      le.datetime_format = "%m-%d %H:%M:%S"
      le.debug s
      le.close
   else
      f= Myname + '.log'
      #p f
      if $zip_log
         l = Logger.new(File.join($logDir,f), 'daily' )
      else
         l = Logger.new(File.join($logDir,f),shift_age =28, shift_size = 1000000)
      end
      l.datetime_format = "%m-%d %H:%M:%S"
      l.info s
      l.close
   end
end

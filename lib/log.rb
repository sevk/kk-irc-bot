#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# sevkme@gmail.com

require 'logger'
Dir.mkdir 'log' if not Dir.exist? 'log'

#记录到日志文件，参数是要记录的内容，不给参数则记录当前错误描述，未出错就是空。
def log(s=nil)
  if $! and s
    s << $!.message
  end
	if not s
		if $!
			s = "#{$!.message} #{$@.join("\n")}"
		else
			return
		end
	end
  if s==""
    puts "#{$!.message} #{$@[-5..-1].join(' ')}"
    return
  end

	p s
	#daily/weekly/monthly.
  logger = Logger.new("./log/log_#{ENV['USER']}.log",shift_age=30,10240000)
  logger.level = Logger::DEBUG
  logger.debug{s}
end
log('log start.')


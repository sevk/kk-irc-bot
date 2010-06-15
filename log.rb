#! /usr/bin/env ruby
# sevkme@gmail.com

require 'logger'
Dir.mkdir 'log' if not File.directory? 'log'

#记录到日志文件，参数是要记录的内容，不给参数则记录当前错误描述，未出错就是空。
def log(s = "#{$!.message} #{$@[0]} ")
  logger = Logger.new('./log/log.log', 'monthly') #daily/weekly/monthly.
  logger.level = Logger::DEBUG
  p s
  logger.debug(''){s}
  nil
end


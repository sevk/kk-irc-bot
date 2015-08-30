#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#需要ruby较新的版本, 比如ruby1.8.7以上 或 ruby1.9.2 以上, 建议使用linux系统.

=begin
   * Description: 当时学ruby，写着玩的机器人
   * Author: Sevkme@gmail.com
   * 源代码: http://github.com/sevk/kk-irc-bot/ 或 http://git.oschina.net/sevkme/kk-irc-bot/ , http://code.google.com/p/kk-irc-bot/ 

=end

#BEGIN {$VERBOSE = true}

$not_savelog = nil
require 'socket'
Socket.do_not_reverse_lookup = true
require 'rubygems'
$: << '.'
$: << 'lib'
require 'plugin.rb'
load 'libirc.rb'

def restart #Hard Reset
  send 'quit lag' rescue nil
  sleep $msg_delay
  p "exec #{$0} #$argv0"
  exec "#{$0} #$argv0"
end

if not defined? $u
  p 'ARGV :' ,ARGV
  ARGV[0] = 'default.conf' if not ARGV[0] || ARGV[0] == $0
  if __FILE__ == $0
    $argv0 = ARGV[0]
  else
    $argv0 = 'default.conf'
  end
  load ARGV[0]
  $bot_on1 = $bot_on
  $bot_on = false
  $re_ignore_nick ||= /^$/
  p $server

  irc = IRC.new($server,$port,$nick[0],$channel,$charset)
  $irc=irc
  irc.timer_start

  irc.input_start if $client
  Thread.current[:name]= 'main'
  check_proxy_status
  loop do
    begin
      exit if @exit
      @irc_stat = 0 
      irc.connect
      irc.main_loop
      p ' main_loop end'
    rescue
      break if irc.exited?
      log ''
      sleep 2
    end
    break if irc.exited?
    #restart rescue log
    p $need_reconn
    p Time.now
    sleep 2+rand($msg_delay*3)
  end
end

# vim:set shiftwidth=2 tabstop=2 expandtab:

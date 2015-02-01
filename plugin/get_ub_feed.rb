#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'timeout'
require 'rss'
require 'time'

#取ubuntu.com.cn的 新帖.
def get_feed (url= 'http://forum.ubuntu.org.cn/feed.php' ,not_re = true)
  begin
   feed = Timeout.timeout(11) {
      RSS::Parser.parse url
    }
  rescue Timeout::Error
    return if rand < 0.98
    return ' 取新帖 timeout '
  end

  $ub=nil
  feed.items.each { |i|
    ti = i.title.content.to_s
    #p ti
    next if ti =~ /Re:/i and not_re
    #p ti
    link = i.link.href.gsub(/&p=\d+#p\d+$/im,'')
    des = i.content.to_s[0, 2*($fun||500)]
    date = i.updated.content
    @last = date
    #p date
    $ub = "新 #{ti} #{link} #{des}"
    break
  }
  #p ' all re ,no new' if $ub.empty?
  return if not $ub
  return if $ub.empty?

  $no_new_feed ||=0
  $data ||= Hash.new
  $data['old_feed'] ||= Time.now - 800
  $data['old_title'] ||= ''

  if $data['old_feed'] >= @last or $data['old_title'] == $ub
    $ub = " 逛了一下论坛,暂时无新贴."
    #p ' is old feed'
    $no_new_feed+=1
    if $no_new_feed > 49 #大约49分钟
      $no_new_feed=0
      return "暂无新帖 讲个笑话吧: #{joke}"
    end
    return if rand < 0.999
    return $ub
  else
    $no_new_feed=0
    $data['old_feed'] = @last
  end

  $ub.gsub!(/\s+/m,' ')
  n = $ub.gsub(/<.+?>/m,' ').unescapeHTML.gsub(/<.+?>/m,' ')
    .unescapeHTML
  #puts n
  n
rescue Exception
  log
end

$last_say_new ||= Time.at 0
#自动说新帖
def say_new to
  return if Time.now - $last_say_new < 58
  $last_say_new=Time.now
  return unless $need_say_feed > 0
  return unless Time.now.hour.between? 8,22
   @say_new=Thread.new(to) { |to1|
      Thread.current[:name]= 'say_new'
      $irc.msg(to1, get_feed ,0)
   }
end

$get_ub_feed.kill rescue nil
$get_ub_feed=Thread.new do
  $get_ub_feed.priority = -4
  Thread.current[:name]= ' get_ub_feed '
  n=80 #n分钟没人说话
  sleep n
  loop {
    sleep 50
    force = nil
    force = true if Time.now - $last_say_new > 300
    #n久没人说话再取
    if force or Time.now - $channel_lastsay > n
      say_new $channel rescue log ''
    end
  }
end


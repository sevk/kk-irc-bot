#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'timeout'
require 'rss'
require 'time'
require 'color.rb'

#取ubuntu.com.cn的 新帖.
def get_feed (url= 'http://forum.ubuntu.org.cn/feed.php' ,not_re = true)
  begin
   feed = Timeout.timeout(12) {
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
    $ub = "新 #{ti.iblue } #{link.icolor(link.sum) } #{des}"
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
    if $no_new_feed > 79 #大约49分钟
      $no_new_feed=0
      return "暂无新帖 讲个笑话吧: #{joke}"
    end
    return if rand < 0.999
    return $ub
  else
    $no_new_feed=0
    $data['old_feed'] = @last
    $data['old_title'] = $ub
  end

  $ub.gsub!(/\s+/m,' ')
  n = $ub.gsub(/<.+?>/m,' ').unescapeHTML.gsub(/<.+?>/m,' ')
    .unescapeHTML
  n.gsub!(/统计信息:.*由/,' zz: ')
  #puts n
  n
rescue Exception
  log ''
end

$need_say_feed ||= -1
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
rescue Exception
  log ''
end

$get_ub_feed.kill rescue nil
$get_ub_feed=Thread.new do
  Thread.current[:name]= ' get_ub_feed '
  loop {
    sleep 40
    sleep rand(20)
    say_new $channel
  }
end


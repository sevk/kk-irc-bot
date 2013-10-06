#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

#取ubuntu.com.cn的 feed.
def get_feed (url= 'http://forum.ubuntu.org.cn/feed.php',not_re = true)
  begin
   feed = Timeout.timeout(25) {
      RSS::Parser.parse(url)
    }
  rescue Timeout::Error
    return if rand < 0.6
    p ' get feed timeout '
    return ' 取新帖 timeout '
  end
  #p 'feed geted'

  $ub=nil
  p feed if feed.class != RSS::Atom::Feed
  #p feed.items.size
  feed.items.each { |i|
    ti = i.title.content.to_s
    next if ti =~ /Re:/i and not_re
    link = i.link.href.gsub(/&p=\d+#p\d+$/i,'')
    des = i.content.to_s[0,2*$fun||500]
    #date = i.updated.content
    @rsslink = link
    #p ti
    #puts 'feed updated: ' + i.updated.content
    $ub = "新 #{ti} #{link} #{des}"
    break
  }
  #p ' all re ,no new' if $ub.empty?
  return if $ub.empty?

  $no_new_feed ||=0
  $data ||= Hash.new
  if $data['old_feed_link'] == @rsslink and $ub
    $ub = " 逛了一下论坛,暂时无新贴."
    #p ' is old feed'
    $no_new_feed+=1
    if $no_new_feed > 40
      $no_new_feed=0
      return "暂时无新帖 讲个笑话吧 #{joke}"
    end
    return
  else
    $no_new_feed=0
    $data['old_feed_link'] = @rsslink
  end

  $ub.gsub!(/\s+/,' ')
  n = $ub.gsub(/<.+?>/,' ').unescapeHTML.gsub(/<.+?>/,' ')
    .unescapeHTML
end

$last_say_new ||= Time.at 0
#自动说新帖
def say_new to
  return if Time.now - $last_say_new < 90
  $last_say_new=Time.now
  return unless $need_say_feed > 0
  return unless Time.now.hour.between? 8,22
   @say_new=Thread.new(to) { |to|
      Thread.current[:name]= 'say_new'
      tmp = get_feed
      $irc.msg(to,tmp,0)
   }
end

$get_ub_feed.kill rescue nil
$get_ub_feed=Thread.new do
  n=220
  sleep n
  loop {
    sleep 59
    force = nil
    force = true if Time.now - $last_say_new > 310
    #n久没人说话再取
    if force or Time.now - $channel_lastsay > n
      say_new $channel rescue log ''
    end
  }
end
$get_ub_feed.priority = -2


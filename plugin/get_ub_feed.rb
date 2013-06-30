#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

#取ubuntu.com.cn的 feed.
def get_feed (url= 'http://forum.ubuntu.org.cn/feed.php',not_re = true)
  p 'in get_feed'
  begin
   feed = Timeout.timeout(14) {
      RSS::Parser.parse(url)
    }
  rescue Timeout::Error
    return if rand < 0.7
    return ' 取新帖 timeout '
  end

  $ub=nil
  p feed if feed.class != RSS::Atom::Feed
  #return if feed.empty?
  feed.items.each { |i|
    link = i.link.href.gsub(/&p=\d+#p\d+$/i,'')
    des = i.content.to_s[0,$fun||500]
    #date = i.updated.content
    $date = link
    ti = i.title.content.to_s

    next if ti =~ /Re:/i and not_re
    puts i.updated.content
    $ub = "新 #{ti} #{link} #{des}"
    #p $ub
    break
  }

  if $old_feed_date == $date and $ub
    #link = feed.items[0].link.href
    #ti = feed.items[0].title.content
    ##date = feed.items[0].updated.content
    #$date = link
    #des = feed.items[0].content
    #$ub = "新⇨ #{ti} #{link} #{des}"
    $ub = ".. 逛了一下论坛,暂时无新贴.只有Re: ."
    $ub = '' if rand > 0.05
  else
    $old_feed_date = $date
  end

  return if $ub.empty?
  $ub.gsub!(/\s+/,' ')
  n = $ub.gsub(/<.+?>/,' ').unescapeHTML.gsub(/<.+?>/,' ')
    .unescapeHTML
  if n.size < 5
    p $ub
    p n
    return
  end
  return n
end
$last_say_new ||= Time.at 0
#自动说新帖
def say_new to
  return if Time.now - $last_say_new < 120
  $last_say_new=Time.now
  return unless $need_say_feed > 0
  return unless Time.now.hour.between? 7,22
   @say_new=Thread.new(to) { |to|
      Thread.current[:name]= 'say_new'
      tmp = get_feed
      $irc.msg(to,tmp,0)
   }
end


$get_ub_feed.kill rescue nil
$get_ub_feed=Thread.new do
  n=40
  sleep n
  loop {
    sleep n/2
    #n久没人说话再取
    if Time.now - $channel_lastsay > n
      say_new $channel rescue log ''
    end
  }
end


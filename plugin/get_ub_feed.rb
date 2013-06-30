#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

$get_ub_feed.kill rescue nil
$get_ub_feed=Thread.new do
  sleep 90
  loop {
    sleep 20
    #n久没人说话再取
    if Time.now - $channel_lastsay > 40
      $irc.say_new($channel) rescue log ''
    end
  }
end


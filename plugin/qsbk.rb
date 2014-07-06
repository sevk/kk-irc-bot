#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'htmlentities'
require 'mechanize'

module Allowa
  def qsbk
    qsbka
  end
  @qsbk_index = 0
  def qsbka id=nil
    if @urls
      url = @urls[@qsbk_index ]
    else
      url = "http://www.qiushibaike.com/hot"
    end
    a = Mechanize.new
    s = a.get url
    @urls = s.links_with(:href=> /^\/[\d\w]+$/).map{|x| "http://www.qiushibaike.com#{x.href}"  }.uniq!
    @urls.delete_if{|x| x =~ /\/(add|my|logo|month)/ }
    e = s.at('.content')
    r= e.text
    id ||= e.parent.attributes['id'].value
    p id
    if @last_id == id
      @qsbk_index = (@qsbk_index + 1) % @urls.size
      sleep 1
      return qsbka
    end
    @last_id = id
    img = s.search("//*[@id=\"#{id}\"]/div[3]/a/img")[0].attributes['src'].value rescue nil
    r << img if img
    r
  end
  alias 糗事百科 qsbk
end

include Allowa
if __FILE__ == $0
  puts qsbk
end


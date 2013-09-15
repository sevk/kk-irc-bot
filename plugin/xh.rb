#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# 取笑话

$: << '..'
$: << '../lib/'
$:.uniq!
require 'mechanize'
require 'htmlentities'
require 'utf.rb'
def joke(n=nil)
  n ||= rand(17786)
  url="http://xiaohua.zol.com.cn/detail1/#{n}.html"
  a=Mechanize.new
  s = a.get_file url
  begin
    s=s.match(/<div class="lC">(.*?)<div class="lastVote">/im)[1]
  rescue
    log ''
    return "empty err. try again. " + joke
  end
  s.gsub!(/<.+?>/,' ')
  s=s.code_a2b(guess(s) ,'utf-8').unescapeHTML
  $fun ||= 800
  if s.bytesize > $fun
    sleep 0.1
    s=joke
  end
  s.gsub!(/\s+|\t/,' ')
  s
end
alias 给大爷讲个笑话 joke

if __FILE__ == $0
  puts joke
end


#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# 取笑话

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
  s=s.code_a2b(guess(s) ,'utf-8')
  "id:#{n} #{s.unescapeHTML}"
end
alias 给大爷讲个笑话 joke


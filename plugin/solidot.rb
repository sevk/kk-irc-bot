#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'htmlentities'
require 'mechanize'

module Allowa
  def get_solida
    get_solidot rescue log('')
  end
  def get_solidot
    url = "http://www.solidot.org/QA"
    a = Mechanize.new
    s = a.get url
    f = s.at('.famous').text
    f
  end
end
include Allowa

if __FILE__ == $0
  puts get_solida
end


#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# Sevkme@gmail.com

def t s 
  Thread.new{ system s }
end

t 'git push github'
t 'git push gitcafe'
t 'git push gitcd'
t 'git push gitshell'
t 'git push osc'

sleep 0.3 while Thread.list.size != 1

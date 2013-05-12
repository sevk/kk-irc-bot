#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# Sevkme@gmail.com

Thread.new{
  puts `git push github`
}
Thread.new{
  puts `git push gitcd`
}
Thread.new{
  puts `git push gitshell`
}
Thread.new{
  puts `git push gitcafe`
}
sleep 1 while Thread.list.size != 1

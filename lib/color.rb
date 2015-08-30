#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

#为终端字符串添加颜色

require 'colored'
require 'ansi/code'

$black="\e[30m"; $red="\e[31m"; $green="\e[32m";
$yellow="\e[33m";
$blue="\e[34m"; $pink="\e[35m"; $cyan="\e[36m";
$white="\e[37m";

$normal="\e[0m"; $bold="\e[1m"; $underline="\e[4m"
$reverse="\e[7m";
$delete="\e[9m";

$b_black="\e[40m"; $b_red="\e[41m"; $b_green="\e[42m";
$b_yellow="\e[43m";
$b_blue="\e[44m"; $b_pink="\e[45m"; $b_cyan="\e[46m";
$b_white="\e[47m";

#windows下面可以安装 msysGit-fullinstall-preview.exe 包含 MINGW32 :)

#颜色代码
a=[1,2,4,7]; b= * 31..37 ; c = [41,42,* 44..46] 
d=[91,92, *94..96] ; e=[100,102,*104..106]
Colors ||= [a,b,c,d,e].inject '+'
class String
  def clear_color
    ANSI.uncolor self
  end
  def green
    "\e[32m#{self}#$normal"
  end
  def yellow
    "\e[33m#{self}#$normal"
  end
  def blue
    "\e[34m#{self}#$normal"
  end
  def pink
    "\e[35m#{self}#$normal"
  end
  def cyan
    "\e[36m#{self}#$normal"
  end
  def c_rand(n=rand(99))
    #13 黄底
    #20 黄字
    #103 黄底白字
    c=Colors[n%Colors.size]
    "\e[#{c}m #{self}#$normal"
  end

  def blueb
    "\e[44m#{self}#$normal"
  end
  def redb
    "\e[41m#{self}#$normal"
  end

  #irc color
  def icolor(n=rand(99))
    "\x03#{n%16} #{self}\x030"
  end
  def iblack
    icolor(1)
  end
  def iNblue
    icolor(2)
  end
  def iblue
    "\x033 #{self}\x030"
  end
  def ired
    icolor 4
  end
  def iBrown
    icolor 5
  end
  def iPurple
    icolor 6
  end
  def iOlive
    icolor 7
  end
  def iYellow
    icolor 8
  end
  def iLgreen
    icolor 9
  end
  def iTeal
    icolor 10
  end
  def iAquaL
    icolor 11
  end
  def iRoyBlue
    icolor 12
  end
  def iHpink
    icolor 13
  end
  def iDgray
    icolor 14
  end
  def iLgray
    icolor 15
  end
  def iWhite
    icolor 16
  end
end


#为终端字符串添加颜色

require 'colored'
if Gem.win_platform?
   #require 'Win32/Console/ANSI' 
end

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
class String
  def black
    "\e[30m#{self}#$normal"
  end
  def red
    "\e[31m#{self}#$normal"
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
		"\e[#{31+n%7}m#{self}#$normal"
	end

  def blueb
    "\e[44m#{self}#$normal"
  end
  def redb
    "\e[41m#{self}#$normal"
  end
	def greenb
    "\e[42m#{self}#$normal"
	end

  #irc color
  def icolor(n=rand(99))
    #n=rand(99)
    #n = 0 if n==1
    #"\e[#{31+n%7}m#{self}#$normal"
    #"\x03#{n%7}#{self}\x03#{n}"
    self
  end
  def iblue
    "\x033#{self}\x030"
  end

end

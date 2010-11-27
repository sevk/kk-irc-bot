#为终端字符串添加颜色
#
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

class String
  def black
    "\e[30m#{self}#$normal"
  end
  def blue
    "\e[34m#{self}#$normal"
  end
  def cyan
    "\e[36m#{self}#$normal"
  end
  def green
    "\e[32m#{self}#$normal"
  end
  def pink
    "\e[35m#{self}#$normal"
  end
  def red
    "\e[31m#{self}#$normal"
  end
  def yellow
    "\e[33m#{self}#$normal"
  end

  def blueb
    "\e[44m#{self}#$normal"
  end
  def redb
    "\e[41m#{self}#$normal"
  end
    
end

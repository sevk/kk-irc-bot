#!/usr/bin/ruby -w
=begin
   * Name: irc.rb
   * Description:     
   * Author: Sevkme@gmail.com
   * Date:  
   * License: GPLV3 
   * http://irc.ubuntu.org.cn
   * 源代码: http://github.com/sevk/kk-irc-bot/ 或 http://code.google.com/p/kk-irc-bot/ 
=end

include Math
load 'irc_user.rb'
require "ipwry.rb"
require 'date'
load 'Dic.rb'
#require "readline"

require 'find'
#载入plugin
Find.find(File.expand_path(File.dirname(__FILE__))+'/plugin/') do |e|
  if File.extname(e) == '.rb'
    p ' load:'+ e
    load e
  end
end

Help = '我是ikk-irc-bot 用法:`g 内容 [|@>] [某人] , `s=grep新手资料 g=google d=define b=baidu tt=google翻译 `t=百度词典 a=查某人地址 `gf `host=域名IP查询 `IP查询 >=ruby简单脚本 `x=乱聊 `deb=软件包查询 `i=源代码'
MATCH_title_RE = /<title>(.*)<\/title>/
Delay_do_after = 4
Ver='v0.12' unless defined?(Ver)

Re_cn=/[\x7f-\xff]/
Http_re= /http:\/\/\S+[^\s*]/
$old_feed_size = -1

Minsaytime= 12
#puts "最小说话时间=#{Minsaytime}"
Minsaytime_forUxxxxx=8000
$last_say_U = Time.now
$min_next_say = Time.now
$Lsay=Time.now; $Lping=Time.now
$lag=1
loadDic

#$SAFE=1 if  `hostname`.index('NoteBook')
puts "$SAFE= #$SAFE"
NoFloodAndPlay=/\#sevk|\-ot|arch|fire/i 
NoTitle=/fire|oftc/i
BotList=/bot|fity|badgirl|crazyghost|u_b|iphone/i
UrlList=/ubuntu|inux|unix|window|nbeta|ruby|py|java|lu|qq|dot|dn/i 

class IRC
  def initialize(server, port, nick, channel, charset, pass, user)
    $otherbot_said = nil
    @Motded = false
    @Named = false
    $name_whois = nil
    @server = server
    $need_say_feed=false if @server =~ /oftc/i 

    @port = port
    @nick = nick
    @pass = pass
    @str_user= user
    @channel = channel
    charset='UTF-8' if charset == 'utf-8' ||  charset == 'utf8'
    @charset = charset
    $notitle = true if @server =~ NoTitle
    puts "$notitle = #{$notitle}" #不读取url title
    $u = ALL_USER.new

    timer1 = Thread.new do
      loop do
        sleep(2000 + rand(1500))
        if $need_say_feed
          begin
            tmp = get_feed 
          rescue Exception => detail
          end
          msg(@channel,tmp,4) if (9..24) === Time.now.hour 
          #msg('#Sevk',tmp,0) if Time.now.hour.between?(9,24)
        end
        #p 'say get_feed'
      end
    end
  end
  def kick(s)
    send "kick #@channel #{s}"
  end
  def ping(s)
    $Lping = Time.now
    $Lsay = Time.now
    send "PING #{s}"
  end
  def notice(who,sSay,delay=4)
    $otherbot_said=false
    do_after_sec(who,sSay,20,delay)
  end
  def msg(who,sSay='',delay=4)
    return if sSay == ''
    $otherbot_said=false
    do_after_sec(who,sSay,0,delay)
  end
  def msg_check_say_time(who,s)
    send "PRIVMSG #{who.untaint} :#{s}"
  end
  def say(s)
    send "PRIVMSG #{@channel} :#{s}"
  end
  def send(s)
    s.gsub!(/\s+/,' ')
    s=s[0,450]#只发送450个byte
    if @charset == 'UTF-8'
      #local是UTF-8时,一个汉字是3个byte.
      s=s[0,s.size - s.gsub(/[^\x7f-\xff]+/,'').size % 3]
    else
      s=Iconv.conv("#{@charset}//IGNORE","UTF-8//IGNORE",s)
      s=s[0,s.size - s.gsub(/[^\x7f-\xff]+/,'').size % 2]
    end
    puts "---> #{s}"
    $Lsay = Time.now
    @irc.send("#{s}\n", 0)
  end
  def connect()
    @irc = TCPSocket.open(@server, @port)
    send "NICK #{@nick}"
    send @str_user
  end
  def evaluate(s)
  #eval
    p s;
    return '操作不安全' if s=~/pass|serv/i
    result = nil
      begin
        p 'begin eval eval='+ s
        Timeout.timeout(6) {
          result = safe(4) {eval(s).to_s[0,460]}
        }
      rescue Exception => detail
        puts detail.message()
      end
    return result
  end

  def sayDic(dic,from,to,s='') #取字典,可以用>之类的重定向,向某人提供字典数据
  #发送字典结果
    tellSender = false
    pub =false
    
    if s=~/(.*?)\s?([#\@|>])\s?(.*?)$/i #消息重定向
      words=$1;b6=$2;b7=$3
      if b7
        b7 =$u.completename(b7) if b7 !~ /^U\d{5}$/
      end
    else
      words=s
    end
    puts "words=#{words},flag=#{b6},to=#{to},s=#{words}"
    case b6
    when '|'#公共
      sto='PRIVMSG'
    when '>' #小窗
      sto='PRIVMSG'
      #sto='PRIVMSG' ;to=b7;tellSender=true
    when /[#\@]/ #notic
      sto='PRIVMSG'
      #sto='notice' ;to=b7;tellSender=true
    else
      sto='PRIVMSG'
      to=from if !pub
    end

    case dic
    when 5
      pub =true
    end

    Thread.new do
      c = words;re=''
      case dic
      when 1 : re = getGoogle(c ,0)
      when 2 : re = getBaidu(c )
      when 3 : re = googleFinance(c )
      when 4 : re = getGoogle_tran(c );c=''
      when 5#拼音
        re = "#{getPY(c)}";c='';b7= from +'说 '
      when 6 : re= $str1.match(/(\n.*?)#{Regexp::escape c}(.*\n?)/i)[0]
      when 10 : re = hostA(c,rand(10))
      when 20 : re = $u.igetlastsay(c).to_s
      when 21 : re = $u.ims(c).to_s
      when 22
        ip = $u.getip(c)
        puts 'ip=' + ip.to_s
        if ip =~ /^gateway\/|mibbit\.com/i#自动whois mibbit 用户
          $name_whois = c
          $from_whois = from
          $to_whois = to
          $s_whois = s
          send('whois ' + c)
          
          return
        end

        re = "#{$u.getname(c)} #{hostA(ip)}"
      when 30
        return if c !~/^[\w\-\.]+$/#只能是字母,数字,-. "#{$`}<<#{$&}>>#{$'}"
        `apt-cache show #{c}`.gsub(/\n/,'~').match(/Version:(.*?)~.{4,16}:(.*?)Description[:\-](.*?)~.{4,16}:/i)
        re="#$3".gsub(/~/,'')
        # gsub(/xxx/){$&.upcase; gsub(/xxx/,'\2,\1')}
        #~ re='未找到软件包' if re.to_s.size<3
      when 40
        c == "" ? re= getTQFromName(from) : re= getTQ(c)
      when 99 : re = Help ;c=''
      when 101 : re = getBaidu_tran(c);c=''
      end
      Thread.exit if re.size < 4

      if sto =~ /notice/i 
        notice(to, "#{b7}\0039 #{c}\017\0037 #{re}",0)
      else
        msg(to, "#{b7}\0039 #{c}\017\0037 #{re}",0)
      end
      msg(from,"#{b7}\0039 #{c}\017\0037 #{re}",0) if tellSender

    end #Thread
  end

  def check_code(s)
  #utf8等乱码检测
    return 2 if !$need_Check_code #not match
    if s =~ /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(.+?)\s:(.*)$/i#需要检测
      from=b1=$1;name=b2=$2;ip=b3=$3;to=b4=$4;b5=$5.to_s.untaint
      return 11 if b3== '59.36.101.19'#不处理U用户
      str= b5.gsub(/[^\x7f-\xff]+/,'')#只取中文字符
      return 3 if str.size < 6 #太短
      tmp=str
      while str.size < 23
        str +=  tmp
      end
      tmp=Codes(str) #encode检测
      if tmp != @charset && tmp !~ /IBM855|windows-1252/ && tmp != '' 
        p b5
        begin
          if tmp !~/gb(.*)/i
            b5=''
          else
            b5=Iconv.conv("#{@charset}//IGNORE","#{tmp}//IGNORE",b5).strip
          end
        rescue Exception => detail
          puts detail.message()
        end
        #send "Notice #{b1} :请用 #{@charset}编码,不要用 #{tmp}"
        send "PRIVMSG #{((b4==@nick)? b1: b4)} :#{b1}:said #{b5} in #{tmp}, but we say #{@charset} here."
        return nil
      else
        return 4 #编码正常
      end
    else
      return 5#不是Priv_msg
    end
  end

  def check_msg(s)
    #处理频道消息,私人消息,JOINS QUITS PARTS KICK NICK NOTICE
    s.gsub!(/(deb\s|deb-src\s)http(.*)/i,'')#过滤 /deb(?:-src)?/
    s.gsub!(/http(.*)\/download/,'')
    s= Iconv.conv("UTF-8//IGNORE","#{@charset}//IGNORE",s) if @charset != 'UTF-8'
    case s.strip
    when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(#{Regexp::escape @nick})\s:(.+)$/i #PRIVMSG me
      from=a1=$1;name=a2=$2;ip=a3=$3;to=a4=$4;sSay=a5=$5
      print(from,' ',s,"\n") #if $SAFE == 1
      return if from =~ /freenode-connect/i
      return if a3== '59.36.101.19'#不处理U用户
      return if a3=~ /^gateway\//i

      if $u.saidAndCheckFloodMe(a1,a2,a3)
#        $u.floodmereset(a1)
        send "PRIVMSG #{a1} :...玩Bot请去 #Sevk 频道" if rand(10) > 6
        return nil
      end
      tmp = check_dic(a5,a1,a1)
      if tmp.class == Fixnum
        if a5.size < 6 and rand(10) > 6
          send "PRIVMSG #{from} :不懂什么是#{sSay},请输入`help" if rand(10) > 7
        end
        $otherbot_said=false
        if rand(10) > 6
          do_after_sec(from, "不好意思,我不喜欢私聊",0,10)
        else
          do_after_sec(to,"#{from}, #{$me.rand(sSay)}",10,15) if $me
        end
      end
    when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(.+?)\s:(.+)$/i #PRIVMSG channel
      from=a1=$1;name=a2=$2;ip=a3=$3;to=a4=$4;sSay=a5=$5
      return if a1==@nick

      #有BOT说话
      $otherbot_said=true if name =~ BotList
      #~ $u.setip(from,name,ip)

      #以我的名字开头
      if sSay =~ /^#{Regexp::escape @nick}\s?,?:?(.*)$/i 
        s=$1.to_s
        if s =~ /help|帮助|有什么功能|叫什么|几岁|\?\?/i
          sSay = '`help '
        end

        case a3
        when '59.36.101.19' #不处理U用户
          msg(to ,"你用的是网页版本的IRC,建议你换个IRC客户端.",12) if rand(10) > 6
          return
        when /^gateway\//i
          msg(to ,"你用的是代理或mibbit版本的IRC,建议你换个IRC客户端.",12) if rand(10) > 6
          return
        end 
      else
        return if a3== '59.36.101.19'#不处理U用户
        return if a3=~ /^gateway\//i
      end

      tmp = check_dic(sSay,from,to)
      case tmp
      when 1
        #非字典消息
        if sSay =~ /^#{Regexp::escape @nick}\s?,?:?(.*)$/i
          sSay=$1.to_s
          if sSay.size < 6
            send "PRIVMSG #{from} :不懂什么是#{sSay},请输入`help" if rand(10)>7 
          end
          #puts '消息以我名字开头'
          #$otherbot_said=false
          #do_after_sec(to,"#{from}, #{$me.rand(sSay)}",10,15) if $me
          #`sh sound.sh`
        else
          #$u.said(from,name,ip)
          #$u.setLastSay(from,sSay)
          if $u.saidAndCheckFlood(a1,a2,a3,sSay)
            $u.floodreset(a1)
            return if to =~ NoFloodAndPlay # 不检测flood和玩bot
            msg(a4,"#{a1}, ...超过4行或图片请贴到 http://paste.ubuntu.org.cn",4)
            return nil
          end
        end
      when 2
        #是title
      else
        #是字典消息
        if $u.saidAndCheckFloodMe(a1,a2,a3)
          $otherbot_said=true
          #$u.floodmereset(a1)
          return if to =~ NoFloodAndPlay # 不检测flood和玩bot
          send "NOTICE #{from} :玩Bot请去 #Sevk 频道" if rand(10) > 5
          send "PRIVMSG #{a1} :玩Bot请去 #Sevk 频道" if rand(10) > 7
          msg to ,"#{from},玩Bot请去 #Sevk 或 #{to}-ot 频道",0 if rand(10) > 6
          return nil
        end
      end
    when /^:(.+?)!(.+?)@(.+?)\s(JOIN)\s:(.*)$/i #join
      #:U55555!i=3cbe89d2@gateway/web/ajax/mibbit.com/x-d50dbdfe784bbbd2 JOIN :#sevk
      #@gateway/tor/x-2f4b59a0d5adf051
      from=$1.to_s;name=$2;ip=$3;to=$5
      #print(from,' JOIN ',to, "\n")
      case from
        when /#{Regexp::escape @nick}/i
          return
        when /badgirl/i
          $need_Check_code=false
        when /crazyghost|u_b/i
          $need_say_feed=false
          $notitle=true
          #msg(to,"每小时取一个论坛最新帖功能自动关闭.",0)
      end
      
      if $u.add(from,name,ip) == 19
        return if rand(10) > 2
        $otherbot_said=false
        do_after_sec(to,from + ",欢迎网页用户来IRC学习,有问题直接问.",11,25)
      end

      new_Readline_complete($u.all_nick)
    when /^:(.+?)!(.+?)@(.+?)\s(PART|QUIT)\s(.*)$/i #quit
      #:lihoo1!n=lihoo@125.120.11.127 QUIT :Remote closed the connection
      from=$1;name=$2;ip=$3;room=$5.to_s
      #puts $4.to_s + ' ' + from + ' '+ room 
      case from
        when /badgirl/i
          $need_Check_code=true
        when /crazyghost|u_b/i
          $need_say_feed=true
          $notitle=false
          #msg(to,"每小时取一个论坛最新帖功能自动打开.",0)
      end

      if ip=='59.36.101.19'#U用户
        $otherbot_said=true
      end
      $u.del(from,ip)
      new_Readline_complete($u.all_nick)
    when /^(.+?)Notice(.+)$/i  #Notice
      #:ChanServ!ChanServ@services. NOTICE ikk-bot :[#sevk] "此频道目前主要用于BOT测试."
      puts s
    when /^:(.+?)!(.+?)@(.+?)\sNICK\s:(.+)$/i #Nick_chg
      #:ikk-test!n=Sevk@125.124.130.81 NICK :ikk-new
      a1=$1;a2=$2;a3=$3;a4=$4;a5=$5
      puts 'NICK ' + s.to_s
      nick=$1;name=$2;ip=$3;new=$4
      if $u.chg_nick(nick,new) ==1
        $u.add(nick,name,ip)
      end
    when /^:(.+?)!(.+?)@(.+?)\sKICK\s(.+?)\s(.+?)\s:(.+?)$/i #KICK 
      #:ikk-irssi!n=k@unaffiliated/sevkme KICK #sevk Guest19279 :ikk-irssi\r\n"
      from=$1;chan=$4;tag=$5;reason=$6
      puts 'Kick ' + tag.to_s + ' ' +  reason.to_s 
      if tag =~ /u_b/ 
        $need_say_feed=true 
        $notitle=false
      end
    else
      return 1 # not match
    end
  end

  def check_dic(s,from,to)
  #检测消息是不是敏感或字典消息
    case s.strip
    when /^(\?|>)\s?(.+)$/i #eval
      puts "[4 EVAL #{$2} from #{from}]"
      tmp=evaluate($2[0,200])
      p tmp
      msg to,"#{from}, #{tmp}",0 if tmp
    when /^`h(ost)?\s(.*?)$/i # host
      puts 'host ' + s
      sayDic(10,from,to,$2)
    when  /^(.*)(http:\/\/\S+[^\s*])/i #url_title查询
      url = $2.match(/http:\/\/\S+[^\s*]/i)[0]
      thread3 = Thread.new do
        #priority = 1
        Thread.exit if $notitle
        Thread.exit if from =~ BotList
        Thread.exit if url !~ UrlList
        Thread.exit if url =~ /past/i 
        #puts 'thread.new in matched url ' + url
        $ti =  nil
        Timeout.timeout(5) {
          $ti = gettitle(url)
        }
        if $ti[0] == 61 #'='
          Timeout.timeout(5) {
            $ti = gettitle($ti[1,$ti.size])
          }
        end

        if $ti 
          #puts $ti + ' is title'
          if s.index($ti[$ti.size/2,6])#已经发了就不说了
            #puts '已经发了标题' + $ti[3,9]
          else
            $ti.gsub!(/Ubuntu中文论坛.{1,6}查看主题/i,'')
            $ti.gsub!(/\sUbuntu中文/i,'')
            msg(to,"⇪ 网址标题: #{$ti}",0) 
          end
        end
        $ti=nil
        Thread.exit
      end
      return 2
    when /^`?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/i #IP查询
      puts 'Ip ' + s
      msg to,"#{IpLocationSeeker.new.seek($1)} #{$1}",0
    when /^`?tr?\s(.+?)\s?(\d?)$/i  #baidu_tran
      word = $1.to_s
      en = $2 == "0"
      #sayDic(101,from,to,$1)
      Thread.new do
        re = getBaidu_tran(word,en)
        msg to,"#{re}",0 if re.size > 3
        Thread.exit
      end
    when /^`deb\s(.*)$/i  #aptitude show
      sayDic(30,from,to,$1)
    when /^`?s\s(.*)$/i  #TXT search
      #~ puts 's ' + s
      sayDic(6,from,to,$1)
    when /^[`']help\s?(.*?)$/i #help
      puts 'help ' + s
      sayDic(99,from,to,$1)
    when /^(what is|什么是)(.+)[\?？]?$/i #什么是
      w=$2.to_s
      return if w =~/这|那|的|哪/
      sayDic(1,from,to,"define: #{w} |")
      puts '什么是 ' + s
    when /^(.*?)[\s:,](.+)是什么[\?？]?$/i #是什么
      if $1 
        return
      else
        w = $2.to_s
        return if w =~/这|那|的|哪/
        sayDic(1,from,to,"define: #{w} |")
      end
    when /^`ims\s?(.*?)$/i  #IMS查询
      puts 'IMS ' + s
      sayDic(21,from,to,$1)
    when /^`fd\s?(.*?)$/i  #flood查询
      puts 'flood ' + s
      sayDic(20,from,to,$1)
    when /^`g?f\s?(.*?)$/i  # GoogleFinance
      puts 'GoogleFinance ' + s
      sayDic(3,from,to,$1)
    when /^`?tt\s(.*?)$/i  # getGoogle_tran
      puts 'getGoogle_tran ' + s
      sayDic(4,from,to,$1)
    when /^`?g\s(.*?)$/i  # Google
      puts 'google ' + s
      sayDic(1,from,to,$1)
    when /^`x\s(.*?)$/i  # plugin
      $otherbot_said=false
      do_after_sec(to,"#{from}, #{$me.rand($1.to_s)}",10,20) if $me
    when /^`?tq\s(.*?)$/i  # 天气
      puts 'TQ ' + s
      sayDic(40,from,to,$1)
    when /^`?d(ef(ine)?)?\s(.*?)$/i#define:
      sayDic(1,from,to,'define: ' + $3)
    when /^`?b\s(.*?)$/i  # 百度
      puts '百度 ' + s
      sayDic(2,from,to,$1)
    when /^`?a\s(.*?)$/i #查某人ip
      sayDic(22,from,to,$1)
    when /^(大家...(...)?|hi( all)?.?|hello)$/i
      $otherbot_said=false
      do_after_sec(to,from + ',您 ◆◆◆ 好.',10,11) if rand(10) > 7
    when /^((有人(...)?(吗|不|么|否)((...)?|\??))|test|测试)$/i #有人吗?
      $otherbot_said=false
      do_after_sec(to,from + ',你好。',10,11)
    when /^(wo|ni|ta|shi|ru|zen|hai|neng|shen|wei|guo|qing|mei|xia|zhuang|geng)\s(.+)$/i  #拼音
      return nil if s =~ /[^,.?\s\w]/ #只能是拼音或标点
      return nil if s.size < 10
      sayDic(5,from,to,s)
    when /^`i\s?(.*?)$/i #svn
      s1= '源代码: http://code.google.com/p/kk-irc-bot/ 或 http://github.com/sevk/kk-irc-bot/'
      msg to,"#{s1}"
    when /^`rst(.+)$/i #restart      
      tmp=$1
      #return if from !~ /^(ikk-|WiiW|lkk-|Sevk)$/
      tmp = "%03s" % tmp
      $notitle = tmp[0] == 48
      $need_say_feed = tmp[1] != 48
      $need_Check_code = tmp[2] != 48
      load 'Dic.rb'
      load 'irc_user.rb'
      loadDic
      msg(to,"restarted,取标题=#{not $notitle} ,读取ubfeed=#$need_say_feed ,检测编码=#$need_Check_code",1)
    else
      print(from,' ',s,"\n") #if $SAFE == 1
      return 1#not match dic_event
    end
  end

  def check_irc_event(s)#服务器消息
    case s.strip
    when /^PING :(.+)$/i  # ping
      @irc.send "PONG :#{$1}\n", 0
    when /LAG1982067890/i #LAG
      $lag=Time.new - $Lping
      puts "LAG = #{$lag} 秒" if $lag > 3
    when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s.+\s:[\001]PING (.+)[\001]$/i #ctcp ping
      puts "[2 CTCP PING from #{$1}!#{$2}@#{$3} ]"
      send "NOTICE #{$1} :\001PING #{$4}\001"
    when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s.+\s:[\001]VERSION[\001]$/i #ctcp
      puts "[3 CTCP VERSION from #{$1}!#{$2}@#{$3} ]"
      send "NOTICE #{$1} :\001VERSION Sevkme@gmail.com Ruby-irc #{Ver} birthday=2008.7.20\001"
    when /^:(.+?)\s(\d+)\s(.*?)\s:(.*)/i#motd , names list
      pos=$2.to_i;tmp=$4.to_s 
      puts pos.to_s + ' ' +  tmp + ' <-- motd'
      if !@Motded
        if pos == 376
          @Motded = true
          do_after_sec(@channel,nil,5, 1.6)
        end
      end
      if !@Named
        if pos == 353
          $need_Check_code=false if tmp =~ /badgirl/i
          $need_say_feed=false if tmp =~ /crazyghost|u_b/i
          $notice=true if tmp =~ /u_b/i
        end
      end
      if pos == 901
        @Named = true 
        puts "是否检测乱码= #{$need_Check_code}"
        puts 'feed功能= ' + $need_say_feed.to_s
        puts 'notitle= ' + $notice.to_s 
      end

      #自动 whois 返回
      if $name_whois && pos == 311
        ip= tmp
        $u.chg_ip($name_whois,ip)
        $name_whois = nil
        sayDic(22,$from_whois,$to_whois,$s_whois)
      end 
      #:zelazny.freenode.net 353 ikk-bot = #sevk :ikk-bot @Sevkme @[ub]
    when /^:(.+?)\sTOPIC\s(.+)\s:(.+)$/i#topic
      from=$1;chan=$2;topic=$3
      puts s
      #:Wii-2!n=Sevk@60.163.53.134 TOPIC #sevk :"此频道目前主要用于闲聊和调戏BOT."

      #QUIT name :niven.freenode.net irc.freenode.net
      #Netsplit hubbard.freenode.net <-> irc.freenode.net
    when /^:(.+?)\sMODE\s(.+)\+(.+)$/i#mode
      #:services. MODE ikk-bot :+e
      #:ChanServ!ChanServ@services. MODE #sevk +o ikk-bot
      puts s
    when /^ERROR\s:(.*?):\s(.*?)$/i # Closeing
      puts s
    else
      return 1#not match 
    end #end case
  end #end irc_event

  def handle_server_input(s)
  #检测消息是不是服务器消息,乱码检测或字典消息
    return if check_irc_event(s).class != Fixnum #服务器消息
    return if check_code(s).class != Fixnum #乱码
    return if check_msg(s).class != Fixnum #字典消息
  end

  def do_after_sec(to,sSay,flg,second)#延时发送
    puts "need_do #{flg} #{second}"
    Thread.new do
      flag=flg
      if Time.now < $min_next_say
        puts '还没到下次说话的时间'
        Thread.exit
      else
        $min_next_say=Time.now + Minsaytime + second
      end
      if second < Delay_do_after
        sleep second
      else
        sleep rand(second-Delay_do_after) + Delay_do_after
      end
      Thread.exit if $otherbot_said

      case flag
      when 0
        send "PRIVMSG #{to} :#{sSay} #{chr_hour}"
      when 5
        send "JOIN #{@channel}"
        send "PRIVMSG nickserv :id #{@pass}";sleep 0.1
        send "JOIN #sevk"
        $pass=@pass=rand(100)
      when 7
        send "privmsg #{@channel}  :\001ACTION 我不是机器人#{0.chr} "
      when 10#打招呼回复
        tmp = ((DateTime.parse('2009-01-26 00:00:00+08:00')-DateTime.now)*24*60*60).round
        if tmp < 0 #不用显示倒计时
          return if sSay =~ /\s$/
          send "PRIVMSG #{to} :#{sSay} \0039 #{chr_hour} \017"
          return
        end
        case tmp
        when 0..60
          tmp="还有#{tmp}秒"
        when 61..3600
          tmp="还有#{tmp/60}分钟"
        when 3601..86400
          tmp="还有#{tmp/60/60}小时"
        else
          tmp="还有#{tmp/60/60/24}天"
        end
        send "privmsg #{to} :#{sSay} #{chr_hour} #{Time.now.strftime('[%H:%M]')} \0039新年快乐，离除夕0点#{tmp}\017"
      when 11
        if Time.now < $last_say_U + Minsaytime_forUxxxxx + rand(4600) + 900
          #~ puts '还没到下次新手打招呼时间'
          Thread.exit
        end
        $last_say_U = Time.now
        sSay += '快速配置指南 http://wiki.ubuntu.org.cn/Qref :)' if rand(10) > 5

        send "privmsg #{to} :#{sSay} #{chr_hour}  #{Time.now.strftime('[%H:%M]')}"
      when 20#notice
        send "NOTICE #{to} :#{sSay}"
      end
    end #Thread
  end

  def new_Readline_complete(w)
    #Readline.completion_proc = proc {|word| w.grep(/^#{Regexp.quote word}/) }
  end

  def main_loop()
    while true
      #ready = select([@irc, readline("> ", true)], nil, nil, nil)
      #ready = select([@tcp, readline("> ", true)], nil, nil, nil)
      ready = select([@irc, $stdin], nil, nil, nil)
      next if !ready
      for s in ready[0]
        if s == @irc 
          return if @irc.eof
          handle_server_input(@irc.gets)
        elsif s == $stdin
          return if $stdin.eof

          s = $stdin.gets
          case s
          when /^\/msg\s(.+?)\s(.+)$/
            who = $1;s=$2
            send "privmsg #{who} :#{s.strip}"
          when /^:q\s?(.*?)$/i
            tmp = $1 || 'optimize'
            send 'quit ' + tmp
          when /^[\/:]/
            send s.gsub(/^[\/:]/,"")
          when /^`/
            check_dic(s+'|','i',@channel)
          when /^\s/
            send "privmsg nickserv :#{s.strip}"
          else
            say s# + ' ' + chr_hour
          end
        end
      end
    end
  end
end

load 'default.conf'
load ARGV[0] if ARGV[0]

irc = IRC.new($server,$port,$nick,$channel,$charset,$pass,$user)
irc.connect()
irc.main_loop()

# vim:set shiftwidth=2 tabstop=2 expandtab textwidth=79:


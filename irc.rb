#!/usr/bin/env ruby
# coding: utf-8
# 版本需ruby较新的版本, 比如ruby1.8.6以上 或 ruby1.9.1 以上

=begin
   * Name: irc.rb
   * Description:
   * Author: Sevkme@gmail.com
   * Date:  
   * License: GPLV3 
   * 源代码: http://github.com/sevk/kk-irc-bot/ 或 http://code.google.com/p/kk-irc-bot/ 
=end

load 'Dic.rb'
include Math
require "monitor"
require "readline"
require 'yaml'
load "ipwry.rb"
load 'irc_user.rb'
load 'plugin.rb'

#irc类
class IRC
  def initialize(server, port, nick, channel, charset, pass, user)
    $_hour = $_min = $_sec = 0
    @tmp = ''
    @exit = false
    $otherbot_said = nil
    @Motded = false
    @Named = false
    $name_whois = nil

    @server = server
    @port = port
    @nick = nick
    @pass = pass
    @str_user= user
    @channel = channel
    charset='UTF-8' if charset =~ /utf\-?8/i
    @charset = charset
    puts "$saytitle = #{$saytitle}" #不读取url title
    loadDic
    mystart
  end
  
  #kick踢出
  def kick(s)
    send "kick #@channel #{s} 大段内容请贴到http://pastebin.ca 或 http://paste.ubuntu.org.cn"
  end

  #/mode #ubuntu-cn +b *!*@1.1.1.0
  def autoban(chan,s,time=50)
    send "mode #{chan} +b #{s}"
    Thread.new do
      tmp = s
      sleep time
      puts 'unban: ' + tmp
      send "mode #{chan} -b #{tmp}"
    end
  end

  def unban(chan,s)
    send "mode #{chan} -b #{s}"
  end

  def ping(s)
    $Lping = Time.now
    $Lsay = Time.now
    send "PING #{s}"
  end
  #发送notice消息
  def notice(who,sSay,delay=4)
    $otherbot_said=false
    do_after_sec(who,sSay,15,delay)
  end

  #发送msg消息,随机 delay 秒数.
  def msg(who,sSay='',delay=4)
    return if sSay.size == 0
    $otherbot_said=false
    do_after_sec(who,sSay,0,delay)
  end
  def say(s)
    send "PRIVMSG #{@channel} :#{s}"
    isaid()
  end

  #发送tcp数据,如果长度大于460 就自动截断.
  def send(s)
    s.gsub!(/\s+/,' ')
    if s.bytesize > 450
      s.chop!.chop! while s.bytesize > 450
      if @charset == 'UTF-8'
        #str.bytes.each_slice(100).map {|s| s.map(&:chr).join }
        #s.scan(/./u)[0,150].join # 也可以用//u
        while not s[-3,1].between?("\xe0","\xef") and s[-1].ord > 127 #ruby1.9 可以不使用这个判断了.
          s.chop!
        end
      else
        #非utf-8的聊天室就直接截断了
        s=Iconv.conv("#{@charset}//IGNORE","UTF-8//IGNORE",s[0,450])
      end
      s+=' ...'
    else
      s+= Time.now.ch
    end
    @irc.send("#{s.strip}\n", 0)
    $Lsay = Time.now
    puts "----> #{s}".pink
  end

  def connect()
    @irc.close if defined?(@irc)
    @irc = TCPSocket.open(@server, @port)
    send "NICK #{@nick}"
    sleep 1
    send "USER #@str_user"
  end

  #发送字典结果 ,取字典,可以用>之类的重定向,向某人提供字典数据
  def sayDic(dic,from,to,s='')
    direction = ''
    tellSender = false
    pub =true #默认公共消息
    pub =true if dic == 5

    if s=~/(.*?)\s?([#|>])\s?(.*?)$/i #消息重定向
      words=$1;direction=$2.to_s;b7=$3
      if b7
        b7 =$u.completename(b7)
      end
    else
      words=s
    end

    case direction
    when /\|/#公共
      sto='PRIVMSG'
    when '>' #小窗
      #sto='PRIVMSG'
      sto='PRIVMSG' ;to=b7;tellSender=true
    when /#/ #notic
      #sto='PRIVMSG'
      sto='notice' ;to=b7;tellSender=true
    else
      sto='PRIVMSG'
      to=from if !pub
    end

    tSayDic = Thread.new do
      c = words;re=''
      case dic
      when /new/i
        re = get_feed.to_s
        c=''
        b7=from
      when 1 then re = getGoogle(c ,0)
      when 2 then re = getBaidu(c )
      when 3 then re = googleFinance(c )
      when 4 then re = getGoogle_tran(c );c=''
      when 5#拼音
        re = "#{getPY(c)}";c=''; b7= from
      when 6 then re= $str1.match(/(\n.*?)#{Regexp::escape c}(.*\n?)/i)[0]
      when 10 then re = hostA(c)
      when 20 then re = $u.igetlastsay(c).to_s
      when 21 then re = $u.ims(c).to_s
      when 22
        c =$u.completename(c)
        ip = $u.getip(c)
        print 'ip=',ip
        if ip =~ /^gateway\/|mibbit\.com/i#自动whois
          $name_whois = c
          $from_whois = from
          $to_whois = to
          $s_whois = s
          send('whois ' + c)
          return
        end
        re = "#{$u.getname(c)} #{hostA(ip)}"
      when 23
        re = "#{$u.addrgrep(c)}"
      when 30
        return if c !~/^[\w\-\.]+$/#只能是字母,数字,-. "#{$`}<<#{$&}>>#{$'}"
        #`apt-cache show #{c}`.gsub(/\n/,'~').match(/Version:(.*?)~.{4,16}:(.*?)Description[:\-](.*?)~.{4,16}:/i)
        re="#$3".gsub(/~/,'')
        # gsub(/xxx/){$&.upcase; gsub(/xxx/,'\2,\1')}
      when 40
        c == "" ? re= getTQFromName(from) : re= getTQ(c)
      when 99 then re = Help ;c=''
      when 101 then re = dictcn(c);c=''
      #when 101 then re = getBaidu_tran(c);c=''
      end
      Thread.exit if re.bytesize < 2

      if sto =~ /notice/i 
        notice(to, "#{b7}:\0039 #{c}\017\0037 #{re}",0)
      else
        msg(to, "#{b7}:\0039 #{c}\017\0037 #{re}",0)
      end
      msg(from,"#{b7}:\0039 #{c}\017\0037 #{re}",0) if tellSender

    end #Thread
  end

  #utf8等乱码检测
  def check_code(s)
    tmp = guess_charset(s)
    if tmp && tmp != @charset && tmp !~ /IBM855|windows-1252/
      if tmp =~ /^gb./i
        s=Iconv.conv("#{@charset}//IGNORE","GB18030//IGNORE",s).strip
      else
        p tmp
        s=Iconv.conv("#{@charset}//IGNORE","#{tmp}//IGNORE",s).strip
      end
      p s
      if s =~ /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(.+?)\s:(.*)$/i#需要提示
        from=b1=$1;name=b2=$2;ip=b3=$3;to=b4=$4;say=$5.to_s.untaint
        #return if s =~ /action/i
        send "Notice #{from} :使用 #{@charset} 字符编码,别用#{tmp}".utf8_to_gb
        return 'matched err charset, but not need check code' if $need_Check_code < 1
        send "PRIVMSG #{((b4==@nick)? from: to)} :#{from}:said #{say} in #{tmp} ? But we use #{@charset} !"
        return 'matched err charset'
      end
    end
    return nil
  end

  #处理频道消息,私人消息,JOINS QUITS PARTS KICK NICK NOTICE
  def check_msg(s)
    return if !s
    s= Iconv.conv("#$local_charset//IGNORE","#{@charset}//IGNORE",s) if @charset != $local_charset
    case s
    when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(#{Regexp::escape @nick})\s:(.+)$/i #PRIVMSG me
      from=a1=$1;name=a2=$2;ip=a3=$3;to=a4=$4;sSay=a5=$5
      return if from =~ /freenode-connect|#{Regexp::escape @nick}/i

      if $u.saidAndCheckFloodMe(a1,a2,a3)
        #$u.floodmereset(a1)
        send "PRIVMSG #{a2} :...go to #Sevk for playing... " if rand(10) > 7
        return nil
      end

      if s =~ /help|man|帮助|有什么功能|叫什么|几岁|\?\?/i
        sSay = '`help |'
      end

      if $u.isBlocked?(from)
        return nil
      end

      tmp = check_dic(a5,a1,a1)
      if tmp.class == Fixnum
        if sSay.bytesize < 4 and rand(10) > 6
          msg(from,"#{sSay} ? ,you can try `help")
        end
        $otherbot_said=false
        if rand(10) == 9
          do_after_sec(from, "sleeping...",0,10)
        else
          do_after_sec(to,"#{from}, #{$me.rand(sSay)}",10,15) if defined?$me
        end
      end
    when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(.+?)\s:(.+)$/i #PRIVMSG channel
      nick=from=a1=$1;name=a2=$2;ip=a3=$3;to=a4=$4;sSay=a5=$5
      return if a1==@nick

      #有BOT说话
      $otherbot_said=true if name =~ $botlist || nick =~ $botlist
      #~ $u.setip(from,name,ip)

      #以我的名字开头
      if sSay =~ /^#{Regexp::escape @nick}[\s,:`](.*)$/i 
        s=$1.to_s.strip

        s = '`' + s if s[0,1] != '`'
        tmp = check_dic(s,from,to)
        case tmp
        when 1
        when 2
          #是title
        else
          puts '是字典消息' if $debug
          if $u.saidAndCheckFloodMe(a1,a2,a3)
            #$u.floodmereset(a1)
            return if to =~ NoFloodAndPlay # 不检测flood和玩bot
            $otherbot_said=true
            msg to ,"#{from}, 玩机器人? ? ... 去 #Sevk or #{to}-ot ",0 if rand(10) > 5
            return nil
          end
        end
        return 'msg with my name:.+'
      else
        ##不处理gateway用户
        return if a3=~ /^gateway\//i && $black_gateway
      end

      #禁掉一段时间
      if $u.isBlocked?(from)
        return nil
      end
      tmp = check_dic(sSay,from,to)
      case tmp
      when 1
        #非字典消息
        if sSay =~ /^#{Regexp::escape @nick}\s?,?:?(.*)$/i
          sSay=$1.to_s.strip
          if sSay.bytesize < 3
            send "PRIVMSG #{from} :#{sSay} ? ,you can try `help" if rand(10)>7 
          end
          #puts '消息以我名字开头'
          #$otherbot_said=false
          #do_after_sec(to,"#{from}, #{$me.rand(sSay)}",10,15) if $me
          #`sh sound.sh` if File.exist? 'sound.sh'
        else
          #$u.said(from,name,ip)
          #$u.setLastSay(from,sSay)
          if $u.saidAndCheckFlood(nick,name,ip,sSay)
            $u.floodreset(nick)
            return if to =~ NoFloodAndPlay # 不检测flood和玩bot
            if Time.now - $u.get_ban_time(nick) < 240 #240 秒之前ban过
              autoban to,"#{nick}!*@*",600
              kick a1
            else
              autoban to,"#{nick}!*@*"
              $u.set_ban_time(nick)
            end
            msg(a4,"#{a1}:KAO,谁说话这么快, 大段内容请贴到 http://pastebin.ca 或 http://paste.ubuntu.org.cn",10)
            notice(nick,"#{a1}: ... 大段内容请贴到 http://pastebin.ca 或 http://paste.ubuntu.org.cn",10)
            return nil
          end
        end
      when 2
        #是title
      else
        #是字典消息
        if $u.saidAndCheckFloodMe(a1,a2,a3)
          #$u.floodmereset(a1)
          return if to =~ NoFloodAndPlay # 不检测flood和玩bot
          $otherbot_said=true
          send "PRIVMSG #{a1} :sleeping ... in channel #Sevk " if rand(10) > 7
          msg to ,"#{from}, play ? ... go to channel #Sevk or #{to}-ot ",0 if rand(10) > 4
          return nil
        end
      end

    when /^:(.+?)!(.+?)@(.+?)\s(JOIN)\s:(.*)$/i #joins
      #@gateway/tor/x-2f4b59a0d5adf051
      nick=from=$1;name=$2;ip=$3;to=$5
      return if from =~ /#{Regexp::escape @nick}/i

      $need_Check_code -= 1 if from =~ $botlist_Code
      $need_say_feed -= 1 if from =~ $botlist_ub_feed
      $saytitle -= 1 if from =~ $botlist_title

      $u.add(nick,name,ip)
      #if $u.chg_ip(nick,ip) ==1
        #$u.add(nick,name,ip)
      #end
      renew_Readline_complete($u.all_nick)
    when /^:(.+?)!(.+?)@(.+?)\s(PART|QUIT)\s(.*)$/i #quit
      #:lihoo1!n=lihoo@125.120.11.127 QUIT :Remote closed the connection
      from=$1;name=$2;ip=$3;room=$5.to_s

      $need_Check_code += 1 if from =~ $botlist_Code
      $need_say_feed += 1 if from =~ $botlist_ub_feed
      $saytitle += 1 if from =~ $botlist_title

      $u.del(from,ip)
      renew_Readline_complete($u.all_nick)
    when /^(.+?)Notice(.+)$/i  #Notice
      #:ChanServ!ChanServ@services. NOTICE ikk-bot :[#sevk] "此频道目前主要用于BOT测试."

    when /^:(.+?)!(.+?)@(.+?)\sNICK\s:(.+)$/i #Nick_chg
      #:ikk-test!n=Sevk@125.124.130.81 NICK :ikk-new
      nick=$1;name=$2;ip=$3;new=$4
      if $u.chg_nick(nick,new) ==1
        $u.add(new,name,ip)
      end
      renew_Readline_complete($u.all_nick)
    when /^:(.+?)!(.+?)@(.+?)\sKICK\s(.+?)\s(.+?)\s:(.+?)$/i #KICK 
      #:ikk-irssi!n=k@unaffiliated/sevkme KICK #sevk Guest19279 :ikk-irssi\r\n"
      from=$1;chan=$4;tag=$5;reason=$6
      $need_Check_code += 1 if from =~ $botlist_Code
      $need_say_feed += 1 if from =~ $botlist_ub_feed
      $saytitle += 1 if from =~ $botlist_title

      renew_Readline_complete($u.all_nick)
    else
      return 1 # not match
    end
  end

  #检测消息是不是敏感或字典消息
  def check_dic(s,from,to)
    case s.strip
    when /^\`?>\s(.+)$/i #eval
      puts "[4 EVAL #{$1} from #{from}]"
      tmp = evaluate($1.to_s)
      msg to,"#{from}, #{tmp}",0 if tmp
    when /^`host\s(.*?)$/i # host
      sayDic(10,from,to,$1.gsub(/http:\/\//i,''))
    when /(....)(:\/\/\S+[^\s*])/#类似 http://
      url = $2
      case $1
      when /http/i
        #when  /^(.*)(http:\/\/\S+[^\s*])/i #url_title查询
        #url = $2.match(/http:\/\/\S+[^\s*]/i)[0]
        url = "http#{url}"
        return if $saytitle < 1
        return if from =~ $botlist
        return if url =~ /past/i 

        $ti = nil
        @ti=Thread.start {
          $ti=begin
            Timeout.timeout(12) { gettitle(url) }
          rescue
            $!
          end

          return if $last_ti == $ti
          $last_ti = $ti

          if $ti 
            #if $ti =~ $tiList || url =~ $urlList
              tmp = $ti.gsub(/\s+/,'')
              if s =~ /#{Regexp::escape tmp[0,14]}/i#已经发了就不说了
                puts "已经发了标题 #{tmp[0,14]}"
              else
                msg(to,"⇪ title: #{$ti}",0) 
              end
            #end
          end
        }
        @ti.priority = 40
        #@ti.join
      when /ed2k/i
        msg(to,geted2kinfo(url),0)
      end
      return 2
    when /^`(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/i #IP查询
      msg to,"#{IpLocationSeeker.new.seek($1)} #{$1}",0
    when /^`tr?\s(.+?)\s?(\d?)\|?$/i  #baidu_tran
      sayDic(101,from,to,$1)
    when /^`deb\s(.*)$/i  #aptitude show
      sayDic(30,from,to,$1)
    when /^`?s\s(.*)$/i  #TXT search
      sayDic(6,from,to,$1)
    when /^[`']h(elp)?\s?(.*?)$/i #`help
      sayDic(99,from,to,$2)
    when /^`?(new|论坛新帖|来个新帖|新帖)$/i
      sayDic('new',from,to,$1)
    when /^`?(什么是)(.+)[\?？]?$/i #什么是
      w=$2.to_s.strip
      return if w =~/这|那|的|哪/
      sayDic(1,from,to,"define:#{w} |")
    when /^(.*?)[\s:,](.+)是什么[\?？]?$/i #是什么
      if $1 
        return
      else
        w = $2.to_s.strip
        return if w =~/这|那|的|哪/
        sayDic(1,from,to,"define:#{w} |")
      end
    when /^`ims\s(.*?)$/i  #IMS查询
      puts 'IMS ' + s
      sayDic(21,from,to,$1)
    when /^`flood\s(.*?)$/i  #flood查询
      sayDic(20,from,to,$1)
    when /^`?tt\s(.*?)$/i  # getGoogle_tran
      sayDic(4,from,to,$1)
    when /^`?g\s(.*?)$/i  # Google
      sayDic(1,from,to,$1)
    when /^`x\s(.*?)$/i  # plugin
      $otherbot_said=false
      do_after_sec(to,"#{from}, #{$me.rand($1.to_s)}",10,20) if $me
    when /^`?tq\s(.*?)$/i  # 天气
      sayDic(40,from,to,$1)
    when /^`?d(ef(ine)?)?\s(.*?)$/i#define:
      sayDic(1,from,to,'define:' + $3.to_s.strip)
    when /^`?b\s(.*?)$/i  # 百度
      sayDic(2,from,to,$1)
    when /^`?a\s(.*?)$/i #查某人ip
      sayDic(22,from,to,$1)
    when /^`?f\s(.*?)$/i #查地区
      sayDic(23,from,to,$1)
    when /^`?(大家好(...)?|hi( all)?.?|hello)$/i
      $otherbot_said=false
      do_after_sec(to,from + ', hi .',10,18) if rand(10) > 4
    when /^`?((有人(...)?(吗|不|么|否)((...)?|\??))|test.{0,6}|测试(中)?(.{1,5})?)$/i #有人吗?
      $otherbot_said=false
      do_after_sec(to,from + ', hello .',10,18)
    when /^`?(bu|wo|ni|ta|shi|ru|zen|hai|neng|shen|shang|wei|guo|qing|mei|xia|zhuang|geng|zai)\s(.+)$/i  #拼音
      return nil if s =~ /[^,.?\s\w]/ #只能是拼音或标点
      return nil if s.bytesize < 12
      sayDic(5,from,to,s)
    when /^`i\s?(.*?)$/i #svn
      s1= '我的源代码: http://github.com/sevk/kk-irc-bot/ 或 http://code.google.com/p/kk-irc-bot/'
      msg to,"#{s1}",0
    when /^`rst\s?(\d*)$/i #restart
      tmp=$1
      #return if from !~ /^(ikk-|WiiW|lkk-|Sevk)$/
      tmp = "%03s" % tmp

      $need_Check_code -= 1 if tmp[0].ord == 48
      $need_Check_code += 1 if tmp[0].ord == 49 and $need_Check_code < 1
      $need_say_feed -= 1 if tmp[1].ord == 48
      $need_say_feed += 1 if tmp[1].ord == 49 and $need_say_feed < 1
      $saytitle -= 1 if tmp[2].ord == 48
      $saytitle += 1 if tmp[2].ord == 49 and $saytitle < 1

      load 'Dic.rb'
      load 'irc_user.rb'
      load "ipwry.rb"
      #load 'plugin.rb' ✘
      loadDic
      msg(to,"✔ restarted, check_charset=#$need_Check_code, get_ub_feed=#$need_say_feed, get_title=#{$saytitle}",0)
    else
      return 1#not match dic_event
    end
  end

  #服务器消息
  def check_irc_event(s)
    case s.strip
    when /^PING :(.+)$/i  # ping
      @irc.send "PONG :#{$1}\n", 0
    when /LAG1982067890/i #LAG
      $lag=Time.now - $Lping
      puts "LAG = #{$lag} 秒" if $lag > 3
    when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s.+\s:[\001]PING (.+)[\001]$/i #ctcp ping
      puts "[2 CTCP PING from #{$1}!#{$2}@#{$3} ]"
      send "NOTICE #{$1} :\001PONG #{$4}\001"
    when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s.+\s:[\001]VERSION[\001]$/i #ctcp
      puts "[3 CTCP VERSION from #{$1}!#{$2}@#{$3} ]"
      send "NOTICE #{$1} :\001VERSION Sevkme@gmail.com Ruby-irc #{Ver} birthday=2008.7.20\001"
    when /^:(.+?)\s(\d+)\s(.*?)\s:(.*)/i#motd , names list
      pos=$2.to_i;names=$3;tmp=$4.to_s
      puts pos.to_s + ' ' +  tmp
      if pos ==391#对时
        $_hour,$_min,$_sec,tmp1 = tmp.match(/(\d+):(..):(..)\s(.\d+)\:/)[1..4]
        $_hour = $_hour.to_i + (Time.now.utc_offset - tmp1.to_i * 3600 ) / 3600
        t = Time.new
        $_time= t - Time.mktime(t.year,t.month,t.day,$_hour,$_min,$_sec)
        puts Time.now.to_s.pink
      end
      if !@Motded
        #376 End of /MOTD
        if pos == 376
          @Motded = true
          $min_next_say=Time.now 
          do_after_sec(@channel,nil,5, 1)
        end
      end
      if !@Named
        case pos
        when 353
          puts '353'.red
          @tmp += " #{tmp}"
        when 366#End of /NAMES list.
          from = @tmp
          puts from

          $need_Check_code -= 1 if from =~ $botlist_Code
          $need_say_feed -= 1 if from =~ $botlist_ub_feed
          $saytitle -= 1 if from =~ $botlist_title

          @Named = true 
          renew_Readline_complete(@tmp.gsub('@','').split(' '))
          Readline.completion_append_character = ', '

          puts "是否检测乱码= #{$need_Check_code}"
          puts "feed功能= " + $need_say_feed.to_s
          print 'saytitle= ' , $saytitle
        end 
      end
      if pos == 901 #901 是 nick 验证完成.
        $min_next_say=Time.now 
        do_after_sec(@channel,nil,7,1)
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
      puts s.yellow
      #:Wii-2!n=Sevk@60.163.53.134 TOPIC #sevk :"此频道目前主要用于闲聊和调戏BOT."

      #QUIT name :niven.freenode.net irc.freenode.net
      #Netsplit hubbard.freenode.net <-> irc.freenode.net
    when /^:(.+?)\sMODE\s(.+?)([\+\-])(.+?)\s(.+)$/i#mode
      from=$1;chan=$2;type=$3;mode=$4;nick=$5
      #:services. MODE ikk-bot :+e
      #:ChanServ!ChanServ@services. MODE #sevk +o ikk-bot

      puts s.yellow
    when /^ERROR\s:(.*?):\s(.*?)$/i # Closeing
      puts s.red
      myexit if s =~ /:Closing Link:/i
    else
      return nil#not match 
    end #end case
    return 'matched'
  end #end irc_event

  #写入日志
  def save_log(s)

  end

  #检测消息是不是服务器消息,乱码检测或字典消息
  def handle_server_input(s)
    return if check_irc_event(s) #服务器消息
    return if check_code(s) #乱码
    pr_highlighted(s) #高亮显示消息
    save_log(s)#写入日志
    return if not $bot_on #bot 功能
    #s=s.force_encoding("UTF-8")
    return if check_msg(s).class != Fixnum #字典消息
  end

  #显示高亮
  def pr_highlighted(s)
    s=s.force_encoding("utf-8")
    s=s.gb_to_utf8 if @charset !~ /UTF-8/i
    case s
    when /^:(.+?)!(.+?)@(.+?)\s(.+?)\s:(.+)$/i
      from=$1;name=$2;ip=$3;mt=msgto=$4;sy=$5
      if mt =~ /^priv/i
        mt= ''
      else
        #return if mt =~ Regexp.new(Regexp.escape($ignore),Regexp::IGNORECASE)
        return if mt =~ Regexp.new($ignore,Regexp::IGNORECASE)
        mt= mt.green 
      end
      sy= sy.yellow if mt =~ /\s#{Regexp::escape @nick}/i
      re= "<#{from.cyan}> #{mt} #{sy}"
    else
      re= s.red
    end
    re = re.utf8_to_gb if $local_charset !~ /UTF-8/i
    puts re
  end

  #记录自己说话的时间
  def isaid(second=3)
    $min_next_say=Time.now + Minsaytime + second
  end

  #延时发送
  def do_after_sec(to,sSay,flg,second)
    #puts "need_do #{flg} #{second}"
    Thread.new do
      flag=flg
      if Time.now < $min_next_say
        puts '还没到下次说话的时间'
        Thread.exit
      else
        isaid(second)
      end
      if second < Delay_do_after
        sleep second
      else
        sleep rand(second-Delay_do_after) + Delay_do_after
      end
      Thread.exit if $otherbot_said

      case flag
      when 0
        send "PRIVMSG #{to} :#{sSay}"
      when 5 #发送密码
        send "PRIVMSG nickserv :id #{@pass}"
        $pass=@pass=rand(100)
        $min_next_say = Time.now
        do_after_sec(@channel,nil,7,11)
      when 7
        send "JOIN #sevk"
        send "JOIN #{@channel}"
        send 'time'
        #send "privmsg #{@channel}  :\001ACTION 我不是机器人#{0.chr} "
      when 10#打招呼回复
        tmp = (Time.parse('2010-02-14 00:00:00+08:00')-Time.now).round
        if tmp < 0 #不用显示倒计时
          return if sSay =~ /\s$/
          send "PRIVMSG #{to} :#{sSay} \0039 #{chr_hour} \017"
          return
        end

        case tmp
        when 0..60
          tmp="#{tmp}秒"
        when 61..3600
          tmp="#{tmp/60}分钟"
        when 3601..86400
          tmp="#{tmp/60/60}小时"
        else
          tmp="#{tmp/60/60/24}天"
        end
        send "privmsg #{to} :#{sSay} #{chr_hour} #{Time.now.strftime('[%H:%M]')} \0039新年快乐，离除夕0点还有 #{tmp}\017"
      when 20#notice
        send "NOTICE #{to} :#{sSay}"
      end
    end #Thread
  end

  def renew_Readline_complete(w)
    Readline.completion_proc = proc {|word| w.grep(/^#{Regexp.quote word}/) }
    Readline.completion_case_fold=true
  end

  #检测用户输入,实现IRC客户端功能.
  def iSend()
    while true
      Thread.pass
      s = Readline.readline('[' + @channel + '] ', true)
      #s = Readline.readline('', true)
      Thread.pass
      next if !s
      #lock.synchronize do
        case s
        when /^:q\s?(.*?)$/i #:q退出
          tmp = $1.to_s
          send 'quit optimize ' + tmp
          p 'quit...'
          myexit()
          sleep 2
          exit
        when /^\/msg\s(.+?)\s(.+)$/i
          who = $1;s=$2
          send "privmsg #{who} :#{s.strip}"
        when /^\/ns\s+(.*)$/i #发送到nick serv
          send "privmsg nickserv :#{$1.strip}"
        when /^\/nick\s+(.*)$/i
          @nick = $1
          send s.gsub(/^[\/]/,'')
        when /^[\/\:]/ # 发送 RAW命令
          send s.gsub(/^[\/\:]/,'')
        when /^`/
          check_dic(s,@nick,@channel)
        when /^\>\s?(.*)/
          t1 = Thread.new{
            tmp=eval($1.to_s).to_s[0,512]
            say tmp
          }
        else
          say s
        end
      #end
    end
  end
  def mystart
    $u = YAML.load_file("person_#{ARGV[0]}.yaml") rescue (p $!.message)
    p $u.class
    $u = ALL_USER.new if $u.class != ALL_USER
    $u.init_pp
    puts $u.all_nick.count.to_s + ' nicks loaded from yaml file.'.red
  end

  def myexit
    saveu
    sleep 1
    puts 'exiting...'.yellow
    @exit = true
  end
  
  #说新帖
  def say_new(to)
    begin
      tmp = get_feed.to_s
      if tmp.bytesize > 4
        msg(to,tmp,0)
      end
    rescue Exception => detail
      puts "#{detail.message()} in timer1"
      puts $@
    end
  end
  def get_time
    send('time')
  end
  def timer_start
    timer1 = Thread.new do#timer 1 , interval = 2600
      n = 0
      loop do
        sleep(650 + rand(850))
        puts Time.now.to_s.yellow
        n+=1
        next if n%2 ==0
        next unless (8..24) === Time.now.hour
        saveu if n%8 ==0
        get_time if n%12 ==0
        next if $need_say_feed < 1
        say_new($channel)
      end
    end
  end

  #主循环
  def main_loop()
    Thread.start{ iSend }

    while true
      Thread.pass
      #ready = select([@irc, $stdin], nil, nil, nil)
      Thread.exit if @exit
      ready = select([@irc], nil, nil, nil) rescue nil
      next if !ready
      for s in ready[0]
        if s == @irc
          next if @irc.eof rescue (p $!.message;p $@; next)
          handle_server_input(@irc.gets.strip) rescue (p $!.message;p $@)
        end
      end
    end

  end
end

load 'default.conf'
load ARGV[0] if ARGV[0]

while true
  irc = IRC.new($server,$port,$nick,$channel,$charset,$pass,$user)
  irc.connect()
  irc.timer_start
  irc.main_loop()
  p 'sleep ..'
  sleep 3600 * 6
end

# vim:set shiftwidth=2 tabstop=2 expandtab textwidth=79:


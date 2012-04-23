#!/usr/bin/env ruby
# coding: utf-8
# 版本需ruby较新的版本, 比如ruby1.8.7以上 或 ruby1.9.2 以上, 建议使用linux系统.

=begin
   * Description:
   * Author: Sevkme@gmail.com
   * 源代码: http://github.com/sevk/kk-irc-bot/ 或 http://code.google.com/p/kk-irc-bot/ 

=end
#BEGIN {$VERBOSE = true}


$: << 'lib'
$: << '.'
require 'rubygems'
require 'platform.rb'
load 'dic.rb'
include Math
require "readline"
require 'set'
require 'yaml'
require "ipwry.rb"
load 'irc_user.rb'
load 'plugin.rb'
load 'log.rb'
Socket.do_not_reverse_lookup = true

class IRC
  def initialize(server,port,nick,channel,charset,name="bot kk ver bot :svn Ver bot")
    $_hour = $_min = $_sec = 0
    @count=0
    @nicks = Set.new
    @exit = false
    $otherbot_said = nil
    @Motded = false
    $name_whois = nil

    @server = server
    @port = port
    @nick = nick
    @str_user= name
    @channel = channel
    charset='UTF-8' if charset =~ /utf\-?8/i
    @charset = charset
    loadDic
    mystart
  end
  
  #踢出
  def kick(ch,n,msg=$kick_info)
    send "kick #{ch} #{n} #{msg}"
  end

  #/mode #ubuntu-cn +q *!*@1.1.1.0
  def autoban(chan,nick,time=55,mode='q')
    if $lag and $lag > 0.8
      msg(to,"#{a1}:..., 有刷屏嫌疑 , 或我的网络有延迟",0)
      sleep 0.1
      restart if $lag > 6
      return
    end
    s="#{nick}!*@*"
    send "mode #{chan} +#{mode} #{s}"
    f = Time.now.strftime('%H%M%S_baned.ban')
    File.open(f,'wb'){|x|
      x.puts "mode #{chan} -#{mode} #{s}"
    }

    Thread.new(f,time) do |f,time|
      Thread.current[:name]= 'autoban del file'
      sleep time + 200
      File.delete f
    end

    $u.set_ban_time(nick)
    Thread.new do
      Thread.current[:name]= 'autoban'
      sleep time
      send "mode #{chan} -#{mode} #{s}"
    end
  end

  def ping
    Thread.new do
      Thread.current[:name]= ' ping '
      $needrestart = true
      $Lping = Time.now
      @irc.send("PING #{Time.now.to_i}\n",0)
      #send "PING #{Time.now.to_i}",false rescue nil
      #sleep 6
      #send "whois #{@nick}",false  rescue log
      sleep 5
      #print '$needrestart: ' , $needrestart , "\n"
      $need_reconn = true if $needrestart
    end
  end
  #发送notice消息
  def notice(who,sSay,delay=5)
    $otherbot_said=false
    do_after_sec(who,sSay,15,delay)
  end

  #发送msg消息,随机 delay 秒数.
  #sSay 不能为空
  def msg(who,sSay,delay=20)
    return if sSay.class != String
    return if sSay.empty?
    $otherbot_said=false
    do_after_sec(who,sSay,0,delay)
  end

  #发送到频道$channel
  def say(s,ch=@channel)
    s= Iconv.conv("#{@charset}//IGNORE","#$local_charset//IGNORE",s) if @charset != $local_charset
    send "PRIVMSG #{ch} :#{s}"
    isaid
  end

  #发送tcp数据,如果长度大于450 就自动截断.
  def send(s,add_tim_chr=true)
    s.gsub!(/\s+/,' ')
    if s.bytesize > 450
      s.chop!.chop! while s.bytesize > 450
      if @charset == 'UTF-8'
        #s.scan(/./u)[0,150].join # 也可以用//u
        while not s[-3,1].between?("\xe0","\xef") and s[-1].ord > 127 #ruby1.9 可以不使用这个判断了.
          s.chop!
        end
      else
        #非utf-8的聊天室就直接截断了
        s=Iconv.conv("#{@charset}//IGNORE","UTF-8//IGNORE",s[0,450])
      end
      s << ' …'
    else
      s.addTimCh + ' <ai>' if add_tim_chr
    end
		return if s.size < 2
    @irc.send("#{s.strip}\r\n",0)
    $Lsay = Time.now
    s= Iconv.conv("#$local_charset//IGNORE","#{@charset}//IGNORE",s) if @charset != $local_charset
    puts "----> #{s}".pink
  end

  def connect()
    trap(:INT){myexit 'int'}
    return if @exit
    $need_reconn = false
    @irc.close if @irc
		begin
			Timeout.timeout(5){@irc = TCPSocket.open(@server, @port)}
		rescue TimeoutError
			p $!.message
		retry
			sleep 50
			p 'retry 1'
		end
		sleep 0.5
    send "NICK #{@nick}"
    sleep 0.5
    send "USER #@str_user"
      Thread.new{
        sleep 22
        identify
      }
    $bot_on = $bot_on1
    $min_next_say = Time.now
    do_after_sec(@channel,nil,7,20)
    Thread.new do
			Thread.current[:name]= 'connect say'
      sleep 220+rand(400)
      #send("privmsg #{@channel} :\001ACTION #{osod} #{1.chr} ",false)
      send("privmsg #{@channel} :\001ACTION #{`uname -rv`} #{`lsb_release -d`} \x01",false) if rand(10) < 3
      #send("privmsg #{@channel} :\001ACTION #{`uname -rd`} #{`lsb_release -d`} #{`ruby --version`} \x01",false)
    end
  end

  def identify(n=false)
    File.open(ARGV[0],'rb').each { |line|
      if line =~ /pass/
        eval line
      end
    }
    send "PRIVMSG nickserv :id #{$pass}"

    $pass = nil
  end

  #发送字典结果 ,取字典,可以用>之类的重定向,向某人提供字典数据
  def sayDic(dic,from,to,s='')
    direction = ''
    tellSender = false
    pub =false #默认公共消息
    pub =true if dic == 5

    if s=~/(.*?)\s?([#|>])\s?(.*?)$/i #消息重定向
      words=$1;direction=$2;b7=$3
      if b7
        b7 =$u.completename(b7)
        p b7
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
			Thread.current[:name]= 'tSayDic'
      c = words;re=''
      case dic
      when /new/i
        re = get_feed
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
          send('whois ' + c,false)
          return
        end
        re = "#{$u.getname(c)} #{hostA(ip)}"
      when 23
        re = "#{$u.addrgrep(c)}"
      when 'deb'
        return if c !~/^[\w\-\.]+$/#只能是字母,数字,-. "#{$`}<<#{$&}>>#{$'}"
        re = get_deb_info c
      when 99 then re = Help ;c=''
      when 101 then re = dictcn(c);c=''
      end
      Thread.exit if re.bytesize < 2

      b7=from if not b7
      if sto =~ /notice/i 
        notice(to, "#{b7}:\0039 #{c}\017\0037 #{re}",18)
      else
        msg(to, "#{b7}:\0039 #{c}\017\0037 #{re}",18)
      end
      msg(from,"#{b7}:\0039 #{c}\017\0037 #{re}",14) if tellSender

    end #Thread
  end

  #utf8等乱码检测
  def check_code(s)
    tmp = guess_charset(s)
    return if ! tmp
    if tmp != @charset && tmp !~ /IBM855|windows-125|ISO-8859/i
			puts tmp
			puts tmp.togb
      if tmp =~ /^gb./i
        #tmp = 'GBK'
        s=Iconv.conv("#{@charset}//IGNORE","GB18030//IGNORE",s).strip
      else
        p tmp
        s=Iconv.conv("#{@charset}//IGNORE","#{tmp}//IGNORE",s).strip rescue s
      end
      #p s
      if s =~ /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(.+?)\s:(.*)$/i#需要提示
        from=b1=$1;name=b2=$2;ip=b3=$3;to=b4=$4;sSay=$5.to_s.untaint
        send "PRIVMSG #{((b4==@nick)? from: to)} :#{from} say: #{sSay} in #{tmp} ? We use #{@charset} !" if $need_Check_code
        send "Notice #{from} :请使用 #{@charset} 字符编码".utf8_to_gb
        return 'matched err charset'
      end
    end
    return nil
  end

  #处理频道消息,私人消息,JOINS QUITS PARTS KICK NICK NOTICE
  def check_msg(s)
    s= Iconv.conv("#$local_charset//IGNORE","#{@charset}//IGNORE",s) if @charset != $local_charset
    case s
    when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(#{Regexp::escape @nick})\s:(.+)$/i #PRIVMSG me
      from=a1=$1;to=a2=$2;ip=a3=$3;to=a4=$4;sSay=a5=$5
      return if from =~ /freenode-connect|#{Regexp::escape @nick}/i

      if $u.saidAndCheckFloodMe(from,to,a3)
        #$u.floodmereset(a1)
        msg from,"..不要玩机器人..谢谢.. .. ",11 if rand(10) > 5
        return
      end

      if s =~ /help|man|\??\??/i
        sSay = '`help |'
      end

      if $u.isBlocked?(from)
        return
      end

      tmp = check_dic(a5,a1,a1)
      if tmp == 1 #not matched check_dic
        #没到下次说话时间，就不处理botsay
        return if Time.now < $min_next_say
        $otherbot_said=false
        do_after_sec(to,"#{from}, #{botsay(sSay)}",10,49)
      end

    when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(.+?)\s:(.+)$/i #PRIVMSG channel
      nick=from=a1=$1;name=a2=$2;ip=a3=$3;to=a4=$4;sSay=a5=$5
      return if a1==@nick

      #禁掉一段时间
      if $u.isBlocked?(from)
        return nil
      end

      #bot功能是否打开
      if not $bot_on
        $u.add(nick,name,ip)
        return
      end
      #p 'check flood'
      
      if sSay.bytesize > 320
        p sSay.size
        $u.said(nick,name,ip,1.3)
      end
      if to !~ ChFreePlay and $u.saidAndCheckFlood(nick,name,ip,sSay)
        $u.floodreset(nick)
        tmp = Time.now - $u.get_ban_time(nick)
        case tmp
        when 0..80
          return
        when 79..1210 #n分钟之前ban过
          autoban to,nick,400,'q'
          kick to,a1
        else
          $b_tim = 78
          autoban to,nick,$b_tim
          msg(to,"#{a1}:..., 有刷屏嫌疑, #$kick_info +q#{$b_tim}s ",1)
        end
        notice(nick,"#{a1}: ... #$kick_info",18)
        return
      elsif $u.rep nick
        msg(to,"#{a1}: .. ..",20)
      end

      #ban ctcp but not /me
      if sSay[0].ord == 1 then
        if sSay[1,6] != /ACTION/i
          log sSay
          #$u.said(nick,name,ip,1.25)
        end
        return
      end

      #有BOT说话
      if name =~ $botlist || nick =~ $botlist
        $otherbot_said=true
        return
      end
      #$u.setip(from,name,ip)

      #以我的名字开头
      if sSay =~ /^#{Regexp::escape @nick}[\s,:`](.*)$/i 
        s=$1.to_s.strip #消息内容

        s = '`' + s if s[0,1] != '`'
        tmp = check_dic(s,from,to)
        case tmp
        when 1 #非字典消息
					#puts '消息以我名字开头'
          #没到下次说话时间，就不处理botsay
          return if Time.now < $min_next_say
					$otherbot_said=false
					do_after_sec(to,"#{from}, #{botsay(s[1..-1])}",10,39)
        when String
          msg to,tmp 
        else #是字典消息
          if $u.saidAndCheckFloodMe(a1,a2,a3)
            #$u.floodmereset(a1)
            $otherbot_said=true
            msg to ,"#{from}, 不要玩机器人 ...",0 if rand(10) > 5
            return
          end
        end
        return 'msg with my name:.+'
      else
        ##不处理gateway用户
        return if a3=~ /^gateway\//i && $black_gateway
      end

      tmp = check_dic(sSay,from,to)
      case tmp
      when 1 #非字典消息
      when 2,5 #是title , pinyin
      when String
        msg to,tmp 
      else #是字典消息
        if $u.saidAndCheckFloodMe(a1,a2,a3)
          $u.floodmereset(a1)
          $otherbot_said=true
          msg to ,"#{from}, 不要玩机器人",0 if rand(10) > 4
          return
        end
      end

    when /^:(.+?)!(.+?)@(.+?)\s(JOIN)\s:(.*)$/i #joins
      #@gateway/tor/x-2f4b59a0d5adf051
      nick=from=$1;name=$2;ip=$3;chan=$5
      return if from =~ /#{Regexp::escape @nick}/i
      return if chan =~ /#sevk/i

      $need_Check_code -= 1 if from =~ $botlist_Code
      $need_say_feed -= 1 if from =~ $botlist_ub_feed
      $saytitle -= 1 if from =~ $botlist_title

      @count +=1
      $u.add(nick,name,ip)
      #if $u.chg_ip(nick,ip) ==1
        #$u.add(nick,name,ip)
      #end
      renew_Readline_complete($u.all_nick)
    when /^:(.+?)!(.+?)@(.+?)\s(PART|QUIT)\s(.*)?\s?$/i #quit|part
      #:lihoo1!n=lihoo@125.120.11.127 QUIT :Remote closed the connection
      from=$1;name=$2;ip=$3;chan=$5.to_s
      return if chan =~ /#sevk/i

      $need_Check_code += 1 if from =~ $botlist_Code
      $need_say_feed += 1 if from =~ $botlist_ub_feed
      $saytitle += 1 if from =~ $botlist_title

      @count -=1 if @count > 0
      puts "all channel nick count : #@count" if rand(10) > 7
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
      $need_Check_code -= 1 if new =~ $botlist_Code
      $need_say_feed -= 1 if new =~ $botlist_ub_feed
      $saytitle -= 1 if new =~ $botlist_title
      renew_Readline_complete($u.all_nick)
    when /^:(.+?)!(.+?)@(.+?)\sKICK\s(.+?)\s(.+?)\s:(.+?)$/i
      #:ikk-irssi!n=k@unaffiliated/sevkme KICK #sevk Guest19279 :ikk-irssi\r\n"
      from=$1;chan=$4;tag=$5;reason=$6
      return if chan =~ /#sevk/i
      $need_Check_code += 1 if from =~ $botlist_Code
      $need_say_feed += 1 if from =~ $botlist_ub_feed
      $saytitle += 1 if from =~ $botlist_title

      @count -=1 if @count > 0
      renew_Readline_complete($u.all_nick)
    else
      return 1 # not match
    end
  rescue
    print $!.message, $@[0], 10.chr
  end

  #return 1 , 非字典
  #       2 , http
  #  String , 发送
  #检测消息是不是敏感或字典消息
  def check_dic(s,from,to)
    case s.strip.force_encoding('utf-8')
    when /^`?>\s(.+)$/i
      @e=Thread.new($1){|s|
        return 'no ad ' if s =~ /出售/ and rand(10)>2
        Thread.current[:name]= 'eval > xxx'
        tmp = evaluate(s.to_s)
        #tmp = safe_eval(s.to_s)
        msg to,"#{from}, #{tmp}", 10 if not tmp.empty?
      }
      @e.priority = -5
    when /^`host\s(.*?)$/i # host
      sayDic(10,from,to,$1.gsub(/http:\/\//i,''))
    when $re_http
      url = $1+$2
      case $1
      when /https?/i
        @ti=Thread.new do 
          msg(to,from + gettitleA(url,from),0)
        end
        @ti_p=Thread.new{ 
          msg(to,from + gettitleA(url,from,false),0)
        }
        #@ti.join(20)
        #@ti_p.join(20)
      when /ed2k/i
        msg(to,Dic.new.geted2kinfo(url),0)
      end
      return 2
    when /^`?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/i #IP查询
      msg to,"#{IpLocationSeeker.new.seek($1)} #{$1}"
    when /^`tr?\s(.+?)\s?(\d?)\|?$/i  #dict_cn
      sayDic(101,from,to,$1)
    when /^`?deb\s(.*)$/i  #aptitude show
      sayDic('deb',from,to,$1)
    when /^`?s\s(.*)$/i  #TXT search
      sayDic(6,from,to,$1)
    when /^[`']help$/i #`help
      sayDic(99,from,to,$2)
    when /^`?(new)$/i
      sayDic('new',from,to,$1)
    when /^`?(什么是)(.+)[\?？]?$/i #什么是
      w=$2.to_s.strip
      return if w =~/这|那|的|哪/
      sayDic(1,from,to,"define:#{w} |")
    when /^(.*?)?[:,]?(.+)是什么(\?|...)?$/i #是什么
      w = $1.delete '`'
      return if w =~ /^(.+)[:,]/
      return if w =~ /这|那|的|哪/
      sayDic(1,from,to,"define:#{w} |")
    when /^`ims\s(.*?)$/i  #IMS查询
      puts 'IMS ' + s
      sayDic(21,from,to,$1)
    when /^`tt\s(.*?)$/i  # getGoogle_tran
      sayDic(4,from,to,$1)
    when /^`?g\s(.*?)$/i  # Google
      sayDic(1,from,to,$1)
    when /^`?d(ef(ine)?)?\s(.*?)$/i#define:
      sayDic(1,from,to,'define:' + $3.to_s.strip)
    when /^`b\s(.*?)$/i  # 百度
      sayDic(2,from,to,$1)
    when /^`address\s(.*?)$/i #查某人ip
      sayDic(22,from,to,$1)
    when /^`f\s(.*?)$/i #查老乡
      sayDic(23,from,to,$1)
    when /^`?(大家好(...)?|hi(.all)?.?|hello)$/i
      $otherbot_said=false
      do_after_sec(to,from + ',  好.. .',10,23)
    when /^`?((有人(...)?(吗|不|么|否))|test.{0,3}|测试(下|中)?.{0,3})$/ui #有人吗?
      $otherbot_said=false
      do_after_sec(to,from + ', .. ..',10,12)
    when /^`i\s?(.*?)$/i #svn
      msg to,from + ", #$my_s",15
    #when $dic
      #msg to,from + ", #$1", 15
    when /^`rst\s?(\d*)$/i #restart soft
      tmp=$1
      #return if from !~ /^(ikk-|WiiW|lkk-|Sevk)$/
      tmp = "%03s" % tmp

      $need_Check_code -= 1 if tmp[0].ord == 48
      $need_Check_code += 1 if tmp[0].ord == 49 and $need_Check_code < 1
      $need_say_feed -= 1 if tmp[1].ord == 48
      $need_say_feed += 1 if tmp[1].ord == 49 and $need_say_feed < 1
      $saytitle -= 1 if tmp[2].ord == 48
      $saytitle += 1 if tmp[2].ord == 49 and $saytitle < 1

      reload_all rescue log
      rt = " ✔ restarted, check_charset=#$need_Check_code, get_ub_feed=#$need_say_feed, get_title=#{$saytitle}"
      msg(from,rt,0)

    #拼音
    when /^`(b|p|m|f|d|t|n|l|g|k|h|j|q|x|zh|ch|sh|r|z|c|s|y|w)(o|ao|e|iu|i|ei|ui|ou|iu|ie|an|en|in|un|ang|eng|ing|ong)/
      return nil if s =~ /[^,.?\s\w]/ #只能是拼音或标点
      return nil if s.bytesize < 12
      sayDic(5,from,to,s)
      return 5
    else
      return 1#not match dic_event
    end
	rescue 
		return 1
  end

  #服务器消息
  def check_irc_event(s)
    #:NickServ!NickServ@services. NOTICE ^k^ :You are now identified for [ub].
    #:NickServ!NickServ@services. NOTICE kk :You have 30 seconds to identify to your nickname before it is changed.
    #This nickname is registered
    case s.strip
    when /^:NickServ!NickServ@services\.\sNOTICE.+?:(This nickname is registered)|(You have 30 seconds to identify)/i
      puts s
      identify

    when /^:NickServ!NickServ@services\.\sNOTICE.+?:(You are already logged in as)|(You are now identified for)/i
      puts s
      joinit
    when /^PING :(.+)$/i  # ping
      @irc.send "PONG :#{$1}\n", 0

    #:barjavel.freenode.net PONG barjavel.freenode.net :LAG1982067890
    when /\sPONG\s(.+)$/i
      $needrestart = false
      $lag=Time.now - $Lping
      if $lag > 0.8
        puts "LAG = #{$lag} 秒" 
      end

    when /^(:.+?)!(.+?)@(.+?)\s(.+?)\s.+\s:(.+)$/i #all mesg from nick
      from=$1;name=$2;ip=$3;to=$4;sSay=$5
      #puts s
      #/#{Regexp::escape str1}/i
      if $ignore_nick =~ Regexp.new(Regexp::escape('^'+from+'$'),Regexp::IGNORECASE)
        print 'ignore_nick ' , from,"\n" if $debug
        return 'ignore_nick'
      end
      if sSay =~ /[\001]VERSION[\001]/i
        from.delete! ':'
        print from, ' get VERSION', "\n"
        send "NOTICE #{from} :\001VERSION kk-Ruby-irc #{Ver} birthday=2008.7.20\001"
        return 'match version'
      end
      return nil
    #when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s.+\s:[\001]PING(.+)[\001]$/i #ctcp ping
      #send "NOTICE #{$1} :\001PONG#{$4}\001"
    when /^:(.+?)\s(\d+)\s(.+?)\s:(.+)/i#motd , names list
      #:calvino.freenode.net 404 kk #ubuntu-cn :Cannot send to channel
      #:zelazny.freenode.net 353 ikk-bot = #sevk :ikk-bot @Sevkme @[ub]
      # verne.freenode.net 353 ^k^ = #ubuntu-cn :^k^ cocoleo seventh
      # :card.freenode.net 319 ^k^ ^k^ :@#ubuntu-cn @#sevk
      #:niven.freenode.net 437 * ^k^ :Nick/channel is temporarily unavailable
      pos=$2.to_i;names=$3;data=tmp=$4.to_s
      puts s
      if pos == 391#对时
        $_hour,$_min,$_sec,tmp1 = tmp.match(/(\d+):(..):(..)\s(.\d+)\:/)[1..4]
        $_hour = $_hour.to_i + (Time.now.utc_offset - tmp1.to_i * 3600 ) / 3600
        $_hour %= 24
        t = Time.new
        $_time= t - Time.mktime(t.year,t.month,t.day,$_hour,$_min,$_sec)
        puts Time.now.to_s.green
      end
      if pos == 376 #moted
        #$min_next_say=Time.now
        #do_after_sec(@channel,nil,7,1)
      end

      case pos
      #whois return
      when 319
        puts data
        #$needrestart = false if data =~ /#@channel/
      when 396 #nick verifd
        puts '396 verifed '.red
        #joinit
      when 353
        p 'all nick:' + tmp
        @nicks.merge tmp.split(/ /)
      when 366#End of /NAMES list.
        @count = @nicks.count
        puts "nick list: #@nicks.collect.join(' ') , #@count ".red

        renew_Readline_complete(@nicks.to_a)
        Readline.completion_append_character = ', '

        puts "是否检测乱码= #{$need_Check_code}"
        print "feed功能= " , $need_say_feed, "\n"
        print 'saytitle= ' , $saytitle, 10.chr

      when 437,433
      #:niven.freenode.net 437 * ^k^ :Nick/channel is temporarily unavailable
      #:wolfe.freenode.net 433 * [ub] :Nickname is already in use.
      #
        @nick = $nick[rand $nick.size]
        Thread.new{
          sleep 10
          send "NICK #{@nick}"
        }
      when 404
        puts s
        identify
      when 376 #end of /motd
        send 'time'
        sleep 0.5
        send "JOIN #sevk"
      end

      #自动 whois 返回
      if $name_whois && pos == 311
        ip= tmp
        $u.chg_ip($name_whois,ip)
        $name_whois = nil
        sayDic(22,$from_whois,$to_whois,$s_whois)
      end 
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
      sleep 2
      return if @exit
      log s
      $need_reconn=true
    when /.+?404\s#{@nick}\s#{@channel}\s:Cannot send to channel/
      puts s
      identify
    else
      return nil #not matched, go on
    end #end case

    return 'matched'
  end #end irc_event

  #检测消息是不是服务器消息,乱码检测或字典消息
  def handle_server_input(s)
    #puts s
    return if check_irc_event(s) #服务器消息
    return if check_code(s) #乱码
    pr_highlighted(s) rescue log #if not $client #简单显示消息
    return if not $bot_on #bot 功能
    return if check_msg(s).class != Fixnum #1 not matched 字典消息
  end

  #加入频道
  def joinit
    sleep 0.5
    send "JOIN #{@channel}" if @channel != '#sevk'
    Thread.new {sleep 40; get_baned.each{|x| sleep 10 ;send x} }
  end

  #延时发送
  def do_after_sec(to,sSay,flag,second=18)
    Thread.new do
      Thread.current[:name]= 'delay say'
      if second !=0
        if second < $minsaytime
          sleep second
        else
          sleep rand(second - $minsaytime) + $minsaytime
        end
      end
      Thread.exit if $otherbot_said

      if Time.now < $min_next_say
        print '还没到下次说话的时间:',sSay,"\n"
        return if second == 0 #如果是非BOT功能,直接return,不做rand_do
				tmp = rand_do
				return if tmp.tmpty?
        send "PRIVMSG #{to} :#{tmp}"
        Thread.exit
      else
        isaid(second)
      end

      case flag
      when 0
        send "PRIVMSG #{to} :#{sSay}"
      when 7
        sleep 0.5
        send 'time'
        sleep 0.5
        send "JOIN #sevk"
      when 10#打招呼回复
        send hello_replay(to,sSay)
      when 20#notice
        send "NOTICE #{to} :#{sSay}"
      end
    end #Thread
  end

  #自动补全
  def renew_Readline_complete(w)
    Readline.completion_proc = proc {|word| w.grep(/^#{Regexp.quote word}/) }
    Readline.completion_case_fold=true
  end

  def mystart
    $u = YAML.load_file("_#{ARGV[0]}.yaml") rescue (p $!.message)
    p $u.class
    $u = ALL_USER.new if $u.class != ALL_USER
    $u.init_pp
    puts "#{$u.all_nick.size} nicks loaded from yaml file.".red
  end

  def exited?
    @exit
  end

  #自定义退出
  def myexit(exit_msg = 'optimize')
    Thread.list.each {|x| puts "#{x.inspect}: #{x[:name]}" }
    saveu
    send( 'quit ' + exit_msg) rescue nil
    log 'my exit '
    puts 'exiting...'.yellow
    @exit = true
  end

  #说新帖
  def say_new(to)
    @say_new=Thread.new{
			Thread.current[:name]= 'say_new'
      tmp = get_feed
      msg(to,tmp,0) if tmp.bytesize > 4
    }
  end

  #大约每天一次
  def timer_daily
    puts Time.now.to_s.blue
    @daily_done = false if Time.now.hour < 5
    if Time.now.hour == 6
      return if @daily_done 
      @daily_done =true
      reload_all rescue nil
      saveu
      send('time')
      msg(@channel, osod.addTimCh ,30)
    end
  end

  #检测用户输入,实现IRC客户端功能.
  #iSend = Proc.new do |a, *b| b.collect {|i| i*a } end
  #退出软件请输入 :q
  def iSend()
    loop do
      $stdout.flush
      sleep 0.2
      #windows 好像不支持Readline
      if win_platform?
        s = IO.select([$stdin],nil,nil,0.2)
        next if !s
        #next if s[0][0] != IO
        s = $stdin.gets
      else
        s = Readline.readline('[' + @channel + '] ')
      end
      #lock.synchronize do
        case s
        when /^[:\/]q(uit)?\s?(.*)?$/i #:q退出
          myexit $2
        when /^\/msg\s(.+?)\s(.+)$/i
          who = $1;s=$2
          send "privmsg #{who} :#{s.strip}"
        when /^\/ns\s+(.*)$/i #发送到nick serv
          send "privmsg nickserv :#{$1.strip}"
        when /^\/ms\s+(.*)$/i #发送到memo serv
          send "privmsg memoserv :#{$1.strip}"
        when /^\/nick\s+(.*)$/i
          @nick = $1
          send s.gsub(/^[\/]/,'')
        when /^\/(.+)/ # /发送 RAW命令
					s1=$1
          if s1 =~ /^me/i
            say(s.gsub(/\/me/i,"\001ACTION") + "\001")
          elsif s1 =~ /^ping/i
            $Lping = Time.now
            send s1
          elsif s1 =~ /^ctcp/i
            say(s1.gsub(/^ctcp/i,"\001") + "\001")
          else
            send s1
          end
        when /^`/ #直接执行
          if s[1..-1] =~ />\s(.*)/
						p s
						begin
							tmp=eval($1.to_s)
							say tmp if tmp.class == String
						rescue Exception
							p $!.message
						#rescue
							#p $!.message
						end
          else
            check_dic(s,@nick,@channel)
          end
        else
          say s
        end
      #end
    end
  rescue
    print $!.message, $@[0], "\n"
  end

  #客户端输入并发送.
  def input_start
    @input=Thread.start{
			Thread.current[:name]= 'iSend'
			iSend }
    @input.priority = -16
  end

  #timer
  def timer_minly #每分钟一次
    @timer_min = Thread.new do
      Thread.current[:name]= 'timer min'
      n = 0
      loop do
        sleep 55+rand(10)
        #p 'timer minly'
        n+=1
        n=0 if n > 900
        if n % 20 == 0
          check_proxy_status rescue log
        end
        ping rescue log
      end
    end
  end
  def timer_start
    timer_minly
    @timer1 = Thread.new do#timer 1 , interval = 2600
      Thread.current[:name]= 'timer 30 min'
      loop do
        sleep 60*10+ rand(60*25)  #间隔14+12分钟左右
        timer_daily
        if Time.now.hour.between? 9,22
          say_new($channel) if $need_say_feed > 0
        end
      end
    end
  end

  #主循环
  def main_loop()
    loop do
      begin
        sleep 0.05
        return if @exit
        break if $need_reconn
        ready = select([@irc], nil, nil, 0.1)
        next if not ready
        for s in ready[0]
          next if s != @irc
          x = @irc.recvfrom(1480)[0]
          if x.empty?
            p ' x.empty, must be lose conn '
            return 
          end
          x.split(/\r?\n/).each{|s|
            handle_server_input(s)
          }
        end
      rescue Exception
        log
        sleep 8
        return
      rescue
        log
        sleep 2
        return
      end
    end
  end
end

if not defined? $u
  ARGV[0] = 'default.conf' if not ARGV[0]
	ARGV[0] = '~/.kk-irc-bot.conf' if File.exist? '~/.kk-irc-bot.conf'
  p 'ARGV[0] :' +  ARGV[0]
  $argv0 = ARGV[0]
  load ARGV[0]
  $bot_on1 = $bot_on
  $bot_on = false
  $ignore_nick.gsub!(/\s+/,'!')
  Dir.mkdir('irclogs') unless Dir.exist?('irclogs')
	p $server

  irc = IRC.new($server,$port,$nick[0],$channel,$charset,$name)
  irc.timer_start

	irc.input_start if $client
	Thread.current[:name]= 'main'
  loop do
    check_proxy_status
    begin
      irc.connect
      irc.main_loop
    rescue
      break if irc.exited?
      log
      p Time.now
      restart
    end
    break if irc.exited?
    #p ' exit main_loop'
    p $need_reconn
		p Time.now
    sleep 50 +rand(160)
  end
end

def restart #Hard Reset
  send 'quit lag' rescue nil
  sleep 110+ rand(300)
  p "exec #{__FILE__} #$argv0"
  sleep 5
  exec "#{__FILE__} #$argv0"
end


# vim:set shiftwidth=2 tabstop=2 expandtab textwidth=79:

#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#需要ruby较新的版本, 比如ruby1.8.7以上 或 ruby1.9.2 以上, 建议使用linux系统.

=begin
   * Description: 当时学ruby，写着玩的机器人
   * Author: Sevkme@gmail.com
   * 源代码: http://github.com/sevk/kk-irc-bot/ 或 http://git.oschina.net/sevkme/kk-irc-bot/ , http://code.google.com/p/kk-irc-bot/ 

=end

BEGIN {$VERBOSE = true}

$not_savelog = nil

require 'socket'
Socket.do_not_reverse_lookup = true
require 'rubygems'
load './lib/dic.rb'
require 'fileutils'
include FileUtils
require 'platform.rb'
require 'openssl'
#OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE #unsafe
#I_KNOW_THAT_OPENSSL_VERIFY_PEER_EQUALS_VERIFY_NONE_IS_WRONG = true
include Math
#require 'timeout'
require "readline"
require 'yaml'
require "ipwry.rb"
require 'thread'
require 'open-uri'

#放入线程运行
def go (tim=50)
  Thread.new{ yield }
end
def t(tim=40,&proc)
  Timeout.timeout(tim){
    Thread.new{ proc.call }}
end

class IRC
  def initialize(server,port,nick,channel,charset,name=$name)
    $_hour = $_min = $_sec = 0
    @count=0
    @daily_done =true
    @nicks = []
    @exit = false
    $otherbot_said = nil
    @Motded = false
    $name_whois = nil
    $re_chfreeplay ||= "sevk-free"

    @server = server
    @port = port
    @nick = nick
    @str_user= name
    @channel = channel
    mkdir_p "irclogs/#{@channel[1..-1]}"
    charset='UTF-8' if charset =~ /utf\-?8/i
    @charset = charset
    @send_nick=Proc.new{
      send "PRIVMSG nickserv :ghost #{$nick[0]}"
      send "NICK #{@nick}"
    }
    $channel_lastsay= Time.now
    loadDic
    mystart
  end
  
  #踢出
  def kick(ch,n,msg=$kick_info)
    send "kick #{ch} #{n} #{msg}"
  end

  #/mode #ubuntu-cn +q *!*@1.1.1.0
  def autoban(chan,nick,time=55,mode='q',ch=@channel)
    if $lag and $lag > 4
      msg(nick,"#{nick}:. .., 有刷屏嫌疑 , 或我的网络有延迟.",0)
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

    Thread.new(f,time) do |f1,tim|
      Thread.current[:name]= 'autoban del file'
      sleep tim + 200
      File.delete f1
    end

    $u.set_ban_time(nick)
    Thread.new(time) do |tim|
      Thread.current[:name]= 'autoban'
      sleep tim
      send "mode #{chan} -#{mode} #{s}"
    end
  end

  def ping
    Thread.new do
      #puts " thread for ping start " if $DEBUG
      Thread.current.exit if Time.now - $Lping < 30
      Thread.current[:name]= ' ping '
      $Lping = Time.now
      $needrestart = true
      @irc.puts "PING #{Time.now.to_i}" rescue log
      sleep 14
      if $needrestart
        print '$needrestart: true && $need_reconn' , "\n"
        $need_reconn = true
      end
    end
  end

  #发送notice消息
  def notice(who,sSay,delay=5)
    $otherbot_said=false
    do_after_sec(who,sSay,15,delay)
  end

  #发送msg消息,随机 delay 秒数.
  #sSay 不能为空
  def msg(who,sSay,delay=nil)
    return if sSay.class != String
    return if sSay.empty?
    $otherbot_said=false
    do_after_sec(who,sSay,0,delay||$msg_delay)
  end

  Max=399
  #发送到频道$channel
  #$fun 为true时，分行发送
  def say(s,chan=@channel)
    s.gsub!(/\s+/m,' ')
    s.strip!
    size = Max - "PRIVMSG #{chan} :".bytesize
    if $fun and s.bytesize > size
      if s.bytesize > $fun
        s.slice_u!($fun..-1)
        s << ' …'
      end
      i=0.09
      a,b=0,140
      b+=1 while b<s.size and s[a..b].bytesize < size
      send "PRIVMSG #{chan} :#{s[a..b]}"
      while b < s.size
        sleep i+=0.05
        a=b+1
        b=a+140
        b+=1 while b<s.size and s[a..b].bytesize < size
        send "PRIVMSG #{chan} : ─> #{s[a..b]}"
      end
    else
      send "PRIVMSG #{chan} :#{s}"
    end
    isaid
  end

  #发送tcp数据,如果长度大于450 就自动截断.
  def send(s)
    #print "s:"
    #p s
    #p s.bytesize
    s.gsub!(/\s+/m,' ')
    if s.bytesize > Max + 13
      s.slice_u!(size..-1)
      if @charset == 'UTF-8'
        while not s[-3].between?("\xe0","\xef") and s[-1].ord > 127 # > ruby1.9 可以不使用这个判断了.
          s.chop!
        end
      else
        #非utf-8的聊天室就直接截断了
        s=s.code_a2b("UTF-8",@charset)
      end
      s << ' …'
    end
		return if s.bytesize < 2
    @irc.puts s.strip if @irc
    #p s.bytesize
    $Lsay = Time.now
    if @charset != $local_charset
       s=s.code_a2b(@charset,$local_charset)
    end
    puts "#{Time.hms} ----> #{s}" .c_rand(Time.now.day)
    savelog s
  end

  #连接irc
  def connect
    p 'irc.conn'
    trap(:INT){myexit 'Ctrl-c'}
    return if @exit
    $need_reconn = false
    begin
      Timeout.timeout(9){
        @tcp = TCPSocket.open(@server, @port)
        if $use_ssl
          ssl_context = OpenSSL::SSL::SSLContext.new
          @socket = OpenSSL::SSL::SSLSocket.new(@tcp , ssl_context)
          @socket.sync = true
          @socket.connect
          @irc = @socket
        else
          @irc = @tcp
        end
      }
    rescue TimeoutError
       log ''
       sleep 3
       retry
       #return
    end

     send "USER #@str_user"
     @send_nick.call
     go {
        sleep 15
        identify
     }
     $bot_on = $bot_on1

     @cs.kill if @cs
     @cs=Thread.new do
        Thread.current[:name]= 'connect say'
        sleep 200+rand(500)
        #send("privmsg #{@channel} :\001ACTION #{osod} #{1.chr} ")
        @nick ||= $nick[0]
        @send_nick.call
        sleep rand(900)
        send("privmsg #{@channel} :\001ACTION #{`uname -rv`} #{`lsb_release -d `rescue '' } #{RUBY_DESCRIPTION} #{get_solida if rand < 0.1 } \x01") if $bot_on and rand < 0.3
     end
  end

  #/ns id pass
  def identify(n=false)
    File.open(ARGV[0],'rb').each { |line|
      if line =~ /pass/
        eval line
      end
    }
    @irc.puts "PRIVMSG nickserv :id #{$pass}"

    $pass = nil
  end

  #发送字典结果 ,取字典,可以用>之类的重定向,向某人提供字典数据
  def sayDic(dic,from,to,s='')
    direction = ''
    tellSender = false
    pub =false
    pub =true if [1,'g',5].include? dic

    b7=from
    if s=~/(.*?)\s?([#|>])\s?(.*?)$/i #消息重定向
      words=$1;direction=$2
      tmp=$3
      unless tmp.empty?
        b7 =$u.completename(tmp)
      end
    else
      words=s
    end

    sto='PRIVMSG'
    case direction
    when '|'#公共
      #sto='PRIVMSG'
    when '>' #小窗
      to=b7;tellSender=true
    when '#' #notic
      sto='notice' ;to=b7;tellSender=true
    else
      to=from if !pub #小窗
    end

    Thread.new(words) do |c|
			Thread.current[:name]= 'tSayDic'
      re=''
      case dic
      when /new/i
        re = get_feed
        c=''
      when 0
        re = c
      when 1,/g/i
        re = '' # "http://lmgtfy.com/ " #?q=#{c.strip} "
        re << getgoogleDefine(c)
      when 2 then re = getBaidu c
      when 3 then re = googleFinance c
      when 4 then re = getGoogle_tran(c );c=''
      when 5#拼音
        re = "#{getPY(c)}";c='';
      when 6,'s'
        re= $str1.match(/(\n.*?)#{Regexp::escape c}(.*\n?)/i)[0]
      when 10 then re = hostA(c)
      when 21 then re = $u.ims(c).to_s
      when 22
        c =$u.completename(c)
        return if c.match($nick_blacklist)#简单过滤白名单
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
        sleep 10
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

      if sto =~ /notice/i
        notice(to, "#{b7}:\0039 #{c}\017\0037 #{re}",$msg_delay)
      else
        msg(to, "#{b7}:\0039 #{c}\017\0037 #{re}",$msg_delay)
      end
      msg(from,"#{b7}:\0039 #{c}\017\0037 #{re}",$msg_delay) if tellSender

    end #Thread
  end

  #utf8等,乱码检测
  def check_code(s)
    tmp = guess_charset(s)
    return unless tmp
    #p tmp if $DEBUG
    return if tmp == 'ASCII'
    if tmp != @charset && tmp !~ /IBM855|windows-125|ISO-8859/i
      p tmp
      if tmp =~ /^gb./i
         s=s.gbtoX(@charset).strip
      else
         s=s.code_a2b(tmp,@charset).strip rescue s
      end
      return if $need_Check_code <= 0
      #p s
      #需要提示
      if s =~ /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(.+?)\s:(.*)$/i
        from=$1;to=b4=$4;sSay=$5.to_s.untaint
        send "PRIVMSG #{((b4==@nick)? from: to)} :#{from} say: #{sSay} in #{tmp} ? We use #{@charset} !"
        send "Notice #{from} :请使用 #{@charset} 字符编码".utf8_to_gb
        return 'matched err charset'
      end
    end
    return nil
  end

  #处理频道消息,私人消息,JOINS QUITS PARTS KICK NICK NOTICE
  def check_msg(s)
    if @charset != $local_charset
       s=s.code_a2b(@charset,$local_charset)
    end
    case s
    #channel 消息
    when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(.+?)\s?:(.+)$/i
      nick=from=a1=$1;name=a2=$2;ip=a3=$3;ch=to=$4;sSay=$5
      return if from =~ /^freenode-connect|#{Regexp::escape @nick}$/i

      #priv msg me
      if to =~ /#{Regexp::escape @nick}/i
        tran_msg_me(nick,name,ip,to,sSay)
        return
      end

      $channel_lastsay=Time.now

      #bot功能是否打开
      unless $bot_on
        $u.add(nick,name,ip)
        return 
      end
      
      #大段
      if sSay.bytesize > 300
        $u.said(nick,name,ip,0)
      end

      if $u.saidAndCheckFlood(nick,name,ip,sSay)
        $u.floodreset(nick)
        if $white_list =~ /#{nick}/i or ch =~ /#$re_chfreeplay/
          p ' white list or freeplay channel '
          return
        end
        tmp = Time.now - $u.get_ban_time(nick)
        #print "get ban time: ", tmp, "\n"
        $b_tim = 23
        case tmp
        when 0..$b_tim
          return
        when $b_tim..1800#之前ban过
          kick to,a1
          autoban to,nick,3600 ,'b'
        else
          autoban to,nick,$b_tim rescue log
          msg(to,"#{nick}:. .., #$kick_info +q #{$b_tim}s ",0)
        end
        notice(nick,"#{a1}: . .. #$kick_info",18)
        return
      elsif $u.rep nick
        $u.said(nick,name,ip,-1)
        msg(to,"#{nick}: .. .. ..",40)
      end

      #check ctcp but not /me
      if sSay[0].ord == 1 then
        if sSay[1,6] != /ACTION/i
          $u.said(nick,name,ip,0)
        end
        return
      end

      #有BOT说话
      if name =~ $botlist || nick =~ $botlist
        $u.said(nick,name,ip,1)
        $otherbot_said=true
        return
      end
      #$u.setip(from,name,ip)

      #以我的名字开头
      if sSay =~ /^#{Regexp::escape @nick}[\s,:`]?(.*)$/i 
        s=$1.to_s.strip #消息内容

        s.prepend '`' if s !~ /^`/
        tmp = check_dic(s,from,to)
        case tmp
        when 1 #非字典消息
           #puts '消息以我名字开头'
           #没到下次说话时间，就不处理botsay
           return if Time.now < $min_next_say
           $otherbot_said=false
           #bot say
           t {
             do_after_sec(to,"#{from}, #{botsay(s[1..-1])}",10,$msg_delay*3+9) 
           }
        when String
           msg to,tmp
        else #是字典消息
           if $u.saidAndCheckFloodMe(a1,a2,a3)
              #$u.floodmereset(a1)
              $otherbot_said=true
              #msg to ,"#{from}, 不要玩机器人 . ..",0 if rand>0.5
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
          #$otherbot_said=true
          #msg to ,"#{from}, 不要玩机器人",0 if rand>0.4
          return
        end
      end

    #join|part|quit|kick
    when /^:(.+?)!(.+?)@(.+?)\s(JOIN|part|quit|kick)\s[:#](.*)$/i
      #:Guest87873!~test@121.18.86.94 JOIN #ubuntu-cn
      #@gateway/tor/x-2f4b59a0d5adf051
      nick=from=$1;name=$2;ip=$3;mt=$4;chan=$5
      return if from =~ /#{Regexp::escape @nick}/i
      return if chan == $channel_o

			case mt
			when /join/i
        n=1
      	$u.add(nick,name,ip)
        @nicks << nick
			when /part|quit|kick/i
				n=-1
				$u.del(nick,ip)
        @nicks.delete nick
     	  puts "all channel nick count : #@count" if rand(10) > 7
			end
      #$need_Check_code -= n if from =~ $botlist_Code
      #$need_say_feed -= n if from =~ $botlist_ub_feed
      #$saytitle -=n if from =~ $botlist_title
      #print " need say title: #$saytitle "

      @count +=n
      #p n
      #p @count
      renew_Readline_complete
    when /^:(.+?)!(.+?)@(.+?)\sNICK\s:(.+)$/i #Nick_chg
      #:ikk-test!n=Sevk@125.124.130.81 NICK :ikk-new
      nick=$1;name=$2;ip=$3;new=$4
      if $u.chg_nick(nick,new) ==1
        $u.add(new,name,ip)
      end
      @nicks.delete nick
      @nicks << new
      $need_Check_code -= 1 if new =~ $botlist_Code
      $need_say_feed -= 1 if new =~ $botlist_ub_feed
      renew_Readline_complete

    when /^(.+?)Notice(.+)$/i  #Notice
      #:ChanServ!ChanServ@services. NOTICE ikk-bot :[#sevk] "此频道目前主要用于BOT测试."
      puts s
    else
      puts s
      return 1 # not match
    end
  end

  #处理私人消息
  def tran_msg_me(nick,name,ip,to,s)
    if $u.saidAndCheckFloodMe(nick,to,ip)
      #$u.floodmereset(nick)
      #msg from,"..不要玩机器人..谢谢.. .. ",0
      return
    end
    if $u.isBlocked?(nick)
      return
    end
    tmp = check_dic(s,nick,nick)
    if tmp == 1 #not matched check_dic
      #没到下次说话时间，就不处理botsay
      return if Time.now < $min_next_say
      $otherbot_said=false
      t{ do_after_sec(nick,"#{nick}, #{botsay(s)}",10,$msg_delay*3+29) }
    end
  end

  def tran_url(url,from,to,force=true)
    url=$last_url if url.empty?
    return if url.empty?
    url.gsub!(/([^\x0-\x7f].*$|[\s<>\\\[\]\^\`\{\}\|\~#"]|，|：).*$/,'')
    unless force
      return if url == $last_url
      $last_url = url.clone
      return if $saytitle < 1
      return if from =~ $botlist
      return if url =~ /(\.inputking\.|paste|imagebin\.org\/)/i
    end
    p url
    $last_url = url.clone

    @ti=Thread.new(to,from,url) do |to,from,url|
      ti = gettitleA(url,from)
      if ti
        @ti_p.kill
        #if $u.has_said? ti[8,6]
          #$saytitle -=0.2 
          #ti << " 检测到有其他取标题机器人 "
        #end
        msg(to, ti ,0)
      end
    end
    @ti_p=Thread.new(to,from,url) { |to,from,url|
      ti = gettitleA(url,from,false)
      if ti
        @ti.kill
        #if $u.has_said? ti[8,6]
          #$saytitle -=0.2 
          #ti << " 检测到有其他取标题机器人 "
        #end
        msg(to, ti ,0)
      end
    }
  end

  #return 1 : 非字典
  #       2,5 : http, pinyin
  #  String : 发送
  #检测消息是不是敏感或字典消息
  def check_dic(s,from,to)
    s.force_encoding('utf-8').strip!
    #tr_name = s.match($re_tran_head)[0]
    s.sub!($re_tran_head,''); from << " " << $1 if $1
    case s.strip
    when /^`?>\s+(.+)$/i
      @e=Thread.new($1){|x|
        Thread.current[:name]= 'eval > xxx'
        r = evaluate(x)
        r = r.inspect if r.class != String
        msg to,"#{from}: #{r}", $msg_delay*1.1
      }
      @e.priority = -3
    when /^`host\s(.*?)$/i # host
      sayDic(10,from,to,$1.gsub(/http:\/\//i,''))
    when $re_http
      url = $1+$2
      case $1
      when /https?/i
        return if s =~ $re_ignore_url
        tran_url(url,from,to,false)
      when /ed2k/i
        msg(to,Dic.new.geted2kinfo(url),0)
      end
      return 2
    when /^`?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/i #IP查询
      msg to,"#{from}, #{$1} #{IpLocationSeeker.new.seek($1)} ", $msg_delay * 2
    when /^`tr?\s(.+?)\s?(\d?)\|?$/i  #dict_cn
      sayDic(101,from,to,$1)
    when /^`?deb\s(.*)$/i  #aptitude show
      sayDic('deb',from,to,$1)
    when /^`title\s?(.*?)$/i
      url = $1.empty? ? $last_url : $1
      tran_url url,from,to,true
    when /^`help$/i #`help
      sayDic(99,from,to,$2)
    when /^`?(new)$/i
      sayDic('new',from,to,$1)
    when /^`?(什么是|what\sis)(.+[^。！.!])(呢|呀|啊)?$/i #什么是
      #http://rmmseg-cpp.rubyforge.org/
      w=$2.to_s.strip
      return if w =~/这|那|哪| that /
      #w.gsub!(/.*?的/,'')
      return if w.empty?
      sayDic(1,from,to,"define:#{w}")
    when /^(.*[:, §])?(.+?)是(什么|啥|神马).{0,3}(呀|啊)?[\?？]$/i
      p $1.class
      p $1,$2
      w = $2.strip
      p ' xxx 是啥 '
      return if $1
      return if w =~ /知道|这|那|的|哪| that|你|,/
      return if w.empty?
      sayDic(1,from,to,"define:#{w}")
    when /^`ims\s(.*?)$/i  #IMS查询
      puts 'IMS ' + s
      sayDic(21,from,to,$1)
    when /^`tt\s(.*?)$/i  # getGoogle_tran
      sayDic(4,from,to,$1)
    when /^`?(g|s)\s+(.*)$/i #Google | TXT search
      sayDic($1,from,to,$2)
    when /^`d(ef(ine)?)?\s(.*?)$/#define:
      sayDic(1,from,to,'define:' + $3.to_s.strip)
    when /^`b\s(.*?)$/  # 百度
      sayDic(2,from,to,$1)
    when /^`address\s(.*?)$/i #查某人ip
      sayDic(22,from,to,$1)
    when /^`f\s(.*?)$/ #查老乡
      sayDic(23,from,to,$1)
    when /^`?(大家好.?.?.?|hi(.all)?.?|hello)$/i
      $otherbot_said=false
      do_after_sec(to,from + ':点点点.',10,$msg_delay*3 )
    when /^\s*((有人.?(吗|么|不|否))|test|测试).?$/i #有人吗?
      #ruby1.9 一个汉字是一个: /./  ;而1.8是 3个: coding: utf-8/ascii-8bit -*-
      #ruby2.0 终于完美了,安逸了.
      $otherbot_said=false
      do_after_sec(to,from + ':点点点.',10,$msg_delay/3 )
    when $re_flood
      $proc_flood.call rescue nil
      $u.said(from,'','',-1)
    #when $dic
      #msg to,from + ", #$1", $msg_delay * 3
    when /^`rst\s?(\d*)$/i #restart soft
      tmp=$1
      #return if from !~ /^(ikk-|WiiW|lkk-|Sevk)$/
      tmp = "%03s" % tmp

      $need_Check_code -= 1 if tmp =~ /^0../
      $need_Check_code += 1 if tmp =~ /^1../ and $need_Check_code < 1
      $need_say_feed -= 1 if tmp =~ /^.0./
      $need_say_feed += 1 if tmp =~ /^.1./ and $need_say_feed < 1
      $saytitle -= 1 if tmp =~ /^..0/
      $saytitle += 1 if tmp =~ /^..1/ and $saytitle < 1

      reload_all
      rt = " ✔ 重新加载配置, 检测编码:#$need_Check_code, 取新帖:#$need_say_feed, 取标题:#{$saytitle}"
      if to != @nick
        msg(to,from+rt,0)
      else
        msg(from,rt,0)
      end

    #拼音
    when /^(.*?)[\s:,](((b|p|m|f|d|t|n|l|g|k|h|j|q|x|zh|ch|sh|r|z|c|s|y|w)(a|o|e|i|u|v|ai|ei|ui|ao|ou|iu|ie|ve|er|an|en|in|un|vn|ang|eng|ing|ong){1,1}[\s,.!?]?)+)/
      #!! nick 像拼音也会被匹配?
      #s.gsub!(/[\u4e00-\u9fa5]/ ,' ')
      s1= $2
      return nil unless s.ascii_only?
      return nil if s1.bytesize < 12
      p s1
      p $3
      #sayDic(5,from,to,s1)
      #msg(to, "#{from} 这里有输入法：http://www.inputking.com/ 或安装fcitx: apt-get install fcitx" ,$msg_delay*4)
      return 5
    else
      return 1#not match dic_event
    end
  end

  Notices_head = "^:NickServ!\\w+?@\\w+?.+?\sNOTICE.+?"
  #服务器消息
  def check_irc_event(s)
    #:NickServ!NickServ@services. NOTICE ^k^ :You are now identified for [ub].
    #:NickServ!NickServ@services. NOTICE kk :You have 30 seconds to identify to your nickname before it is changed.
    #This nickname is registered
    #p s.strip
    notices_head = Notices_head + "#{@nick}\s?:"
    case s.strip
    when Regexp.new((notices_head + $need_identify).force_encoding('ASCII-8BIT'))
      p s.green
      identify
    when Regexp.new((notices_head + $need_join).force_encoding('ASCII-8BIT'))
      p s.green
      joinit
      $sle =40
    when /^:NickServ!NickServ@services\.\sNOTICE.+?:(This nickname is registered)|(You have 30 seconds to identify)/i
      puts s
      identify
    when /^:NickServ!NickServ@services\.\sNOTICE.+?:(You are already logged in as)|(You are now identified for)/i
      puts s
      joinit
      $sle =40
    #:barjavel.freenode.net PONG barjavel.freenode.net :LAG1982067890
    when /\sPONG\s(.+)$/i
      $needrestart = false
      $lag=Time.now - $Lping
      if $lag > 1.3
        puts "LAG = #{$lag} sec".green
      end

    when /^(:.+?)!(.+?)@(.+?)\s(.+?)\s.+\s:(.+)$/i #all mesg from nick
      from=$1;name=$2;ip=$3;sSay=$5
      if from =~ $re_ignore_nick
        return '$re_ignore_nick'
      end
      if sSay =~ /[\001]VERSION[\001]/i
        from.delete! ':'
        print from, ' get VERSION', "\n"
        send "NOTICE #{from} :\001VERSION kk-Ruby-irc birthday=2008.7.20 #{Ver}\001"
        return 'match version'
      end
      return nil
    when /^PING :(.+)$/i  # ping
      @irc.write "PONG :#{$1}\n"

    #when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s.+\s:[\001]PING(.+)[\001]$/i #ctcp ping
      #send "NOTICE #{$1} :\001PONG#{$4}\001"

    #motd ed
    when /^:(.+?)\s(\d+)\s(.+?)\s:(.+)/i#motd , names list
      #:calvino.freenode.net 404 kk #ubuntu-cn :Cannot send to channel
      #:pratchett.freenode.net 482 kkk #xx :You're not a channel operator
      #:zelazny.freenode.net 353 ikk-bot = #sevk :ikk-bot @Sevkme @[ub]
      # verne.freenode.net 353 ^k^ = #ubuntu-cn :^k^ cocoleo seventh
      # :card.freenode.net 319 ^k^ ^k^ :@#ubuntu-cn @#sevk
      #:niven.freenode.net 437 * ^k^ :Nick/channel is temporarily unavailable
      #
      pos=$2.to_i;name,ch=$3.split ;data=tmp=$4.to_s
      if @charset != $local_charset
         puts s.code_a2b( @charset,$local_charset)
      else
         puts s
      end
      if pos == 391#对时
        $_time=Time.now - Time.parse(tmp)
        puts Time.now.to_s.green
      end

      case pos

      #whois return
      when 319
        puts data
        #$needrestart = false if data =~ /#@channel/
      when 328 #:services. 328 xxxx #Ubuntu-CN :http://www.ubuntu.org.cn
        puts s.green
      when 396 #nick verifd
        puts '396 verifed '.red
        #joinit
      when 353
        @nicks |= tmp.split(/ /)
        @nicks.flatten!
        p 'all nick:' , @nicks
      when 366#End of /NAMES list.
        @count = @nicks.count
        puts "nick list: #{ @nicks.join(' ') } , #@count ".red

        renew_Readline_complete
        Readline.completion_append_character = ', '

        puts "$need_Check_code= #{$need_Check_code}"
        print "$need_say_feed= " , $need_say_feed, "\n"
        print '$saytitle= ' , $saytitle, 10.chr

      when 437,433
      #:niven.freenode.net 437 * ^k^ :Nick/channel is temporarily unavailable
      #:wolfe.freenode.net 433 * [ub] :Nickname is already in use.
      #
        Thread.new{
          Thread.current[:name]= '433 change nick'
          nick = $nick[rand $nick.size]
          sleep 12
          p $nick
          send "PRIVMSG nickserv :ghost #{nick}"
          send "NICK #{nick}"
          sleep 500
          @send_nick.call
        }
      when 404
        puts s
        identify
      when 376 #end of /motd
         #send time , send join #sevk
        send 'time'
        sleep 1
        send "JOIN #$channel_o"
        $min_next_say = Time.now
      when 482
        #:pratchett.freenode.net 482 kk-bot #sevk :You're not a channel operator
        #p " * need operator for #{data} ? "
        msg ch, "#{data} * need Op.",$msg_delay*4 if rand < 0.2
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
    when /^:(.+?)\sMODE\s(.+?)\s([\+\-])(.+?)\s(.+)$/i#mode
      from=$1;chan=$2;mode=$3;nick=$4
      #:services. MODE ikk-bot :+e
      #:ChanServ!ChanServ@services. MODE #sevk +o ikk-bot
      #:a!~a@a.org MODE #ubuntu-cn +v hamo

      puts s.yellow
      log s
    when /^ERROR\s:(.*?):\s(.*?)$/i # Closeing
      log s
      return if @exit
      $need_reconn=true
    when /.+?404\s#{@nick}\s#{@channel}\s:Cannot send to channel/
      puts s
      identify
    else
      return #not matched, go on
    end #end case

    return 'matched'
  end #end irc_event

  #检测消息是不是服务器消息,乱码检测或字典消息
  def handle_server_input(s)
    #puts s
    return if check_irc_event(s) #服务器消息
    return if check_code(s) #乱码
    pr_highlighted(s) rescue log #if not $client #简单显示消息
    check_msg s rescue log '' #1 not matched 字典消息
  end

  #加入频道
  def joinit
    Thread.new {sleep 40; get_baned.each{|x| sleep 10 ;send x} }
    send "JOIN #{@channel}"
  end

  #延时发送
  def do_after_sec(to,sSay,flag,second=3)
    #print " to: #{to}  say:#{sSay[0,400]}  flag:#{flag}  second:#{second} \n"
    Thread.new do
      Thread.current[:name]= 'delay say'
      if second !=0
        if second < $minsaytime
          sleep second
        else
          sleep rand(second - $minsaytime) + $minsaytime
        end
      end
      if $otherbot_said
        #say("other bot said",to) if rand < 0.2
        #Thread.exit
      end

      if Time.now < $min_next_say and second != 0
        print '还没到下次说话的时间:',sSay,"\n"
        return if second == 0 #如果是非BOT功能,直接return,不做rand_do
				tmp = rand_do
				return if tmp.empty?
        say(tmp,to)
        Thread.exit
      end

      case flag
      when 0
        say(sSay,to)
      when 10
         #打招呼回复, 春节问好
        say(hello_replay(sSay),to)
      when 20#notice
        send "NOTICE #{to} :#{sSay}"
        #isaid
      end
    end #Thread
  end

  #自动补全
  def renew_Readline_complete
    Readline.completion_case_fold=true
    Readline.completion_proc = proc { |s|
      @nicks.grep(/^#{Regexp.escape(s)}/i)
    }
  end

  def mystart
    $data = YAML.load_file "_#{ARGV[0]}.data" rescue Hash.new
	  conf = "_#{ARGV[0]}.yaml"
    $u = YAML.load_file conf rescue All_user.new
    File.delete conf if $u.index.size == 0 rescue true
    $u ||= All_user.new
    $u.init_pp
    puts "#{$u.all_nick.size} nicks loaded from yaml file.".red
  end

  def exited?
    @exit
  end

  #自定义退出
  def myexit(exit_msg = 'optimize')
    $exit = @exit = true
    send( 'quit ' + exit_msg) rescue nil
    Thread.list.each {|x| puts "#{x.inspect}: #{x[:name]}" }
    saveu
    sleep 0.3
  end

  #大约每天一次
  def timer_daily
    #大约每天6点执行
    if Time.now.hour < 5
       @daily_done = false
    else
      return if @daily_done
      @daily_done = true
      reload_all rescue nil
      send "NICK " + @nick
      saveu
      send 'time'
      joinit
      #msg(@channel, osod.addTimCh ,30)
      #msg(@channel, "我不是机器人".addTimCh ,300)
    end
  end

  #检测用户输入,实现IRC客户端功能.
  #i Send = Proc.new do |a, *b| b.collect {|i| i*a } end
  #退出软件请输入 :quit
  def iSend(s='')
     #$stdout.flush
     return if s.empty?
     #p s.encoding

     s.force_encoding($local_charset)
     if @charset != $local_charset
        s=s.code_a2b($local_charset,@charset)
     end

     #lock.synchronize do
     case s
     when /^[:\/]quit\s?(.*)?$/i #:q退出
        myexit $1
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
     when /^\/n$/ # nicks @channel
       send "names #@channel"
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
        if s[1..-1] =~ />\s+(.*)/
           p s
           begin
              tmp=eval($1.to_s)
              say tmp if tmp.class == String
           rescue Exception
              p $!.message
           end
        else
          check_dic(s,@nick,@nick)
        end
     else
        s << " `人机合一" if $bot_on
        say s
     end
  end

  #客户端输入并发送.
  def input_start
    #$stty_save = `stty -g`.chomp rescue nil
    Thread.new do
      Thread.current.priority = -1
      Thread.current[:name]= 'iSend'
      loop do
        begin
          s = Readline.readline("[#@channel]",true)
          iSend s
          sleep 0.1
        rescue
          log ''
        end
      end
    end
  end

  #timer
  def timer_minly #每分钟一次
    @timer_min = Thread.new do
      Thread.current[:name]= 'timer min'
      n = 0
      loop do
        sleep rand(20) + 49
        n+=1
        n=0 if n > 9000
        if n % 4 == 1
          ping
        end
        if n % 20 == 0
          check_proxy_status rescue log
        end

      end
    end
  end
  def timer_start
    timer_minly
    @timer1 = Thread.new do#timer 1 , interval = 2600
      Thread.current[:name]= 'timer 30 min'
      loop do
        sleep 400 + rand(600)
        timer_daily
      end
    end
  end

  #主循环
  def main_loop()
    loop {
      return if @exit
      return if $need_reconn
      ready = select([@irc], nil, nil, 0.1)
      next unless ready
      ready[0].each do |s|
        next unless s == @irc
        if $use_ssl
          x = @irc.readpartial(OpenSSL::Buffering::BLOCK_SIZE)
        else
          x = @irc.recvfrom(1522)[0]
        end
        if x.empty?
          #log ' x.empty, may be lose conn '
          return
        end
        x.each_line {|i|
          handle_server_input(i) rescue log('')
        }
      end
    }
  end
end

def restart #Hard Reset
  send 'quit lag' rescue nil
  sleep $msg_delay + rand($msg_delay*10)
  p "exec #{$0} #$argv0"
  exec "#{$0} #$argv0"
end

if not defined? $u
  p 'ARGV :' ,ARGV
  ARGV[0] = 'default.conf' if not ARGV[0] || ARGV[0] == $0
  if __FILE__ == $0
    $argv0 = ARGV[0]
  else
    $argv0 = 'default.conf'
  end
  load ARGV[0]
  $bot_on1 = $bot_on
  $bot_on = false
  $re_ignore_nick ||= /^$/
  p $server

  irc = IRC.new($server,$port,$nick[0],$channel,$charset)
  $irc=irc
  irc.timer_start

  irc.input_start if $client
  Thread.current[:name]= 'main'
  check_proxy_status
  loop do
    begin
      exit if @exit
      irc.connect
      irc.main_loop
      p ' main_loop end'
    rescue
      break if irc.exited?
      log ''
      sleep 2
    end
    break if irc.exited?
    #restart rescue log
    p $need_reconn
    p Time.now
    sleep 2+rand($msg_delay*4)
  end
end

# vim:set shiftwidth=2 tabstop=2 expandtab:

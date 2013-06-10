#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# Sevkme@gmail.com

$: << '.'
$: << 'lib'
$:.uniq!
require 'filesize'
load 'log.rb'
load 'utf.rb'
load 'irc_user.rb'
load 'color.rb'
load 'plugin.rb' rescue log
require 'json'

def nil.empty?
	true
end

class String
  def slice_u!(n)
    self.force_encoding('ascii-8bit')
    self.slice!(n) #Deletes the specified portion from str
    self.force_encoding('utf-8')
  end

  def uri_decode
      URI.decode self
   end
   def uri_encode
      URI.encode self
   end
  def decode64
    Base64.decode64 self
  end
	alias unbase64 decode64
	alias ub64 decode64
  def encode64
    Base64.encode64 self
  end
	alias base64 encode64
	def rot13
		self.tr "A-Za-z", "N-ZA-Mn-za-m"
	end
	#"\343\213\206" ㏠
  def ii(s=['☘',"\322\211"][rand(2)])
    self.split(//u).join(s)
  end
  def addTimCh
    self << Time.now.hm.to_s
  end
  def md5
    Digest::MD5.digest self
  end
  def md5hex
    Digest::MD5.hexdigest self
  end

  #整理html里的 &nbsp; 等转义串
  def unescapeHTML
    #CGI.unescapeHTML(self) rescue self
    HTMLEntities.new.decode(self) rescue self
  end

	alias dir public_methods
end

load 'ipwry.rb'

begin
  #apt-get install rubygems
	require 'rubygems' #  以便引用相关的库, 兼容1.8的写法
  #gem install htmlentities
  require 'htmlentities'
  #gem install mechanize
  require 'mechanize'
   load 'color.rb'
   load 'showpic.rb'
rescue LoadError
  puts $!.message
  s="载入库错误, 看 README \n"
  s = s.utf8_to_gb if win_platform?
  puts s
end

begin
  require 'charguess.so'
rescue LoadError
  #p 'charguess.so not found'
end
require 'time'
require 'timeout'
require 'open-uri'
require 'uri'
require 'net/http'
require 'rss'
require 'base64'
require 'digest'
require 'resolv'
require 'yaml'
require 'pp'
require 'mechanize'
#require 'mathn'
load 'do_as_rb19.rb'
#load 'color.rb'

#todo http://www.sharej.com/ 下载查询
#todo http://netkiller.hikz.com/book/linux/ linux资料查询
$old_feed_date = nil unless defined?$old_feed_date
$_time=0 if not defined?$_time
$kick_info = "请勿Flood，超过6行请贴至paste.ubuntu.com ."

Ver='v0.52' unless defined? Ver
Help = "我是 kk-irc-bot Ver:#{Ver} ㉿ s 新手资料 g google d define `new 取论坛新贴 `deb 包查询 tt 翻译 `t 词典 > s 计算s的值 > gg 公告 > b 服务器状态 `address 查某人地址 `host 查域名 `i 机器人源码. 末尾加入|重定向,如 g ubuntu | nick" unless defined? Help

def help
  Help
end

UserAgent="kk-bot/#{Ver} (X11; U; Linux i686; en-US; rv:1.9.1.2) Gecko/20090810 Ubuntu/#{`lsb_release -r`.split(/\s/)[1] rescue ''} (ub) kk-bot/#{Ver}" unless defined? UserAgent

CN_re = /(?:\xe4[\xb8-\xbf][\x80-\xbf]|[\xe5-\xe8][\x80-\xbf][\x80-\xbf]|\xe9[\x80-\xbd][\x80-\xbf]|\xe9\xbe[\x80-\xa5])+/n unless defined? CN_re

$re_http=/(....s?)(:\/\/.+)\s?$/iu#类似 http:// https:// ed2k://
# /....s?:\/\/\S*?[^\s<>\\\[\]\{\}\^\`\~\|#"：]/i

$min_next_say = Time.now
$Lsay=Time.now; $Lping=Time.now
$last_save = Time.now - 110
$proxy_status_ok = false if not defined? $proxy_status_ok

ChFreePlay=/\-ot|arch|fire/i unless defined? ChFreePlay
$botlist=/fity|badgirl|pocoyo.?.?|iphone|\^?[Ou]_[ou]|MadGirl/i
$botlist_Code=/badgirl|\^?[Ou]_[ou]/i
$botlist_ub_feed=/crazyghost|\^?[Ou]_[ou]/i
$urlList = $tiList = /ubunt|linux|unix|debi|kernel|redhat|suse|gentoo|fedora|java|c\+\+|python|ruby|perl|Haskell|lisp|flash|vim|emacs|github|gnome|kde|x11|gtk|qt|xorg|wine|sql|wikipedia|source|android|xterm|progra|google|devel|sed|awk|regex|solaris|\.org\/|编译/i
$urlProxy=/.|\.ubuntu\.(org|com)\.cn|\.archive\.org|linux\.org|ubuntuforums\.org|\.wikipedia\.org|\.twitter\.com|\.youtube\.com|\.haskell\.org/i
$urlNoMechanize=/.|google|\.cnbeta\.com|combatsim\.bbs\.net\/bbs|wikipedia\.org|wiki\.ubuntu/i
$my_s= '我的源码: http://github.com/sevk/kk-irc-bot/ '

#字符串编码集猜测
def guess_charset(str)
	#s=str.force_encoding("ASCII-8BIT")
	#s=str.clone
  return if str.empty?
   s=str.gsub(/[\x0-\x7f]/,'') rescue str.clone
  return if s.bytesize < 6
  while s.bytesize < 25
    s << s
  end
  return guess(s) rescue nil
end

#sudo gem install charguess
#require "charguess"

if defined?CharGuess
  def guess(s)
    c=CharGuess::guess(s)
    if c =~ /gbk|gb2312/i
      return 'GB18030'
    end
    c
  end
else
  #第二种字符集猜测库
  begin
		require 'rchardet' if RUBY_VERSION < '1.9'
		require 'rchardet19' if RUBY_VERSION > '1.9'
  rescue LoadError
    s="载入库错误,命令:\napt-get install rubygems; #安装ruby库管理器 \ngem install rchardet; #安装字符猜测库\n否则字符编码检测功能可能失效. \n\n"
    s = s.utf8_to_gb if win_platform?
    puts s
    puts $!.message + $@[0]
  end
  def guess(s)
		CharDet.detect(s)['encoding'].upcase
  end
end

def reload_all
	load 'dic.rb'
	loadDic
	Thread.list.each {|x| puts "#{x.inspect}: #{x[:name]}" }
rescue Exception
  log
rescue
  log
end

def loadDic
  $str1 = IO.read('U.txt') rescue ''
  puts 'Dic load [ok]'
end

#保存缓存的users
def saveu
  return if Time.now - $last_save < 120 rescue nil
  $last_save = Time.now
  File.open("_#{ARGV[0]}.yaml","w") do |o|
    YAML.dump($u, o)
  end
  puts ' save u ok'.red
end

def safe_eval(str)
  str.force_encoding('utf-8')
  Thread.new {
    if str !~ $eval_black_list
      $SAFE=4
    end
    begin
      eval(str).to_s.gsub(/\s+/,' ')
    rescue Exception
      $!
    rescue
      $!
    end
  }.value
end

def safe(level)
  result = nil
  Thread.start {
    Thread.current[:name]= 'safe eval thread'
    $SAFE = level
    p $SAFE
    result = yield
  }.join
  return result
rescue
  log
end

#取ubuntu.com.cn的 feed.
def get_feed(url= 'http://forum.ubuntu.org.cn/feed.php',not_re = true)
  p 'in get_feed'
  begin
   feed = Timeout.timeout(11) {
      RSS::Parser.parse(url)
    }
  rescue Timeout::Error
    log ''
    return $!
  end

  $ub=nil
  p feed if feed.class != RSS::Atom::Feed
  #return if feed.empty?
  feed.items.each { |i|
    link = i.link.href.gsub(/&p=\d+#p\d+$/i,'')
    des = i.content.to_s
    #date = i.updated.content
    $date = link
    ti = i.title.content.to_s

    next if ti =~ /Re:/i && not_re
    puts i.updated.content
    $ub = "新 #{ti} #{link} #{des}"
    #p $ub
    break
  }

  if $old_feed_date == $date and $ub
    #link = feed.items[0].link.href
    #ti = feed.items[0].title.content
    ##date = feed.items[0].updated.content
    #$date = link
    #des = feed.items[0].content
    #$ub = "新⇨ #{ti} #{link} #{des}"
    $ub = ".. 逛了一下论坛,暂时无新贴.只有Re: ."
    $ub = '' if rand > 0.1
  else
    $old_feed_date = $date
  end

  return if $ub.empty?
  $ub.gsub!(/\s+/,' ')
  n = $ub.gsub(/<.+?>/,' ').unescapeHTML.gsub(/<.+?>/,' ')
    .unescapeHTML
  if n.size < 5
    p $ub
    p n
    return
  end
  return n.icolor
end

class String
  def alice_say
    return if self.empty?
    url = 'http://www.pandorabots.com/pandora/talk?botid=f5d922d97e345aa1&skin=custom_input'
    p 'alice say'
    #$uri = uri=URI.parse(url)
    #$uri.open(
      #'Accept'=>'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*',
      #'Accept'=>'text/html',
      #'Referer'=> URI.escape(url),
      #'Accept-Language'=>'zh-cn',
      #'User-Agent'=> UserAgent
    #)
    agent = Mechanize.new
    agent.user_agent_alias = 'Linux Mozilla'
    agent.max_history = 0
    agent.open_timeout = 12
		agent.read_timeout = 12
    agent.cookies
    page = agent.get(url)
    #form          = page.form_with(:name => 'f')
    #form.input = 'how old are you ?'
    #page          = agent.submit(form)
    page = agent.post(url,{"input"=> self } )
    #File.new('a.txt','wb').puts page.body
    page.body.match(/<em>.+:(.+)<input type/m)[1].gsub(/alice/i,' @ ')
      .gsub!(/<.*?>/i,'') rescue '休息一下..'
  end

	def en2zh
		#return self if self.force_encoding("ASCII-8BIT") =~ CN_re #有中文
		return self unless self.ascii_only?
		flg = 'auto%7czh-CN'
		g_tr(self,flg)
	end
	def zh2en
		#return self if self.force_encoding("ASCII-8BIT") !~ CN_re #无中文
		return self if self.ascii_only?
		flg = 'zh-CN%7cen'
		g_tr(self,flg)
	end
end

def getbody(url)
  p url
	agent = Mechanize.new
  agent.user_agent_alias = 'Linux Mozilla'
	#agent.user_agent_alias = 'Mac Safari'
  agent.max_history = 0
  agent.open_timeout = 12
  agent.cookies
	page = agent.get(url)
	#form = page.form_with(:name => 'f')
	#page = agent.post(url,{"input"=> self } )
  p ' get body ok '
	page.body
end
#google 全文翻译,参数可以是中文,也可以是英文.
def g_tr(word,flg)
  word = URI.escape(word)
  url = "http://translate.google.com/translate_a/t?client=firefox-a&text=#{word}&langpair=#{flg}&ie=UTF-8&oe=UTF-8"
  uri = URI.parse(url)
  uri.open(
	 'Accept'=>'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*',
	 'Accept'=>'text/html',
	 'Referer'=> URI.escape(url)
	 ){ |f|
			return f.read.match(/"trans":"(.*?)","/)[1]
  }
end
def getGoogle_tran(word)
  if word.force_encoding("ASCII-8BIT") =~ CN_re #有中文
    flg = 'zh-CN%7cen'
    #flg = '#auto|en|' + word ; puts '中文>英文'
  else
    flg = 'auto%7czh-CN'
    #flg = '#auto|zh-CN|' + word
  end
  word = URI.escape(word)
  #url = "http://66.249.89.100/translate_t?hl=zh-CN#{flg}"
  url = "http://translate.google.com/translate_a/t?client=firefox-a&text=#{word}&langpair=#{flg}&ie=UTF-8&oe=UTF-8"
  uri = URI.parse(url)
  uri.open(
           'Accept'=>'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*',
           'Accept'=>'text/html',
           'Referer'=> URI.escape(url)
           #'Accept-Language'=>'zh-cn',
           #'Cookie' => cookie,
           #'Range' => 'bytes=0-8000',
           #'User-Agent'=> UserAgent
           ){
    |f|
    return f.read.match(/"trans":"(.*?)","/)[1]
    #re = f.read[0,5059].force_encoding('utf-8').gsub(/\s+/,' ').gb_to_utf8
    #re.gsub!(/<.*?>/i,'')
    #return re.unescapeHTML
  }

  #Net::HTTP.start('translate.google.com') {|http|
  #resp = http.get("/translate_a/t?client=firefox-a&text=#{word}&langpair=#{flg}&ie=UTF-8&oe=UTF-8", nil)
  #p resp.body
  #return resp.body
  #}
end

#dict.cn
def dictcn(word)
  word = word.utf8_to_gb
  url = 'http://dict.cn/mini.php?q=' + word
  url = URI.escape(url)
  uri = URI.parse(url)
  res = nil
  uri.open(
  'Accept'=>'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*',
  'Accept'=>'text/html',
  'Referer'=> URI.escape(url),
  'Accept-Language'=>'zh-cn',
  #'Cookie' => cookie,
  'Range' => 'bytes=0-9000',
  'User-Agent'=> UserAgent
  ){ |f|
    re = f.read[0,5059].force_encoding('utf-8').gsub(/\s+/,' ').gb_to_utf8
    re.gsub!(/<script.*?<\/script>/i,'')
    re.gsub!(/<.*?>/i,'')
    re.gsub!(/.*?Define /i,'')
    re.gsub!(/加入生词本.*/,'')
    return re.unescapeHTML + ' << Dict.cn'
  }
rescue
  return $!.message
end

#取标题,参数是url.
def gettitle(url,proxy=true,mechanize=1)
  #p url
  timeout=6
  title = ''
  charset = ''
  flag = 0
  istxthtml = false
  if url.b =~ CN_re
    url = URI.encode(url)
  end

	if mechanize == 1
		mechanize = false if url =~ $urlNoMechanize
	else
		mechanize = true
	end
	mechanize = true if url =~ /www\.google\.com/i
  mechanize = true if url =~ $urlProxy
	mechanize = true if proxy
  print ' mechanize:' , mechanize , ' ' , url ,10.chr unless mechanize

  #用代理加快速度
  if mechanize
		#if url =~ /%[A-F0-9]/
			#url = URI.decode(url)
		#end
    if url =~ /^https/i
       agent = Mechanize.new{|a| a.ssl_version, a.verify_mode= 'SSLv3', OpenSSL::SSL::VERIFY_NONE}
       #agent = Mechanize.new
    else
       agent = Mechanize.new
    end
    if proxy and $proxy_status_ok
      agent.set_proxy($proxy_addr2,$proxy_port2)
    else
      agent.set_proxy($proxy_addr,$proxy_port)
    end
    agent.user_agent_alias = 'Linux Mozilla'
    agent.max_history = 0
    agent.open_timeout = timeout
    agent.read_timeout = timeout
    #agent.cookies
    #agent.auth('^k^', 'password')
    begin
      page = agent.head(url)
      p 'head ok' if $DEBUG
       type = page.header['content-type']
       if type =~ /image\/./i
         showpic(url)
         return
       end
       if type and type !~ /^$|text\/html/i
        re = page.response.select{|x| x=~/^conten/i }.to_s
          .gsub(/content-/i,'')
        return if re =~ /"length"=>"0"/i
        return re.gsub(/("length"=>")(\d+)"/i){ "长度=>"+Filesize.from($2+'b').pretty }
       end
    rescue Exception
      log ''
    rescue
      log ''
    end

    begin
      #p 'start agent.get' if $DEBUG
      page = agent.get(url)
      #File.new('/tmp/a.x','wb').puts page.title
      #File.new('/tmp/b.x','wb').puts Mechanize.new.get_file url
      p 'end agent.get' if $DEBUG
      if page.class != Mechanize::Page
        p 'no page'
        return
      end
      title = page.title
      puts title if $DEBUG
      return if title.empty?
			charset= guess_charset(title)
      charset='GB18030' if charset =~ /^gb|IBM855|windows-1252/i

			if charset and charset !~ /#@charset/i
        title = title.code_a2b(charset,@charset) rescue title
			end
			title = title.unescapeHTML.uri_decode
			title.gsub!(/\s+/,' ')
      puts title if $DEBUG
      return title[0,1000]
    rescue Exception
      log ''
      return if $!.message =~ /connection refused/
    rescue
      log ''
    end
  end

  #puts URI.split url
  print 'no mechanize , ' , "\n"
  tmp = begin #加入错误处理
      Timeout.timeout(timeout) {
        $uri = URI.parse(url)
        $uri.open(
					'Accept'=>'text/html , application/*',
					'Range' => 'bytes=0-8999',
					#'Cookie' => cookie,
					'User-Agent'=> UserAgent
        ){ |f|
          p f.content_type
          istxthtml= f.content_type =~ /text\/html|application\//i
					istxthtml = false if f.content_type =~ /application\/octet-stream/i
          charset= f.charset          # "iso-8859-1"
          f.read[0,8800].gsub(/\s+/,' ')
        }
      }
    rescue Timeout::Error
      #return 'time out . IN gettitle '
      return
    rescue Exception
      log ''
    rescue
      if $!.message =~ /Connection reset by peer/ && $proxy_status_ok
				p $!.message
				p ' need pass wall '
				return if proxy
      end
      #log ''
      return $!.message[0,100] + ' . IN gettitle'
    end

    return unless istxthtml

    title = tmp.match(/<title.*?>(.*?)<\/title>/i)[1] rescue nil
    #return if title.empty?

    if title.empty?
      p tmp
      if tmp.match(/meta\shttp-equiv="refresh(.*?)url=(.*?)">/i)
        p 'refresh..'
        return Timeout.timeout(7){
          url = $2
          url = "http://#{$uri.host}/#{$2}" if url !~ /^http/i
          gettitle(url)
        }
      end
    end

    #return if title =~ /index of/i

    if tmp =~ /<meta.*?charset=(.+?)["']/i
      charset=$1 if $1
    end

    if charset != 'UTF-8'
      #charset='GB18030' if charset =~ /^gb|iso-8859-/i
      title = title.code_a2b(charset,'UTF-8') rescue title
    end
    title = title.unescapeHTML rescue title
    #p title
    title
end

def gettitleA(url,from="_",proxy=true)
  $last_url = url

  ti=nil
  begin
    ti=Timeout.timeout(13){gettitle(url,proxy)}
  rescue Timeout::Error
    Thread.pass
    p 'get title Time out '
    return ['time out . IN gettitle ']
  end

  return if ti.empty?

  #检测是否有其它取标题机器人
  #
    return " ... ⇪ #{ti} "  if ti !~ $tiList and url !~ $urlList
    #登录 • Ubuntu中文论坛
    if ti
      ti.gsub!(/登录 •/, '水区水贴? ')
      return " \x033⇪ t: #{ti}\x030" if proxy
      return " \x033⇪ ti: #{ti}\x030"
    end
end

def getPY(c)
  p 'getPY'
  c=' '+ c
  c.gsub!(/\sfirefox(.*?)\s/i,' huohuliulanqi ')
  c.gsub!(/\subuntu/i,' wu ban tu ')
  c.gsub!(/\sopen(.*?)\s/i,' ')
  c.gsub!(/\s(xubuntu|fedora)/i,' ')
  c.gsub!(/\s[A-Z](.*?)\s/,' ')
  if c =~ /\skubuntu/i
    needAddKub=true
    c.gsub!(/\skubuntu/i,' ')
  end
  #re = google_py(c)
  re = youdao_py(c)
  re = re + ' Kubuntu' if needAddKub==true
  re.gsub!(/还原/i,'换源')

  if re=~ CN_re#是中文才返回
    return re
  end
end

def encodeurl(url)
  URI.encode(url)
end

def google_py(word)
  p 'google_py'
    re=''
    url = 'http://www.google.com/search?hl=zh-CN&oe=UTF-8&q=' + word.strip
    url = encodeurl(url)
    url_mini = encodeurl('http://www.google.com/search?q=' + word.strip)

    open(url,
    'Referer'=> url,
    'Accept-Encoding'=>'deflate',
    'User-Agent'=> UserAgent
    ){ |f|
      html=f.read.gsub(/\s+/,' ')
      html.match(/是不是要找.*<em>(.*?)<\/em>/i)
      return $1.to_s.unescapeHTML
    }
end

#拼音转中文
def youdao_py(words)
  url = "http://www.youdao.com/search?q=#{words}&ue=utf8&keyfrom=web.index"
  geturl(url)
end
def geturl(url,type=1)
  agent = Mechanize.new
  agent.user_agent_alias = 'Linux Mozilla'
  agent.max_history = 1
  agent.open_timeout = 12
  #agent.cookies
  begin
    page = agent.get_file(url)
  rescue Exception => e
    return e.message[0,60] + ' . IN geturl.'
  end
  puts page
  s = page.force_encoding('utf-8').match(/您是不是要找.*?<strong>(.*?)<\/strong>/im)[1]
  s.gsub!(/\s+/,' ')
  #puts s
  s.gsub!(/<.*?>/,'')#.unescapeHTML.gb_to_utf8
  s
end

def getGoogle(word,flg=0)
  print "word:"
  p word
  #url = 'http://www.google.com.hk/search?hl=zh-CN&oe=UTF-8&q=' + word.strip
  url = 'http://www.google.com.hk/search?q=' + word.strip
  #s=getbody(url)
  #puts s.size
  #File.new('/tmp/a.x','wb').puts s
  #p s.class
  #s = s.match(/<div id=resultStats>.+/i)[0]
  #File.open('tmp.html','wb').puts s
	#puts s.match(/.+?<div id=foot>/i)[0]
	#return
	#url = encodeurl(url)
	url = URI.encode(url)
  p url
	#url_mini = encodeurl('http://g.cn/search?q=' + word.strip)
	url_mini = 'http g.cn'

    re=''
    open(url
      #'Accept'=>'*/*',
      #'Referer'=> url,
      #'Accept-Language'=>'zh-CN',
      #'Accept-Encoding'=>'deflate',
      #'User-Agent'=> UserAgent
    ){ |f|
        html=f.read.gsub(/\s+/,' ')
        html=html.code_a2b(guess_charset(html) ,'utf-8')
        #File.new('/tmp/a.html','wb').puts html.match(/<div id="resultStats">.*/im)[0].gsub(/></,">\n<")
        matched = true
        case html
        when /<div class=f .*?><h3 class="r"><nobr>.*?<\/nobr>(.*?)<!--n--><!--m-->.*?<li class="g"><div class="vsc" sig="U2O">/
            re = "#$1 #$2"
        when /相关词句：(.*?)网络上查询(.*?)(https?:\/\/\S+[^\s*])">/i#define
          tmp = $2.to_s + " > " + $3.to_s.gsub(/&amp;.*/i,'')
          tmp += ' ⋙ SEE ALSO ' + $1.to_s if rand(10)>5 and $1.to_s.size > 2
        when /专业气象台|比价仅作信息参考/
          tmp = html.match(/resultStats.*?\/nobr>(.*?)(class=hd>搜索结果|Google\s+主页)/i)[1]
        when /calc_img\.gif(.*?)Google 计算器详情/i #是计算器
          tmp = "<#{$1} Google 计算器" #(.*?)<li>
        else
          matched = false
        end
        #puts html.match(/搜索用时(.*?)搜索结果<\/h2>(.*?)网页快照/i)[0]
        if matched or html =~ /搜索用时(.*?)搜索结果<\/h2>(.*?)网页快照/i
          if !matched
            tmp =$2.gsub(/<cite>.+<\/cite>/,' ' + url_mini)
            tmp1=$1
          end
          tmp.gsub!(/(.+?)您的广告/,'')
          if tmp=~/赞助商链接/
            tmp.gsub!(/赞助商链接.+?<ol.+?<\/ol>/,' ')
          end
          tmp.gsub!(/更多有关货币兑换的信息。/,"")
          tmp.gsub!(/<br>/i," ")
          #puts tmp + "\n"
          tmp.gsub!(/(.*秒）)|\s+/i,' ')
          if tmp.bytesize > 30 || word =~ /^.?13.{9}$/ || tmp =~ /小提示/ then
            re=tmp
          else
            #puts "tmp.bytesize=#{tmp.bytesize} => 是普通搜索"
            do1=true
          end
        else
          do1=true
        end
        if do1
          puts '+普通搜索+'
          if html.match(/<div class=f .*?><h3 class="r"><nobr>.*?<\/nobr>(.*?)<!--n--><!--m-->.*?<li class="g"><div class="vsc" sig="U2O">/)
            re = "#$1 #$2"
          else
            html.match(/<div id="search"><div id="ires"(.*?)(<a href="\/url\?q=https?:\/\/[^\s]*?)">?(.*?)<span class="st">(.*?)<\/span>/i)
            #~ puts "$1=#{$1}\n$2=#{$2}\n$3=#{$3}\n$4=#{$4}\n$5=#{$5}"
            #url= $2.to_s
            re = $4.to_s + $5.to_s #+ $3.to_s.sub(/.*?>/i,'')
          end

          #if url =~ /https?:\/\/(.*?)(https?:\/\/.+?)/i
            #puts '清理二次http'
            #url=$2.to_s
          #end
          return if re.bytesize < 3
          re = url_mini + ' ' + re
        end
      re.gsub!(/<.*?>/i,'')
      re.gsub!(/\[\s翻译此页\s\]/,'')
      re= re.unescapeHTML
    }

    return unless re
    return if re.bytesize < url_mini.bytesize + 3
    return re
end

class Dic
#ed2k
	def geted2kinfo(url)
    p url
		url.match(/^:\/\/\|(.+?)\|(\S+?)\|(.+?)\|.*$/)
		name=$2.to_s;size=$3.to_f
		return if $1 == 'server'
		return if not $3
		if url =~ /%..%../ #解析%DA之类的
			$ti = "#{URLDecode(name)} , #{'%.2f' % (size / 1024**3)} GB"
		else
			$ti = " #{ '%.2f' % (size / 1024**3)} GB"
		end
		$ti.gsub!(/.*\]\./,'')
		"⇪ #{$ti.unescapeHTML}"
	end
end

def getBaidu(word)
  url=  'http://www.baidu.com/s?cl=3&ie=UTF-8&wd='+word
  if url =~ /[\u4E00-\u9FA5]/
    url = URI.encode(url)
  end
  p url
  open(url,
  'Accept'=>'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*',
  'Referer'=> url,
  'Accept-Language'=>'zh-cn',
  'Accept-Encoding'=>'deflate',
  'User-Agent'=> UserAgent,
  'Host'=>'www.baidu.com',
  'Connection'=>'close'
  ) {|f|
      html=f.read().gsub!(/\s/,' ')
      re = html.match(/ScriptDiv(.*?)(http:\/\/\S+[^\s*])(.*?)size=-1>(.*?)<br><font color=#008000>(.*?)<a\ href(.*?)(http:\/\/\S+[^\s*])/i).to_s
      re = $4 ; a2=$2[0,120]
      re= re.unescapeHTML.gsub(/<.*?>/i,'')[0,330]
      $re = a2 + ' ' +  re
      $re = $re.code_a2b('gbk','UTF-8')[0,980]
  }
  $re
end

def getBaidu_tran(word,en=true)
    url= 'http://www.baidu.com/s?cl=3&ie=UTF-8&wd='+word+'&ct=1048576'
    if url =~ /[\u4E00-\u9FA5]/
      url = URI.encode(url)
    end
    open(url,
    'Accept'=>'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*',
    'Referer'=> url,
    'Accept-Language'=>'zh-cn',
    'Accept-Encoding'=>'deflate',
    'User-Agent'=> UserAgent,
    'Host'=>'www.baidu.com',
    'Connection'=>'close',
    'Cookie'=>'BAIDUID=EBBDCF1D3F9B11071169B4971122829A:FG=1; BDSTAT=172f338baaeb951db319ebc4b74543a98226cffc1f178a82b9014a90f703d697'
    ) {|f|
        html = f.read()
        html = html.gb_to_utf8.gsub(/\s+/,' ')
        re = ' <' + html.match(/class="wd"(.+?)<script>pronu/i)[1].to_s + ' '
        re += html.match(/class="explain">(.+?)<script/i)[1]
        re.gsub!(/<script\s?.+?>.+?<\/script>/i,'')
        re = re[0,600]
        re.gsub!(/&nbsp/,' ')
        re = re.unescapeHTML
        re.gsub!(/<.*?>/,'')
        $re = re.gsub(/>pronu.+?中文翻译/i,' ')
        $re.gsub!(/以下结果由.*?提供词典解释/,' ')
        $re.gsub!(/部首笔画部首.+?基本字义/,' 基本字义: ')
        if en
          $re.gsub!(/基本字义.*?英文翻译/,': ')
        end
    }
    $re
end

#为Time类加入hm方法,返回格式化后的时和分
class Time
  def hm
    Time.now.strftime(' %H:%M')
  end
  #ch,小时字符. '㍘' = 0x3358
  def ch
    " \xE3\x8D".force_encoding('ascii-8bit') + (Time.now.hour + 0x98).chr
  end
end

#取IP地址的具体位置,参数是IP
#
class String
  def getaddr_fromip
    hostA(self,true)
  end
end

def getaddr_fromip(ip)
  hostA(ip,true)
end

#域名转化为IP
def host(domain)
  return 'IPV6' if domain =~ /^([\da-f]{1,4}(:|::)){1,6}[\da-f]{1,4}$/i
  domain.gsub!(/\/.*/i,'')
  return domain if not domain.include?('.')
  return Resolv.getaddress(domain) rescue domain
end
def getProvince(domain)#取省
  hostA(domain).gsub(/^.*(\s|省)/,'').match(/\s?(.*?)市/)[1]
end

#取IP或域名的地理位置
#hostA('www.g.cn',true)
def hostA(domain,hideip=true)#处理IP 或域名
  return nil if !domain
  if domain=~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/
    tmp = $1
  else
    tmp = host(domain)
  end
  if hideip
    tmp = IpLocationSeeker.new.seek(tmp) rescue tmp
  else
    tmp = tmp + '-' + IpLocationSeeker.new.seek(tmp) rescue tmp
  end
  tmp.gsub!(/CZ88\.NET/i,'')
  tmp.gsub!(/IANA/i,'不在宇宙')
  tmp.gsub(/\s+/,'').to_s + ' '
end

alias _print print if not defined?_print
def print(* s)
	_print s.join rescue nil
	s.join
end

#eval
def evaluate(s)
	begin
		r=Timeout.timeout(2){
      safe_eval(s)
      #return safe_eval(s)
      #return safe(l){eval(s).to_s[0,290]}
      #return safely(s,l)[0,300]
		}.inspect
    #p r
    return r
	rescue Timeout::Error
		return 'Timeout'
	rescue Exception
		return $!.message[0,38] # + $@[1..2].join(' ')
	rescue
		return $!.message[0,28]#+ $@[1..2].join(' ')
	end
end

def onemin
  60
end
def onehour
  3600
end
Oneday = 86400 unless defined? Oneday

#重定义Time.now
unless defined?Time._now
  p 'redefine Time.now'
  class Time
      class << self
         alias _now now if not defined?_now
         def now
           _now - $_time
         end
      end
  end
end

#返回roll
def roll
  "掷出了: #{rand(101)} "
end

#返回uptime
def b
  `uptime`
end

#每日一句英语学习
def osod
  return '' if true
  agent = Mechanize.new
  agent.user_agent_alias = 'Linux Mozilla'
  agent.max_history = 0
  agent.open_timeout = 12
  #agent.cookies
  #url = 'http://ppcbook.hongen.com/eng/daily/sentence/0425sent.htm'
  t=Time.now
  m="%02d" % (t.sec%10+3)
  d="%02d" % t.day
  url = "http://ppcbook.hongen.com/eng/daily/sentence/#{m}#{d}sent.htm"
  begin
    page = agent.get_file(url)
  rescue Exception => e
    return e.message[0,60] + ' . IN osod'
  end
  s = page.match(/span class="e2">(.*?)<select name='selectmonth'>/mi)[1]
  s = s.gsub!(/\s+/,' ')
  s.gsub!(/<.*?>/,'').unescapeHTML.gb_to_utf8
end

        #`apt-cache show #{c}`.gsub(/\n/,'~').match(/Version:(.*?)~.{4,16}:(.*?)Description[:\-](.*?)~.{4,16}:/i)
        #re="#$3".gsub(/~/,'')
        # gsub(/xxx/){$&.upcase; gsub(/xxx/,'\2,\1')}
#get deb info
def ge name
  agent = Mechanize.new
  agent.user_agent_alias = 'Linux Mozilla'
  agent.max_history = 0
  agent.open_timeout = 12
  agent.cookies
  begin
    url = 'http://packages.ubuntu.com/search?&searchon=names&suite=all&section=all&keywords=' + name.strip
    #url = 'http://packages.debian.org/search?suite=all&arch=any&searchon=names&keywords=' + name.strip
    #p url
    #page = agent.get(url)
    page = agent.get_file(url)
    #return nil if page.class != Mechanize::Page
  rescue Exception => e
    #p e.message
    return e.message[0,60] + ' . IN getdeb'
  end
  s = page.split(/<\/h2>/im)[1]
  s = s.match(/.*resultlink".+?:(.+?)<br>(.+?): .*<h2>/mi)[1..2].join ','
  s = s.gsub!(/\s+/,' ')
  s.gsub!(/<.*?>/,'')
  s.unescapeHTML
end
alias get_deb_info ge

#公告
def gg
  t=Time.now
#http://logs.ubuntu-eu.org/free/#{t.strftime('%Y/%m/%d')}/%23ubuntu-cn.html
#https://groups.google.com/group/ircubuntu-cn/topics
"频道 #ubuntu-cn当前log地址是 :
http://irclogs.ubuntu.com/#{t.strftime('%Y/%m/%d')}/%23ubuntu-cn.html
有需要请浏览 
. #{t.strftime('%H:%M:%S')} "
end
#alias say_公告 say_gg

#简单检测代理是否可用
def check_proxy_status
  Thread.new do
    Thread.current[:name]= 'check proxy stat'
    begin
      Timeout.timeout(8){
        a=TCPSocket.open($proxy_addr2,$proxy_port2)
        a.send('get',0)
        a.close
      }
    rescue Timeout::Error
      print $proxy_addr2,':',$proxy_port2,' ',false,"\n"
      $proxy_status_ok = false
      break
    end
    #print $proxy_addr2,':',$proxy_port2,' ',true,"\n"
    $proxy_status_ok = true
  end
  true
end

def addTimCh
	Time.now.hm
end

def chr_hour
	Time.now.hm
	#Time.now.ch
end

#随机事件
def rand_do
	case rand(1000)
	when 0..130
		$my_s
	when 131..180
		get_feed
	when 200..400
		"..休息一下.. #$my_s"
	else
		""
	end
end

def hello_replay(sSay)
	tmp = Time.parse('2013-02-10')-Time.now
   #不用显示倒计时
	if tmp < 0 or tmp > Oneday*30 or rand(9) < 2
		return if sSay =~ /\s$/
		return "#{sSay} \0039 #{chr_hour} \017"
	end

	case tmp
	when 61..3600
		tmp="#{tmp/60}分钟"
	when 3601..86400
		tmp="#{tmp/60/60}小时"
	when 0..60
		tmp="#{tmp}秒"
	else
		tmp="#{tmp/60/60/24}天"
	end
	tmp.sub!(/([\.?\d]+)/){ "%.2f" % $1}
	"#{sSay} #{chr_hour} \0039新年快乐 : #{tmp}\017"
end

def gettitle_https(url)
	require 'net/http'
	require 'net/https'

	url = URI.parse(url)

	http = Net::HTTP.new(url.host, url.port)
	http.use_ssl = true if url.scheme == 'https'

	request = Net::HTTP::Get.new(url.path)
	s= http.request(request)
	#puts s.head[0,9999]
	pp s.body
	#puts s.body[0,9999]
end

def gettitle_proxy(url)
#Net::HTTP 的类方法 Net::HTTP.Proxy通常会生成一个新的类，该类通过代理进行连接操作。由于该类继承了Net::HTTP，所以可以像使用Net::HTTP那样来操作它。

	require 'net/http'
	Net::HTTP.version_1_2   # 设定对象的运作方式
#Net::HTTP::Proxy($proxy_addr, $proxy_port).start( 'some.www.server' ) {|http|
		## always connect to your.proxy.addr:8080
				#:
#}
#若Net::HTTP.Proxy的第一参数为nil的话，它就会返回Net::HTTP本身。所以即使没有代理，上面的代码也可应对自如。

end

def update_proxy_rule
  File.open('gfwlist.txt','w'){ |x|
    url = "nUE0pQbiY2S1qT9jpz94rF1aMaqfnKA0Yzqio2qfMJAiMTHhL29gY3A2ov90\npaIhnl9aMaqfnKA0YaE4qN==\n".rot13.ub64
    x.write Mechanize.new.get(url).body
  }
end

def read_proxy_rule
  $proxy_rule = File.read('gfwlist.txt').unbase64.split(/\n/)
end

#调用 alice 
def botsay(s)
  return if s.empty?
  s.zh2en.alice_say.en2zh rescue ( '.. 休息一下 ..')
end

#高亮打印消息
def pr_highlighted(s)
  #s=s.force_encoding("utf-8")
  s=s.gb_to_utf8 if @charset !~ /UTF-8/i #如果频道编码不是utf-8,则转换成utf-8

  need_savelog = false
  case s
  when /^:(.+?)!(.+?)@(.+?)\s(.+?)\s((.+?)\s:)?(.+)$/i
    from=$1;name=$2;ip=$3;mt=$4;to=$6;sy=$7
    return if $ignore_action =~ /#{Regexp::escape mt}/i
    case mt
    when /privmsg/i
      need_savelog = true
      mt.replace ' '
      if to =~ /#{Regexp::escape @channel}/i
        to.clear
      end
      sy= sy.yellow if to =~ /#{Regexp::escape @nick}/i
    when /join|part|quit|nick|notice|kick/i
      mt = ' ' << mt[0,4].red_on_white << ' '
      from << ' ' << ip.getaddr_fromip.underline
      if to =~ /#{Regexp::escape @channel}/i
        to.clear
      end
      need_savelog = true
    else
      #pp s.match(/^:(.+?)!(.+?)@(.+?)\s(.+?)\s((.+)\s:)?(.+)$/i)
      re= s.pink
      mt= ' ' + mt[0,4].blue + ' '
      sy=sy.green
      need_savelog = true
    end

    t = Time.now.strftime('%H%M%S')
    sy.force_encoding('utf-8')
    re= "#{t}#{ (('<'+from+'>').rjust(14)).c_rand(name.sum)}#{mt}#{to} #{sy}"
  else
    re= s.red
  end
  re = "\r" << re
  if $local_charset !~ /UTF-8/i
     puts re.code_a2b('utf-8',$local_charset)
  else
     puts re
  end
  savelog re if need_savelog
end

#写入聊天记录
def savelog(s)
  return if $not_savelog
  s.gsub!(/\e\[\d\d?m/i,'') #去掉ANSI颜色代码
	#gem install ansi2html

	#m = Time.now.min
	#m = "%02d" % (m - (m % 30))
	fn=Time.now.strftime("%y%m%d.txt")
  #mkdir_p "irclogs/#{@channel[1..-1]}"
	File.open("irclogs/#{@channel[1..-1]}/" + fn,'ab'){|x|
		x.puts s
	}
end

#记录自己说话的时间
def isaid(second=0)
	$min_next_say=Time.now + $minsaytime + second
end

#记录频道说话的频率
def auto_set_ch_baud(ch)
	@ch_baud ||= Hash.new
	@ch_baud.default = Hash.new
  #最后1次发言时间
	@ch_baud[ch]['last']=Time.now
end

begin
  require 'bfrb'
rescue LoadError
end
def bf(s='.')
  $last_bf=''
  BfRb::Interpreter.new.run s
  $last_bf
end

#.rvm/gems/ruby-1.9.2-p180/gems/bfrb-0.1.5/lib/bfrb/interpreter.rb
# print value in memory$
#when "."$
  #@output_stream.print current_memory.chr
  #$last_bf << current_memory.chr rescue nil

if __FILE__ == $0
   p rand_do
end


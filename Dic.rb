#!/usr/bin/env ruby1.9
# coding: utf-8
# Sevkme@gmail.com

begin
  #sudo gem install mechanize
  #安装 mechanize
  #require 'mechanize'

  #sudo apt-get install rubygems
  require 'rubygems'

  #gem install htmlentities
  $LOAD_PATH << '/usr/lib/ruby/gems/1.8/gems/htmlentities-4.0.0/lib'
  require 'htmlentities'

  #require 'rchardet'
  require 'charguess'
rescue
  puts "载入相关的库时错误,你应该执行以下命令:\nsudo apt-get install ruby rubygems; sudo gem install htmlentities"
  exit
end

require 'open-uri'
require 'iconv'
require 'uri'
require 'net/http'
require 'rss/1.0'
require 'rss/2.0'
#require 'cgi'
require 'base64'
#require 'md5'
require 'resolv'
#require 'pp'
load 'color.rb'
require 'yaml'

UserAgent='Mozilla/4.0 (X11; U; Linux i686; en-US; rv:1.9.0.11) Gecko/2009060309 Ubuntu/8.04 (hardy) Firefox/3.0.11'
#UserAgent='Opera/4.00 (X11; Linux i686 ; U; zh-cn) Presto/2.2.0'
Fi1="/media/other/LINUX学习/www/study/UBUNTU新手资料.txt"
Fi2="UBUNTU新手资料.txt"
#todo http://www.sharej.com/ 下载查询
#todo http://netkiller.hikz.com/book/linux/ linux资料查询
$old_feed_size = 0

Help = '我是ikk-irc-bot s=新手资料 g=google d=define `b=baidu tt=google翻译 `t=百度词典 `a=查某人地址 `f=查老乡 `host=查域名 >1+1 `deb=软件包查询 `i=源代码 末尾加入|是公共消息,如 g ubuntu | nick.'
Delay_do_after = 4
Ver='v0.22' unless defined?(Ver)

CN_re=/[\u4E00-\u9FA5]+/
Http_re= /http:\/\/\S+[^\s*]/

Minsaytime= 4
#puts "最小说话时间=#{Minsaytime}"
$min_next_say = Time.now
$Lsay=Time.now; $Lping=Time.now
$lag=1

#$SAFE=1 if `hostname` =~ /NoteBook/
puts "$SAFE= #$SAFE"
NoFloodAndPlay=/\#sevk|\-ot|arch|fire/i 
NoTitle=/oftc/i
BotList=/bot|fity|badgirl|crazyghost|u_b|iphone|\^O_|O_0|Psycho/i
BotList_Code=/badgirl|O_0|\^O_/i
BotList_ub_feed=/crazyghost|O_0|\^O_/i
BotList_title=/GiGi|u_b|O_0|\^O_/i
TiList=/ub|deb|ux|ix|win|goo|beta|py|ja|lu|qq|dot|dn|li|pr|qt|tk|ed|re|rt/i
UrlList=TiList

def URLDecode(str)
  #str.gsub(/%[a-fA-F0-9]{2}/) { |x| x = x[1..2].hex.chr }  
  URI.unescape(str)
end
   
def URLEncode(str)
  #str.gsub(/[^\w$&\-+.,\/:;=?@]/) { |x| x = format("%%%x", x.ord) }  
  URI.escape(str)
end

def unescapeHTML(str)
  HTMLEntities.new.decode(str)
  #CGI.unescapeHTML(str)
end 

#字符串编码集猜测,只取参数的中文部分
def guess_charset(str)
 #s = str.gsub(/./) {|s| s.ord < 128 ? '':s}
  s = str.gsub(/[\x0-\x7f]/,'')
  return nil if s.bytesize < 4
  while s.bytesize < 25
    s = s + s
  end
  return CharGuess::guess(s)
end

#如果当前目录存在UBUNTU新手资料.txt,就读取.
def readDicA()
  if (File.exist?Fi1 )
    IO.read(Fi1)
  elsif (File.exist?Fi2 )
    IO.read(Fi2)
  else
    ''
    #'http://linuxfire.com.cn/~sevk/UBUNTU新手资料.php'
  end
end
def loadDic()
  $str1 = readDicA
  puts 'Dic load [ok]'
  saveu
end
def saveu
  person_list = []
  person_list << $u
  File.open("person.yaml","w") do|io|
    YAML.dump(person_list,io)
  end
  p 'save u ok'
end

#使用安全进程进行eval操作,参数level是安全级别.
def safe(level)
  result = nil
  Thread.start {
    $SAFE = level
    begin
      result = yield
    rescue Exception => detail
      result = detail.message()
    end
  }.join
  result
end

class Rss_reader
  attr_accessor :title, :pub_date, :description, :link
end
#取ubuntu.org.cn的 feed.
def get_feed(url= 'http://forum.ubuntu.org.cn/feed.php',not_re = true)
  @rss_str = Net::HTTP.get(URI.parse(url)).force_encoding("utf-8")
  @rss_str = @rss_str.gsub(/\s/,' ')
  xml_doc = REXML::Document.new(@rss_str)
  return nil unless xml_doc
  re = Array.new
  $ub = ''
  xml_doc.elements["rss/channel"].each_element("//item") do |ele|
    reader = Rss_reader.new
    reader.title = ele.elements["title"].get_text
    reader.pub_date = ele.elements["pubDate"].get_text
    reader.description = ele.elements["description"].get_text
    reader.link = ele.elements["link"].get_text
    re << reader

    next if reader.title.to_s =~ /^Re:/i && not_re 
    #puts reader.title.to_s
    #puts reader.title.to_s.size
    $ub = "新⇨ #{reader.title} #{reader.link} #{reader.description}"
    $ub = unescapeHTML($ub)
    $ub.gsub!(/<.+?>/,' ')
    break
  end
  #puts re[0].title.to_s + " == "
  #puts re[0].description.to_s + " == "
  #puts re[0].link.to_s + " == "
  if $old_feed_size == $ub.size
    $ub = nil
  else
    $old_feed_size = $ub.size
  end
  return $ub
end

#google 全文翻译,参数可以是中文,也可以是英文.
def getGoogle_tran(word) 
    if word =~/^[\u4E00-\u9FA5]+$/#有中文
      flg = 'zh-CN%7Cen'
      #flg = '#auto|en|' + word ; puts '中文>英文'
    else
      flg = 'auto%7Czh-CN'
      #flg = '#auto|zh-CN|' + word
    end
    word = URI.escape(word)
    puts word
    #url = "http://66.249.89.100/translate_t?hl=zh-CN#{flg}"
    #66.249.89.100 = translate.google.com
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
      ){ |f|
        p f.content_type
        return f.read
        p 2323
        re = f.read[0,5059].force_encoding('utf-8').gsub(/\s+/,' ').gb_to_utf8
        re.gsub!(/<.*?>/i,'')
        return unescapeHTML(re)
      }


    #Net::HTTP.start('translate.google.com') {|http|
      #resp = http.get("/translate_a/t?client=firefox-a&text=#{word}&langpair=#{flg}&ie=UTF-8&oe=UTF-8", nil)
      #p resp.body
      #return resp.body
    #}
end

def dictcn(word)
  puts '1'.red
  word = word.utf8_to_gb
  
  url = 'http://api.dict.cn/api.php?utf8=true&q=' + word
  url = 'http://dict.cn/mini.php?q=' + word
  url = URI.escape(url)
  puts url
  uri = URI.parse(url)
  begin #加入错误处理
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
        p f.content_type
        re = f.read[0,5059].force_encoding('utf-8').gsub(/\s+/,' ').gb_to_utf8
        re.gsub!(/<script.*?<\/script>/,'')
        re.gsub!(/<.*?>/i,'')
        re.gsub!(/.*?Define /,'')
        return unescapeHTML(re) + ' << Dict.cn'
      }
  rescue 
    return $!
  end
end

#取标题,参数是url.
def gettitle(url)
    title = $tmp = ''
    flag = 0
    istxthtml = false
    if url =~ /[\u4E00-\u9FA5]/
      url = URI.encode(url)
    end
    #puts url.red
    uri = URI.parse(url)
    begin #加入错误处理
        uri.open(
        'Accept'=>'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*',
        #'Accept'=>'text/html',
        'Referer'=> URI.encode(url),
        'Accept-Language'=>'zh-cn',
        #'Cookie' => cookie,
        #'Range' => 'bytes=0-9999',
        'User-Agent'=> UserAgent
        ){ |f|
          #p f.content_type
          istxthtml= f.content_type =~ /text\/html|application\/octet-stream/i
          $charset= f.charset          # "iso-8859-1"
          $tmp = f.read[0,9999].gsub(/\s+/,' ')
        }
    rescue 
      return $!
    end
    return nil unless istxthtml

    tmp = $tmp
    tmp.match(/<title.*?>(.*?)<\/title>/i) rescue nil
    title = $1.to_s
    #puts title.green

    if title.size < 1
      puts title.size
      if tmp.match(/meta\shttp-equiv="refresh(.*?)url=(.*?)">/i)
        p 'refresh..'
        return gettitle("http://#{uri.host}/#{$2}")
      end
    end

    return nil if title =~ /index of/i

    charset=$charset
    #puts "1=" + charset.to_s
    tmp.match(/<meta.*?charset=(.+?)["']/i)
    charset=$1 if $1
    if charset =~ /^gb/i
      charset='gb18030' 
    end
    #puts '2=' + charset.to_s

    #tmp = guess_charset(title * 2).to_s
    #charset = 'gb18030' if tmp == 'TIS-620'
    #charset = tmp if tmp != ''
    #return title.force_encoding(charset)
    
    title = Iconv.conv("UTF-8","#{charset}//IGNORE",title).to_s rescue title
    title = unescapeHTML(title) rescue title
    #puts title.blue
    title
end

def getPY(c)
  c=' '+ c
  c.gsub!(/\sfirefox(.*?)\s/i,' huohuliulanqi ')
  c.gsub!(/\subuntu/i,' wu ban tu ')
  c.gsub!(/\sEnglish/i,' ying yu ')
  c.gsub!(/\sopen(.*?)\s/i,' ')
  c.gsub!(/\s(xubuntu|fedora)/i,' ')
  c.gsub!(/\s[A-Z](.*?)\s/,' ')
  if c =~ /\skubuntu/i
    needAddKub=true
    c.gsub!(/\skubuntu/i,' ')
  end
  re = getGoogle(c ,1).to_s
  re = re + ' Kubuntu' if needAddKub==true
  re.gsub!(/还原/i,'换源')

  if re=~CN_re#是中文才返回
    return re
  end
end

def getTQFromName(nick)
  ip=$u.getip(nick).to_s
  p 'getip=' + ip
  tmp=getProvince(ip).to_s
  getTQ(tmp)
end

def getTQ(s)
  getGoogle(s + ' tq',0)
end

def getGoogle(word,flg)
    re=''
    #wwwgoogle.com
    url = 'http://66.249.89.99/search?hl=zh-CN&oe=UTF-8&q=' + word.strip #+ '&btnG=Google+%E6%90%9C%E7%B4%A2&meta=lr%3Dlang_zh-TW|lang_zh-CN|lang_en&aq=f&oq='
    url = URI.escape(url)

    open(url,
    #'Accept'=>'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*',
    'Referer'=> url,
    'Accept-Language'=>'zh-cn',
    #'Accept-Encoding'=>'zip,deflate',
    'User-Agent'=> UserAgent
    ){ |f|
      html=f.read.gsub(/\s+/,' ')#.gb_to_utf8
      case flg
      when 1#拼音查询
        #~ html.match(/是不是要找：(.*?)<\/div>/)
        html.match(/是不是要找：.*?<em>(.*?)<\/em>/i)#<!--a-->
        re = $1.to_s.gsub(/\s/i,' ')
        re = unescapeHTML(re)
        #puts re + "\n\n\n"
      when 0
        matched = true
        #puts html
        case html
        when /相关词句：(.*?)<p>网络上查询<b>(.*?)(https?:\/\/\S+[^\s*])&usg=/i#define
          tmp = $2 + " > " + url
          tmp += ' ⋙ SEE ALSO ' + $1 if rand(10)>5
        when /专业气象台|比价仅作信息参考/
          tmp = html.match(/>网页<.+?(搜索用时|>网页<\/b>)(.*?)(搜索结果|Google 主页)/)[2]
        when /calc_img\.gif(.*?)Google 计算器详情/i #是计算器
          tmp = '<' +$1.to_s + ' Google 计算器' #(.*?)<li>
        else
          matched = false
        end
        #p;puts html.match(/搜索用时(.*?)搜索结果<\/h2>(.*?)网页快照/i)[0]
        if matched or html =~ /搜索用时(.*?)搜索结果<\/h2>(.*?)网页快照/i
          if !matched
            #puts ' tmp=' + $2.to_s
            tmp =$2.gsub(/<cite>.+<\/cite>/,url)
            #puts ' tmp1=' + tmp1.to_s
            tmp1=$1
          end
          tmp.gsub!(/(.+?)此展示您的广告/i,'')
          if tmp=~/赞助商链接/
            tmp.gsub!(/赞助商链接.+?<ol.+?<\/ol>/,' ')
            puts '有赞助商链接'
          end
          tmp.gsub!(/更多有关货币兑换的信息。/,"")
          tmp.gsub!(/<br>/i," ")
          #puts tmp + "\n"
          case word
          when /^tq|tq$|天气$|tianqi$/i
            #puts '天气过滤' + tmp.to_s
            tmp.gsub!(/alt="/,'>')
            tmp.gsub!(/"\stitle=/,'<')
            tmp.gsub!(/\s\/\s/,"\/")
            tmp.gsub!(/级/, '级 ' )
            tmp.gsub!(/今日\s+/, ' 今日' )
            tmp.gsub!(/<\/b>/, ' ')
            tmp.gsub!(/添加到(.*?)当前：/,' ')
            #tmp.gsub!(/北京市专业气象台(.*)/, '' )
            tmp=tmp.match(/.+?°C.+?°C.+?°C/)[0]
            tmp.gsub!(/°C/,'°C ')
          end
          tmp.gsub!(/(.*秒）)|\s+/i,' ')
          #puts "tmp.size=#{tmp.size} , #{tmp}"
          #~ puts html
          if tmp.size > 30 || word =~ /^.?13.{9}$/ || tmp =~ /小提示/ then
            re=tmp
          else
            puts "tmp.size=#{tmp.size} => 是普通搜索"
            do1=true
          end
        else
          do1=true
        end
        if do1
          puts '+普通搜索+'
          html.match(/搜索结果(.*?)(https?:\/\/[^\s]*?)">?(.*?)<div class="s">(.*?)<em>(.*?)<br><cite>/i)
          #~ puts "$1=#{$1}\n$2=#{$2}\n$3=#{$3}\n$4=#{$4}\n$5=#{$5}"
          #url= $2.to_s
          re = $4.to_s + $5.to_s #+ $3.to_s.sub(/.*?>/i,'')

          #if url =~ /https?:\/\/(.*?)(https?:\/\/.+?)/i
            #puts '清理二次http'
            #url=$2.to_s
          #end
          re = url + ' ' + re
        end
      end
      return nil if re.size < 3
      re.gsub!(/<.*?>/i,'')
      re.gsub!(/\[\s翻译此页\s\]/,'')
      re = unescapeHTML(re)
      #puts "-" * 10 + re + "-" * 10
      #puts '结果长度=' + re.to_s.size.to_s
    }

    re = nil if re.strip == url.strip
    return re
end

def geted2kinfo(url)
  url.match(/^:\/\/\|(\w+?)\|(\S+?)\|(.+?)\|.*$/)
  $ti = "#{URLDecode($2.to_s)} , #{ '%.1f' % ($3.to_f / 1024**3)} GB"
  $ti.gsub!(/.*\]\./,'')
  "⇪ #{unescapeHTML($ti)}"
end

def getBaidu(word)
  p 'getBaidu'
  p word
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
    'Connection'=>'close',
    'Cookie'=>'BAIDUID=EBBDCF1D3F9B11071169B4971122829A:FG=1; BDSTAT=172f338baaeb951db319ebc4b74543a98226cffc1f178a82b9014a90f703d697'
    ) {|f|
        html=f.read().gsub!(/\s/,' ')
        re = nil
        #scan(/>\d+.*?</).to_s.gsub!(/(>)|</,' ').to_s
        #~ <a href="http://cache.baidu" target=
        re = html.match(/ScriptDiv(.*?)(http:\/\/\S+[^\s*])(.*?)size=-1>(.*?)<br><font color=#008000>(.*?)<a\ href(.*?)(http:\/\/\S+[^\s*])/i).to_s
        re = $4 ; a2=$2[0,120]
        re= re.gsub(/<.*?>/i,'')[0,330]
        $re =  a2 + ' ' +  re
        $re = unescapeHTML($re)
        $re =  Iconv.conv("UTF-8//IGNORE","gb2312//IGNORE",$re).to_s[0,980]
    }
    $re
end

def getBaidu_tran(word,en=true)
    #word= Iconv.conv("GB18030//IGNORE","UTF-8//IGNORE",word).to_s
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
        re.gsub!(/<.*?>/,'')
        re = re[0,500]
        re.gsub!(/&nbsp/,' ')
        re = unescapeHTML(re)
        $re = re.gsub(/>pronu.+?中文翻译/i,' ')
        $re.gsub!(/以下结果由.*?提供词典解释/,' ')
        if en
          $re.gsub!(/基本字义.*?英文翻译/," #{chr_hour} ")
        end
    }
    $re
end

#为Time类加入hm方法,返回格式化后的时和分
class Time
  def hm()
    "#{Time.now.strftime('[%H:%M]')}"
  end
  def ch()
    ' ' + chr_hour.to_s
  end
end

$last_time_min = Time.now
def time_min_ai()
  if Time.now - $last_time_min > 900
    $last_time_min = Time.now
    return " #{Time.hm}"
  end
end

def time_min()
  " #{Time.now.strftime('[%H:%M]')}"
end

#ch,小时字符. '㍘' = 0x3358
def chr_hour()
  if Time.now - $last_time_min > 1800
    $last_time_min = Time.now
    return (Time.now.hour + 0x3358).chr("UTF-8")
    #"\xE3\x8D"+ (Time.now.hour + 0x98).chr
  end
end

#取IP地址的具体位置,参数是IP
def getaddr_fromip(ip)
  hostA(ip)
end

def host(domain)#处理域名
  return 'IPV6' if domain =~ /^([\da-f]{1,4}(:|::)){1,6}[\da-f]{1,4}$/i
  domain=domain.match(/^[\w\.\-\d]*/)[0]
  begin
    return Resolv.getaddress(domain)
  rescue Exception => detail
    puts detail.message()
    '水星'
  end
end
def getProvince(domain)#取省
  hostA(domain).gsub(/^.*(\s|省)/,'').match(/\s?(.*?)市/)[1]
end
def hostA(domain)#处理IP 或域名
  return nil if !domain
    if domain=~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/
        tmp = $1
    else
        tmp = host(domain)
    end
  tmp = tmp + '-' + IpLocationSeeker.new.seek(tmp)
  tmp.gsub!(/CZ88\.NET/i,'某处')
  tmp.gsub!(/IANA/i,'不在宇宙')
  tmp.gsub(/\s+/,'')
end

#为字符串添加2个方法,用于gb18030和utf8互转.
class String
  def utf8
    self.force_encoding("utf-8")
  end
  def gb
    self.force_encoding("gb18030")
  end
  def gb_to_utf8
    Iconv.conv("UTF-8//IGNORE","GB18030//IGNORE",self).to_s
  end
  def utf8_to_gb
    Iconv.conv("GB18030//IGNORE","UTF-8//IGNORE",self).to_s
  end
  def decode64
    Base64.decode64 self
  end
  def encode64
    Base64.encode64 self
  end
  def ee(s=['☘',"\322\211"][rand(2)])
    self.split(//u).join(s)
  end
end




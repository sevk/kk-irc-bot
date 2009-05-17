#!/usr/bin/ruby -w
#Sevkme@gmail.com

require 'open-uri'
require 'iconv'
require 'uri'
require 'net/http'
require 'rss/1.0'
require 'rss/2.0'
#require 'cgi'

begin require 'rubygems' ;rescue LoadError ;end
#sudo gem install htmlentities
require 'htmlentities'

begin
  require 'charguess'
  #可用这个替代gem install rchardet
  #CharDet.detect("中文")["encoding"]
rescue Exception => detail
  $need_Check_code = false
end

#UserAgent= 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.0.7) Gecko/2009030422 Ubuntu/8.04 (hardy) Firefox/3.0.7' unless defined?(UserAgent)
UserAgent= 'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0; zh-CN; Maxthon 2.0)' unless defined?(UserAgent)
Fi1="/media/other/LINUX学习/www/study/UBUNTU新手资料.txt"
Fi2="UBUNTU新手资料.txt"
#~ require 'google'
#todo http://www.sharej.com/ 下载查询
#todo http://netkiller.hikz.com/book/linux/ linux资料查询
$old_feed_size = nil

def unescapeHTML(str)
  HTMLEntities.new.decode(str)
  #CGI.unescapeHTML(str)
end 

def Codes(s) #irssi: /RECODE ADD #sevk gbk
  return CharGuess::guess(s).to_s
end

def readDicA()
  if (File.exist?Fi1 )
    IO.read(Fi1)
  elsif (File.exist?Fi2 )
    IO.read(Fi2)
  else
    'http://linuxfire.com.cn/~sevk/UBUNTU新手资料.php'
  end
end
def loadDic()
  $str1 = readDicA
  puts 'Dic load [ok]'
end

def safe(level)
  result = nil
  Thread.start {
    p 'safe thread start'
    $SAFE = level
    begin
      result = yield
    rescue Exception => detail
      puts detail.message()
    end
  }.join
  result
end

class Rss_reader
  attr_accessor :title, :pub_date, :description, :link
end
def get_feed(url= 'http://forum.ubuntu.org.cn/feed.php')
  @rss_str = Net::HTTP.get(URI.parse(url))
  @rss_str = @rss_str.gsub(/\s/,' ')
  xml_doc = REXML::Document.new(@rss_str)
  re = Array.new
  $ub = ''
  xml_doc.elements["rss/channel"].each_element("//item") do |ele|
    reader = Rss_reader.new
    reader.title = ele.elements["title"].get_text
    reader.pub_date = ele.elements["pubDate"].get_text
    reader.description = ele.elements["description"].get_text
    reader.link = ele.elements["link"].get_text
    re << reader

    next if reader.title.to_s =~ /^Re:/i
    #puts reader.title.to_s
    #puts reader.title.to_s.size
    $ub = "新⇨ #{reader.title}\r#{reader.link}\r#{reader.description}"
    $ub = unescapeHTML($ub)
    $ub.gsub!(/<.+?>/,' ')
    break
  end
  #puts re[0].title.to_s + " == "
  #puts re[0].description.to_s + " == "
  #puts re[0].link.to_s + " == "
  if $old_feed_size == $ub.size
    $ub =nil
  else
    $old_feed_size = $ub.size
  end
  #puts $ub
  $ub
end

def getGoogle_tran(word)'google 翻译
    word.gsub!(/['&]/,'"')
    if word =~/[\x7f-\xff]/#有中文
      flg = 'zh-CN%7Cen'
      #flg = '#auto|en|' + word ; puts '中文>英文'
    else
      flg = 'en%7Czh-CN'
      #flg = '#auto|zh-CN|' + word
    end
    word = URI.encode(word)
    #url = "http://translate.google.cn/translate_t?hl=zh-CN#{flg}"

    Net::HTTP.start('translate.google.cn') {|http|
      resp, data = http.get("/translate_a/t?client=firefox-a&text=#{word}&langpair=#{flg}&ie=UTF-8&oe=UTF-8", nil)
      return resp.body
    }

    #url = "http://ajax.googleapis.com/ajax/services/language/translate?v=1.0&q=#{word}&langpair=#{flg}"
    #return `curl -e http://www.my-ajax-site.com '#{url}' 2>/dev/null`.match(/"translatedText":"(.+?)"\}/)[1].to_s
end

def gettitle(url)
    uri = URI.parse(url.untaint.strip)
    #puts uri.host.to_s + ' ' + uri.path.to_s
    begin #加入错误处理
        if url =~ /taobao\.com\//i
          flag=1
        else
          flag=0
        end
        response = nil
        Net::HTTP.start(uri.host.untaint, uri.port.untaint) { |http|
            response = http.head(uri.path.size > 0 ? uri.path.untaint : "/")
        }
        case response['content-type'].to_s
        when /text\/html/i
          #~ puts "response['content-type']=" + response['content-type'].to_s
        when /(text\/plain)/i
          return nil if flag ==0
        else
          p response['content-type']
          return nil
        end
    rescue Exception => detail
        puts detail.message()
    end
  if url.index(/\.bbs\.net|autoer\.cn/i) != nil #某些网站防刷
    sleep 2.1
  end
  uri.open(
    'Accept'=>'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, */*',
    'Referer'=> URI.escape(url) ,
    'Accept-Language'=>'zh-cn',
    'Accept-Encoding'=>'zip,deflate',
    'User-Agent'=> UserAgent
  ) {|f|
      #~ p f.base_uri         # <URI::HTTP:0x40e6ef2 URL:http://www.ruby-lang.org/en/>
      $istxthtml= f.content_type.index(/text\/html/i) != nil
      #~ cc= f.content_type
      $charset= f.charset          # "iso-8859-1"
      #~ puts "1=#{$charset}"
      #~ $charset='gb2312' if $charset=="iso-8859-1"
      #~ p f.content_encoding # []
      #~ p f.last_modified    # Thu Dec 05 02:45:02 UTC 2002
  }
  if $istxthtml then
    a=uri.read[0,16095].gsub(/\s+/,' ')#8095
    a=~ /<title>(.*?)<\/title>/i
    title=$1.to_s
    if ''==title
      if a.match(/meta http-equiv="refresh(.*?)url=(.*?)">/i)
        return "=http://#{uri.host}/#{$2}"
      end
    end
    return nil if title.index(/index of/i)
    #return nil if title !~ Re_cn  #没中文就忽略
    charset=$charset
    a.match(/charset=(.+?)["']\s?/i)
    charset=$1 if $1 !=nil
    #~ puts '2=' + charset.to_s

    title.gsub!(/<\/?title(.*?)>/i,'')
    title = unescapeHTML(title)
    title.gsub!(/&(.*?);/i," ")
    title.gsub!(/\s\W?\s/,' ')
    return Iconv.conv("UTF-8//IGNORE","#{charset}//IGNORE",title).to_s
  end
end

def getGoogle_api(word, start)
  p word;p start
  #~ KEY = File.open("#{ENV['HOME']}/.google_key") {|kf| kf.readline.chomp}
  query = word.untaint.strip
  #~ google = Google::Search.new('SMnBKRNh0ihAE/k4P3BG/2ID3/Q3WzYc')
  google = Google::Search.new('SMnBKRNh0ihAE/k4P3BG/2ID3/Q4WzYu')
  google.utf8('iso-8859-15')
  i = 0;$re = ''
  q = google.search(query,start)#,1,false,'',false,'lang_zh-CN|lang_en')
  q.resultElements.each do |result|
    printf "\nResult # %d\n\n", i += 1
    result.each do |key|
      printf("%s = %s\n", key, result.send(key))
      $re = result.send('snippet') + ' ' + result.send('url')
    end
  end
  return $re.gsub(/<(.*?)>/,'')
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
  if re=~/[\x7f-\xff]/#是中文才返回
    return re
  end
end
def getTQFromName(nick)
  ip=$u.getip(nick).to_s
  p 'getip=' + ip
  tmp=getProvince(ip).to_s
  getTQ(tmp)
  #return getGoogle(tmp + ' tq',0)
end

def getTQ(s)
  getGoogle(s + ' tq',0)
end

def getGoogle(word,flg)
    c=''
    re=''
    #~ uri = URI.parse(url.untaint.strip)
    c='http://www.google.cn/search?hl=zh-CN&q=' + word #+ '&btnG=Google+%E6%90%9C%E7%B4%A2&meta=lr%3Dlang_zh-TW|lang_zh-CN|lang_en&aq=f&oq='
    c=c.untaint.strip
    puts '  ----- url=' + URI.escape(c ) + '-----   '
    open(URI.escape(c ),
    #~ 'Accept'=>'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*',
    'Referer'=> URI.escape(c),
    #~ 'Accept-Language'=>'zh-cn',
    #~ 'Accept-Encoding'=>'zip,deflate',
    'User-Agent'=> UserAgent
    ){ |f|
      html=f.read().gsub(/\s/,' ')
      case flg
      when 1#拼音查询
        #~ html.match(/是不是要找：(.*?)<\/div>/)
        html.match(/是不是要找：.*?<em>(.*?)<\/em>/i)#<!--a-->
        re=$1.to_s
        re.gsub!(/\s/i,' ')
        re = unescapeHTML(re)
        #puts re + "\n\n\n"
      when 0
        matched = true
        case html
        when /相关词句：(.*?)<p>网络上查询<b>(.*?)(https?:\/\/\S+[^\s*])&usg=/i#define
          tmp = $2 + " > " + $3
          tmp += ' === SEE ALSO ' + $1 if rand(10)>5
        when /专业气象台|比价仅作信息参考/
          tmp = html.match(/>网页<.+?(搜索用时|>网页<\/b>)(.*?)(搜索结果|Google 主页)/)[2]
        when /calc_img\.gif(.*?)Google 计算器详情/i #是计算器
          tmp ='<'+$1.to_s + ' Google 计算器详情' #(.*?)<li>
        else
          matched = false
        end
        #p;puts html.match(/搜索用时(.*?)搜索结果<\/h2>(.*?)网页快照/i)[0]
        if matched or html =~ /搜索用时(.*?)搜索结果<\/h2>(.*?)网页快照/i
          if !matched
            tmp =$2
            #puts 'tmp=' + tmp.to_s
            tmp1=$1
            #puts 'tmp1=' + tmp1.to_s
          end
          tmp.gsub!(/(.+?)此展示您的广告/i,'')
          #if tmp=~/赞助商链接/
            #puts '赞助商链接'
            ##tmp=tmp1 
          #end
          tmp.gsub!(/赞助商链接(.+?)id=rhspad>/i,'')
          tmp.gsub!(/更多有关货币兑换的信息。/,"")
          tmp.gsub!(/<br>/i," ")
          #~ puts tmp + "\n"
          case word
          when /tq$|天气$|tianqi$/i
            #puts '天气过滤' + tmp.to_s
            tmp.gsub!(/alt="/,'>')
            tmp.gsub!(/"\stitle=/,'<')
            tmp.gsub!(/\s\/\s/,"\/")
            tmp.gsub!(/级/, '级  ' )
            tmp.gsub!(/今日\s+/, ' 今日' )
            tmp.gsub!(/<\/b>/, '')
            tmp.gsub!(/(添加到)(.*?)当前：/,' ')
            #tmp.gsub!(/北京市专业气象台(.*)/, '' )
            tmp=tmp.match(/.+?°C.+?°C/)[0]
            tmp.gsub!(/°C/, '度 ' )
          end
          tmp.gsub!(/(.*秒）)|\s+/i,' ')
          #puts "tmp.size=#{tmp.size} , #{tmp}"
          #~ puts html
          if tmp.size > 30 && word.match(/^13.........$/i) == nil && tmp.match(/小提示/)==nil then
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
          url=$2.to_s
          re = $4.to_s + $5.to_s #+ $3.to_s.sub(/.*?>/i,'')
          if url =~ /https?:\/\/(.*?)(https?:\/\/.+?)/i
            puts '清理二次http'
            url=$2.to_s
          end
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
    return re
end

def getBaidu(word)
    word= Iconv.conv("gb2312//IGNORE","UTF-8//IGNORE",word).to_s
    c=  'http://www.baidu.com/s?cl=3&wd='+word
    puts URI.escape(c)
    open(URI.escape(c),
    'Accept'=>'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*',
    'Referer'=>'http://www.baidu.com/s?cl=3&wd='+word ,
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
        #~ if re.match(/<font\scolor=#C60A00>(.*?)<\/font>/i) != nil
          #~ re.gsub!(/<font\scolor=#C60A00>(.*?)<\/font>/i,$1)[0,270]
        #~ end
        $re =  a2 + ' ' +  re
        $re = unescapeHTML($re)
        $re =  Iconv.conv("UTF-8//IGNORE","gb2312//IGNORE",$re).to_s[0,980]
        #~ re = html.match(/ScriptDiv(.*)#008000/).to_s
        #~ $re =   Iconv.conv("UTF-8//IGNORE","GB18030//IGNORE",ss).to_s
    }
    $re
end

def getBaidu_tran(word,en=true)
    word= Iconv.conv("GB18030//IGNORE","UTF-8//IGNORE",word).to_s
    c=  'http://www.baidu.com/s?cl=3&wd='+word+'&ct=1048576'
    puts URI.encode(c)
    open(URI.encode(c),
    'Accept'=>'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*',
    'Referer'=> URI.encode(c) ,
    'Accept-Language'=>'zh-cn',
    'Accept-Encoding'=>'deflate',
    'User-Agent'=> UserAgent,
    'Host'=>'www.baidu.com',
    'Connection'=>'close',
    'Cookie'=>'BAIDUID=EBBDCF1D3F9B11071169B4971122829A:FG=1; BDSTAT=172f338baaeb951db319ebc4b74543a98226cffc1f178a82b9014a90f703d697'
    ) {|f|
        html=f.read()
        html.gsub!(/\s+/,' ')
        #html = Iconv.conv("UTF-8//IGNORE","GB18030//IGNORE",html.to_s).to_s
        re = html.match(/class="wd">(.+?)pronu/i)[1].to_s + ' '
        #puts utf8(re)
        re += html.match(/class="explain">(.+?)<script/i)[1]
        re.gsub!(/<.*?>/,'')
        re = Iconv.conv("UTF-8//IGNORE","GB18030//IGNORE",re).to_s
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

def time_min()
  "#{Time.now.strftime('[%H:%M]')}"
end
def chr_hour()
  "\343\215"+ (Time.now.hour + 0230).chr
end

def host(domain)#处理域名
  return 'IPV6' if domain =~ /^([\da-f]{1,4}(:|::)){1,6}[\da-f]{1,4}$/i
  domain=domain.match(/^[\w\.\-\d]*/)[0]
  begin
    return `host #{domain} | grep has | head -n 1`.strip.match(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/)[0]
  rescue Exception => detail
    puts detail.message()
    '火星'
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
  return '网页版irc' if tmp == '59.36.101.19'
  tmp = tmp + ' ' + IpLocationSeeker.new.seek(tmp)
  tmp.gsub!(/CZ88\.NET/i,'不在地球上')
  tmp.gsub!(/IANA/i,'火星')
  tmp
end
def utf8(s)
  return Iconv.conv("UTF-8//IGNORE","GB18030//IGNORE",s).to_s
end
def googleFinance(word)
  #~ return nil # debuging
  #~ return nil if word == nil
  word='上证指数' if word.to_s==''
    c=  'http://finance.google.cn/finance?q=' + word + '&hl=zh-cn'
    c= URI.encode(c)  ; p c
    open( c,
    'Accept'=>'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*',
    'Referer'=> c,
    'Accept-Language'=>'zh-cn',
    'Accept-Encoding'=>'deflate',
    'User-Agent'=> UserAgent
    ) {|f|
        html=f.read()[3048,20202]
        html.gsub!(/\s/,' ')
        html = unescapeHTML(html)
        re = '' ; a2 = '' ; p
        #~ re = html.match(/(http:\/\/\S+[^\s*]?)(.*?)/i).to_s
        html=~ /<h1>(.*?)<\/h1>/i
        name = $1 + '：'
        html.match(/MARKET\ DATA\ AND\ CHART(.*?)table(.*?)<tr>(.*?)<\/tr>(.*?)<\/tr>(.*?)<\/tr>(.*?)<\/tr>/i)
        a1=$1;a2=$2;a3=$3;a4=$4;a5=$5;a6=$6
        #~ puts a3.to_s.strip.gsub(/<.*?>/,'')   ; puts a4.to_s.strip.gsub(/<.*?>/,'')
        #~ puts a5.to_s.strip.gsub(/<.*?>/,'')   ; puts a6.to_s.strip.gsub(/<.*?>/,'')
        re = name + a3.to_s.strip.gsub(/<.*?>/,'')  +  a4.to_s.strip.gsub(/<.*?>/,'')  + \
        a5.to_s.strip.gsub(/<.*?>/,'') + a6.to_s.strip.gsub(/<.*?>/,'')
        re= re.gsub(/\s+/i,' ')
        re.gsub!(/日(.*?)收盘/,'日收盘')
        re.gsub!(/：\s/,':')
        $re =  re[0,600]
    }
    if $re.size < 20
      puts $re
      puts $re.size
      return nil
    end
    $re
end

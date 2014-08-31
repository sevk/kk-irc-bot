require 'mechanize'

def get_eval_in code
  if code !~ /print|puts/
    code = "def a;#{code};end;p a"
  end
  log ' eval: ' + code
  a=Mechanize.new
  a.user_agent_alias = 'Linux Mozilla'
  url = 'https://eval.in/'
  s = a.get url
  #code = URI.encode(code)
  s.forms[0].code = code
  s.forms[0].lang = "ruby/mri-2.1"
  s = a.submit s.forms[0]
  r = s.body.match(/ output.*?<pre>(.*?)</im)[1]
  r << '  =>  ' << s.uri.to_s
  r.unescapeHTML
end


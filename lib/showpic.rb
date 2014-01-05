
#run sh 30 sec
def sh30
  Timeout.timeout(30){
    Thread.new { system s }
  }
end

def showpic(url)
  return if not ENV.has_key? 'DISPLAY'
  sh30 "feh #{url}"
end



#run sh 30 sec
def sh30
  Timeout.timeout(30){
    Thread.new { system s }
  }
end

def showpic(url)
  #sh30 "feh #{url}"
end


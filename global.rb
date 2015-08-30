
CN_re = /(?:\xe4[\xb8-\xbf][\x80-\xbf]|[\xe5-\xe8][\x80-\xbf][\x80-\xbf]|\xe9[\x80-\xbd][\x80-\xbf]|\xe9\xbe[\x80-\xa5])+/n unless defined? CN_re
UserAgent="(X11; U; Linux i686; en-US; rv:1.9.1.2) Gecko/20090810 Ubuntu/#{`lsb_release -r`.split(/\s/)[1] rescue ''} (ub)" unless defined? UserAgent

$botlist=/ubrl|^\^k\^|fity|badgirl|pocoyo.?.?|MadGirl/i

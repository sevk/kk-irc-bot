
require "sinatra"

configure do
  mime_type :text, 'text/plain'
  set :port , 8080
end

get "/" do
  #send_file  './public/index.html'
  #redirect "http://#{request.host}:/env", 'www xx '
  "hello world"
end

get "/env" do
  #content_type :text

  html = ""
  html << "<!DOCTYPE html>\n<html><body>\n <pre> \n System Environment:\n\n"
  ENV.each do |key, value|
    html << "#{key}: #{value}\n"
  end
  html << " </pre></body></html> "
end

get "/.profile" do
  s = `cat ~/.bash_profile`
  "<pre> #{s} </pre> "
end



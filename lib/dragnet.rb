require 'rubygems'

require 'nokogiri'
require 'open-uri'
require 'pp'
require 'uri'
# Should be using: https://github.com/speedmax/mofo
# ...but can't require that in the gemspec because it shares same name
# as a released gem :(
require 'mofo'

$:.unshift(File.dirname(__FILE__))

require 'dragnet/dragger'

#Dragnet::Dragger::DEBUG = true
#Dragnet::Dragger::DEBUG_CONTENT = 'Report abuse'
#Dragnet::Dragger.drag!(File.read("/Users/justin/dev/me/ruby/dragnet/test/data/the-fix.html")).content

#Dragnet::Dragger.drag!(open('http://www.fivethirtyeight.com/2009/08/are-progressives-on-tilt.html').read).links
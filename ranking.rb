#!/usr/bin/env ruby

require 'optparse'
require 'open-uri'
require 'net/http'

API_ENDPOINT = 'http://nmsg.nicovideo.jp/api.json/'

params = ARGV.getopts('u:p:t:')

def login(user, pass)
	ENDPOINT = 'https://secure.nicovideo.jp/secure/login?site=niconico'
end


def list_movies(tag)
	ENDPOINT = 'https://api.search.nicovideo.jp/api/v2/video/contents/search'
end

def list_comments(movie)
	# https://qiita.com/tor4kichi/items/74939b49954d3e72d789
end


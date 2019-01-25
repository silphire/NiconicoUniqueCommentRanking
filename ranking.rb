#!/usr/bin/env ruby

require 'optparse'
require 'open-uri'
require 'httpclient'
require 'uri'
require 'json'

API_ENDPOINT = 'http://nmsg.nicovideo.jp/api.json/'
TAGS = %w(
	超振り付け選手権2019_ソロ部門
	超振り付け選手権2019_コラボ部門
)

params = ARGV.getopts('u:p:t:')

def login(user, pass)
	endpoint = URI.parse('https://secure.nicovideo.jp/secure/login?site=niconico')
	client = HTTPClient.new
	response = client.post(endpoint, query: {mail: user, password: pass})
	if HTTP::Status.successful?(response.code)
		return client
	else
		return nil
	end
end

def list_movies(tag)
	endpoint = 'https://api.search.nicovideo.jp/api/v2/video/contents/search'
	query = URI.encode_www_form({
		'q' => tag,
		'targets' => 'tagsExact',
		'fields' => 'contentId,title',
		'_sort' => 'startTime',
		'_context' => 'NiconicoUniqueCommentRanking',
	})
	url = URI.parse('%s?%s' % [endpoint, query])

	open(url) do |io|
		return JSON.parse(io.read)
	end
end

def list_comments(client, content_id)
	# https://qiita.com/tor4kichi/items/74939b49954d3e72d789

	movie_url = 'https://www.nicovideo.jp/watch/' + content_id
end

list_movies(TAGS[0])['data'].each do |data|
	puts data['title']
	puts data['contentId']
end
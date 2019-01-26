#!/usr/bin/env ruby

require 'optparse'
require 'open-uri'
require 'httpclient'
require 'uri'
require 'json'
require 'cgi'

API_ENDPOINT = 'http://nmsg.nicovideo.jp/api.json/'
TAGS = %w(
	超振り付け選手権2019_ソロ部門
	超振り付け選手権2019_コラボ部門
)

params = ARGV.getopts('u:p:t:')

def login(user, pass)
	endpoint = URI.parse('https://secure.nicovideo.jp/secure/login?site=niconico')
	client = HTTPClient.new
	response = client.post(endpoint, {'mail' => user, 'password' => pass})
	return client
end

def list_movies(tag)
	# http://site.nicovideo.jp/search-api-docs/search.html

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

def _create_request_ping(content)
	return {
		"ping" => {
			"content" => content,
		}
	}
end

def _create_comment_request(threads)
	request = []
	request << _create_request_ping(client, 'rs:0')
	request << _create__request_ping(client, 'ps:0')
	# thread
	request << _create__request_ping(client, 'pf:0')
	request << _create__request_ping(client, 'ps:1')
	# thread_leaves
	request << _create__request_ping(client, 'pf:1')
	request << _create__request_ping(client, 'rf:0')
end

def list_comments(client, content_id)
	# https://qiita.com/tor4kichi/items/74939b49954d3e72d789
	# 1000コメント以上未対応。応募期間中に多分そこまで行かないので。

	movie_url = 'https://www.nicovideo.jp/watch/' + content_id
	response = client.get(movie_url)
	json = nil
	if /<div id="js-initial-watch-data" data-api-data="([^"]*)"/ =~ response.body
		json = JSON.parse(CGI.unescape_html(Regexp.last_match(1)))
	else
		return []
	end

	threads = json['commentComposite']['threads'].select {|thread| thread['isActive']}

	endpoint = 'http://nmsg.nicovideo.jp/api.json/'
	client.post(endpoint, JSON.unparse(request))
end

if $0 == __FILE__
	list_movies(TAGS[0])['data'].each do |data|
		puts data['title']
		puts data['contentId']
	end
end

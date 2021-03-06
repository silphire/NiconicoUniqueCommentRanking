#!/usr/bin/env ruby

require 'optparse'
require 'open-uri'
require 'httpclient'
require 'uri'
require 'json'
require 'cgi'

TAGS = %w(
	超振り付け選手権2019_ソロ部門
	超振り付け選手権2019_コラボ部門
)

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

def _create_request_component(request, component, count)
	request << _create_request_ping('ps:' + count.to_s)
	request << component
	request << _create_request_ping('pf:' + count.to_s)
end

def _create_comment_request(threads, userkey, user_id, duration)
	count = 0
	request = []
	request << _create_request_ping('rs:0')

	threads.each do |thread|
		if thread['isActive']
			component = {
				"thread" => {
					"thread" => thread["id"].to_s,
					"version" => "20090994",
					"fork" => thread["fork"],
					"language" => 0,
					"user_id" => user_id.to_s,
					"with_global" => 1,
					"scores" => 1,
					"nicoru" => 0,
					"userkey" => userkey,
				}
			}
			_create_request_component(request, component, count)
			count += 1
		end

		if thread['isLeafRequired']
			component = {
				"thread_leaves" => {
					"thread" => thread["id"].to_s,
					"language" => 0,
					"user_id" => user_id.to_s,
					"content" => "0-%d:100,1000" % (duration / 60 + ((duration % 60 > 0) ? 1 : 0)),
					"scores" => 1,
					"nicoru" => 0,
					"userkey" => userkey,
				}
			}
			_create_request_component(request, component, count)
			count += 1
		end
	end

	request << _create_request_ping('rf:0')
	return request
end

require 'pp'

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

	threads = json['commentComposite']['threads']
	userkey = json["context"]["userkey"]
	user_id = json["viewer"]["id"]
	duration = json["video"]["duration"]
	request = _create_comment_request(threads, userkey, user_id, duration)

	endpoint = 'http://nmsg.nicovideo.jp/api.json/'
	response = client.post(endpoint, body: JSON.unparse(request), header: {
		'Content-Type' => 'text/plain;charset=UTF-8',
		'Referer' => movie_url,
		'Origin' => 'https://www.nicovideo.jp',
		'Accept' => '*/*',
	})

	json = JSON.parse(CGI.unescape_html(response.body))
	chats = json.select{|component| component.include?('chat')}
	return chats
end

def count_comments(chats, content_id)
	comments = 0
	deleted = 0
	user_hash = Hash.new(0)
	chats.each do |chat|
		chat = chat['chat']
		if chat.include?('user_id')
			user_hash[chat['user_id']] += 1
		end
		comments += 1
		deleted += 1 if chat.include?('deleted') && chat['deleted'] >=1
	end
	users = user_hash.size
	return [comments, users, deleted]
end

def show_ranking(client)
	TAGS.each do |tag|
		stats = []

		movies = list_movies(tag)['data']
		movies.each do |movie|
			content_id = movie['contentId']

			retry_count = 0
			loop do 
				comments = list_comments(client, content_id)
				count = count_comments(comments, content_id)
				if count[0] > 0
					stats << [count[1], content_id, movie['title']]
					break
				end

				retry_count += 1
				puts "#{content_id} retrying (#{retry_count}/10)..."
				if retry_count == 10
					raise 'retry limit exceeded'
				end
				sleep(5)
			end
		end

		stats.sort!{|a, b| -(a[0] <=> b[0])}

		puts('# ' + tag)
		puts()
		stats.each_with_index do |n, stat|
			puts "#{n}: (#{stat[0]} users) [#{stats[2]}](https://www.nicovideo.jp/watch/#{stat[1]})"
		end
		puts()
	end
end

if $0 == __FILE__
	client = login(ARGV[0], ARGV[1])
	show_ranking(client)
end

# Written By: Colin Mitchell
# Source: http://muffinlabs.com/2013/12/03/ebook-yourself/
#!/usr/bin/env ruby

require 'bundler/setup'
require 'chatterbot/dsl'
require 'marky_markov'
#
# this is the script for the twitter bot mitchc2_ebooks
# generated on 2013-11-26 16:31:48 -0500
#

consumer_key ENV['CONSUMER_KEY']
consumer_secret ENV['CONSUMER_SECRET']

secret ENV['ACCESS_SECRET']
token ENV['ACCESS_TOKEN']

PARENT_ACCOUNT = 'floriidaaa'

old_since_id = since_id


#
# load in tweets. if this is the first run of the script, it will
# iterate as far back as possible to get a good corpus. otherwise, it
# will load tweets that have been generated since the last time the
# script ran
#
use_max_id = since_id.nil?
tmp_since_id = since_id
tmp_max_id = nil

all_tweets = []
tweets = nil

while tweets.nil? || tweets.size > 0
  opts = {
    :count => 200,
    :exclude_replies => true,
    :include_rts => false,
    :trim_user => true
  }

  if use_max_id
    opts[:max_id] = tmp_max_id.nil? ? 9223372036854775806 : tmp_max_id - 1
  else
    opts[:since_id] = tmp_since_id
  end

  tweets = client.user_timeline(PARENT_ACCOUNT, opts)

  if tweets.size > 0
    tmp_since_id = tweets.first.id
    tmp_max_id = tweets.last.id
    puts tmp_max_id

    all_tweets << tweets
  end
end


markov = MarkyMarkov::Dictionary.new("#{PARENT_ACCOUNT}_ebooks", 3)

#
# get rid of any tweets with associated URLs
#
all_tweets = all_tweets.flatten.reject { |t|
  t.urls.size > 0
}

highest_id = 0

#
# load new tweets into the database
#
all_tweets.each { |t|
  if t.id > highest_id
    highest_id = t.id
  end

  #
  # some arbitrary cleanup here. remove any @ signs so we don't spam
  # users. reject any links, hash tags, etc.
  #
  txt = t.text.gsub(/@[^ ]+/, "").split(/ /).reject { |w| w =~ /^http/ || w =~ /^RT/ || w =~ /#/ }.join(" ")
  puts txt

  markov.parse_string txt
}

#
# update the last tweet id
#
if highest_id > 0
  since_id highest_id
end

markov.save_dictionary!

did_reply = false

verbose

#
# reply to any mentions
#
replies do |tweet|
  reply "#USER# #{markov.generate_1_sentence}", tweet
  did_reply = true
end

#
# send out a tweet if the parent account has tweeted, or if it's been awhile
#
last_tweet = bot.config[:last_update] || Time.now - 1200000
diff = Time.now - last_tweet

if did_reply == false && (old_since_id != since_id || diff > 432000)
  tweet markov.generate_1_sentence
  bot.config[:last_update] = Time.now
end

#!/usr/bin/env ruby

# cleanupStreams.rb
# Origin Date: 9 April 2012
# Author: Brian Granaghan <bgranaghan@gmail.com>
# Maintained By: Brian Granaghan <bgranaghan@gmail.com>

require 'rubygems'
require 'aws-sdk'
require 'aws/s3'
require 'chronic'
require_relative 'notifyMailer.rb'
require_relative 'accessKeys.rb'

# Get formatted date of last sunday
day = Chronic.parse('last Sunday')
formattedDate = day.strftime('%m_%d_%y')
fileName = 'Encoder1.ismv'

# Initialize S3 Connection
AWS.config(:access_key_id => $accessKeys_key, :secret_access_key => $accessKeys_privateKey)
s3 = AWS::S3.new
sns = AWS::SNS.new(:access_key_id => $accessKeys_key, :secret_access_key => $accessKeys_privateKey)
sns_topic = sns.topics[$notifyMailer_streamNotificationTopic]
# Open asccvideoin bucket and check for video
bucket = s3.buckets["asccvideoin"]
fileExists = bucket.objects["#{formattedDate}/Encoder1.ismv"].exists?

if fileExists
   print "File Found\n"
   sns_topic.publish("Stream \"#{formattedDate}/#{fileName}\" found. Proceeding with cleanup.")
   %x(sh ~/cleanupStreams.sh)
else
   sns_topic.publish("Stream \"#{formattedDate}/#{fileName}\" not found. Aborting cleanup!")
end

#!/usr/bin/env ruby

# uploadStreams.rb
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
today = Chronic.parse('today')
formattedDate = today.strftime('%m_%d_%y')
fileName = 'Encoder1.ismv'

# @TODO: upload_file.rb has to be called from the command line since it uses
#        ARGC and ARGV. We need to create am equivalent function and call it 
#        here.
#upload_file.rb "asccvideoin" "#{formattedDate}" "/var/www/html/9am.isml/Encoder1.ismv"

# Initialize S3 Connection
AWS.config(:access_key_id => $accessKeys_key, :secret_access_key => $accessKeys_privateKey)
s3 = AWS::S3.new
sns = AWS::SNS.new(:access_key_id => $accessKeys_key, :secret_access_key => $accessKeys_privateKey)
sns_topic = sns.topics[$notifyMailer_streamNotificationTopic]

# Open asccvideoin bucket and check for video
bucket = s3.buckets["asccvideoin"]
fileExists = bucket.objects["#{formattedDate}/#{fileName}"].exists?

if fileExists
   sns_topic.publish("Tried to upload \"#{formattedDate}/#{fileName}\", but it already exists! Aborting upload.")
   abort
else
   %x(sh ~/uploadStreams.sh "#{formattedDate}/" "#{fileName}")
   %x(sh ~/uploadStreams.sh "#{formattedDate}/" "low_bitrate.mp4")
end

fileExists = bucket.objects["#{formattedDate}/#{fileName}"].exists?

if fileExists
   print "File Found\n"
   sns_topic.publish("Stream \"#{formattedDate}/#{fileName}\" uploaded successfully.")
else
   sns_topic.publish("Stream \"#{formattedDate}/#{fileName}\" failed to upload.")
end


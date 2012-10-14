# Copyright 2011 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
#     http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.

require 'rubygems'
require 'yaml'
require 'peach'
require 'thread'
require 'aws-sdk'


AWS.config(:access_key_id => '', :secret_access_key => '')
CHUNK_SIZE=25*1024*1024
NUM_UPLOAD_THREADS=10


$stream_mutex = Mutex.new
def get_chunk(stream, chunk_number)
  data=""

  $stream_mutex.synchronize do
    stream.seek(chunk_number * CHUNK_SIZE, IO::SEEK_SET)
    data=stream.read(CHUNK_SIZE)
  end

  data
end

def get_num_chunks(stream)
  num_chunks=stream.stat.size / CHUNK_SIZE
  num_chunks.ceil
end

def upload_chunk(upload, stream, chunk_number, num_chunks)
  puts "Reading chunk #{chunk_number} out of #{num_chunks}"
  part=get_chunk(stream, chunk_number)
  puts "Uploading chunk #{chunk_number} (length=#{part.size}) out of #{num_chunks}"
  upload.add_part(part, :part_number => chunk_number+1)
  puts "Uploaded chunk #{chunk_number} out of #{num_chunks}"
end

if(ARGV.size < 2 || ARGV.size > 3)
  puts "Usage: upload_file.rb <BUCKET_NAME> [PREFIX] <FILE_NAME>"
  exit 1
end

if(ARGV.size == 2)
	(bucket_name, file_name) = ARGV
else
	(bucket_name, prefix, file_name) = ARGV
end

# get an instance of the S3 interface using the default configuration
s3 = AWS::S3.new

# create a bucket
s3_bucket = s3.buckets.create(bucket_name)

# upload a file
if(prefix)
  basename = prefix + File.basename(file_name)
else
  basename = File.basename(file_name)
end
s3_object = s3_bucket.objects[basename]

part_number=0
uploaded_size=0


file_to_upload=File.open(file_name, "rb")
num_chunks=get_num_chunks(file_to_upload)
puts "Uploading #{num_chunks} chunks"

s3_object.multipart_upload() do |upload|
  (0...num_chunks+1).to_a.peach(NUM_UPLOAD_THREADS) {|part_number| upload_chunk(upload, file_to_upload, part_number, num_chunks)}

  upload.parts.each do |cur_part|
    puts "Part #{cur_part.part_number}: size=#{cur_part.size} etag=#{cur_part.etag}"
  end
end

puts "Uploaded #{file_name} (size=#{s3_object.content_length}) to:"
puts s3_object.url_for(:read, :secure=>false)
